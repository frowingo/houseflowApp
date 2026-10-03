import CoreGraphics
import Foundation

@MainActor
final class DemoHouseRocketsSession: HouseRocketsGameServicing {
    let scene: HouseRocketsScene

    private var snapshot: HouseRocketsSnapshot?
    private var configuration = HouseRocketsConfiguration.demo
    private var continuation: AsyncStream<HouseRocketsSnapshot>.Continuation?
    private var countdownTask: Task<Void, Never>?
    private var simulationTask: Task<Void, Never>?
    private var lastHumanSequence = -1
    private var pausedFrom: HouseRocketsPhase?

    init(scene: HouseRocketsScene? = nil) {
        self.scene = scene ?? HouseRocketsScene(size: CGSize(width: 1_180, height: 640))
        self.scene.onElimination = { [weak self] playerID in
            Task { @MainActor in self?.receiveElimination(playerID) }
        }
    }

    deinit {
        countdownTask?.cancel()
        simulationTask?.cancel()
    }

    func events() -> AsyncStream<HouseRocketsSnapshot> {
        continuation?.finish()
        return AsyncStream { continuation in
            self.continuation = continuation
            if let snapshot { continuation.yield(snapshot) }
        }
    }

    func start(configuration: HouseRocketsConfiguration) async {
        cancelTasks()
        self.configuration = HouseRocketsConfiguration(
            botCount: configuration.normalizedBotCount
        )
        lastHumanSequence = -1
        pausedFrom = nil

        let colors = HouseRocketsColor.allCases
        let botNames = ["house_rockets_bot_one", "house_rockets_bot_two", "house_rockets_bot_three"]
        var players = (0...self.configuration.normalizedBotCount).map { index in
            HouseRocketsPlayer(
                id: UUID(),
                nameKey: index == 0 ? "house_rockets_you" : botNames[index - 1],
                role: index == 0 ? .human : .bot,
                color: colors[index],
                isAlive: true,
                distance: 0,
                heading: 0,
                worldX: 0,
                worldY: 0
            )
        }
        scene.prepare(players: players)
        let initialTelemetry = scene.telemetry()
        players = players.map { player in
            guard let reading = initialTelemetry[player.id] else { return player }
            var updated = player
            updated.worldX = reading.worldX
            updated.worldY = reading.worldY
            updated.speedEffect = reading.speedEffect
            updated.effectRemaining = reading.effectRemaining
            return updated
        }
        snapshot = HouseRocketsSnapshot(
            matchID: UUID(),
            revision: 0,
            phase: .countdown,
            players: players,
            gates: scene.gateStates(),
            speedFields: scene.speedFieldStates(),
            elapsedTime: 0,
            cameraX: 0,
            countdown: 3,
            winnerID: nil,
            lastEliminatedID: nil
        )
        publish()
        beginCountdown(from: 3)
    }

    func send(_ command: HouseRocketsCommand) async {
        guard let current = snapshot, command.matchID == current.matchID else { return }
        if command.action == .restart {
            guard current.phase == .ended else { return }
            await start(configuration: configuration)
            return
        }

        guard current.phase == .playing,
              let playerID = command.playerID,
              playerID == current.humanPlayer?.id,
              current.humanPlayer?.isAlive == true,
              command.sequence > lastHumanSequence else { return }
        lastHumanSequence = command.sequence

        switch command.action {
        case .steer(let heading):
            guard heading.isFinite else { return }
            scene.steer(playerID: playerID, heading: heading)
        case .restart:
            break
        }
    }

    func pause() {
        guard var current = snapshot,
              current.phase == .playing || current.phase == .countdown else { return }
        pausedFrom = current.phase
        if current.phase == .countdown { countdownTask?.cancel() }
        current.phase = .paused
        snapshot = current
        scene.setSimulationPaused(true)
        publish()
    }

    func resume() {
        guard var current = snapshot, current.phase == .paused else { return }
        let previous = pausedFrom ?? .playing
        current.phase = previous
        snapshot = current
        pausedFrom = nil
        scene.setSimulationPaused(false)
        publish()
        if previous == .countdown { beginCountdown(from: current.countdown ?? 3) }
    }

    func setReduceMotion(_ enabled: Bool) { scene.setReduceMotion(enabled) }

    func disconnect() {
        cancelTasks()
        scene.stopMatch()
        continuation?.finish()
        continuation = nil
        snapshot = nil
        pausedFrom = nil
    }

    private func beginCountdown(from initial: Int) {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            guard let self else { return }
            for value in stride(from: initial, through: 1, by: -1) {
                guard !Task.isCancelled, var current = self.snapshot,
                      current.phase == .countdown else { return }
                current.countdown = value
                self.snapshot = current
                self.publish()
                try? await Task.sleep(nanoseconds: 750_000_000)
            }
            guard !Task.isCancelled, var current = self.snapshot,
                  current.phase == .countdown else { return }
            current.phase = .playing
            current.countdown = nil
            self.snapshot = current
            self.scene.setGameplayEnabled(true)
            self.publish()
            self.beginSimulation()
        }
    }

    private func beginSimulation() {
        simulationTask?.cancel()
        simulationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 120_000_000)
                guard !Task.isCancelled, let self, var current = self.snapshot else { return }
                if current.phase == .paused { continue }
                guard current.phase == .playing else { return }

                self.synchronizeWorld(into: &current)
                self.snapshot = current
                self.driveBots(players: current.players)
                if HouseRocketsRules.resolve(players: current.players) != .ongoing {
                    self.finishIfNeeded()
                    return
                }
                self.publish()
            }
        }
    }

    private func driveBots(players: [HouseRocketsPlayer]) {
        let laneOffsets = [-18.0, 20.0, 5.0]
        for (index, player) in players.filter({ $0.role == .bot }).enumerated() where player.isAlive {
            guard let heading = scene.botHeading(for: player.id, laneOffset: laneOffsets[index]) else { continue }
            scene.steer(playerID: player.id, heading: heading)
        }
    }

    private func receiveElimination(_ id: UUID) {
        guard var current = snapshot, current.phase == .playing,
              current.players.contains(where: { $0.id == id && $0.isAlive }) else { return }
        synchronizeWorld(into: &current)
        current.lastEliminatedID = id
        snapshot = current
        finishIfNeeded()
        if snapshot?.phase == .playing { publish() }
    }

    private func synchronizeWorld(into current: inout HouseRocketsSnapshot) {
        let telemetry = scene.telemetry()
        let aliveIDs = scene.alivePlayerIDs()
        current.players = current.players.map { player in
            guard let reading = telemetry[player.id] else { return player }
            var updated = player
            updated.isAlive = aliveIDs.contains(player.id)
            updated.distance = reading.distance
            updated.heading = reading.heading
            updated.worldX = reading.worldX
            updated.worldY = reading.worldY
            updated.speedEffect = reading.speedEffect
            updated.effectRemaining = reading.effectRemaining
            return updated
        }
        current.gates = scene.gateStates()
        current.speedFields = scene.speedFieldStates()
        current.elapsedTime = scene.runElapsed
        current.cameraX = scene.cameraX
    }

    private func finishIfNeeded() {
        guard var current = snapshot, current.phase == .playing else { return }
        switch HouseRocketsRules.resolve(players: current.players) {
        case .ongoing:
            return
        case .draw:
            current.winnerID = nil
        case .winner(let id):
            current.winnerID = id
        }
        current.phase = .ended
        snapshot = current
        scene.stopMatch()
        simulationTask?.cancel()
        publish()
    }

    private func publish() {
        guard var current = snapshot else { return }
        current.revision += 1
        snapshot = current
        continuation?.yield(current)
    }

    private func cancelTasks() {
        countdownTask?.cancel()
        simulationTask?.cancel()
        countdownTask = nil
        simulationTask = nil
    }
}
