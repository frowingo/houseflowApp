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
    /// The room is portrait; the screen turns to landscape when the countdown starts.
    public static let readyRequiresLandscape = false

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
        guard snapshot.tick >= 0, snapshot.runners.count <= 8,
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

    /// A robot that finished or crashed never runs again.
    public static func isValidSuccessor(_ next: FausSwitchSnapshotDTO, of current: FausSwitchSnapshotDTO) -> Bool {
        let done = Set(current.runners.filter { $0.status != .running }.map(\.playerId))
        return !next.runners.contains { $0.status == .running && done.contains($0.playerId) }
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
