import CoreGraphics
import Foundation

enum HouseTanksPhase: String, Codable, Sendable {
    case countdown
    case playing
    case paused
    case roundEnded
    case matchEnded
}

enum HouseTanksDifficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy
    case normal
    case hard

    var id: String { rawValue }
    var titleKey: String { "house_tanks_difficulty_\(rawValue)" }
}

enum HouseTanksPlayerRole: String, Codable, Sendable {
    case human
    case bot
}

enum HouseTanksColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case teal
    case orange
    case blue

    var id: String { rawValue }
}

enum HouseTanksMapID: String, CaseIterable, Codable, Identifiable, Sendable {
    case livingRoom
    case corridors
    case warehouse
    case courtyard

    var id: String { rawValue }
    var titleKey: String { "house_tanks_map_\(rawValue)_title" }
    var detailKey: String { "house_tanks_map_\(rawValue)_detail" }
}

struct HouseTanksNormalizedPoint: Codable, Equatable, Sendable {
    let x: Double
    let y: Double
}

struct HouseTanksNormalizedSize: Codable, Equatable, Sendable {
    let width: Double
    let height: Double
}

enum HouseTanksObstacleStyle: String, Codable, Equatable, Sendable {
    case divider
    case sofa
    case roundTable
    case crate
    case bookshelf
    case pillar
    case planter
}

enum HouseTanksObstacleTone: String, Codable, Equatable, Sendable {
    case navy
    case teal
    case orange
    case blue
    case wood
    case green
}

struct HouseTanksObstacleDefinition: Codable, Equatable, Sendable {
    let center: HouseTanksNormalizedPoint
    let size: HouseTanksNormalizedSize
    let rotation: Double
    let style: HouseTanksObstacleStyle
    let tone: HouseTanksObstacleTone

    var isMovable: Bool { style == .crate }
    var breaksOnHit: Bool { style == .crate }

    func renderedSize(in arena: CGSize) -> CGSize {
        let scale = HouseTanksMapCatalog.obstacleBaseScale * HouseTanksMapCatalog.gameplayScale
        let height = arena.height * size.height * scale
        switch style {
        case .roundTable, .crate, .pillar, .planter:
            return CGSize(width: height, height: height)
        case .divider, .sofa, .bookshelf:
            return CGSize(width: arena.width * size.width * scale, height: height)
        }
    }

    func bounds(in arena: CGSize) -> CGRect {
        let rendered = renderedSize(in: arena)
        let width = abs(cos(rotation)) * rendered.width + abs(sin(rotation)) * rendered.height
        let height = abs(sin(rotation)) * rendered.width + abs(cos(rotation)) * rendered.height
        return CGRect(x: center.x * arena.width - width / 2,
                      y: center.y * arena.height - height / 2, width: width, height: height)
    }

    func clearance(from point: CGPoint, in arena: CGSize) -> CGFloat {
        let rendered = renderedSize(in: arena)
        let dx = point.x - center.x * arena.width
        let dy = point.y - center.y * arena.height
        switch style {
        case .roundTable, .pillar, .planter:
            return max(0, hypot(dx, dy) - rendered.width / 2)
        default:
            let localX = dx * cos(rotation) + dy * sin(rotation)
            let localY = -dx * sin(rotation) + dy * cos(rotation)
            return hypot(max(0, abs(localX) - rendered.width / 2),
                         max(0, abs(localY) - rendered.height / 2))
        }
    }
}

struct HouseTanksFloorLineDefinition: Codable, Equatable, Sendable {
    let start: HouseTanksNormalizedPoint
    let end: HouseTanksNormalizedPoint
}

struct HouseTanksMapDefinition: Codable, Equatable, Sendable {
    let id: HouseTanksMapID
    let version: Int
    let spawnPoints: [HouseTanksNormalizedPoint]
    let obstacles: [HouseTanksObstacleDefinition]
    let floorLines: [HouseTanksFloorLineDefinition]
    let floorMarkers: [HouseTanksNormalizedPoint]
}

struct HouseTanksPlayer: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let nameKey: String
    let role: HouseTanksPlayerRole
    let color: HouseTanksColor
    var armor: Int
    var roundsWon: Int
    var isAlive: Bool
    var powerUp: HouseTanksPowerUpStatus? = nil
}

enum HouseTanksPowerUp: String, CaseIterable, Codable, Sendable {
    case speed, rapidFire, spreadShot, shield

    var titleKey: String { "house_tanks_power_\(rawValue)" }

    var symbolName: String {
        switch self {
        case .speed: "bolt.fill"
        case .rapidFire: "flame.fill"
        case .spreadShot: "arrow.up.left.and.arrow.up.right"
        case .shield: "shield.fill"
        }
    }
}

struct HouseTanksPowerUpStatus: Codable, Equatable, Sendable {
    let kind: HouseTanksPowerUp
    let remaining: TimeInterval
}

struct HouseTanksMatchConfiguration: Codable, Equatable, Sendable {
    var difficulty: HouseTanksDifficulty
    var humanColor: HouseTanksColor
    var mapID: HouseTanksMapID = .livingRoom
    var armorPerRound: Int = 5
    var roundWinsNeeded: Int = 3
    var roundDuration: TimeInterval = 60

    static let demo = HouseTanksMatchConfiguration(
        difficulty: .normal,
        humanColor: .teal
    )
}

enum HouseTanksAction: Codable, Equatable, Sendable {
    case pressStarted
    case pressEnded
    case nextRound
    case restartMatch
}

struct HouseTanksCommand: Codable, Equatable, Sendable {
    let matchID: UUID
    let playerID: UUID?
    let sequence: Int
    let action: HouseTanksAction
}

struct HouseTanksSnapshot: Codable, Equatable, Sendable {
    let matchID: UUID
    var revision: Int
    var phase: HouseTanksPhase
    var mapID: HouseTanksMapID
    var mapVersion: Int
    var players: [HouseTanksPlayer]
    var roundNumber: Int
    var timeRemaining: TimeInterval
    var countdown: Int?
    var roundWinnerID: UUID?
    var championID: UUID?

    var humanPlayer: HouseTanksPlayer? {
        players.first { $0.role == .human }
    }

    var roundWinner: HouseTanksPlayer? {
        players.first { $0.id == roundWinnerID }
    }

    var champion: HouseTanksPlayer? {
        players.first { $0.id == championID }
    }
}

enum HouseTanksRoundResolution: Equatable {
    case ongoing
    case draw
    case winner(UUID)
}

enum HouseTanksMatchRules {
    static func applyingDamage(
        to players: [HouseTanksPlayer],
        targetID: UUID,
        amount: Int = 1
    ) -> [HouseTanksPlayer] {
        players.map { player in
            guard player.id == targetID, player.isAlive else { return player }
            var updated = player
            updated.armor = max(0, player.armor - max(0, amount))
            updated.isAlive = updated.armor > 0
            return updated
        }
    }

    static func resolveRound(
        players: [HouseTanksPlayer],
        timeExpired: Bool
    ) -> HouseTanksRoundResolution {
        let alive = players.filter(\.isAlive)

        if alive.count == 1 {
            return .winner(alive[0].id)
        }
        if alive.isEmpty {
            return .draw
        }
        guard timeExpired else { return .ongoing }

        let highestArmor = alive.map(\.armor).max() ?? 0
        let leaders = alive.filter { $0.armor == highestArmor }
        return leaders.count == 1 ? .winner(leaders[0].id) : .draw
    }

    static func awardingRound(
        to winnerID: UUID?,
        players: [HouseTanksPlayer]
    ) -> [HouseTanksPlayer] {
        guard let winnerID else { return players }
        return players.map { player in
            var updated = player
            if player.id == winnerID {
                updated.roundsWon += 1
            }
            return updated
        }
    }

    static func champion(
        in players: [HouseTanksPlayer],
        winsNeeded: Int
    ) -> UUID? {
        players.first { $0.roundsWon >= winsNeeded }?.id
    }
}

enum HouseTanksMath {
    static func normalizedAngle(_ angle: CGFloat) -> CGFloat {
        var value = angle
        while value > .pi { value -= .pi * 2 }
        while value < -.pi { value += .pi * 2 }
        return value
    }

    static func oppositeRotationDirection(after direction: CGFloat) -> CGFloat {
        direction >= 0 ? -1 : 1
    }
}
