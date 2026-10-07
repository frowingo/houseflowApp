import Foundation

enum HouseRocketsMode: String, CaseIterable, Identifiable, Sendable {
    case localBots
    case housemates

    var id: String { rawValue }
}

/// Captured at screen entry; local play does not require either identifier.
struct HouseRocketsLaunchContext: Equatable, Sendable {
    let houseID: String?
    let localPlayerID: String?
    var houseOwnerID: String? = nil
}

enum HouseRocketsOnlineBlocker: Equatable {
    case signInRequired
    case houseRequired
    case serviceUnavailable
}

enum HouseRocketsPhase: String, Codable, Sendable {
    case countdown
    case playing
    case paused
    case ended
}

enum HouseRocketsRole: String, Codable, Sendable {
    case human
    case bot
    case remote
}

enum HouseRocketsColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case mint
    case coral
    case blue
    case gold
    case violet
    case orange
    case pink
    case teal

    var id: String { rawValue }
}

struct HouseRocketsPlayer: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let nameKey: String
    let role: HouseRocketsRole
    let color: HouseRocketsColor
    var isAlive: Bool
    var distance: Double
    var heading: Double
    var worldX: Double
    var worldY: Double
    var speedEffect: HouseRocketsSpeedEffect? = nil
    var effectRemaining: Double = 0
}

struct HouseRocketsPoint: Codable, Equatable, Sendable {
    var x: Double
    var y: Double
}

struct HouseRocketsPassageSection: Codable, Equatable, Sendable {
    let offsetX: Double
    let lowerY: Double
    let upperY: Double
    var centerY: Double { (lowerY + upperY) / 2 }
}

struct HouseRocketsGateState: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let worldX: Double
    let sections: [HouseRocketsPassageSection]

    var width: Double { (sections.last?.offsetX ?? 0) - (sections.first?.offsetX ?? 0) }
    var minX: Double { worldX + (sections.first?.offsetX ?? 0) }
    var maxX: Double { worldX + (sections.last?.offsetX ?? 0) }
}

enum HouseRocketsSpeedEffect: String, Codable, Sendable {
    case boost
    case slow

    var multiplier: Double { self == .boost ? 1.45 : 0.65 }
    var duration: Double { self == .boost ? 1.3 : 1.4 }
}

/// Non-solid fields oscillate across the course; their forward coordinate stays fixed.
struct HouseRocketsSpeedField: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let worldX: Double
    let effect: HouseRocketsSpeedEffect
    let phase: Double
    let period: Double
    static let artworkScale = 0.7
    static let radius = 22.0 * artworkScale

    func worldY(at time: TimeInterval) -> Double {
        180 + sin(time * 2 * .pi / period + phase) * 112
    }
}

struct HouseRocketsConfiguration: Codable, Equatable, Sendable {
    var botCount: Int

    var normalizedBotCount: Int { min(3, max(1, botCount)) }
    static let demo = HouseRocketsConfiguration(botCount: 3)
}

enum HouseRocketsAction: Codable, Equatable, Sendable {
    case steer(heading: Double)
    case restart
}

struct HouseRocketsCommand: Codable, Equatable, Sendable {
    let matchID: UUID
    let playerID: UUID?
    let sequence: Int
    let action: HouseRocketsAction
}

struct HouseRocketsSnapshot: Codable, Equatable, Sendable {
    let matchID: UUID
    var revision: Int
    var phase: HouseRocketsPhase
    var players: [HouseRocketsPlayer]
    var gates: [HouseRocketsGateState]
    var speedFields: [HouseRocketsSpeedField]
    var elapsedTime: TimeInterval
    var cameraX: Double
    var countdown: Int?
    var winnerID: UUID?
    var lastEliminatedID: UUID?

    var humanPlayer: HouseRocketsPlayer? { players.first { $0.role == .human } }
    var winner: HouseRocketsPlayer? { players.first { $0.id == winnerID } }
    var aliveCount: Int { players.filter(\.isAlive).count }
}

enum HouseRocketsResolution: Equatable {
    case ongoing
    case draw
    case winner(UUID)
}

enum HouseRocketsRules {
    static func resolve(players: [HouseRocketsPlayer]) -> HouseRocketsResolution {
        let alive = players.filter(\.isAlive)
        if alive.count == 1 { return .winner(alive[0].id) }
        if alive.isEmpty { return .draw }
        return .ongoing
    }

    static func eliminating(_ id: UUID, from players: [HouseRocketsPlayer]) -> [HouseRocketsPlayer] {
        players.map { player in
            guard player.id == id else { return player }
            var updated = player
            updated.isAlive = false
            return updated
        }
    }
}
