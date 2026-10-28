import Foundation

/// Lobby commands, authoritative sync, reconnect and application heartbeat of one
/// realtime game, without tasks: the host feeds results and a periodic `tick`, and
/// sends complete as soon as the host has written them.
final class GameOnlineLobbyMachine<Game: GameRealtimeGame> {
    typealias State = GameOnlineLobbyState<Game>
    typealias ClientMessage = GameRealtimeClientMessageOf<Game>
    typealias ClientAction = GameRealtimeClientActionOf<Game>

    var onStateChange: ((State) -> Void)?
    var onGameplayRejected: ((String?, GameRealtimeRejection) -> Void)?
    private(set) var state = State()
    private(set) var isClosed = false
    private let context: GameLaunchContext
    private let excludingSessionID: String?
    private let policy: GameReconnectPolicy
    private let makeID: () -> String
    private let emit: (GameOnlineEffect) -> Void

    private var connection = 0
    private var connectInFlight = false
    private var socketActive = false
    private var pinned: GameSessionDTO?
    private var reconnectDeadline: TimeInterval?
    private var reconnectAt: TimeInterval?
    private var sessionSynced = false
    private var gameSynced = false
    private var pendingGameSyncID: String?
    private var stableSince: TimeInterval?
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
    /// The latest ping → pong round trip, for debug diagnostics.
    private(set) var lastRTT: TimeInterval?
    /// Game snapshots that arrived older than (or equal to) the one held and were dropped.
    private(set) var lateSnapshots = 0
    private var pendingSyncID: String?
    private var syncDeadline: TimeInterval?
    private var lastPongAt: TimeInterval = 0
    private var now: TimeInterval = 0

    init(context: GameLaunchContext, excludingSessionID: String?, policy: GameReconnectPolicy,
         makeID: @escaping () -> String, emit: @escaping (GameOnlineEffect) -> Void) {
        self.context = context
        self.excludingSessionID = excludingSessionID
        self.policy = policy
        self.makeID = makeID
        self.emit = emit
    }

    var isLeaving: Bool { state.isLeaving }

    func start(isForeground: Bool, isLandscape: Bool, now: TimeInterval) {
        self.now = now
        guard !isClosed, state.connection == .idle else { return }
        state.isForeground = isForeground
        state.isLandscape = isLandscape
        withdrawReady = !isForeground || !isLandscape
        state.connection = .connecting
        startedAt = now
        publish()
        beginAttempt(isRetry: false)
    }

    // MARK: Host results

    func sessionResponse(_ response: HTTPResponse, retryAfter: TimeInterval?, connection tag: Int, now: TimeInterval) {
        self.now = now
        guard !isClosed, tag == connection, connectInFlight else { return }
        let session: GameSessionDTO
        do {
            session = try GameOnlineWire.session(from: response, houseID: context.houseID ?? "", gameKey: Game.gameKey)
            guard session.state != .finished, session.state != .cancelled,
                  session.sessionId != excludingSessionID else { throw GameRealtimeError.unexpectedSession }
        } catch {
            failConnect(GameOnlineWire.failure(from: error, retryAfter: retryAfter))
            return
        }
        pinned = session // Pin the ID even if the upgrade fails.
        socketActive = true
        emit(.openSocket(sessionID: session.sessionId, connection: connection))
    }

    func socketOpened(connection tag: Int, now: TimeInterval) {
        self.now = now
        guard !isClosed, tag == connection, connectInFlight else { return }
        connectInFlight = false
        if state.session == nil { state.session = pinned }
        publish()
    }

    /// Ensure transport errors, upgrade failures, receive errors and server closes.
    func connectionFailed(_ failure: GameRealtimeSessionFailure, connection tag: Int, now: TimeInterval) {
        self.now = now
        guard !isClosed, tag == connection else { return }
        failConnect(failure)
    }

    func received(text: String, connection tag: Int, now: TimeInterval) {
        self.now = now
        guard !isClosed, tag == connection, socketActive else { return }
        let message: GameRealtimeServerMessageOf<Game>
        do {
            guard text.utf8.count <= gameOnlineMaximumIncomingBytes else { throw GameRealtimeError.messageTooLarge }
            message = try GameRealtimeCodec.decode(Data(text.utf8), as: Game.self)
            try validateSession(message)
        } catch {
            failConnect(GameOnlineWire.failure(from: error, retryAfter: nil))
            return
        }
        receive(GameRealtimeReceivedMessageOf(message: message, receivedAt: Date(), receivedUptime: now,
                                            generation: UUID()))
    }

    func sendFailed(_ failure: GameRealtimeSessionFailure, connection tag: Int, now: TimeInterval) {
        self.now = now
        guard !isClosed, tag == connection else { return }
        fail(.connection(failure))
    }

    // MARK: User intents

    func retry(now: TimeInterval) {
        self.now = now
        guard !isClosed, !state.isLeaving, state.isForeground, state.canReconnect(at: now) else { return }
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
    func reclaimControl(now: TimeInterval) {
        self.now = now
        guard !isClosed, state.controlTransferred, state.isForeground,
              state.connection == .connected, !state.isTerminal else { return }
        state.controlTransferred = false
        requestSync()
        publish()
    }

    func setLandscape(_ landscape: Bool, now: TimeInterval) {
        self.now = now
        guard !isClosed else { return }
        state.isLandscape = landscape
        if !landscape { withdrawReady = true }
        reconcile()
        publish()
    }

    func setForeground(_ active: Bool, now: TimeInterval) {
        self.now = now
        guard !isClosed, state.isForeground != active else { return }
        state.isForeground = active
        if !active {
            withdrawReady = true
            state.controlGrant = nil
            pendingPing = nil
            reconnectAt = nil
        } else if !hasWelcome, state.connection == .connecting, !connectInFlight {
            beginAttempt(isRetry: false)
        } else if state.connection == .reconnecting || state.connection == .failed {
            if !state.isTerminal, !state.controlTransferred,
               GameReconnectPolicy.automaticallyRetries(state.issue ?? .timeout) {
                reconnectDeadline = nil
                state.reconnectAttempt = 0
                scheduleReconnect()
            }
        } else if hasWelcome, !state.isTerminal, !state.controlTransferred {
            // Resume requires fresh authoritative sync before ready can be enabled.
            state.isSynced = false
            state.controlGrant = nil
            pendingPing = nil
            nextPingAt = now
            lastPongAt = now
            requestSync()
        }
        reconcile()
        publish()
    }

    func setReady(_ ready: Bool, now: TimeInterval) {
        self.now = now
        guard state.canChangeReady(playerID: context.localPlayerID),
              !ready || state.isLandscape || !Game.readyRequiresLandscape else { return }
        guard (state.localPlayer(context.localPlayerID)?.state == .ready) != ready else { return }
        withdrawReady = false
        sendLifecycle(.setReady(ready))
    }

    func cancelMatch(now: TimeInterval) {
        self.now = now
        guard !isClosed, state.canCancel(context: context) else { return }
        sendLifecycle(.cancel)
    }

    /// Explicit user exit: a business `leave` when connected, then cleanup. The engine
    /// reports `isClosed` once the leave is confirmed or after two seconds.
    func leave(now: TimeInterval) {
        self.now = now
        guard !isClosed, !state.isLeaving else { return }
        exitDeadline = now + 2
        state.isLeaving = true
        publish()
        if hasWelcome, [.connected, .syncing].contains(state.connection), !state.isTerminal {
            state.pendingCommand = nil
            sendLifecycle(.leave)
        }
        finishLeaveIfDone()
    }

    /// Close a committed match while retaining its final roster and geometry.
    func finish() {
        guard !isClosed else { return }
        isClosed = true
        closeConnection()
        state.connection = .idle
        state.isSynced = false
        state.controlGrant = nil
        state.pendingCommand = nil
        publish()
        onStateChange = nil
        onGameplayRejected = nil
    }

    func disconnect() {
        guard !isClosed else { return }
        isClosed = true
        closeConnection()
        state = State()
        publish()
        onStateChange = nil
        onGameplayRejected = nil
    }

    // MARK: Gameplay hooks

    /// The gameplay gate: returns false when the grant is stale or the intent is
    /// bound to another control generation.
    func sendGameplay(_ message: ClientMessage, grant: GameRealtimeControlGrantDTO, now: TimeInterval) -> Bool {
        self.now = now
        guard !isClosed, state.validControl(playerID: context.localPlayerID) == grant,
              case .gameplay(let intent) = message.action,
              Game.controlGeneration(of: intent) == grant.controlGeneration else { return false }
        return send(message)
    }

    func resyncGameplay(now: TimeInterval) {
        self.now = now
        guard !isClosed, !state.controlTransferred, state.connection == .connected,
              pendingSyncID == nil, !state.isTerminal else { return }
        state.controlGrant = nil
        requestSync()
        publish()
    }

    func invalidateGameplay(now: TimeInterval) {
        self.now = now
        // Do not republish invalid terminal geometry into the same presentation sink.
        state.game = nil
        state.gameReceivedUptime = nil
        fail(.connection(.invalidPayload))
    }

    // MARK: Timer

    func tick(now: TimeInterval) {
        self.now = now
        guard !isClosed else { return }
        if let at = reconnectAt, now >= at {
            reconnectAt = nil
            if state.isForeground, !state.isLeaving, !(reconnectDeadline.map { now >= $0 } ?? false) {
                beginAttempt(isRetry: true)
                return
            }
        }
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
            stopConnectionWork()
            suspendConnection()
            reconnectAt = nil
            state.connection = .failed
            reconnectDeadline = nil
            publish()
            return
        }
        if [.connecting, .reconnecting, .syncing].contains(state.connection), reconnectAt == nil,
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
            if now >= nextPingAt, pendingPing == nil { sendHeartbeat() }
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

    // MARK: Connection attempts

    private func beginAttempt(isRetry: Bool) {
        guard !isClosed, !state.isLeaving, !state.isTerminal, state.isForeground else { return }
        stopConnectionWork()
        hasWelcome = false
        sessionSynced = false; gameSynced = false
        joinAttempted = false
        state.isSynced = false
        state.controlGrant = nil
        state.connectionGeneration = UUID()
        state.connection = isRetry ? .reconnecting : .connecting
        startedAt = now
        state.serverClock = nil
        bestRTT = .infinity
        publish()
        connectInFlight = true
        if let pinned {
            // Reopen the same match with the current token; never PUT or implicitly join.
            suspendConnection()
            socketActive = true
            emit(.openSocket(sessionID: pinned.sessionId, connection: connection))
        } else {
            suspendConnection()
            guard let houseID = context.houseID, let playerID = context.localPlayerID,
                  (try? GameWireContract.validateIdentifier(houseID)) != nil,
                  (try? GameWireContract.validateIdentifier(playerID)) != nil else {
                failConnect(.protocolFailure(.invalidContext))
                return
            }
            emit(.ensureSession(houseID: houseID, connection: connection))
        }
    }

    private func failConnect(_ failure: GameRealtimeSessionFailure) {
        connectInFlight = false
        fail(.connection(failure))
    }

    private func validateSession(_ message: GameRealtimeServerMessageOf<Game>) throws {
        guard let expected = pinned?.sessionId else { throw GameRealtimeError.unexpectedSession }
        let sessionID: String?
        switch message.payload {
        case .welcome(let value): sessionID = value.sessionId
        case .session(let value):
            guard value.houseId == context.houseID else { throw GameRealtimeError.unexpectedSession }
            sessionID = value.sessionId
        case .controlGranted(let value):
            guard value.playerId == context.localPlayerID else { throw GameRealtimeError.invalidContext }
            sessionID = value.sessionId
        case .snapshot(let value): sessionID = value.sessionId
        case .result(let value):
            guard value.houseId == context.houseID else { throw GameRealtimeError.unexpectedSession }
            sessionID = value.sessionId
        case .accepted, .pong, .rejected: sessionID = nil
        }
        if let sessionID, sessionID != expected { throw GameRealtimeError.unexpectedSession }
    }

    // MARK: Messages

    private func receive(_ received: GameRealtimeReceivedMessageOf<Game>) {
        let message = received.message
        if state.serverClock == nil {
            state.serverClock = .init(serverTime: message.sentAt, localUptime: received.receivedUptime)
        }
        switch message.payload {
        case .welcome(let welcome):
            guard !hasWelcome else { return }
            // Settings are frozen per session and may change without a deploy.
            guard welcome.settings.isUsable else {
                fail(.connection(.protocolFailure(.invalidResponse)))
                return
            }
            hasWelcome = true
            state.runtimeSettings = welcome.settings
            heartbeatInterval = welcome.settings.heartbeatInterval
            heartbeatTimeout = welcome.settings.heartbeatTimeout
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
                    if GameReconnectPolicy.automaticallyRetries(.rejected(rejection)) {
                        fail(.rejected(rejection))
                    } else {
                        fail(.connection(.invalidPayload))
                    }
                    return
                }
                if let ping = pendingPing, message.messageId == ping.id,
                   rejection.code == Game.staleControlCode { controlLost() }
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
            lastRTT = rtt
            if rtt <= bestRTT {
                bestRTT = rtt
                state.serverClock = .init(serverTime: pong.serverTime, localUptime: ping.uptime + rtt / 2)
            }
            pendingPing = nil
            lastPongAt = received.receivedUptime
        case .snapshot(let snapshot):
            guard state.result == nil else { return }
            let correlated = pendingGameSyncID != nil && pendingGameSyncID == message.messageId
            if let current = state.game {
                // A newer periodic frame can reach us before this critical sync reply.
                // Keep its geometry while retaining nonce proof.
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
                      (snapshot.stateSequence == current.stateSequence && (correlated || !gameSynced)))) else {
                    lateSnapshots += 1
                    return
                }
                guard Game.isValidSuccessor(snapshot, of: current) else {
                    fail(.connection(.invalidPayload))
                    return
                }
                if snapshot.runtimeEpoch == current.runtimeEpoch, !state.controlTransferred,
                   state.connection == .connected, pendingSyncID == nil,
                   let grant = state.controlGrant, grant.runtimeEpoch == snapshot.runtimeEpoch,
                   let localID = context.localPlayerID,
                   let local = snapshot.controlSeat(of: localID), local.canHoldControl,
                   current.controlSeat(of: localID)?.controlGeneration == grant.controlGeneration,
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
        finishLeaveIfDone()
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
        if state.connection != .connected { stableSince = now }
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

    private func sendLifecycle(_ action: ClientAction) {
        guard state.pendingCommand == nil,
              state.connection == .connected || (action == .leave && state.connection == .syncing),
              let version = state.session?.version else { return }
        state.issue = nil
        state.pendingCommand = .init(message: .init(messageId: makeID(), action: action),
            sessionVersion: version, issuedAt: now, lastSentAt: now)
        sendPending()
        publish()
    }

    private func sendPending() {
        guard var pending = state.pendingCommand else { return }
        pending.attempts += 1
        pending.lastSentAt = now
        state.pendingCommand = pending
        _ = send(pending.message)
    }

    private func sendHeartbeat() {
        let id = makeID()
        pendingPing = (id, now)
        nextPingAt = now + heartbeatInterval
        _ = send(.init(messageId: id, action: .ping(id: id)))
    }

    private func requestSync() {
        guard !isClosed, hasWelcome, pendingSyncID == nil,
              state.connection != .failed, state.connection != .reconnecting, !state.isTerminal else { return }
        let id = makeID()
        pendingSyncID = id
        pendingGameSyncID = id
        sessionSynced = false; gameSynced = false
        startedAt = now
        syncDeadline = now + 5
        state.isSynced = false
        state.connection = .syncing
        _ = send(.init(messageId: id, action: .resync))
    }

    @discardableResult
    private func send(_ message: ClientMessage) -> Bool {
        guard socketActive else {
            fail(.connection(.protocolFailure(.notConnected)))
            return false
        }
        do {
            let data = try GameRealtimeCodec.encode(message)
            emit(.send(text: String(decoding: data, as: UTF8.self), connection: connection))
            return true
        } catch {
            fail(.connection(GameOnlineWire.failure(from: error, retryAfter: nil)))
            return false
        }
    }

    private func fail(_ issue: GameOnlineLobbyIssue) {
        guard !isClosed else { return }
        stopConnectionWork()
        suspendConnection()
        hasWelcome = false
        state.connection = state.isTerminal ? .idle : .failed
        state.isSynced = false
        state.controlGrant = nil
        state.pendingCommand = nil
        if state.session == nil { state.session = pinned }
        state.issue = state.isTerminal ? nil : issue
        if case .connection(.http(let status, _)) = issue, [404, 409].contains(status), state.session != nil {
            state.terminalConflict = true
        }
        if case .connection(.http(_, let retryAfter)) = issue, let retryAfter {
            state.retryNotBefore = now + retryAfter
        }
        if !state.isLeaving, !state.isTerminal, !state.controlTransferred, state.game?.phase != .finalizing,
           GameReconnectPolicy.automaticallyRetries(issue) {
            scheduleReconnect()
        } else { publish() }
        finishLeaveIfDone()
    }

    private func scheduleReconnect() {
        guard !isClosed, !state.isLeaving, !state.isTerminal, reconnectAt == nil else { return }
        state.connection = .reconnecting
        guard state.isForeground else { publish(); return }
        if reconnectDeadline == nil {
            let grace = state.game == nil ? policy.initialBudget
                : (state.runtimeSettings ?? Game.Settings.releaseDefaults).reconnectGrace
            reconnectDeadline = now + max(0.5, min(20, grace))
        }
        let nextAttempt = state.reconnectAttempt + 1
        let minimum = max(0, (state.retryNotBefore ?? now) - now)
        let delay = policy.delay(attempt: nextAttempt, minimum: minimum)
        guard nextAttempt <= policy.maximumAttempts, now + delay < (reconnectDeadline ?? now) else {
            state.connection = .failed
            reconnectDeadline = nil
            publish()
            return
        }
        state.reconnectAttempt = nextAttempt
        let retryAt = now + delay
        state.retryNotBefore = retryAt
        reconnectAt = retryAt
        publish()
    }

    private func finishLeaveIfDone() {
        guard !isClosed, state.isLeaving, state.pendingCommand == nil else { return }
        disconnect()
    }

    /// iOS `stopConnectionTasks`: new connection identity, cleared deadlines.
    private func stopConnectionWork() {
        connection += 1
        connectInFlight = false
        stableSince = nil
        pendingPing = nil
        pendingSyncID = nil; pendingGameSyncID = nil
        syncDeadline = nil
    }

    /// Temporary transport cleanup; the pinned match survives.
    private func suspendConnection() {
        if socketActive { emit(.closeSocket) }
        socketActive = false
    }

    private func closeConnection() {
        stopConnectionWork()
        reconnectAt = nil
        exitDeadline = nil
        suspendConnection()
    }

    private func publish() {
        onStateChange?(state)
    }
}

/// Largest server text frame an engine accepts.
let gameOnlineMaximumIncomingBytes = 1_048_576

/// HTTP/wire decoding shared by the engines and their hosts.
public enum GameOnlineWire {
    public static func session(from response: HTTPResponse, houseID: String, gameKey: String) throws -> GameSessionDTO {
        let session: GameSessionDTO = try value(from: response)
        try GameRealtimeCodec.validateSession(session, gameKey: gameKey)
        guard session.houseId == houseID, !session.sessionId.isEmpty else { throw GameRealtimeError.unexpectedSession }
        return session
    }

    public static func result<Game: GameRealtimeGame>(from response: HTTPResponse, sessionID: String, houseID: String,
                                                       as game: Game.Type) throws -> Game.Result {
        let result: Game.Result = try value(from: response)
        try Game.checkCompatibility(result)
        try result.validate(sessionID: sessionID, houseID: houseID)
        return result
    }

    /// Maps decoding, contract and HTTP errors to the lobby's failure vocabulary.
    public static func failure(from error: Error, retryAfter: TimeInterval?) -> GameRealtimeSessionFailure {
        if error as? GameRealtimeError == .accessRevoked { return .http(statusCode: 403, retryAfterSeconds: nil) }
        if let error = error as? GameHTTPError {
            if error.isGameUnavailable { return .protocolFailure(.gameUnavailable) }
            return .http(statusCode: error.statusCode, retryAfterSeconds: retryAfter)
        }
        if let error = error as? GameRealtimeError { return .protocolFailure(error) }
        if error is DecodingError { return .invalidPayload }
        return .transport
    }

    private static func value<Value: Decodable>(from response: HTTPResponse) throws -> Value {
        guard (200..<300).contains(response.statusCode) else {
            throw GameHTTPError(statusCode: response.statusCode, body: response.body)
        }
        let envelope = try GameRealtimeCodec.makeDecoder().decode(GameHTTPEnvelope<Value>.self, from: response.body)
        guard envelope.success, let value = envelope.data else { throw GameRealtimeError.invalidResponse }
        return value
    }
}
