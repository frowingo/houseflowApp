import Foundation

public struct FausSwitchPlayConfiguration: Sendable {
    /// How long past the newest snapshot robots keep running on screen.
    public var maximumExtrapolation: TimeInterval = 0.35
    /// A playing match without snapshots for this long asks for a full sync.
    public var staleSnapshotResync: TimeInterval = 1
    public var retransmitInterval: TimeInterval = 0.25
    public var maximumRetransmits = 3
    public var inputCapacity = 16
    /// A correction larger than this (world units) snaps instead of easing.
    public var correctionLimit = 70.0
    public var correctionTime: TimeInterval = 0.08

    public init() {}
}

public enum FausSwitchFlipFeedback: Equatable, Sendable {
    case flipped
    /// The robot is mid-air: the tap does nothing, as in demo.
    case unsupported
    /// No control right now (countdown, syncing, finished).
    case ignored
}

/// What the online screen draws for one display frame.
public struct FausSwitchOnlinePresentation: Equatable, Sendable {
    public var frame: FausSwitchRenderFrame
    public var canFlip: Bool
    public var isSyncing: Bool

    public init(frame: FausSwitchRenderFrame, canFlip: Bool, isSyncing: Bool) {
        self.frame = frame
        self.canFlip = canFlip
        self.isSyncing = isSyncing
    }
}

/// Display timing, flips and prediction without tasks. Every robot is drawn at the
/// current tick by stepping the whole race (robots block each other, in the snapshot's
/// seat order) from the newest snapshot; the player's own unconfirmed flips are
/// replayed on top. Other players' flips are only known from the next snapshot. A new snapshot's
/// small differences ease out over 80 ms.
final class FausSwitchOnlinePlayMachine {
    typealias Send = (FausSwitchClientMessage, GameRealtimeControlGrantDTO) -> Bool

    private struct PendingFlip {
        let message: FausSwitchClientMessage
        let sequence: Int64
        let clientTick: Int64
        var sentUptime: TimeInterval
        var attempts = 0
    }

    private struct CacheKey: Equatable {
        let epoch: Int64
        let sequence: Int64
        let inputs: Int
    }

    var onControlLost: (() -> Void)?
    /// The local robot's server-confirmed end (finish or crash), once per match.
    var onLocalOutcome: ((FausSwitchRunnerStatus) -> Void)?

    private let localPlayerID: String
    private let configuration: FausSwitchPlayConfiguration
    private let baseCourse: FausSwitchCourse
    /// The base course plus one start platform per robot of the current snapshot.
    private var course: FausSwitchCourse
    private var courseRunnerCount = 0
    private let makeID: () -> String
    private let send: Send
    private let resync: () -> Void
    private var state = FausSwitchOnlineLobbyState()
    private var snapshot: FausSwitchSnapshotDTO?
    private var receivedUptime: TimeInterval = 0
    private var binding: GameRealtimeControlGrantDTO?
    private var inputs: [PendingFlip] = []
    private var inputsVersion = 0
    private var sequence: Int64 = 0
    private var lastACK: Int64 = 0
    private var cache: (key: CacheKey, tick: Int64, runners: [FausSwitchRunnerState])?
    private var corrections: [String: (x: Double, y: Double)] = [:]
    private var correctionAt: TimeInterval = 0
    private var lastResyncAt = -TimeInterval.infinity
    private var controlWaitStartedAt: TimeInterval?
    private var backoffUntil: TimeInterval = 0
    private var reportedOutcome = false
    private var reduceMotion = false
    private var isClosed = false

    init(localPlayerID: String, configuration: FausSwitchPlayConfiguration, course: FausSwitchCourse = .standard,
         makeID: @escaping () -> String, send: @escaping Send, resync: @escaping () -> Void) {
        self.localPlayerID = localPlayerID
        self.configuration = configuration
        baseCourse = course
        self.course = course
        self.makeID = makeID
        self.send = send
        self.resync = resync
    }

    var pendingInputCount: Int { inputs.count }

    func disconnect() {
        guard !isClosed else { return }
        isClosed = true
        snapshot = nil
        cache = nil
        corrections = [:]
        clearControl()
        onControlLost = nil
        onLocalOutcome = nil
    }

    func setReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
        if enabled { corrections = [:] }
    }

    /// Called synchronously for every lobby publication.
    func consume(_ incoming: FausSwitchOnlineLobbyState, now: TimeInterval) throws {
        guard !isClosed else { return }
        let changedConnection = state.connectionGeneration != incoming.connectionGeneration
        let previous = snapshot
        state = incoming
        guard let game = incoming.game else {
            snapshot = nil
            cache = nil
            corrections = [:]
            clearControl()
            return
        }
        if changedConnection || incoming.connection != .connected || !incoming.isForeground || !incoming.isSynced {
            clearControl()
        }

        var before: [String: FausSwitchRunnerState]?
        if game != previous {
            let sameWorld = previous?.sessionId == game.sessionId && previous?.runtimeEpoch == game.runtimeEpoch
            if sameWorld, let previous {
                guard game.stateSequence >= previous.stateSequence else { return }
                guard game.tick >= previous.tick else { throw GameRealtimeError.invalidResponse }
                if !reduceMotion { before = displayed(at: now) }
            } else {
                clearControl()
                corrections = [:]
                reportedOutcome = false
            }
            if game.runners.count != courseRunnerCount {
                courseRunnerCount = game.runners.count
                course = baseCourse.adding(FausSwitchStartGrid.lanes(count: game.runners.count).map(\.platform),
                                           kind: .platform)
            }
            snapshot = game
            receivedUptime = incoming.gameReceivedUptime ?? now
            cache = nil
            // A reconnect into a match the robot already left plays no haptic again.
            if !reportedOutcome, let me = game.runners.first(where: { $0.playerId == localPlayerID }),
               me.status != .running {
                reportedOutcome = true
                if sameWorld { onLocalOutcome?(me.status) }
            }
        }

        let grant = incoming.validControl(playerID: localPlayerID)
        if grant == nil, incoming.isSynced, incoming.isForeground, incoming.isLandscape,
           game.phase == .playing, !incoming.isTerminal, !incoming.controlTransferred,
           game.runners.contains(where: { $0.playerId == localPlayerID && $0.status == .running && $0.connected }) {
            if controlWaitStartedAt == nil { controlWaitStartedAt = now }
        } else {
            controlWaitStartedAt = nil
        }
        if grant != binding {
            clearControl()
            binding = grant
            sequence = game.runners.first(where: { $0.playerId == localPlayerID })?.lastProcessedInputSequence ?? 0
            lastACK = sequence
        }
        if binding != nil, let me = game.runners.first(where: { $0.playerId == localPlayerID }) {
            guard me.lastProcessedInputSequence >= lastACK else { throw GameRealtimeError.invalidResponse }
            lastACK = me.lastProcessedInputSequence
            sequence = max(sequence, lastACK)
            let count = inputs.count
            inputs.removeAll { $0.sequence <= lastACK }
            if inputs.count != count { inputsVersion += 1 }
        }

        if let before {
            let after = predicted(at: now)
            var next: [String: (x: Double, y: Double)] = [:]
            for (id, old) in before {
                guard let new = after[id] else { continue }
                let dx = old.x - new.x
                let dy = old.y - new.y
                if hypot(dx, dy) <= configuration.correctionLimit, hypot(dx, dy) > 0.01 { next[id] = (dx, dy) }
            }
            corrections = next
            correctionAt = now
        }
    }

    func flip(now: TimeInterval) -> FausSwitchFlipFeedback {
        guard canFlip(at: now), let binding, let snapshot, snapshot.phase == .playing else { return .ignored }
        let tick = currentTick(at: now)
        let states = states(at: tick)
        guard let index = localIndex, states.indices.contains(index), states[index].isRunning else { return .ignored }
        guard FausSwitchPhysics.isSupported(states, index: index, course: course) else { return .unsupported }
        guard inputs.count < max(1, configuration.inputCapacity), sequence < Int64.max else {
            clearControl()
            requestResync(at: now)
            return .ignored
        }
        sequence += 1
        let message = FausSwitchClientMessage(messageId: makeID(), action: .gameplay(.flip(
            controlGeneration: binding.controlGeneration, inputSequence: sequence, clientTick: tick)))
        inputs.append(.init(message: message, sequence: sequence, clientTick: tick, sentUptime: now))
        inputsVersion += 1
        guard send(message, binding) else {
            guard !isClosed else { return .ignored }
            clearControl()
            requestResync(at: now)
            return .ignored
        }
        return .flipped
    }

    func reject(messageID: String?, rejection: GameRealtimeRejection, now: TimeInterval) {
        guard let messageID, inputs.contains(where: { $0.message.messageId == messageID }) else { return }
        // A rejected flip is never replayed; the next snapshot shows what the server ran.
        clearControl()
        if [FausSwitchRealtime.staleControlCode, "fausSwitch.error.control_unavailable"].contains(rejection.code) {
            onControlLost?()
            return
        }
        if rejection.code == "realtime.error.rate_limited" { backoffUntil = now + 0.5 }
        requestResync(at: now)
    }

    func tick(at now: TimeInterval) {
        guard !isClosed, let snapshot, snapshot.phase == .playing, state.connection == .connected,
              state.isForeground, state.isSynced, !state.controlTransferred, !state.isTerminal else { return }
        if now - receivedUptime > configuration.staleSnapshotResync {
            clearControl()
            requestResync(at: now)
            return
        }
        if let controlWaitStartedAt, now - controlWaitStartedAt >= 0.5 {
            requestResync(at: now)
            return
        }
        guard let binding else { return }
        for index in inputs.indices where now - inputs[index].sentUptime >= configuration.retransmitInterval {
            guard inputs[index].attempts < configuration.maximumRetransmits else {
                clearControl()
                requestResync(at: now)
                return
            }
            inputs[index].attempts += 1
            inputs[index].sentUptime = now
            // The same message and sequence: the server ignores a flip it already ran.
            guard send(inputs[index].message, binding) else {
                guard !isClosed else { return }
                clearControl()
                requestResync(at: now)
                return
            }
        }
    }

    func render(at now: TimeInterval) -> FausSwitchOnlinePresentation? {
        guard !isClosed, let snapshot else { return nil }
        let tick = currentTick(at: now)
        let states = displayed(at: now)
        let age = max(0, now - receivedUptime)
        let phase: FausSwitchMatchPhase
        switch snapshot.phase {
        case .countdown: phase = .countdown
        case .playing, .recovering: phase = .playing
        case .finalizing, .ended, .cancelled: phase = .ended
        }
        let runners = snapshot.runners.map { dto -> FausSwitchRenderRunner in
            let state = states[dto.playerId] ?? dto.state
            return FausSwitchRenderRunner(id: dto.playerId, nameKey: nil, displayName: dto.displayName, color: dto.color,
                                          state: state, isLocal: dto.playerId == localPlayerID, isConnected: dto.connected,
                                          isBoosted: state.isBoosted(atTick: tick), rank: nil)
        }
        let frame = FausSwitchRenderFrame(matchID: snapshot.sessionId, tick: tick, phase: phase, countdown: nil,
                                          cameraFocus: course.cameraFocus(atTick: tick),
                                          cameraTrail: course.cameraTrail(atTick: tick), runners: runners)
        let syncing = state.connection != .connected || snapshot.phase == .recovering
            || (snapshot.phase == .playing && (!state.isSynced || age > configuration.maximumExtrapolation))
        return .init(frame: frame, canFlip: canFlip(at: now), isSyncing: syncing)
    }

    // MARK: Prediction

    private func currentTick(at now: TimeInterval) -> Int64 {
        guard let snapshot else { return 0 }
        guard snapshot.phase == .playing, state.connection == .connected, state.isSynced else { return snapshot.tick }
        let age = min(configuration.maximumExtrapolation, max(0, now - receivedUptime))
        return snapshot.tick + Int64(age * Double(FausSwitchMetrics.physicsRate))
    }

    private func canFlip(at now: TimeInterval) -> Bool {
        guard binding != nil, state.validControl(playerID: localPlayerID) == binding else { return false }
        return now >= backoffUntil && now - receivedUptime <= configuration.maximumExtrapolation
    }

    /// Predicted states with the easing offsets applied.
    private func displayed(at now: TimeInterval) -> [String: FausSwitchRunnerState] {
        var states = predicted(at: now)
        guard !corrections.isEmpty, !reduceMotion else { return states }
        let decay = exp(-max(0, now - correctionAt) / configuration.correctionTime)
        guard decay > 0.01 else { return states }
        for (id, offset) in corrections where states[id]?.isRunning == true {
            states[id]?.x += offset.x * decay
            states[id]?.y += offset.y * decay
        }
        return states
    }

    private func predicted(at now: TimeInterval) -> [String: FausSwitchRunnerState] {
        runners(at: currentTick(at: now))
    }

    private var localIndex: Int? { snapshot?.runners.firstIndex { $0.playerId == localPlayerID } }

    private func runners(at target: Int64) -> [String: FausSwitchRunnerState] {
        guard let snapshot else { return [:] }
        return Dictionary(uniqueKeysWithValues: zip(snapshot.runners.map(\.playerId), states(at: target)))
    }

    /// Every robot (seat order) stepped together from the newest snapshot to `target`;
    /// the local robot's unconfirmed flips are applied at their ticks (never before the
    /// snapshot).
    private func states(at target: Int64) -> [FausSwitchRunnerState] {
        guard let snapshot else { return [] }
        let key = CacheKey(epoch: snapshot.runtimeEpoch, sequence: snapshot.stateSequence, inputs: inputsVersion)
        var tick = snapshot.tick
        var runners = snapshot.runners.map(\.state)
        if let cache, cache.key == key, cache.tick <= target, cache.tick >= snapshot.tick {
            tick = cache.tick
            runners = cache.runners
        }
        let local = localIndex
        while tick < target {
            applyFlips(at: tick, base: snapshot.tick, local: local, to: &runners)
            FausSwitchPhysics.step(&runners, tick: tick, course: course)
            tick += 1
        }
        cache = (key, tick, runners)
        // A flip made at this very tick shows at once (the next step runs it again from the cache).
        applyFlips(at: tick, base: snapshot.tick, local: local, to: &runners)
        return runners
    }

    private func applyFlips(at tick: Int64, base: Int64, local: Int?, to runners: inout [FausSwitchRunnerState]) {
        guard let local, runners.indices.contains(local) else { return }
        for input in inputs where max(input.clientTick, base) == tick {
            FausSwitchPhysics.flip(&runners, index: local, course: course)
        }
    }

    private func clearControl() {
        binding = nil
        if !inputs.isEmpty { inputsVersion += 1 }
        inputs.removeAll()
        sequence = 0
        lastACK = 0
    }

    private func requestResync(at now: TimeInterval) {
        guard state.connection == .connected, state.isForeground, !state.controlTransferred,
              !state.isTerminal, now - lastResyncAt >= 1 else { return }
        lastResyncAt = now
        resync()
    }
}
