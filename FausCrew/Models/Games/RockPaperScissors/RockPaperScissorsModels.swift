import Foundation

enum RPSMove: String, CaseIterable, Codable, Sendable {
    case rock, paper, scissors

    func beats(_ other: RPSMove) -> Bool {
        switch (self, other) {
        case (.rock, .scissors), (.paper, .rock), (.scissors, .paper): return true
        default: return false
        }
    }
}

struct RPSPlayer: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    var name: String
    let avatarIndex: Int

    init(id: UUID = UUID(), name: String, avatarIndex: Int) {
        self.id = id
        self.name = name
        self.avatarIndex = avatarIndex
    }
}

struct RPSMatch: Identifiable, Codable, Equatable, Sendable {
    let id: UUID
    let first: RPSPlayer
    let second: RPSPlayer
    var attempt = 1
    // Hidden choices never appear in a snapshot until both players reveal.
    var firstMove: RPSMove?
    var secondMove: RPSMove?
    var winnerID: UUID?

    var winner: RPSPlayer? {
        [first, second].first { $0.id == winnerID }
    }

    func contains(_ playerID: UUID) -> Bool {
        first.id == playerID || second.id == playerID
    }
}

struct RPSRound: Identifiable, Codable, Equatable, Sendable {
    let number: Int
    var matches: [RPSMatch]
    let bye: RPSPlayer?
    var id: Int { number }
    var isComplete: Bool { matches.allSatisfy { $0.winnerID != nil } }
    var advancingPlayers: [RPSPlayer] { matches.compactMap(\.winner) + [bye].compactMap { $0 } }
}

enum RPSPhase: String, Codable, Sendable {
    case draw, choosing, countdown, reveal, roundComplete, finished
}

/// A complete, revisioned public state. A future socket adapter can emit the same
/// snapshots after reconnecting; the UI never decides winners or pairings.
struct RPSSnapshot: Codable, Equatable, Sendable {
    let sessionID: UUID
    var revision: Int
    let players: [RPSPlayer]
    let localPlayerID: UUID
    var rounds: [RPSRound]
    var phase: RPSPhase
    var activeMatchID: UUID?
    var countdown: Int?
    var champion: RPSPlayer?

    var currentRound: RPSRound? { rounds.last }
    var activeMatch: RPSMatch? { currentRound?.matches.first { $0.id == activeMatchID } }
    var localPlayerIsPlaying: Bool { activeMatch?.contains(localPlayerID) == true }
}

enum RPSAction: Codable, Sendable {
    case advance
    case play(matchID: UUID, attempt: Int, move: RPSMove?)
}

/// Session and revision prevent late / duplicate inputs from playing another hand.
struct RPSCommand: Codable, Sendable {
    let sessionID: UUID
    let expectedRevision: Int
    let action: RPSAction
}

enum RPSGameError: Error {
    case invalidPlayers, staleCommand, invalidAction
}
