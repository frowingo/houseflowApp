import Foundation

// Wire DTOs of contract houseTanks.v2. Nullable fields must be present and are
// written back as null; event fields exist only for the kinds that use them and
// stay absent otherwise, so a payload re-encodes to the JSON it came from.

extension KeyedEncodingContainer {
    /// Writes `null` for nil instead of omitting the key.
    public mutating func encodeNullable<Value: Encodable>(_ value: Value?, forKey key: Key) throws {
        if let value { try encode(value, forKey: key) } else { try encodeNil(forKey: key) }
    }
}

public enum HouseTanksWireRoundPhase: String, Codable, Sendable {
    case roundCountdown, roundPlaying, roundReady, matchEnded
}

public enum HouseTanksWireEventKind: String, Codable, Sendable {
    case fired, hit, shielded, crateBroken, explosion, eliminated, jokerCollected, roundEnded
}

public enum HouseTanksResultStatus: String, Codable, Sendable {
    case completed, cancelled
}

public enum HouseTanksEndReason: String, Codable, Sendable {
    case championDecided, insufficientPlayers, cancelledByUser, sessionExpired
    case recoveryFailed, coordinationUnavailable, runtimeOverloaded
}

/// Settings frozen into a session. Network and presence limits may change on
/// the server without a deploy; physics, arena and match rules are contract
/// values that `HouseTanksRealtime` checks against this client's engine.
public struct HouseTanksRuntimeSettingsDTO: Codable, Equatable, Sendable {
    public let physicsRateHz: Int
    public let schedulingRateHz: Int
    public let snapshotRateHz: Int
    public let maximumInputRateHz: Int
    public let maximumPressMessagesPerSecond: Int
    public let controlHeartbeatMilliseconds: Int64
    public let controlTimeoutMilliseconds: Int64
    public let reconnectGraceMilliseconds: Int64
    public let lagCompensationMilliseconds: Int64
    public let headingToleranceMilliradians: Int64
    public let arenaWidth: Double
    public let arenaHeight: Double
    public let roundWinsNeeded: Int
    public let armorPerRound: Int
    public let roundCountdownMilliseconds: Int64
    public let roundReadyWindowMilliseconds: Int64
    public let roundReadyIdleMilliseconds: Int64
    public let maximumMatchMilliseconds: Int64
    public let eventWindowMilliseconds: Int64

    public init(physicsRateHz: Int, schedulingRateHz: Int, snapshotRateHz: Int, maximumInputRateHz: Int,
                maximumPressMessagesPerSecond: Int, controlHeartbeatMilliseconds: Int64,
                controlTimeoutMilliseconds: Int64, reconnectGraceMilliseconds: Int64,
                lagCompensationMilliseconds: Int64, headingToleranceMilliradians: Int64,
                arenaWidth: Double, arenaHeight: Double, roundWinsNeeded: Int, armorPerRound: Int,
                roundCountdownMilliseconds: Int64, roundReadyWindowMilliseconds: Int64,
                roundReadyIdleMilliseconds: Int64, maximumMatchMilliseconds: Int64, eventWindowMilliseconds: Int64) {
        self.physicsRateHz = physicsRateHz
        self.schedulingRateHz = schedulingRateHz
        self.snapshotRateHz = snapshotRateHz
        self.maximumInputRateHz = maximumInputRateHz
        self.maximumPressMessagesPerSecond = maximumPressMessagesPerSecond
        self.controlHeartbeatMilliseconds = controlHeartbeatMilliseconds
        self.controlTimeoutMilliseconds = controlTimeoutMilliseconds
        self.reconnectGraceMilliseconds = reconnectGraceMilliseconds
        self.lagCompensationMilliseconds = lagCompensationMilliseconds
        self.headingToleranceMilliradians = headingToleranceMilliradians
        self.arenaWidth = arenaWidth
        self.arenaHeight = arenaHeight
        self.roundWinsNeeded = roundWinsNeeded
        self.armorPerRound = armorPerRound
        self.roundCountdownMilliseconds = roundCountdownMilliseconds
        self.roundReadyWindowMilliseconds = roundReadyWindowMilliseconds
        self.roundReadyIdleMilliseconds = roundReadyIdleMilliseconds
        self.maximumMatchMilliseconds = maximumMatchMilliseconds
        self.eventWindowMilliseconds = eventWindowMilliseconds
    }

    /// The defaults of contract houseTanks.v2; used only before a welcome arrives.
    public static let releaseDefaults = HouseTanksRuntimeSettingsDTO(
        physicsRateHz: 120, schedulingRateHz: 60, snapshotRateHz: 20, maximumInputRateHz: 20,
        maximumPressMessagesPerSecond: 30, controlHeartbeatMilliseconds: 2_000,
        controlTimeoutMilliseconds: 6_000, reconnectGraceMilliseconds: 10_000,
        lagCompensationMilliseconds: 150, headingToleranceMilliradians: 35,
        arenaWidth: 872, arenaHeight: 400, roundWinsNeeded: 3, armorPerRound: 5,
        roundCountdownMilliseconds: 3_000, roundReadyWindowMilliseconds: 30_000,
        roundReadyIdleMilliseconds: 120_000, maximumMatchMilliseconds: 300_000, eventWindowMilliseconds: 1_000
    )

    public var heartbeatInterval: Double { Double(controlHeartbeatMilliseconds) / 1_000 }
    public var heartbeatTimeout: Double { Double(controlTimeoutMilliseconds) / 1_000 }
    public var reconnectGrace: Double { Double(reconnectGraceMilliseconds) / 1_000 }
    public var lagCompensationWindow: Double { Double(lagCompensationMilliseconds) / 1_000 }

    /// Rejects settings a client could not run safely (a ping storm, a timeout
    /// shorter than the ping, or a socket kept silent for minutes).
    public var isUsable: Bool {
        heartbeatInterval >= 0.25 && heartbeatTimeout > heartbeatInterval && heartbeatTimeout <= 60
            && snapshotRateHz >= 1 && maximumInputRateHz >= 1 && maximumPressMessagesPerSecond >= 1
            && reconnectGraceMilliseconds >= 0 && eventWindowMilliseconds > 0
    }

    /// Press cadence ceiling: never above either server limit, at least 1 Hz.
    public func pressRate(preferredHz: Double) -> Double {
        max(1, min(preferredHz, Double(min(maximumInputRateHz, maximumPressMessagesPerSecond))))
    }
}

public struct HouseTanksWelcomeDTO: Codable, Equatable, Sendable {
    public let sessionId: String
    public let gameKey: String
    public let connectionId: String
    public let protocolVersion: Int
    public let contractRevision: String
    public let mapCatalogVersion: Int
    public let settings: HouseTanksRuntimeSettingsDTO

    public init(sessionId: String, gameKey: String, connectionId: String, protocolVersion: Int,
                contractRevision: String, mapCatalogVersion: Int, settings: HouseTanksRuntimeSettingsDTO) {
        self.sessionId = sessionId
        self.gameKey = gameKey
        self.connectionId = connectionId
        self.protocolVersion = protocolVersion
        self.contractRevision = contractRevision
        self.mapCatalogVersion = mapCatalogVersion
        self.settings = settings
    }
}

/// A seat of the match. `isAlive` is the tank in the current round; `hasLeft`
/// never returns, while `connected == false` alone may still reconnect.
public struct HouseTanksPlayerDTO: Codable, Equatable, Sendable {
    public let playerId: String
    public let displayName: String
    public let seat: Int
    public let color: HouseTanksColor
    public let armor: Int
    public let roundsWon: Int
    public let isAlive: Bool
    public let connected: Bool
    public let hasLeft: Bool
    public let roundReady: Bool
    public let powerUp: HouseTanksPowerUp?
    public let powerUpExpiresAtTick: Int64?
    public let lastProcessedInputSequence: Int64
    /// Set only on the watching connection's own player while it holds control.
    public let controlGeneration: String?

    private enum CodingKeys: String, CodingKey {
        case playerId, displayName, seat, color, armor, roundsWon, isAlive, connected, hasLeft, roundReady
        case powerUp, powerUpExpiresAtTick, lastProcessedInputSequence, controlGeneration
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        playerId = try values.decode(String.self, forKey: .playerId)
        displayName = try values.decode(String.self, forKey: .displayName)
        seat = try values.decode(Int.self, forKey: .seat)
        color = try values.decode(HouseTanksColor.self, forKey: .color)
        armor = try values.decode(Int.self, forKey: .armor)
        roundsWon = try values.decode(Int.self, forKey: .roundsWon)
        isAlive = try values.decode(Bool.self, forKey: .isAlive)
        connected = try values.decode(Bool.self, forKey: .connected)
        hasLeft = try values.decode(Bool.self, forKey: .hasLeft)
        roundReady = try values.decode(Bool.self, forKey: .roundReady)
        powerUp = try values.decodeRequiredNullable(HouseTanksPowerUp.self, forKey: .powerUp)
        powerUpExpiresAtTick = try values.decodeRequiredNullable(Int64.self, forKey: .powerUpExpiresAtTick)
        lastProcessedInputSequence = try values.decode(Int64.self, forKey: .lastProcessedInputSequence)
        controlGeneration = try values.decodeRequiredNullable(String.self, forKey: .controlGeneration)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(playerId, forKey: .playerId)
        try values.encode(displayName, forKey: .displayName)
        try values.encode(seat, forKey: .seat)
        try values.encode(color, forKey: .color)
        try values.encode(armor, forKey: .armor)
        try values.encode(roundsWon, forKey: .roundsWon)
        try values.encode(isAlive, forKey: .isAlive)
        try values.encode(connected, forKey: .connected)
        try values.encode(hasLeft, forKey: .hasLeft)
        try values.encode(roundReady, forKey: .roundReady)
        try values.encodeNullable(powerUp, forKey: .powerUp)
        try values.encodeNullable(powerUpExpiresAtTick, forKey: .powerUpExpiresAtTick)
        try values.encode(lastProcessedInputSequence, forKey: .lastProcessedInputSequence)
        try values.encodeNullable(controlGeneration, forKey: .controlGeneration)
    }
}

/// A tank body; a dead tank stays as a wreck. `controllable == false` is a
/// stationary target whose player has no control.
public struct HouseTanksTankDTO: Codable, Equatable, Sendable {
    public let playerId: String
    public let x: Double
    public let y: Double
    public let vx: Double
    public let vy: Double
    public let rotation: Double
    public let rotationDirection: Int
    public let isDriving: Bool
    public let aimLocks: Int
    public let controllable: Bool
}

/// A pushable crate; `index` is its obstacle index in the map definition.
public struct HouseTanksCrateDTO: Codable, Equatable, Sendable {
    public let index: Int
    public let x: Double
    public let y: Double
    public let destroyed: Bool
}

public struct HouseTanksTokenDTO: Codable, Equatable, Sendable {
    public let kind: HouseTanksPowerUp
    public let x: Double
    public let y: Double
    public let expiresAtTick: Int64
}

/// A live shell or rocket; clients extrapolate it along its velocity.
public struct HouseTanksProjectileDTO: Codable, Equatable, Sendable {
    public let id: Int64
    public let ownerId: String
    public let x: Double
    public let y: Double
    public let vx: Double
    public let vy: Double
    public let rocket: Bool
    public let spawnTick: Int64
}

/// One effect of the last event window, repeated in every snapshot of that
/// window; `(runtimeEpoch, sequence)` identifies it.
public struct HouseTanksEventDTO: Codable, Equatable, Sendable {
    public let sequence: Int64
    public let tick: Int64
    public let kind: HouseTanksWireEventKind
    public let playerId: String?
    public let sourceId: String?
    public let x: Double?
    public let y: Double?
    public let angle: Double?
    public let armor: Int?
    public let lethal: Bool?
    public let crateIndex: Int?
    public let powerUp: HouseTanksPowerUp?
    public let roundNumber: Int?
    public let winnerId: String?
}

/// `houseTanks.snapshot`: the public state of a match.
public struct HouseTanksSnapshotDTO: Codable, Equatable, Sendable {
    public let sessionId: String
    public let gameKey: String
    public let runtimeEpoch: Int64
    public let stateSequence: Int64
    public let tick: Int64
    public let phase: GameRuntimePhase
    /// Kept as text: an unknown map asks for an update instead of failing the decode.
    public let mapId: String
    public let mapVersion: Int
    public let seed: String
    /// Null only in the lobby countdown preview.
    public let roundPhase: HouseTanksWireRoundPhase?
    public let roundNumber: Int
    public let countdownEndsAt: Date?
    public let roundCountdownEndsAt: Date?
    public let roundReadyWindowEndsAt: Date?
    public let players: [HouseTanksPlayerDTO]
    public let tanks: [HouseTanksTankDTO]
    public let crates: [HouseTanksCrateDTO]
    public let token: HouseTanksTokenDTO?
    public let projectiles: [HouseTanksProjectileDTO]
    public let events: [HouseTanksEventDTO]
    public let roundWinnerId: String?
    /// Only after the result is committed (`phase == .ended`).
    public let championId: String?

    private enum CodingKeys: String, CodingKey {
        case sessionId, gameKey, runtimeEpoch, stateSequence, tick, phase, mapId, mapVersion, seed
        case roundPhase, roundNumber, countdownEndsAt, roundCountdownEndsAt, roundReadyWindowEndsAt
        case players, tanks, crates, token, projectiles, events, roundWinnerId, championId
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try values.decode(String.self, forKey: .sessionId)
        gameKey = try values.decode(String.self, forKey: .gameKey)
        runtimeEpoch = try values.decode(Int64.self, forKey: .runtimeEpoch)
        stateSequence = try values.decode(Int64.self, forKey: .stateSequence)
        tick = try values.decode(Int64.self, forKey: .tick)
        phase = try values.decode(GameRuntimePhase.self, forKey: .phase)
        mapId = try values.decode(String.self, forKey: .mapId)
        mapVersion = try values.decode(Int.self, forKey: .mapVersion)
        seed = try values.decode(String.self, forKey: .seed)
        roundPhase = try values.decodeRequiredNullable(HouseTanksWireRoundPhase.self, forKey: .roundPhase)
        roundNumber = try values.decode(Int.self, forKey: .roundNumber)
        countdownEndsAt = try values.decodeRequiredNullable(Date.self, forKey: .countdownEndsAt)
        roundCountdownEndsAt = try values.decodeRequiredNullable(Date.self, forKey: .roundCountdownEndsAt)
        roundReadyWindowEndsAt = try values.decodeRequiredNullable(Date.self, forKey: .roundReadyWindowEndsAt)
        players = try values.decode([HouseTanksPlayerDTO].self, forKey: .players)
        tanks = try values.decode([HouseTanksTankDTO].self, forKey: .tanks)
        crates = try values.decode([HouseTanksCrateDTO].self, forKey: .crates)
        token = try values.decodeRequiredNullable(HouseTanksTokenDTO.self, forKey: .token)
        projectiles = try values.decode([HouseTanksProjectileDTO].self, forKey: .projectiles)
        events = try values.decode([HouseTanksEventDTO].self, forKey: .events)
        roundWinnerId = try values.decodeRequiredNullable(String.self, forKey: .roundWinnerId)
        championId = try values.decodeRequiredNullable(String.self, forKey: .championId)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(sessionId, forKey: .sessionId)
        try values.encode(gameKey, forKey: .gameKey)
        try values.encode(runtimeEpoch, forKey: .runtimeEpoch)
        try values.encode(stateSequence, forKey: .stateSequence)
        try values.encode(tick, forKey: .tick)
        try values.encode(phase, forKey: .phase)
        try values.encode(mapId, forKey: .mapId)
        try values.encode(mapVersion, forKey: .mapVersion)
        try values.encode(seed, forKey: .seed)
        try values.encodeNullable(roundPhase, forKey: .roundPhase)
        try values.encode(roundNumber, forKey: .roundNumber)
        try values.encodeNullable(countdownEndsAt, forKey: .countdownEndsAt)
        try values.encodeNullable(roundCountdownEndsAt, forKey: .roundCountdownEndsAt)
        try values.encodeNullable(roundReadyWindowEndsAt, forKey: .roundReadyWindowEndsAt)
        try values.encode(players, forKey: .players)
        try values.encode(tanks, forKey: .tanks)
        try values.encode(crates, forKey: .crates)
        try values.encodeNullable(token, forKey: .token)
        try values.encode(projectiles, forKey: .projectiles)
        try values.encode(events, forKey: .events)
        try values.encodeNullable(roundWinnerId, forKey: .roundWinnerId)
        try values.encodeNullable(championId, forKey: .championId)
    }

    /// The catalog map this snapshot plays, if this client knows its version.
    public var map: HouseTanksMapDefinition? {
        HouseTanksMapCatalog.maps.first { $0.id.rawValue == mapId && $0.version == mapVersion }
    }
}

public struct HouseTanksPlayerResultDTO: Codable, Equatable, Sendable {
    public let playerId: String
    public let roundsWon: Int
    /// Null for every player of a cancelled match.
    public let finalRank: Int?

    private enum CodingKeys: String, CodingKey { case playerId, roundsWon, finalRank }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        playerId = try values.decode(String.self, forKey: .playerId)
        roundsWon = try values.decode(Int.self, forKey: .roundsWon)
        finalRank = try values.decodeRequiredNullable(Int.self, forKey: .finalRank)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(playerId, forKey: .playerId)
        try values.encode(roundsWon, forKey: .roundsWon)
        try values.encodeNullable(finalRank, forKey: .finalRank)
    }
}

/// `houseTanks.result` and `GET /game/sessions/{id}/result`, byte for byte the same.
public struct HouseTanksResultDTO: Codable, Equatable, Sendable {
    public let sessionId: String
    public let houseId: String
    public let gameKey: String
    public let protocolVersion: Int
    /// Null only when the match never started.
    public let mapId: String?
    public let mapVersion: Int?
    public let status: HouseTanksResultStatus
    public let endReason: HouseTanksEndReason
    public let championId: String?
    public let roundsPlayed: Int
    public let startedAt: Date?
    public let endedAt: Date
    public let durationSeconds: Double
    public let players: [HouseTanksPlayerResultDTO]

    private enum CodingKeys: String, CodingKey {
        case sessionId, houseId, gameKey, protocolVersion, mapId, mapVersion, status, endReason
        case championId, roundsPlayed, startedAt, endedAt, durationSeconds, players
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try values.decode(String.self, forKey: .sessionId)
        houseId = try values.decode(String.self, forKey: .houseId)
        gameKey = try values.decode(String.self, forKey: .gameKey)
        protocolVersion = try values.decode(Int.self, forKey: .protocolVersion)
        mapId = try values.decodeRequiredNullable(String.self, forKey: .mapId)
        mapVersion = try values.decodeRequiredNullable(Int.self, forKey: .mapVersion)
        status = try values.decode(HouseTanksResultStatus.self, forKey: .status)
        endReason = try values.decode(HouseTanksEndReason.self, forKey: .endReason)
        championId = try values.decodeRequiredNullable(String.self, forKey: .championId)
        roundsPlayed = try values.decode(Int.self, forKey: .roundsPlayed)
        startedAt = try values.decodeRequiredNullable(Date.self, forKey: .startedAt)
        endedAt = try values.decode(Date.self, forKey: .endedAt)
        durationSeconds = try values.decode(Double.self, forKey: .durationSeconds)
        players = try values.decode([HouseTanksPlayerResultDTO].self, forKey: .players)
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(sessionId, forKey: .sessionId)
        try values.encode(houseId, forKey: .houseId)
        try values.encode(gameKey, forKey: .gameKey)
        try values.encode(protocolVersion, forKey: .protocolVersion)
        try values.encodeNullable(mapId, forKey: .mapId)
        try values.encodeNullable(mapVersion, forKey: .mapVersion)
        try values.encode(status, forKey: .status)
        try values.encode(endReason, forKey: .endReason)
        try values.encodeNullable(championId, forKey: .championId)
        try values.encode(roundsPlayed, forKey: .roundsPlayed)
        try values.encodeNullable(startedAt, forKey: .startedAt)
        try values.encode(endedAt, forKey: .endedAt)
        try values.encode(durationSeconds, forKey: .durationSeconds)
        try values.encode(players, forKey: .players)
    }

    /// Shape rules a client can check without the session: only a decided
    /// champion completes a match, ranks follow round wins with shared ties,
    /// and a cancelled match keeps its scores without ranks or a champion.
    public func validate(sessionID: String, houseID: String) throws {
        try HouseTanksRealtime.checkCompatibility(self)
        guard sessionId == sessionID, houseId == houseID else { throw GameRealtimeError.unexpectedSession }
        let winsNeeded = HouseTanksMatchRules.roundWinsNeeded
        guard durationSeconds.isFinite, durationSeconds >= 0, roundsPlayed >= 0,
              players.count <= HouseTanksMapCatalog.maximumPlayers,
              Set(players.map(\.playerId)).count == players.count,
              players.allSatisfy({ !$0.playerId.isEmpty && (0...winsNeeded).contains($0.roundsWon) }),
              players.reduce(0, { $0 + $1.roundsWon }) <= roundsPlayed,
              (mapId == nil) == (mapVersion == nil),
              startedAt.map({ endedAt >= $0 }) ?? (durationSeconds == 0 && roundsPlayed == 0) else {
            throw GameRealtimeError.invalidResponse
        }
        switch status {
        case .cancelled:
            guard championId == nil, endReason != .championDecided,
                  players.allSatisfy({ $0.finalRank == nil }) else { throw GameRealtimeError.invalidResponse }
        case .completed:
            guard endReason == .championDecided, startedAt != nil, mapId != nil, let championId,
                  players.filter({ $0.roundsWon == winsNeeded }).map(\.playerId) == [championId],
                  players.allSatisfy({ player in
                      player.finalRank == 1 + players.filter { $0.roundsWon > player.roundsWon }.count
                  }) else { throw GameRealtimeError.invalidResponse }
        }
    }
}
