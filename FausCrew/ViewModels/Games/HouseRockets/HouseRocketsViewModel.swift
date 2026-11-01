import Combine
import Foundation
import FausCrewCore
import UIKit

@MainActor
final class HouseRocketsViewModel: ObservableObject {
    @Published private(set) var snapshot: HouseRocketsSnapshot?
    @Published private(set) var selectedMode: HouseRocketsMode?
    @Published private(set) var context: HouseRocketsLaunchContext
    @Published private(set) var onlineState = HouseRocketsOnlineLobbyState()
    @Published private(set) var onlinePresentation: HouseRocketsOnlinePresentation?
    @Published private(set) var onlineResultState = HouseRocketsOnlineResultState()
    @Published private(set) var catalogAvailability = HouseRocketsCatalogAvailability.unknown
    var onlineFrame: HouseRocketsRenderFrame? { onlinePresentation?.frame }
    @Published var botCount = 3

    let scene: HouseRocketsScene
    let preferredFramesPerSecond: Int
    private let acceptanceRecorder: HouseRocketsAcceptanceRecorder?
    private var presentationCadence = HouseRocketsPresentationCadence()
    private let sessionFactory: HouseRocketsSessionFactory
    private var service: (any HouseRocketsGameServicing)?
    /// The current online match, run by FausCrewCore's engine (shared with Android).
    private var onlineHost: HouseRocketsOnlineHost?
    private var leaveWaiters: [CheckedContinuation<Void, Never>] = []
    private var previousOnlineSessionID: String?
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
        guard sessionFactory.makeOnlineHost != nil else { return .serviceUnavailable }
        return catalogAvailability == .unavailable ? .gameUnavailable : nil
    }

    /// Reads the server catalog for the current house. A failed read keeps the
    /// last answer: the session request is still guarded by the server.
    func refreshCatalog() async {
        guard let houseID = context.houseID, !houseID.isEmpty,
              let loadCatalog = sessionFactory.loadCatalog else { return }
        guard let catalog = try? await loadCatalog(houseID), context.houseID == houseID else { return }
        catalogAvailability = catalog.houseRockets.map { .available(maximumPlayers: $0.rules.maximumPlayers) }
            ?? .unavailable
    }

    var requiresAuthentication: Bool {
        if case .http(401, _) = onlineResultState.failure { return true }
        return onlineState.requiresAuthentication
    }

    init(sessionFactory: HouseRocketsSessionFactory, context: HouseRocketsLaunchContext,
         scene: HouseRocketsScene? = nil) {
        self.sessionFactory = sessionFactory
        self.context = context
        self.scene = scene ?? HouseRocketsScene(size: CGSize(width: 1_180, height: 640))
        let configuration = HouseRocketsAcceptanceConfiguration.current
        preferredFramesPerSecond = configuration.requestedFramesPerSecond
        acceptanceRecorder = configuration.isEnabled ? HouseRocketsAcceptanceRecorder(configuration: configuration) : nil
        if let recorder = acceptanceRecorder {
            self.scene.onRenderedFrame = { [weak recorder] time, maximumFPS in
                recorder?.renderedFrame(at: time, screenMaximumFPS: maximumFPS)
            }
        }
    }

    deinit {
        observationTask?.cancel()
        commandTask?.cancel()
    }

    func selectMode(_ mode: HouseRocketsMode) {
        guard snapshot == nil, onlineHost == nil else { return }
        selectedMode = mode
        acceptanceRecorder?.begin(mode: mode)
        if mode == .housemates { connectOnline() }
    }

    func returnToModeSelection() {
        stop()
        selectedMode = nil
    }

    func updateContext(_ newContext: HouseRocketsLaunchContext) {
        guard newContext != context else { return }
        returnToModeSelection()
        if newContext.houseID != context.houseID { catalogAvailability = .unknown }
        context = newContext
    }

    func retryOnline() {
        guard selectedMode == .housemates,
              onlineState.canReconnect(at: ProcessInfo.processInfo.systemUptime) else { return }
        onlineHost?.perform { $0.retry(now: $1) }
    }

    func setLandscape(_ landscape: Bool) {
        isLandscape = landscape
        onlineHost?.perform { $0.setLandscape(landscape, now: $1) }
    }

    func setForeground(_ active: Bool) {
        isForeground = active
        acceptanceRecorder?.setForeground(active)
        onlineHost?.perform { $0.setForeground(active, now: $1) }
    }

    func setOnlineReady(_ ready: Bool) { onlineHost?.perform { $0.setReady(ready, now: $1) } }
    func cancelOnlineMatch() { onlineHost?.perform { $0.cancelMatch(now: $1) } }
    func retryOnlineResult() { onlineHost?.perform { $0.retryResult(now: $1) } }
    func reclaimOnlineControl() { onlineHost?.perform { $0.reclaimControl(now: $1) } }

    func rematchOnline() {
        guard selectedMode == .housemates, onlineResultState.canRematch,
              let oldSessionID = onlineResultState.sessionID else { return }
        connectOnline(excludingSessionID: oldSessionID)
    }

    /// Explicit exit: a business leave through the engine, then cleanup. Returns false
    /// when a newer match replaced this one meanwhile.
    @discardableResult
    func leaveOnline() async -> Bool {
        let expected = generation
        if let host = onlineHost, !host.engine.isClosed {
            host.perform { $0.leave(now: $1) }
            if !host.engine.isClosed {
                // The engine closes after the confirmation or its two-second limit.
                await withCheckedContinuation { leaveWaiters.append($0) }
            }
        }
        guard generation == expected else { return false }
        stop()
        return true
    }

    private func connectOnline(excludingSessionID: String? = nil) {
        guard onlineBlocker == nil, let makeHost = sessionFactory.makeOnlineHost else { return }
        generation = UUID()
        previousOnlineSessionID = excludingSessionID
        observationTask?.cancel()
        disposeOnline()
        onlinePresentation = nil
        presentationCadence = .init()
        if excludingSessionID != nil { acceptanceRecorder?.begin(mode: .housemates) }
        onlineState = HouseRocketsOnlineLobbyState()
        onlineResultState = HouseRocketsOnlineResultState()
        scene.reset()
        let host = makeHost(context, excludingSessionID)
        onlineHost = host
        let expected = generation
        host.onLobbyChange = { [weak self] state in
            guard let self, self.generation == expected else { return }
            self.acceptanceRecorder?.consume(state)
            if self.onlineState != state { self.onlineState = state }
            if let frame = self.sampleOnlineFrame() { self.scene.applyFrame(frame) }
        }
        host.onResultChange = { [weak self] state in
            guard let self, self.generation == expected else { return }
            let couldRematch = self.onlineResultState.canRematch
            self.onlineResultState = state
            if state.canRematch {
                if !couldRematch { self.acceptanceRecorder?.flush(.result) }
                self.scene.frameProvider = nil
            }
        }
        host.onHaptic = { haptic in
            UINotificationFeedbackGenerator().notificationOccurred(haptic == .success ? .success : .warning)
        }
        host.onClosed = { [weak self] in self?.resumeLeaveWaiters() }
        host.perform { engine, _ in engine.setReduceMotion(reduceMotion) }
        scene.frameProvider = { [weak self] in self?.sampleOnlineFrame() }
        host.start(isForeground: isForeground, isLandscape: isLandscape)
    }

    private func sampleOnlineFrame() -> HouseRocketsRenderFrame? {
        let presentation = onlineHost?.presentation()
        if presentationCadence.shouldPublish(presentation, at: ProcessInfo.processInfo.systemUptime) {
            onlinePresentation = presentation
        }
        return presentation?.frame
    }

    private func disposeOnline() {
        onlineHost?.dispose()
        onlineHost = nil
        resumeLeaveWaiters()
    }

    private func resumeLeaveWaiters() {
        let waiters = leaveWaiters
        leaveWaiters.removeAll()
        waiters.forEach { $0.resume() }
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
        if selectedMode == .housemates { onlineHost?.perform { $0.steer(screenHeading: heading, now: $1) }; return }
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
        onlineHost?.perform { engine, _ in engine.endSteering() }
    }

    func adjustHeading(by amount: Double) {
        if selectedMode == .housemates { onlineHost?.perform { $0.adjustHeading(by: amount, now: $1) }; return }
        steer(heading: (lastHeading ?? snapshot?.humanPlayer?.heading ?? 0) + amount)
    }

    func restart() {
        guard selectedMode == .localBots, let snapshot, snapshot.phase == .ended else { return }
        acceptanceRecorder?.begin(mode: .localBots)
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
        acceptanceRecorder?.setReduceMotion(enabled)
        scene.setReduceMotion(enabled)
        onlineHost?.perform { engine, _ in engine.setReduceMotion(enabled) }
    }

    func stop() {
        acceptanceRecorder?.flush(.stop)
        generation = UUID()
        lastHeading = nil
        pendingCommand = nil
        commandTask?.cancel()
        commandTask = nil
        observationTask?.cancel()
        observationTask = nil
        service?.disconnect()
        service = nil
        disposeOnline()
        onlineState = HouseRocketsOnlineLobbyState()
        onlinePresentation = nil
        presentationCadence = .init()
        onlineResultState = HouseRocketsOnlineResultState()
        snapshot = nil
        previousOnlineSessionID = nil
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
