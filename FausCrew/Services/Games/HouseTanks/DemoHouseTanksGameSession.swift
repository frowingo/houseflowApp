import FausCrewCore
import Foundation
import SpriteKit

/// iOS host for the shared FauseTanks demo match (FausCrewCore). The rules, physics and
/// bots run in `HouseTanksBotMatch`; this type only schedules them — a countdown timer and
/// one engine step per SpriteKit frame — and hands the result to the scene and the view model.
@MainActor
final class DemoHouseTanksGameSession: HouseTanksGameServicing {
    let scene: HouseTanksScene

    private var match = HouseTanksBotMatch()
    private var continuation: AsyncStream<HouseTanksSnapshot>.Continuation?
    private var countdownTask: Task<Void, Never>?
    private var publishedState: PublishedState?

    /// What the SwiftUI layer shows; the arena itself is drawn every frame by the scene.
    private struct PublishedState: Equatable {
        let matchID: UUID
        let phase: HouseTanksPhase
        let countdown: Int?
        let roundNumber: Int
        let players: [PlayerState]
        let roundWinnerID: UUID?
        let championID: UUID?

        struct PlayerState: Equatable {
            let armor: Int
            let roundsWon: Int
            let isAlive: Bool
        }

        init(_ snapshot: HouseTanksSnapshot) {
            matchID = snapshot.matchID
            phase = snapshot.phase
            countdown = snapshot.countdown
            roundNumber = snapshot.roundNumber
            players = snapshot.players.map { PlayerState(armor: $0.armor, roundsWon: $0.roundsWon, isAlive: $0.isAlive) }
            roundWinnerID = snapshot.roundWinnerID
            championID = snapshot.championID
        }
    }

    init(scene: HouseTanksScene? = nil) {
        let scene = scene ?? HouseTanksScene()
        self.scene = scene
        scene.onFrame = { [weak self] delta in self?.frame(delta: delta) }
    }

    deinit {
        countdownTask?.cancel()
    }

    func events() -> AsyncStream<HouseTanksSnapshot> {
        continuation?.finish()
        return AsyncStream { continuation in
            self.continuation = continuation
            if let snapshot = self.match.snapshot {
                continuation.yield(snapshot)
            }
        }
    }

    func start(configuration: HouseTanksMatchConfiguration) async {
        match.start(configuration: configuration)
        scene.setSimulationPaused(false)
        render()
        publish(force: true)
        beginCountdown()
    }

    func send(_ command: HouseTanksCommand) async {
        guard match.send(command) else { return }
        switch command.action {
        case .nextRound, .restartMatch:
            render()
            publish(force: true)
            beginCountdown()
        case .pressStarted, .pressEnded:
            break
        }
    }

    func pause() {
        guard match.pause() else { return }
        scene.setSimulationPaused(true)
        publish()
    }

    func resume() {
        guard match.resume() else { return }
        scene.setSimulationPaused(false)
        publish()
    }

    func setReduceMotion(_ enabled: Bool) {
        scene.setReduceMotion(enabled)
    }

    func disconnect() {
        countdownTask?.cancel()
        countdownTask = nil
        match.reset()
        scene.stopMatch()
        continuation?.finish()
        continuation = nil
        publishedState = nil
    }

    // MARK: - Scheduling

    private func beginCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(HouseTanksBotMatch.countdownStepSeconds * 1_000_000_000))
                guard !Task.isCancelled, let self, self.match.phase == .countdown else { return }
                let started = self.match.advanceCountdown()
                self.publish()
                if started { return }
            }
        }
    }

    /// One engine step per rendered frame while playing; the arena is redrawn every frame.
    private func frame(delta: TimeInterval) {
        if match.phase == .playing, delta > 0 {
            match.advance(by: delta)
        }
        render()
        publish()
    }

    private func render() {
        guard let world = match.world, let snapshot = match.snapshot else { return }
        scene.render(world, roundKey: "\(snapshot.matchID.uuidString)-\(snapshot.roundNumber)",
                     events: match.drainEvents(),
                     localPlayerID: snapshot.humanPlayer.map { HouseTanksBotMatch.tankID($0.id) })
    }

    private func publish(force: Bool = false) {
        guard let snapshot = match.snapshot else { return }
        let state = PublishedState(snapshot)
        if let previous = publishedState, previous.matchID == state.matchID {
            // Armor loss flashes the hull, as SpriteKit did on every regular hit.
            for (index, player) in snapshot.players.enumerated()
            where index < previous.players.count && player.armor < previous.players[index].armor && player.isAlive {
                scene.showHit(playerID: HouseTanksBotMatch.tankID(player.id))
            }
        }
        guard force || state != publishedState else { return }
        publishedState = state
        continuation?.yield(snapshot)
    }
}
