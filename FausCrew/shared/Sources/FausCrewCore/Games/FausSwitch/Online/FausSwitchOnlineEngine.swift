import Foundation

/// Online Faus Switch for one match, in House Rockets' sans-IO effect model: the
/// platform host performs `effects` (HTTP, WebSocket, haptics), reports each outcome
/// with the same `connection`/`request` tag, calls `tick` about every 25 ms and asks
/// for one `presentation(at:)` per drawn frame. Time is the host's monotonic uptime.
///
/// Room: `PUT` → socket → welcome and session → join → color → ready. The server owns
/// the race: robot colors, flips (at the player's tick, inside its rewind window),
/// crashes, finish order and the persisted result.
public final class FausSwitchOnlineEngine {
    public let context: GameLaunchContext
    public private(set) var lobby = FausSwitchOnlineLobbyState()
    public private(set) var result = FausSwitchOnlineResultState()
    /// The color this player asked for; resent after a reconnect while still in the lobby.
    public private(set) var preferredColor: FausSwitchColor?
    /// The lobby's robot colors (`lobbyState`); the local color shown is
    /// `lobbyColors.localColor(preferred: preferredColor)`.
    public var lobbyColors: FausSwitchLobbyColors { lobby.lobbyColors(localPlayerID: context.localPlayerID) }
    /// True after `leave` finished or `disconnect`; the host leaves the screen.
    public var isClosed: Bool { lobbyMachine.isClosed && !finished }
    /// The session to exclude when the player asks for a rematch.
    public var rematchExcludedSessionID: String? { result.canRematch ? result.sessionID : nil }

    private var effects: [GameOnlineEffect] = []
    private var lobbyMachine: FausSwitchOnlineLobbyMachine!
    private var resultMachine: FausSwitchOnlineResultMachine!
    private var play: FausSwitchOnlinePlayMachine!
    private var sentColor: (session: String, color: FausSwitchColor, connection: UUID?)?
    private var finished = false
    private var now: TimeInterval = 0

    public init(context: GameLaunchContext, excludingSessionID: String? = nil, preferredColor: FausSwitchColor? = nil,
                policy: GameReconnectPolicy = .init(), configuration: FausSwitchPlayConfiguration = .init(),
                makeID: @escaping () -> String = { UUID().uuidString }) {
        self.context = context
        self.preferredColor = preferredColor
        let emit: (GameOnlineEffect) -> Void = { [weak self] in self?.effects.append($0) }
        lobbyMachine = FausSwitchOnlineLobbyMachine(context: context, excludingSessionID: excludingSessionID,
                                                    policy: policy, makeID: makeID, emit: emit)
        resultMachine = FausSwitchOnlineResultMachine(houseID: context.houseID ?? "", emit: emit)
        play = FausSwitchOnlinePlayMachine(
            localPlayerID: context.localPlayerID ?? "", configuration: configuration, makeID: makeID,
            send: { [weak self] message, grant in
                guard let self else { return false }
                return self.lobbyMachine.sendGameplay(message, grant: grant, now: self.now)
            },
            resync: { [weak self] in
                guard let self else { return }
                self.lobbyMachine.resyncGameplay(now: self.now)
            })
        play.onControlLost = { [weak self] in self?.lobbyMachine.controlLost() }
        play.onLocalOutcome = { [weak self] status in
            self?.effects.append(.haptic(status == .finished ? .success : .warning))
        }
        lobbyMachine.onGameplayRejected = { [weak self] id, rejection in
            guard let self else { return }
            self.play.reject(messageID: id, rejection: rejection, now: self.now)
        }
        lobbyMachine.onStateChange = { [weak self] state in self?.lobbyChanged(state) }
        resultMachine.onStateChange = { [weak self] state in self?.resultChanged(state) }
    }

    /// Effects produced since the last call, in order.
    public func drainEffects() -> [GameOnlineEffect] {
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
        play.tick(at: now)
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
    public func setReduceMotion(_ enabled: Bool) { play.setReduceMotion(enabled) }

    /// The tap. Flips only with valid control and only from a surface, like demo.
    @discardableResult
    public func flip(now: TimeInterval) -> FausSwitchFlipFeedback {
        self.now = now
        return play.flip(now: now)
    }

    /// Asks for a robot color; sent now if the player sits in the lobby, otherwise as
    /// soon as they do. A ready player's color is locked: the pick is ignored.
    public func selectColor(_ color: FausSwitchColor, now: TimeInterval) {
        self.now = now
        guard !lobbyColors.isLocked else { return }
        preferredColor = color
        sendColorIfNeeded()
    }

    /// Cleanup only (screen closed); explicit business leave is `leave(now:)`.
    public func disconnect() {
        resultMachine.disconnect()
        play.disconnect()
        lobbyMachine.disconnect()
    }

    /// Nil before the first match snapshot.
    public func presentation(at now: TimeInterval) -> FausSwitchOnlinePresentation? {
        guard var presentation = play.render(at: now) else { return nil }
        if presentation.frame.phase == .countdown {
            presentation.frame.countdown = roomCountdown(at: now).map { max(1, $0) }
        }
        return presentation
    }

    public func canCancel() -> Bool { lobby.canCancel(context: context) }

    /// Seconds left on the room's current deadline: the ready window, then the match countdown.
    public func roomCountdown(at uptime: TimeInterval) -> Int? {
        if let game = lobby.game {
            return game.phase == .countdown ? lobby.remainingSeconds(until: game.countdownEndsAt, uptime: uptime) : nil
        }
        switch lobby.session?.state {
        case .countdown: return lobby.remainingSeconds(until: lobby.session?.countdownEndsAt, uptime: uptime)
        case .readyWindow: return lobby.remainingSeconds(until: lobby.session?.readyWindowEndsAt, uptime: uptime)
        default: return nil
        }
    }

    private func lobbyChanged(_ state: FausSwitchOnlineLobbyState) {
        do { try play.consume(state, now: now) }
        catch { lobbyMachine.invalidateGameplay(now: now); return }
        lobby = state
        resultMachine.consume(state, now: now)
        sendColorIfNeeded()
    }

    private func sendColorIfNeeded() {
        guard let color = preferredColor, let sessionID = lobby.session?.sessionId,
              lobby.connection == .connected, lobby.isSynced, lobby.isLobby,
              lobby.localPlayer(context.localPlayerID) != nil else { return }
        // Already ours, or held by another player (the claim would change nothing; it is
        // sent once the holder leaves and the color is free again).
        // A ready player keeps their color, even when the one they asked for frees up.
        let colors = lobbyColors
        if colors.isLocked || colors.localClaim == color || colors.isTakenByOthers(color) { return }
        if let sent = sentColor, sent.session == sessionID, sent.color == color,
           sent.connection == lobby.connectionGeneration { return }
        if lobbyMachine.sendLobbyIntent(.selectColor(color), now: now) {
            sentColor = (sessionID, color, lobby.connectionGeneration)
        }
    }

    private func resultChanged(_ state: FausSwitchOnlineResultState) {
        let hadResult = result.result != nil
        let couldRematch = result.canRematch
        result = state
        if state.canRematch, !couldRematch {
            finished = true
            play.disconnect()
            lobbyMachine.finish()
        }
        if !hadResult, let final = state.result, final.status == .completed {
            effects.append(.haptic(final.winnerId == context.localPlayerID ? .success : .warning))
        }
    }
}

/// HTTP/wire decoding shared by the engine and its hosts.
public enum FausSwitchOnlineWire {
    public static func session(from response: HTTPResponse, houseID: String) throws -> GameSessionDTO {
        try GameOnlineWire.session(from: response, houseID: houseID, gameKey: GameKey.fausSwitch)
    }

    public static func result(from response: HTTPResponse, sessionID: String, houseID: String) throws -> FausSwitchResultDTO {
        try GameOnlineWire.result(from: response, sessionID: sessionID, houseID: houseID, as: FausSwitchRealtime.self)
    }
}
