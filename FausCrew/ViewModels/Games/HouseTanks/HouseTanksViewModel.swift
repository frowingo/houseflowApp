import Combine
import Foundation
import UIKit
import FausCrewCore

@MainActor
final class HouseTanksViewModel: ObservableObject {
    @Published private(set) var snapshot: HouseTanksSnapshot?
    @Published var difficulty: HouseTanksDifficulty?
    @Published var humanColor: HouseTanksColor?
    @Published var mapID: HouseTanksMapID?
    /// Tanks in the match, the human included; asked only on maps with a player range.
    @Published var playerCount: Int?
    @Published private(set) var selectedMode: HouseTanksMode?
    @Published private(set) var onlineMapID: HouseTanksMapID?

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

    /// The arena the next match uses: the player's pick in demo, the drawn one online.
    var matchMapID: HouseTanksMapID? {
        selectedMode == .online ? onlineMapID : mapID
    }

    /// The picks this setup asks for: the player count appears only on crowded-match maps.
    var setupSteps: [HouseTanksSetupStep] {
        HouseTanksSetupStep.allCases.filter { $0 != .players || needsPlayerCount }
    }

    var needsPlayerCount: Bool {
        selectedMode != .online && mapID.map { HouseTanksMapCatalog.definition(for: $0).hasDemoPlayerChoice } == true
    }

    func isComplete(_ step: HouseTanksSetupStep) -> Bool {
        switch step {
        case .map: matchMapID != nil
        case .players: playerCount != nil
        case .color: humanColor != nil
        case .difficulty: difficulty != nil
        }
    }

    /// The first pick still missing, in the order the setup screen asks for them.
    var pendingSetupStep: HouseTanksSetupStep? {
        setupSteps.first { !isComplete($0) }
    }

    var completedSetupSteps: Int {
        setupSteps.filter(isComplete).count
    }

    func selectMode(_ mode: HouseTanksMode) {
        guard snapshot == nil else { return }
        selectedMode = mode
        // Until the online service assigns arenas, each room visit draws one locally.
        onlineMapID = mode == .online ? HouseTanksMapID.allCases.randomElement() : nil
    }

    func returnToModeSelection() {
        guard snapshot == nil else { return }
        selectedMode = nil
        onlineMapID = nil
    }

    /// Ends the match and reopens the demo setup with the same map, color and difficulty.
    func returnToDemoSetup() {
        stop()
        selectMode(.demo)
    }

    func startMatch() async {
        guard pendingSetupStep == nil, let difficulty, let humanColor, let mapID = matchMapID else { return }
        commandSequence = 0
        isPressing = false
        await service.start(configuration: HouseTanksMatchConfiguration(
            difficulty: difficulty,
            humanColor: humanColor,
            mapID: mapID,
            playerCount: needsPlayerCount ? playerCount : nil
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
