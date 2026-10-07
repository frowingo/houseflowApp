import Foundation

enum GameRealtimeConnectionState: Equatable, Sendable {
    case idle, connecting, reconnecting, syncing, connected, failed
}

enum GameRealtimeSessionFailure: Equatable, Sendable {
    case http(statusCode: Int, retryAfterSeconds: TimeInterval?)
    case protocolFailure(GameRealtimeError)
    case invalidPayload
    case transport
}

struct HouseRocketsOnlineEvent: Sendable {
    enum Payload: Sendable {
        case connection(GameRealtimeConnectionState)
        case message(GameRealtimeReceivedMessage)
        case failure(GameRealtimeSessionFailure)
    }
    let generation: UUID
    let payload: Payload
}

/// Owns the pinned match's wire streams and socket lifetime, including temporary reconnect.
/// Lobby and flight services own lifecycle commands, control gating and presentation timing.
@MainActor
final class OnlineHouseRocketsSession {
    private let sessions: any GameSessionServicing
    private let transport: any GameRealtimeTransporting
    private let clock: GameRealtimeClock
    private var receiveTask: Task<Void, Never>?
    private var isClosed = false
    private(set) var generation = UUID()
    private(set) var context: HouseRocketsLaunchContext?
    private(set) var session: GameSessionDTO?

    private let eventStream: AsyncThrowingStream<HouseRocketsOnlineEvent, Error>
    private let eventContinuation: AsyncThrowingStream<HouseRocketsOnlineEvent, Error>.Continuation
    private let snapshotStream: AsyncStream<GameRealtimeReceivedMessage>
    private let snapshotContinuation: AsyncStream<GameRealtimeReceivedMessage>.Continuation

    init(sessions: any GameSessionServicing, transport: any GameRealtimeTransporting,
         clock: GameRealtimeClock? = nil, criticalEventCapacity: Int = 64) {
        self.sessions = sessions
        self.transport = transport
        self.clock = clock ?? .live
        let events = AsyncThrowingStream<HouseRocketsOnlineEvent, Error>.makeStream(
            bufferingPolicy: .bufferingOldest(max(1, criticalEventCapacity)))
        eventStream = events.stream
        eventContinuation = events.continuation
        let snapshots = AsyncStream<GameRealtimeReceivedMessage>.makeStream(bufferingPolicy: .bufferingNewest(1))
        snapshotStream = snapshots.stream
        snapshotContinuation = snapshots.continuation
        eventContinuation.onTermination = { [weak self] reason in
            guard case .cancelled = reason else { return }
            Task { @MainActor in self?.disconnect() }
        }
    }

    deinit {
        receiveTask?.cancel()
        eventContinuation.finish()
        snapshotContinuation.finish()
    }

    /// One observer consumes critical events; playing snapshots have their own latest-state stream.
    func events() -> AsyncThrowingStream<HouseRocketsOnlineEvent, Error> { eventStream }
    func snapshots() -> AsyncStream<GameRealtimeReceivedMessage> { snapshotStream }

    @discardableResult
    func connect(context: HouseRocketsLaunchContext, excludingSessionID: String? = nil) async throws -> GameSessionDTO {
        guard !isClosed, let houseID = context.houseID, let playerID = context.localPlayerID,
              !houseID.isEmpty, !playerID.isEmpty else { throw GameRealtimeError.invalidContext }
        try GameRealtimeCodec.validateIdentifier(houseID)
        try GameRealtimeCodec.validateIdentifier(playerID)
        stopConnection()
        self.context = context
        let expected = generation
        try emit(.connection(.connecting), generation: expected)
        do {
            let session = try await sessions.ensureHouseRocketsSession(houseID: houseID)
            try requireCurrent(expected)
            guard session.state != .finished, session.state != .cancelled,
                  session.sessionId != excludingSessionID else { throw GameRealtimeError.unexpectedSession }
            self.session = session // Pin the ID even if the upgrade fails.
            let request = try sessions.realtimeRequest(sessionID: session.sessionId)
            try await transport.connect(request: request)
            try requireCurrent(expected)
            self.session = session
            beginReceiving(generation: expected, sessionID: session.sessionId)
            return session
        } catch {
            guard generation == expected, !isClosed else { throw CancellationError() }
            transport.disconnect()
            try Task.checkCancellation()
            try emit(.failure(failure(from: error)), generation: expected)
            try emit(.connection(.failed), generation: expected)
            throw error
        }
    }

    /// Reopen the same match with the current token; never PUT or implicitly join.
    func reconnect() async throws {
        guard !isClosed, context != nil, let previous = session else { throw GameRealtimeError.invalidContext }
        suspendConnection()
        let expected = generation
        do {
            let request = try sessions.realtimeRequest(sessionID: previous.sessionId)
            try await transport.connect(request: request)
            try requireCurrent(expected)
            beginReceiving(generation: expected, sessionID: previous.sessionId)
        } catch {
            try requireCurrent(expected)
            transport.disconnect()
            throw error
        }
    }

    /// Temporary transport cleanup. Critical observers and the pinned match survive.
    func suspendConnection() {
        guard !isClosed else { return }
        let previous = session
        stopConnection()
        session = previous
    }

    func send(_ message: GameRealtimeClientMessage) async throws {
        guard !isClosed, session != nil else { throw GameRealtimeError.notConnected }
        let expected = generation
        do {
            try await transport.send(GameRealtimeCodec.encode(message))
            try requireCurrent(expected)
        } catch {
            try requireCurrent(expected)
            throw error
        }
    }

    func result(sessionID: String) async throws -> HouseRocketsResultDTO {
        guard !isClosed, let houseID = context?.houseID else { throw GameRealtimeError.invalidContext }
        let expected = generation
        do {
            let result = try await sessions.houseRocketsResult(sessionID: sessionID)
            try requireCurrent(expected)
            guard result.sessionId == sessionID, result.houseId == houseID else {
                throw GameRealtimeError.unexpectedSession
            }
            return result
        } catch {
            try requireCurrent(expected)
            throw error
        }
    }

    /// Captures HTTP dependencies and house scope, never the mutable socket context.
    /// The result coordinator owns cancellation and pins the old match ID.
    func resultReader(houseID: String) -> HouseRocketsOnlineResult.Reader {
        let sessions = self.sessions
        return { sessionID in
            try Task.checkCancellation()
            let result = try await sessions.houseRocketsResult(sessionID: sessionID)
            try Task.checkCancellation()
            try result.validate(sessionID: sessionID, houseID: houseID)
            return result
        }
    }

    /// Cleanup only. Explicit business leave remains a separate client command.
    func disconnect() {
        guard !isClosed else { return }
        isClosed = true
        stopConnection()
        context = nil
        eventContinuation.finish()
        snapshotContinuation.finish()
    }

    private func stopConnection() {
        generation = UUID()
        receiveTask?.cancel()
        receiveTask = nil
        transport.disconnect()
        session = nil
    }

    private func beginReceiving(generation expected: UUID, sessionID: String) {
        let transport = self.transport
        receiveTask = Task { [weak self] in
            do {
                while !Task.isCancelled {
                    let data = try await transport.receive()
                    guard let self else { return }
                    try self.requireCurrent(expected)
                    let message = try GameRealtimeCodec.decode(data)
                    try self.validateSession(message, expected: sessionID)
                    let received = GameRealtimeReceivedMessage(message: message,
                        receivedAt: self.clock.wallTime(), receivedUptime: self.clock.uptime(), generation: expected)
                    if case .snapshot(let snapshot) = message.payload, snapshot.phase == .playing,
                       message.messageId?.isEmpty != false {
                        self.snapshotContinuation.yield(received)
                    } else {
                        try self.emit(.message(received), generation: expected)
                    }
                    if case .welcome = message.payload {
                        try self.emit(.connection(.connected), generation: expected)
                    }
                }
            } catch {
                guard let self, !Task.isCancelled, self.generation == expected, !self.isClosed else { return }
                self.transport.disconnect()
                do {
                    try self.emit(.failure(self.failure(from: error)), generation: expected)
                    try self.emit(.connection(.failed), generation: expected)
                } catch {
                    self.disconnect()
                }
            }
        }
    }

    private func emit(_ payload: HouseRocketsOnlineEvent.Payload, generation: UUID) throws {
        let result = eventContinuation.yield(.init(generation: generation, payload: payload))
        if case .dropped = result {
            // Important events are never silently discarded under snapshot pressure.
            eventContinuation.finish(throwing: GameRealtimeError.slowConsumer)
            disconnect()
            throw GameRealtimeError.slowConsumer
        }
        if case .terminated = result { throw CancellationError() }
    }

    private func requireCurrent(_ expected: UUID) throws {
        try Task.checkCancellation()
        guard generation == expected, !isClosed else { throw CancellationError() }
    }

    private func validateSession(_ message: GameRealtimeServerMessage, expected: String) throws {
        let sessionID: String?
        switch message.payload {
        case .welcome(let value): sessionID = value.sessionId
        case .session(let value):
            guard value.houseId == context?.houseID else { throw GameRealtimeError.unexpectedSession }
            sessionID = value.sessionId
        case .controlGranted(let value):
            guard value.playerId == context?.localPlayerID else { throw GameRealtimeError.invalidContext }
            sessionID = value.sessionId
        case .snapshot(let value): sessionID = value.sessionId
        case .result(let value):
            guard value.houseId == context?.houseID else { throw GameRealtimeError.unexpectedSession }
            sessionID = value.sessionId
        case .accepted, .pong, .rejected: sessionID = nil
        }
        if let sessionID, sessionID != expected { throw GameRealtimeError.unexpectedSession }
    }

    private func failure(from error: Error) -> GameRealtimeSessionFailure {
        if error as? GameRealtimeError == .accessRevoked { return .http(statusCode: 403, retryAfterSeconds: nil) }
        if let error = error as? NetworkHTTPFailure {
            return .http(statusCode: error.statusCode, retryAfterSeconds: error.retryAfterSeconds(at: clock.wallTime()))
        }
        if let error = error as? GameRealtimeError { return .protocolFailure(error) }
        if error is DecodingError { return .invalidPayload }
        return .transport
    }
}
