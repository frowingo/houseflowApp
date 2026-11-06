import Combine
import FausCrewCore
import Foundation
import UIKit

/// Faus Switch in two modes, like FauseTanks and House Rockets: a demo race against
/// local bots (FausCrewCore's `FausSwitchBotMatch`) and an online race run by the
/// server through `FausSwitchOnlineEngine`. One scene draws both; it asks this model
/// for a frame on every display refresh.
@MainActor
final class FausSwitchViewModel: ObservableObject {
    @Published private(set) var selectedMode: FausSwitchMode?
    /// The robot color: the demo robot, and the online request (first claim wins).
    @Published var robotColor: FausSwitchColor {
        didSet {
            guard robotColor != oldValue else { return }
            userDefaults.set(robotColor.rawValue, forKey: Self.colorKey)
            onlineHost?.perform { [robotColor] in $0.selectColor(robotColor, now: $1) }
        }
    }
    @Published var botCount = 3
    @Published private(set) var bestTime: Double?
    /// The robot's flip sounds; the HUD's speaker button toggles them (remembered).
    @Published private(set) var isSoundEnabled: Bool
    /// The background track; the HUD's music button toggles it (remembered).
    @Published private(set) var isMusicEnabled: Bool

    /// True while a demo race is on screen (countdown to result).
    @Published private(set) var isDemoVisible = false
    @Published private(set) var isPaused = false
    /// The demo result panel; dismissing it keeps watching the bots until the race ends.
    @Published private(set) var showsDemoResult = false
    @Published private(set) var isWatchingDemo = false
    /// The bars and panels over the race, refreshed only when something they show changes.
    @Published private(set) var match: FausSwitchMatchUI?

    @Published private(set) var onlineState = FausSwitchOnlineLobbyState()
    @Published private(set) var onlineCatalog = FausSwitchOnlineCatalog.unknown
    @Published private(set) var onlineResult = FausSwitchOnlineResultState()
    /// From the first race snapshot (its countdown) until the player leaves: the screen
    /// turns to landscape and draws the server's race.
    @Published private(set) var isOnlineMatchVisible = false
    @Published private(set) var isOnlineRematchRoom = false

    let scene = FausSwitchScene()
    private let audio: FausSwitchAudio
    /// Kept and prepared: creating a generator per tap can stall the frame.
    private let lightImpact = UIImpactFeedbackGenerator(style: .light)
    private let rigidImpact = UIImpactFeedbackGenerator(style: .rigid)
    private let mediumImpact = UIImpactFeedbackGenerator(style: .medium)
    private let softImpact = UIImpactFeedbackGenerator(style: .soft)
    private let notification = UINotificationFeedbackGenerator()
    private let planner = FausSwitchBotPlanner()

    private static let colorKey = "faus_switch_color"
    private static let bestTimeKey = "faus_switch_best_time"
    private let userDefaults: UserDefaults
    private let onlineFactory: FausSwitchOnlineFactory
    private var demo: FausSwitchBotMatch?
    private var onlineHost: FausSwitchOnlineHost?
    private var onlineContext: GameLaunchContext?
    private var onlineGeneration = UUID()
    private var lastOnlineFrame: FausSwitchRenderFrame?
    private var reduceMotion = false
    private var isLandscape = false

    init(onlineFactory: FausSwitchOnlineFactory = .unavailable, userDefaults: UserDefaults = .standard,
         audio: FausSwitchAudio? = nil) {
        self.onlineFactory = onlineFactory
        self.userDefaults = userDefaults
        let audio = audio ?? FausSwitchAudio(userDefaults: userDefaults)
        self.audio = audio
        isSoundEnabled = audio.isEffectsEnabled
        isMusicEnabled = audio.isMusicEnabled
        robotColor = userDefaults.string(forKey: Self.colorKey).flatMap(FausSwitchColor.init(rawValue:)) ?? .lavender
        let stored = userDefaults.double(forKey: Self.bestTimeKey)
        bestTime = stored > 0 ? stored : nil
        scene.frameProvider = { [weak self] elapsed in
            MainActor.assumeIsolated { self?.nextFrame(elapsed: elapsed) }
        }
        scene.onTap = { [weak self] in
            MainActor.assumeIsolated { self?.flip() }
        }
    }

    // MARK: - Mode

    func selectMode(_ mode: FausSwitchMode) {
        guard !isDemoVisible, !isOnlineMatchVisible else { return }
        selectedMode = mode
    }

    func returnToModeSelection() {
        guard !isDemoVisible else { return }
        leaveOnlineRoom()
        selectedMode = nil
    }

    /// Flip sounds only.
    func toggleSound() {
        audio.setEffectsEnabled(!audio.isEffectsEnabled)
        isSoundEnabled = audio.isEffectsEnabled
    }

    /// Music only.
    func toggleMusic() {
        audio.setMusicEnabled(!audio.isMusicEnabled)
        isMusicEnabled = audio.isMusicEnabled
    }

    /// The app left or returned to the foreground; a paused demo stays silent until resumed.
    func setAppActive(_ active: Bool) {
        if active {
            if !isPaused { audio.setMusicPaused(false) }
        } else {
            audio.setMusicPaused(true)
        }
    }

    func setReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
        scene.reduceMotion = enabled
    }

    /// Demo bots take the colors the player did not pick, in palette order.
    var demoBotColors: [FausSwitchColor] {
        FausSwitchColor.free(excluding: [robotColor], count: botCount)
    }

    // MARK: - Demo

    func startDemo() {
        var race = FausSwitchBotMatch(planner: planner)
        race.start(configuration: FausSwitchMatchConfiguration(humanColor: robotColor, botCount: botCount))
        demo = race
        scene.reset()
        isPaused = false
        showsDemoResult = false
        isWatchingDemo = false
        isDemoVisible = true
        match = Self.demoUI(race.frame(), canFlip: false)
        audio.startMusic()
        prepareHaptics()
    }

    func restartDemo() {
        guard demo != nil else { return startDemo() }
        startDemo()
    }

    func pauseDemo() {
        guard isDemoVisible, !isPaused, !showsDemoResult, demo?.phase != .ended else { return }
        demo?.pause()
        isPaused = true
        audio.setMusicPaused(true)
    }

    func resumeDemo() {
        guard isPaused else { return }
        demo?.resume()
        isPaused = false
        audio.setMusicPaused(false)
    }

    /// Hides the result panel and keeps the camera on the bots until the race ends.
    func watchDemo() {
        guard showsDemoResult, demo?.phase != .ended else { return }
        showsDemoResult = false
        isWatchingDemo = true
    }

    func exitDemo() {
        demo = nil
        isDemoVisible = false
        isPaused = false
        showsDemoResult = false
        isWatchingDemo = false
        match = nil
        scene.reset()
        if !isOnlineMatchVisible { audio.stopMusic() }
    }

    /// The single input: flip from a surface. Mid-air taps give a soft "no".
    func flip() {
        if isOnlineMatchVisible {
            guard let host = onlineHost, !host.isDisposed else { return }
            var feedback = FausSwitchFlipFeedback.ignored
            host.perform { feedback = $0.flip(now: $1) }
            playFlipFeedback(feedback)
            // The flip goes to the rail opposite the one last drawn (no extra presentation).
            if feedback == .flipped, let gravity = lastOnlineFrame?.localRunner?.state.gravity {
                audio.playFlip(toward: gravity.opposite)
            }
            return
        }
        guard isDemoVisible, !isPaused, demo?.phase == .playing, demo?.human?.state.isRunning == true,
              let outcome = demo?.flipHuman() else { return }
        switch outcome {
        case .flipped:
            if let gravity = demo?.human?.state.gravity { audio.playFlip(toward: gravity) }
            playFlipFeedback(.flipped)
        case .unsupported: playFlipFeedback(.unsupported)
        case .notRunning: break
        }
    }

    private func playFlipFeedback(_ feedback: FausSwitchFlipFeedback) {
        switch feedback {
        case .flipped:
            lightImpact.impactOccurred()
            lightImpact.prepare()
        case .unsupported:
            rigidImpact.impactOccurred(intensity: 0.55)
            rigidImpact.prepare()
        case .ignored: break
        }
    }

    private func prepareHaptics() {
        [lightImpact, rigidImpact, mediumImpact, softImpact].forEach { $0.prepare() }
        notification.prepare()
    }

    private func nextFrame(elapsed: TimeInterval) -> FausSwitchRenderFrame? {
        if isOnlineMatchVisible { return nextOnlineFrame() }
        guard isDemoVisible, demo != nil else { return nil }
        // Mutated in place: copying the match out and back would copy its arrays every frame.
        if !isPaused, let events = demo?.advance(by: elapsed), !events.isEmpty, let race = demo {
            handle(events, race: race)
        }
        guard let race = demo else { return nil }
        let frame = race.frame()
        let ui = Self.demoUI(frame, canFlip: race.phase == .playing && race.human?.state.isRunning == true)
        if match != ui { match = ui }
        audio.setMusicDucked(showsDemoResult)
        return frame
    }

    private func handle(_ events: [FausSwitchMatchEvent], race: FausSwitchBotMatch) {
        for event in events {
            switch event {
            case .countdown:
                softImpact.impactOccurred(intensity: 0.6)
            case .started, .humanBoosted:
                mediumImpact.impactOccurred()
                mediumImpact.prepare()
            case .humanSlowed:
                softImpact.impactOccurred(intensity: 0.9)
            case .humanTeleported:
                audio.playPortal()
                notification.notificationOccurred(.warning)
            case .humanCrashed:
                notification.notificationOccurred(.error)
                showsDemoResult = true
            case .humanFinished:
                notification.notificationOccurred(.success)
                if let tick = race.human?.state.finishedAtTick { recordBestTime(FausSwitchMetrics.seconds(tick)) }
                showsDemoResult = true
            case .ended:
                isWatchingDemo = false
                showsDemoResult = true
            }
        }
    }

    /// Online frames carry no events: a portal shows as the running robot thrown back
    /// between two frames (nothing else moves a robot backward), as the demo's
    /// `humanTeleported` detects it.
    static func wentThroughPortal(from before: FausSwitchRunnerState?, to after: FausSwitchRunnerState?) -> Bool {
        guard let before, let after, before.isRunning, after.isRunning else { return false }
        return after.x < before.x - 20
    }

    private static func demoUI(_ frame: FausSwitchRenderFrame, canFlip: Bool) -> FausSwitchMatchUI {
        var ui = FausSwitchMatchUI()
        ui.phase = frame.phase
        ui.countdown = frame.countdown
        ui.standings = FausSwitchMatchUI.standings(from: frame)
        ui.nameTags = FausSwitchMatchUI.nameTags(from: frame)
        ui.runnerCount = frame.runners.count
        ui.canFlip = canFlip
        if let local = frame.localRunner {
            ui.localStatus = FausSwitchMatchUI.status(of: local.state)
            ui.localRank = local.rank
            ui.localTime = local.state.finishedAtTick.map { FausSwitchMetrics.seconds($0) }
        }
        return ui
    }

    private func recordBestTime(_ time: Double) {
        guard time > 0, bestTime.map({ time < $0 }) ?? true else { return }
        bestTime = time
        userDefaults.set(time, forKey: Self.bestTimeKey)
    }

    // MARK: - Online room

    var isOnlineServiceAvailable: Bool { onlineFactory.makeHost != nil }

    /// Reads the house's catalog. A failed read keeps the last answer: the session
    /// request is still guarded by the server.
    func refreshOnlineCatalog(houseID: String) async {
        guard let loadCatalog = onlineFactory.loadCatalog else { return }
        guard let catalog = try? await loadCatalog(houseID) else { return }
        onlineCatalog = catalog.fausSwitch.map { .available(maximumPlayers: $0.rules.maximumPlayers) } ?? .unavailable
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

    private func connectOnlineHost(makeHost: FausSwitchOnlineFactory.MakeHost,
                                   context: GameLaunchContext, excludingSessionID: String?) {
        onlineContext = context
        onlineGeneration = UUID()
        let expected = onlineGeneration
        let host = makeHost(context, excludingSessionID, robotColor)
        onlineHost = host
        host.onLobbyChange = { [weak self] state in
            guard let self, self.onlineGeneration == expected else { return }
            if self.onlineState != state { self.onlineState = state }
            if !self.isOnlineMatchVisible, state.game != nil {
                self.scene.reset()
                self.lastOnlineFrame = nil
                self.isOnlineMatchVisible = true
                self.audio.startMusic()
                self.prepareHaptics()
            }
            if self.isOnlineRematchRoom, state.game != nil { self.isOnlineRematchRoom = false }
        }
        host.onResultChange = { [weak self] state in
            guard let self, self.onlineGeneration == expected, self.onlineResult != state else { return }
            self.onlineResult = state
        }
        host.onHaptic = { [weak self] haptic in
            self?.notification.notificationOccurred(haptic == .success ? .success : .warning)
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

    func setOnlineLandscape(_ landscape: Bool) {
        guard isLandscape != landscape else { return }
        isLandscape = landscape
        onlineHost?.perform { $0.setLandscape(landscape, now: $1) }
    }

    func onlineCountdown() -> Int? { onlineHost?.roomCountdown() }
    func reclaimOnlineControl() { onlineHost?.perform { $0.reclaimControl(now: $1) } }
    func retryOnlineResult() { onlineHost?.perform { $0.retryResult(now: $1) } }

    func canCancelOnline(context: GameLaunchContext?) -> Bool {
        guard let context else { return false }
        return onlineState.canCancel(context: context)
    }

    /// A new session that excludes the finished one; the race screen stays and shows the
    /// new room until its first snapshot.
    func rematchOnline() {
        guard onlineResult.canRematch, let context = onlineContext, let old = onlineHost,
              let makeHost = onlineFactory.makeHost,
              let excluded = old.engine.rematchExcludedSessionID ?? onlineResult.sessionID else { return }
        old.onLobbyChange = nil
        old.onResultChange = nil
        old.onHaptic = nil
        old.dispose()
        onlineHost = nil
        onlineState = FausSwitchOnlineLobbyState()
        onlineResult = FausSwitchOnlineResultState()
        match = nil
        lastOnlineFrame = nil
        scene.reset()
        audio.stopMusic()
        isOnlineMatchVisible = false
        isOnlineRematchRoom = true
        connectOnlineHost(makeHost: makeHost, context: context, excludingSessionID: excluded)
    }

    /// The explicit, permanent leave from a running race; the screen returns to the modes.
    func leaveOnlineMatch() {
        leaveOnlineRoom()
        selectedMode = nil
    }

    /// The server no longer accepts this sign-in (HTTP 401).
    var requiresOnlineSignIn: Bool {
        if case .http(401, _) = onlineResult.failure { return true }
        return onlineState.requiresAuthentication
    }

    /// Another house or account closes the room, a running race included.
    func onlineIdentityChanged(houseID: String?, userID: String?) {
        guard onlineHost != nil, let context = onlineContext,
              context.houseID != houseID || context.localPlayerID != userID else { return }
        leaveOnlineRoom()
    }

    /// The race's last frame for the result table while the persisted result is pending.
    var lastOnlineStandings: [FausSwitchStanding] {
        lastOnlineFrame.map(FausSwitchMatchUI.standings(from:)) ?? []
    }

    private func nextOnlineFrame() -> FausSwitchRenderFrame? {
        guard let host = onlineHost, !host.isDisposed else { return lastOnlineFrame }
        let now = host.uptime
        let presentation = host.engine.presentation(at: now)
        if let frame = presentation?.frame {
            if Self.wentThroughPortal(from: lastOnlineFrame?.localRunner?.state, to: frame.localRunner?.state) {
                audio.playPortal()
                notification.notificationOccurred(.warning)
            }
            lastOnlineFrame = frame
        }
        var ui = FausSwitchMatchUI()
        if let frame = presentation?.frame ?? lastOnlineFrame {
            ui = Self.demoUI(frame, canFlip: presentation?.canFlip ?? false)
        }
        if let notice = FausSwitchOnlineCopyKeys.matchNotice(onlineState, presentation) {
            ui.noticeTitleKey = notice.title
            ui.noticeDetailKey = notice.detail
            ui.noticeIsBlocking = notice.isBlocking
        }
        let raceOver = presentation?.frame.phase == .ended || onlineState.isTerminal
            || [.ended, .cancelled, .finalizing].contains(onlineState.game?.phase)
        ui.showsResult = onlineResult.isVisible || (raceOver && !isOnlineRematchRoom)
        if ui.showsResult {
            ui.noticeTitleKey = nil
            ui.noticeDetailKey = nil
        }
        ui.showsRematchRoom = isOnlineRematchRoom && !ui.showsResult
        ui.canRetry = onlineState.connection == .failed && onlineState.canReconnect(at: now)
        ui.canReclaim = onlineState.controlTransferred && onlineState.connection == .connected
        if match != ui { match = ui }
        audio.setMusicDucked(ui.showsResult || ui.noticeTitleKey != nil)
        return presentation?.frame ?? lastOnlineFrame
    }

    /// A business leave, then cleanup: the host stays alive until the server confirms
    /// or the engine's own limit closes it, so the seat is freed for the others.
    func leaveOnlineRoom() {
        guard let host = onlineHost else { return }
        onlineHost = nil
        onlineGeneration = UUID()
        onlineState = FausSwitchOnlineLobbyState()
        onlineResult = FausSwitchOnlineResultState()
        isOnlineMatchVisible = false
        isOnlineRematchRoom = false
        lastOnlineFrame = nil
        if !isDemoVisible { match = nil; audio.stopMusic() }
        scene.reset()
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

    func stop() {
        exitDemo()
        leaveOnlineRoom()
    }
}
