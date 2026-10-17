import Foundation


/// Lobby/application state, separate from both local physics and SpriteKit render state.
public struct HouseRocketsOnlineLobbyState: Equatable, Sendable {
    public var connection: GameRealtimeConnectionState = .idle
    public var session: GameSessionDTO?
    public var game: HouseRocketsSnapshotDTO?
    public var controlGrant: HouseRocketsControlGrantDTO?
    public var result: HouseRocketsResultDTO?
    public var resultEventID: String?
    public var pendingCommand: HouseRocketsPendingLobbyCommand?
    public var issue: HouseRocketsOnlineLobbyIssue?
    public var isForeground = true
    public var isLandscape = false
    public var isSynced = false
    public var isLeaving = false
    public var serverClock: HouseRocketsServerClock?
    public var retryNotBefore: TimeInterval?
    public var runtimeSettings: HouseRocketsRuntimeSettingsDTO?
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

    public func validControl(playerID: String?) -> HouseRocketsControlGrantDTO? {
        guard connection == .connected, isSynced, isForeground, isLandscape,
              !isLeaving, !isTerminal, !controlTransferred, session?.state == .running,
              let game, game.phase == .playing, let grant = controlGrant,
              grant.sessionId == game.sessionId, grant.sessionId == session?.sessionId,
              grant.playerId == playerID, grant.runtimeEpoch == game.runtimeEpoch,
              !grant.controlGeneration.isEmpty,
              let player = game.players.first(where: { $0.playerId == playerID }),
              player.isAlive, player.connected, player.controlGeneration == grant.controlGeneration else { return nil }
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

    public func canCancel(context: HouseRocketsLaunchContext) -> Bool {
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

public struct HouseRocketsPendingLobbyCommand: Equatable, Sendable {
    public let message: GameRealtimeClientMessage
    public let sessionVersion: Int64
    public let issuedAt: TimeInterval
    public var lastSentAt: TimeInterval
    public var attempts = 0
    public var accepted = false
    public var requestedSync = false

    public init(message: GameRealtimeClientMessage, sessionVersion: Int64, issuedAt: TimeInterval, lastSentAt: TimeInterval) {
        self.message = message
        self.sessionVersion = sessionVersion
        self.issuedAt = issuedAt
        self.lastSentAt = lastSentAt
    }
}

public enum HouseRocketsOnlineLobbyIssue: Equatable, Sendable {
    case connection(GameRealtimeSessionFailure)
    case rejected(GameRealtimeRejection)
    case timeout
    case commandTimeout
}

public struct HouseRocketsServerClock: Equatable, Sendable {
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

