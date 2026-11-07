import Foundation

/// Faus Switch settings frozen into a session; `welcome.settings` is the authority for
/// a running match and the catalog copy only previews the next one.
public struct FausSwitchRuntimeSettingsDTO: Codable, Equatable, Sendable {
    public let physicsRateHz: Int
    public let snapshotRateHz: Int
    public let maximumInputRateHz: Int
    /// How far back the server applies a flip at the tick the player saw.
    public let maximumRewindMilliseconds: Int64
    public let controlHeartbeatMilliseconds: Int64
    public let controlTimeoutMilliseconds: Int64
    public let reconnectGraceMilliseconds: Int64
    public let maximumMatchMilliseconds: Int64

    public init(physicsRateHz: Int, snapshotRateHz: Int, maximumInputRateHz: Int, maximumRewindMilliseconds: Int64,
                controlHeartbeatMilliseconds: Int64, controlTimeoutMilliseconds: Int64,
                reconnectGraceMilliseconds: Int64, maximumMatchMilliseconds: Int64) {
        self.physicsRateHz = physicsRateHz
        self.snapshotRateHz = snapshotRateHz
        self.maximumInputRateHz = maximumInputRateHz
        self.maximumRewindMilliseconds = maximumRewindMilliseconds
        self.controlHeartbeatMilliseconds = controlHeartbeatMilliseconds
        self.controlTimeoutMilliseconds = controlTimeoutMilliseconds
        self.reconnectGraceMilliseconds = reconnectGraceMilliseconds
        self.maximumMatchMilliseconds = maximumMatchMilliseconds
    }

    /// Used only before a welcome arrives.
    public static let releaseDefaults = FausSwitchRuntimeSettingsDTO(
        physicsRateHz: FausSwitchMetrics.physicsRate, snapshotRateHz: 20, maximumInputRateHz: 20,
        maximumRewindMilliseconds: 250, controlHeartbeatMilliseconds: 2_000, controlTimeoutMilliseconds: 6_000,
        reconnectGraceMilliseconds: 10_000, maximumMatchMilliseconds: 120_000)

    public var heartbeatInterval: Double { Double(controlHeartbeatMilliseconds) / 1_000 }
    public var heartbeatTimeout: Double { Double(controlTimeoutMilliseconds) / 1_000 }
    public var reconnectGrace: Double { Double(reconnectGraceMilliseconds) / 1_000 }

    public var isUsable: Bool {
        heartbeatInterval >= 0.25 && heartbeatTimeout > heartbeatInterval && heartbeatTimeout <= 60
            && snapshotRateHz >= 1 && maximumInputRateHz >= 1 && maximumRewindMilliseconds >= 0
            && reconnectGraceMilliseconds >= 0
    }
}

public struct FausSwitchWelcomeDTO: Decodable, Equatable, Sendable {
    public let sessionId: String
    public let gameKey: String
    public let connectionId: String
    public let protocolVersion: Int
    public let courseVersion: Int
    public let settings: FausSwitchRuntimeSettingsDTO

    public init(sessionId: String, gameKey: String, connectionId: String, protocolVersion: Int, courseVersion: Int,
                settings: FausSwitchRuntimeSettingsDTO) {
        self.sessionId = sessionId
        self.gameKey = gameKey
        self.connectionId = connectionId
        self.protocolVersion = protocolVersion
        self.courseVersion = courseVersion
        self.settings = settings
    }
}

/// One robot in `fausSwitch.snapshot`. The physical fields are the complete state the
/// shared simulation needs, so every client steps the robot forward exactly as the server.
public struct FausSwitchRunnerDTO: Decodable, Equatable, Sendable {
    public let playerId: String
    public let displayName: String
    public let color: FausSwitchColor
    public let x: Double
    public let y: Double
    public let velocityY: Double
    public let gravity: FausSwitchGravity
    public let boostedUntilTick: Int64
    public let usedBoosts: [Int]
    public let slowedUntilTick: Int64
    public let usedSlows: [Int]
    public let status: FausSwitchRunnerStatus
    public let finishedAtTick: Int64?
    public let eliminatedAtTick: Int64?
    public let eliminationReason: FausSwitchCrashReason?
    public let connected: Bool
    public let lastProcessedInputSequence: Int64
    /// Present only on the watching connection's own robot while it holds control.
    public let controlGeneration: String?

    private enum CodingKeys: String, CodingKey {
        case playerId, displayName, color, x, y, velocityY, gravity, boostedUntilTick, usedBoosts
        case slowedUntilTick, usedSlows, status
        case finishedAtTick, eliminatedAtTick, eliminationReason, connected, lastProcessedInputSequence, controlGeneration
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        playerId = try values.decode(String.self, forKey: .playerId)
        displayName = try values.decode(String.self, forKey: .displayName)
        color = try values.decode(FausSwitchColor.self, forKey: .color)
        x = try values.decode(Double.self, forKey: .x)
        y = try values.decode(Double.self, forKey: .y)
        velocityY = try values.decode(Double.self, forKey: .velocityY)
        gravity = try values.decode(FausSwitchGravity.self, forKey: .gravity)
        boostedUntilTick = try values.decode(Int64.self, forKey: .boostedUntilTick)
        usedBoosts = try values.decode([Int].self, forKey: .usedBoosts)
        slowedUntilTick = try values.decode(Int64.self, forKey: .slowedUntilTick)
        usedSlows = try values.decode([Int].self, forKey: .usedSlows)
        status = try values.decode(FausSwitchRunnerStatus.self, forKey: .status)
        finishedAtTick = try values.decodeRequiredNullable(Int64.self, forKey: .finishedAtTick)
        eliminatedAtTick = try values.decodeRequiredNullable(Int64.self, forKey: .eliminatedAtTick)
        eliminationReason = try values.decodeRequiredNullable(FausSwitchCrashReason.self, forKey: .eliminationReason)
        connected = try values.decode(Bool.self, forKey: .connected)
        lastProcessedInputSequence = try values.decode(Int64.self, forKey: .lastProcessedInputSequence)
        controlGeneration = try values.decodeRequiredNullable(String.self, forKey: .controlGeneration)
    }

    /// The physical state at the snapshot's tick, at the race's robot size.
    public func state(scale: Double) -> FausSwitchRunnerState {
        FausSwitchRunnerState(x: x, y: y, velocityY: velocityY, gravity: gravity, boostedUntilTick: boostedUntilTick,
                              usedBoosts: Set(usedBoosts), slowedUntilTick: slowedUntilTick, usedSlows: Set(usedSlows),
                              status: status, finishedAtTick: finishedAtTick,
                              crashedAtTick: eliminatedAtTick, crashReason: eliminationReason, scale: scale)
    }

    var isValid: Bool {
        !playerId.isEmpty && x.isFinite && y.isFinite && velocityY.isFinite && boostedUntilTick >= 0 && slowedUntilTick >= 0
            && lastProcessedInputSequence >= 0
            && (status == .finished) == (finishedAtTick != nil)
            && (status == .crashed) == (eliminatedAtTick != nil && eliminationReason != nil)
    }
}

public struct FausSwitchSnapshotDTO: Decodable, Equatable, Sendable {
    public let sessionId: String
    public let gameKey: String
    public let runtimeEpoch: Int64
    public let stateSequence: Int64
    public let tick: Int64
    public let elapsedSeconds: Double
    public let phase: GameRuntimePhase
    public let courseVersion: Int
    /// Every robot's size this race: 1, or 0.75 with more than four robots (course 7).
    public let runnerScale: Double
    public let runners: [FausSwitchRunnerDTO]
    public let countdownEndsAt: Date?
    public let winnerId: String?

    private enum CodingKeys: String, CodingKey {
        case sessionId, gameKey, runtimeEpoch, stateSequence, tick, elapsedSeconds, phase, courseVersion
        case runnerScale, runners, countdownEndsAt, winnerId
    }

    /// The robots' physical states at `tick`, in seat order.
    public var runnerStates: [FausSwitchRunnerState] { runners.map { $0.state(scale: runnerScale) } }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try values.decode(String.self, forKey: .sessionId)
        gameKey = try values.decode(String.self, forKey: .gameKey)
        runtimeEpoch = try values.decode(Int64.self, forKey: .runtimeEpoch)
        stateSequence = try values.decode(Int64.self, forKey: .stateSequence)
        tick = try values.decode(Int64.self, forKey: .tick)
        elapsedSeconds = try values.decode(Double.self, forKey: .elapsedSeconds)
        phase = try values.decode(GameRuntimePhase.self, forKey: .phase)
        courseVersion = try values.decode(Int.self, forKey: .courseVersion)
        runnerScale = try values.decode(Double.self, forKey: .runnerScale)
        runners = try values.decode([FausSwitchRunnerDTO].self, forKey: .runners)
        countdownEndsAt = try values.decodeRequiredNullable(Date.self, forKey: .countdownEndsAt)
        winnerId = try values.decodeRequiredNullable(String.self, forKey: .winnerId)
    }
}

public enum FausSwitchResultStatus: String, Decodable, Sendable {
    case completed, cancelled
}

public enum FausSwitchEndReason: String, Decodable, Sendable {
    /// Every robot finished or crashed.
    case raceComplete
    /// The match limit was reached with robots still running.
    case timeLimit
    case insufficientPlayers, cancelledByUser, sessionExpired, recoveryFailed
    case coordinationUnavailable, runtimeOverloaded
}

public struct FausSwitchPlayerResultDTO: Decodable, Equatable, Sendable {
    public let playerId: String
    public let rank: Int?
    public let finishedAtTick: Int64?
    public let eliminatedAtTick: Int64?
    public let eliminationReason: FausSwitchCrashReason?
    /// World x reached, from the start line.
    public let distance: Double

    private enum CodingKeys: String, CodingKey {
        case playerId, rank, finishedAtTick, eliminatedAtTick, eliminationReason, distance
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        playerId = try values.decode(String.self, forKey: .playerId)
        rank = try values.decodeRequiredNullable(Int.self, forKey: .rank)
        finishedAtTick = try values.decodeRequiredNullable(Int64.self, forKey: .finishedAtTick)
        eliminatedAtTick = try values.decodeRequiredNullable(Int64.self, forKey: .eliminatedAtTick)
        eliminationReason = try values.decodeRequiredNullable(FausSwitchCrashReason.self, forKey: .eliminationReason)
        distance = try values.decode(Double.self, forKey: .distance)
    }
}

public struct FausSwitchResultDTO: Decodable, Equatable, Sendable {
    public let sessionId: String
    public let houseId: String
    public let gameKey: String
    public let protocolVersion: Int
    public let courseVersion: Int
    public let status: FausSwitchResultStatus
    public let endReason: FausSwitchEndReason
    public let winnerId: String?
    public let startedAt: Date?
    public let endedAt: Date
    public let durationSeconds: Double
    public let players: [FausSwitchPlayerResultDTO]

    private enum CodingKeys: String, CodingKey {
        case sessionId, houseId, gameKey, protocolVersion, courseVersion, status, endReason, winnerId
        case startedAt, endedAt, durationSeconds, players
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        sessionId = try values.decode(String.self, forKey: .sessionId)
        houseId = try values.decode(String.self, forKey: .houseId)
        gameKey = try values.decode(String.self, forKey: .gameKey)
        protocolVersion = try values.decode(Int.self, forKey: .protocolVersion)
        courseVersion = try values.decode(Int.self, forKey: .courseVersion)
        status = try values.decode(FausSwitchResultStatus.self, forKey: .status)
        endReason = try values.decode(FausSwitchEndReason.self, forKey: .endReason)
        winnerId = try values.decodeRequiredNullable(String.self, forKey: .winnerId)
        startedAt = try values.decodeRequiredNullable(Date.self, forKey: .startedAt)
        endedAt = try values.decode(Date.self, forKey: .endedAt)
        durationSeconds = try values.decode(Double.self, forKey: .durationSeconds)
        players = try values.decode([FausSwitchPlayerResultDTO].self, forKey: .players)
    }

    /// A final snapshot never substitutes for this contract.
    public func validate(sessionID: String, houseID: String) throws {
        try FausSwitchRealtime.checkCompatibility(self)
        guard sessionId == sessionID, houseId == houseID else { throw GameRealtimeError.unexpectedSession }
        guard durationSeconds.isFinite, durationSeconds >= 0, players.count <= 8,
              Set(players.map(\.playerId)).count == players.count,
              startedAt.map({ endedAt >= $0 }) ?? (durationSeconds == 0),
              players.allSatisfy({ !$0.playerId.isEmpty && $0.distance.isFinite && $0.distance >= 0 }) else {
            throw GameRealtimeError.invalidResponse
        }
        switch status {
        case .cancelled:
            guard winnerId == nil, players.allSatisfy({ $0.rank == nil }),
                  endReason != .raceComplete, endReason != .timeLimit else { throw GameRealtimeError.invalidResponse }
        case .completed:
            guard startedAt != nil, !players.isEmpty, endReason == .raceComplete || endReason == .timeLimit,
                  players.allSatisfy({ $0.rank.map { (1...players.count).contains($0) } ?? false }) else {
                throw GameRealtimeError.invalidResponse
            }
            if let winnerId {
                guard players.first(where: { $0.playerId == winnerId })?.rank == 1,
                      players.filter({ $0.rank == 1 }).count == 1 else { throw GameRealtimeError.invalidResponse }
            } else {
                // No winner: either a shared first place, or a lone first who never
                // finished (the time limit ran out with robots still running).
                let firsts = players.filter { $0.rank == 1 }
                guard firsts.count > 1 || (firsts.count == 1 && firsts[0].finishedAtTick == nil) else {
                    throw GameRealtimeError.invalidResponse
                }
            }
        }
    }
}
