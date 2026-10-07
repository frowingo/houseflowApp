import Foundation

/// Owns lobby commands, authoritative sync, reconnect and application heartbeat. No UI or local physics.
@MainActor
final class HouseRocketsOnlineLobby {
    // Synchronous service sinks preserve critical updates before the UI projection coalesces.
    var onStateChange: ((HouseRocketsOnlineLobbyState) -> Void)?
    var onGameplayRejected: ((String?, GameRealtimeRejection) -> Void)?
    private let session: OnlineHouseRocketsSession
    private let context: HouseRocketsLaunchContext
    private let clock: GameRealtimeClock
    private let excludingSessionID: String?
    private let reconnectPolicy: HouseRocketsReconnectPolicy
    private let acceptanceRecorder: HouseRocketsAcceptanceRecorder?
    private var attemptID = UUID()
    private var reconnectDeadline: TimeInterval?
    private var reconnectTask: Task<Void, Never>?
    private var sessionSynced = false
    private var gameSynced = false
    private var pendingGameSyncID: String?
    private var stableSince: TimeInterval?
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
         clock: GameRealtimeClock? = nil, excludingSessionID: String? = nil,
         reconnectPolicy: HouseRocketsReconnectPolicy? = nil,
         acceptanceRecorder: HouseRocketsAcceptanceRecorder? = nil) {
        self.session = session
        self.context = context
        self.clock = clock ?? .live
        self.excludingSessionID = excludingSessionID
        self.reconnectPolicy = reconnectPolicy ?? .init()
        self.acceptanceRecorder = acceptanceRecorder
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
        reconnectTask?.cancel()
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
        beginAttempt(isRetry: false)
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

    private func beginAttempt(isRetry: Bool) {
        guard !isClosed, !state.isLeaving, !state.isTerminal, state.isForeground else { return }
        stopConnectionTasks()
        attemptID = UUID()
        let expected = attemptID
        hasWelcome = false
        sessionSynced = false; gameSynced = false
        joinAttempted = false
        state.isSynced = false
        state.controlGrant = nil
        state.connectionGeneration = UUID()
        state.connection = isRetry ? .reconnecting : .connecting
        startedAt = clock.uptime()
        state.serverClock = nil
        bestRTT = .infinity
        publish()
        let session = self.session
        let context = self.context
        let excluded = excludingSessionID
        connectTask = Task { [weak self] in
            do {
                if session.session != nil {
                    try await session.reconnect()
                } else {
                    _ = try await session.connect(context: context, excludingSessionID: excluded)
                }
                guard !Task.isCancelled, let self, self.attemptID == expected, !self.isClosed else { return }
                self.connectTask = nil
                if self.state.session == nil { self.state.session = session.session }
                self.publish()
            } catch {
                guard !Task.isCancelled, let self, self.attemptID == expected, !self.isClosed else { return }
                self.fail(.connection(self.failure(from: error)))
            }
        }
    }

    func retry() {
        guard !isClosed, !state.isLeaving, state.isForeground,
              state.canReconnect(at: clock.uptime()) else { return }
        reconnectDeadline = nil
        state.reconnectAttempt = 0
        state.issue = nil
        state.controlTransferred = false
        beginAttempt(isRetry: true)
    }

    func controlLost() {
        guard !isClosed, !state.isTerminal else { return }
        state.controlTransferred = true
        state.controlGrant = nil
        publish()
    }

    /// Only explicit user intent may reclaim control after another device takes it.
    func reclaimControl() {
        guard !isClosed, state.controlTransferred, state.isForeground,
              state.connection == .connected, !state.isTerminal else { return }
        state.controlTransferred = false
        requestSync()
        publish()
    }

    func setLandscape(_ landscape: Bool) {
        guard !isClosed else { return }
        state.isLandscape = landscape
        if !landscape { withdrawReady = true }
        reconcile()
        publish()
    }

    func setForeground(_ active: Bool) {
        guard !isClosed, state.isForeground != active else { return }
        state.isForeground = active
        if !active {
            withdrawReady = true
            state.controlGrant = nil
            heartbeatTask?.cancel(); heartbeatTask = nil
            pendingPing = nil
            reconnectTask?.cancel(); reconnectTask = nil
        } else if !hasWelcome, state.connection == .connecting, connectTask == nil {
            beginAttempt(isRetry: false)
        } else if state.connection == .reconnecting || state.connection == .failed {
            if !state.isTerminal, !state.controlTransferred,
               HouseRocketsReconnectPolicy.automaticallyRetries(state.issue ?? .timeout) {
                reconnectDeadline = nil
                state.reconnectAttempt = 0
                scheduleReconnect()
            }
        } else if hasWelcome, !state.isTerminal, !state.controlTransferred {
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

    func cancelMatch() {
        guard !isClosed, state.canCancel(context: context) else { return }
        sendLifecycle(.cancel)
    }

    /// Close a committed match while retaining its final roster and geometry for presentation.
    func finish() {
        guard !isClosed else { return }
        isClosed = true
        stopTasks()
        session.disconnect()
        state.connection = .idle
        state.isSynced = false
        state.controlGrant = nil
        state.pendingCommand = nil
        publish()
        continuation.finish()
        onStateChange = nil
        onGameplayRejected = nil
    }

    func sendSteering(_ message: GameRealtimeClientMessage, grant: HouseRocketsControlGrantDTO) async throws {
        guard !isClosed, state.validControl(playerID: context.localPlayerID) == grant,
              case .steer(let controlGeneration, _, _) = message.action,
              controlGeneration == grant.controlGeneration else { throw GameRealtimeError.invalidContext }
        let expected = attemptID
        do {
            try await session.send(message)
            guard expected == attemptID, !isClosed, !Task.isCancelled else { throw CancellationError() }
        } catch {
            guard expected == attemptID, !isClosed, !Task.isCancelled else { throw CancellationError() }
            fail(.connection(failure(from: error)))
            throw error
        }
    }

    func resyncGameplay() {
        guard !isClosed, !state.controlTransferred, state.connection == .connected,
              pendingSyncID == nil, !state.isTerminal else { return }
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
        if hasWelcome, [.connected, .syncing].contains(state.connection), !state.isTerminal {
            // TCP send order keeps an in-flight join before this leave.
            do {
                while commandTask != nil, !isClosed, clock.uptime() < deadline { try await clock.sleep(0.05) }
            } catch { disconnect(); return }
            guard !isClosed, clock.uptime() < deadline else { disconnect(); return }
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
                sessionSynced = true
            }
            confirmPending(with: incoming)
        case .accepted:
            if state.pendingCommand?.message.messageId == message.messageId {
                state.pendingCommand?.accepted = true
            }
        case .rejected(let rejection):
            if rejection.code == "house.error.user_not_member" {
                fail(.connection(.http(statusCode: 403, retryAfterSeconds: nil)))
                return
            }
            guard let pending = state.pendingCommand, pending.message.messageId == message.messageId else {
                if let syncID = pendingSyncID, message.messageId == syncID {
                    if HouseRocketsReconnectPolicy.automaticallyRetries(.rejected(rejection)) {
                        fail(.rejected(rejection))
                    } else {
                        fail(.connection(.invalidPayload))
                    }
                    return
                }
                if let ping = pendingPing, message.messageId == ping.id,
                   rejection.code == "houseRockets.error.stale_control" { controlLost() }
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
            acceptanceRecorder?.record(.roundTrip, seconds: rtt)
            if rtt <= bestRTT {
                bestRTT = rtt
                state.serverClock = .init(serverTime: pong.serverTime,
                    localUptime: ping.uptime + rtt / 2)
            }
            pendingPing = nil
            lastPongAt = received.receivedUptime
        case .snapshot(let snapshot):
            guard state.result == nil else { return }
            let correlated = pendingGameSyncID != nil && pendingGameSyncID == message.messageId
            if let current = state.game {
                // A newer periodic frame can reach the snapshot consumer before this
                // critical sync reply. Keep its geometry while retaining nonce proof.
                if correlated, snapshot.runtimeEpoch == current.runtimeEpoch,
                   snapshot.stateSequence < current.stateSequence {
                    gameSynced = true
                    reconcile()
                    publish()
                    return
                }
                guard snapshot.runtimeEpoch > current.runtimeEpoch ||
                    (snapshot.runtimeEpoch == current.runtimeEpoch &&
                     (snapshot.stateSequence > current.stateSequence ||
                      (snapshot.stateSequence == current.stateSequence && (correlated || !gameSynced)))) else { return }
                let eliminated = Set(current.players.filter { !$0.isAlive }.map(\.playerId))
                guard !snapshot.players.contains(where: { $0.isAlive && eliminated.contains($0.playerId) }) else {
                    fail(.connection(.invalidPayload))
                    return
                }
                if snapshot.runtimeEpoch == current.runtimeEpoch, !state.controlTransferred,
                   state.connection == .connected, pendingSyncID == nil,
                   let grant = state.controlGrant, grant.runtimeEpoch == snapshot.runtimeEpoch,
                   let local = snapshot.players.first(where: { $0.playerId == context.localPlayerID && $0.isAlive }),
                   current.players.first(where: { $0.playerId == context.localPlayerID })?.controlGeneration == grant.controlGeneration,
                   local.controlGeneration == nil {
                    state.controlTransferred = true
                    state.controlGrant = nil
                }
            }
            if pendingGameSyncID == nil || correlated { gameSynced = true }
            state.game = snapshot
            state.gameReceivedUptime = received.receivedUptime
            if let grant = state.controlGrant, grant.runtimeEpoch < snapshot.runtimeEpoch {
                state.controlGrant = nil
            }
        case .controlGranted(let grant):
            guard !state.controlTransferred, grant.runtimeEpoch >= (state.game?.runtimeEpoch ?? 0),
                  grant.runtimeEpoch >= (state.controlGrant?.runtimeEpoch ?? 0) else { return }
            state.controlGrant = grant
        case .result(let result):
            guard state.result == nil else { return }
            do { try result.validate(sessionID: state.session?.sessionId ?? result.sessionId,
                                     houseID: context.houseID ?? "") }
            catch { fail(.connection(.invalidPayload)); return }
            state.result = result
            state.resultEventID = message.messageId
            state.controlGrant = nil
            state.pendingCommand = nil
        }
        reconcile()
        publish()
    }

    private func reconcile() {
        guard !isClosed, hasWelcome, sessionSynced, state.connection != .failed else { return }
        let needsGame = state.session?.state == .running || state.session?.state == .countdown
        guard state.isTerminal || !needsGame || gameSynced else {
            state.isSynced = false
            state.connection = .syncing
            return
        }
        state.isSynced = true
        pendingSyncID = nil; pendingGameSyncID = nil; syncDeadline = nil
        if state.connection != .connected { stableSince = clock.uptime() }
        state.connection = .connected
        state.retryNotBefore = nil
        if case .connection = state.issue { state.issue = nil }
        if state.issue == .timeout { state.issue = nil }
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
        case .cancel: confirmed = session.state == .cancelled
        default: confirmed = false
        }
        if confirmed {
            state.pendingCommand = nil
            state.issue = nil
        }
    }

    private func sendLifecycle(_ action: GameRealtimeClientAction) {
        guard state.pendingCommand == nil,
              state.connection == .connected || (action == .leave && state.connection == .syncing),
              let version = state.session?.version else { return }
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
        if state.connection == .connected, let stableSince, now - stableSince >= heartbeatInterval * 2 {
            reconnectDeadline = nil
            if state.reconnectAttempt != 0 { state.reconnectAttempt = 0; publish() }
        }
        if let exitDeadline, now >= exitDeadline {
            disconnect()
            return
        }
        if let deadline = reconnectDeadline, now >= deadline,
           [.connecting, .reconnecting, .syncing].contains(state.connection) {
            stopConnectionTasks()
            session.suspendConnection()
            reconnectTask?.cancel(); reconnectTask = nil
            state.connection = .failed
            reconnectDeadline = nil
            publish()
            return
        }
        if [.connecting, .reconnecting, .syncing].contains(state.connection), reconnectTask == nil,
           state.isForeground, now - startedAt >= 10 {
            fail(.timeout)
            return
        }
        guard hasWelcome, state.connection != .failed, state.connection != .reconnecting, !state.isTerminal else { return }
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
        guard !isClosed, hasWelcome, resyncTask == nil, pendingSyncID == nil,
              state.connection != .failed, state.connection != .reconnecting, !state.isTerminal else { return }
        let expected = generation
        let id = UUID().uuidString
        pendingSyncID = id
        pendingGameSyncID = id
        sessionSynced = false; gameSynced = false
        startedAt = clock.uptime()
        syncDeadline = clock.uptime() + 5
        state.isSynced = false
        state.connection = .syncing
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
        guard !isClosed else { return }
        stopConnectionTasks()
        session.suspendConnection()
        hasWelcome = false
        state.connection = state.isTerminal ? .idle : .failed
        state.isSynced = false
        state.controlGrant = nil
        state.pendingCommand = nil
        if state.session == nil { state.session = session.session }
        state.issue = state.isTerminal ? nil : issue
        if case .connection(.http(let status, _)) = issue, [404, 409].contains(status), state.session != nil {
            state.terminalConflict = true
        }
        if case .connection(.http(_, let retryAfter)) = issue, let retryAfter {
            state.retryNotBefore = clock.uptime() + retryAfter
        }
        if !state.isLeaving, !state.isTerminal, !state.controlTransferred, state.game?.phase != .finalizing,
           HouseRocketsReconnectPolicy.automaticallyRetries(issue) {
            scheduleReconnect()
        } else { publish() }
    }

    private func scheduleReconnect() {
        guard !isClosed, !state.isLeaving, !state.isTerminal, reconnectTask == nil else { return }
        state.connection = .reconnecting
        guard state.isForeground else { publish(); return }
        let now = clock.uptime()
        if reconnectDeadline == nil {
            let grace = state.game == nil ? reconnectPolicy.initialBudget
                : Double(state.runtimeSettings?.reconnectGraceMilliseconds ?? 10_000) / 1_000
            reconnectDeadline = now + max(0.5, min(20, grace))
        }
        let nextAttempt = state.reconnectAttempt + 1
        let minimum = max(0, (state.retryNotBefore ?? now) - now)
        let delay = reconnectPolicy.delay(attempt: nextAttempt, minimum: minimum)
        guard nextAttempt <= reconnectPolicy.maximumAttempts,
              now + delay < (reconnectDeadline ?? now) else {
            state.connection = .failed
            reconnectDeadline = nil
            publish()
            return
        }
        state.reconnectAttempt = nextAttempt
        let retryAt = now + delay
        state.retryNotBefore = retryAt
        let expected = generation
        let clock = self.clock
        reconnectTask = Task { [weak self] in
            do { try await clock.sleep(max(0, retryAt - clock.uptime())) } catch { return }
            guard !Task.isCancelled, let self, !self.isClosed, self.generation == expected,
                  self.state.isForeground, !self.state.isLeaving else { return }
            self.reconnectTask = nil
            if let deadline = self.reconnectDeadline, clock.uptime() >= deadline {
                self.tick()
                return
            }
            self.beginAttempt(isRetry: true)
        }
        publish()
    }

    private func stopConnectionTasks() {
        attemptID = UUID()
        stableSince = nil
        connectTask?.cancel(); connectTask = nil
        commandTask?.cancel(); commandTask = nil
        heartbeatTask?.cancel(); heartbeatTask = nil
        resyncTask?.cancel(); resyncTask = nil
        pendingPing = nil
        pendingSyncID = nil; pendingGameSyncID = nil
        syncDeadline = nil
    }

    private func stopTasks() {
        generation = UUID()
        stopConnectionTasks()
        eventTask?.cancel(); eventTask = nil
        snapshotTask?.cancel(); snapshotTask = nil
        timerTask?.cancel(); timerTask = nil
        reconnectTask?.cancel(); reconnectTask = nil
    }

    private func failure(from error: Error) -> GameRealtimeSessionFailure {
        if error as? GameRealtimeError == .accessRevoked { return .http(statusCode: 403, retryAfterSeconds: nil) }
        if let error = error as? NetworkHTTPFailure {
            return .http(statusCode: error.statusCode, retryAfterSeconds: error.retryAfterSeconds(at: clock.wallTime()))
        }
        if let error = error as? GameRealtimeError { return .protocolFailure(error) }
        if error is DecodingError { return .invalidPayload }
        return .transport
    }

    private func publish() {
        acceptanceRecorder?.consume(state)
        onStateChange?(state)
        continuation.yield(state)
    }
}
