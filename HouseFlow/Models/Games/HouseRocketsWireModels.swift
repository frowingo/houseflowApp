import Foundation

// Dedicated v2 wire DTOs. Nullable game fields must exist, even when their value is null.
enum HouseRocketsWirePhase: String, Decodable, Sendable {
    case countdown, playing, recovering, finalizing, ended, cancelled
}

enum HouseRocketsEliminationReason: String, Decodable, Sendable {
    case behindCamera, forfeit, connectionExpired, membershipRevoked
}

enum HouseRocketsResultStatus: String, Decodable, Sendable {
    case completed, cancelled
}

enum HouseRocketsEndReason: String, Decodable, Sendable {
    case lastSurvivor, simultaneousElimination, insufficientPlayers, cancelledByUser
    case sessionExpired, recoveryFailed, coordinationUnavailable, runtimeOverloaded
}

extension KeyedDecodingContainer {
    func decodeRequiredNullable<Value: Decodable>(_ type: Value.Type, forKey key: Key) throws -> Value? {
        guard contains(key) else {
            throw DecodingError.keyNotFound(key, .init(codingPath: codingPath,
                debugDescription: "Nullable field must be present: \(key.stringValue)"))
        }
        return try decodeIfPresent(type, forKey: key)
    }
}

struct HouseRocketsRuntimeSettingsDTO: Decodable, Equatable, Sendable {
    let physicsRateHz: Int
    let schedulingRateHz: Int
    let snapshotRateHz: Int
    let maximumInputRateHz: Int
    let maximumSteerMessagesPerSecond: Int
    let controlHeartbeatMilliseconds: Int64
    let controlTimeoutMilliseconds: Int64
    let reconnectGraceMilliseconds: Int64
    let maximumMatchMilliseconds: Int64
}

struct HouseRocketsWelcomeDTO: Decodable, Equatable, Sendable {
    let sessionId: String
    let gameKey: String
    let connectionId: String
    let protocolVersion: Int
    let courseVersion: Int
    let settings: HouseRocketsRuntimeSettingsDTO
}

struct HouseRocketsControlGrantDTO: Decodable, Equatable, Sendable {
    let sessionId: String
    let playerId: String
    let runtimeEpoch: Int64
    let controlGeneration: String
}

struct HouseRocketsPlayerDTO: Decodable, Equatable, Sendable {
    let playerId: String
    let displayName: String
    let color: HouseRocketsColor
    let worldX: Double
    let worldY: Double
    let courseHeading: Double
    let isAlive: Bool
    let connected: Bool
    let distance: Double
    let speedEffect: HouseRocketsSpeedEffect?
    let effectRemainingSeconds: Double
    let eliminatedAtTick: Int64?
    let eliminationReason: HouseRocketsEliminationReason?
    let lastProcessedInputSequence: Int64
    let controlGeneration: String?

    private enum CodingKeys: String, CodingKey {
        case playerId, displayName, color, worldX, worldY, courseHeading, isAlive, connected, distance, speedEffect, effectRemainingSeconds, eliminatedAtTick, eliminationReason, lastProcessedInputSequence, controlGeneration
    }

    init(from decoder: Decoder) throws {
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

struct HouseRocketsPassageDTO: Decodable, Equatable, Sendable {
    let offsetX: Double
    let lowerY: Double
    let upperY: Double
}

struct HouseRocketsGateDTO: Decodable, Equatable, Sendable {
    let id: String
    let worldX: Double
    let sections: [HouseRocketsPassageDTO]
}

struct HouseRocketsSpeedFieldDTO: Decodable, Equatable, Sendable {
    let id: String
    let worldX: Double
    let effect: HouseRocketsSpeedEffect
    let phase: Double
    let periodSeconds: Double
}

struct HouseRocketsSnapshotDTO: Decodable, Equatable, Sendable {
    let sessionId: String
    let gameKey: String
    let runtimeEpoch: Int64
    let stateSequence: Int64
    let tick: Int64
    let elapsedSeconds: Double
    let phase: HouseRocketsWirePhase
    let courseVersion: Int
    let cameraX: Double
    let courseAngle: Double
    let players: [HouseRocketsPlayerDTO]
    let gates: [HouseRocketsGateDTO]
    let speedFields: [HouseRocketsSpeedFieldDTO]
    let countdownEndsAt: Date?
    let winnerId: String?

    private enum CodingKeys: String, CodingKey {
        case sessionId, gameKey, runtimeEpoch, stateSequence, tick, elapsedSeconds, phase, courseVersion, cameraX, courseAngle, players, gates, speedFields, countdownEndsAt, winnerId
    }

    init(from decoder: Decoder) throws {
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

struct HouseRocketsPlayerResultDTO: Decodable, Equatable, Sendable {
    let playerId: String
    let rank: Int?
    let eliminatedAtTick: Int64?
    let eliminationReason: HouseRocketsEliminationReason?
    let distance: Double

    private enum CodingKeys: String, CodingKey {
        case playerId, rank, eliminatedAtTick, eliminationReason, distance
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        playerId = try values.decode(String.self, forKey: .playerId)
        rank = try values.decodeRequiredNullable(Int.self, forKey: .rank)
        eliminatedAtTick = try values.decodeRequiredNullable(Int64.self, forKey: .eliminatedAtTick)
        eliminationReason = try values.decodeRequiredNullable(HouseRocketsEliminationReason.self, forKey: .eliminationReason)
        distance = try values.decode(Double.self, forKey: .distance)
    }
}

struct HouseRocketsResultDTO: Decodable, Equatable, Sendable {
    let sessionId: String
    let houseId: String
    let gameKey: String
    let protocolVersion: Int
    let courseVersion: Int
    let status: HouseRocketsResultStatus
    let endReason: HouseRocketsEndReason
    let winnerId: String?
    let startedAt: Date?
    let endedAt: Date
    let durationSeconds: Double
    let players: [HouseRocketsPlayerResultDTO]

    private enum CodingKeys: String, CodingKey {
        case sessionId, houseId, gameKey, protocolVersion, courseVersion, status, endReason, winnerId, startedAt, endedAt, durationSeconds, players
    }

    init(from decoder: Decoder) throws {
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

