import Foundation

/// Owns local physics, bot decisions and results independently of SpriteKit.
@MainActor
final class DemoHouseRocketsSession: HouseRocketsGameServicing {
    private var simulation = HouseRocketsSimulation(playerIDs: [])
    private var snapshot: HouseRocketsSnapshot?
    private var configuration = HouseRocketsConfiguration.demo
    private var continuation: AsyncStream<HouseRocketsSnapshot>.Continuation?
    private var countdownTask: Task<Void, Never>?
    private var simulationTask: Task<Void, Never>?
    private var lastHumanSequence = -1
    private var pausedFrom: HouseRocketsPhase?
    private var lastSimulationTime: TimeInterval?
    private var lastBotUpdate = 0.0
    private let now: () -> TimeInterval

    init(now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.now = now
    }

    deinit {
        countdownTask?.cancel()
        simulationTask?.cancel()
    }

    func events() -> AsyncStream<HouseRocketsSnapshot> {
        continuation?.finish()
        return AsyncStream(bufferingPolicy: .bufferingNewest(1)) { continuation in
            self.continuation = continuation
            if let snapshot { continuation.yield(snapshot) }
        }
    }

    func start(configuration: HouseRocketsConfiguration) async {
        cancelTasks()
        self.configuration = HouseRocketsConfiguration(botCount: configuration.normalizedBotCount)
        lastHumanSequence = -1
        pausedFrom = nil
        lastSimulationTime = nil
        lastBotUpdate = 0

        let colors = HouseRocketsColor.allCases
        let botNames = ["house_rockets_bot_one", "house_rockets_bot_two", "house_rockets_bot_three"]
        let players = (0...self.configuration.normalizedBotCount).map { index in
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
        simulation = HouseRocketsSimulation(playerIDs: players.map(\.id))
        let matchID = UUID()
        var initial = HouseRocketsSnapshot(
            matchID: matchID,
            revision: 0,
            phase: .countdown,
            players: players,
            gates: [],
            speedFields: [],
            elapsedTime: 0,
            cameraX: 0,
            countdown: 3,
            winnerID: nil,
            lastEliminatedID: nil
        )
        synchronizeWorld(into: &initial)
        snapshot = initial
        publish()
        beginCountdown(from: 3, matchID: matchID)
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

        switch command.action {
        case .steer(let heading):
            guard heading.isFinite else { return }
            lastHumanSequence = command.sequence
            simulation.steer(playerID: playerID, heading: heading)
        case .restart:
            break
        }
    }

    func pause() {
        guard var current = snapshot,
              current.phase == .playing || current.phase == .countdown else { return }
        pausedFrom = current.phase
        if current.phase == .countdown { countdownTask?.cancel() }
        lastSimulationTime = nil
        current.phase = .paused
        snapshot = current
        publish()
    }

    func resume() {
        guard var current = snapshot, current.phase == .paused else { return }
        let previous = pausedFrom ?? .playing
        current.phase = previous
        snapshot = current
        pausedFrom = nil
        lastSimulationTime = now()
        publish()
        if previous == .countdown {
            beginCountdown(from: current.countdown ?? 3, matchID: current.matchID)
        }
    }

    func disconnect() {
        cancelTasks()
        continuation?.finish()
        continuation = nil
        snapshot = nil
        pausedFrom = nil
        lastSimulationTime = nil
        simulation = HouseRocketsSimulation(playerIDs: [])
    }

    private func beginCountdown(from initial: Int, matchID: UUID) {
        countdownTask?.cancel()
        countdownTask = Task { [weak self] in
            for value in stride(from: initial, through: 1, by: -1) {
                guard !Task.isCancelled, let self, var current = self.snapshot,
                      current.matchID == matchID, current.phase == .countdown else { return }
                current.countdown = value
                self.snapshot = current
                self.publish()
                try? await Task.sleep(nanoseconds: 750_000_000)
            }
            guard !Task.isCancelled, let self, var current = self.snapshot,
                  current.matchID == matchID, current.phase == .countdown else { return }
            current.phase = .playing
            current.countdown = nil
            self.snapshot = current
            self.lastSimulationTime = self.now()
            self.publish()
            self.beginSimulation(matchID: matchID)
        }
    }

    private func beginSimulation(matchID: UUID) {
        simulationTask?.cancel()
        simulationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_666_667)
                guard !Task.isCancelled, let self, var current = self.snapshot,
                      current.matchID == matchID else { return }
                if current.phase == .paused {
                    self.lastSimulationTime = nil
                    continue
                }
                guard current.phase == .playing else { return }

                let time = self.now()
                let delta = self.lastSimulationTime.map { time - $0 } ?? 0
                self.lastSimulationTime = time
                let previousAlive = Set(current.players.filter(\.isAlive).map(\.id))
                self.simulation.advance(by: delta)
                self.synchronizeWorld(into: &current)
                // Resolve after every body has completed the same physics batch.
                current.lastEliminatedID = current.players.first {
                    previousAlive.contains($0.id) && !$0.isAlive
                }?.id ?? current.lastEliminatedID
                self.snapshot = current
                if self.finishIfNeeded() { return }
                if self.simulation.elapsedTime - self.lastBotUpdate >= 0.12 {
                    self.driveBots(players: current.players)
                    self.lastBotUpdate = self.simulation.elapsedTime
                }
                self.publish()
            }
        }
    }

    private func driveBots(players: [HouseRocketsPlayer]) {
        let laneOffsets = [-18.0, 20.0, 5.0]
        for (index, player) in players.filter({ $0.role == .bot }).enumerated() where player.isAlive {
            guard let heading = simulation.botHeading(playerID: player.id, laneOffset: laneOffsets[index]) else { continue }
            simulation.steer(playerID: player.id, heading: heading)
        }
    }

    private func synchronizeWorld(into current: inout HouseRocketsSnapshot) {
        let bodies = Dictionary(uniqueKeysWithValues: simulation.bodies.map { ($0.id, $0) })
        current.players = current.players.map { player in
            guard let body = bodies[player.id] else { return player }
            var updated = player
            updated.isAlive = body.isAlive
            updated.distance = body.x - HouseRocketsSimulation.spawnX
            updated.heading = simulation.screenHeading(for: body)
            updated.worldX = body.x
            updated.worldY = body.y
            updated.speedEffect = body.speedEffect
            updated.effectRemaining = body.effectRemaining
            return updated
        }
        current.gates = simulation.gates
        current.speedFields = simulation.speedFields
        current.elapsedTime = simulation.elapsedTime
        current.cameraX = simulation.cameraX
    }

    @discardableResult
    private func finishIfNeeded() -> Bool {
        guard var current = snapshot, current.phase == .playing else { return false }
        switch HouseRocketsRules.resolve(players: current.players) {
        case .ongoing:
            return false
        case .draw:
            current.winnerID = nil
        case .winner(let id):
            current.winnerID = id
        }
        current.phase = .ended
        snapshot = current
        lastSimulationTime = nil
        publish()
        return true
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
