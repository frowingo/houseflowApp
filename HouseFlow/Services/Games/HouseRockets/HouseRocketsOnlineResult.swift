import Foundation

/// One match, one immutable result. HTTP remains available after socket cleanup.
@MainActor
final class HouseRocketsOnlineResult {
    typealias Reader = @MainActor (String) async throws -> HouseRocketsResultDTO
    var onStateChange: ((HouseRocketsOnlineResultState) -> Void)?
    private(set) var state = HouseRocketsOnlineResultState()
    private let houseID: String
    private let read: Reader
    private let clock: GameRealtimeClock
    private var lookupTask: Task<Void, Never>?
    private var deadlineTask: Task<Void, Never>?
    private var generation = UUID()
    private var isClosed = false
    private var cancellationBeforeStart = false
    private var acceptedEventID: String?

    init(houseID: String, read: @escaping Reader, clock: GameRealtimeClock? = nil) {
        self.houseID = houseID
        self.read = read
        self.clock = clock ?? .live
    }

    deinit { lookupTask?.cancel(); deadlineTask?.cancel() }

    func consume(_ lobby: HouseRocketsOnlineLobbyState) {
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
        guard state.phase == .idle,
              lobby.isTerminal || lobby.game?.phase == .finalizing else { return }
        state.endReason = lobby.session?.endReason.flatMap(HouseRocketsEndReason.init(rawValue:))
        cancellationBeforeStart = lobby.session?.state == .cancelled && lobby.session?.startedAt == nil
            && (lobby.game == nil || lobby.game?.phase == .countdown || lobby.game?.elapsedSeconds == 0)
        lookup()
    }

    func retry() {
        guard !isClosed, state.canRetry(at: clock.uptime()) else { return }
        lookup()
    }

    func disconnect() {
        guard !isClosed else { return }
        isClosed = true
        cancelLookup()
        onStateChange = nil
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

    private func lookup() {
        guard lookupTask == nil, let sessionID = state.sessionID else { return }
        state.phase = .waiting
        state.failure = nil
        publish()
        let expected = generation
        let clock = self.clock
        let read = self.read
        // One request at a time, at most five attempts and a 20-second total budget.
        deadlineTask = Task { [weak self] in
            do { try await clock.sleep(20) } catch { return }
            guard let self, !Task.isCancelled, self.generation == expected else { return }
            self.fail(.transport)
        }
        lookupTask = Task { [weak self] in
            let delays: [TimeInterval] = [0.5, 1, 2, 4]
            for attempt in 0...delays.count {
                guard !Task.isCancelled, self?.generation == expected else { return }
                do {
                    let result = try await read(sessionID)
                    guard !Task.isCancelled, let self, !self.isClosed, self.generation == expected else { return }
                    self.accept(result)
                    return
                } catch {
                    guard !Task.isCancelled, let self, !self.isClosed, self.generation == expected else { return }
                    let failure: GameRealtimeSessionFailure
                    var retryable = false
                    var retryAfter: TimeInterval = 0
                    if let http = error as? NetworkHTTPFailure {
                        retryAfter = http.retryAfterSeconds(at: clock.wallTime()) ?? 0
                        failure = .http(statusCode: http.statusCode, retryAfterSeconds: retryAfter)
                        if http.statusCode == 404, self.cancellationBeforeStart {
                            self.cancelLookup()
                            self.state.phase = .cancelledWithoutRecord
                            self.state.failure = nil
                            self.publish()
                            return
                        }
                        retryable = [404, 429, 500, 502, 503, 504].contains(http.statusCode)
                    } else if let protocolError = error as? GameRealtimeError {
                        failure = .protocolFailure(protocolError)
                    } else if error is DecodingError {
                        failure = .invalidPayload
                    } else {
                        failure = .transport
                        retryable = true
                    }
                    self.state.retryNotBefore = clock.uptime() + retryAfter
                    guard retryable, attempt < delays.count, retryAfter < 20 else { self.fail(failure); return }
                    do { try await clock.sleep(max(delays[attempt], retryAfter)) } catch { return }
                }
            }
        }
    }

    private func fail(_ failure: GameRealtimeSessionFailure) {
        cancelLookup()
        state.phase = .failed
        state.failure = failure
        publish()
    }

    private func cancelLookup() {
        generation = UUID()
        lookupTask?.cancel(); lookupTask = nil
        deadlineTask?.cancel(); deadlineTask = nil
    }

    private func publish() { onStateChange?(state) }
}
