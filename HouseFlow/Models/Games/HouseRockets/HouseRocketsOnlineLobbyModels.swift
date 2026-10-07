import Foundation

/// Lobby/application state, separate from both local physics and SpriteKit render state.
struct HouseRocketsOnlineLobbyState: Equatable, Sendable {
    var connection: GameRealtimeConnectionState = .idle
    var session: GameSessionDTO?
    var game: HouseRocketsSnapshotDTO?
    var controlGrant: HouseRocketsControlGrantDTO?
    var result: HouseRocketsResultDTO?
    var resultEventID: String?
    var pendingCommand: HouseRocketsPendingLobbyCommand?
    var issue: HouseRocketsOnlineLobbyIssue?
    var isForeground = true
    var isLandscape = false
    var isSynced = false
    var isLeaving = false
    var serverClock: HouseRocketsServerClock?
    var retryNotBefore: TimeInterval?
    var runtimeSettings: HouseRocketsRuntimeSettingsDTO?
    var gameReceivedUptime: TimeInterval?
    var connectionGeneration: UUID?
    var reconnectAttempt = 0
    var controlTransferred = false
    var terminalConflict = false

    var participants: [GameSessionPlayerDTO] { session?.players.filter { $0.state != .left } ?? [] }
    var readyCount: Int { participants.filter { $0.state == .ready }.count }
    var isLobby: Bool { game == nil && (session?.state == .lobby || session?.state == .readyWindow) }
    var isTerminal: Bool {
        terminalConflict || session?.state == .finished || session?.state == .cancelled || result != nil
            || game?.phase == .ended || game?.phase == .cancelled
    }

    func localPlayer(_ id: String?) -> GameSessionPlayerDTO? {
        participants.first { $0.playerId == id }
    }

    func canChangeReady(playerID: String?) -> Bool {
        guard connection == .connected, isSynced, isForeground, isLobby,
              pendingCommand == nil, !isLeaving, let player = localPlayer(playerID) else { return false }
        return player.state == .waiting || player.state == .ready
    }

    func validControl(playerID: String?) -> HouseRocketsControlGrantDTO? {
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

    func canReconnect(at uptime: TimeInterval) -> Bool {
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

    var requiresAuthentication: Bool {
        if case .connection(.http(401, _)) = issue { return true }
        if case .connection(.protocolFailure(.authenticationRequired)) = issue { return true }
        return false
    }

    func canCancel(context: HouseRocketsLaunchContext) -> Bool {
        guard connection == .connected, isSynced, isForeground, !isTerminal,
              game?.phase != .finalizing, pendingCommand == nil, !isLeaving,
              let session, let playerID = context.localPlayerID else { return false }
        return session.createdBy == playerID || context.houseOwnerID == playerID
    }

    /// Reaching zero never changes the authoritative session/game phase.
    func remainingSeconds(until deadline: Date?, uptime: TimeInterval) -> Int? {
        guard let deadline, let serverClock else { return nil }
        return max(0, Int(ceil(deadline.timeIntervalSince(serverClock.time(at: uptime)))))
    }
}

struct HouseRocketsPendingLobbyCommand: Equatable, Sendable {
    let message: GameRealtimeClientMessage
    let sessionVersion: Int64
    let issuedAt: TimeInterval
    var lastSentAt: TimeInterval
    var attempts = 0
    var accepted = false
    var requestedSync = false
}

enum HouseRocketsOnlineLobbyIssue: Equatable, Sendable {
    case connection(GameRealtimeSessionFailure)
    case rejected(GameRealtimeRejection)
    case timeout
    case commandTimeout
}

struct HouseRocketsServerClock: Equatable, Sendable {
    let serverTime: Date
    let localUptime: TimeInterval

    func time(at uptime: TimeInterval) -> Date {
        serverTime.addingTimeInterval(max(0, uptime - localUptime))
    }
}
