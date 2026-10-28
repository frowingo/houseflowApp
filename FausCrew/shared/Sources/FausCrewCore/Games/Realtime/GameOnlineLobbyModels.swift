import Foundation

/// What an online engine asks its platform host to do. The host performs I/O only
/// and reports back; every rule, deadline and retry decision stays in the engine.
public enum GameOnlineEffect: Equatable, Sendable {
    /// `PUT /game/{gameKey}/session`; answer with `sessionResponse` or `connectionFailed`.
    case ensureSession(houseID: String, connection: Int)
    /// Open `GameRoute.realtime(sessionId:)` with the current token; answer with
    /// `socketOpened`, `received` and finally `connectionFailed`.
    case openSocket(sessionID: String, connection: Int)
    /// Close the current socket; events tagged with older connections are ignored.
    case closeSocket
    /// One JSON text frame on the socket opened for `connection`.
    case send(text: String, connection: Int)
    /// `GET /game/sessions/{id}/result`; answer with `resultResponse` or `resultFailed`.
    case fetchResult(sessionID: String, request: Int)
    case haptic(GameOnlineHaptic)
}

public enum GameOnlineHaptic: String, Equatable, Sendable {
    case success, warning
}

/// Captured at screen entry; local play does not require either identifier.
public struct GameLaunchContext: Equatable, Sendable {
    public let houseID: String?
    public let localPlayerID: String?
    public var houseOwnerID: String? = nil

    public init(houseID: String?, localPlayerID: String?, houseOwnerID: String? = nil) {
        self.houseID = houseID
        self.localPlayerID = localPlayerID
        self.houseOwnerID = houseOwnerID
    }
}

/// Retry classification and timing only. Never changes match/session authority.
public struct GameReconnectPolicy: Sendable {
    public var maximumAttempts = 5
    public var initialBudget: TimeInterval = 20
    public var jitter: @Sendable () -> Double = { Double.random(in: 0.8...1.2) }

    public init(maximumAttempts: Int = 5, initialBudget: TimeInterval = 20,
                jitter: @escaping @Sendable () -> Double = { Double.random(in: 0.8...1.2) }) {
        self.maximumAttempts = maximumAttempts
        self.initialBudget = initialBudget
        self.jitter = jitter
    }

    public func delay(attempt: Int, minimum: TimeInterval) -> TimeInterval {
        max(minimum, min(8, 0.5 * pow(2, Double(max(0, attempt - 1)))) * min(1.2, max(0.8, jitter())))
    }

    public static func automaticallyRetries(_ issue: GameOnlineLobbyIssue) -> Bool {
        switch issue {
        case .connection(.transport), .timeout: return true
        case .connection(.http(let status, _)): return [408, 429, 500, 502, 503, 504].contains(status)
        case .connection(.protocolFailure(.notConnected)): return true
        case .rejected(let error): return ["realtime.error.unavailable", "realtime.error.command_failed"].contains(error.code) && error.retryable
        default: return false
        }
    }
}

/// Lobby/application state, separate from both local physics and render state.
public struct GameOnlineLobbyState<Game: GameRealtimeGame>: Equatable, Sendable {
    public var connection: GameRealtimeConnectionState = .idle
    public var session: GameSessionDTO?
    public var game: Game.Snapshot?
    public var controlGrant: GameRealtimeControlGrantDTO?
    public var result: Game.Result?
    public var resultEventID: String?
    public var pendingCommand: GamePendingLobbyCommand<Game>?
    public var issue: GameOnlineLobbyIssue?
    public var isForeground = true
    public var isLandscape = false
    public var isSynced = false
    public var isLeaving = false
    public var serverClock: GameServerClock?
    public var retryNotBefore: TimeInterval?
    public var runtimeSettings: Game.Settings?
    public var gameReceivedUptime: TimeInterval?
    public var connectionGeneration: UUID?
    public var reconnectAttempt = 0
    public var controlTransferred = false
    public var terminalConflict = false

    public var participants: [GameSessionPlayerDTO] { session?.players.filter { $0.state != .left } ?? [] }
    public var readyCount: Int { participants.filter { $0.state == .ready }.count }
    public var isLobby: Bool { game == nil && (session?.state == .lobby || session?.state == .readyWindow) }
    public var isTerminal: Bool {
        terminalConflict || session?.state == .finished || session?.state == .cancelled || result != nil
            || game?.phase == .ended || game?.phase == .cancelled
    }

    public func localPlayer(_ id: String?) -> GameSessionPlayerDTO? {
        participants.first { $0.playerId == id }
    }

    public func canChangeReady(playerID: String?) -> Bool {
        guard connection == .connected, isSynced, isForeground, isLobby,
              pendingCommand == nil, !isLeaving, let player = localPlayer(playerID) else { return false }
        return player.state == .waiting || player.state == .ready
    }

    public func validControl(playerID: String?) -> GameRealtimeControlGrantDTO? {
        guard connection == .connected, isSynced, isForeground, isLandscape,
              !isLeaving, !isTerminal, !controlTransferred, session?.state == .running,
              let game, game.phase == .playing, let grant = controlGrant,
              grant.sessionId == game.sessionId, grant.sessionId == session?.sessionId,
              let playerID, grant.playerId == playerID, grant.runtimeEpoch == game.runtimeEpoch,
              !grant.controlGeneration.isEmpty,
              let seat = game.controlSeat(of: playerID),
              seat.canHoldControl, seat.connected, seat.controlGeneration == grant.controlGeneration else { return nil }
        return grant
    }

    public func canReconnect(at uptime: TimeInterval) -> Bool {
        guard !isTerminal, game?.phase != .finalizing,
              connection == .failed, uptime >= (retryNotBefore ?? 0) else { return false }
        if case .connection(.http(let status, _)) = issue { return ![401, 403, 409].contains(status) }
        if case .connection(.protocolFailure(.unsupportedProtocol)) = issue { return false }
        if case .connection(.protocolFailure(.unsupportedCourse)) = issue { return false }
        if case .connection(.protocolFailure(.authenticationRequired)) = issue { return false }
        if case .connection(.invalidPayload) = issue { return false }
        if case .connection(.protocolFailure(let error)) = issue, error != .notConnected { return false }
        return true
    }

    public var requiresAuthentication: Bool {
        if case .connection(.http(401, _)) = issue { return true }
        if case .connection(.protocolFailure(.authenticationRequired)) = issue { return true }
        return false
    }

    /// The server speaks a contract, version or map this client cannot play.
    public var requiresUpdate: Bool {
        guard case .connection(.protocolFailure(let error)) = issue else { return false }
        switch error {
        case .unsupportedProtocol, .unsupportedCourse, .unsupportedContract, .unsupportedMap: return true
        default: return false
        }
    }

    public func canCancel(context: GameLaunchContext) -> Bool {
        guard connection == .connected, isSynced, isForeground, !isTerminal,
              game?.phase != .finalizing, pendingCommand == nil, !isLeaving,
              let session, let playerID = context.localPlayerID else { return false }
        return session.createdBy == playerID || context.houseOwnerID == playerID
    }

    /// Reaching zero never changes the authoritative session/game phase.
    public func remainingSeconds(until deadline: Date?, uptime: TimeInterval) -> Int? {
        guard let deadline, let serverClock else { return nil }
        return max(0, Int(ceil(deadline.timeIntervalSince(serverClock.time(at: uptime)))))
    }

    public init() {}
}

public struct GamePendingLobbyCommand<Game: GameRealtimeGame>: Equatable, Sendable {
    public let message: GameRealtimeClientMessageOf<Game>
    public let sessionVersion: Int64
    public let issuedAt: TimeInterval
    public var lastSentAt: TimeInterval
    public var attempts = 0
    public var accepted = false
    public var requestedSync = false

    public init(message: GameRealtimeClientMessageOf<Game>, sessionVersion: Int64, issuedAt: TimeInterval, lastSentAt: TimeInterval) {
        self.message = message
        self.sessionVersion = sessionVersion
        self.issuedAt = issuedAt
        self.lastSentAt = lastSentAt
    }
}

public enum GameOnlineLobbyIssue: Equatable, Sendable {
    case connection(GameRealtimeSessionFailure)
    case rejected(GameRealtimeRejection)
    case timeout
    case commandTimeout
}

public struct GameServerClock: Equatable, Sendable {
    public let serverTime: Date
    public let localUptime: TimeInterval

    public func time(at uptime: TimeInterval) -> Date {
        serverTime.addingTimeInterval(max(0, uptime - localUptime))
    }

    public init(serverTime: Date, localUptime: TimeInterval) {
        self.serverTime = serverTime
        self.localUptime = localUptime
    }
}
