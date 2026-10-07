import Foundation

/// In-memory authority for one human and 1...7 bots. Randomness and timing are
/// injectable so tournament rules can be checked without UI or wall-clock delays.
@MainActor
final class DemoRPSGameService: RPSGameServicing {
    private var state: RPSSnapshot?
    private var continuation: AsyncStream<RPSSnapshot>.Continuation?
    private var revealTask: Task<Void, Never>?
    private let randomIndex: (Int) -> Int
    private let countdownNanoseconds: UInt64

    init(
        countdownNanoseconds: UInt64 = 700_000_000,
        randomIndex: @escaping (Int) -> Int = { Int.random(in: 0..<$0) }
    ) {
        self.countdownNanoseconds = countdownNanoseconds
        self.randomIndex = randomIndex
    }

    deinit { revealTask?.cancel() }

    func events() -> AsyncStream<RPSSnapshot> {
        continuation?.finish()
        return AsyncStream { continuation in
            self.continuation = continuation
            if let state { continuation.yield(state) }
        }
    }

    func start(players: [RPSPlayer], localPlayerID: UUID) async throws {
        let names = players.map { $0.name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
        guard (2...8).contains(players.count), Set(players.map(\.id)).count == players.count,
              Set(names).count == players.count, names.allSatisfy({ !$0.isEmpty && $0.count <= 24 }),
              players.contains(where: { $0.id == localPlayerID }) else {
            throw RPSGameError.invalidPlayers
        }
        revealTask?.cancel()
        state = RPSSnapshot(
            sessionID: UUID(), revision: 0, players: players, localPlayerID: localPlayerID,
            rounds: [makeRound(players: players, number: 1)], phase: .draw
        )
        publish()
    }

    func send(_ command: RPSCommand) async throws {
        guard let state, state.sessionID == command.sessionID,
              state.revision == command.expectedRevision else { throw RPSGameError.staleCommand }
        switch command.action {
        case .advance: try advance()
        case let .play(matchID, attempt, move):
            try play(matchID: matchID, attempt: attempt, move: move)
        }
    }

    func disconnect() {
        revealTask?.cancel()
        revealTask = nil
        continuation?.finish()
        continuation = nil
        state = nil
    }

    private func advance() throws {
        guard var state, let round = state.currentRound else { throw RPSGameError.invalidAction }
        switch state.phase {
        case .draw:
            state.activeMatchID = round.matches.first?.id
            state.phase = .choosing
        case .reveal:
            guard let index = round.matches.firstIndex(where: { $0.id == state.activeMatchID }) else {
                throw RPSGameError.invalidAction
            }
            if round.matches[index].winnerID == nil {
                state.rounds[state.rounds.count - 1].matches[index].attempt += 1
                state.rounds[state.rounds.count - 1].matches[index].firstMove = nil
                state.rounds[state.rounds.count - 1].matches[index].secondMove = nil
                state.phase = .choosing
            } else if let next = round.matches.first(where: { $0.winnerID == nil }) {
                state.activeMatchID = next.id
                state.phase = .choosing
            } else {
                state.activeMatchID = nil
                state.phase = .roundComplete
            }
        case .roundComplete:
            guard round.isComplete else { throw RPSGameError.invalidAction }
            let advancing = round.advancingPlayers
            if advancing.count == 1 {
                state.champion = advancing.first
                state.phase = .finished
            } else {
                state.rounds.append(makeRound(players: advancing, number: round.number + 1))
                state.phase = .draw
            }
        default: throw RPSGameError.invalidAction
        }
        self.state = state
        publish()
    }

    private func play(matchID: UUID, attempt: Int, move: RPSMove?) throws {
        guard var state, state.phase == .choosing, let match = state.activeMatch,
              match.id == matchID, match.attempt == attempt,
              state.localPlayerIsPlaying == (move != nil) else { throw RPSGameError.invalidAction }

        // Bot choices are independent of the human's choice. Keep them private
        // until reveal; the transport must preserve this boundary in online play.
        let first = match.first.id == state.localPlayerID ? move! : randomMove()
        let second = match.second.id == state.localPlayerID ? move! : randomMove()
        state.phase = .countdown
        state.countdown = 3
        self.state = state
        publish()
        let sessionID = state.sessionID
        let delay = countdownNanoseconds
        revealTask = Task { [weak self] in
            do {
                for tick in [2, 1, 0] {
                    try await Task.sleep(nanoseconds: delay)
                    try Task.checkCancellation()
                    guard let self, var current = self.state,
                          current.sessionID == sessionID, current.activeMatchID == matchID,
                          current.phase == .countdown else { return }
                    if tick > 0 {
                        current.countdown = tick
                    } else {
                        guard let index = current.currentRound?.matches.firstIndex(where: { $0.id == matchID }) else { return }
                        let roundIndex = current.rounds.count - 1
                        current.rounds[roundIndex].matches[index].firstMove = first
                        current.rounds[roundIndex].matches[index].secondMove = second
                        current.rounds[roundIndex].matches[index].winnerID = first == second ? nil :
                            (first.beats(second) ? match.first.id : match.second.id)
                        current.countdown = nil
                        current.phase = .reveal
                    }
                    self.state = current
                    self.publish()
                }
            } catch { /* Leaving or restarting cancels the pending reveal. */ }
        }
    }

    private func randomMove() -> RPSMove { RPSMove.allCases[randomIndex(RPSMove.allCases.count)] }

    private func makeRound(players: [RPSPlayer], number: Int) -> RPSRound {
        var pool = players
        // Fisher–Yates: every remaining player has the same chance of a bye,
        // independently each round, including someone who received a previous bye.
        for index in stride(from: pool.count - 1, through: 1, by: -1) {
            pool.swapAt(index, randomIndex(index + 1))
        }
        let bye = pool.count.isMultiple(of: 2) ? nil : pool.removeLast()
        let matches = stride(from: 0, to: pool.count, by: 2).map {
            RPSMatch(id: UUID(), first: pool[$0], second: pool[$0 + 1])
        }
        return RPSRound(number: number, matches: matches, bye: bye)
    }

    private func publish() {
        guard var state else { return }
        state.revision += 1
        self.state = state
        continuation?.yield(state)
    }
}
