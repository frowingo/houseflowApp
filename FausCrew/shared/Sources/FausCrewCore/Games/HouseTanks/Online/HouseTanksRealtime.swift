import Foundation

/// FauseTanks on the shared realtime protocol (contract houseTanks.v2): one
/// button (`press`), a vote between rounds (`roundReady`) and `resync`.
public enum HouseTanksRealtime: GameRealtimeGame {
    public enum Intent: Equatable, Sendable {
        /// The single button pressed (`true`) or released. `clientTick` and
        /// `heading` are the world tick and barrel angle shown on screen when the
        /// player pressed; the server uses them for lag compensation only.
        case press(controlGeneration: String, inputSequence: Int64, pressed: Bool, clientTick: Int64, heading: Double)
        /// A vote in `roundReady`.
        case roundReady(controlGeneration: String, ready: Bool)
    }

    public static let gameKey = GameKey.houseTanks
    public static let readyRequiresLandscape = false

    /// A different contract or catalog means this build cannot draw the server's
    /// world; so does a frozen physics rate, arena or round rule it does not run.
    public static func checkCompatibility(_ welcome: HouseTanksWelcomeDTO) throws {
        try checkGame(welcome.gameKey, protocolVersion: welcome.protocolVersion)
        let settings = welcome.settings
        guard welcome.contractRevision == HouseTanksMapCatalog.contractRevision,
              welcome.mapCatalogVersion == HouseTanksMapCatalog.catalogVersion,
              settings.physicsRateHz == HouseTanksWorld.physicsRate,
              settings.arenaWidth == HouseTanksWorld.arenaSize.width,
              settings.arenaHeight == HouseTanksWorld.arenaSize.height,
              settings.armorPerRound == HouseTanksWorld.armorPerRound,
              settings.roundWinsNeeded == HouseTanksMatchRules.roundWinsNeeded else {
            throw GameRealtimeError.unsupportedContract(welcome.contractRevision)
        }
    }

    public static func checkCompatibility(_ snapshot: HouseTanksSnapshotDTO) throws {
        guard snapshot.gameKey == gameKey else { throw GameRealtimeError.invalidResponse }
        guard snapshot.map != nil else { throw GameRealtimeError.unsupportedMap(snapshot.mapId, snapshot.mapVersion) }
    }

    public static func checkCompatibility(_ result: HouseTanksResultDTO) throws {
        try checkGame(result.gameKey, protocolVersion: result.protocolVersion)
    }

    public static func type(of intent: Intent) -> String {
        switch intent {
        case .press: return "houseTanks.press"
        case .roundReady: return "houseTanks.roundReady"
        }
    }

    /// The server rejects an empty or padded generation, a sequence below 1, a
    /// negative tick and a non-finite heading; none of them is ever encoded.
    public static func payload(of intent: Intent) throws -> any Encodable {
        switch intent {
        case .press(let generation, let sequence, let pressed, let clientTick, let heading):
            try GameRealtimeCodec.validateIdentifier(generation)
            guard sequence > 0, clientTick >= 0, heading.isFinite else { throw GameRealtimeError.invalidInput }
            return Press(controlGeneration: generation, inputSequence: sequence, pressed: pressed,
                         clientTick: clientTick, heading: heading)
        case .roundReady(let generation, let ready):
            try GameRealtimeCodec.validateIdentifier(generation)
            return RoundReady(controlGeneration: generation, ready: ready)
        }
    }

    public static func controlGeneration(of intent: Intent) -> String? {
        switch intent {
        case .press(let generation, _, _, _, _), .roundReady(let generation, _): return generation
        }
    }

    /// A player who left never returns; a dead tank comes back every round.
    public static func isValidSuccessor(_ next: HouseTanksSnapshotDTO, of current: HouseTanksSnapshotDTO) -> Bool {
        let left = Set(current.players.filter(\.hasLeft).map(\.playerId))
        return !next.players.contains { !$0.hasLeft && left.contains($0.playerId) }
    }

    public static func identities(in snapshot: HouseTanksSnapshotDTO) -> [String: HouseTanksResultPlayerIdentity] {
        var identities: [String: HouseTanksResultPlayerIdentity] = [:]
        for player in snapshot.players where identities[player.playerId] == nil {
            identities[player.playerId] = .init(displayName: player.displayName, color: player.color)
        }
        return identities
    }

    private static func checkGame(_ key: String, protocolVersion: Int) throws {
        guard protocolVersion == GameRoute.realtimeProtocolVersion else {
            throw GameRealtimeError.unsupportedProtocol(protocolVersion)
        }
        guard key == gameKey else { throw GameRealtimeError.invalidResponse }
    }

    private struct Press: Encodable {
        let controlGeneration: String
        let inputSequence: Int64
        let pressed: Bool
        let clientTick: Int64
        let heading: Double
    }

    private struct RoundReady: Encodable {
        let controlGeneration: String
        let ready: Bool
    }
}

public struct HouseTanksResultPlayerIdentity: Equatable, Sendable {
    public let displayName: String
    public let color: HouseTanksColor

    public init(displayName: String, color: HouseTanksColor) {
        self.displayName = displayName
        self.color = color
    }
}

extension HouseTanksRuntimeSettingsDTO: GameRealtimeSettings {}
extension HouseTanksWelcomeDTO: GameRealtimeWelcome {}
extension HouseTanksResultDTO: GameRealtimeResult {}

extension HouseTanksSnapshotDTO: GameRealtimeSnapshot {
    public var isBeforeStart: Bool { phase == .countdown || roundNumber == 0 }

    /// A tank whose round ended still holds control: its player votes.
    public func controlSeat(of playerID: String) -> GameRealtimeControlSeat? {
        players.first { $0.playerId == playerID }.map {
            .init(controlGeneration: $0.controlGeneration, canHoldControl: !$0.hasLeft, connected: $0.connected)
        }
    }
}

public typealias HouseTanksOnlineLobbyState = GameOnlineLobbyState<HouseTanksRealtime>
public typealias HouseTanksOnlineResultState = GameOnlineResultState<HouseTanksRealtime>
public typealias HouseTanksClientMessage = GameRealtimeClientMessageOf<HouseTanksRealtime>
public typealias HouseTanksServerMessage = GameRealtimeServerMessageOf<HouseTanksRealtime>
typealias HouseTanksOnlineLobbyMachine = GameOnlineLobbyMachine<HouseTanksRealtime>
typealias HouseTanksOnlineResultMachine = GameOnlineResultMachine<HouseTanksRealtime>
