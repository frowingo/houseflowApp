import Foundation
import FausCrewCore
import XCTest

/// The sans-IO online engine against the shared protocol fixture (also used by iOS).
final class HouseRocketsOnlineEngineTests: XCTestCase {
    private let houseID = "507f1f77bcf86cd799439012"
    private let playerID = "507f1f77bcf86cd799439021"
    private let sessionID = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"
    private var ids = 0

    func testLobbyJoinsReadiesAndKeepsHeartbeat() throws {
        let (engine, socket) = try connectedLobby()
        XCTAssertEqual(engine.lobby.connection, .connected)
        XCTAssertTrue(engine.lobby.isSynced)
        let join = try XCTUnwrap(sent(engine).first)
        XCTAssertEqual(join["type"] as? String, "gameSession.join")

        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting"), at: 1)
        XCTAssertNil(engine.lobby.pendingCommand, "Roster proof confirms the join")
        XCTAssertTrue(engine.lobby.canChangeReady(playerID: playerID))

        engine.setReady(true, now: 1.1)
        XCTAssertEqual(try sent(engine).first?["type"] as? String, "gameSession.setReady")
        try receive(engine, socket, session(version: 8, state: "lobby", localState: "ready"), at: 1.2)
        XCTAssertEqual(engine.lobby.localPlayer(playerID)?.state, .ready)

        engine.tick(now: 2.6)
        let ping = try XCTUnwrap(sent(engine).first)
        XCTAssertEqual(ping["type"] as? String, "realtime.ping")
        let pingID = try XCTUnwrap((ping["payload"] as? [String: Any])?["pingId"] as? String)
        try receive(engine, socket, server("pong") { message in
            message["payload"] = ["pingId": pingID, "serverTime": "2026-10-03T12:00:33.125Z"]
        }, at: 2.7)
        engine.tick(now: 8)
        XCTAssertEqual(engine.lobby.connection, .connected, "A pong within the timeout keeps the lobby")
    }

    func testLandscapeLossWithdrawsReadiness() throws {
        let (engine, socket) = try connectedLobby()
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "ready"), at: 1)
        engine.setLandscape(false, now: 1.1)
        let message = try XCTUnwrap(sent(engine).first)
        XCTAssertEqual(message["type"] as? String, "gameSession.setReady")
        XCTAssertEqual((message["payload"] as? [String: Any])?["ready"] as? Bool, false)
    }

    func testFlightStreamsSteeringOnlyWithTheCurrentGrant() throws {
        let (engine, socket) = try connectedLobby(state: "running")
        try receive(engine, socket, server("playing"), at: 1)
        try receive(engine, socket, server("controlGranted"), at: 1.01)
        XCTAssertEqual(engine.lobby.controlGrant?.controlGeneration, "controlA")
        let presentation = try XCTUnwrap(engine.presentation(at: 1.02))
        XCTAssertTrue(presentation.canSteer)
        XCTAssertEqual(presentation.frame.players.first { $0.id == playerID }?.role, .human)

        _ = engine.drainEffects()
        engine.steer(screenHeading: 0.5, now: 1.03)
        engine.tick(now: 1.05)
        let steer = try XCTUnwrap(sent(engine).first { $0["type"] as? String == "houseRockets.steer" })
        let payload = try XCTUnwrap(steer["payload"] as? [String: Any])
        XCTAssertEqual(payload["controlGeneration"] as? String, "controlA")
        XCTAssertEqual((payload["inputSequence"] as? NSNumber)?.int64Value, 43, "Continues after the server's last processed input (42)")

        // Without a fresh snapshot the stream stops and asks for authority again.
        engine.tick(now: 1.4)
        XCTAssertTrue(try sent(engine).contains { $0["type"] as? String == "houseRockets.resync" })
        XCTAssertFalse(engine.presentation(at: 1.4)?.canSteer ?? true)
    }

    func testTransportLossReconnectsToThePinnedMatchWithoutANewSession() throws {
        let (engine, socket) = try connectedLobby()
        _ = engine.drainEffects()
        engine.connectionFailed(.transport, connection: socket, now: 2)
        XCTAssertEqual(engine.lobby.connection, .reconnecting)
        XCTAssertTrue(engine.drainEffects().contains(.closeSocket))
        let retryAt = try XCTUnwrap(engine.lobby.retryNotBefore)
        XCTAssertEqual(retryAt, 2.4, accuracy: 0.001, "First backoff is 0.5 s × jitter 0.8")
        engine.tick(now: retryAt + 0.01)
        let effects = engine.drainEffects()
        XCTAssertFalse(effects.contains { if case .ensureSession = $0 { return true }; return false })
        guard case .openSocket(let pinnedID, let next) = effects.last else { return XCTFail("Expected reopen: \(effects)") }
        XCTAssertEqual(pinnedID, sessionID)
        XCTAssertGreaterThan(next, socket)

        // Events from the old socket are ignored.
        engine.received(text: String(decoding: try server("welcome"), as: UTF8.self), connection: socket, now: 3)
        XCTAssertEqual(engine.lobby.connection, .reconnecting)
    }

    func testClosedGameAndForbiddenAreTerminalFailures() throws {
        for (status, body, expected) in [
            (409, #"{"code":"game.error.unavailable"}"#, GameRealtimeSessionFailure.protocolFailure(.gameUnavailable)),
            (403, #"{"code":"house.error.user_not_member"}"#, .http(statusCode: 403, retryAfterSeconds: nil)),
        ] {
            let engine = makeEngine()
            engine.start(isForeground: true, isLandscape: true, now: 0)
            let connection = try ensureConnection(engine)
            engine.sessionResponse(HTTPResponse(statusCode: status, headers: [:], body: Data(body.utf8)),
                                   retryAfter: nil, connection: connection, now: 0.2)
            XCTAssertEqual(engine.lobby.connection, .failed)
            XCTAssertEqual(engine.lobby.issue, .connection(expected))
            XCTAssertFalse(engine.lobby.canReconnect(at: .infinity))
        }
    }

    func testServerBusyHonoursRetryAfter() throws {
        let engine = makeEngine()
        engine.start(isForeground: true, isLandscape: true, now: 0)
        let connection = try ensureConnection(engine)
        engine.sessionResponse(HTTPResponse(statusCode: 503, headers: [:], body: Data()), retryAfter: 3,
                               connection: connection, now: 0.1)
        XCTAssertEqual(engine.lobby.connection, .reconnecting)
        XCTAssertEqual(try XCTUnwrap(engine.lobby.retryNotBefore), 3.1, accuracy: 0.001)
        engine.tick(now: 3.0)
        XCTAssertFalse(engine.drainEffects().contains { if case .ensureSession = $0 { return true }; return false })
        engine.tick(now: 3.2)
        XCTAssertTrue(engine.drainEffects().contains { if case .ensureSession = $0 { return true }; return false })
    }

    func testMissingWelcomeTimesOutAfterTenSeconds() throws {
        let engine = makeEngine()
        engine.start(isForeground: true, isLandscape: true, now: 0)
        let connection = try ensureConnection(engine)
        engine.sessionResponse(try http("ensure", state: "lobby"), retryAfter: nil, connection: connection, now: 0.1)
        engine.socketOpened(connection: connection, now: 0.2)
        engine.tick(now: 9.9)
        XCTAssertEqual(engine.lobby.connection, .connecting)
        engine.tick(now: 10.1)
        XCTAssertEqual(engine.lobby.issue, .timeout)
        XCTAssertEqual(engine.lobby.connection, .reconnecting)
    }

    func testLeaveSendsBusinessLeaveThenCloses() throws {
        let (engine, socket) = try connectedLobby()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting"), at: 1)
        _ = engine.drainEffects()
        engine.leave(now: 2)
        XCTAssertTrue(engine.lobby.isLeaving)
        XCTAssertEqual(try sent(engine).first?["type"] as? String, "gameSession.leave")
        XCTAssertFalse(engine.isClosed)
        try receive(engine, socket, session(version: 8, state: "lobby", localState: nil), at: 2.2)
        XCTAssertTrue(engine.isClosed)
        XCTAssertTrue(engine.drainEffects().contains(.closeSocket))

        let unconfirmed = try connectedLobby().engine
        unconfirmed.leave(now: 5)
        unconfirmed.tick(now: 7.1)
        XCTAssertTrue(unconfirmed.isClosed, "Exit never waits more than two seconds")
    }

    func testResultEventFinishesTheMatchAndAllowsRematch() throws {
        let (engine, socket) = try connectedLobby(state: "running")
        try receive(engine, socket, server("playing"), at: 1)
        _ = engine.drainEffects()
        try receive(engine, socket, server("result"), at: 2)
        XCTAssertEqual(engine.result.phase, .available)
        XCTAssertTrue(engine.result.canRematch)
        XCTAssertEqual(engine.rematchExcludedSessionID, sessionID)
        XCTAssertFalse(engine.isClosed, "A finished match keeps its result screen")
        let effects = engine.drainEffects()
        XCTAssertTrue(effects.contains(.closeSocket))
        XCTAssertTrue(effects.contains(.haptic(.success)) || effects.contains(.haptic(.warning)))
    }

    func testTerminalSessionLooksUpTheResultOverHTTPWithRetries() throws {
        let (engine, socket) = try connectedLobby(state: "running")
        try receive(engine, socket, server("playing"), at: 1)
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 10, state: "finished", localState: "finished"), at: 2)
        XCTAssertEqual(engine.result.phase, .waiting)
        guard case .fetchResult(let id, let first) = try XCTUnwrap(engine.drainEffects().last) else {
            return XCTFail("Expected an HTTP result lookup")
        }
        XCTAssertEqual(id, sessionID)
        engine.resultResponse(HTTPResponse(statusCode: 503, headers: [:], body: Data()), retryAfter: nil,
                              request: first, now: 2.1)
        XCTAssertEqual(engine.result.phase, .waiting)
        engine.tick(now: 2.7)
        guard case .fetchResult(_, let second) = try XCTUnwrap(engine.drainEffects().last) else {
            return XCTFail("Expected a retry")
        }
        engine.resultResponse(try http("result"), retryAfter: nil, request: second, now: 2.8)
        XCTAssertEqual(engine.result.phase, .available)
        XCTAssertEqual(engine.result.result?.sessionId, sessionID)
    }

    func testCancelledBeforeStartWithoutRecord() throws {
        let (engine, socket) = try connectedLobby()
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 7, state: "cancelled", localState: "left"), at: 1)
        guard case .fetchResult(_, let request) = try XCTUnwrap(engine.drainEffects().last) else { return XCTFail() }
        engine.resultResponse(HTTPResponse(statusCode: 404, headers: [:], body: Data()), retryAfter: nil,
                              request: request, now: 1.1)
        XCTAssertEqual(engine.result.phase, .cancelledWithoutRecord)
        XCTAssertTrue(engine.result.canRematch)
    }

    func testForegroundLossClearsControlAndResumeResyncs() throws {
        let (engine, socket) = try connectedLobby(state: "running")
        try receive(engine, socket, server("playing"), at: 1)
        try receive(engine, socket, server("controlGranted"), at: 1.01)
        engine.setForeground(false, now: 1.1)
        XCTAssertNil(engine.lobby.controlGrant)
        _ = engine.drainEffects()
        engine.setForeground(true, now: 5)
        XCTAssertEqual(engine.lobby.connection, .syncing)
        XCTAssertTrue(try sent(engine).contains { $0["type"] as? String == "houseRockets.resync" })
    }

    func testOversizeOrUnknownMessagesFailWithoutRetryingForever() throws {
        let (engine, socket) = try connectedLobby()
        engine.received(text: #"{"protocolVersion":2,"type":"mystery.type","sentAt":"2026-10-03T12:00:30Z","payload":{}}"#,
                        connection: socket, now: 1)
        XCTAssertEqual(engine.lobby.issue, .connection(.protocolFailure(.unsupportedMessage("mystery.type"))))
        XCTAssertEqual(engine.lobby.connection, .failed)
    }

    // MARK: Behaviour ported from the iOS lobby, reconnect, flight and result suites

    func testSessionBeforeWelcomeDoesNotJoinAndJoinIsSentOnce() throws {
        let engine = makeEngine()
        engine.start(isForeground: true, isLandscape: true, now: 0)
        let connection = try ensureConnection(engine)
        engine.sessionResponse(try http("ensure", state: "lobby"), retryAfter: nil, connection: connection, now: 0.1)
        engine.socketOpened(connection: connection, now: 0.2)
        _ = engine.drainEffects()
        try receive(engine, connection, session(version: 6, state: "lobby", localState: nil), at: 0.3)
        XCTAssertTrue(try sent(engine).isEmpty, "No join before the welcome")
        try receive(engine, connection, server("welcome"), at: 0.4)
        try receive(engine, connection, session(version: 7, state: "lobby", localState: nil), at: 0.5)
        XCTAssertEqual(try sent(engine).filter { $0["type"] as? String == "gameSession.join" }.count, 1)
        try receive(engine, connection, session(version: 8, state: "lobby", localState: nil), at: 0.6)
        XCTAssertTrue(try sent(engine).isEmpty, "A pending join is not repeated")
    }

    func testReadyRejectionKeepsTheServerRosterAndAsksForCorrelatedResync() throws {
        let (engine, socket) = try connectedLobby()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting"), at: 1)
        _ = engine.drainEffects()
        engine.setReady(true, now: 1.1)
        let ready = try XCTUnwrap(sent(engine).first)
        let id = try XCTUnwrap(ready["messageId"] as? String)
        try receive(engine, socket, server("rejected") { message in
            message["messageId"] = id
            message["error"] = ["code": "game.error.ready_closed", "args": [], "retryable": false]
        }, at: 1.2)
        XCTAssertEqual(engine.lobby.localPlayer(playerID)?.state, .waiting, "No optimistic ready")
        XCTAssertEqual(engine.lobby.issue, .rejected(.init(code: "game.error.ready_closed", args: [], retryable: false)))
        let resync = try XCTUnwrap(sent(engine).first)
        XCTAssertEqual(resync["type"] as? String, "houseRockets.resync")
        XCTAssertEqual(engine.lobby.connection, .syncing)
        try receive(engine, socket, session(version: 8, state: "lobby", localState: "waiting") { $0["messageId"] = resync["messageId"] }, at: 1.3)
        XCTAssertEqual(engine.lobby.connection, .connected)
        XCTAssertEqual(engine.lobby.issue, .rejected(.init(code: "game.error.ready_closed", args: [], retryable: false)))
    }

    func testUnconfirmedLifecycleCommandIsResentOnceThenTimesOut() throws {
        let (engine, socket) = try connectedLobby()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting"), at: 1)
        _ = engine.drainEffects()
        engine.setReady(true, now: 1)
        let first = try XCTUnwrap(sent(engine).first)
        var resent: [[String: Any]] = []
        var now = 1.0
        while now < 9.2 {
            now += 0.25
            engine.tick(now: now)
            for message in try sent(engine) {
                if message["type"] as? String == "gameSession.setReady" { resent.append(message) }
                if message["type"] as? String == "realtime.ping",
                   let id = (message["payload"] as? [String: Any])?["pingId"] as? String {
                    try receive(engine, socket, server("pong") {
                        $0["payload"] = ["pingId": id, "serverTime": "2026-10-03T12:00:33.125Z"]
                    }, at: now)
                }
            }
        }
        XCTAssertEqual(resent.count, 1, "One retransmission")
        XCTAssertEqual(resent.first?["messageId"] as? String, first["messageId"] as? String, "Same identity on retry")
        XCTAssertEqual(engine.lobby.issue, .commandTimeout)
    }

    func testGrantAndSnapshotMayArriveInEitherOrder() throws {
        let (engine, socket) = try connectedLobby(state: "running")
        try receive(engine, socket, server("controlGranted"), at: 0.9)
        XCTAssertNil(engine.presentation(at: 0.95), "No flight before the first snapshot")
        try receive(engine, socket, server("playing"), at: 1.0)
        XCTAssertTrue(try XCTUnwrap(engine.presentation(at: 1.01)).canSteer)
    }

    func testSteeringIsCoalescedToTheServerRateAndAcknowledgementsPruneInputs() throws {
        let (engine, socket) = try flying()
        _ = engine.drainEffects()
        var now = 1.02
        var steers = 0
        for step in 0..<10 {
            engine.steer(screenHeading: Double(step) * 0.1, now: now)
            engine.tick(now: now)
            steers += try sent(engine).filter { $0["type"] as? String == "houseRockets.steer" }.count
            now += 0.01
        }
        XCTAssertLessThanOrEqual(steers, 3, "At most 20 Hz even when the finger moves every 10 ms")
        try receive(engine, socket, playing(sequence: 3, tick: 27, elapsed: 0.225) { players in
            players[0]["lastProcessedInputSequence"] = 42 + steers
        }, at: now)
        engine.tick(now: now + 0.3)
        XCTAssertTrue(try sent(engine).filter { $0["type"] as? String == "houseRockets.steer" }.isEmpty,
                      "A steady heading that the server acknowledged is not resent")
    }

    func testStaleControlRejectionMeansAnotherDeviceTookControlUntilReclaimed() throws {
        let (engine, socket) = try flying()
        _ = engine.drainEffects()
        engine.steer(screenHeading: 0.4, now: 1.03)
        engine.tick(now: 1.04)
        let steer = try XCTUnwrap(sent(engine).first { $0["type"] as? String == "houseRockets.steer" })
        try receive(engine, socket, server("rejected") { $0["messageId"] = steer["messageId"] }, at: 1.05)
        XCTAssertTrue(engine.lobby.controlTransferred)
        XCTAssertFalse(engine.presentation(at: 1.06)?.canSteer ?? true)
        engine.tick(now: 3)
        XCTAssertTrue(try sent(engine).filter { $0["type"] as? String == "houseRockets.resync" }.isEmpty,
                      "No automatic resync race while another device steers")
        engine.reclaimControl(now: 3.1)
        XCTAssertTrue(try sent(engine).contains { $0["type"] as? String == "houseRockets.resync" })
        XCTAssertFalse(engine.lobby.controlTransferred)
    }

    func testMembershipRevocationStopsRetrying() throws {
        let (engine, socket) = try connectedLobby()
        try receive(engine, socket, server("rejected") { message in
            message.removeValue(forKey: "messageId")
            message["error"] = ["code": "house.error.user_not_member", "args": [], "retryable": false]
        }, at: 1)
        XCTAssertEqual(engine.lobby.issue, .connection(.http(statusCode: 403, retryAfterSeconds: nil)))
        XCTAssertEqual(engine.lobby.connection, .failed)
        XCTAssertFalse(engine.lobby.canReconnect(at: .infinity))
    }

    func testRepeated503StopsAfterFiveAutomaticAttempts() throws {
        let engine = makeEngine()
        engine.start(isForeground: true, isLandscape: true, now: 0)
        var now = 0.0
        var ensures = 0
        for _ in 0..<20 {
            for effect in engine.drainEffects() {
                if case .ensureSession(_, let connection) = effect {
                    ensures += 1
                    engine.sessionResponse(HTTPResponse(statusCode: 503, headers: [:], body: Data()), retryAfter: nil,
                                           connection: connection, now: now)
                }
            }
            now += 1
            engine.tick(now: now)
        }
        XCTAssertEqual(ensures, 6, "The first attempt plus five automatic retries")
        XCTAssertEqual(engine.lobby.connection, .failed)
        XCTAssertTrue(engine.lobby.canReconnect(at: .infinity), "A manual retry stays available")
    }

    func testEliminatedPlayerCannotBeRevivedByAnOlderAliveFrame() throws {
        let (engine, socket) = try flying()
        try receive(engine, socket, playing(sequence: 3, tick: 30, elapsed: 0.25) { players in
            players[1]["isAlive"] = false
            players[1]["eliminatedAtTick"] = 30
            players[1]["eliminationReason"] = "behindCamera"
        }, at: 1.1)
        XCTAssertEqual(try XCTUnwrap(engine.presentation(at: 1.11)).eliminations.map(\.displayName), ["Ece"])
        try receive(engine, socket, playing(sequence: 4, tick: 33, elapsed: 0.275), at: 1.2)
        XCTAssertEqual(engine.lobby.issue, .connection(.invalidPayload), "A revived player is an invalid frame")
    }

    func testPresentationNeverRunsAheadOfTheServerMoreThanTheExtrapolationBudget() throws {
        let (engine, _) = try flying()
        let fresh = try XCTUnwrap(engine.presentation(at: 1.02))
        XCTAssertFalse(fresh.isSyncing)
        let stale = try XCTUnwrap(engine.presentation(at: 1.5))
        XCTAssertTrue(stale.isSyncing, "Old authority is shown as syncing")
        XCTAssertLessThanOrEqual(stale.frame.elapsedTime, 0.125 + 0.15 + 0.000_1)
    }

    func testRematchRefusesTheFinishedSession() throws {
        let engine = HouseRocketsOnlineEngine(
            context: HouseRocketsLaunchContext(houseID: houseID, localPlayerID: playerID),
            excludingSessionID: sessionID, policy: HouseRocketsReconnectPolicy(jitter: { 0.8 }),
            makeID: { [unowned self] in ids += 1; return "id\(ids)" })
        engine.start(isForeground: true, isLandscape: true, now: 0)
        let connection = try ensureConnection(engine)
        engine.sessionResponse(try http("ensure", state: "lobby"), retryAfter: nil, connection: connection, now: 0.1)
        XCTAssertEqual(engine.lobby.issue, .connection(.protocolFailure(.unexpectedSession)))
        XCTAssertFalse(engine.drainEffects().contains { if case .openSocket = $0 { return true }; return false })
    }

    func testCancelIsOnlyForTheCreatorOrHouseOwner() throws {
        let (owner, socket) = try connectedLobby()
        XCTAssertFalse(owner.canCancel(), "Not while the join is unconfirmed")
        try receive(owner, socket, session(version: 7, state: "lobby", localState: "waiting"), at: 1)
        XCTAssertTrue(owner.canCancel(), "The fixture session was created by this player")
        let guestEngine = HouseRocketsOnlineEngine(
            context: HouseRocketsLaunchContext(houseID: houseID, localPlayerID: "507f1f77bcf86cd799439022"))
        XCTAssertFalse(guestEngine.canCancel())
    }

    func testResultLookupGivesUpAfterFiveAttemptsAndAuthFailuresStopAtOnce() throws {
        for (status, expectedRequests) in [(404, 5), (401, 1)] {
            let (engine, socket) = try connectedLobby(state: "running")
            try receive(engine, socket, server("playing"), at: 1)
            _ = engine.drainEffects()
            try receive(engine, socket, session(version: 10, state: "finished", localState: "finished"), at: 2)
            var now = 2.0
            var requests = 0
            for _ in 0..<40 {
                for effect in engine.drainEffects() {
                    if case .fetchResult(_, let request) = effect {
                        requests += 1
                        engine.resultResponse(HTTPResponse(statusCode: status, headers: [:], body: Data()), retryAfter: nil,
                                              request: request, now: now)
                    }
                }
                now += 0.5
                engine.tick(now: now)
            }
            XCTAssertEqual(requests, expectedRequests, "status \(status)")
            XCTAssertEqual(engine.result.phase, .failed)
            XCTAssertFalse(engine.result.canRematch, "No result is invented")
        }
    }

    func testDuplicateResultEventDoesNotReplaceTheFirstOne() throws {
        let (engine, socket) = try connectedLobby(state: "running")
        try receive(engine, socket, server("playing"), at: 1)
        try receive(engine, socket, server("result") { $0["messageId"] = "event-1" }, at: 2)
        let first = engine.result.result
        try receive(engine, socket, server("drawResult") { $0["messageId"] = "event-2" }, at: 2.1)
        XCTAssertEqual(engine.result.result, first)
    }

    // MARK: Helpers

    private func flying() throws -> (engine: HouseRocketsOnlineEngine, socket: Int) {
        let (engine, socket) = try connectedLobby(state: "running")
        try receive(engine, socket, server("playing"), at: 1)
        try receive(engine, socket, server("controlGranted"), at: 1.01)
        return (engine, socket)
    }

    private func playing(sequence: Int, tick: Int, elapsed: Double,
                         players mutate: (inout [[String: Any]]) -> Void = { _ in }) throws -> Data {
        try server("playing") { message in
            var payload = message["payload"] as! [String: Any]
            payload["stateSequence"] = sequence
            payload["tick"] = tick
            payload["elapsedSeconds"] = elapsed
            var players = payload["players"] as! [[String: Any]]
            mutate(&players)
            payload["players"] = players
            message["payload"] = payload
            message["sequence"] = sequence
        }
    }

    private func makeEngine() -> HouseRocketsOnlineEngine {
        HouseRocketsOnlineEngine(
            context: HouseRocketsLaunchContext(houseID: houseID, localPlayerID: playerID, houseOwnerID: playerID),
            policy: HouseRocketsReconnectPolicy(jitter: { 0.8 }),
            makeID: { [unowned self] in ids += 1; return "id\(ids)" }
        )
    }

    private func connectedLobby(state: String = "lobby") throws -> (engine: HouseRocketsOnlineEngine, socket: Int) {
        let engine = makeEngine()
        engine.start(isForeground: true, isLandscape: true, now: 0)
        let connection = try ensureConnection(engine)
        engine.sessionResponse(try http("ensure", state: state), retryAfter: nil, connection: connection, now: 0.1)
        guard case .openSocket(let id, let socket) = try XCTUnwrap(engine.drainEffects().last) else {
            throw XCTSkip("No socket opened")
        }
        XCTAssertEqual(id, sessionID)
        engine.socketOpened(connection: socket, now: 0.2)
        try receive(engine, socket, server("welcome"), at: 0.3)
        let localState: String? = state == "lobby" ? nil : "playing"
        try receive(engine, socket, session(version: 6, state: state, localState: localState), at: 0.4)
        return (engine, socket)
    }

    private func ensureConnection(_ engine: HouseRocketsOnlineEngine) throws -> Int {
        guard case .ensureSession(let house, let connection) = try XCTUnwrap(engine.drainEffects().first) else {
            throw XCTSkip("No ensure effect")
        }
        XCTAssertEqual(house, houseID)
        return connection
    }

    private func receive(_ engine: HouseRocketsOnlineEngine, _ socket: Int, _ data: Data, at now: TimeInterval) throws {
        engine.received(text: String(decoding: data, as: UTF8.self), connection: socket, now: now)
    }

    private func sent(_ engine: HouseRocketsOnlineEngine) throws -> [[String: Any]] {
        try engine.drainEffects().compactMap { effect in
            guard case .send(let text, _) = effect else { return nil }
            return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        }
    }

    private static var fixture: [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Fixtures/houseRocketsProtocol.json")
        return (try? JSONSerialization.jsonObject(with: Data(contentsOf: url))) as? [String: Any] ?? [:]
    }

    private func server(_ name: String, mutate: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        let messages = try XCTUnwrap(Self.fixture["serverMessages"] as? [[String: Any]])
        var message = try XCTUnwrap(messages.first { $0["name"] as? String == name }?["message"] as? [String: Any])
        mutate(&message)
        return try JSONSerialization.data(withJSONObject: message)
    }

    private func http(_ name: String, state: String? = nil) throws -> HTTPResponse {
        let http = try XCTUnwrap(Self.fixture["http"] as? [String: [String: Any]])
        var response = try XCTUnwrap(http[name]?["response"] as? [String: Any])
        if let state, var data = response["data"] as? [String: Any] {
            data["state"] = state
            if state == "lobby" { data["players"] = []; data["countdownEndsAt"] = NSNull() }
            response["data"] = data
        }
        return HTTPResponse(statusCode: 200, headers: [:], body: try JSONSerialization.data(withJSONObject: response))
    }

    /// A `gameSession.snapshot` with the local player in `localState` (nil = absent).
    private func session(version: Int64, state: String, localState: String?,
                         message extra: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        try server("sessionSnapshot") { message in
            defer { extra(&message) }
            var payload = message["payload"] as! [String: Any]
            payload["version"] = version
            payload["state"] = state
            var players = (payload["players"] as! [[String: Any]]).filter { $0["playerId"] as? String != self.playerID }
            if let localState {
                players.insert(["playerId": self.playerID, "state": localState,
                                "joinedAt": "2026-10-03T12:00:00Z", "readyAt": NSNull(), "leftAt": NSNull()], at: 0)
            }
            payload["players"] = players
            if state == "lobby" { payload["countdownEndsAt"] = NSNull() }
            if state == "finished" || state == "cancelled" { payload["endedAt"] = "2026-10-03T12:00:40Z" }
            if state == "cancelled" { payload["startedAt"] = NSNull(); payload["endReason"] = "cancelledByUser" }
            message["payload"] = payload
        }
    }
}
