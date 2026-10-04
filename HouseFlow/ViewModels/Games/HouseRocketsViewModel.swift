import Combine
import Foundation
import UIKit

@MainActor
final class HouseRocketsViewModel: ObservableObject {
    @Published private(set) var snapshot: HouseRocketsSnapshot?
    @Published private(set) var selectedMode: HouseRocketsMode?
    @Published private(set) var context: HouseRocketsLaunchContext
    @Published var botCount = 3

    let scene: HouseRocketsScene
    private let sessionFactory: HouseRocketsSessionFactory
    private var service: (any HouseRocketsGameServicing)?
    private var observationTask: Task<Void, Never>?
    private var generation = UUID()
    private var commandSequence = 0
    private var lastHeading: Double?
    private var pendingCommand: HouseRocketsCommand?
    private var commandTask: Task<Void, Never>?

    var onlineBlocker: HouseRocketsOnlineBlocker {
        guard let playerID = context.localPlayerID, !playerID.isEmpty else { return .signInRequired }
        guard let houseID = context.houseID, !houseID.isEmpty else { return .houseRequired }
        return .serviceUnavailable
    }

    init(sessionFactory: HouseRocketsSessionFactory, context: HouseRocketsLaunchContext,
         scene: HouseRocketsScene? = nil) {
        self.sessionFactory = sessionFactory
        self.context = context
        self.scene = scene ?? HouseRocketsScene(size: CGSize(width: 1_180, height: 640))
    }

    func selectMode(_ mode: HouseRocketsMode) {
        guard snapshot == nil else { return }
        selectedMode = mode
    }

    func returnToModeSelection() {
        stop()
        selectedMode = nil
    }

    func updateContext(_ newContext: HouseRocketsLaunchContext) {
        guard newContext != context else { return }
        returnToModeSelection()
        context = newContext
    }

    func startMatch() async {
        guard selectedMode == .localBots, snapshot == nil, service == nil else { return }
        let session = sessionFactory.makeBotSession()
        service = session
        commandSequence = 0
        lastHeading = nil
        let currentGeneration = generation
        let events = session.events()
        observationTask = Task { [weak self] in
            for await incoming in events {
                guard !Task.isCancelled, let self, self.generation == currentGeneration else { return }
                self.receive(incoming)
            }
        }
        await session.start(configuration: HouseRocketsConfiguration(botCount: botCount))
    }

    private func receive(_ incoming: HouseRocketsSnapshot) {
        guard snapshot?.matchID != incoming.matchID
                || (snapshot?.revision ?? -1) < incoming.revision else { return }
        if snapshot?.humanPlayer?.isAlive == true && incoming.humanPlayer?.isAlive == false {
            UINotificationFeedbackGenerator().notificationOccurred(.warning)
        } else if snapshot?.phase != .ended && incoming.phase == .ended {
            UINotificationFeedbackGenerator().notificationOccurred(
                incoming.winnerID == incoming.humanPlayer?.id ? .success : .warning
            )
        }
        scene.applySnapshot(incoming)
        snapshot = incoming
    }

    func steer(heading: Double) {
        guard heading.isFinite, selectedMode == .localBots,
              let snapshot, snapshot.phase == .playing,
              let human = snapshot.humanPlayer, human.isAlive else { return }
        if let previous = lastHeading,
           abs(atan2(sin(heading - previous), cos(heading - previous))) < 0.01 { return }
        lastHeading = heading
        send(.steer(heading: heading), matchID: snapshot.matchID, playerID: human.id)
    }

    // A fresh touch must be able to reapply the same screen direction after a course turn.
    func endSteering() { lastHeading = nil }

    func adjustHeading(by amount: Double) {
        steer(heading: (lastHeading ?? snapshot?.humanPlayer?.heading ?? 0) + amount)
    }

    func restart() {
        guard selectedMode == .localBots, let snapshot, snapshot.phase == .ended else { return }
        lastHeading = nil
        send(.restart, matchID: snapshot.matchID, playerID: nil)
    }

    func pause() {
        guard selectedMode == .localBots else { return }
        endSteering()
        pendingCommand = nil
        service?.pause()
    }

    func resume() {
        guard selectedMode == .localBots else { return }
        service?.resume()
    }

    func setReduceMotion(_ enabled: Bool) { scene.setReduceMotion(enabled) }

    func stop() {
        generation = UUID()
        lastHeading = nil
        pendingCommand = nil
        commandTask?.cancel()
        commandTask = nil
        observationTask?.cancel()
        observationTask = nil
        service?.disconnect()
        service = nil
        snapshot = nil
        selectedMode = nil
        scene.reset()
    }

    private func send(_ action: HouseRocketsAction, matchID: UUID, playerID: UUID?) {
        guard let service else { return }
        commandSequence += 1
        pendingCommand = HouseRocketsCommand(
            matchID: matchID,
            playerID: playerID,
            sequence: commandSequence,
            action: action
        )
        guard commandTask == nil else { return }
        let currentGeneration = generation
        // At most one command is in flight and one latest intent is waiting.
        commandTask = Task { [weak self, service] in
            while !Task.isCancelled {
                guard let self, self.generation == currentGeneration else { return }
                guard let command = self.pendingCommand else { break }
                self.pendingCommand = nil
                await service.send(command)
            }
            guard let self, self.generation == currentGeneration else { return }
            self.commandTask = nil
        }
    }
}
