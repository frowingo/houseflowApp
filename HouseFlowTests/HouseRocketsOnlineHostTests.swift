import Foundation
import HouseFlowCore
import XCTest
@testable import HouseFlow

/// The iOS host around HouseFlowCore's online engine: URLSession requests, socket
/// lifetime and ordering. Lobby/flight/result rules are tested in HouseFlowCore.
@MainActor
final class HouseRocketsOnlineHostTests: XCTestCase {
    private let houseID = "507f1f77bcf86cd799439012"
    private let playerID = "507f1f77bcf86cd799439021"
    private let sessionID = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"

    func testUpgradeRequestMatchesAndroidAndCarriesOnlyTheToken() async throws {
        let keychain = FakeKeychainStore()
        keychain.authToken = "fixture-token"
        let io = LiveHouseRocketsOnlineIO(network: HostHTTP(), keychain: keychain,
                                          baseURL: URL(string: "https://example.test/api/v1")!)
        let request = try io.socketRequest(sessionID: sessionID)
        XCTAssertEqual(request.url?.absoluteString,
                       "wss://example.test/api/v1/game/sessions/\(sessionID)/realtime?protocolVersion=2")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-token")
        XCTAssertNil(request.value(forHTTPHeaderField: "Accept"))
        XCTAssertNil(request.value(forHTTPHeaderField: "Content-Type"))
        keychain.authToken = nil
        XCTAssertThrowsError(try io.socketRequest(sessionID: sessionID))
    }

    func testEnsureOpenWelcomeJoinRunsThroughTheSharedEngine() async throws {
        let (host, io, transport) = makeHost()
        var lobbies: [HouseRocketsOnlineLobbyState] = []
        host.onLobbyChange = { lobbies.append($0) }
        host.start(isForeground: true, isLandscape: false)
        try await waitFor { io.requests.count == 1 && transport.connected }
        XCTAssertEqual(io.requests.first?.route, .ensureSession(gameKey: GameKey.houseRockets))
        XCTAssertEqual(try JSONSerialization.jsonObject(with: XCTUnwrap(io.requests.first?.body)) as? [String: String],
                       ["houseId": houseID])
        XCTAssertEqual(io.socketSessions, [sessionID])

        transport.push(try HostFixture.server("welcome"))
        transport.push(try HostFixture.session(version: 6, state: "lobby", players: []))
        try await waitFor { transport.sentTypes.contains("gameSession.join") }
        XCTAssertEqual(host.lobby.connection, .connected)
        XCTAssertEqual(lobbies.last?.connection, .connected)
        host.dispose()
        XCTAssertTrue(transport.disconnected)
    }

    func testDroppedSocketReconnectsToThePinnedSessionWithoutANewEnsure() async throws {
        let (host, io, transport) = makeHost()
        host.start(isForeground: true, isLandscape: false)
        try await waitFor { transport.connected }
        transport.push(try HostFixture.server("welcome"))
        transport.push(try HostFixture.session(version: 6, state: "lobby", players: []))
        try await waitFor { host.lobby.connection == .connected }
        transport.fail(URLError(.networkConnectionLost))
        try await waitFor { host.lobby.connection == .reconnecting }
        try await waitFor(timeout: 3) { io.socketSessions.count == 2 }
        XCTAssertEqual(io.requests.count, 1, "Reconnect reopens the same match; it never PUTs again")
        XCTAssertEqual(io.socketSessions, [sessionID, sessionID])
        host.dispose()
    }

    func testClosedGameStopsWithoutRetryAndUpgradeErrorsMapToHTTPStatus() async throws {
        let (host, io, _) = makeHost()
        io.ensureStatus = 409
        io.ensureBody = #"{"success":false,"code":"game.error.unavailable"}"#
        host.start(isForeground: true, isLandscape: false)
        try await waitFor { host.lobby.connection == .failed }
        XCTAssertEqual(host.lobby.issue, .connection(.protocolFailure(.gameUnavailable)))
        try await Task.sleep(for: .milliseconds(300))
        XCTAssertEqual(io.requests.count, 1)
        host.dispose()

        let (forbidden, _, transport) = makeHost()
        transport.connectError = NetworkHTTPFailure(response: .init(data: Data(),
            response: HTTPURLResponse(url: URL(string: "wss://example.test")!, statusCode: 403, httpVersion: nil, headerFields: nil)!))
        forbidden.start(isForeground: true, isLandscape: false)
        try await waitFor { forbidden.lobby.connection == .failed }
        XCTAssertEqual(forbidden.lobby.issue, .connection(.http(statusCode: 403, retryAfterSeconds: nil)))
        forbidden.dispose()
    }

    func testLeaveSendsBusinessLeaveAndClosesWhenConfirmed() async throws {
        let (host, _, transport) = makeHost()
        var closed = false
        host.onClosed = { closed = true }
        host.start(isForeground: true, isLandscape: false)
        try await waitFor { transport.connected }
        transport.push(try HostFixture.server("welcome"))
        transport.push(try HostFixture.session(version: 6, state: "lobby", players: [["playerId": playerID, "state": "waiting",
            "joinedAt": "2026-10-03T12:00:00Z"]]))
        try await waitFor { host.lobby.connection == .connected }
        host.perform { $0.leave(now: $1) }
        try await waitFor { transport.sentTypes.contains("gameSession.leave") }
        transport.push(try HostFixture.session(version: 7, state: "lobby", players: []))
        try await waitFor { closed }
        XCTAssertTrue(host.engine.isClosed)
        host.dispose()
    }

    // MARK: Helpers

    private func makeHost() -> (HouseRocketsOnlineHost, HostIO, HostTransport) {
        let io = HostIO()
        let transport = HostTransport()
        let engine = HouseRocketsOnlineEngine(
            context: HouseRocketsLaunchContext(houseID: houseID, localPlayerID: playerID, houseOwnerID: playerID),
            policy: HouseRocketsReconnectPolicy(jitter: { 0.8 }))
        let host = HouseRocketsOnlineHost(engine: engine, io: io, makeTransport: { _ in transport },
                                          tickInterval: 0.02)
        return (host, io, transport)
    }

    private func waitFor(timeout: TimeInterval = 2, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            guard Date() < deadline else { return XCTFail("Timed out") }
            try await Task.sleep(for: .milliseconds(10))
        }
    }
}

@MainActor
private final class HostIO: HouseRocketsOnlineIO {
    var requests: [(route: GameRoute, body: Data?)] = []
    var socketSessions: [String] = []
    var ensureStatus = 200
    var ensureBody: String?

    func http(_ route: GameRoute, body: Data?) async throws -> NetworkHTTPResponse {
        requests.append((route, body))
        let data = try ensureBody.map { Data($0.utf8) } ?? HostFixture.ensure()
        let response = HTTPURLResponse(url: URL(string: "https://example.test")!, statusCode: ensureStatus,
                                       httpVersion: nil, headerFields: nil)!
        return .init(data: data, response: response)
    }

    func socketRequest(sessionID: String) throws -> URLRequest {
        socketSessions.append(sessionID)
        return URLRequest(url: URL(string: "wss://example.test/\(sessionID)")!)
    }
}

@MainActor
private final class HostHTTP: HTTPRequestExecuting {
    func execute(_ request: URLRequest) async throws -> NetworkHTTPResponse { throw URLError(.notConnectedToInternet) }
}

@MainActor
private final class HostTransport: GameRealtimeTransporting {
    var connected = false
    var disconnected = false
    var connectError: Error?
    var sent: [[String: Any]] = []
    var sentTypes: [String] { sent.compactMap { $0["type"] as? String } }
    private var queued: [Result<Data, Error>] = []
    private var waiting: CheckedContinuation<Data, Error>?

    func connect(request: URLRequest) async throws {
        if let connectError { throw connectError }
        connected = true
        disconnected = false
    }
    func send(_ data: Data) async throws {
        sent.append(try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any]))
    }
    func receive() async throws -> Data {
        if !queued.isEmpty { return try queued.removeFirst().get() }
        return try await withCheckedThrowingContinuation { waiting = $0 }
    }
    func ping() async throws {}
    func disconnect() {
        disconnected = true
        connected = false
        waiting?.resume(throwing: CancellationError())
        waiting = nil
        queued.removeAll()
    }
    func push(_ data: Data) { deliver(.success(data)) }
    func fail(_ error: Error) { deliver(.failure(error)) }
    private func deliver(_ value: Result<Data, Error>) {
        if let waiting {
            self.waiting = nil
            waiting.resume(with: value)
        } else { queued.append(value) }
    }
}

private enum HostFixture {
    static func root() throws -> [String: Any] {
        let bundle = Bundle(for: HouseRocketsOnlineHostTests.self)
        let url = bundle.url(forResource: "houseRocketsProtocol", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "houseRocketsProtocol", withExtension: "json")
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: XCTUnwrap(url))) as? [String: Any])
    }

    static func server(_ name: String, mutate: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        let messages = try XCTUnwrap(root()["serverMessages"] as? [[String: Any]])
        var message = try XCTUnwrap(messages.first { $0["name"] as? String == name }?["message"] as? [String: Any])
        mutate(&message)
        return try JSONSerialization.data(withJSONObject: message)
    }

    static func session(version: Int, state: String, players: [[String: Any]]) throws -> Data {
        try server("sessionSnapshot") { message in
            var payload = message["payload"] as! [String: Any]
            payload["version"] = version
            payload["state"] = state
            payload["players"] = players
            payload["countdownEndsAt"] = NSNull()
            message["payload"] = payload
        }
    }

    static func ensure() throws -> Data {
        let http = try XCTUnwrap(root()["http"] as? [String: [String: Any]])
        var response = try XCTUnwrap(http["ensure"]?["response"] as? [String: Any])
        var data = try XCTUnwrap(response["data"] as? [String: Any])
        data["state"] = "lobby"
        data["players"] = []
        data["countdownEndsAt"] = NSNull()
        response["data"] = data
        return try JSONSerialization.data(withJSONObject: response)
    }
}
