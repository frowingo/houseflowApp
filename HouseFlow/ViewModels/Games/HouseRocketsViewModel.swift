import Combine
import Foundation
import UIKit

@MainActor
final class HouseRocketsViewModel: ObservableObject {
    @Published private(set) var snapshot: HouseRocketsSnapshot?
    @Published private(set) var selectedMode: HouseRocketsMode?
    @Published private(set) var context: HouseRocketsLaunchContext
    @Published private(set) var onlineState = HouseRocketsOnlineLobbyState()
    @Published private(set) var onlinePresentation: HouseRocketsOnlinePresentation?
    var onlineFrame: HouseRocketsRenderFrame? { onlinePresentation?.frame }
    @Published var botCount = 3

    let scene: HouseRocketsScene
    private let sessionFactory: HouseRocketsSessionFactory
    private var service: (any HouseRocketsGameServicing)?
    private var onlineLobby: HouseRocketsOnlineLobby?
    private var onlineFlight: HouseRocketsOnlineFlight?
    private var reduceMotion = false
    private var isForeground = true
    private var isLandscape = false
    private var observationTask: Task<Void, Never>?
    private var generation = UUID()
    private var commandSequence = 0
    private var lastHeading: Double?
    private var pendingCommand: HouseRocketsCommand?
    private var commandTask: Task<Void, Never>?

    var onlineBlocker: HouseRocketsOnlineBlocker? {
        guard let playerID = context.localPlayerID, !playerID.isEmpty else { return .signInRequired }
        guard let houseID = context.houseID, !houseID.isEmpty else { return .houseRequired }
        return sessionFactory.makeOnlineSession == nil ? .serviceUnavailable : nil
    }

    init(sessionFactory: HouseRocketsSessionFactory, context: HouseRocketsLaunchContext,
         scene: HouseRocketsScene? = nil) {
        self.sessionFactory = sessionFactory
        self.context = context
        self.scene = scene ?? HouseRocketsScene(size: CGSize(width: 1_180, height: 640))
    }

    deinit {
        observationTask?.cancel()
        commandTask?.cancel()
    }

    func selectMode(_ mode: HouseRocketsMode) {
        guard snapshot == nil, onlineLobby == nil else { return }
        selectedMode = mode
        if mode == .housemates { connectOnline() }
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

    func retryOnline() {
        guard selectedMode == .housemates,
              onlineState.canReconnect(at: ProcessInfo.processInfo.systemUptime) else { return }
        connectOnline()
    }

    func setLandscape(_ landscape: Bool) {
        isLandscape = landscape
        onlineLobby?.setLandscape(landscape)
    }

    func setForeground(_ active: Bool) {
        isForeground = active
        onlineLobby?.setForeground(active)
    }

    func setOnlineReady(_ ready: Bool) { onlineLobby?.setReady(ready) }

    @discardableResult
    func leaveOnline() async -> Bool {
        let expected = generation
        await onlineLobby?.leave()
        guard generation == expected else { return false }
        stop()
        return true
    }

    private func connectOnline() {
        guard onlineBlocker == nil, let makeSession = sessionFactory.makeOnlineSession else { return }
        generation = UUID()
        observationTask?.cancel()
        onlineFlight?.disconnect()
        onlineLobby?.disconnect()
        onlinePresentation = nil
        onlineState = HouseRocketsOnlineLobbyState()
        scene.reset()
        let lobby = HouseRocketsOnlineLobby(session: makeSession(), context: context)
        onlineLobby = lobby
        let expected = generation
        let flight = HouseRocketsOnlineFlight(localPlayerID: context.localPlayerID ?? "",
            send: { [weak lobby] message, grant in
                guard let lobby else { throw CancellationError() }
                try await lobby.sendSteering(message, grant: grant)
            }, resync: { [weak lobby] in lobby?.resyncGameplay() })
        onlineFlight = flight
        flight.setReduceMotion(reduceMotion)
        flight.onEliminations = { [weak self] eliminated in
            guard let self, self.generation == expected else { return }
            if eliminated.contains(where: { $0.playerID == self.context.localPlayerID }) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
            }
        }
        lobby.onGameplayRejected = { [weak flight] id, rejection in
            flight?.reject(messageID: id, rejection: rejection)
        }
        lobby.onStateChange = { [weak self, weak flight, weak lobby] state in
            guard let self, let flight, self.generation == expected else { return }
            do { try flight.consume(state) }
            catch { lobby?.invalidateGameplay(); return }
            self.onlineState = state
            if state.connection == .failed {
                self.onlinePresentation = nil
                self.scene.reset()
            } else if let frame = self.sampleOnlineFrame() {
                self.scene.applyFrame(frame)
            }
        }
        scene.frameProvider = { [weak self] in self?.sampleOnlineFrame() }
        flight.start()
        lobby.start(isForeground: isForeground, isLandscape: isLandscape)
    }

    private func sampleOnlineFrame() -> HouseRocketsRenderFrame? {
        let presentation = onlineFlight?.presentation()
        if presentation != onlinePresentation { onlinePresentation = presentation }
        return presentation?.frame
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
        if selectedMode == .housemates { onlineFlight?.steer(screenHeading: heading); return }
        guard heading.isFinite, selectedMode == .localBots,
              let snapshot, snapshot.phase == .playing,
              let human = snapshot.humanPlayer, human.isAlive else { return }
        if let previous = lastHeading,
           abs(atan2(sin(heading - previous), cos(heading - previous))) < 0.01 { return }
        lastHeading = heading
        send(.steer(heading: heading), matchID: snapshot.matchID, playerID: human.id)
    }

    // A fresh touch must be able to reapply the same screen direction after a course turn.
    func endSteering() {
        lastHeading = nil
        onlineFlight?.endSteering()
    }

    func adjustHeading(by amount: Double) {
        if selectedMode == .housemates { onlineFlight?.adjustHeading(by: amount); return }
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

    func setReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
        scene.setReduceMotion(enabled)
        onlineFlight?.setReduceMotion(enabled)
    }

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
        onlineFlight?.disconnect()
        onlineFlight = nil
        onlineLobby?.disconnect()
        onlineLobby = nil
        onlineState = HouseRocketsOnlineLobbyState()
        onlinePresentation = nil
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
