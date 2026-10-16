import Foundation
import HouseFlowCore

/// Schedules the shared `HouseRocketsBotMatch` on the main actor. Rules, physics,
/// bots and results live in HouseFlowCore; this type only owns timers and the stream.
@MainActor
final class DemoHouseRocketsSession: HouseRocketsGameServicing {
    private var match = HouseRocketsBotMatch()
    private var continuation: AsyncStream<HouseRocketsSnapshot>.Continuation?
    private var countdownTask: Task<Void, Never>?
    private var simulationTask: Task<Void, Never>?
    private var lastSimulationTime: TimeInterval?
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
            if let snapshot = self.match.snapshot { continuation.yield(snapshot) }
        }
    }

    func start(configuration: HouseRocketsConfiguration) async {
        cancelTasks()
        lastSimulationTime = nil
        match.start(configuration: configuration)
        publish()
        beginCountdown()
    }

    func send(_ command: HouseRocketsCommand) async {
        guard match.send(command) else { return }
        if command.action == .restart {
            cancelTasks()
            lastSimulationTime = nil
            publish()
            beginCountdown()
        }
    }

    func pause() {
        guard match.pause() else { return }
        countdownTask?.cancel()
        lastSimulationTime = nil
        publish()
    }

    func resume() {
        guard let previous = match.resume() else { return }
        lastSimulationTime = now()
        publish()
        if previous == .countdown { beginCountdown() }
    }

    func disconnect() {
        cancelTasks()
        continuation?.finish()
        continuation = nil
        lastSimulationTime = nil
        match.reset()
    }

    private func beginCountdown() {
        countdownTask?.cancel()
        guard let matchID = match.snapshot?.matchID else { return }
        countdownTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(HouseRocketsBotMatch.countdownStepSeconds * 1_000_000_000))
                guard !Task.isCancelled, let self, self.match.snapshot?.matchID == matchID,
                      self.match.phase == .countdown else { return }
                let started = self.match.advanceCountdown()
                if started { self.lastSimulationTime = self.now() }
                self.publish()
                if started {
                    self.beginSimulation(matchID: matchID)
                    return
                }
            }
        }
    }

    private func beginSimulation(matchID: UUID) {
        simulationTask?.cancel()
        simulationTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 16_666_667)
                guard !Task.isCancelled, let self, self.match.snapshot?.matchID == matchID else { return }
                if self.match.phase == .paused {
                    self.lastSimulationTime = nil
                    continue
                }
                guard self.match.phase == .playing else { return }

                let time = self.now()
                let delta = self.lastSimulationTime.map { time - $0 } ?? 0
                self.lastSimulationTime = time
                self.match.advance(by: delta)
                self.publish()
                if self.match.phase == .ended {
                    self.lastSimulationTime = nil
                    return
                }
            }
        }
    }

    private func publish() {
        guard let snapshot = match.snapshot else { return }
        continuation?.yield(snapshot)
    }

    private func cancelTasks() {
        countdownTask?.cancel()
        simulationTask?.cancel()
        countdownTask = nil
        simulationTask = nil
    }
}
