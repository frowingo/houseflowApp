import Foundation
import XCTest
@testable import HouseFlow

@MainActor
final class HouseRocketsOnlineResultTests: XCTestCase {
    func testFinalizingWaitsForPersistenceAndMissingEventFallsBackToOldID() async throws {
        let gate = ResultReadGate()
        var calls: [String] = []
        let service = HouseRocketsOnlineResult(houseID: ResultFixture.houseID, read: { id in
            calls.append(id)
            return try await gate.read()
        })
        service.consume(try ResultFixture.lobby(gamePhase: "finalizing"))
        await settle()
        XCTAssertEqual(service.state.phase, .waiting)
        XCTAssertNil(service.state.result)
        XCTAssertFalse(service.state.canRematch)
        XCTAssertEqual(calls, [ResultFixture.sessionID])
        gate.resolve(try ResultFixture.result())
        await settle()
        XCTAssertEqual(service.state.phase, .available)
        XCTAssertTrue(service.state.canRematch)
        XCTAssertEqual(service.state.result?.players.map(\.rank), [1, 2, 2, 4])
        XCTAssertEqual(service.state.identities[ResultFixture.playerID]?.displayName, "Deniz")
        service.disconnect()
    }

    func testCommitPending404RetriesWithinBudget() async throws {
        var calls = 0
        let service = HouseRocketsOnlineResult(houseID: ResultFixture.houseID, read: { _ in
            calls += 1
            if calls < 3 { throw ResultFixture.http(404) }
            return try ResultFixture.result()
        }, clock: ResultFixture.fastClock)
        service.consume(try ResultFixture.lobby(gamePhase: "finalizing"))
        try await waitUntil { service.state.phase == .available }
        XCTAssertEqual(calls, 3)
        service.disconnect()
    }

    func test404ExhaustsFiveAttemptsWithoutInventingResultOrRematch() async throws {
        var calls = 0
        let service = HouseRocketsOnlineResult(houseID: ResultFixture.houseID, read: { _ in
            calls += 1; throw ResultFixture.http(404)
        }, clock: ResultFixture.fastClock)
        service.consume(try ResultFixture.lobby(gamePhase: "ended", sessionState: "finished"))
        try await waitUntil { service.state.phase == .failed }
        XCTAssertEqual(calls, 5)
        XCTAssertNil(service.state.result)
        XCTAssertFalse(service.state.canRematch)
        XCTAssertTrue(service.state.canRetry(at: 100))
        service.disconnect()
    }

    func testLobbyAndCountdownCancellationMayHaveNoResultRecord() async throws {
        for phase in [nil, "countdown"] as [String?] {
            var calls = 0
            let service = HouseRocketsOnlineResult(houseID: ResultFixture.houseID, read: { _ in
                calls += 1; throw ResultFixture.http(404)
            })
            service.consume(try ResultFixture.lobby(gamePhase: phase, sessionState: "cancelled", beforeStart: true))
            await settle()
            XCTAssertEqual(service.state.phase, .cancelledWithoutRecord)
            XCTAssertEqual(calls, 1)
            XCTAssertNil(service.state.result)
            XCTAssertTrue(service.state.canRematch)
            service.disconnect()
        }
    }

    func testPlayedCancellation404IsNotTreatedAsPrestartCancellation() async throws {
        let service = HouseRocketsOnlineResult(houseID: ResultFixture.houseID,
            read: { _ in throw ResultFixture.http(404) }, clock: ResultFixture.fastClock)
        service.consume(try ResultFixture.lobby(gamePhase: "cancelled", sessionState: "cancelled"))
        try await waitUntil { service.state.phase == .failed }
        XCTAssertNil(service.state.result)
        XCTAssertFalse(service.state.canRematch)
        service.disconnect()
    }

    func testDrawAndExpiryKeepServerRanksAndNoWinner() async throws {
        for name in ["drawResult", "cancelledResult", "cancelledBeforeStartResult"] {
            let service = HouseRocketsOnlineResult(houseID: ResultFixture.houseID,
                read: { _ in XCTFail("Socket result must not issue HTTP"); throw CancellationError() })
            var lobby = try ResultFixture.lobby(gamePhase: nil)
            let result = try ResultFixture.result(name)
            lobby.result = result
            lobby.resultEventID = "event-\(name)"
            service.consume(lobby)
            XCTAssertEqual(service.state.phase, .available)
            XCTAssertNil(service.state.result?.winnerId)
            XCTAssertEqual(service.state.result?.players.map(\.rank), result.players.map(\.rank))
            if result.status == .cancelled { XCTAssertTrue(result.players.allSatisfy { $0.rank == nil }) }
            service.disconnect()
        }
    }

    func testDuplicateEventDifferentEventIDAndHTTPDoNotReplaceFirstCommittedResult() async throws {
        let gate = ResultReadGate()
        let service = HouseRocketsOnlineResult(houseID: ResultFixture.houseID, read: { _ in try await gate.read() })
        service.consume(try ResultFixture.lobby(gamePhase: "finalizing"))
        await settle()
        var updates = 0
        service.onStateChange = { _ in updates += 1 }
        var lobby = try ResultFixture.lobby(gamePhase: "ended")
        lobby.result = try ResultFixture.result()
        lobby.resultEventID = "committed-event"
        service.consume(lobby)
        service.consume(lobby)
        lobby.resultEventID = "replayed-event"
        lobby.result = try ResultFixture.result("drawResult")
        service.consume(lobby)
        gate.resolve(try ResultFixture.result("cancelledResult")) // deliberately ignores cancellation
        await settle()
        XCTAssertEqual(updates, 1)
        XCTAssertEqual(service.state.result?.endReason, .lastSurvivor)
        service.disconnect()
    }

    func testLateOldHTTPAndSocketCannotAffectNewRematch() async throws {
        let gate = ResultReadGate()
        let old = HouseRocketsOnlineResult(houseID: ResultFixture.houseID, read: { _ in try await gate.read() })
        old.consume(try ResultFixture.lobby(gamePhase: "finalizing"))
        await settle()
        old.disconnect()
        let fresh = HouseRocketsOnlineResult(houseID: ResultFixture.houseID, read: { _ in throw CancellationError() })
        fresh.consume(try ResultFixture.lobby(gamePhase: nil, sessionID: "new-match"))
        gate.resolve(try ResultFixture.result())
        var late = try ResultFixture.lobby(gamePhase: "ended")
        late.result = try ResultFixture.result()
        fresh.consume(late)
        old.consume(late)
        await settle()
        XCTAssertNil(old.state.result)
        XCTAssertEqual(fresh.state.sessionID, "new-match")
        XCTAssertEqual(fresh.state.phase, .idle)
        XCTAssertNil(fresh.state.result)
        fresh.disconnect()
    }

    func testResultReaderWorksAfterSocketCleanupAndRejectsCrossHouse() async throws {
        let sessions = try ResultSessions()
        let online = OnlineHouseRocketsSession(sessions: sessions, transport: ResultTransport())
        let read = online.resultReader(houseID: ResultFixture.houseID)
        online.disconnect()
        let result = try await read(ResultFixture.sessionID)
        XCTAssertEqual(result.sessionId, ResultFixture.sessionID)
        let wrongHouse = online.resultReader(houseID: "another-house")
        do { _ = try await wrongHouse(ResultFixture.sessionID); XCTFail("Wrong house accepted") }
        catch { XCTAssertEqual(error as? GameRealtimeError, .unexpectedSession) }
    }

    func testWrongSessionHouseAndInvalidCancellationNeverPublishResult() async throws {
        for key in ["sessionId", "houseId", "rank"] {
            let invalid = try ResultFixture.result("cancelledResult") { payload in
                if key == "rank" {
                    var players = payload["players"] as! [[String: Any]]
                    players[0]["rank"] = 1; payload["players"] = players
                } else { payload[key] = "wrong" }
            }
            let service = HouseRocketsOnlineResult(houseID: ResultFixture.houseID, read: { _ in invalid })
            service.consume(try ResultFixture.lobby(gamePhase: "finalizing"))
            await settle()
            XCTAssertEqual(service.state.phase, .failed)
            XCTAssertNil(service.state.result)
            XCTAssertFalse(service.state.canRetry(at: 100))
            service.disconnect()
        }
    }

    func test401And403StopImmediatelyWithoutRetry() async throws {
        for status in [401, 403] {
            var calls = 0
            let service = HouseRocketsOnlineResult(houseID: ResultFixture.houseID, read: { _ in
                calls += 1; throw ResultFixture.http(status)
            }, clock: ResultFixture.fastClock)
            service.consume(try ResultFixture.lobby(gamePhase: "finalizing"))
            await settle()
            XCTAssertEqual(calls, 1)
            XCTAssertFalse(service.state.canRetry(at: 100))
            service.disconnect()
        }
    }

    func testRetryAfterIsRespectedWithoutUnboundedWaiting() async throws {
        var calls = 0
        let service = HouseRocketsOnlineResult(houseID: ResultFixture.houseID, read: { _ in
            calls += 1; throw ResultFixture.http(503, retryAfter: "60")
        }, clock: ResultFixture.fastClock)
        service.consume(try ResultFixture.lobby(gamePhase: "finalizing"))
        await settle()
        XCTAssertEqual(calls, 1)
        XCTAssertFalse(service.state.canRetry(at: 159))
        XCTAssertTrue(service.state.canRetry(at: 160))
        service.disconnect()
    }

    func testHungHTTPHasDeadlineAndLateCompletionIsIgnored() async throws {
        let gate = ResultReadGate()
        let clock = GameRealtimeClock(wallTime: { Date() }, uptime: { 100 }, sleep: { _ in
            try await Task.sleep(for: .milliseconds(20))
        })
        let service = HouseRocketsOnlineResult(houseID: ResultFixture.houseID, read: { _ in try await gate.read() }, clock: clock)
        service.consume(try ResultFixture.lobby(gamePhase: "finalizing"))
        try await waitUntil { service.state.phase == .failed }
        gate.resolve(try ResultFixture.result())
        await settle()
        XCTAssertNil(service.state.result)
        service.disconnect()
    }

    func testTerminalAndFinalizingSessionsCannotRetrySocket() async throws {
        for phase in ["finalizing", "ended", "cancelled"] {
            var lobby = try ResultFixture.lobby(gamePhase: phase)
            lobby.connection = .failed
            XCTAssertFalse(lobby.canReconnect(at: 100))
        }
        var lobby = try ResultFixture.lobby(gamePhase: nil, sessionState: "finished")
        lobby.connection = .failed
        XCTAssertFalse(lobby.canReconnect(at: 100))
    }

    func testCancellationPermissionMatchesCreatorOrHouseOwnerAndRequiresSync() async throws {
        let lobby = try ResultFixture.lobby(gamePhase: nil)
        let creator = lobby.session!.createdBy
        XCTAssertTrue(lobby.canCancel(context: .init(houseID: ResultFixture.houseID, localPlayerID: creator)))
        XCTAssertTrue(lobby.canCancel(context: .init(houseID: ResultFixture.houseID,
            localPlayerID: "owner", houseOwnerID: "owner")))
        XCTAssertFalse(lobby.canCancel(context: .init(houseID: ResultFixture.houseID, localPlayerID: "ordinary-member")))
        var pending = lobby
        pending.isSynced = false
        XCTAssertFalse(pending.canCancel(context: .init(houseID: ResultFixture.houseID, localPlayerID: creator)))
        pending = try ResultFixture.lobby(gamePhase: "finalizing")
        XCTAssertFalse(pending.canCancel(context: .init(houseID: ResultFixture.houseID, localPlayerID: creator)))
    }

    func testRematchRejectsOldOrTerminalPUTBeforeOpeningSocket() async throws {
        for terminal in [false, true] {
            let sessions = try ResultSessions(terminal: terminal)
            let transport = ResultTransport()
            let online = OnlineHouseRocketsSession(sessions: sessions, transport: transport)
            do {
                _ = try await online.connect(context: .init(houseID: ResultFixture.houseID, localPlayerID: ResultFixture.playerID),
                    excludingSessionID: terminal ? "some-old-session" : ResultFixture.sessionID)
                XCTFail("Old/terminal session accepted")
            } catch { XCTAssertEqual(error as? GameRealtimeError, .unexpectedSession) }
            XCTAssertEqual(transport.connects, 0)
            online.disconnect()
        }
    }

    func testRematchReusesExistingLobbyRosterWithoutJoiningOrReadyingTwice() async throws {
        var payload = try ResultFixture.payload("sessionSnapshot")
        payload["sessionId"] = "shared-rematch"; payload["state"] = "lobby"; payload["version"] = 1
        payload["players"] = [["playerId": ResultFixture.playerID, "state": "waiting", "joinedAt": "2026-10-03T12:00:00Z"]]
        let initial = try GameRealtimeCodec.makeDecoder().decode(GameSessionDTO.self, from: JSONSerialization.data(withJSONObject: payload))
        let sessions = try ResultSessions(initial: initial)
        let transport = ResultTransport()
        let session = OnlineHouseRocketsSession(sessions: sessions, transport: transport)
        let lobby = HouseRocketsOnlineLobby(session: session,
            context: .init(houseID: ResultFixture.houseID, localPlayerID: ResultFixture.playerID), excludingSessionID: ResultFixture.sessionID)
        var latest = HouseRocketsOnlineLobbyState()
        lobby.onStateChange = { latest = $0 }
        lobby.start(isForeground: true, isLandscape: true)
        transport.push(try ResultFixture.wire("welcome", sessionID: "shared-rematch"))
        transport.push(try ResultFixture.wire("sessionSnapshot", payload: payload))
        try await waitUntil { latest.connection == .connected && latest.isSynced }
        XCTAssertEqual(transport.count("gameSession.join"), 0)
        XCTAssertEqual(transport.count("gameSession.setReady"), 0)
        XCTAssertNil(latest.game)
        XCTAssertNil(latest.controlGrant)
        lobby.setReady(true)
        try await waitUntil { transport.count("gameSession.setReady") == 1 }
        XCTAssertEqual(sessions.ensureCalls, 1)
        lobby.disconnect()
    }

    func testRematchJoinsOnlyAbsentPlayerAndCancelRequiresAuthoritativeState() async throws {
        var payload = try ResultFixture.payload("sessionSnapshot")
        payload["sessionId"] = "new-rematch"; payload["state"] = "lobby"; payload["version"] = 1
        payload["createdBy"] = ResultFixture.playerID; payload["players"] = []
        let initial = try GameRealtimeCodec.makeDecoder().decode(GameSessionDTO.self, from: JSONSerialization.data(withJSONObject: payload))
        let transport = ResultTransport()
        let session = OnlineHouseRocketsSession(sessions: try ResultSessions(initial: initial), transport: transport)
        let lobby = HouseRocketsOnlineLobby(session: session,
            context: .init(houseID: ResultFixture.houseID, localPlayerID: ResultFixture.playerID), excludingSessionID: ResultFixture.sessionID)
        var latest = HouseRocketsOnlineLobbyState()
        lobby.onStateChange = { latest = $0 }
        lobby.start(isForeground: true, isLandscape: true)
        transport.push(try ResultFixture.wire("welcome", sessionID: "new-rematch"))
        transport.push(try ResultFixture.wire("sessionSnapshot", payload: payload))
        try await waitUntil { transport.count("gameSession.join") == 1 }
        payload["version"] = 2
        payload["players"] = [["playerId": ResultFixture.playerID, "state": "waiting", "joinedAt": "2026-10-03T12:00:00Z"]]
        transport.push(try ResultFixture.wire("sessionSnapshot", payload: payload))
        try await waitUntil { latest.pendingCommand == nil }
        XCTAssertEqual(transport.count("gameSession.join"), 1)
        XCTAssertEqual(transport.count("gameSession.setReady"), 0)
        lobby.cancelMatch()
        try await waitUntil { transport.count("gameSession.cancel") == 1 }
        let commandID = try XCTUnwrap(latest.pendingCommand?.message.messageId)
        transport.push(try ResultFixture.wire("accepted", messageID: commandID))
        try await waitUntil { latest.pendingCommand?.accepted == true }
        XCTAssertEqual(latest.pendingCommand?.message.action, .cancel)
        XCTAssertFalse(latest.isTerminal)
        payload["version"] = 3; payload["state"] = "cancelled"
        transport.push(try ResultFixture.wire("sessionSnapshot", payload: payload))
        try await waitUntil { latest.isTerminal }
        XCTAssertNil(latest.pendingCommand)
        lobby.finish()
        XCTAssertEqual(latest.session?.sessionId, "new-rematch")
        XCTAssertEqual(latest.connection, .idle)
        XCTAssertFalse(latest.canReconnect(at: ProcessInfo.processInfo.systemUptime))
        let sentAtFinish = transport.sent.count
        lobby.setForeground(false); lobby.setForeground(true); lobby.setLandscape(false)
        await settle()
        XCTAssertEqual(transport.sent.count, sentAtFinish)
        lobby.disconnect()
    }

    private func settle() async { for _ in 0..<30 { await Task.yield() } }
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        while !condition() {
            guard ProcessInfo.processInfo.systemUptime < deadline else { XCTFail("Condition timed out"); throw CancellationError() }
            try await Task.sleep(for: .milliseconds(1))
        }
    }
}

@MainActor
private final class ResultReadGate {
    var pending: CheckedContinuation<HouseRocketsResultDTO, Error>?
    func read() async throws -> HouseRocketsResultDTO { try await withCheckedThrowingContinuation { pending = $0 } }
    func resolve(_ result: HouseRocketsResultDTO) { pending?.resume(returning: result); pending = nil }
}

@MainActor
private final class ResultSessions: GameSessionServicing {
    let initial: GameSessionDTO
    var ensureCalls = 0
    init(terminal: Bool = false, initial: GameSessionDTO? = nil) throws {
        self.initial = try initial ?? XCTUnwrap(ResultFixture.lobby(gamePhase: nil, sessionState: terminal ? "finished" : "lobby").session)
    }
    func ensureHouseRocketsSession(houseID: String) async throws -> GameSessionDTO { ensureCalls += 1; return initial }
    func discoverHouseRocketsSession(houseID: String) async throws -> GameSessionDTO { initial }
    func houseRocketsResult(sessionID: String) async throws -> HouseRocketsResultDTO { try ResultFixture.result() }
    func realtimeRequest(sessionID: String) throws -> URLRequest { URLRequest(url: URL(string: "https://example.test")!) }
}

@MainActor
private final class ResultTransport: GameRealtimeTransporting {
    var connects = 0
    var sent: [[String: Any]] = []
    var queued: [Data] = []
    var receiving: CheckedContinuation<Data, Error>?
    func connect(request: URLRequest) async throws { connects += 1 }
    func send(_ data: Data) async throws {
        let message = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        sent.append(message)
        if message["type"] as? String == "realtime.ping" {
            var pong = try ResultFixture.payload("pong")
            pong["pingId"] = (message["payload"] as? [String: Any])?["pingId"]
            push(try ResultFixture.wire("pong", payload: pong))
        }
    }
    func receive() async throws -> Data {
        if !queued.isEmpty { return queued.removeFirst() }
        return try await withCheckedThrowingContinuation { receiving = $0 }
    }
    func ping() async throws {}
    func disconnect() { receiving?.resume(throwing: CancellationError()); receiving = nil }
    func push(_ data: Data) {
        if let receiving { self.receiving = nil; receiving.resume(returning: data) }
        else { queued.append(data) }
    }
    func count(_ type: String) -> Int { sent.filter { $0["type"] as? String == type }.count }
}

@MainActor
private enum ResultFixture {
    static let sessionID = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"
    static let houseID = "507f1f77bcf86cd799439012"
    static let playerID = "507f1f77bcf86cd799439021"
    static var fastClock: GameRealtimeClock {
        .init(wallTime: { Date() }, uptime: { 100 }, sleep: { duration in
            try await Task.sleep(for: .milliseconds(duration >= 20 ? 200 : 1))
        })
    }
    static func message(_ name: String) throws -> [String: Any] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: HouseRocketsOnlineResultTests.self)
        #endif
        let url = bundle.url(forResource: "houseRocketsProtocol", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "houseRocketsProtocol", withExtension: "json")
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: XCTUnwrap(url))) as! [String: Any]
        let messages = root["serverMessages"] as! [[String: Any]]
        return try XCTUnwrap(messages.first { $0["name"] as? String == name }?["message"] as? [String: Any])
    }
    static func payload(_ name: String) throws -> [String: Any] { try XCTUnwrap(message(name)["payload"] as? [String: Any]) }
    static func wire(_ name: String, payload: [String: Any]? = nil, sessionID: String? = nil, messageID: String? = nil) throws -> Data {
        var value = try message(name)
        if let payload { value["payload"] = payload }
        if let sessionID {
            var body = value["payload"] as! [String: Any]; body["sessionId"] = sessionID; value["payload"] = body
        }
        if let messageID { value["messageId"] = messageID }
        return try JSONSerialization.data(withJSONObject: value)
    }
    static func result(_ name: String = "result", mutate: (inout [String: Any]) -> Void = { _ in }) throws -> HouseRocketsResultDTO {
        var value = try payload(name); mutate(&value)
        return try GameRealtimeCodec.makeDecoder().decode(HouseRocketsResultDTO.self, from: JSONSerialization.data(withJSONObject: value))
    }
    static func lobby(gamePhase: String?, sessionState: String = "running", beforeStart: Bool = false,
                      sessionID: String? = nil) throws -> HouseRocketsOnlineLobbyState {
        let sessionID = sessionID ?? ResultFixture.sessionID
        var session = try payload("sessionSnapshot")
        session["sessionId"] = sessionID; session["state"] = sessionState
        session["startedAt"] = beforeStart ? NSNull() : "2026-10-03T12:00:33Z"
        if sessionState == "cancelled" { session["endReason"] = "cancelledByUser" }
        var state = HouseRocketsOnlineLobbyState()
        state.session = try GameRealtimeCodec.makeDecoder().decode(GameSessionDTO.self, from: JSONSerialization.data(withJSONObject: session))
        state.connection = .connected; state.isSynced = true; state.isLandscape = true
        if let gamePhase {
            var game = try payload("playing")
            game["phase"] = gamePhase; game["sessionId"] = sessionID
            if beforeStart { game["elapsedSeconds"] = 0 }
            state.game = try GameRealtimeCodec.makeDecoder().decode(HouseRocketsSnapshotDTO.self, from: JSONSerialization.data(withJSONObject: game))
        }
        return state
    }
    static func http(_ status: Int, retryAfter: String? = nil) -> NetworkHTTPFailure {
        let response = HTTPURLResponse(url: URL(string: "https://example.test")!, statusCode: status,
            httpVersion: nil, headerFields: retryAfter.map { ["Retry-After": $0] })!
        return .init(response: .init(data: Data("{\"success\":false,\"error\":\"localized text\"}".utf8), response: response))
    }
}
