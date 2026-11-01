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
    @Published private(set) var selectedMode: HouseTanksMode?
    /// The online room, run by FausCrewCore's engine (shared with Android).
    @Published private(set) var onlineState = HouseTanksOnlineLobbyState()
    /// The server's arena from the match countdown on; the map is the server's draw.
    @Published private(set) var onlineArena: HouseTanksWorld?
    @Published private(set) var onlineCatalog = HouseTanksOnlineCatalog.unknown
    /// True from the first round countdown of an online match until the player leaves it;
    /// the screen then turns to landscape and draws `onlineScene`.
    @Published private(set) var isOnlineMatchVisible = false
    /// The bars and banners over the online arena, refreshed by the frame loop when they change.
    @Published private(set) var onlineMatch: HouseTanksOnlineMatchUI?
    /// The persisted result: finalizing, champion or cancellation, and whether a rematch may start.
    @Published private(set) var onlineResult = HouseTanksOnlineResultState()
    /// The HUD's frame rate: presentations drawn in the last second, refreshed twice a second.
    @Published private(set) var onlineFramesPerSecond: Int?
    private var lastFramesPerSecondAt = -TimeInterval.infinity
    /// A rematch's new session before its first snapshot: the room is drawn on the match screen.
    @Published private(set) var isOnlineRematchRoom = false

    /// Draws the server's arena; its frame loop asks the engine for one presentation per frame.
    let onlineScene = HouseTanksScene()

    private let service: any HouseTanksGameServicing
    private let onlineFactory: HouseTanksOnlineFactory
    private var onlineHost: HouseTanksOnlineHost?
    private var onlineContext: GameLaunchContext?
    private var onlineGeneration = UUID()
    /// The seat bar stays after the match's last presentation, under the result panel.
    private var lastOnlineSeats: [HouseTanksOnlineSeat] = []
    private var commandSequence = 0
    private var isPressing = false
    private var commandTask: Task<Void, Never>?
    private var isLandscape = false
    private var reduceMotion = false

    var scene: HouseTanksScene { service.scene }

    init(service: any HouseTanksGameServicing, onlineFactory: HouseTanksOnlineFactory = .unavailable) {
        self.service = service
        self.onlineFactory = onlineFactory
        onlineScene.onFrame = { [weak self] _ in
            MainActor.assumeIsolated { self?.renderOnlineFrame() }
        }
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

    /// The arena the next match uses: the player's pick in demo, the server's draw online.
    var matchMapID: HouseTanksMapID? {
        selectedMode == .online ? onlineMapID : mapID
    }

    var onlineMapID: HouseTanksMapID? { onlineArena?.map.id }

    /// The picks this setup asks for; a demo match is always four tanks.
    var setupSteps: [HouseTanksSetupStep] { HouseTanksSetupStep.allCases }

    func isComplete(_ step: HouseTanksSetupStep) -> Bool {
        switch step {
        case .map: matchMapID != nil
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
    }

    func returnToModeSelection() {
        guard snapshot == nil else { return }
        leaveOnlineRoom()
        selectedMode = nil
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
            mapID: mapID
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
        reduceMotion = enabled
        service.setReduceMotion(enabled)
        onlineScene.setReduceMotion(enabled)
        onlineHost?.engine.setReduceMotion(enabled)
    }

    func stop() {
        isPressing = false
        commandTask?.cancel()
        commandTask = nil
        service.disconnect()
        snapshot = nil
        leaveOnlineRoom()
    }

    // MARK: - Online room

    /// Whether this build can open rooms at all; the catalog then says whether the house has the game.
    var isOnlineServiceAvailable: Bool { onlineFactory.makeHost != nil }

    /// Reads the house's catalog. A failed read keeps the last answer: the session
    /// request is still guarded by the server.
    func refreshOnlineCatalog(houseID: String) async {
        guard let loadCatalog = onlineFactory.loadCatalog else { return }
        guard let catalog = try? await loadCatalog(houseID) else { return }
        onlineCatalog = catalog.houseTanks.map { .available(maximumPlayers: $0.rules.maximumPlayers) } ?? .unavailable
        if onlineCatalog == .unavailable { leaveOnlineRoom() }
    }

    /// Opens the room for this house and player; a different house or player replaces it.
    func enterOnlineRoom(context: GameLaunchContext) {
        guard selectedMode == .online, onlineCatalog != .unavailable,
              let makeHost = onlineFactory.makeHost else { return }
        guard onlineHost == nil || onlineContext != context else { return }
        leaveOnlineRoom()
        connectOnlineHost(makeHost: makeHost, context: context, excludingSessionID: nil)
    }

    private func connectOnlineHost(makeHost: @MainActor (GameLaunchContext, String?) -> HouseTanksOnlineHost,
                                   context: GameLaunchContext, excludingSessionID: String?) {
        onlineContext = context
        onlineGeneration = UUID()
        let expected = onlineGeneration
        let host = makeHost(context, excludingSessionID)
        onlineHost = host
        host.onLobbyChange = { [weak self, weak host] state in
            guard let self, self.onlineGeneration == expected else { return }
            if self.onlineState != state { self.onlineState = state }
            let arena = host?.engine.arena
            if self.onlineArena?.tick != arena?.tick || self.onlineArena?.map.id != arena?.map.id
                || self.onlineArena?.tanks != arena?.tanks {
                self.onlineArena = arena
            }
            if !self.isOnlineMatchVisible, let phase = state.game?.phase, phase != .countdown {
                self.isOnlineMatchVisible = true
            }
            if self.isOnlineRematchRoom, state.game != nil { self.isOnlineRematchRoom = false }
        }
        host.onResultChange = { [weak self] state in
            guard let self, self.onlineGeneration == expected, self.onlineResult != state else { return }
            self.onlineResult = state
        }
        host.onHaptic = { haptic in
            UINotificationFeedbackGenerator().notificationOccurred(haptic == .success ? .success : .warning)
        }
        host.engine.setReduceMotion(reduceMotion)
        host.start(isForeground: true, isLandscape: isLandscape)
    }

    func setOnlineReady(_ ready: Bool) { onlineHost?.perform { $0.setReady(ready, now: $1) } }
    func cancelOnlineMatch() { onlineHost?.perform { $0.cancelMatch(now: $1) } }

    func retryOnline() {
        guard onlineState.canReconnect(at: ProcessInfo.processInfo.systemUptime) else { return }
        onlineHost?.perform { $0.retry(now: $1) }
    }

    func setOnlineForeground(_ active: Bool) {
        onlineHost?.perform { $0.setForeground(active, now: $1) }
    }

    func onlineCountdown() -> Int? { onlineHost?.roomCountdown() }

    // MARK: - Online match

    /// The single button; the engine sends only changes it is allowed to send.
    func onlinePress() { onlineHost?.perform { $0.press(now: $1) } }
    func onlineRelease() { onlineHost?.perform { $0.release(now: $1) } }

    /// The button opens only in landscape (shared control rule).
    func setOnlineLandscape(_ landscape: Bool) {
        guard isLandscape != landscape else { return }
        isLandscape = landscape
        onlineHost?.perform { $0.setLandscape(landscape, now: $1) }
    }

    func reclaimOnlineControl() { onlineHost?.perform { $0.reclaimControl(now: $1) } }

    /// The vote for the next round from the in-game panel.
    func setOnlineRoundReady(_ ready: Bool) { onlineHost?.perform { $0.setRoundReady(ready, now: $1) } }
    func retryOnlineResult() { onlineHost?.perform { $0.retryResult(now: $1) } }

    /// A new session that excludes the finished one, joined from the result panel; the
    /// match screen stays and shows the new room until its first snapshot.
    func rematchOnline() {
        guard onlineResult.canRematch, let context = onlineContext, let old = onlineHost,
              let makeHost = onlineFactory.makeHost,
              let excluded = old.engine.rematchExcludedSessionID ?? onlineResult.sessionID else { return }
        old.onLobbyChange = nil
        old.onResultChange = nil
        old.onHaptic = nil
        old.dispose()
        onlineHost = nil
        onlineState = HouseTanksOnlineLobbyState()
        onlineResult = HouseTanksOnlineResultState()
        onlineArena = nil
        onlineMatch = nil
        onlineFramesPerSecond = nil
        lastFramesPerSecondAt = -.infinity
        lastOnlineSeats = []
        onlineScene.stopMatch()
        isOnlineRematchRoom = true
        connectOnlineHost(makeHost: makeHost, context: context, excludingSessionID: excluded)
    }

    /// The explicit, permanent leave from a running match; the screen returns to the modes.
    func leaveOnlineMatch() {
        leaveOnlineRoom()
        selectedMode = nil
    }

    /// The server no longer accepts this sign-in (HTTP 401); the screen signs out like House Rockets.
    var requiresOnlineSignIn: Bool {
        if case .http(401, _) = onlineResult.failure { return true }
        return onlineState.requiresAuthentication
    }

    /// Another house or account closes the room, a running match included; the lobby then
    /// opens the new house's room.
    func onlineIdentityChanged(houseID: String?, userID: String?) {
        guard onlineHost != nil, let context = onlineContext,
              context.houseID != houseID || context.localPlayerID != userID else { return }
        leaveOnlineRoom()
    }

    /// One presentation per drawn frame: the scene gets the arena, the bars get a model
    /// only when something they show changed.
    private func renderOnlineFrame() {
        guard isOnlineMatchVisible, let host = onlineHost, !host.isDisposed else { return }
        let now = host.uptime
        let presentation = host.engine.presentation(at: now)
        let localID = onlineContext?.localPlayerID
        if let presentation {
            onlineScene.render(presentation.world, roundKey: presentation.roundKey, events: presentation.events,
                               localPlayerID: localID, offlinePlayerIDs: presentation.offlinePlayerIDs)
            for event in presentation.events where event.kind == .hit {
                guard let target = event.playerID else { continue }
                onlineScene.showHit(playerID: target)
                if target == localID { UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.72) }
            }
        }
        if now - lastFramesPerSecondAt >= 0.5 {
            lastFramesPerSecondAt = now
            let fps = host.engine.displayFramesPerSecond(at: now)
            if onlineFramesPerSecond != fps { onlineFramesPerSecond = fps }
        }
        if let presentation { lastOnlineSeats = presentation.seats }
        let window = presentation?.roundPhase == .roundReady ? host.engine.roomCountdown(at: now) : nil
        let match = HouseTanksOnlineMatchUI(state: onlineState, presentation: presentation, result: onlineResult,
                                            isRematchRoom: isOnlineRematchRoom, lastSeats: lastOnlineSeats,
                                            localPlayerID: localID, windowSeconds: window,
                                            canRetry: onlineState.canReconnect(at: now))
        if onlineMatch != match { onlineMatch = match }
    }

    /// A business leave, then cleanup: the host stays alive until the server confirms
    /// or the engine's own limit closes it, so the seat is freed for the others.
    func leaveOnlineRoom() {
        guard let host = onlineHost else { return }
        onlineHost = nil
        onlineGeneration = UUID()
        onlineState = HouseTanksOnlineLobbyState()
        onlineArena = nil
        isOnlineMatchVisible = false
        isOnlineRematchRoom = false
        onlineMatch = nil
        onlineFramesPerSecond = nil
        lastFramesPerSecondAt = -.infinity
        onlineResult = HouseTanksOnlineResultState()
        lastOnlineSeats = []
        onlineScene.stopMatch()
        // A finished match (result final) has nothing to leave: its socket is already done.
        guard !host.engine.isClosed, !host.result.canRematch else { return host.dispose() }
        host.onLobbyChange = nil
        host.onHaptic = nil
        host.onClosed = { [weak host] in host?.dispose() }
        host.perform { $0.leave(now: $1) }
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            host.dispose()
        }
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

/// What the bars and banners over the online arena show; equal values skip a redraw.
struct HouseTanksOnlineMatchUI: Equatable {
    var seats: [HouseTanksOnlineSeat] = []
    var canPress = false
    var isPressed = false
    var phase: GameRuntimePhase?
    var roundPhase: HouseTanksWireRoundPhase?
    var roundNumber = 0
    /// `HouseTanksOnlineCopyKeys.matchNotice`; `noticeName` fills `{name}`.
    var noticeTitleKey: String?
    var noticeDetailKey: String?
    var noticeName: String?
    var canRetry = false
    var canReclaim = false
    var isFinished = false
    /// No tank in this match: the banner offers the way out.
    var isSpectating = false
    /// `roundReady`: the panel with the round's winner and the vote for the next one.
    var showsRoundPanel = false
    var roundTitleKey = ""
    var roundDetailKey = ""
    var roundWindowSeconds: Int?
    var canVote = false
    var isLocalReady = false
    var isVotePending = false
    var readyCount = 0
    var voterCount = 0
    /// The end menu (from the match's end, result or not) replaces every banner, the round
    /// panel and the top-left controls; `standings` is its table.
    var showsResult = false
    var standings: [HouseTanksOnlineStanding] = []
    var showsRematchRoom = false

    init(state: HouseTanksOnlineLobbyState, presentation: HouseTanksOnlinePresentation?,
         result: HouseTanksOnlineResultState = .init(), isRematchRoom: Bool = false,
         lastSeats: [HouseTanksOnlineSeat] = [], localPlayerID: String? = nil, windowSeconds: Int? = nil,
         canRetry: Bool) {
        seats = presentation?.seats ?? lastSeats
        if let presentation {
            canPress = presentation.canPress
            isPressed = presentation.isPressed
            phase = presentation.phase
            roundPhase = presentation.roundPhase
            roundNumber = presentation.roundNumber
            noticeName = presentation.seats.first { $0.playerID == presentation.roundWinnerID }?.displayName
            canVote = presentation.canVote
            isLocalReady = presentation.isLocalReady
            isVotePending = presentation.isVotePending
            readyCount = presentation.readyCount
            voterCount = presentation.voterCount
            isSpectating = presentation.isSpectating
        }
        showsResult = result.isVisible || (!isRematchRoom && HouseTanksOnlineCopyKeys.isMatchOver(state, presentation))
        if showsResult { standings = HouseTanksOnlineCopyKeys.standings(result, seats: seats) }
        showsRematchRoom = isRematchRoom && !showsResult
        let notice = showsResult || showsRematchRoom ? nil : HouseTanksOnlineCopyKeys.matchNotice(state, presentation)
        noticeTitleKey = notice?.title
        noticeDetailKey = notice?.detail
        if let presentation, presentation.roundPhase == .roundReady, presentation.phase == .playing,
           !showsResult, notice == nil {
            showsRoundPanel = true
            roundTitleKey = HouseTanksOnlineCopyKeys.roundTitle(presentation, localPlayerID: localPlayerID)
            roundDetailKey = HouseTanksOnlineCopyKeys.roundDetail(presentation, windowSeconds: windowSeconds)
            roundWindowSeconds = windowSeconds
        }
        self.canRetry = canRetry
        canReclaim = state.controlTransferred && state.connection == .connected
        isFinished = showsResult || state.isTerminal || [.ended, .cancelled].contains(phase)
    }
}

/// Whether the house's catalog lists FauseTanks; unknown until the first read.
enum HouseTanksOnlineCatalog: Equatable {
    case unknown
    case available(maximumPlayers: Int)
    case unavailable
}
