import Foundation

/// Online Faus Rockets for one match, shared by iOS and Android. It is sans-IO:
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
    /// The rocket color this player asked for; resent after a reconnect while still in the lobby.
    public var preferredColor: HouseRocketsColor? { colorClaim.preferred }
    /// The lobby's rocket colors (`lobbyState`); the local color shown is
    /// `lobbyColors.localColor(preferred: preferredColor)`.
    public var lobbyColors: HouseRocketsLobbyColors { lobby.lobbyColors(localPlayerID: context.localPlayerID) }

    private var effects: [HouseRocketsOnlineEffect] = []
    private var lobbyMachine: HouseRocketsOnlineLobbyMachine!
    private var flight: HouseRocketsOnlineFlightMachine!
    private var resultMachine: HouseRocketsOnlineResultMachine!
    private var colorClaim: GameLobbyColorClaim<HouseRocketsColor>
    private var finished = false
    /// Play Again: ready as soon as the player sits in the new room.
    private var readiesOnJoin = false
    private var now: TimeInterval = 0

    public init(context: HouseRocketsLaunchContext, excludingSessionID: String? = nil,
                preferredColor: HouseRocketsColor? = nil,
                policy: HouseRocketsReconnectPolicy = .init(),
                configuration: HouseRocketsFlightConfiguration = .init(),
                makeID: @escaping () -> String = { UUID().uuidString }) {
        self.context = context
        colorClaim = GameLobbyColorClaim(preferred: preferredColor)
        let emit: (HouseRocketsOnlineEffect) -> Void = { [weak self] in self?.effects.append($0) }
        lobbyMachine = HouseRocketsOnlineLobbyMachine(context: context, excludingSessionID: excludingSessionID,
                                                      policy: policy, makeID: makeID, emit: emit)
        resultMachine = HouseRocketsOnlineResultMachine(houseID: context.houseID ?? "", emit: emit)
        flight = HouseRocketsOnlineFlightMachine(
            localPlayerID: context.localPlayerID ?? "", configuration: configuration, makeID: makeID,
            send: { [weak self] message, grant in
                guard let self else { return false }
                return self.lobbyMachine.sendGameplay(message, grant: grant, now: self.now)
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

    /// The ready button works: the lobby takes the change and, to get ready, the server holds
    /// the local player's color (picked first; never ready without one).
    public var canChangeReady: Bool {
        lobby.canChangeReady(playerID: context.localPlayerID) && lobbyColors.allowsReady
    }

    /// Getting ready waits for the color claim; taking ready back always goes out.
    public func setReady(_ ready: Bool, now: TimeInterval) {
        self.now = now
        if ready, !lobbyColors.allowsReady { return }
        lobbyMachine.setReady(ready, now: now)
    }
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

    /// Asks for a rocket color; sent now if the player sits in the lobby, otherwise as soon
    /// as they do. A ready player's color is locked: the pick is ignored. A server without
    /// lobby colors rejects the claim and the flight keeps the seat colors.
    public func selectColor(_ color: HouseRocketsColor, now: TimeInterval) {
        self.now = now
        guard colorClaim.select(color, colors: lobbyColors) else { return }
        sendColorIfNeeded()
    }

    /// Play Again from the result: the player is made ready once they sit in the new room
    /// (after the join and with the color asked for first), so the flight starts as soon as
    /// the crew is ready without another tap. Taking ready back afterwards is the player's.
    public func readyOnJoin(now: TimeInterval) {
        self.now = now
        readiesOnJoin = true
        readyIfAsked()
    }

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
        sendColorIfNeeded()
        readyIfAsked()
    }

    private func readyIfAsked() {
        guard readiesOnJoin, lobby.isLobby, let player = lobby.localPlayer(context.localPlayerID),
              canChangeReady else { return }
        readiesOnJoin = false
        if player.state != .ready { lobbyMachine.setReady(true, now: now) }
    }

    /// A ready player keeps their color, even when the one they asked for frees up.
    private func sendColorIfNeeded() {
        colorClaim.update(lobby: lobby, localPlayerID: context.localPlayerID, colors: lobbyColors) { color in
            lobbyMachine.sendLobbyIntent(.selectColor(color), now: now)
        }
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
