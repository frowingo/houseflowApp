import Combine
import Foundation
import UIKit

@MainActor
final class HouseRocketsViewModel: ObservableObject {
    @Published private(set) var snapshot: HouseRocketsSnapshot?
    @Published var botCount = 3

    private let service: any HouseRocketsGameServicing
    private var commandSequence = 0
    private var lastHeading: Double?
    private var commandTask: Task<Void, Never>?

    var scene: HouseRocketsScene { service.scene }

    init(service: any HouseRocketsGameServicing) {
        self.service = service
    }

    func observe() async {
        for await incoming in service.events() {
            guard !Task.isCancelled else { return }
            guard snapshot?.matchID != incoming.matchID
                    || (snapshot?.revision ?? -1) < incoming.revision else { continue }
            if snapshot?.humanPlayer?.isAlive == true && incoming.humanPlayer?.isAlive == false {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            } else if snapshot?.phase != .ended && incoming.phase == .ended {
                UINotificationFeedbackGenerator().notificationOccurred(
                    incoming.winnerID == incoming.humanPlayer?.id ? .success : .warning
                )
            }
            snapshot = incoming
        }
    }

    func startMatch() async {
        commandSequence = 0
        lastHeading = nil
        await service.start(configuration: HouseRocketsConfiguration(botCount: botCount))
    }

    func steer(heading: Double) {
        guard heading.isFinite, let snapshot, snapshot.phase == .playing,
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
        guard let snapshot else { return }
        lastHeading = nil
        send(.restart, matchID: snapshot.matchID, playerID: nil)
    }

    func pause() {
        service.pause()
    }

    func resume() { service.resume() }
    func setReduceMotion(_ enabled: Bool) { service.setReduceMotion(enabled) }

    func stop() {
        lastHeading = nil
        commandTask?.cancel()
        commandTask = nil
        service.disconnect()
        snapshot = nil
    }

    private func send(_ action: HouseRocketsAction, matchID: UUID, playerID: UUID?) {
        commandSequence += 1
        let command = HouseRocketsCommand(
            matchID: matchID,
            playerID: playerID,
            sequence: commandSequence,
            action: action
        )
        let previous = commandTask
        commandTask = Task { [service] in
            await previous?.value
            guard !Task.isCancelled else { return }
            await service.send(command)
        }
    }
}
