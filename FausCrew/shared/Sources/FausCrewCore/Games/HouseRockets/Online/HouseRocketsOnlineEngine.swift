import Foundation

/// One match, one immutable result (`HouseRocketsOnlineResult` on iOS). HTTP lookups
/// are effects; retries and the 20-second budget run on the engine tick.
final class HouseRocketsOnlineResultMachine {
    var onStateChange: ((HouseRocketsOnlineResultState) -> Void)?
    private(set) var state = HouseRocketsOnlineResultState()
    private let houseID: String
    private let emit: (HouseRocketsOnlineEffect) -> Void
    private var request = 0
    private var inFlight = false
    private var attempt = 0
    private var retryAt: TimeInterval?
    private var deadline: TimeInterval?
    private var isClosed = false
    private var cancellationBeforeStart = false
    private var acceptedEventID: String?
    private static let delays: [TimeInterval] = [0.5, 1, 2, 4]

    init(houseID: String, emit: @escaping (HouseRocketsOnlineEffect) -> Void) {
        self.houseID = houseID
        self.emit = emit
    }

    func consume(_ lobby: HouseRocketsOnlineLobbyState, now: TimeInterval) {
        guard !isClosed, let id = lobby.session?.sessionId ?? lobby.game?.sessionId ?? lobby.result?.sessionId else { return }
        if let bound = state.sessionID, bound != id { return }
        state.sessionID = id
        if state.result == nil {
            for player in lobby.game?.players ?? [] where state.identities[player.playerId] == nil {
                state.identities[player.playerId] = .init(displayName: player.displayName, color: player.color)
            }
        }
        state.terminalConfirmed = state.terminalConfirmed || lobby.isTerminal
        if let result = lobby.result {
            accept(result, eventID: lobby.resultEventID)
            return
        }
        guard state.phase == .idle, lobby.isTerminal || lobby.game?.phase == .finalizing else { return }
        state.endReason = lobby.session?.endReason.flatMap(HouseRocketsEndReason.init(rawValue:))
        cancellationBeforeStart = lobby.session?.state == .cancelled && lobby.session?.startedAt == nil
            && (lobby.game == nil || lobby.game?.phase == .countdown || lobby.game?.elapsedSeconds == 0)
        lookup(now: now)
    }

    func retry(now: TimeInterval) {
        guard !isClosed, state.canRetry(at: now) else { return }
        lookup(now: now)
    }

    func disconnect() {
        guard !isClosed else { return }
        isClosed = true
        cancelLookup()
        onStateChange = nil
    }

    func response(_ response: HTTPResponse, retryAfter: TimeInterval?, request tag: Int, now: TimeInterval) {
        guard !isClosed, tag == request, inFlight, let sessionID = state.sessionID else { return }
        inFlight = false
        do {
            accept(try HouseRocketsOnlineWire.result(from: response, sessionID: sessionID, houseID: houseID))
        } catch let error as GameHTTPError {
            if error.statusCode == 404, cancellationBeforeStart {
                cancelLookup()
                state.phase = .cancelledWithoutRecord
                state.failure = nil
                publish()
                return
            }
            handleFailure(.http(statusCode: error.statusCode, retryAfterSeconds: retryAfter ?? 0),
                          retryable: [404, 429, 500, 502, 503, 504].contains(error.statusCode),
                          retryAfter: retryAfter ?? 0, now: now)
        } catch {
            handleFailure(HouseRocketsOnlineWire.failure(from: error, retryAfter: nil), retryable: false,
                          retryAfter: 0, now: now)
        }
    }

    /// A transport failure (no HTTP response) is always retryable.
    func failed(request tag: Int, now: TimeInterval) {
        guard !isClosed, tag == request, inFlight else { return }
        inFlight = false
        handleFailure(.transport, retryable: true, retryAfter: 0, now: now)
    }

    func tick(now: TimeInterval) {
        guard !isClosed else { return }
        if let deadline, now >= deadline {
            fail(.transport)
            return
        }
        if let at = retryAt, now >= at {
            retryAt = nil
            send()
        }
    }

    private func accept(_ result: HouseRocketsResultDTO, eventID: String? = nil) {
        guard !isClosed, state.result == nil, let sessionID = state.sessionID else { return }
        // Session identity deduplicates HTTP and events; the first event identity is retained.
        if let eventID, eventID == acceptedEventID { return }
        do { try result.validate(sessionID: sessionID, houseID: houseID) }
        catch { fail(.invalidPayload); return }
        acceptedEventID = eventID
        cancelLookup()
        state.result = result
        state.endReason = result.endReason
        state.terminalConfirmed = true
        state.phase = .available
        state.failure = nil
        publish()
    }

    private func lookup(now: TimeInterval) {
        guard !inFlight, retryAt == nil, state.sessionID != nil else { return }
        state.phase = .waiting
        state.failure = nil
        publish()
        // One request at a time, at most five attempts and a 20-second total budget.
        attempt = 0
        deadline = now + 20
        send()
    }

    private func send() {
        guard let sessionID = state.sessionID else { return }
        request += 1
        inFlight = true
        emit(.fetchResult(sessionID: sessionID, request: request))
    }

    private func handleFailure(_ failure: GameRealtimeSessionFailure, retryable: Bool,
                               retryAfter: TimeInterval, now: TimeInterval) {
        state.retryNotBefore = now + retryAfter
        guard retryable, attempt < Self.delays.count, retryAfter < 20 else { fail(failure); return }
        retryAt = now + max(Self.delays[attempt], retryAfter)
        attempt += 1
    }

    private func fail(_ failure: GameRealtimeSessionFailure) {
        cancelLookup()
        state.phase = .failed
        state.failure = failure
        publish()
    }

    private func cancelLookup() {
        request += 1
        inFlight = false
        retryAt = nil
        deadline = nil
    }

    private func publish() { onStateChange?(state) }
}

/// Online House Rockets for one match, shared by iOS and Android. It is sans-IO:
/// the platform host performs the `effects` (HTTP, WebSocket, haptics), reports
/// each outcome with the same `connection`/`request` tag, calls `tick` about every
/// 25 ms and samples `presentation(at:)` once per rendered frame. Time is always the
/// host's monotonic uptime in seconds.
public final class HouseRocketsOnlineEngine {
    public let context: HouseRocketsLaunchContext
    public private(set) var lobby = HouseRocketsOnlineLobbyState()
    public private(set) var result = HouseRocketsOnlineResultState()
    /// True after `leave` finished or `disconnect`; the host leaves the screen.
    public var isClosed: Bool { lobbyMachine.isClosed && !finished }
    /// The session to exclude when the player asks for a rematch.
    public var rematchExcludedSessionID: String? { result.canRematch ? result.sessionID : nil }

    private var effects: [HouseRocketsOnlineEffect] = []
    private var lobbyMachine: HouseRocketsOnlineLobbyMachine!
    private var flight: HouseRocketsOnlineFlightMachine!
    private var resultMachine: HouseRocketsOnlineResultMachine!
    private var finished = false
    private var now: TimeInterval = 0

    public init(context: HouseRocketsLaunchContext, excludingSessionID: String? = nil,
                policy: HouseRocketsReconnectPolicy = .init(),
                configuration: HouseRocketsFlightConfiguration = .init(),
                makeID: @escaping () -> String = { UUID().uuidString }) {
        self.context = context
        let emit: (HouseRocketsOnlineEffect) -> Void = { [weak self] in self?.effects.append($0) }
        lobbyMachine = HouseRocketsOnlineLobbyMachine(context: context, excludingSessionID: excludingSessionID,
                                                      policy: policy, makeID: makeID, emit: emit)
        resultMachine = HouseRocketsOnlineResultMachine(houseID: context.houseID ?? "", emit: emit)
        flight = HouseRocketsOnlineFlightMachine(
            localPlayerID: context.localPlayerID ?? "", configuration: configuration, makeID: makeID,
            send: { [weak self] message, grant in
                guard let self else { return false }
                return self.lobbyMachine.sendSteering(message, grant: grant, now: self.now)
            },
            resync: { [weak self] in
                guard let self else { return }
                self.lobbyMachine.resyncGameplay(now: self.now)
            })
        flight.onControlLost = { [weak self] in self?.lobbyMachine.controlLost() }
        flight.onEliminations = { [weak self] eliminated in
            guard let self, eliminated.contains(where: { $0.playerID == self.context.localPlayerID }) else { return }
            self.effects.append(.haptic(.warning))
        }
        lobbyMachine.onGameplayRejected = { [weak self] id, rejection in
            guard let self else { return }
            self.flight.reject(messageID: id, rejection: rejection, now: self.now)
        }
        lobbyMachine.onStateChange = { [weak self] state in self?.lobbyChanged(state) }
        resultMachine.onStateChange = { [weak self] state in self?.resultChanged(state) }
    }

    /// Effects produced since the last call, in order.
    public func drainEffects() -> [HouseRocketsOnlineEffect] {
        defer { effects.removeAll() }
        return effects
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
        lobbyMachine.received(text: text, connection: connection, now: now)
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
        self.now = now
        lobbyMachine.tick(now: now)
        flight.tick(at: now)
        resultMachine.tick(now: now)
    }

    public func setReady(_ ready: Bool, now: TimeInterval) { self.now = now; lobbyMachine.setReady(ready, now: now) }
    public func setLandscape(_ landscape: Bool, now: TimeInterval) { self.now = now; lobbyMachine.setLandscape(landscape, now: now) }
    public func setForeground(_ active: Bool, now: TimeInterval) { self.now = now; lobbyMachine.setForeground(active, now: now) }
    public func retry(now: TimeInterval) { self.now = now; lobbyMachine.retry(now: now) }
    public func retryResult(now: TimeInterval) { self.now = now; resultMachine.retry(now: now) }
    public func cancelMatch(now: TimeInterval) { self.now = now; lobbyMachine.cancelMatch(now: now) }
    public func reclaimControl(now: TimeInterval) { self.now = now; lobbyMachine.reclaimControl(now: now) }
    public func leave(now: TimeInterval) { self.now = now; lobbyMachine.leave(now: now) }
    public func steer(screenHeading: Double, now: TimeInterval) { self.now = now; flight.steer(screenHeading: screenHeading, now: now) }
    public func endSteering() { flight.endSteering() }
    public func adjustHeading(by amount: Double, now: TimeInterval) { self.now = now; flight.adjustHeading(by: amount, now: now) }
    public func setReduceMotion(_ enabled: Bool) { flight.setReduceMotion(enabled) }

    /// Cleanup only (screen closed); explicit business leave is `leave(now:)`.
    public func disconnect() {
        resultMachine.disconnect()
        flight.disconnect()
        lobbyMachine.disconnect()
    }

    public func presentation(at now: TimeInterval) -> HouseRocketsOnlinePresentation? {
        flight.render(at: now)
    }

    public func canCancel() -> Bool { lobby.canCancel(context: context) }

    private func lobbyChanged(_ state: HouseRocketsOnlineLobbyState) {
        do { try flight.consume(state, now: now) }
        catch { lobbyMachine.invalidateGameplay(now: now); return }
        lobby = state
        resultMachine.consume(state, now: now)
    }

    private func resultChanged(_ state: HouseRocketsOnlineResultState) {
        let hadResult = result.result != nil
        let couldRematch = result.canRematch
        result = state
        if state.canRematch, !couldRematch {
            finished = true
            flight.disconnect()
            lobbyMachine.finish()
        }
        if !hadResult, let final = state.result, final.status == .completed {
            effects.append(.haptic(final.winnerId == context.localPlayerID ? .success : .warning))
        }
    }
}
