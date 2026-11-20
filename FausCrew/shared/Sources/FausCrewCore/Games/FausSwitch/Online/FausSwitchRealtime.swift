import Foundation

/// Faus Switch on the shared realtime protocol (contract fausSwitch.v1): a flip at the
/// tick the player saw, a robot color asked for in the lobby, and `resync`.
public enum FausSwitchRealtime: GameRealtimeGame {
    public enum Intent: Equatable, Sendable {
        /// A tap while holding control. `clientTick` is the world tick on screen; the
        /// server applies the flip there when it is within its rewind window.
        case flip(controlGeneration: String, inputSequence: Int64, clientTick: Int64)
        /// Lobby only: the color this player asks for. The server keeps the first claim
        /// per color and gives the rest the first free color by seat order.
        case selectColor(FausSwitchColor)
    }

    public static let gameKey = GameKey.fausSwitch

    // Overflow safety, not a match-duration rule: 30 days at 120 Hz leaves ample
    // Int/Int64 headroom for tick differences, prediction and effect expiry.
    static let maximumSnapshotTick: Int64 = 30 * 24 * 60 * 60 * 120

    public static func checkCompatibility(_ welcome: FausSwitchWelcomeDTO) throws {
        try checkGame(welcome.gameKey, protocolVersion: welcome.protocolVersion, courseVersion: welcome.courseVersion)
        guard welcome.settings.physicsRateHz == FausSwitchMetrics.physicsRate else {
            throw GameRealtimeError.unsupportedContract("physicsRateHz=\(welcome.settings.physicsRateHz)")
        }
    }

    public static func checkCompatibility(_ snapshot: FausSwitchSnapshotDTO) throws {
        guard snapshot.gameKey == gameKey else { throw GameRealtimeError.invalidResponse }
        guard snapshot.courseVersion == FausSwitchCourse.currentVersion else {
            throw GameRealtimeError.unsupportedCourse(snapshot.courseVersion)
        }
        guard (0...maximumSnapshotTick).contains(snapshot.tick),
              snapshot.elapsedSeconds.isFinite,
              snapshot.runners.count <= FausSwitchStartGrid.maximumRunners,
              snapshot.runnerScale == 1 || snapshot.runnerScale == FausSwitchStartGrid.crowdedRobotScale,
              Set(snapshot.runners.map(\.playerId)).count == snapshot.runners.count,
              snapshot.runners.allSatisfy(\.isValid) else { throw GameRealtimeError.invalidResponse }
    }

    public static func checkCompatibility(_ result: FausSwitchResultDTO) throws {
        try checkGame(result.gameKey, protocolVersion: result.protocolVersion, courseVersion: result.courseVersion)
    }

    public static func type(of intent: Intent) -> String {
        switch intent {
        case .flip: return "fausSwitch.flip"
        case .selectColor: return "fausSwitch.selectColor"
        }
    }

    public static func payload(of intent: Intent) throws -> any Encodable {
        switch intent {
        case .flip(let generation, let sequence, let clientTick):
            try GameRealtimeCodec.validateIdentifier(generation)
            guard sequence > 0, clientTick >= 0 else { throw GameRealtimeError.invalidInput }
            return Flip(controlGeneration: generation, inputSequence: sequence, clientTick: clientTick)
        case .selectColor(let color):
            return SelectColor(color: color.rawValue)
        }
    }

    public static func controlGeneration(of intent: Intent) -> String? {
        switch intent {
        case .flip(let generation, _, _): return generation
        case .selectColor: return nil
        }
    }

    /// A robot that stopped runs again only when a late flip rewound the world to before
    /// its end: within the rewind window of the next snapshot (ADR-031). Any other return
    /// to the race is a broken stream. `settings` are the welcome's; the release defaults
    /// stand in before one arrives (nil).
    public static func isValidSuccessor(_ next: FausSwitchSnapshotDTO, of current: FausSwitchSnapshotDTO,
                                        settings: FausSwitchRuntimeSettingsDTO?) -> Bool {
        let ends = Dictionary(current.runners.compactMap { runner -> (String, Int64)? in
            switch runner.status {
            case .running: return nil
            case .finished: return runner.finishedAtTick.map { (runner.playerId, $0) }
            case .crashed: return runner.eliminatedAtTick.map { (runner.playerId, $0) }
            }
        }, uniquingKeysWith: { first, _ in first })
        return !next.runners.contains { runner in
            guard runner.status == .running, let end = ends[runner.playerId] else { return false }
            return next.tick - end > (settings ?? .releaseDefaults).flipClipTicks
        }
    }

    public static func isValidSuccessor(_ next: FausSwitchSnapshotDTO, of current: FausSwitchSnapshotDTO) -> Bool {
        isValidSuccessor(next, of: current, settings: nil)
    }

    public static func identities(in snapshot: FausSwitchSnapshotDTO) -> [String: FausSwitchResultPlayerIdentity] {
        var identities: [String: FausSwitchResultPlayerIdentity] = [:]
        for runner in snapshot.runners where identities[runner.playerId] == nil {
            identities[runner.playerId] = .init(displayName: runner.displayName, color: runner.color)
        }
        return identities
    }

    private static func checkGame(_ key: String, protocolVersion: Int, courseVersion: Int) throws {
        guard protocolVersion == GameRoute.realtimeProtocolVersion else {
            throw GameRealtimeError.unsupportedProtocol(protocolVersion)
        }
        guard key == gameKey else { throw GameRealtimeError.invalidResponse }
        guard courseVersion == FausSwitchCourse.currentVersion else { throw GameRealtimeError.unsupportedCourse(courseVersion) }
    }

    private struct Flip: Encodable {
        let controlGeneration: String
        let inputSequence: Int64
        let clientTick: Int64
    }

    private struct SelectColor: Encodable {
        let color: String
    }
}

extension FausSwitchRuntimeSettingsDTO {
    /// How far back the server rewinds the world for a late flip (`maximumRewindMilliseconds`).
    var maximumRewindTicks: Int64 { Self.ticks(milliseconds: maximumRewindMilliseconds) }

    /// A snapshot leaves the server at most this many ticks after the step it shows.
    var snapshotTicks: Int64 { Int64((Double(FausSwitchMetrics.physicsRate) / Double(max(1, snapshotRateHz))).rounded(.up)) }

    /// A flip older than this when the snapshot that confirms it arrives was clipped by the
    /// rewind window; it is also how long after its end a stopped robot may still return.
    var flipClipTicks: Int64 { maximumRewindTicks + snapshotTicks }

    private static func ticks(milliseconds: Int64) -> Int64 {
        Int64((Double(milliseconds) * Double(FausSwitchMetrics.physicsRate) / 1_000).rounded(.up))
    }
}

public struct FausSwitchResultPlayerIdentity: Equatable, Sendable {
    public let displayName: String
    public let color: FausSwitchColor

    public init(displayName: String, color: FausSwitchColor) {
        self.displayName = displayName
        self.color = color
    }
}

extension FausSwitchRuntimeSettingsDTO: GameRealtimeSettings {}
extension FausSwitchWelcomeDTO: GameRealtimeWelcome {}
extension FausSwitchResultDTO: GameRealtimeResult {}

extension FausSwitchSnapshotDTO: GameRealtimeSnapshot {
    public var isBeforeStart: Bool { phase == .countdown || tick == 0 }

    public func controlSeat(of playerID: String) -> GameRealtimeControlSeat? {
        runners.first { $0.playerId == playerID }.map {
            .init(controlGeneration: $0.controlGeneration, canHoldControl: $0.status == .running, connected: $0.connected)
        }
    }
}

public typealias FausSwitchOnlineLobbyState = GameOnlineLobbyState<FausSwitchRealtime>
public typealias FausSwitchOnlineResultState = GameOnlineResultState<FausSwitchRealtime>
public typealias FausSwitchClientMessage = GameRealtimeClientMessageOf<FausSwitchRealtime>
public typealias FausSwitchServerMessage = GameRealtimeServerMessageOf<FausSwitchRealtime>
typealias FausSwitchOnlineLobbyMachine = GameOnlineLobbyMachine<FausSwitchRealtime>
typealias FausSwitchOnlineResultMachine = GameOnlineResultMachine<FausSwitchRealtime>
