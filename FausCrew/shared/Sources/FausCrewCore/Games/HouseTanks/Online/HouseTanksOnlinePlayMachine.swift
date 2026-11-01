import Foundation

/// The playing match (`HouseRocketsOnlineFlightMachine`'s counterpart) without tasks:
/// display timing, the own tank's bounded prediction, the button and event replay.
///
/// - The button is open only with a grant whose epoch and generation the visible
///   `playing` snapshot confirms. Press and release are sent only on change, with a
///   sequence that starts over for every generation; `clientTick` and `heading` are the
///   own tank as last drawn. A press is never assumed applied: the snapshot says.
/// - Other tanks, crates and shots are drawn `interpolationDelay` behind the server from
///   a small buffer. The own tank is the newest frame stepped forward by the shared
///   engine with the presses the server has not acknowledged yet, and is pulled back
///   smoothly when a frame disagrees.
/// - Events are played once, by `(runtimeEpoch, sequence)`, when the display reaches them.
/// - Between rounds the same grant votes for the next round (`roundReady`); a dead tank's
///   player votes too. The vote shows at once and the snapshot confirms it.
/// - `stale_control` never resyncs at once: a resync rebinds this connection, which would
///   take the tank back from a second device. The next frames show either the takeover
///   (the lobby marks it, only "reclaim" binds again) or a grant that still stands.
final class HouseTanksOnlinePlayMachine {
    typealias Send = (HouseTanksClientMessage, GameRealtimeControlGrantDTO) -> Bool

    private struct Frame {
        let snapshot: HouseTanksSnapshotDTO
        let world: HouseTanksWorld
        let receivedUptime: TimeInterval
        var tick: Double { Double(snapshot.tick) }
    }

    private struct Input {
        let messageID: String
        let sequence: Int64
        let pressed: Bool
        let tick: Int
        let heading: Double
        let sentUptime: TimeInterval
    }

    private struct Correction {
        var x = 0.0, y = 0.0, rotation = 0.0
        static let zero = Correction()
    }

    private let localPlayerID: String?
    private let configuration: HouseTanksPlayConfiguration
    private let makeID: () -> String
    private let send: Send
    private let resync: () -> Void
    private var state = HouseTanksOnlineLobbyState()
    private var frames: [Frame] = []
    private var lastDisplayTick = 0.0
    private var binding: GameRealtimeControlGrantDTO?
    private var sequence: Int64 = 0
    private var lastACK: Int64 = 0
    /// The highest sequence sent in a generation. The server rejects anything at or below
    /// its highest accepted input (`stale_control`), which can be above the ACK, so a
    /// rebind to the same generation (rotation, resync) continues past it.
    private var sentHighWater: (generation: String, sequence: Int64)?
    /// Sent and not yet acknowledged, oldest first; replayed by the prediction.
    private var inputs: [Input] = []
    /// Our own press messages still able to draw a rejection.
    private var sentIDs: [String: Bool] = [:]
    private var sentOrder: [String] = []
    /// Changes waiting for the rate limit, in order; a quick tap keeps both halves.
    private var queued: [Bool] = []
    private var sentTimes: [TimeInterval] = []
    private var isHeld = false
    private var sentPressed = false
    private var eliminatedRound: (epoch: Int64, round: Int)?
    /// The vote sent and not yet shown by a snapshot; a rejection, a new round or
    /// `voteWait` without confirmation drops it and the snapshot's vote shows again.
    private var pendingVote: (ready: Bool, epoch: Int64, round: Int, sentAt: TimeInterval)?
    /// Our own vote messages still able to draw a rejection.
    private var voteIDs: [String: Bool] = [:]
    private let voteWait: TimeInterval = 2
    private var isSpectating = false
    private var backoffUntil: TimeInterval = 0
    private var lastResyncAt = -TimeInterval.infinity
    /// When the server last answered `stale_control`; see the type comment.
    private var staleControlAt: TimeInterval?
    private var controlWaitStartedAt: TimeInterval?
    private var eventEpoch: (session: String, epoch: Int64)?
    private var lastEventSequence: Int64 = 0
    private var pendingEvents: [HouseTanksWorld.Event] = []
    private var suppressHistoricalEvents = true
    /// The own tank as last drawn: what a press reports.
    private var shown: (tick: Int, heading: Double)?
    private var correction = Correction.zero
    private var correctionAt: TimeInterval = 0
    private var reduceMotion = false
    private var isClosed = false
    let diagnostics: HouseTanksDiagnosticsRecorder

    init(localPlayerID: String?, configuration: HouseTanksPlayConfiguration,
         diagnostics: HouseTanksDiagnosticsRecorder = .init(),
         makeID: @escaping () -> String, send: @escaping Send, resync: @escaping () -> Void) {
        self.localPlayerID = localPlayerID
        self.configuration = configuration
        self.diagnostics = diagnostics
        self.makeID = makeID
        self.send = send
        self.resync = resync
    }

    func disconnect() {
        guard !isClosed else { return }
        isClosed = true
        frames.removeAll()
        pendingEvents.removeAll()
        clearControl()
    }

    func setReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
        if enabled { correction = .zero }
    }

    // MARK: Frames

    /// Called synchronously for every lobby publication.
    func consume(_ incoming: HouseTanksOnlineLobbyState, now: TimeInterval) throws {
        guard !isClosed else { return }
        let before = reduceMotion ? nil : drawnLocal(at: now)
        let previous = frames.last
        let changedConnection = state.connectionGeneration != incoming.connectionGeneration
        state = incoming
        guard let snapshot = incoming.game else {
            frames.removeAll()
            pendingEvents.removeAll()
            clearControl()
            suppressHistoricalEvents = true
            return
        }
        if changedConnection || incoming.connection != .connected || !incoming.isForeground || !incoming.isSynced
            || incoming.controlTransferred {
            staleControlAt = nil
        }
        if changedConnection || incoming.connection != .connected || !incoming.isForeground || !incoming.isSynced {
            clearControl()
            pendingEvents.removeAll()
            suppressHistoricalEvents = true
        }
        var appended = false
        var resetTimeline = false
        let sameWorld = previous?.snapshot.sessionId == snapshot.sessionId
            && previous?.snapshot.runtimeEpoch == snapshot.runtimeEpoch
        // An older or equal state is not drawn again, but its publication still carries the grant.
        let isNewer = !sameWorld || previous.map { snapshot.stateSequence > $0.snapshot.stateSequence } ?? true
        if isNewer {
            if let previous, sameWorld, snapshot.tick < previous.snapshot.tick { throw GameRealtimeError.invalidResponse }
            // An unknown map draws nothing; the lobby asks for an update.
            guard let world = HouseTanksWorld(server: snapshot) else {
                frames.removeAll()
                clearControl()
                return
            }
            resetTimeline = !sameWorld || previous?.snapshot.roundNumber != snapshot.roundNumber
            if !resetTimeline, let previous,
               Double(snapshot.tick - previous.snapshot.tick) > configuration.staleFrameAge * Double(HouseTanksWorld.physicsRate) {
                // Frames were lost (reconnect, resync): never slide bodies across the gap; the
                // display holds the new frame until the delay catches up.
                frames.removeAll()
                diagnostics.gapResets += 1
                diagnostics.timelineRestarted()
            }
            if resetTimeline {
                diagnostics.timelineRestarted()
                frames.removeAll()
                lastDisplayTick = 0
                correction = .zero
                pendingEvents.removeAll()
                pendingVote = nil
                if sameWorld {
                    // A new round starts every tank released; a held button must be pressed again.
                    sentPressed = false
                    queued.removeAll()
                    inputs.removeAll()
                } else {
                    clearControl()
                }
            }
            collectEvents(snapshot)
            frames.append(Frame(snapshot: snapshot, world: world, receivedUptime: incoming.gameReceivedUptime ?? now))
            frames = Array(frames.suffix(max(2, min(16, configuration.snapshotCapacity))))
            appended = true
            diagnostics.frameDrawn(receivedUptime: incoming.gameReceivedUptime ?? now)
        }
        let grant = incoming.validControl(playerID: localPlayerID)
        let seat = snapshot.players.first { $0.playerId == localPlayerID }
        if grant == nil, incoming.isSynced, incoming.isForeground, incoming.isLandscape, snapshot.phase == .playing,
           !incoming.isTerminal, !incoming.controlTransferred, let seat, !seat.hasLeft {
            if controlWaitStartedAt == nil { controlWaitStartedAt = now }
        } else {
            controlWaitStartedAt = nil
        }
        if grant != binding {
            clearControl()
            binding = grant
            // A new generation counts from zero; gaps are allowed, so the ACK is a safe floor,
            // and the same generation again continues above what was already sent.
            let acknowledged = max(0, seat?.lastProcessedInputSequence ?? 0)
            let sent = grant.flatMap { grant in
                sentHighWater.flatMap { $0.generation == grant.controlGeneration ? $0.sequence : nil } } ?? 0
            sequence = grant == nil ? 0 : max(acknowledged, sent)
            lastACK = grant == nil ? 0 : acknowledged
        }
        if binding != nil, let seat {
            guard seat.lastProcessedInputSequence >= lastACK else { throw GameRealtimeError.invalidResponse }
            lastACK = seat.lastProcessedInputSequence
            sequence = max(sequence, lastACK)
            if let acknowledged = inputs.last(where: { $0.sequence <= lastACK }) {
                diagnostics.acknowledged(after: (incoming.gameReceivedUptime ?? now) - acknowledged.sentUptime)
            }
            inputs.removeAll { $0.sequence <= lastACK }
        }
        if let pending = pendingVote, snapshot.runtimeEpoch != pending.epoch || snapshot.roundNumber != pending.round
            || snapshot.roundPhase != .roundReady || seat?.roundReady == pending.ready {
            pendingVote = nil
        }
        if appended, !resetTimeline, let before, let after = predictedLocal(at: now) {
            // What was drawn stays drawn; the difference fades out over ~80 ms.
            let x = before.position.x - after.position.x
            let y = before.position.y - after.position.y
            let rotation = HouseTanksMath.normalizedAngle(before.rotation - after.rotation)
            let fits = hypot(x, y) <= 40 && abs(rotation) <= 0.6
            correction = fits ? Correction(x: x, y: y, rotation: rotation) : .zero
            correctionAt = now
            if hypot(x, y) > 0.5 || abs(rotation) > 0.005 {
                if fits { diagnostics.corrections += 1 } else { diagnostics.snaps += 1 }
            }
        }
        flush(now: now)
    }

    /// Events are new by sequence within one runtime epoch; a fresh timeline (first frame,
    /// reconnect, resync, new epoch) treats the frame's events as history and plays none.
    private func collectEvents(_ snapshot: HouseTanksSnapshotDTO) {
        let world = (session: snapshot.sessionId, epoch: snapshot.runtimeEpoch)
        if eventEpoch?.session != world.session || eventEpoch?.epoch != world.epoch {
            eventEpoch = world
            lastEventSequence = 0
            suppressHistoricalEvents = true
        }
        let fresh = snapshot.events.filter { $0.sequence > lastEventSequence }.sorted { $0.sequence < $1.sequence }
        lastEventSequence = max(lastEventSequence, snapshot.events.map(\.sequence).max() ?? 0)
        if suppressHistoricalEvents {
            // Marked as seen; frames after this one on a synced connection play again.
            if state.isSynced, state.connection == .connected, state.isForeground { suppressHistoricalEvents = false }
            return
        }
        pendingEvents += fresh.compactMap(HouseTanksPlayMath.event)
        pendingEvents = Array(pendingEvents.suffix(64))
    }

    // MARK: Button

    func press(now: TimeInterval) {
        isHeld = true
        guard canPress(at: now), (queued.last ?? sentPressed) == false else { return }
        queued.append(true)
        flush(now: now)
    }

    func release(now: TimeInterval) {
        isHeld = false
        guard binding != nil, (queued.last ?? sentPressed) == true else { return }
        queued.append(false)
        flush(now: now)
    }

    /// The vote for the next round. Sent only when it changes what the screen shows.
    func vote(_ ready: Bool, now: TimeInterval) {
        guard canVote, let binding, let game = state.game, displayedVote != ready else { return }
        let message = HouseTanksClientMessage(messageId: makeID(), action: .gameplay(.roundReady(
            controlGeneration: binding.controlGeneration, ready: ready)))
        guard send(message, binding) else {
            guard !isClosed else { return }
            clearControl()
            requestResync(at: now)
            return
        }
        if voteIDs.count >= 8 { voteIDs.removeAll() }
        voteIDs[message.messageId] = ready
        pendingVote = (ready, game.runtimeEpoch, game.roundNumber, now)
    }

    func reject(messageID: String?, rejection: GameRealtimeRejection, now: TimeInterval) {
        if rejection.code == HouseTanksRealtime.staleControlCode { diagnostics.staleControls += 1 }
        if rejection.code == "realtime.error.rate_limited" { diagnostics.rateLimited += 1 }
        if let messageID, let ready = voteIDs.removeValue(forKey: messageID) {
            // `invalid_input` is a vote that arrived after the round started: nothing to redo.
            if pendingVote?.ready == ready { pendingVote = nil }
            if rejection.code == HouseTanksRealtime.staleControlCode {
                clearControl()
                staleControlAt = now
            }
            return
        }
        guard let messageID, let pressed = sentIDs.removeValue(forKey: messageID) else { return }
        let wasLatest = inputs.last?.messageID == messageID
        inputs.removeAll { $0.messageID == messageID }
        switch rejection.code {
        case HouseTanksRealtime.staleControlCode:
            // Drop the input and let the next frames show who holds the tank; never replay the sequence.
            clearControl()
            staleControlAt = now
        case "houseTanks.error.player_eliminated":
            // The tank died this round; the player is still in the match and votes.
            if let game = frames.last?.snapshot { eliminatedRound = (game.runtimeEpoch, game.roundNumber) }
            queued.removeAll()
            sentPressed = false
        case "houseTanks.error.control_unavailable":
            isSpectating = true
            queued.removeAll()
            sentPressed = false
        case "houseTanks.error.not_running":
            queued.removeAll()
            sentPressed = false
        case "realtime.error.rate_limited", "realtime.error.unavailable":
            backoffUntil = now + (rejection.code == "realtime.error.rate_limited" ? 0.5 : 0.25)
            // The server did not apply it: send the button's state again after the backoff.
            if wasLatest, queued.isEmpty {
                sentPressed = !pressed
                if isHeld != sentPressed, isHeld == false || canPress(at: now) { queued.append(isHeld) }
            }
        default:
            break // invalid_input and unknown codes: logged by the host, never shown.
        }
    }

    /// Presses sent and not yet acknowledged by a snapshot.
    var pendingInputCount: Int { inputs.count }

    // MARK: Timer

    func tick(at now: TimeInterval) {
        if let pending = pendingVote, now - pending.sentAt > voteWait { pendingVote = nil }
        guard !isClosed, let newest = frames.last, newest.snapshot.phase == .playing,
              state.connection == .connected, state.isForeground, state.isSynced,
              !state.controlTransferred, !state.isTerminal else { return }
        if now - newest.receivedUptime > configuration.staleFrameAge * 2 {
            requestResync(at: now)
            return
        }
        if let staleControlAt, now - staleControlAt >= configuration.staleControlSettle {
            // No takeover showed up: the grant stands but the server refused it, so rebind.
            self.staleControlAt = nil
            requestResync(at: now)
            return
        }
        if let controlWaitStartedAt, now - controlWaitStartedAt >= configuration.controlWait {
            requestResync(at: now)
            return
        }
        inputs.removeAll { now - $0.sentUptime > configuration.inputLifetime }
        flush(now: now)
    }

    private func flush(now: TimeInterval) {
        guard !queued.isEmpty else { return }
        guard let binding, state.validControl(playerID: localPlayerID) == binding, !isSpectating else {
            queued.removeAll()
            return
        }
        let rate = (state.runtimeSettings ?? .releaseDefaults).pressRate(preferredHz: configuration.preferredPressRateHz)
        while let pressed = queued.first, now >= backoffUntil {
            sentTimes.removeAll { now - $0 >= 1 }
            guard Double(sentTimes.count) < rate, sequence < Int64.max else { return }
            let pose = shown ?? drawnLocal(at: now).map { (tick: predictionTick(at: now), heading: $0.rotation) }
                ?? (tick: Int(frames.last?.snapshot.tick ?? 0), heading: 0)
            let heading = pose.heading.isFinite ? pose.heading : 0
            sequence += 1
            let message = HouseTanksClientMessage(messageId: makeID(), action: .gameplay(.press(
                controlGeneration: binding.controlGeneration, inputSequence: sequence, pressed: pressed,
                clientTick: Int64(max(0, pose.tick)), heading: heading)))
            queued.removeFirst()
            guard send(message, binding) else {
                guard !isClosed else { return }
                clearControl()
                requestResync(at: now)
                return
            }
            sentPressed = pressed
            sentHighWater = (binding.controlGeneration, sequence)
            sentTimes.append(now)
            remember(message.messageId, pressed: pressed)
            inputs.append(Input(messageID: message.messageId, sequence: sequence, pressed: pressed,
                                tick: max(0, pose.tick), heading: heading, sentUptime: now))
            inputs = Array(inputs.suffix(32))
        }
    }

    private func remember(_ id: String, pressed: Bool) {
        sentIDs[id] = pressed
        sentOrder.append(id)
        if sentOrder.count > 32 { sentIDs[sentOrder.removeFirst()] = nil }
    }

    // MARK: Drawing

    func render(at now: TimeInterval) -> HouseTanksOnlinePresentation? {
        guard !isClosed, let newest = frames.last else { return nil }
        let snapshot = newest.snapshot
        let age = max(0, now - newest.receivedUptime)
        let live = snapshot.phase == .playing && state.connection == .connected && state.isSynced && state.isForeground
        let displayTick = live ? self.displayTick(at: now) : newest.tick
        lastDisplayTick = displayTick
        var world = interpolated(at: displayTick, newest: newest)
        if live, let local = drawnLocal(at: now), let index = world.tanks.firstIndex(where: { $0.id == local.id }) {
            var tanks = world.tanks
            tanks[index] = local
            world = world.placed(tick: world.tick, tanks: tanks, obstacles: world.obstacles, projectiles: world.projectiles)
            shown = (predictionTick(at: now), local.rotation)
        } else if let local = world.tank(localPlayerID ?? "") {
            shown = (Self.whole(displayTick), local.rotation)
        }
        let events: [HouseTanksWorld.Event]
        if live {
            events = pendingEvents.filter { Double($0.tick) <= displayTick }
            pendingEvents.removeAll { Double($0.tick) <= displayTick }
        } else {
            events = pendingEvents
            pendingEvents.removeAll()
        }
        let bodies = Dictionary(snapshot.tanks.map { ($0.playerId, $0) }, uniquingKeysWith: { first, _ in first })
        let vote = displayedVote
        let seats = snapshot.players.sorted { $0.seat < $1.seat }.map { player in
            HouseTanksOnlineSeat(
                playerID: player.playerId, displayName: player.displayName, color: player.color, armor: player.armor,
                roundsWon: player.roundsWon, isAlive: player.isAlive,
                isConnected: player.connected && !player.hasLeft && bodies[player.playerId]?.controllable != false,
                hasLeft: player.hasLeft, roundReady: player.playerId == localPlayerID ? vote : player.roundReady,
                isLocal: player.playerId == localPlayerID,
                powerUp: world.powerUpStatus(for: player.playerId))
        }
        let offline = snapshot.phase == .playing
            ? Set(seats.filter { $0.isAlive && !$0.isConnected }.map(\.playerID)) : []
        let local = snapshot.players.first { $0.playerId == localPlayerID }
        // Votes count for players with control, as on the server.
        let voters = seats.filter(\.isConnected)
        let spectating = snapshot.phase == .playing && (isSpectating || local.map(\.hasLeft) ?? true)
        let destroyed = snapshot.phase == .playing && snapshot.roundPhase == .roundPlaying && !spectating
            && (local.map { !$0.isAlive } ?? false || eliminatedRound.map {
                $0.epoch == snapshot.runtimeEpoch && $0.round == snapshot.roundNumber } ?? false)
        let awaiting = snapshot.roundPhase == .roundPlaying && !spectating && !destroyed
            && controlWaitStartedAt.map { now - $0 >= configuration.controlNoticeDelay } ?? false
        return HouseTanksOnlinePresentation(
            world: world, roundKey: "\(snapshot.sessionId):\(snapshot.runtimeEpoch):\(snapshot.roundNumber)",
            events: events, phase: snapshot.phase, roundPhase: snapshot.roundPhase, roundNumber: snapshot.roundNumber,
            roundWinnerID: snapshot.roundWinnerId, seats: seats, offlinePlayerIDs: offline,
            canPress: canPress(at: now), isPressed: isHeld,
            canVote: canVote, isLocalReady: vote, isVotePending: pendingVote != nil,
            readyCount: voters.filter(\.roundReady).count, voterCount: voters.count, championID: snapshot.championId,
            isLocalTankDestroyed: destroyed,
            isSyncing: state.connection != .connected || snapshot.phase == .recovering
                || (snapshot.phase == .playing && (!state.isSynced || age > configuration.staleFrameAge)),
            isAwaitingControl: awaiting, isSpectating: spectating)
    }

    /// The server tick the screen shows: the best clock estimate over the buffer, minus the
    /// delay, never backwards and never more than `maximumExtrapolation` past the newest frame.
    private func displayTick(at now: TimeInterval) -> Double {
        guard let newest = frames.last else { return 0 }
        let rate = Double(HouseTanksWorld.physicsRate)
        let offset = frames.map { $0.tick / rate - $0.receivedUptime }.max() ?? 0
        let target = (now + offset - configuration.interpolationDelay) * rate
        let latest = newest.tick + configuration.maximumExtrapolation * rate
        return min(latest, max(lastDisplayTick, frames[0].tick, target))
    }

    /// Bodies and crates between the two frames around `tick`; discrete state (alive,
    /// destroyed, armor, jokers) always from the newest frame.
    private func interpolated(at tick: Double, newest: Frame) -> HouseTanksWorld {
        let rate = Double(HouseTanksWorld.physicsRate)
        var pose: (HouseTanksWorld.Tank) -> HouseTanksWorld.Tank = { $0 }
        var cratePosition: (Int) -> HouseTanksVector? = { _ in nil }
        if let right = frames.firstIndex(where: { $0.tick >= tick }), right > 0 {
            let a = frames[right - 1], b = frames[right]
            let t = b.tick > a.tick ? max(0, min(1, (tick - a.tick) / (b.tick - a.tick))) : 1
            pose = { tank in
                guard let old = a.world.tank(tank.id), let new = b.world.tank(tank.id), old.isActive, new.isActive else { return tank }
                var drawn = tank
                drawn.position = HouseTanksPlayMath.lerp(old.position, new.position, t)
                drawn.rotation = HouseTanksPlayMath.lerpAngle(old.rotation, new.rotation, t)
                return drawn
            }
            cratePosition = { index in
                guard a.world.obstacles.indices.contains(index), b.world.obstacles.indices.contains(index) else { return nil }
                return HouseTanksPlayMath.lerp(a.world.obstacles[index].position, b.world.obstacles[index].position, t)
            }
        } else if let first = frames.first, tick <= first.tick {
            pose = { tank in
                guard let old = first.world.tank(tank.id), old.isActive else { return tank }
                var drawn = tank
                drawn.position = old.position
                drawn.rotation = old.rotation
                return drawn
            }
            cratePosition = { index in first.world.obstacles.indices.contains(index) ? first.world.obstacles[index].position : nil }
        } else {
            let dt = max(0, tick - newest.tick) / rate
            pose = { tank in
                guard tank.isActive else { return tank }
                var drawn = tank
                drawn.position = tank.position + tank.velocity * dt
                if !tank.isDriving, tank.aimLocks == 0, tank.isControllable {
                    drawn.rotation += HouseTanksWorld.rotationSpeed * tank.rotationDirection * dt
                }
                return drawn
            }
        }
        let tanks = newest.world.tanks.map(pose)
        let obstacles = newest.world.obstacles.map { obstacle -> HouseTanksWorld.Obstacle in
            guard obstacle.isMovable, !obstacle.isDestroyed, let position = cratePosition(obstacle.index) else { return obstacle }
            var drawn = obstacle
            drawn.position = position
            return drawn
        }
        // Shots fly straight: the newest frame's shots placed at the display tick, plus shots
        // that ended after the display tick, until it reaches the newest frame.
        let base = frames.last(where: { $0.tick <= tick }) ?? newest
        let liveIDs = Set(newest.world.projectiles.map(\.id))
        var shots = newest.world.projectiles.filter { Double($0.spawnTick) <= tick }.map { shot(of: $0, from: newest.tick, to: tick) }
        if tick < newest.tick {
            shots += base.world.projectiles.filter { !liveIDs.contains($0.id) }.map { shot(of: $0, from: base.tick, to: tick) }
                .filter { HouseTanksWorld.arenaFrame.contains($0.position) }
        }
        return newest.world.placed(tick: Self.whole(tick), tanks: tanks, obstacles: obstacles, projectiles: shots)
    }

    private func shot(of projectile: HouseTanksWorld.Projectile, from start: Double, to tick: Double) -> HouseTanksWorld.Projectile {
        var drawn = projectile
        drawn.position = projectile.position + projectile.velocity * ((tick - start) / Double(HouseTanksWorld.physicsRate))
        drawn.age = max(0, Self.whole(tick) - projectile.spawnTick)
        return drawn
    }

    // MARK: Own tank

    private func predictionTick(at now: TimeInterval) -> Int {
        guard let newest = frames.last else { return 0 }
        let ahead = min(configuration.maximumPrediction, max(0, now - newest.receivedUptime))
        return Int(newest.snapshot.tick) + Self.whole(ahead * Double(HouseTanksWorld.physicsRate))
    }

    /// The own tank stepped forward from the newest frame by the shared engine, replaying
    /// the presses the server has not acknowledged (aimed as they were drawn). Motion only:
    /// shots, hits and jokers are stripped from the copy.
    private func predictedLocal(at now: TimeInterval) -> HouseTanksWorld.Tank? {
        guard binding != nil, let localPlayerID, let newest = frames.last,
              newest.snapshot.phase == .playing, newest.snapshot.roundPhase == .roundPlaying,
              let tank = newest.world.tank(localPlayerID), tank.isActive, tank.isControllable else { return nil }
        var world = newest.world.withoutShots
        let target = predictionTick(at: now)
        var pending = inputs[...]
        while true {
            while let input = pending.first, input.tick <= world.tick {
                if input.pressed {
                    _ = world.setRotation(localPlayerID, input.heading)
                    world.press(localPlayerID)
                    world = world.withoutShots
                } else {
                    world.release(localPlayerID)
                }
                pending = pending.dropFirst()
            }
            guard world.tick < target else { break }
            world.step()
            world = world.withoutShots
        }
        return world.tank(localPlayerID)
    }

    /// The prediction with the decaying correction of the last disagreement.
    private func drawnLocal(at now: TimeInterval) -> HouseTanksWorld.Tank? {
        guard var tank = predictedLocal(at: now) else { return nil }
        let decay = correctionDecay(at: now)
        tank.position = HouseTanksVector(x: tank.position.x + correction.x * decay, y: tank.position.y + correction.y * decay)
        tank.rotation += correction.rotation * decay
        return tank
    }

    private func correctionDecay(at now: TimeInterval) -> Double {
        reduceMotion ? 0 : exp(-max(0, now - correctionAt) / 0.08)
    }

    private func canPress(at now: TimeInterval) -> Bool {
        guard let binding, let localPlayerID, let newest = frames.last, !isSpectating,
              state.validControl(playerID: localPlayerID) == binding,
              newest.snapshot.roundPhase == .roundPlaying,
              now - newest.receivedUptime <= configuration.staleFrameAge,
              newest.snapshot.players.first(where: { $0.playerId == localPlayerID })?.isAlive == true else { return false }
        if let eliminatedRound, eliminatedRound.epoch == newest.snapshot.runtimeEpoch,
           eliminatedRound.round == newest.snapshot.roundNumber { return false }
        return true
    }

    /// Any player with control votes between rounds, a dead tank's included.
    private var canVote: Bool {
        guard let binding, let localPlayerID, !isSpectating, state.validControl(playerID: localPlayerID) == binding,
              state.game?.roundPhase == .roundReady else { return false }
        return true
    }

    /// The pending vote, else the snapshot's.
    private var displayedVote: Bool {
        pendingVote?.ready ?? state.game?.players.first { $0.playerId == localPlayerID }?.roundReady ?? false
    }

    private func clearControl() {
        pendingVote = nil
        voteIDs.removeAll()
        binding = nil
        inputs.removeAll()
        queued.removeAll()
        sentIDs.removeAll()
        sentOrder.removeAll()
        sequence = 0
        lastACK = 0
        sentPressed = false
        isSpectating = false
        correction = .zero
    }

    /// Whole ticks of a display time; uptime differences are not exact multiples of 1/120.
    private static func whole(_ ticks: Double) -> Int { Int((ticks + 1e-6).rounded(.down)) }

    private func requestResync(at now: TimeInterval) {
        guard state.connection == .connected, state.isForeground, !state.controlTransferred,
              !state.isTerminal, now - lastResyncAt >= 2 else { return }
        lastResyncAt = now
        resync()
    }
}
