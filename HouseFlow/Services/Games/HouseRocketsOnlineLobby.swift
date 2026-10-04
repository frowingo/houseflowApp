import Foundation

/// Owns online lobby orchestration and application heartbeat. No UI or local physics.
@MainActor
final class HouseRocketsOnlineLobby {
    // Synchronous service sinks preserve critical updates before the UI projection coalesces.
    var onStateChange: ((HouseRocketsOnlineLobbyState) -> Void)?
    var onGameplayRejected: ((String?, GameRealtimeRejection) -> Void)?
    private let session: OnlineHouseRocketsSession
    private let context: HouseRocketsLaunchContext
    private let clock: GameRealtimeClock
    private var state = HouseRocketsOnlineLobbyState()
    private var generation = UUID()
    private var isClosed = false
    private var exitDeadline: TimeInterval?
    private var hasWelcome = false
    private var joinAttempted = false
    private var withdrawReady = false
    private var startedAt: TimeInterval = 0
    private var heartbeatInterval: TimeInterval = 2
    private var heartbeatTimeout: TimeInterval = 6
    private var nextPingAt: TimeInterval = 0
    private var pendingPing: (id: String, uptime: TimeInterval)?
    private var bestRTT = TimeInterval.infinity
    private var pendingSyncID: String?
    private var syncDeadline: TimeInterval?
    private var lastPongAt: TimeInterval = 0
    private var connectTask: Task<Void, Never>?
    private var eventTask: Task<Void, Never>?
    private var snapshotTask: Task<Void, Never>?
    private var timerTask: Task<Void, Never>?
    private var commandTask: Task<Void, Never>?
    private var heartbeatTask: Task<Void, Never>?
    private var resyncTask: Task<Void, Never>?
    private let updates: AsyncStream<HouseRocketsOnlineLobbyState>
    private let continuation: AsyncStream<HouseRocketsOnlineLobbyState>.Continuation

    init(session: OnlineHouseRocketsSession, context: HouseRocketsLaunchContext,
         clock: GameRealtimeClock? = nil) {
        self.session = session
        self.context = context
        self.clock = clock ?? .live
        let stream = AsyncStream<HouseRocketsOnlineLobbyState>.makeStream(bufferingPolicy: .bufferingNewest(1))
        updates = stream.stream
        continuation = stream.continuation
        continuation.onTermination = { [weak self] reason in
            guard case .cancelled = reason else { return }
            Task { @MainActor in self?.disconnect() }
        }
    }

    deinit {
        connectTask?.cancel()
        eventTask?.cancel()
        snapshotTask?.cancel()
        timerTask?.cancel()
        commandTask?.cancel()
        heartbeatTask?.cancel()
        resyncTask?.cancel()
        continuation.finish()
    }

    func events() -> AsyncStream<HouseRocketsOnlineLobbyState> { updates }

    func start(isForeground: Bool, isLandscape: Bool) {
        guard !isClosed, state.connection == .idle else { return }
        state.isForeground = isForeground
        state.isLandscape = isLandscape
        withdrawReady = !isForeground || !isLandscape
        state.connection = .connecting
        startedAt = clock.uptime()
        publish()
        let expected = generation
        let events = session.events()
        eventTask = Task { [weak self] in
            do {
                for try await event in events {
                    guard !Task.isCancelled, let self, self.generation == expected else { return }
                    guard event.generation == self.session.generation else { continue }
                    switch event.payload {
                    case .message(let received): self.receive(received)
                    case .failure(let failure): self.fail(.connection(failure))
                    case .connection: break // Welcome + session sync establish lobby readiness together.
                    }
                }
            } catch {
                guard !Task.isCancelled, let self, self.generation == expected else { return }
                self.fail(.connection(self.failure(from: error)))
            }
        }
        let snapshots = session.snapshots()
        snapshotTask = Task { [weak self] in
            for await received in snapshots {
                guard !Task.isCancelled, let self, self.generation == expected else { return }
                guard received.generation == self.session.generation else { continue }
                self.receive(received)
            }
        }
        connectTask = Task { [weak self, session, context] in
            do {
                let initial = try await session.connect(context: context)
                guard !Task.isCancelled, let self, self.generation == expected else { return }
                // HTTP is a preview; only a socket session snapshot enables join/ready.
                if self.state.session == nil { self.state.session = initial }
                self.publish()
            } catch {
                guard !Task.isCancelled, let self, self.generation == expected else { return }
                self.fail(.connection(self.failure(from: error)))
            }
        }
        let clock = self.clock
        timerTask = Task { [weak self] in
            do {
                while !Task.isCancelled {
                    try await clock.sleep(0.25)
                    guard let self, self.generation == expected else { return }
                    self.tick()
                }
            } catch { /* Cancellation closes the timer. */ }
        }
    }

    func setLandscape(_ landscape: Bool) {
        state.isLandscape = landscape
        if !landscape { withdrawReady = true }
        reconcile()
        publish()
    }

    func setForeground(_ active: Bool) {
        guard state.isForeground != active else { return }
        state.isForeground = active
        if !active {
            withdrawReady = true
        } else if hasWelcome, !state.isTerminal {
            // Resume requires fresh authoritative sync before ready can be enabled.
            state.isSynced = false
            state.controlGrant = nil
            pendingPing = nil
            nextPingAt = clock.uptime()
            lastPongAt = nextPingAt
            requestSync()
        }
        reconcile()
        publish()
    }

    func setReady(_ ready: Bool) {
        guard state.canChangeReady(playerID: context.localPlayerID),
              !ready || state.isLandscape else { return }
        guard (state.localPlayer(context.localPlayerID)?.state == .ready) != ready else { return }
        withdrawReady = false
        sendLifecycle(.setReady(ready))
    }

    func sendSteering(_ message: GameRealtimeClientMessage, grant: HouseRocketsControlGrantDTO) async throws {
        guard !isClosed, state.validControl(playerID: context.localPlayerID) == grant,
              case .steer(let controlGeneration, _, _) = message.action,
              controlGeneration == grant.controlGeneration else { throw GameRealtimeError.invalidContext }
        let expected = generation
        do {
            try await session.send(message)
            guard expected == generation, !isClosed else { throw CancellationError() }
        } catch {
            guard expected == generation, !isClosed else { throw CancellationError() }
            fail(.connection(failure(from: error)))
            throw error
        }
    }

    func resyncGameplay() {
        guard !isClosed, pendingSyncID == nil, !state.isTerminal else { return }
        state.controlGrant = nil
        requestSync()
        publish()
    }

    func invalidateGameplay() {
        // Do not republish invalid terminal geometry into the same presentation sink.
        state.game = nil
        state.gameReceivedUptime = nil
        fail(.connection(.invalidPayload))
    }

    /// Explicit user exit; socket cleanup by itself is never business leave.
    func leave() async {
        guard !isClosed, !state.isLeaving else { return }
        let deadline = clock.uptime() + 2
        exitDeadline = deadline
        state.isLeaving = true
        publish()
        if state.connection == .connected, !state.isTerminal {
            // TCP send order keeps an in-flight join before this leave.
            await commandTask?.value
            state.pendingCommand = nil
            sendLifecycle(.leave)
            let expected = generation
            do {
                while generation == expected, state.pendingCommand != nil, clock.uptime() < deadline {
                    try await clock.sleep(0.05)
                }
            } catch { /* Cleanup still runs after an interrupted exit. */ }
        }
        disconnect()
    }

    func disconnect() {
        guard !isClosed else { return }
        isClosed = true
        stopTasks()
        session.disconnect()
        state = HouseRocketsOnlineLobbyState()
        publish()
        continuation.finish()
        onStateChange = nil
        onGameplayRejected = nil
    }

    private func receive(_ received: GameRealtimeReceivedMessage) {
        let message = received.message
        if state.serverClock == nil {
            state.serverClock = .init(serverTime: message.sentAt, localUptime: received.receivedUptime)
        }
        switch message.payload {
        case .welcome(let welcome):
            guard !hasWelcome else { return }
            let interval = Double(welcome.settings.controlHeartbeatMilliseconds) / 1_000
            let timeout = Double(welcome.settings.controlTimeoutMilliseconds) / 1_000
            guard interval >= 0.25, timeout > interval, timeout <= 60 else {
                fail(.connection(.protocolFailure(.invalidResponse)))
                return
            }
            hasWelcome = true
            state.runtimeSettings = welcome.settings
            heartbeatInterval = interval
            heartbeatTimeout = timeout
            lastPongAt = received.receivedUptime
            nextPingAt = received.receivedUptime
        case .session(let incoming):
            if let current = state.session {
                guard incoming.version >= current.version else { return }
                if incoming.version == current.version, incoming != current { return }
            }
            state.session = incoming
            if pendingSyncID == nil || pendingSyncID == message.messageId {
                state.isSynced = true
                pendingSyncID = nil
                syncDeadline = nil
            }
            confirmPending(with: incoming)
        case .accepted:
            if state.pendingCommand?.message.messageId == message.messageId {
                state.pendingCommand?.accepted = true
            }
        case .rejected(let rejection):
            guard let pending = state.pendingCommand, pending.message.messageId == message.messageId else {
                onGameplayRejected?(message.messageId, rejection)
                return
            }
            state.pendingCommand = nil
            if pending.message.action == .join, rejection.code == "game.error.player_already_joined" {
                // A concurrent/replayed join needs roster proof, not an optimistic local player.
                requestSync()
            } else {
                state.issue = .rejected(rejection)
                requestSync()
            }
        case .pong(let pong):
            guard let ping = pendingPing, pong.pingId == ping.id else { return }
            let rtt = max(0, received.receivedUptime - ping.uptime)
            if rtt <= bestRTT {
                bestRTT = rtt
                state.serverClock = .init(serverTime: pong.serverTime,
                    localUptime: ping.uptime + rtt / 2)
            }
            pendingPing = nil
            lastPongAt = received.receivedUptime
        case .snapshot(let snapshot):
            guard state.result == nil else { return }
            if let current = state.game {
                guard snapshot.runtimeEpoch > current.runtimeEpoch ||
                    (snapshot.runtimeEpoch == current.runtimeEpoch && snapshot.stateSequence > current.stateSequence) else { return }
            }
            state.game = snapshot
            state.gameReceivedUptime = received.receivedUptime
            if let grant = state.controlGrant, grant.runtimeEpoch < snapshot.runtimeEpoch {
                state.controlGrant = nil
            }
        case .controlGranted(let grant):
            guard grant.runtimeEpoch >= (state.game?.runtimeEpoch ?? 0),
                  grant.runtimeEpoch >= (state.controlGrant?.runtimeEpoch ?? 0) else { return }
            state.controlGrant = grant
        case .result(let result):
            state.result = result
            state.controlGrant = nil
            state.pendingCommand = nil
        }
        reconcile()
        publish()
    }

    private func reconcile() {
        guard hasWelcome, state.isSynced, state.connection != .failed else { return }
        state.connection = .connected
        if state.isTerminal {
            state.pendingCommand = nil
            state.controlGrant = nil
            return
        }
        guard !state.isLeaving else { return }
        if state.isForeground, state.isLobby, state.localPlayer(context.localPlayerID) == nil, !joinAttempted {
            joinAttempted = true
            sendLifecycle(.join)
        }
        if withdrawReady, state.isLobby, state.pendingCommand == nil,
           state.localPlayer(context.localPlayerID)?.state == .ready {
            withdrawReady = false
            sendLifecycle(.setReady(false))
        }
    }

    private func confirmPending(with session: GameSessionDTO) {
        guard let pending = state.pendingCommand, session.version > pending.sessionVersion else { return }
        let player = session.players.first { $0.playerId == context.localPlayerID }
        let confirmed: Bool
        switch pending.message.action {
        case .join: confirmed = player != nil && player?.state != .left
        case .setReady(let ready):
            confirmed = player?.state == (ready ? .ready : .waiting) || !state.isLobby
        case .leave: confirmed = player == nil || player?.state == .left
        default: confirmed = false
        }
        if confirmed {
            state.pendingCommand = nil
            state.issue = nil
        }
    }

    private func sendLifecycle(_ action: GameRealtimeClientAction) {
        guard state.pendingCommand == nil, state.connection == .connected, let version = state.session?.version else { return }
        let now = clock.uptime()
        state.issue = nil
        state.pendingCommand = .init(message: .init(messageId: UUID().uuidString, action: action),
            sessionVersion: version, issuedAt: now, lastSentAt: now)
        sendPending()
        publish()
    }

    private func sendPending() {
        guard commandTask == nil, var pending = state.pendingCommand else { return }
        pending.attempts += 1
        pending.lastSentAt = clock.uptime()
        state.pendingCommand = pending
        let expected = generation
        let message = pending.message
        commandTask = Task { [weak self, session] in
            do {
                try await session.send(message)
                guard !Task.isCancelled, let self, self.generation == expected else { return }
                self.commandTask = nil
                if self.state.pendingCommand?.attempts == 0 { self.sendPending() }
                self.reconcile()
                self.publish()
            } catch {
                guard !Task.isCancelled, let self, self.generation == expected else { return }
                self.fail(.connection(self.failure(from: error)))
            }
        }
    }

    private func tick() {
        let now = clock.uptime()
        if let exitDeadline, now >= exitDeadline {
            disconnect()
            return
        }
        if state.connection == .connecting, now - startedAt >= 10 {
            fail(.timeout)
            return
        }
        guard hasWelcome, state.connection != .failed, !state.isTerminal else { return }
        if state.isForeground, let syncDeadline, now >= syncDeadline {
            fail(.timeout)
            return
        }
        if state.isForeground {
            if now - lastPongAt >= heartbeatTimeout {
                fail(.timeout)
                return
            }
            if now >= nextPingAt, pendingPing == nil, heartbeatTask == nil { sendHeartbeat(at: now) }
        }
        if let pending = state.pendingCommand, !state.isLeaving {
            if now - pending.issuedAt >= 8 {
                fail(.commandTimeout)
                return
            }
            if now - pending.issuedAt >= 4, !pending.requestedSync {
                state.pendingCommand?.requestedSync = true
                requestSync()
            }
            if !pending.accepted, pending.attempts < 2, now - pending.lastSentAt >= 3 {
                sendPending() // Same lifecycle messageId/content; never applies to steer.
            }
        }
    }

    private func sendHeartbeat(at now: TimeInterval) {
        let id = UUID().uuidString
        pendingPing = (id, now)
        nextPingAt = now + heartbeatInterval
        let expected = generation
        heartbeatTask = Task { [weak self, session] in
            do {
                try await session.send(.init(messageId: id, action: .ping(id: id)))
                guard !Task.isCancelled, let self, self.generation == expected else { return }
                self.heartbeatTask = nil
            } catch {
                guard !Task.isCancelled, let self, self.generation == expected else { return }
                self.fail(.connection(self.failure(from: error)))
            }
        }
    }

    private func requestSync() {
        guard hasWelcome, resyncTask == nil, state.connection != .failed, !state.isTerminal else { return }
        let expected = generation
        let id = UUID().uuidString
        pendingSyncID = id
        syncDeadline = clock.uptime() + 5
        state.isSynced = false
        resyncTask = Task { [weak self, session] in
            do {
                try await session.send(.init(messageId: id, action: .resync))
                guard !Task.isCancelled, let self, self.generation == expected else { return }
                self.resyncTask = nil
            } catch {
                guard !Task.isCancelled, let self, self.generation == expected else { return }
                self.fail(.connection(self.failure(from: error)))
            }
        }
    }

    private func fail(_ issue: HouseRocketsOnlineLobbyIssue) {
        stopTasks()
        session.disconnect()
        state.connection = state.isTerminal ? .idle : .failed
        state.isSynced = false
        state.controlGrant = nil
        state.pendingCommand = nil
        state.issue = state.isTerminal ? nil : issue
        if case .connection(.http(let status, let retryAfter)) = issue,
           [429, 503].contains(status), let retryAfter {
            state.retryNotBefore = clock.uptime() + retryAfter
        }
        publish()
    }

    private func stopTasks() {
        generation = UUID()
        connectTask?.cancel(); connectTask = nil
        eventTask?.cancel(); eventTask = nil
        snapshotTask?.cancel(); snapshotTask = nil
        timerTask?.cancel(); timerTask = nil
        commandTask?.cancel(); commandTask = nil
        heartbeatTask?.cancel(); heartbeatTask = nil
        resyncTask?.cancel(); resyncTask = nil
        pendingPing = nil
        pendingSyncID = nil
        syncDeadline = nil
    }

    private func failure(from error: Error) -> GameRealtimeSessionFailure {
        if let error = error as? NetworkHTTPFailure {
            return .http(statusCode: error.statusCode, retryAfterSeconds: error.retryAfterSeconds(at: clock.wallTime()))
        }
        if let error = error as? GameRealtimeError { return .protocolFailure(error) }
        if error is DecodingError { return .invalidPayload }
        return .transport
    }

    private func publish() {
        onStateChange?(state)
        continuation.yield(state)
    }
}
