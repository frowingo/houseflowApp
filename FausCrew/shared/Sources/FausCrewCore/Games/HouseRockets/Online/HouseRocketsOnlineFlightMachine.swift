import Foundation

/// Display timing, bounded prediction and input scheduling (`HouseRocketsOnlineFlight`
/// on iOS) without tasks. Sends complete when the lobby has handed them to the host.
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
    private var lastSentAt = -TimeInterval.infinity
    private var retransmits = 0
    private var backoffUntil: TimeInterval = 0
    private var lastResyncAt = -TimeInterval.infinity
    private var controlWaitStartedAt: TimeInterval?
    private var correction = HouseRocketsPoint(x: 0, y: 0)
    private var correctionAt: TimeInterval = 0
    private var notices: [HouseRocketsOnlineElimination] = []
    private var isClosed = false
    private var reduceMotion = false
    private var suppressHistoricalEliminations = false

    init(localPlayerID: String, configuration: HouseRocketsFlightConfiguration,
         makeID: @escaping () -> String, send: @escaping Send, resync: @escaping () -> Void) {
        self.localPlayerID = localPlayerID
        self.configuration = configuration
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
        if enabled { correction = .init(x: 0, y: 0) }
    }

    /// Called synchronously for every lobby publication.
    func consume(_ incoming: HouseRocketsOnlineLobbyState, now: TimeInterval) throws {
        guard !isClosed else { return }
        let oldPrediction = predictedLocal(at: now)
        let previous = frames.last
        let changedConnection = state.connectionGeneration != incoming.connectionGeneration
        state = incoming
        if incoming.game == nil {
            frames.removeAll()
            notices.removeAll()
            clearControl()
            return
        }
        if changedConnection || incoming.connection != .connected || !incoming.isForeground || !incoming.isSynced {
            clearControl()
            notices.removeAll()
            frames = Array(frames.suffix(1))
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
                frames.removeAll()
                if !sameWorld { notices.removeAll() }
                clearControl()
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
            frames.append(.init(snapshot: snapshot, frame: frame, receivedUptime: incoming.gameReceivedUptime ?? now))
            frames = Array(frames.suffix(max(2, min(16, configuration.snapshotCapacity))))
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
            inputs.removeAll { $0.sequence <= lastACK }
        }
        if appended, !resetTimeline, !reduceMotion, let oldPrediction, let newPrediction = predictedLocal(at: now) {
            let decay = exp(-max(0, now - correctionAt) / 0.08)
            let x = oldPrediction.worldX + correction.x * decay - newPrediction.worldX
            let y = oldPrediction.worldY + correction.y * decay - newPrediction.worldY
            correction = hypot(x, y) <= 60 ? .init(x: x, y: y) : .init(x: 0, y: 0)
            correctionAt = now
        }
    }

    func steer(screenHeading: Double, now: TimeInterval) {
        guard screenHeading.isFinite, canSteer(at: now), let newest = frames.last else { return }
        let estimatedTime = newest.frame.elapsedTime + min(configuration.maximumExtrapolation,
                                                          max(0, now - newest.receivedUptime))
        let courseAngle = HouseRocketsFlightMath.angle(newest.frame, at: estimatedTime)
        let heading = HouseRocketsFlightMath.normalize(screenHeading - courseAngle)
        if let old = lastTouchHeading, abs(HouseRocketsFlightMath.normalize(heading - old)) < 0.01 { return }
        lastTouchHeading = heading
        intent = (heading, estimatedTime)
        retransmits = 0
    }

    func endSteering() { lastTouchHeading = nil }

    func adjustHeading(by amount: Double, now: TimeInterval) {
        guard let newest = frames.last,
              let player = newest.frame.players.first(where: { $0.id == localPlayerID }) else { return }
        let elapsed = newest.frame.elapsedTime + min(configuration.maximumExtrapolation, max(0, now - newest.receivedUptime))
        steer(screenHeading: (intent?.heading ?? player.courseHeading)
              + HouseRocketsFlightMath.angle(newest.frame, at: elapsed) + amount, now: now)
    }

    func reject(messageID: String?, rejection: GameRealtimeRejection, now: TimeInterval) {
        guard let messageID, inputs.contains(where: { $0.messageID == messageID }) else { return }
        // Never replay a rejected sequence or let an obsolete rejection revoke a new binding.
        clearControl()
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
        if frame.phase == .playing, !state.isTerminal, state.connection == .connected,
           state.isSynced, state.isForeground {
            let target = newest.frame.elapsedTime + age - configuration.interpolationDelay
            if let right = frames.firstIndex(where: { $0.frame.elapsedTime >= target }), right > 0 {
                frame = HouseRocketsFlightMath.interpolate(frames[right - 1].frame, frames[right].frame, at: target)
            } else if target <= frames[0].frame.elapsedTime {
                frame = frames[0].frame
            } else {
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
                        to: frame.elapsedTime, gates: newest.frame.gates)
                }
            }
            // Discrete authority always comes from the newest snapshot, even inside the buffer.
            let current = Dictionary(uniqueKeysWithValues: newest.frame.players.map { ($0.id, $0) })
            frame.players = frame.players.map { player in
                guard let latest = current[player.id] else { return player }
                return latest.isAlive ? player : latest
            }
            if let predicted = predictedLocal(at: now), let index = frame.players.firstIndex(where: { $0.id == localPlayerID }) {
                var rendered = predicted
                let decay = reduceMotion ? 0 : exp(-max(0, now - correctionAt) / 0.08)
                var point = HouseRocketsPoint(x: rendered.worldX + correction.x * decay,
                                             y: rendered.worldY + correction.y * decay)
                for _ in 0..<3 {
                    point.y = min(HouseRocketsSimulation.trackHeight - HouseRocketsSimulation.rocketRadius,
                                  max(HouseRocketsSimulation.rocketRadius, point.y))
                    for polygon in newest.frame.gates.flatMap(\.solidPolygons) {
                        point = HouseRocketsContact.resolve(point, radius: HouseRocketsSimulation.rocketRadius, polygon: polygon)
                    }
                }
                rendered.worldX = point.x; rendered.worldY = point.y
                frame.players[index] = rendered
            }
        }
        notices.removeAll { now - $0.receivedUptime > 1.8 }
        return .init(frame: frame, canSteer: canSteer(at: now),
            isSyncing: state.connection != .connected || frame.phase == .recovering
                || (frame.phase == .playing && (!state.isSynced || age > configuration.maximumExtrapolation)),
            eliminations: notices)
    }

    func tick(at now: TimeInterval) {
        guard !isClosed, let newest = frames.last, newest.frame.phase == .playing,
              state.connection == .connected, state.isForeground, state.isSynced,
              !state.controlTransferred, !state.isTerminal else { return }
        if now - newest.receivedUptime > configuration.interpolationDelay + configuration.maximumExtrapolation {
            clearControl()
            requestResync(at: now)
            return
        }
        if let controlWaitStartedAt, now - controlWaitStartedAt >= 0.5 {
            requestResync(at: now)
            return
        }
        guard canSteer(at: now), now >= backoffUntil, let binding else { return }
        let rate = (state.runtimeSettings ?? .releaseDefaults).steerRate(preferredHz: configuration.inputRateHz)
        guard now - lastSentAt >= 1 / rate else { return }
        var heading = intent?.heading
        let changed = heading.map { value in
            lastSentHeading.map { abs(HouseRocketsFlightMath.normalize(value - $0)) >= 0.01 } ?? true
        } ?? false
        if !changed {
            guard let latest = inputs.last, now - latest.sentUptime >= configuration.retransmitInterval else { return }
            guard retransmits < configuration.maximumRetransmits else {
                clearControl(); requestResync(at: now); return
            }
            heading = latest.heading
            retransmits += 1
        }
        guard let heading, sequence < Int64.max, inputs.count < max(1, min(32, configuration.inputCapacity)) else {
            clearControl(); requestResync(at: now); return
        }
        sequence += 1
        let message = GameRealtimeClientMessage(messageId: makeID(),
            action: .steer(controlGeneration: binding.controlGeneration, inputSequence: sequence, courseHeading: heading))
        let time = newest.frame.elapsedTime + min(configuration.maximumExtrapolation, max(0, now - newest.receivedUptime))
        inputs.append(.init(messageID: message.messageId, sequence: sequence, heading: heading,
                            simulationTime: max(inputs.last?.simulationTime ?? 0, intent?.time ?? time), sentUptime: now))
        lastSentHeading = heading
        lastSentAt = now
        intent = nil
        if !send(message, binding) {
            guard !isClosed else { return }
            clearControl()
            requestResync(at: now)
        }
    }

    private func canSteer(at now: TimeInterval) -> Bool {
        guard let newest = frames.last, binding != nil,
              state.validControl(playerID: localPlayerID) == binding else { return false }
        return now >= backoffUntil && now - newest.receivedUptime <= configuration.maximumExtrapolation
    }

    private func predictedLocal(at now: TimeInterval) -> HouseRocketsRenderPlayer? {
        guard binding != nil, let newest = frames.last, newest.frame.phase == .playing,
              let player = newest.frame.players.first(where: { $0.id == localPlayerID }), player.isAlive else { return nil }
        let delta = min(configuration.maximumPrediction, configuration.maximumExtrapolation,
                        max(0, now - newest.receivedUptime))
        var predicted = HouseRocketsFlightMath.advance(player, from: newest.frame.elapsedTime,
            to: newest.frame.elapsedTime + delta, gates: newest.frame.gates, inputs: inputs, intent: intent)
        // A touch changes visible heading immediately even before the next render substep.
        if let intent { predicted.courseHeading = intent.heading }
        else if let latest = inputs.last { predicted.courseHeading = latest.heading }
        return predicted
    }

    private func clearControl() {
        binding = nil
        inputs.removeAll()
        intent = nil
        sequence = 0; lastACK = 0
        lastSentHeading = nil; lastTouchHeading = nil
        retransmits = 0
        correction = .init(x: 0, y: 0)
    }

    private func requestResync(at now: TimeInterval) {
        guard state.connection == .connected, state.isForeground, !state.controlTransferred,
              !state.isTerminal, now - lastResyncAt >= 1 else { return }
        lastResyncAt = now
        resync()
    }
}
