import Foundation

public enum HouseRocketsPhase: String, Codable, Sendable {
    case countdown
    case playing
    case paused
    case ended
}

public enum HouseRocketsRole: String, Codable, Sendable {
    case human
    case bot
    case remote
}

public enum HouseRocketsColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case mint
    case coral
    case blue
    case gold
    case violet
    case orange
    case pink
    case teal

    public var id: String { rawValue }
}

public struct HouseRocketsPlayer: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let nameKey: String
    public let role: HouseRocketsRole
    public let color: HouseRocketsColor
    public var isAlive: Bool
    public var distance: Double
    public var heading: Double
    public var worldX: Double
    public var worldY: Double
    public var speedEffect: HouseRocketsSpeedEffect? = nil
    public var effectRemaining: Double = 0

    public init(id: UUID, nameKey: String, role: HouseRocketsRole, color: HouseRocketsColor, isAlive: Bool, distance: Double, heading: Double, worldX: Double, worldY: Double, speedEffect: HouseRocketsSpeedEffect? = nil, effectRemaining: Double = 0) {
        self.id = id
        self.nameKey = nameKey
        self.role = role
        self.color = color
        self.isAlive = isAlive
        self.distance = distance
        self.heading = heading
        self.worldX = worldX
        self.worldY = worldY
        self.speedEffect = speedEffect
        self.effectRemaining = effectRemaining
    }
}

public struct HouseRocketsPoint: Codable, Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }
}

public struct HouseRocketsPassageSection: Codable, Equatable, Sendable {
    public let offsetX: Double
    public let lowerY: Double
    public let upperY: Double
    public var centerY: Double { (lowerY + upperY) / 2 }

    public init(offsetX: Double, lowerY: Double, upperY: Double) {
        self.offsetX = offsetX
        self.lowerY = lowerY
        self.upperY = upperY
    }
}

public struct HouseRocketsGateState: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let worldX: Double
    public let sections: [HouseRocketsPassageSection]

    public var width: Double { (sections.last?.offsetX ?? 0) - (sections.first?.offsetX ?? 0) }
    public var minX: Double { worldX + (sections.first?.offsetX ?? 0) }
    public var maxX: Double { worldX + (sections.last?.offsetX ?? 0) }

    public init(id: UUID, worldX: Double, sections: [HouseRocketsPassageSection]) {
        self.id = id
        self.worldX = worldX
        self.sections = sections
    }
}

public enum HouseRocketsSpeedEffect: String, Codable, Sendable {
    case boost
    case slow

    public var multiplier: Double { self == .boost ? 1.45 : 0.65 }
    public var duration: Double { self == .boost ? 1.3 : 1.4 }
}

/// Non-solid fields oscillate across the course; their forward coordinate stays fixed.
public struct HouseRocketsSpeedField: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let worldX: Double
    public let effect: HouseRocketsSpeedEffect
    public let phase: Double
    public let period: Double
    public static let artworkScale = 0.7
    public static let radius = 22.0 * artworkScale

    public func worldY(at time: TimeInterval) -> Double {
        180 + sin(time * 2 * .pi / period + phase) * 112
    }

    public init(id: UUID, worldX: Double, effect: HouseRocketsSpeedEffect, phase: Double, period: Double) {
        self.id = id
        self.worldX = worldX
        self.effect = effect
        self.phase = phase
        self.period = period
    }
}

public struct HouseRocketsConfiguration: Codable, Equatable, Sendable {
    public var botCount: Int

    public var normalizedBotCount: Int { min(3, max(1, botCount)) }
    public static let demo = HouseRocketsConfiguration(botCount: 3)

    public init(botCount: Int) {
        self.botCount = botCount
    }
}

public enum HouseRocketsAction: Codable, Equatable, Sendable {
    case steer(heading: Double)
    case restart
}

public struct HouseRocketsCommand: Codable, Equatable, Sendable {
    public let matchID: UUID
    public let playerID: UUID?
    public let sequence: Int
    public let action: HouseRocketsAction

    public init(matchID: UUID, playerID: UUID?, sequence: Int, action: HouseRocketsAction) {
        self.matchID = matchID
        self.playerID = playerID
        self.sequence = sequence
        self.action = action
    }
}

public struct HouseRocketsSnapshot: Codable, Equatable, Sendable {
    public let matchID: UUID
    public var revision: Int
    public var phase: HouseRocketsPhase
    public var players: [HouseRocketsPlayer]
    public var gates: [HouseRocketsGateState]
    public var speedFields: [HouseRocketsSpeedField]
    public var elapsedTime: TimeInterval
    public var cameraX: Double
    public var countdown: Int?
    public var winnerID: UUID?
    public var lastEliminatedID: UUID?

    public var humanPlayer: HouseRocketsPlayer? { players.first { $0.role == .human } }
    public var winner: HouseRocketsPlayer? { players.first { $0.id == winnerID } }
    public var aliveCount: Int { players.filter(\.isAlive).count }

    public init(matchID: UUID, revision: Int, phase: HouseRocketsPhase, players: [HouseRocketsPlayer], gates: [HouseRocketsGateState], speedFields: [HouseRocketsSpeedField], elapsedTime: TimeInterval, cameraX: Double, countdown: Int?, winnerID: UUID?, lastEliminatedID: UUID?) {
        self.matchID = matchID
        self.revision = revision
        self.phase = phase
        self.players = players
        self.gates = gates
        self.speedFields = speedFields
        self.elapsedTime = elapsedTime
        self.cameraX = cameraX
        self.countdown = countdown
        self.winnerID = winnerID
        self.lastEliminatedID = lastEliminatedID
    }
}

public enum HouseRocketsResolution: Equatable {
    case ongoing
    case draw
    case winner(UUID)
}

public enum HouseRocketsRules {
    public static func resolve(players: [HouseRocketsPlayer]) -> HouseRocketsResolution {
        let alive = players.filter(\.isAlive)
        if alive.count == 1 { return .winner(alive[0].id) }
        if alive.isEmpty { return .draw }
        return .ongoing
    }

    public static func eliminating(_ id: UUID, from players: [HouseRocketsPlayer]) -> [HouseRocketsPlayer] {
        players.map { player in
            guard player.id == id else { return player }
            var updated = player
            updated.isAlive = false
            return updated
        }
    }
}

