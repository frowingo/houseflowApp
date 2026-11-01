import Foundation

/// Persistence state, independent of the gameplay frame and socket lifetime.
public struct GameOnlineResultState<Game: GameRealtimeGame>: Equatable, Sendable {
    public enum Phase: Equatable, Sendable { case idle, waiting, available, cancelledWithoutRecord, failed }
    public var phase: Phase = .idle
    public var sessionID: String?
    public var result: Game.Result?
    public var identities: [String: Game.ResultIdentity] = [:]
    public var endReason: Game.Result.EndReason?
    public var failure: GameRealtimeSessionFailure?
    public var retryNotBefore: TimeInterval = 0
    public var terminalConfirmed = false

    public var isVisible: Bool { phase != .idle }
    public var canRematch: Bool { terminalConfirmed && (phase == .available || phase == .cancelledWithoutRecord) }
    public func canRetry(at uptime: TimeInterval) -> Bool {
        guard phase == .failed, uptime >= retryNotBefore else { return false }
        switch failure {
        case .http(let status, _): return ![401, 403].contains(status)
        case .invalidPayload, .protocolFailure: return false
        default: return true
        }
    }

    public init() {}
}

/// Waits between result lookups; four retries after the first request.
private let gameOnlineResultRetryDelays: [TimeInterval] = [0.5, 1, 2, 4]

/// One match, one immutable result. HTTP lookups are effects; retries and the
/// 20-second budget run on the engine tick.
final class GameOnlineResultMachine<Game: GameRealtimeGame> {
    var onStateChange: ((GameOnlineResultState<Game>) -> Void)?
    private(set) var state = GameOnlineResultState<Game>()
    private let houseID: String
    private let emit: (GameOnlineEffect) -> Void
    private var request = 0
    private var inFlight = false
    private var attempt = 0
    private var retryAt: TimeInterval?
    private var deadline: TimeInterval?
    private var isClosed = false
    private var cancellationBeforeStart = false
    private var acceptedEventID: String?

    init(houseID: String, emit: @escaping (GameOnlineEffect) -> Void) {
        self.houseID = houseID
        self.emit = emit
    }

    func consume(_ lobby: GameOnlineLobbyState<Game>, now: TimeInterval) {
        guard !isClosed, let id = lobby.session?.sessionId ?? lobby.game?.sessionId ?? lobby.result?.sessionId else { return }
        if let bound = state.sessionID, bound != id { return }
        state.sessionID = id
        if state.result == nil, let game = lobby.game {
            state.identities.merge(Game.identities(in: game)) { kept, _ in kept }
        }
        state.terminalConfirmed = state.terminalConfirmed || lobby.isTerminal
        if let result = lobby.result {
            accept(result, eventID: lobby.resultEventID)
            return
        }
        guard state.phase == .idle, lobby.isTerminal || lobby.game?.phase == .finalizing else { return }
        state.endReason = lobby.session?.endReason.flatMap(Game.Result.EndReason.init(rawValue:))
        cancellationBeforeStart = lobby.session?.state == .cancelled && lobby.session?.startedAt == nil
            && (lobby.game?.isBeforeStart ?? true)
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
            accept(try GameOnlineWire.result(from: response, sessionID: sessionID, houseID: houseID, as: Game.self))
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
            handleFailure(GameOnlineWire.failure(from: error, retryAfter: nil), retryable: false,
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

    private func accept(_ result: Game.Result, eventID: String? = nil) {
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
        guard retryable, attempt < gameOnlineResultRetryDelays.count, retryAfter < 20 else { fail(failure); return }
        retryAt = now + max(gameOnlineResultRetryDelays[attempt], retryAfter)
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
