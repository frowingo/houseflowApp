import Foundation

public enum HouseTanksPhase: String, Codable, Sendable {
    case countdown
    case playing
    case paused
    case roundEnded
    case matchEnded
}

/// Demo lets the player pick the arena; online rooms are assigned one at random.
public enum HouseTanksMode: String, CaseIterable, Identifiable, Sendable {
    case demo
    case online

    public var id: String { rawValue }
}

/// Demo picks the player must make before a match; nothing is preselected.
public enum HouseTanksSetupStep: Int, CaseIterable, Identifiable, Sendable {
    case map
    /// Only on maps with a player range (the crowded-match Basement).
    case players
    case color
    case difficulty

    public var id: Int { rawValue }
}

public enum HouseTanksDifficulty: String, CaseIterable, Codable, Identifiable, Sendable {
    case easy
    case normal
    case hard

    public var id: String { rawValue }
    public var titleKey: String { "house_tanks_difficulty_\(rawValue)" }
}

public enum HouseTanksPlayerRole: String, Codable, Sendable {
    case human
    case bot
}

public enum HouseTanksColor: String, CaseIterable, Codable, Identifiable, Sendable {
    case plum
    case orange
    case blue
    case olive
    case mustard
    case crimson
    case sky
    case ivory

    public var id: String { rawValue }
}

public enum HouseTanksMapID: String, CaseIterable, Codable, Identifiable, Sendable {
    case livingRoom
    case corridors
    case warehouse
    case courtyard
    case basement

    public var id: String { rawValue }
    public var titleKey: String { "house_tanks_map_\(rawValue)_title" }
    public var detailKey: String { "house_tanks_map_\(rawValue)_detail" }
}

public struct HouseTanksNormalizedPoint: Codable, Equatable, Sendable {
    public let x: Double
    public let y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public func point(in arena: HouseTanksSize = HouseTanksWorld.arenaSize) -> HouseTanksVector {
        HouseTanksVector(x: x * arena.width, y: y * arena.height)
    }
}

public struct HouseTanksNormalizedSize: Codable, Equatable, Sendable {
    public let width: Double
    public let height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }
}

public enum HouseTanksObstacleStyle: String, Codable, Equatable, Sendable {
    case divider
    case sofa
    case roundTable
    case crate
    case bookshelf
    case pillar
    case planter

    public var isRound: Bool { self == .roundTable || self == .pillar || self == .planter }
}

public enum HouseTanksObstacleTone: String, Codable, Equatable, Sendable {
    case navy
    case teal
    case orange
    case blue
    case wood
    case green
}

public struct HouseTanksObstacleDefinition: Codable, Equatable, Sendable {
    public let center: HouseTanksNormalizedPoint
    public let size: HouseTanksNormalizedSize
    public let rotation: Double
    public let style: HouseTanksObstacleStyle
    public let tone: HouseTanksObstacleTone

    public init(center: HouseTanksNormalizedPoint, size: HouseTanksNormalizedSize, rotation: Double,
                style: HouseTanksObstacleStyle, tone: HouseTanksObstacleTone) {
        self.center = center
        self.size = size
        self.rotation = rotation
        self.style = style
        self.tone = tone
    }

    public var isMovable: Bool { style == .crate }
    public var breaksOnHit: Bool { style == .crate }

    /// `mapScale` is the map's own scale (smaller on crowded-match maps).
    public func renderedSize(in arena: HouseTanksSize = HouseTanksWorld.arenaSize, mapScale: Double = 1) -> HouseTanksSize {
        let scale = HouseTanksMapCatalog.obstacleBaseScale * HouseTanksMapCatalog.gameplayScale * mapScale
        let height = arena.height * size.height * scale
        switch style {
        case .roundTable, .crate, .pillar, .planter:
            return HouseTanksSize(width: height, height: height)
        case .divider, .sofa, .bookshelf:
            return HouseTanksSize(width: arena.width * size.width * scale, height: height)
        }
    }

    public func bounds(in arena: HouseTanksSize = HouseTanksWorld.arenaSize, mapScale: Double = 1) -> HouseTanksRect {
        let rendered = renderedSize(in: arena, mapScale: mapScale)
        let width = abs(cos(rotation)) * rendered.width + abs(sin(rotation)) * rendered.height
        let height = abs(sin(rotation)) * rendered.width + abs(cos(rotation)) * rendered.height
        return HouseTanksRect(x: center.x * arena.width - width / 2,
                              y: center.y * arena.height - height / 2, width: width, height: height)
    }

    public func clearance(from point: HouseTanksVector, in arena: HouseTanksSize = HouseTanksWorld.arenaSize, mapScale: Double = 1) -> Double {
        let rendered = renderedSize(in: arena, mapScale: mapScale)
        let dx = point.x - center.x * arena.width
        let dy = point.y - center.y * arena.height
        if style.isRound {
            return max(0, hypot(dx, dy) - rendered.width / 2)
        }
        let localX = dx * cos(rotation) + dy * sin(rotation)
        let localY = -dx * sin(rotation) + dy * cos(rotation)
        return hypot(max(0, abs(localX) - rendered.width / 2),
                     max(0, abs(localY) - rendered.height / 2))
    }
}

public struct HouseTanksFloorLineDefinition: Codable, Equatable, Sendable {
    public let start: HouseTanksNormalizedPoint
    public let end: HouseTanksNormalizedPoint

    public init(start: HouseTanksNormalizedPoint, end: HouseTanksNormalizedPoint) {
        self.start = start
        self.end = end
    }
}

public struct HouseTanksMapDefinition: Codable, Equatable, Sendable {
    public let id: HouseTanksMapID
    public let version: Int
    public let spawnPoints: [HouseTanksNormalizedPoint]
    public let obstacles: [HouseTanksObstacleDefinition]
    public let floorLines: [HouseTanksFloorLineDefinition]
    public let floorMarkers: [HouseTanksNormalizedPoint]
    /// Size of tanks, shots, jokers and furniture relative to the standard maps.
    /// Crowded-match maps are smaller so six to eight tanks still have room.
    public let scale: Double
    public let minPlayers: Int
    public let maxPlayers: Int

    public init(id: HouseTanksMapID, version: Int, spawnPoints: [HouseTanksNormalizedPoint],
                obstacles: [HouseTanksObstacleDefinition], floorLines: [HouseTanksFloorLineDefinition],
                floorMarkers: [HouseTanksNormalizedPoint], scale: Double, minPlayers: Int, maxPlayers: Int) {
        self.id = id
        self.version = version
        self.spawnPoints = spawnPoints
        self.obstacles = obstacles
        self.floorLines = floorLines
        self.floorMarkers = floorMarkers
        self.scale = scale
        self.minPlayers = minPlayers
        self.maxPlayers = maxPlayers
    }

    /// Seats online play may fill on this map.
    public var playerCounts: ClosedRange<Int> { minPlayers...maxPlayers }

    /// Demo matches keep their own rule: standard maps always seat four tanks, only the
    /// crowded-match maps (above four seats) let the player pick how many take part.
    public static let demoStandardPlayerCount = 4
    public var demoPlayerCounts: ClosedRange<Int> {
        minPlayers > Self.demoStandardPlayerCount
            ? playerCounts : Self.demoStandardPlayerCount...Self.demoStandardPlayerCount
    }

    /// A map whose demo setup asks how many tanks take part.
    public var hasDemoPlayerChoice: Bool { demoPlayerCounts.count > 1 }
}

public struct HouseTanksPlayer: Identifiable, Codable, Equatable, Sendable {
    public let id: UUID
    public let nameKey: String
    public let role: HouseTanksPlayerRole
    public let color: HouseTanksColor
    public var armor: Int
    public var roundsWon: Int
    public var isAlive: Bool
    public var powerUp: HouseTanksPowerUpStatus?

    public init(id: UUID, nameKey: String, role: HouseTanksPlayerRole, color: HouseTanksColor,
                armor: Int, roundsWon: Int, isAlive: Bool, powerUp: HouseTanksPowerUpStatus? = nil) {
        self.id = id
        self.nameKey = nameKey
        self.role = role
        self.color = color
        self.armor = armor
        self.roundsWon = roundsWon
        self.isAlive = isAlive
        self.powerUp = powerUp
    }
}

public enum HouseTanksPowerUp: String, CaseIterable, Codable, Sendable {
    case rocket, rapidFire, spreadShot, shield, aim

    public var titleKey: String { "house_tanks_power_\(rawValue)" }
    public var detailKey: String { "house_tanks_joker_\(rawValue)_detail" }
}

public struct HouseTanksPowerUpStatus: Codable, Equatable, Sendable {
    public let kind: HouseTanksPowerUp
    public let remaining: Double

    public init(kind: HouseTanksPowerUp, remaining: Double) {
        self.kind = kind
        self.remaining = remaining
    }
}

public struct HouseTanksMatchConfiguration: Codable, Equatable, Sendable {
    public var difficulty: HouseTanksDifficulty
    public var humanColor: HouseTanksColor
    public var mapID: HouseTanksMapID
    /// Tanks in the match, the human included. Clamped to the map's demo player range.
    public var playerCount: Int
    public var armorPerRound: Int
    public var roundWinsNeeded: Int

    /// Bot names in seat order; a match uses as many as it has bots.
    public static let botNameKeys = ["house_tanks_bot_one", "house_tanks_bot_two", "house_tanks_bot_three",
                                     "house_tanks_bot_four", "house_tanks_bot_five", "house_tanks_bot_six",
                                     "house_tanks_bot_seven"]
    public static let humanNameKey = "house_tanks_you"

    public init(difficulty: HouseTanksDifficulty, humanColor: HouseTanksColor, mapID: HouseTanksMapID = .livingRoom,
                playerCount: Int? = nil, armorPerRound: Int = 5, roundWinsNeeded: Int = 3) {
        self.difficulty = difficulty
        self.humanColor = humanColor
        self.mapID = mapID
        let map = HouseTanksMapCatalog.definition(for: mapID)
        let seats = map.demoPlayerCounts
        self.playerCount = min(max(playerCount ?? seats.lowerBound, seats.lowerBound), seats.upperBound)
        self.armorPerRound = armorPerRound
        self.roundWinsNeeded = roundWinsNeeded
    }

    public static let demo = HouseTanksMatchConfiguration(difficulty: .normal, humanColor: .plum)
}

public enum HouseTanksAction: Codable, Equatable, Sendable {
    case pressStarted
    case pressEnded
    case nextRound
    case restartMatch
}

public struct HouseTanksCommand: Codable, Equatable, Sendable {
    public let matchID: UUID
    public let playerID: UUID?
    public let sequence: Int
    public let action: HouseTanksAction

    public init(matchID: UUID, playerID: UUID?, sequence: Int, action: HouseTanksAction) {
        self.matchID = matchID
        self.playerID = playerID
        self.sequence = sequence
        self.action = action
    }
}

public struct HouseTanksSnapshot: Codable, Equatable, Sendable {
    public let matchID: UUID
    public var revision: Int
    public var phase: HouseTanksPhase
    public var mapID: HouseTanksMapID
    public var mapVersion: Int
    public var players: [HouseTanksPlayer]
    public var roundNumber: Int
    public var countdown: Int?
    public var roundWinnerID: UUID?
    public var championID: UUID?

    public init(matchID: UUID, revision: Int, phase: HouseTanksPhase, mapID: HouseTanksMapID, mapVersion: Int,
                players: [HouseTanksPlayer], roundNumber: Int, countdown: Int?, roundWinnerID: UUID?,
                championID: UUID?) {
        self.matchID = matchID
        self.revision = revision
        self.phase = phase
        self.mapID = mapID
        self.mapVersion = mapVersion
        self.players = players
        self.roundNumber = roundNumber
        self.countdown = countdown
        self.roundWinnerID = roundWinnerID
        self.championID = championID
    }

    public var humanPlayer: HouseTanksPlayer? { players.first { $0.role == .human } }
    public var roundWinner: HouseTanksPlayer? { players.first { $0.id == roundWinnerID } }
    public var champion: HouseTanksPlayer? { players.first { $0.id == championID } }
}

public enum HouseTanksRoundResolution: Equatable, Sendable {
    case ongoing
    case draw
    case winner(UUID)
}

public enum HouseTanksMatchRules {
    public static func applyingDamage(to players: [HouseTanksPlayer], targetID: UUID,
                                      amount: Int = 1) -> [HouseTanksPlayer] {
        players.map { player in
            guard player.id == targetID, player.isAlive else { return player }
            var updated = player
            updated.armor = max(0, player.armor - max(0, amount))
            updated.isAlive = updated.armor > 0
            return updated
        }
    }

    /// Rounds have no clock: they last until one tank is left (or none, a draw).
    public static func resolveRound(players: [HouseTanksPlayer]) -> HouseTanksRoundResolution {
        let alive = players.filter(\.isAlive)
        if alive.count == 1 {
            return .winner(alive[0].id)
        }
        return alive.isEmpty ? .draw : .ongoing
    }

    public static func awardingRound(to winnerID: UUID?, players: [HouseTanksPlayer]) -> [HouseTanksPlayer] {
        guard let winnerID else { return players }
        return players.map { player in
            var updated = player
            if player.id == winnerID { updated.roundsWon += 1 }
            return updated
        }
    }

    public static func champion(in players: [HouseTanksPlayer], winsNeeded: Int) -> UUID? {
        players.first { $0.roundsWon >= winsNeeded }?.id
    }
}

public enum HouseTanksMath {
    public static func normalizedAngle(_ angle: Double) -> Double {
        var value = angle
        while value > .pi { value -= .pi * 2 }
        while value < -.pi { value += .pi * 2 }
        return value
    }

    /// Distance from `origin` along `angle` to the edge of `bounds`; zero when the origin is outside.
    public static func rayLength(from origin: HouseTanksVector, angle: Double, in bounds: HouseTanksRect) -> Double {
        guard bounds.contains(origin) else { return 0 }
        let dx = cos(angle)
        let dy = sin(angle)
        var length = Double.greatestFiniteMagnitude
        if dx > 0.0001 { length = min(length, (bounds.maxX - origin.x) / dx) }
        if dx < -0.0001 { length = min(length, (bounds.minX - origin.x) / dx) }
        if dy > 0.0001 { length = min(length, (bounds.maxY - origin.y) / dy) }
        if dy < -0.0001 { length = min(length, (bounds.minY - origin.y) / dy) }
        return length == .greatestFiniteMagnitude ? 0 : length
    }

    public static func oppositeRotationDirection(after direction: Double) -> Double {
        direction >= 0 ? -1 : 1
    }
}
