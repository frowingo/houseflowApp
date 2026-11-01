import Foundation

/// Online FauseTanks for one match, shared by iOS and Android, in House Rockets'
/// effect model: the platform host performs the `effects` (HTTP, WebSocket,
/// haptics), reports each outcome with the same `connection`/`request` tag and
/// calls `tick` about every 25 ms. Time is always the host's monotonic uptime.
///
/// The room and the match start: `PUT` → socket → welcome and session → join →
/// ready, and the server's arena (`arena`) from the first `countdown` snapshot on.
/// The playing match (button, display timing, events) is `presentation(at:)`, fed by
/// `press`/`release`; the screen must report landscape for the button to open.
public final class HouseTanksOnlineEngine {
    public let context: GameLaunchContext
    public private(set) var lobby = HouseTanksOnlineLobbyState()
    public private(set) var result = HouseTanksOnlineResultState()
    /// The latest snapshot's arena, drawn as is; nil before the match countdown and
    /// when this build lacks the map (then `lobby.requiresUpdate` is set).
    public private(set) var arena: HouseTanksWorld?
    /// True after `leave` finished or `disconnect`; the host leaves the screen.
    public var isClosed: Bool { lobbyMachine.isClosed && !finished }
    /// The session to exclude when the player asks for a rematch.
    public var rematchExcludedSessionID: String? { result.canRematch ? result.sessionID : nil }

    private var effects: [GameOnlineEffect] = []
    private var lobbyMachine: HouseTanksOnlineLobbyMachine!
    private var resultMachine: HouseTanksOnlineResultMachine!
    private var play: HouseTanksOnlinePlayMachine!
    private var arenaSnapshot: (epoch: Int64, sequence: Int64)?
    private var finished = false
    private var now: TimeInterval = 0
    private let configuration: HouseTanksPlayConfiguration
    private let diagnosticsRecorder = HouseTanksDiagnosticsRecorder()
    /// Debug-build network condition (F6); `.off` delivers everything at once.
    public private(set) var latencySimulation = HouseTanksLatencySimulation.off
    private let jitter: () -> Double
    private var inbound: [(text: String, connection: Int, at: TimeInterval)] = []
    private var outbound: [(effect: GameOnlineEffect, at: TimeInterval)] = []

    public init(context: GameLaunchContext, excludingSessionID: String? = nil,
                policy: GameReconnectPolicy = .init(), configuration: HouseTanksPlayConfiguration = .init(),
                makeID: @escaping () -> String = { UUID().uuidString },
                jitter: @escaping () -> Double = { Double.random(in: -1...1) }) {
        self.context = context
        self.configuration = configuration
        self.jitter = jitter
        let emit: (GameOnlineEffect) -> Void = { [weak self] in self?.effects.append($0) }
        lobbyMachine = HouseTanksOnlineLobbyMachine(context: context, excludingSessionID: excludingSessionID,
                                                    policy: policy, makeID: makeID, emit: emit)
        resultMachine = HouseTanksOnlineResultMachine(houseID: context.houseID ?? "", emit: emit)
        play = HouseTanksOnlinePlayMachine(
            localPlayerID: context.localPlayerID, configuration: configuration, diagnostics: diagnosticsRecorder,
            makeID: makeID,
            send: { [weak self] message, grant in
                guard let self else { return false }
                return self.lobbyMachine.sendGameplay(message, grant: grant, now: self.now)
            },
            resync: { [weak self] in
                guard let self else { return }
                self.lobbyMachine.resyncGameplay(now: self.now)
            })
        lobbyMachine.onGameplayRejected = { [weak self] id, rejection in
            guard let self else { return }
            self.play.reject(messageID: id, rejection: rejection, now: self.now)
        }
        lobbyMachine.onStateChange = { [weak self] state in self?.lobbyChanged(state) }
        resultMachine.onStateChange = { [weak self] state in self?.resultChanged(state) }
    }

    /// Effects produced since the last call, in order. With a latency simulation socket sends
    /// wait in order until due (released by `tick`); a closed socket loses the ones still held.
    public func drainEffects() -> [GameOnlineEffect] {
        defer { effects.removeAll() }
        guard latencySimulation.isActive || !outbound.isEmpty else { return effects }
        var passing: [GameOnlineEffect] = []
        for effect in effects {
            switch effect {
            case .send:
                let at = max(outbound.last?.at ?? 0, now + latencySimulation.delay(unit: jitter()))
                outbound.append((effect, at))
            case .closeSocket:
                outbound.removeAll()
                passing.append(effect)
            default:
                passing.append(effect)
            }
        }
        let due = outbound.prefix { $0.at <= now }.map(\.effect)
        outbound.removeFirst(due.count)
        return due + passing
    }

    /// Debug builds only (device acceptance): delays socket traffic both ways. Turning it off
    /// delivers what is held at once.
    public func setLatencySimulation(_ simulation: HouseTanksLatencySimulation, now: TimeInterval) {
        self.now = now
        latencySimulation = simulation
        guard !simulation.isActive else { return }
        deliverInbound(until: .infinity)
        effects.insert(contentsOf: outbound.map(\.effect), at: 0)
        outbound.removeAll()
    }

    /// Presentations drawn in the last second: the HUD's FPS chip, the same on iOS and Android.
    public func displayFramesPerSecond(at now: TimeInterval) -> Int {
        diagnosticsRecorder.displayedFramesPerSecond(at: now)
    }

    /// The debug panel's numbers at this display time.
    public func diagnostics(at now: TimeInterval) -> HouseTanksOnlineDiagnostics {
        let measured = diagnosticsRecorder.snapshot(at: now)
        let recorder = diagnosticsRecorder
        return HouseTanksOnlineDiagnostics(
            connection: "\(lobby.connection)", runtimeEpoch: lobby.game?.runtimeEpoch,
            roundTripMilliseconds: lobbyMachine.lastRTT.map { Int(($0 * 1_000).rounded()) },
            snapshotIntervalMilliseconds: measured.interval, snapshotJitterMilliseconds: measured.jitter,
            frameAgeMilliseconds: measured.age, inputAcknowledgementMilliseconds: measured.ack,
            unacknowledgedInputs: play.pendingInputCount, lateFrames: lobbyMachine.lateSnapshots,
            gapResets: recorder.gapResets, corrections: recorder.corrections, snaps: recorder.snaps,
            staleControls: recorder.staleControls, rateLimited: recorder.rateLimited, reconnects: recorder.reconnects,
            receivedKilobytesPerSecond: measured.kilobytes, displayFramesPerSecond: measured.fps,
            interpolationDelayMilliseconds: Int((configuration.interpolationDelay * 1_000).rounded()),
            simulation: latencySimulation)
    }

    public func start(isForeground: Bool, isLandscape: Bool, now: TimeInterval) {
        self.now = now
        lobbyMachine.start(isForeground: isForeground, isLandscape: isLandscape, now: now)
    }

    public func sessionResponse(_ response: HTTPResponse, retryAfter: TimeInterval?, connection: Int, now: TimeInterval) {
        self.now = now
        lobbyMachine.sessionResponse(response, retryAfter: retryAfter, connection: connection, now: now)
    }

    public func socketOpened(connection: Int, now: TimeInterval) {
        self.now = now
        lobbyMachine.socketOpened(connection: connection, now: now)
    }

    /// `failure` uses the shared vocabulary: HTTP upgrade status (with Retry-After),
    /// `.http(403)` for a membership-revoked close, `.transport` for other drops.
    public func connectionFailed(_ failure: GameRealtimeSessionFailure, connection: Int, now: TimeInterval) {
        self.now = now
        lobbyMachine.connectionFailed(failure, connection: connection, now: now)
    }

    public func received(text: String, connection: Int, now: TimeInterval) {
        self.now = now
        guard latencySimulation.isActive || !inbound.isEmpty else { return deliver(text, connection: connection, at: now) }
        let at = max(inbound.last?.at ?? 0, now + latencySimulation.delay(unit: jitter()))
        inbound.append((text, connection, at))
        deliverInbound(until: now)
    }

    private func deliver(_ text: String, connection: Int, at uptime: TimeInterval) {
        now = uptime
        diagnosticsRecorder.receivedText(bytes: text.utf8.count, at: uptime)
        lobbyMachine.received(text: text, connection: connection, now: uptime)
    }

    /// Held messages arrive at their own time, never before what the engine already saw;
    /// `.infinity` delivers everything now.
    private func deliverInbound(until uptime: TimeInterval) {
        while let next = inbound.first, next.at <= uptime {
            inbound.removeFirst()
            deliver(next.text, connection: next.connection, at: uptime.isFinite ? max(now, next.at) : now)
        }
    }

    public func sendFailed(_ failure: GameRealtimeSessionFailure, connection: Int, now: TimeInterval) {
        self.now = now
        lobbyMachine.sendFailed(failure, connection: connection, now: now)
    }

    public func resultResponse(_ response: HTTPResponse, retryAfter: TimeInterval?, request: Int, now: TimeInterval) {
        self.now = now
        resultMachine.response(response, retryAfter: retryAfter, request: request, now: now)
    }

    public func resultFailed(request: Int, now: TimeInterval) {
        self.now = now
        resultMachine.failed(request: request, now: now)
    }

    public func tick(now: TimeInterval) {
        deliverInbound(until: now)
        self.now = now
        lobbyMachine.tick(now: now)
        resultMachine.tick(now: now)
        play.tick(at: now)
    }

    /// The single button went down / up on screen. Sent only when it changes the tank and
    /// only with valid control; the snapshot, not the press, says what the tank does.
    public func press(now: TimeInterval) { self.now = now; play.press(now: now) }
    public func release(now: TimeInterval) { self.now = now; play.release(now: now) }
    public func setReduceMotion(_ enabled: Bool) { play.setReduceMotion(enabled) }
    /// The vote for the next round in `roundReady`; ignored without control or outside it.
    public func setRoundReady(_ ready: Bool, now: TimeInterval) { self.now = now; play.vote(ready, now: now) }

    /// What the game screen draws now; nil before the first snapshot. Each server event is
    /// in exactly one presentation, so call this once per drawn frame.
    public func presentation(at now: TimeInterval) -> HouseTanksOnlinePresentation? {
        diagnosticsRecorder.displayedFrame(at: now)
        return play.render(at: now)
    }

    public func setReady(_ ready: Bool, now: TimeInterval) { self.now = now; lobbyMachine.setReady(ready, now: now) }
    /// Portrait and the background close the button; a held press is released first, while
    /// the grant still sends, so the tank does not drive on until the server drops control.
    public func setLandscape(_ landscape: Bool, now: TimeInterval) {
        self.now = now
        if !landscape { play.release(now: now) }
        lobbyMachine.setLandscape(landscape, now: now)
    }

    /// Back in the foreground the lobby resyncs before the button opens again.
    public func setForeground(_ active: Bool, now: TimeInterval) {
        self.now = now
        if !active { play.release(now: now) }
        lobbyMachine.setForeground(active, now: now)
    }
    public func retry(now: TimeInterval) { self.now = now; lobbyMachine.retry(now: now) }
    public func retryResult(now: TimeInterval) { self.now = now; resultMachine.retry(now: now) }
    public func cancelMatch(now: TimeInterval) { self.now = now; lobbyMachine.cancelMatch(now: now) }
    public func reclaimControl(now: TimeInterval) { self.now = now; lobbyMachine.reclaimControl(now: now) }
    public func leave(now: TimeInterval) { self.now = now; lobbyMachine.leave(now: now) }

    /// Cleanup only (screen closed); explicit business leave is `leave(now:)`.
    public func disconnect() {
        inbound.removeAll()
        outbound.removeAll()
        resultMachine.disconnect()
        play.disconnect()
        lobbyMachine.disconnect()
    }

    public func canCancel() -> Bool { lobby.canCancel(context: context) }

    /// The countdown the room shows: the session's ready window or match countdown,
    /// then the snapshot's round countdown or open vote window. Seconds left, never below zero.
    public func roomCountdown(at uptime: TimeInterval) -> Int? {
        let session = lobby.session
        if let game = lobby.game {
            if game.phase == .countdown { return lobby.remainingSeconds(until: game.countdownEndsAt, uptime: uptime) }
            if game.roundPhase == .roundCountdown {
                return lobby.remainingSeconds(until: game.roundCountdownEndsAt, uptime: uptime)
            }
            if game.roundPhase == .roundReady, game.phase == .playing {
                return lobby.remainingSeconds(until: game.roundReadyWindowEndsAt, uptime: uptime)
            }
            return nil
        }
        switch session?.state {
        case .countdown: return lobby.remainingSeconds(until: session?.countdownEndsAt, uptime: uptime)
        case .readyWindow: return lobby.remainingSeconds(until: session?.readyWindowEndsAt, uptime: uptime)
        default: return nil
        }
    }

    private func lobbyChanged(_ state: HouseTanksOnlineLobbyState) {
        if state.connection == .reconnecting, lobby.connection != .reconnecting { diagnosticsRecorder.reconnects += 1 }
        do { try play.consume(state, now: now) }
        catch { lobbyMachine.invalidateGameplay(now: now); return }
        lobby = state
        updateArena(state.game)
        resultMachine.consume(state, now: now)
    }

    /// Rebuilt once per snapshot; a new runtime epoch restarts the sequence.
    private func updateArena(_ snapshot: HouseTanksSnapshotDTO?) {
        guard let snapshot else {
            arena = nil
            arenaSnapshot = nil
            return
        }
        guard arenaSnapshot?.epoch != snapshot.runtimeEpoch || arenaSnapshot?.sequence != snapshot.stateSequence else { return }
        arenaSnapshot = (snapshot.runtimeEpoch, snapshot.stateSequence)
        arena = HouseTanksWorld(server: snapshot)
    }

    private func resultChanged(_ state: HouseTanksOnlineResultState) {
        let hadResult = result.result != nil
        let couldRematch = result.canRematch
        result = state
        if state.canRematch, !couldRematch {
            finished = true
            play.disconnect()
            lobbyMachine.finish()
        }
        if !hadResult, let final = state.result, final.status == .completed {
            effects.append(.haptic(final.championId == context.localPlayerID ? .success : .warning))
        }
    }
}
