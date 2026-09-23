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

struct HouseTanksPlayer: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let nameKey: String
    let role: HouseTanksPlayerRole
    let color: HouseTanksColor
    var armor: Int
    var roundsWon: Int
    var isAlive: Bool
}

struct HouseTanksMatchConfiguration: Codable, Equatable, Sendable {
    var difficulty: HouseTanksDifficulty
    var humanColor: HouseTanksColor
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
}
