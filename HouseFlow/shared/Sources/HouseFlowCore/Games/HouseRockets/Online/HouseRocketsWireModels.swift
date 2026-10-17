import Foundation


// Dedicated v2 wire DTOs. Nullable game fields must exist, even when their value is null.
public enum HouseRocketsWirePhase: String, Decodable, Sendable {
    case countdown, playing, recovering, finalizing, ended, cancelled
}

public enum HouseRocketsEliminationReason: String, Decodable, Sendable {
    case behindCamera, forfeit, connectionExpired, membershipRevoked
}

public enum HouseRocketsResultStatus: String, Decodable, Sendable {
    case completed, cancelled
}

public enum HouseRocketsEndReason: String, Decodable, Sendable {
    case lastSurvivor, simultaneousElimination, insufficientPlayers, cancelledByUser
    case sessionExpired, recoveryFailed, coordinationUnavailable, runtimeOverloaded
}

extension KeyedDecodingContainer {
    public func decodeRequiredNullable<Value: Decodable>(_ type: Value.Type, forKey key: Key) throws -> Value? {
        guard contains(key) else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath,
                debugDescription: "Nullable field must be present: \(key.stringValue)"))
        }
        return try decodeIfPresent(type, forKey: key)
    }
}

public struct HouseRocketsWelcomeDTO: Decodable, Equatable, Sendable {
    public let sessionId: String
    public let gameKey: String
    public let connectionId: String
    public let protocolVersion: Int
    public let courseVersion: Int
    public let settings: HouseRocketsRuntimeSettingsDTO

    public init(sessionId: String, gameKey: String, connectionId: String, protocolVersion: Int, courseVersion: Int, settings: HouseRocketsRuntimeSettingsDTO) {
        self.sessionId = sessionId
        self.gameKey = gameKey
        self.connectionId = connectionId
        self.protocolVersion = protocolVersion
        self.courseVersion = courseVersion
        self.settings = settings
    }
}

public struct HouseRocketsControlGrantDTO: Decodable, Equatable, Sendable {
    public let sessionId: String
    public let playerId: String
    public let runtimeEpoch: Int64
    public let controlGeneration: String

    public init(sessionId: String, playerId: String, runtimeEpoch: Int64, controlGeneration: String) {
        self.sessionId = sessionId
        self.playerId = playerId
        self.runtimeEpoch = runtimeEpoch
        self.controlGeneration = controlGeneration
    }
}

public struct HouseRocketsPlayerDTO: Decodable, Equatable, Sendable {
    public let playerId: String
    public let displayName: String
    public let color: HouseRocketsColor
    public let worldX: Double
    public let worldY: Double
    public let courseHeading: Double
    public let isAlive: Bool
    public let connected: Bool
    public let distance: Double
    public let speedEffect: HouseRocketsSpeedEffect?
    public let effectRemainingSeconds: Double
    public let eliminatedAtTick: Int64?
    public let eliminationReason: HouseRocketsEliminationReason?
    public let lastProcessedInputSequence: Int64
    public let controlGeneration: String?

    private enum CodingKeys: String, CodingKey {
        case playerId, displayName, color, worldX, worldY, courseHeading, isAlive, connected, distance, speedEffect, effectRemainingSeconds, eliminatedAtTick, eliminationReason, lastProcessedInputSequence, controlGeneration
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        playerId = try values.decode(String.self, forKey: .playerId)
        displayName = try values.decode(String.self, forKey: .displayName)
        color = try values.decode(HouseRocketsColor.self, forKey: .color)
        worldX = try values.decode(Double.self, forKey: .worldX)
        worldY = try values.decode(Double.self, forKey: .worldY)
        courseHeading = try values.decode(Double.self, forKey: .courseHeading)
        isAlive = try values.decode(Bool.self, forKey: .isAlive)
        connected = try values.decode(Bool.self, forKey: .connected)
        distance = try values.decode(Double.self, forKey: .distance)
        speedEffect = try values.decodeRequiredNullable(HouseRocketsSpeedEffect.self, forKey: .speedEffect)
        effectRemainingSeconds = try values.decode(Double.self, forKey: .effectRemainingSeconds)
        eliminatedAtTick = try values.decodeRequiredNullable(Int64.self, forKey: .eliminatedAtTick)
        eliminationReason = try values.decodeRequiredNullable(HouseRocketsEliminationReason.self, forKey: .eliminationReason)
        lastProcessedInputSequence = try values.decode(Int64.self, forKey: .lastProcessedInputSequence)
        controlGeneration = try values.decodeRequiredNullable(String.self, forKey: .controlGeneration)
    }
}

public struct HouseRocketsPassageDTO: Decodable, Equatable, Sendable {
    public let offsetX: Double
    public let lowerY: Double
    public let upperY: Double

    public init(offsetX: Double, lowerY: Double, upperY: Double) {
        self.offsetX = offsetX
        self.lowerY = lowerY
        self.upperY = upperY
    }
}

public struct HouseRocketsGateDTO: Decodable, Equatable, Sendable {
    public let id: String
    public let worldX: Double
    public let sections: [HouseRocketsPassageDTO]

    public init(id: String, worldX: Double, sections: [HouseRocketsPassageDTO]) {
        self.id = id
        self.worldX = worldX
        self.sections = sections
    }
}

public struct HouseRocketsSpeedFieldDTO: Decodable, Equatable, Sendable {
    public let id: String
    public let worldX: Double
    public let effect: HouseRocketsSpeedEffect
    public let phase: Double
    public let periodSeconds: Double

    public init(id: String, worldX: Double, effect: HouseRocketsSpeedEffect, phase: Double, periodSeconds: Double) {
        self.id = id
        self.worldX = worldX
        self.effect = effect
        self.phase = phase
        self.periodSeconds = periodSeconds
    }
}

public struct HouseRocketsSnapshotDTO: Decodable, Equatable, Sendable {
    public let sessionId: String
    public let gameKey: String
    public let runtimeEpoch: Int64
    public let stateSequence: Int64
    public let tick: Int64
    public let elapsedSeconds: Double
    public let phase: HouseRocketsWirePhase
    public let courseVersion: Int
    public let cameraX: Double
    public let courseAngle: Double
    public let players: [HouseRocketsPlayerDTO]
    public let gates: [HouseRocketsGateDTO]
    public let speedFields: [HouseRocketsSpeedFieldDTO]
    public let countdownEndsAt: Date?
    public let winnerId: String?

    private enum CodingKeys: String, CodingKey {
        case sessionId, gameKey, runtimeEpoch, stateSequence, tick, elapsedSeconds, phase, courseVersion, cameraX, courseAngle, players, gates, speedFields, countdownEndsAt, winnerId
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try values.decode(String.self, forKey: .sessionId)
        gameKey = try values.decode(String.self, forKey: .gameKey)
        runtimeEpoch = try values.decode(Int64.self, forKey: .runtimeEpoch)
        stateSequence = try values.decode(Int64.self, forKey: .stateSequence)
        tick = try values.decode(Int64.self, forKey: .tick)
        elapsedSeconds = try values.decode(Double.self, forKey: .elapsedSeconds)
        phase = try values.decode(HouseRocketsWirePhase.self, forKey: .phase)
        courseVersion = try values.decode(Int.self, forKey: .courseVersion)
        cameraX = try values.decode(Double.self, forKey: .cameraX)
        courseAngle = try values.decode(Double.self, forKey: .courseAngle)
        players = try values.decode([HouseRocketsPlayerDTO].self, forKey: .players)
        gates = try values.decode([HouseRocketsGateDTO].self, forKey: .gates)
        speedFields = try values.decode([HouseRocketsSpeedFieldDTO].self, forKey: .speedFields)
        countdownEndsAt = try values.decodeRequiredNullable(Date.self, forKey: .countdownEndsAt)
        winnerId = try values.decodeRequiredNullable(String.self, forKey: .winnerId)
    }
}

public struct HouseRocketsPlayerResultDTO: Decodable, Equatable, Sendable {
    public let playerId: String
    public let rank: Int?
    public let eliminatedAtTick: Int64?
    public let eliminationReason: HouseRocketsEliminationReason?
    public let distance: Double

    private enum CodingKeys: String, CodingKey {
        case playerId, rank, eliminatedAtTick, eliminationReason, distance
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        playerId = try values.decode(String.self, forKey: .playerId)
        rank = try values.decodeRequiredNullable(Int.self, forKey: .rank)
        eliminatedAtTick = try values.decodeRequiredNullable(Int64.self, forKey: .eliminatedAtTick)
        eliminationReason = try values.decodeRequiredNullable(HouseRocketsEliminationReason.self, forKey: .eliminationReason)
        distance = try values.decode(Double.self, forKey: .distance)
    }
}

public struct HouseRocketsResultDTO: Decodable, Equatable, Sendable {
    public let sessionId: String
    public let houseId: String
    public let gameKey: String
    public let protocolVersion: Int
    public let courseVersion: Int
    public let status: HouseRocketsResultStatus
    public let endReason: HouseRocketsEndReason
    public let winnerId: String?
    public let startedAt: Date?
    public let endedAt: Date
    public let durationSeconds: Double
    public let players: [HouseRocketsPlayerResultDTO]

    private enum CodingKeys: String, CodingKey {
        case sessionId, houseId, gameKey, protocolVersion, courseVersion, status, endReason, winnerId, startedAt, endedAt, durationSeconds, players
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try values.decode(String.self, forKey: .sessionId)
        houseId = try values.decode(String.self, forKey: .houseId)
        gameKey = try values.decode(String.self, forKey: .gameKey)
        protocolVersion = try values.decode(Int.self, forKey: .protocolVersion)
        courseVersion = try values.decode(Int.self, forKey: .courseVersion)
        status = try values.decode(HouseRocketsResultStatus.self, forKey: .status)
        endReason = try values.decode(HouseRocketsEndReason.self, forKey: .endReason)
        winnerId = try values.decodeRequiredNullable(String.self, forKey: .winnerId)
        startedAt = try values.decodeRequiredNullable(Date.self, forKey: .startedAt)
        endedAt = try values.decode(Date.self, forKey: .endedAt)
        durationSeconds = try values.decode(Double.self, forKey: .durationSeconds)
        players = try values.decode([HouseRocketsPlayerResultDTO].self, forKey: .players)
    }
}


