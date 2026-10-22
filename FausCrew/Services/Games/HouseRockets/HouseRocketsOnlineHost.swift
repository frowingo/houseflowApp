import Foundation
import FausCrewCore
import os

/// HTTP and WebSocket requests for the online engine, built exactly like Android's:
/// Bearer token, JSON content headers on HTTP, and only Authorization on the upgrade.
@MainActor
protocol HouseRocketsOnlineIO: AnyObject {
    func http(_ route: GameRoute, body: Data?) async throws -> NetworkHTTPResponse
    func socketRequest(sessionID: String) throws -> URLRequest
}

@MainActor
final class LiveHouseRocketsOnlineIO: HouseRocketsOnlineIO {
    private let network: any HTTPRequestExecuting
    private let keychain: any KeychainStoring
    private let endpoints: GameEndpointBuilder

    init(network: any HTTPRequestExecuting, keychain: any KeychainStoring, baseURL: URL) {
        self.network = network
        self.keychain = keychain
        endpoints = GameEndpointBuilder(baseURL: baseURL)
    }

    func http(_ route: GameRoute, body: Data?) async throws -> NetworkHTTPResponse {
        try await network.execute(endpoints.request(route, token: token(), body: body))
    }

    func socketRequest(sessionID: String) throws -> URLRequest {
        try endpoints.request(.realtime(sessionId: sessionID), token: token())
    }

    private func token() throws -> String {
        guard let token = keychain.authToken else { throw GameRealtimeError.authenticationRequired }
        return token
    }
}

/// The iOS host of FausCrewCore's online engine for one match (Android:
/// `HouseRocketsOnlineSession`). It performs the engine's effects with URLSession,
/// reports each outcome with its tag and ticks the engine every 25 ms. Lobby, reconnect,
/// control and result rules all live in the engine.
@MainActor
final class HouseRocketsOnlineHost {
    var onLobbyChange: ((HouseRocketsOnlineLobbyState) -> Void)?
    var onResultChange: ((HouseRocketsOnlineResultState) -> Void)?
    var onHaptic: ((HouseRocketsOnlineHaptic) -> Void)?
    var onClosed: (() -> Void)?

    let engine: HouseRocketsOnlineEngine
    private let io: any HouseRocketsOnlineIO
    private let makeTransport: @MainActor (URLSession) -> any GameRealtimeTransporting
    /// One WebSocket session per match: every reconnect reuses it and `dispose`
    /// invalidates it, so no abandoned connection keeps counting against the
    /// server's realtime capacity (a full instance answers the upgrade with 503).
    private let socketSession = URLSession(configuration: .ephemeral)
    private let clock: GameRealtimeClock
    private let tickInterval: TimeInterval
    private static let log = Logger(subsystem: "com.fauscrew", category: "HouseRocketsOnline")

    private var transport: (any GameRealtimeTransporting)?
    private var socketConnection = -1
    private var receiveTask: Task<Void, Never>?
    private var tickTask: Task<Void, Never>?
    private var sendQueue: [(text: String, connection: Int)] = []
    private var sendTask: Task<Void, Never>?
    private var requestTasks: [Task<Void, Never>] = []
    private var lastLobby: HouseRocketsOnlineLobbyState?
    private var lastResult: HouseRocketsOnlineResultState?
    private var didClose = false
    private(set) var isDisposed = false

    init(engine: HouseRocketsOnlineEngine, io: any HouseRocketsOnlineIO,
         makeTransport: @escaping @MainActor (URLSession) -> any GameRealtimeTransporting = { GameRealtimeTransport(session: $0) },
         clock: GameRealtimeClock = .live, tickInterval: TimeInterval = 0.025) {
        self.engine = engine
        self.io = io
        self.makeTransport = makeTransport
        self.clock = clock
        self.tickInterval = tickInterval
    }

    var lobby: HouseRocketsOnlineLobbyState { engine.lobby }
    var result: HouseRocketsOnlineResultState { engine.result }

    func start(isForeground: Bool, isLandscape: Bool) {
        run { engine.start(isForeground: isForeground, isLandscape: isLandscape, now: $0) }
        let clock = self.clock
        let interval = tickInterval
        tickTask = Task { [weak self] in
            while !Task.isCancelled {
                do { try await clock.sleep(interval) } catch { return }
                guard let self, !self.isDisposed else { return }
                self.run { self.engine.tick(now: $0) }
            }
        }
    }

    /// Applies a user intent at the current uptime and performs what it produced.
    func perform(_ intent: (HouseRocketsOnlineEngine, TimeInterval) -> Void) {
        run { intent(engine, $0) }
    }

    func presentation() -> HouseRocketsOnlinePresentation? {
        isDisposed ? nil : engine.presentation(at: clock.uptime())
    }

    /// Cleanup without a business leave (screen closed, rematch, logout).
    func dispose() {
        guard !isDisposed else { return }
        isDisposed = true
        tickTask?.cancel(); tickTask = nil
        requestTasks.forEach { $0.cancel() }
        requestTasks.removeAll()
        closeSocket()
        socketSession.invalidateAndCancel()
        engine.disconnect()
        _ = engine.drainEffects()
        onLobbyChange = nil; onResultChange = nil; onHaptic = nil; onClosed = nil
    }

    // MARK: Effects

    private func run(_ body: (TimeInterval) -> Void) {
        guard !isDisposed else { return }
        body(clock.uptime())
        flush()
    }

    private func flush() {
        guard !isDisposed else { return }
        engine.drainEffects().forEach(execute)
        if engine.lobby != lastLobby {
            if let issue = engine.lobby.issue, issue != lastLobby?.issue {
                Self.log.notice("House Rockets lobby issue: \(String(describing: issue), privacy: .public)")
            }
            lastLobby = engine.lobby
            onLobbyChange?(engine.lobby)
        }
        if engine.result != lastResult {
            lastResult = engine.result
            onResultChange?(engine.result)
        }
        if engine.isClosed, !didClose {
            didClose = true
            onClosed?()
        }
    }

    private func execute(_ effect: HouseRocketsOnlineEffect) {
        switch effect {
        case .ensureSession(let houseID, let connection):
            request(.ensureSession(gameKey: GameKey.houseRockets),
                    body: try? GameWireContract.ensureSessionBody(houseId: houseID)) { [weak self] outcome in
                guard let self else { return }
                switch outcome {
                case .success(let response):
                    self.run { self.engine.sessionResponse(Self.core(response), retryAfter: self.retryAfter(response),
                                                          connection: connection, now: $0) }
                case .failure(let failure):
                    self.report(failure, kind: "ensure")
                    self.run { self.engine.connectionFailed(failure, connection: connection, now: $0) }
                }
            }
        case .openSocket(let sessionID, let connection):
            openSocket(sessionID: sessionID, connection: connection)
        case .closeSocket:
            closeSocket()
        case .send(let text, let connection):
            sendQueue.append((text, connection))
            drainSends()
        case .fetchResult(let sessionID, let requestID):
            request(.result(sessionId: sessionID), body: nil) { [weak self] outcome in
                guard let self else { return }
                switch outcome {
                case .success(let response):
                    self.run { self.engine.resultResponse(Self.core(response), retryAfter: self.retryAfter(response),
                                                         request: requestID, now: $0) }
                case .failure(let failure):
                    self.report(failure, kind: "result")
                    self.run { self.engine.resultFailed(request: requestID, now: $0) }
                }
            }
        case .haptic(let haptic):
            onHaptic?(haptic)
        }
    }

    private func request(_ route: GameRoute, body: Data?,
                         completion: @escaping @MainActor (HTTPOutcome) -> Void) {
        let io = self.io
        let task = Task { [weak self] in
            let outcome: HTTPOutcome
            do { outcome = .success(try await io.http(route, body: body)) }
            catch is CancellationError { return }
            catch { outcome = .failure(Self.failure(from: error)) }
            guard let self, !self.isDisposed, !Task.isCancelled else { return }
            completion(outcome)
        }
        requestTasks.append(task)
        requestTasks.removeAll { $0.isCancelled }
    }

    private func openSocket(sessionID: String, connection: Int) {
        closeSocket()
        socketConnection = connection
        let request: URLRequest
        do { request = try io.socketRequest(sessionID: sessionID) }
        catch {
            let failure = Self.failure(from: error)
            report(failure, kind: "socket")
            run { engine.connectionFailed(failure, connection: connection, now: $0) }
            return
        }
        let transport = makeTransport(socketSession)
        self.transport = transport
        receiveTask = Task { [weak self] in
            do {
                try await transport.connect(request: request)
                guard let self, !self.isDisposed, self.socketConnection == connection else { return }
                self.run { self.engine.socketOpened(connection: connection, now: $0) }
                while !Task.isCancelled {
                    let data = try await transport.receive()
                    guard !self.isDisposed, self.socketConnection == connection else { return }
                    let text = String(decoding: data, as: UTF8.self)
                    self.run { self.engine.received(text: text, connection: connection, now: $0) }
                }
            } catch {
                guard let self, !Task.isCancelled, !self.isDisposed, self.socketConnection == connection else { return }
                let failure = Self.failure(from: error)
                self.report(failure, kind: "socket")
                self.run { self.engine.connectionFailed(failure, connection: connection, now: $0) }
            }
        }
    }

    private func closeSocket() {
        receiveTask?.cancel(); receiveTask = nil
        sendTask?.cancel(); sendTask = nil
        sendQueue.removeAll()
        transport?.disconnect()
        transport = nil
        socketConnection = -1
    }

    /// One writer keeps the engine's send order on the wire.
    private func drainSends() {
        guard sendTask == nil, !sendQueue.isEmpty else { return }
        sendTask = Task { [weak self] in
            while let self, !Task.isCancelled, !self.sendQueue.isEmpty {
                let (text, connection) = self.sendQueue.removeFirst()
                guard connection == self.socketConnection, let transport = self.transport else {
                    self.run { self.engine.sendFailed(.protocolFailure(.notConnected), connection: connection, now: $0) }
                    continue
                }
                do {
                    try await transport.send(Data(text.utf8))
                } catch {
                    guard !Task.isCancelled, !self.isDisposed else { return }
                    let failure = Self.failure(from: error)
                    self.report(failure, kind: "send")
                    self.run { self.engine.sendFailed(failure, connection: connection, now: $0) }
                }
            }
            self?.sendTask = nil
        }
    }

    // MARK: Mapping

    private func retryAfter(_ response: NetworkHTTPResponse) -> TimeInterval? {
        NetworkHTTPFailure(response: response).retryAfterSeconds(at: clock.wallTime())
    }

    private static func core(_ response: NetworkHTTPResponse) -> HTTPResponse {
        HTTPResponse(statusCode: response.statusCode, headers: response.headers, body: response.data)
    }

    private static func failure(from error: Error) -> GameRealtimeSessionFailure {
        if error as? GameRealtimeError == .accessRevoked { return .http(statusCode: 403, retryAfterSeconds: nil) }
        if let error = error as? NetworkHTTPFailure {
            return .http(statusCode: error.statusCode, retryAfterSeconds: error.retryAfterSeconds(at: Date()))
        }
        if let error = error as? GameRealtimeError { return .protocolFailure(error) }
        if error is DecodingError { return .invalidPayload }
        return .transport
    }

    /// Category only: never tokens, ids, payloads or member names.
    private func report(_ failure: GameRealtimeSessionFailure, kind: String) {
        Self.log.notice("House Rockets \(kind, privacy: .public) failed: \(String(describing: failure), privacy: .public)")
    }
}

private enum HTTPOutcome {
    case success(NetworkHTTPResponse)
    case failure(GameRealtimeSessionFailure)
}
