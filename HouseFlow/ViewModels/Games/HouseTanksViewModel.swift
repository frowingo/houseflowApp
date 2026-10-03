import Combine
import Foundation
import UIKit

@MainActor
final class HouseTanksViewModel: ObservableObject {
    @Published private(set) var snapshot: HouseTanksSnapshot?
    @Published var difficulty: HouseTanksDifficulty = .normal
    @Published var humanColor: HouseTanksColor = .teal

    private let service: any HouseTanksGameServicing
    private var commandSequence = 0
    private var isPressing = false
    private var commandTask: Task<Void, Never>?

    var scene: HouseTanksScene { service.scene }

    init(service: any HouseTanksGameServicing) {
        self.service = service
    }

    func observe() async {
        for await incoming in service.events() {
            guard !Task.isCancelled else { return }
            guard snapshot?.matchID != incoming.matchID
                    || (snapshot?.revision ?? -1) < incoming.revision else { continue }
            playFeedback(previous: snapshot, incoming: incoming)
            snapshot = incoming
        }
    }

    func startMatch() async {
        commandSequence = 0
        isPressing = false
        await service.start(configuration: HouseTanksMatchConfiguration(
            difficulty: difficulty,
            humanColor: humanColor
        ))
    }

    func beginPress() {
        guard let snapshot, snapshot.phase == .playing,
              let playerID = snapshot.humanPlayer?.id,
              !isPressing else { return }
        isPressing = true
        commandSequence += 1
        let command = HouseTanksCommand(
            matchID: snapshot.matchID,
            playerID: playerID,
            sequence: commandSequence,
            action: .pressStarted
        )
        enqueue(command)
    }

    func endPress() {
        guard isPressing else { return }
        isPressing = false
        guard let snapshot, let playerID = snapshot.humanPlayer?.id else { return }
        commandSequence += 1
        let command = HouseTanksCommand(
            matchID: snapshot.matchID,
            playerID: playerID,
            sequence: commandSequence,
            action: .pressEnded
        )
        enqueue(command)
    }

    func performAccessiblePress() {
        beginPress()
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 420_000_000)
            guard !Task.isCancelled else { return }
            self?.endPress()
        }
    }

    func nextRound() {
        sendSystemAction(.nextRound)
    }

    func restartMatch() {
        isPressing = false
        commandSequence = 0
        sendSystemAction(.restartMatch)
    }

    func pause() {
        service.pause()
    }

    func resume() {
        service.resume()
    }

    func setReduceMotion(_ enabled: Bool) {
        service.setReduceMotion(enabled)
    }

    func stop() {
        isPressing = false
        commandTask?.cancel()
        commandTask = nil
        service.disconnect()
        snapshot = nil
    }

    var timeLabel: String {
        guard let snapshot else { return "60" }
        return "\(Int(ceil(snapshot.timeRemaining)))"
    }

    private func sendSystemAction(_ action: HouseTanksAction) {
        guard let snapshot else { return }
        commandSequence += 1
        let command = HouseTanksCommand(
            matchID: snapshot.matchID,
            playerID: nil,
            sequence: commandSequence,
            action: action
        )
        enqueue(command)
    }

    private func enqueue(_ command: HouseTanksCommand) {
        let previous = commandTask
        commandTask = Task { [service] in
            await previous?.value
            guard !Task.isCancelled else { return }
            await service.send(command)
        }
    }

    private func playFeedback(
        previous: HouseTanksSnapshot?,
        incoming: HouseTanksSnapshot
    ) {
        if let oldHuman = previous?.humanPlayer,
           let newHuman = incoming.humanPlayer,
           newHuman.armor < oldHuman.armor {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.72)
        }

        guard previous?.phase != incoming.phase else { return }
        switch incoming.phase {
        case .roundEnded:
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        case .matchEnded:
            UINotificationFeedbackGenerator().notificationOccurred(
                incoming.championID == incoming.humanPlayer?.id ? .success : .warning
            )
        default:
            break
        }
    }
}
