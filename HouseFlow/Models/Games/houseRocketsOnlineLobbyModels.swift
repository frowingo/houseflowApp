import Foundation

/// Lobby/application state, separate from both local physics and SpriteKit render state.
struct HouseRocketsOnlineLobbyState: Equatable, Sendable {
    var connection: GameRealtimeConnectionState = .idle
    var session: GameSessionDTO?
    var game: HouseRocketsSnapshotDTO?
    var controlGrant: HouseRocketsControlGrantDTO?
    var result: HouseRocketsResultDTO?
    var pendingCommand: HouseRocketsPendingLobbyCommand?
    var issue: HouseRocketsOnlineLobbyIssue?
    var isForeground = true
    var isLandscape = false
    var isSynced = false
    var isLeaving = false
    var serverClock: HouseRocketsServerClock?
    var retryNotBefore: TimeInterval?

    var participants: [GameSessionPlayerDTO] { session?.players.filter { $0.state != .left } ?? [] }
    var readyCount: Int { participants.filter { $0.state == .ready }.count }
    var isLobby: Bool { game == nil && (session?.state == .lobby || session?.state == .readyWindow) }
    var isTerminal: Bool {
        session?.state == .finished || session?.state == .cancelled || result != nil
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

    func canReconnect(at uptime: TimeInterval) -> Bool {
        guard connection == .failed, uptime >= (retryNotBefore ?? 0) else { return false }
        if case .connection(.http(let status, _)) = issue { return ![401, 403, 409].contains(status) }
        if case .connection(.protocolFailure(.unsupportedProtocol)) = issue { return false }
        if case .connection(.protocolFailure(.unsupportedCourse)) = issue { return false }
        return true
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
