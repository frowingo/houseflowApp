import Foundation

/// Display timing, bounded prediction and input scheduling (`HouseRocketsOnlineFlight`
/// on iOS) without tasks. Sends complete when the lobby has handed them to the host.
///
/// Two paced clocks (see `HouseRocketsPacedClock`) drive everything on screen: the stream
/// clock follows the newest snapshot's pace and times the local prediction and the inputs;
/// the render clock runs the interpolation delay behind it and times the other rockets and
/// the camera. Neither runs backwards while a timeline lasts.
final class HouseRocketsOnlineFlightMachine {
    typealias Send = (GameRealtimeClientMessage, HouseRocketsControlGrantDTO) -> Bool
    var onEliminations: (([HouseRocketsOnlineElimination]) -> Void)?
    var onControlLost: (() -> Void)?
    private let localPlayerID: String
    private let configuration: HouseRocketsFlightConfiguration
    private let makeID: () -> String
    private let send: Send
    private let resync: () -> Void
    private var state = HouseRocketsOnlineLobbyState()
    private var frames: [HouseRocketsBufferedFrame] = []
    private var inputs: [HouseRocketsPredictedInput] = []
    private var binding: HouseRocketsControlGrantDTO?
    private var intent: (heading: Double, time: TimeInterval)?
    private var sequence: Int64 = 0
    private var lastACK: Int64 = 0
    private var lastSentHeading: Double?
    private var lastTouchHeading: Double?
    /// A blocked drag sends a steer per move event: it counts as one swallowed touch.
    private var swallowedThisGesture = false
    /// Sequences sent again with an old heading: their ACK says nothing new about latency.
    private var retransmittedSequences = Set<Int64>()
    private var lastSentAt = -TimeInterval.infinity
    private var retransmits = 0
    private var backoffUntil: TimeInterval = 0
    private var lastResyncAt = -TimeInterval.infinity
    private var controlWaitStartedAt: TimeInterval?
    /// What is left of an easing offset (added to the predicted or interpolated position) as
    /// of `updatedAt`. Easing is memoryless, so reading it at any rate gives the same curve.
    private struct Correction {
        var x: Double
        var y: Double
        var updatedAt: TimeInterval
    }
    private var localCorrection: Correction?
    /// Display-only offsets that ease a remote rocket back after it was extrapolated and the
    /// next snapshot moved it; at most one per player.
    private var remoteCorrections: [String: Correction] = [:]
    private var clocks: (stream: HouseRocketsPacedClock, render: HouseRocketsPacedClock)?
    private var interpolationDelay: TimeInterval
    private var arrivalJitter: GameDiagnosticsWindow
    private var lastArrival: TimeInterval?
    private var notices: [HouseRocketsOnlineElimination] = []
    private var isClosed = false
    private var reduceMotion = false
    private var suppressHistoricalEliminations = false
    private let diagnostics: GameOnlineDiagnosticsRecorder

    init(localPlayerID: String, configuration: HouseRocketsFlightConfiguration,
         diagnostics: GameOnlineDiagnosticsRecorder = .init(),
         makeID: @escaping () -> String, send: @escaping Send, resync: @escaping () -> Void) {
        self.localPlayerID = localPlayerID
        self.diagnostics = diagnostics
        self.configuration = configuration
        interpolationDelay = configuration.minimumInterpolationDelay
        arrivalJitter = GameDiagnosticsWindow(capacity: configuration.jitterWindow)
        self.makeID = makeID
        self.send = send
        self.resync = resync
    }

    func disconnect() {
        guard !isClosed else { return }
        isClosed = true
        frames.removeAll()
        notices.removeAll()
        clearControl()
        onEliminations = nil
        onControlLost = nil
    }

    func setReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
        if enabled {
            localCorrection = nil
            remoteCorrections.removeAll(keepingCapacity: true)
        }
    }

    /// Called synchronously for every lobby publication.
    func consume(_ incoming: HouseRocketsOnlineLobbyState, now: TimeInterval) throws {
        guard !isClosed else { return }
        let oldPrediction = predictedLocal(at: now)
        let oldRemote = extrapolatedRemotePositions(at: now)
        let previous = frames.last
        let changedConnection = state.connectionGeneration != incoming.connectionGeneration
        state = incoming
        if incoming.game == nil {
            frames.removeAll()
            notices.removeAll()
            clearControl()
            restartDisplayTiming()
            diagnostics.timelineRestarted()
            return
        }
        if changedConnection || incoming.connection != .connected || !incoming.isForeground || !incoming.isSynced {
            clearControl()
            notices.removeAll()
            frames = Array(frames.suffix(1))
            restartDisplayTiming()
            suppressHistoricalEliminations = true
        }
        var appended = false
        var resetTimeline = false
        if let snapshot = incoming.game, snapshot != previous?.snapshot ||
            (suppressHistoricalEliminations && incoming.isSynced && incoming.connection == .connected) {
            if let previous, snapshot.sessionId == previous.snapshot.sessionId,
               snapshot.runtimeEpoch == previous.snapshot.runtimeEpoch {
                guard snapshot.stateSequence >= previous.snapshot.stateSequence else { return }
                guard snapshot.tick >= previous.snapshot.tick,
                      snapshot.elapsedSeconds >= previous.snapshot.elapsedSeconds else { throw GameRealtimeError.invalidResponse }
            }
            let frame = try HouseRocketsRenderFrame.online(snapshot, localPlayerID: localPlayerID)
            resetTimeline = previous?.snapshot.sessionId != snapshot.sessionId
                || previous?.snapshot.runtimeEpoch != snapshot.runtimeEpoch
                || previous?.snapshot.phase != snapshot.phase
                || suppressHistoricalEliminations
            let sameWorld = previous?.snapshot.sessionId == snapshot.sessionId && previous?.snapshot.runtimeEpoch == snapshot.runtimeEpoch
            if resetTimeline {
                diagnostics.timelineRestarted()
                frames.removeAll()
                if !sameWorld { notices.removeAll() }
                clearControl()
                restartDisplayTiming()
            }
            if sameWorld, !suppressHistoricalEliminations, let previous {
                let alive = Set(previous.snapshot.players.filter(\.isAlive).map(\.playerId))
                let eliminated = snapshot.players.filter { !$0.isAlive && alive.contains($0.playerId) }.map {
                    HouseRocketsOnlineElimination(sessionID: snapshot.sessionId, epoch: snapshot.runtimeEpoch,
                        tick: $0.eliminatedAtTick ?? snapshot.tick, playerID: $0.playerId,
                        displayName: $0.displayName, receivedUptime: now)
                }
                if !eliminated.isEmpty {
                    notices.append(contentsOf: eliminated)
                    notices = Array(notices.suffix(8))
                    onEliminations?(eliminated)
                }
            }
            let receivedUptime = incoming.gameReceivedUptime ?? now
            frames.append(.init(snapshot: snapshot, frame: frame, receivedUptime: receivedUptime))
            diagnostics.snapshotArrived(at: receivedUptime)
            frames = Array(frames.suffix(max(2, min(16, configuration.snapshotCapacity))))
            recordArrival(at: receivedUptime)
            paceClocks(by: frames[frames.count - 1], now: now)
            appended = true
            if incoming.isSynced, incoming.connection == .connected { suppressHistoricalEliminations = false }
        }
        let grant = incoming.validControl(playerID: localPlayerID)
        if grant == nil, incoming.isSynced, incoming.isForeground, incoming.isLandscape,
           incoming.game?.phase == .playing, !incoming.isTerminal, !incoming.controlTransferred,
           incoming.game?.players.first(where: { $0.playerId == localPlayerID && $0.isAlive && $0.connected }) != nil {
            if controlWaitStartedAt == nil { controlWaitStartedAt = now }
        } else { controlWaitStartedAt = nil }
        if grant != binding {
            clearControl()
            binding = grant
            sequence = incoming.game?.players.first(where: { $0.playerId == localPlayerID })?.lastProcessedInputSequence ?? 0
            lastACK = sequence
        }
        if let player = incoming.game?.players.first(where: { $0.playerId == localPlayerID }), binding != nil {
            guard player.lastProcessedInputSequence >= lastACK else { throw GameRealtimeError.invalidResponse }
            if player.lastProcessedInputSequence > lastACK { retransmits = 0 }
            lastACK = player.lastProcessedInputSequence
            sequence = max(sequence, lastACK)
            for input in inputs where input.sequence <= lastACK {
                if retransmittedSequences.remove(input.sequence) == nil {
                    diagnostics.inputAcknowledged(after: (incoming.gameReceivedUptime ?? now) - input.sentUptime)
                }
            }
            inputs.removeAll { $0.sequence <= lastACK }
        }
        if appended, !resetTimeline, !reduceMotion {
            if let oldPrediction, let newPrediction = predictedLocal(at: now) {
                let offset = localOffset(for: oldPrediction, at: now)
                let x = oldPrediction.worldX + offset.x - newPrediction.worldX
                let y = oldPrediction.worldY + offset.y - newPrediction.worldY
                let distance = hypot(x, y)
                let snapped = distance > configuration.correctionLimit
                diagnostics.localCorrected(by: distance, snapped: snapped)
                localCorrection = snapped ? nil : Correction(x: x, y: y, updatedAt: now)
            }
            if let oldRemote { easeRemotes(from: oldRemote, at: now) }
        }
    }

    func steer(screenHeading: Double, now: TimeInterval) {
        guard screenHeading.isFinite else { return }
        guard canSteer(at: now), let newest = frames.last else {
            if frames.last?.frame.phase == .playing, !swallowedThisGesture {
                diagnostics.inputSwallowed()
                swallowedThisGesture = true
            }
            return
        }
        swallowedThisGesture = false
        let time = inputTime(at: now, newest: newest)
        let courseAngle = HouseRocketsFlightMath.angle(newest.frame, at: time)
        let heading = HouseRocketsFlightMath.normalize(screenHeading - courseAngle)
        if let old = lastTouchHeading, abs(HouseRocketsFlightMath.normalize(heading - old)) < 0.01 { return }
        lastTouchHeading = heading
        intent = (heading, time)
        retransmits = 0
        // The first change after idling goes out at once; a busy rate gate leaves it to `tick`.
        if isLive(newest) { transmitSteer(at: now, newest: newest) }
    }

    func endSteering() {
        lastTouchHeading = nil
        swallowedThisGesture = false
    }

    func adjustHeading(by amount: Double, now: TimeInterval) {
        guard let newest = frames.last,
              let player = newest.frame.players.first(where: { $0.id == localPlayerID }) else { return }
        let elapsed = inputTime(at: now, newest: newest)
        steer(screenHeading: (intent?.heading ?? player.courseHeading)
              + HouseRocketsFlightMath.angle(newest.frame, at: elapsed) + amount, now: now)
    }

    func reject(messageID: String?, rejection: GameRealtimeRejection, now: TimeInterval) {
        guard let messageID, inputs.contains(where: { $0.messageID == messageID }) else { return }
        // Never replay a rejected sequence or let an obsolete rejection revoke a new binding.
        loseControl(.reject)
        if ["houseRockets.error.stale_control", "houseRockets.error.control_unavailable"].contains(rejection.code) {
            onControlLost?()
            return
        }
        if rejection.code == "realtime.error.rate_limited" { backoffUntil = now + 0.5 }
        requestResync(at: now)
    }

    func render(at now: TimeInterval) -> HouseRocketsOnlinePresentation? {
        guard !isClosed, let newest = frames.last else { return nil }
        var frame = newest.frame
        let age = max(0, now - newest.receivedUptime)
        if let world = displayedWorld(at: now, newest: newest) {
            frame = world.frame
            applyRemoteCorrections(to: &frame, at: now)
            recordDisplay(of: frame, at: now)
            if let predicted = predictedLocal(at: now), let index = frame.players.firstIndex(where: { $0.id == localPlayerID }) {
                var rendered = predicted
                let offset = localOffset(for: rendered, at: now)
                let point = newest.solids.resolve(HouseRocketsPoint(x: rendered.worldX + offset.x,
                                                                   y: rendered.worldY + offset.y))
                rendered.worldX = point.x; rendered.worldY = point.y
                frame.players[index] = rendered
            }
        } else {
            diagnostics.displayInterrupted()
        }
        notices.removeAll { now - $0.receivedUptime > 1.8 }
        // Syncing means the display budget ran out, not that one snapshot is a little late.
        return .init(frame: frame, canSteer: canSteer(at: now),
            isSyncing: state.connection != .connected || frame.phase == .recovering
                || (frame.phase == .playing
                    && (!state.isSynced || age > interpolationDelay + configuration.maximumExtrapolation)),
            eliminations: notices)
    }

    func tick(at now: TimeInterval) {
        guard !isClosed, let newest = frames.last, isLive(newest) else { return }
        if now - newest.receivedUptime > configuration.staleSnapshotResync {
            loseControl(.stale)
            requestResync(at: now)
            return
        }
        if let controlWaitStartedAt, now - controlWaitStartedAt >= 0.5 {
            requestResync(at: now)
            return
        }
        transmitSteer(at: now, newest: newest)
    }

    /// The one send path for steers: a fresh intent, or a retransmit of the last one, at
    /// most at the server's steer rate. `steer` and `tick` both end here.
    private func transmitSteer(at now: TimeInterval, newest: HouseRocketsBufferedFrame) {
        guard canSteer(at: now), now >= backoffUntil, let binding else { return }
        let rate = (state.runtimeSettings ?? .releaseDefaults).steerRate(preferredHz: configuration.inputRateHz)
        guard now - lastSentAt >= 1 / rate else { return }
        var heading = intent?.heading
        var isRetransmit = false
        let changed = heading.map { value in
            lastSentHeading.map { abs(HouseRocketsFlightMath.normalize(value - $0)) >= 0.01 } ?? true
        } ?? false
        if !changed {
            guard let latest = inputs.last, now - latest.sentUptime >= configuration.retransmitInterval else { return }
            guard retransmits < configuration.maximumRetransmits else {
                loseControl(.retransmit); requestResync(at: now); return
            }
            heading = latest.heading
            retransmits += 1
            isRetransmit = true
        }
        guard let heading, sequence < Int64.max, inputs.count < max(1, min(32, configuration.inputCapacity)) else {
            loseControl(.other); requestResync(at: now); return
        }
        sequence += 1
        if isRetransmit { retransmittedSequences.insert(sequence) }
        let message = GameRealtimeClientMessage(messageId: makeID(),
            action: .steer(controlGeneration: binding.controlGeneration, inputSequence: sequence, courseHeading: heading))
        inputs.append(.init(messageID: message.messageId, sequence: sequence, heading: heading,
                            simulationTime: max(inputs.last?.simulationTime ?? 0,
                                                intent?.time ?? inputTime(at: now, newest: newest)),
                            sentUptime: now))
        lastSentHeading = heading
        lastSentAt = now
        intent = nil
        if !send(message, binding) {
            guard !isClosed else { return }
            loseControl(.other)
            requestResync(at: now)
        }
    }

    /// The game is on and this client may act in it.
    private func isLive(_ newest: HouseRocketsBufferedFrame) -> Bool {
        isShowingFlight(newest) && !state.controlTransferred
    }

    private func isShowingFlight(_ newest: HouseRocketsBufferedFrame) -> Bool {
        newest.frame.phase == .playing && !state.isTerminal && state.connection == .connected
            && state.isSynced && state.isForeground
    }

    private func canSteer(at now: TimeInterval) -> Bool {
        guard let newest = frames.last, binding != nil,
              state.validControl(playerID: localPlayerID) == binding else { return false }
        return now >= backoffUntil && now - newest.receivedUptime <= configuration.steerFreshness
    }

    private func predictedLocal(at now: TimeInterval) -> HouseRocketsRenderPlayer? {
        guard binding != nil, let newest = frames.last, newest.frame.phase == .playing,
              let player = newest.frame.players.first(where: { $0.id == localPlayerID }), player.isAlive else { return nil }
        var predicted = HouseRocketsFlightMath.advance(player, from: newest.frame.elapsedTime,
            to: inputTime(at: now, newest: newest), solids: newest.solids, inputs: inputs, intent: intent)
        // A touch changes visible heading immediately even before the next render substep.
        if let intent { predicted.courseHeading = intent.heading }
        else if let latest = inputs.last { predicted.courseHeading = latest.heading }
        return predicted
    }

    /// The simulation time of the local rocket and of an input made now: the stream clock,
    /// at most the prediction budget past the newest snapshot. The single place that decides
    /// it, so inputs that later carry their own tick change here only.
    private func inputTime(at now: TimeInterval, newest: HouseRocketsBufferedFrame) -> TimeInterval {
        min(currentClocks(for: newest, at: now).stream.time(at: now),
            newest.frame.elapsedTime + configuration.maximumPrediction)
    }

    // MARK: Display clocks and corrections

    private func streamTarget(of newest: HouseRocketsBufferedFrame, at now: TimeInterval) -> TimeInterval {
        newest.frame.elapsedTime + max(0, now - newest.receivedUptime)
    }

    private func currentClocks(for newest: HouseRocketsBufferedFrame, at now: TimeInterval)
        -> (stream: HouseRocketsPacedClock, render: HouseRocketsPacedClock) {
        if let clocks { return clocks }
        let target = streamTarget(of: newest, at: now)
        let started = (stream: HouseRocketsPacedClock(at: now, time: target),
                       render: HouseRocketsPacedClock(at: now, time: target - interpolationDelay))
        clocks = started
        return started
    }

    /// Moves both clocks toward the pace the new snapshot implies (see `HouseRocketsPacedClock`).
    private func paceClocks(by newest: HouseRocketsBufferedFrame, now: TimeInterval) {
        guard isShowingFlight(newest) else {
            clocks = nil
            return
        }
        guard var paced = clocks else {
            _ = currentClocks(for: newest, at: now)
            return
        }
        let target = streamTarget(of: newest, at: now)
        let lead = paced.stream.pace(toward: target, at: now, snapLimit: configuration.clockSnapLimit)
        paced.render.pace(toward: target - interpolationDelay, at: now, snapLimit: configuration.clockSnapLimit)
        diagnostics.clockPaced(ahead: lead.ahead, snapped: lead.snapped)
        clocks = paced
    }

    /// Learns the snapshot cadence's jitter: how far each arrival interval is from the
    /// server's nominal one. The delay is read from it only here, never per frame.
    private func recordArrival(at uptime: TimeInterval) {
        let interval = 1 / Double(max(1, (state.runtimeSettings ?? .releaseDefaults).snapshotRateHz))
        if let lastArrival { arrivalJitter.append(abs(uptime - lastArrival - interval)) }
        lastArrival = uptime
        let wanted = 2 * interval + (arrivalJitter.percentile(0.95) ?? 0)
        interpolationDelay = min(configuration.maximumInterpolationDelay,
                                 max(configuration.minimumInterpolationDelay, wanted))
    }

    /// A new world (session, epoch, phase, resync, reconnect): nothing measured before it applies.
    private func restartDisplayTiming() {
        clocks = nil
        lastArrival = nil
        arrivalJitter.removeAll()
        remoteCorrections.removeAll(keepingCapacity: true)
    }

    /// The correction after easing up to `now`: exponential, except that on an axis where it
    /// would move the rocket against its own velocity it is held to a share of that speed.
    /// A rocket at 300 u/s would otherwise be dragged backwards by a large offset. Nil once gone.
    private func eased(_ correction: Correction, at now: TimeInterval,
                       rocket: HouseRocketsRenderPlayer) -> Correction? {
        let elapsed = max(0, now - correction.updatedAt)
        let keep = exp(-elapsed / configuration.correctionTime)
        let speed = HouseRocketsSimulation.speed * (rocket.speedEffect?.multiplier ?? 1)
        func ease(_ offset: Double, velocity: Double) -> Double {
            let next = offset * keep
            // Removing the offset moves the rocket by `next - offset`: against `velocity`
            // when the offset has the velocity's sign.
            guard offset * velocity > 0 else { return next }
            let limit = configuration.easingBackwardShare * abs(velocity) * elapsed
            return abs(offset - next) > limit ? offset - (offset > 0 ? limit : -limit) : next
        }
        let x = ease(correction.x, velocity: cos(rocket.courseHeading) * speed)
        let y = ease(correction.y, velocity: sin(rocket.courseHeading) * speed)
        guard abs(x) > 0.01 || abs(y) > 0.01 else { return nil }
        return Correction(x: x, y: y, updatedAt: now)
    }

    private func localOffset(for rocket: HouseRocketsRenderPlayer, at now: TimeInterval) -> HouseRocketsPoint {
        guard let correction = localCorrection, !reduceMotion,
              let remaining = eased(correction, at: now, rocket: rocket) else {
            localCorrection = nil
            return .init(x: 0, y: 0)
        }
        localCorrection = remaining
        return .init(x: remaining.x, y: remaining.y)
    }

    /// The frame to draw for the other rockets and the camera: interpolated between two
    /// snapshots at the render clock, or extrapolated (within the display budget) past
    /// the newest one. Nil when no flight is shown.
    private func displayedWorld(at now: TimeInterval, newest: HouseRocketsBufferedFrame)
        -> (frame: HouseRocketsRenderFrame, isExtrapolated: Bool)? {
        guard isShowingFlight(newest) else { return nil }
        let target = currentClocks(for: newest, at: now).render.time(at: now)
        var frame = newest.frame
        var isExtrapolated = false
        if let right = frames.firstIndex(where: { $0.frame.elapsedTime >= target }), right > 0 {
            frame = HouseRocketsFlightMath.interpolate(frames[right - 1].frame, frames[right].frame, at: target)
        } else if target <= frames[0].frame.elapsedTime {
            frame = frames[0].frame
        } else {
            isExtrapolated = true
            let delta = min(configuration.maximumExtrapolation, max(0, target - newest.frame.elapsedTime))
            frame.elapsedTime += delta
            frame.courseAngle = HouseRocketsFlightMath.angle(newest.frame, at: frame.elapsedTime)
            if frames.count > 1 {
                let old = frames[frames.count - 2].frame
                let duration = newest.frame.elapsedTime - old.elapsedTime
                if duration > 0 {
                    let velocity = max(0, min(HouseRocketsSimulation.speed * 1.45,
                                            (newest.frame.cameraX - old.cameraX) / duration))
                    frame.cameraX += velocity * delta
                }
            }
            frame.players = frame.players.map {
                HouseRocketsFlightMath.advance($0, from: newest.frame.elapsedTime,
                    to: frame.elapsedTime, solids: newest.solids)
            }
        }
        // Discrete authority always comes from the newest snapshot, even inside the buffer.
        for index in frame.players.indices {
            if let latest = newest.frame.players.first(where: { $0.id == frame.players[index].id }), !latest.isAlive {
                frame.players[index] = latest
            }
        }
        return (frame, isExtrapolated)
    }

    /// A rocket that is dead in the newest snapshot stays exactly where the server left it.
    private func applyRemoteCorrections(to frame: inout HouseRocketsRenderFrame, at now: TimeInterval) {
        guard !remoteCorrections.isEmpty else { return }
        for index in frame.players.indices {
            let player = frame.players[index]
            guard let correction = remoteCorrections[player.id] else { continue }
            guard player.isAlive, !reduceMotion, let remaining = eased(correction, at: now, rocket: player) else {
                remoteCorrections[player.id] = nil
                continue
            }
            remoteCorrections[player.id] = remaining
            frame.players[index].worldX += remaining.x
            frame.players[index].worldY += remaining.y
        }
    }

    /// Where the other rockets are drawn right now, when that is an extrapolation: the
    /// only case in which the next snapshot can move them.
    private func extrapolatedRemotePositions(at now: TimeInterval) -> [String: HouseRocketsPoint]? {
        guard !reduceMotion, let newest = frames.last, clocks != nil,
              var world = displayedWorld(at: now, newest: newest), world.isExtrapolated else { return nil }
        applyRemoteCorrections(to: &world.frame, at: now)
        return Dictionary(uniqueKeysWithValues: world.frame.players
            .filter { $0.id != localPlayerID && $0.isAlive }.map { ($0.id, HouseRocketsPoint(x: $0.worldX, y: $0.worldY)) })
    }

    /// The new snapshot moved extrapolated rockets: ease them from where they were drawn.
    private func easeRemotes(from old: [String: HouseRocketsPoint], at now: TimeInterval) {
        guard let newest = frames.last, let world = displayedWorld(at: now, newest: newest) else { return }
        remoteCorrections.removeAll(keepingCapacity: true)
        for player in world.frame.players where player.id != localPlayerID && player.isAlive {
            guard let before = old[player.id] else { continue }
            let x = before.x - player.worldX
            let y = before.y - player.worldY
            let distance = hypot(x, y)
            let snapped = distance > configuration.correctionLimit
            diagnostics.remoteCorrected(by: distance, snapped: snapped)
            if !snapped { remoteCorrections[player.id] = Correction(x: x, y: y, updatedAt: now) }
        }
    }

    private func loseControl(_ cause: GameControlLossCause) {
        if binding != nil { diagnostics.controlLost(cause) }
        clearControl()
    }

    /// The rendered simulation time against the wall clock, and whether a remote rocket
    /// moved farther than its speed allows between two renders. Reads the frame only.
    private func recordDisplay(of frame: HouseRocketsRenderFrame, at now: TimeInterval) {
        let wall = diagnostics.displayStep(now: now, simulationTime: frame.elapsedTime)
        let maximumStep = wall.map { HouseRocketsSimulation.speed * 1.45 * $0 + 20 }
        for player in frame.players where player.id != localPlayerID {
            diagnostics.remoteRendered(id: player.id, x: player.worldX, y: player.worldY,
                                       isAlive: player.isAlive, maximumStep: maximumStep)
        }
    }

    private func clearControl() {
        binding = nil
        inputs.removeAll()
        intent = nil
        sequence = 0; lastACK = 0
        retransmittedSequences.removeAll()
        lastSentHeading = nil; lastTouchHeading = nil
        retransmits = 0
        localCorrection = nil
    }

    private func requestResync(at now: TimeInterval) {
        guard state.connection == .connected, state.isForeground, !state.controlTransferred,
              !state.isTerminal, now - lastResyncAt >= 1 else { return }
        lastResyncAt = now
        diagnostics.resyncRequested()
        resync()
    }
}
