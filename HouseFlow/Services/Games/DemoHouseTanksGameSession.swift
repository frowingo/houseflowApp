import CoreGraphics
import Foundation
import SpriteKit

@MainActor
final class DemoHouseTanksGameSession: HouseTanksGameServicing {
    let scene: HouseTanksScene

    private var snapshot: HouseTanksSnapshot?
    private var configuration = HouseTanksMatchConfiguration.demo
    private var continuation: AsyncStream<HouseTanksSnapshot>.Continuation?
    private var countdownTask: Task<Void, Never>?
    private var clockTask: Task<Void, Never>?
    private var botTask: Task<Void, Never>?
    private var botReleaseTasks: [UUID: Task<Void, Never>] = [:]
    private var botControllers: [UUID: HouseTanksBotController] = [:]
    private var lastSequence: [UUID: Int] = [:]
    private var activePresses = Set<UUID>()
    private var invulnerableUntil: [UUID: TimeInterval] = [:]
    private var isResolvingRound = false

    init(scene: HouseTanksScene = HouseTanksScene(size: CGSize(width: 1_180, height: 640))) {
        self.scene = scene
        scene.scaleMode = .resizeFill
        scene.onTankHit = { [weak self] targetID, ownerID in
            Task { @MainActor in
                self?.receiveHit(targetID: targetID, ownerID: ownerID)
            }
        }
    }

    deinit {
        countdownTask?.cancel()
        clockTask?.cancel()
        botTask?.cancel()
        botReleaseTasks.values.forEach { $0.cancel() }
    }

    func events() -> AsyncStream<HouseTanksSnapshot> {
        continuation?.finish()
        return AsyncStream { continuation in
            self.continuation = continuation
            if let snapshot {
                continuation.yield(snapshot)
            }
        }
    }

    func start(configuration: HouseTanksMatchConfiguration) async {
        cancelTasks()
        self.configuration = configuration
        lastSequence.removeAll()
        activePresses.removeAll()
        invulnerableUntil.removeAll()
        isResolvingRound = false

        let players = makePlayers(configuration: configuration)
        snapshot = HouseTanksSnapshot(
            matchID: UUID(),
            revision: 0,
            phase: .countdown,
            players: players,
            roundNumber: 1,
            timeRemaining: configuration.roundDuration,
            countdown: 3,
            roundWinnerID: nil,
            championID: nil
        )
        makeBotControllers(players: players)
        scene.prepareRound(players: players)
        scene.setGameplayEnabled(false)
        scene.setSimulationPaused(false)
        publish()
        beginCountdown()
    }

    func send(_ command: HouseTanksCommand) async {
        guard let snapshot, snapshot.matchID == command.matchID else { return }

        switch command.action {
        case .pressStarted:
            guard snapshot.phase == .playing,
                  let playerID = command.playerID,
                  snapshot.players.contains(where: { $0.id == playerID && $0.isAlive }),
                  !activePresses.contains(playerID),
                  command.sequence > (lastSequence[playerID] ?? -1) else { return }
            lastSequence[playerID] = command.sequence
            activePresses.insert(playerID)
            _ = scene.beginPress(playerID: playerID)

        case .pressEnded:
            guard let playerID = command.playerID,
                  command.sequence > (lastSequence[playerID] ?? -1) else { return }
            lastSequence[playerID] = command.sequence
            activePresses.remove(playerID)
            scene.endPress(playerID: playerID)

        case .nextRound:
            guard snapshot.phase == .roundEnded else { return }
            beginNextRound()

        case .restartMatch:
            guard snapshot.phase == .matchEnded || snapshot.phase == .roundEnded else { return }
            await start(configuration: configuration)
        }
    }

    func pause() {
        guard var snapshot, snapshot.phase == .playing else { return }
        snapshot.phase = .paused
        self.snapshot = snapshot
        scene.setSimulationPaused(true)
        publish()
    }

    func resume() {
        guard var snapshot, snapshot.phase == .paused else { return }
        snapshot.phase = .playing
        self.snapshot = snapshot
        scene.setSimulationPaused(false)
        publish()
    }

    func setReduceMotion(_ enabled: Bool) {
        scene.setReduceMotion(enabled)
    }

    func disconnect() {
        cancelTasks()
        scene.stopMatch()
        continuation?.finish()
        continuation = nil
        snapshot = nil
        botControllers.removeAll()
        activePresses.removeAll()
        lastSequence.removeAll()
        invulnerableUntil.removeAll()
    }

    private func beginCountdown() {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            for value in [3, 2, 1] {
                guard !Task.isCancelled, var current = self.snapshot,
                      current.phase == .countdown else { return }
                current.countdown = value
                self.snapshot = current
                self.publish()
                try? await Task.sleep(nanoseconds: 720_000_000)
            }

            guard !Task.isCancelled, var current = self.snapshot,
                  current.phase == .countdown else { return }
            current.phase = .playing
            current.countdown = nil
            self.snapshot = current
            self.scene.setGameplayEnabled(true)
            self.publish()
            self.startClock()
            self.startBots()
        }
    }

    private func startClock() {
        clockTask?.cancel()
        clockTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 100_000_000)
                guard let self, var current = self.snapshot else { return }

                if current.phase == .paused { continue }
                guard current.phase == .playing else { return }

                current.timeRemaining = max(0, current.timeRemaining - 0.1)
                self.snapshot = current
                self.publish()

                if current.timeRemaining <= 0 {
                    self.evaluateRound(timeExpired: true)
                    return
                }
            }
        }
    }

    private func startBots() {
        botTask?.cancel()
        botTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                let delay = self.botControllers.values.first?
                    .decisionDelay(for: self.configuration.difficulty) ?? 250_000_000
                try? await Task.sleep(nanoseconds: delay)
                guard !Task.isCancelled, let current = self.snapshot else { return }
                if current.phase == .paused { continue }
                guard current.phase == .playing else { return }

                for (playerID, controller) in self.botControllers {
                    guard current.players.contains(where: { $0.id == playerID && $0.isAlive }),
                          !self.activePresses.contains(playerID) else { continue }
                    let observation = self.scene.botObservation(for: playerID)
                    guard controller.shouldFire(
                        observation: observation,
                        difficulty: self.configuration.difficulty
                    ) else { continue }
                    self.sendBotPress(playerID: playerID, controller: controller)
                }
            }
        }
    }

    private func sendBotPress(playerID: UUID, controller: HouseTanksBotController) {
        guard let snapshot else { return }
        let sequence = (lastSequence[playerID] ?? 0) + 1
        let command = HouseTanksCommand(
            matchID: snapshot.matchID,
            playerID: playerID,
            sequence: sequence,
            action: .pressStarted
        )
        Task { [weak self] in
            await self?.send(command)
        }

        botReleaseTasks[playerID]?.cancel()
        let holdDuration = controller.holdDuration(for: configuration.difficulty)
        botReleaseTasks[playerID] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: holdDuration)
            guard !Task.isCancelled, let self, let current = self.snapshot else { return }
            let release = HouseTanksCommand(
                matchID: current.matchID,
                playerID: playerID,
                sequence: (self.lastSequence[playerID] ?? sequence) + 1,
                action: .pressEnded
            )
            await self.send(release)
            self.botReleaseTasks[playerID] = nil
        }
    }

    private func receiveHit(targetID: UUID, ownerID: UUID) {
        guard !isResolvingRound, var snapshot, snapshot.phase == .playing else { return }
        let now = Date.timeIntervalSinceReferenceDate
        guard now >= (invulnerableUntil[targetID] ?? 0) else { return }
        invulnerableUntil[targetID] = now + 0.36

        snapshot.players = HouseTanksMatchRules.applyingDamage(
            to: snapshot.players,
            targetID: targetID
        )
        self.snapshot = snapshot
        scene.showHit(playerID: targetID)

        if snapshot.players.first(where: { $0.id == targetID })?.isAlive == false {
            scene.eliminate(playerID: targetID)
        }

        publish()
        evaluateRound(timeExpired: false)
    }

    private func evaluateRound(timeExpired: Bool) {
        guard !isResolvingRound, let snapshot, snapshot.phase == .playing else { return }

        switch HouseTanksMatchRules.resolveRound(players: snapshot.players, timeExpired: timeExpired) {
        case .ongoing:
            return
        case .draw:
            finishRound(winnerID: nil)
        case .winner(let winnerID):
            finishRound(winnerID: winnerID)
        }
    }

    private func finishRound(winnerID: UUID?) {
        guard var snapshot else { return }
        isResolvingRound = true
        clockTask?.cancel()
        botTask?.cancel()
        cancelBotReleaseTasks()
        scene.freezeActors()
        activePresses.removeAll()

        snapshot.players = HouseTanksMatchRules.awardingRound(
            to: winnerID,
            players: snapshot.players
        )
        snapshot.roundWinnerID = winnerID
        snapshot.championID = HouseTanksMatchRules.champion(
            in: snapshot.players,
            winsNeeded: configuration.roundWinsNeeded
        )
        snapshot.phase = snapshot.championID == nil ? .roundEnded : .matchEnded
        self.snapshot = snapshot
        publish()
    }

    private func beginNextRound() {
        guard var snapshot else { return }
        isResolvingRound = false
        invulnerableUntil.removeAll()
        activePresses.removeAll()

        snapshot.roundNumber += 1
        snapshot.timeRemaining = configuration.roundDuration
        snapshot.roundWinnerID = nil
        snapshot.countdown = 3
        snapshot.phase = .countdown
        snapshot.players = snapshot.players.map { player in
            var reset = player
            reset.armor = configuration.armorPerRound
            reset.isAlive = true
            return reset
        }
        self.snapshot = snapshot
        scene.prepareRound(players: snapshot.players)
        scene.setGameplayEnabled(false)
        publish()
        beginCountdown()
    }

    private func makePlayers(
        configuration: HouseTanksMatchConfiguration
    ) -> [HouseTanksPlayer] {
        let botColors = HouseTanksColor.allCases.filter { $0 != configuration.humanColor }
        return [
            HouseTanksPlayer(
                id: UUID(),
                nameKey: "house_tanks_you",
                role: .human,
                color: configuration.humanColor,
                armor: configuration.armorPerRound,
                roundsWon: 0,
                isAlive: true
            ),
            HouseTanksPlayer(
                id: UUID(),
                nameKey: "house_tanks_bot_one",
                role: .bot,
                color: botColors[0],
                armor: configuration.armorPerRound,
                roundsWon: 0,
                isAlive: true
            ),
            HouseTanksPlayer(
                id: UUID(),
                nameKey: "house_tanks_bot_two",
                role: .bot,
                color: botColors[1],
                armor: configuration.armorPerRound,
                roundsWon: 0,
                isAlive: true
            ),
        ]
    }

    private func makeBotControllers(players: [HouseTanksPlayer]) {
        botControllers = Dictionary(uniqueKeysWithValues: players.compactMap { player in
            guard player.role == .bot else { return nil }
            return (player.id, HouseTanksBotController(playerID: player.id))
        })
    }

    private func publish() {
        guard var snapshot else { return }
        snapshot.revision += 1
        self.snapshot = snapshot
        continuation?.yield(snapshot)
    }

    private func cancelTasks() {
        countdownTask?.cancel()
        clockTask?.cancel()
        botTask?.cancel()
        cancelBotReleaseTasks()
        countdownTask = nil
        clockTask = nil
        botTask = nil
    }

    private func cancelBotReleaseTasks() {
        botReleaseTasks.values.forEach { $0.cancel() }
        botReleaseTasks.removeAll()
    }
}
