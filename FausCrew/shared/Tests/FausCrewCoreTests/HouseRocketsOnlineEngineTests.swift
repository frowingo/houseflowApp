import Foundation
import FausCrewCore
import XCTest

/// The sans-IO online engine against the shared protocol fixture (also used by iOS).
final class HouseRocketsOnlineEngineTests: XCTestCase {
    private struct UnexpectedTestState: Error {}

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

        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting", colors: [playerID: "teal"]), at: 1)
        XCTAssertNil(engine.lobby.pendingCommand, "Roster proof confirms the join")
        XCTAssertTrue(engine.canChangeReady)

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

    func testReadyCountsInThePortraitRoom() throws {
        let (engine, socket) = try connectedLobby()
        engine.setLandscape(false, now: 1)
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting", colors: [playerID: "teal"]), at: 1.05)
        engine.setReady(true, now: 1.1)
        let message = try XCTUnwrap(sent(engine).first)
        XCTAssertEqual(message["type"] as? String, "gameSession.setReady")
        XCTAssertEqual((message["payload"] as? [String: Any])?["ready"] as? Bool, true,
                       "The room is portrait; the screen turns only when the countdown starts")
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

        // A silence of a second drops control and asks for authority again.
        engine.tick(now: 2.1)
        XCTAssertTrue(try sent(engine).contains { $0["type"] as? String == "houseRockets.resync" })
        XCTAssertFalse(engine.presentation(at: 2.1)?.canSteer ?? true)
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
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting", colors: [playerID: "teal"]), at: 1)
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
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting", colors: [playerID: "teal"]), at: 1)
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
        // The newest heading the busy rate gate held back goes out with the next host tick.
        engine.tick(now: now)
        steers += try sent(engine).filter { $0["type"] as? String == "houseRockets.steer" }.count
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
        let configuration = HouseRocketsFlightConfiguration()
        let (engine, _) = try flying()
        let fresh = try XCTUnwrap(engine.presentation(at: 1.02))
        XCTAssertFalse(fresh.isSyncing)
        let hiccup = try XCTUnwrap(engine.presentation(at: 1.3))
        XCTAssertFalse(hiccup.isSyncing, "A 300 ms hiccup is inside the display budget")
        let stale = try XCTUnwrap(engine.presentation(at: 1.6))
        XCTAssertTrue(stale.isSyncing, "Old authority is shown as syncing")
        XCTAssertLessThanOrEqual(stale.frame.elapsedTime, 0.125 + configuration.maximumExtrapolation + 0.000_1)
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

    // MARK: Diagnostics

    /// The HUD's FPS chip counts the playing frames drawn in the last second.
    func testDisplayFramesPerSecondCountsPlayingFrames() throws {
        let (engine, _) = try flying()
        XCTAssertEqual(engine.displayFramesPerSecond(at: 1.0), 0)
        var frameTime = 1.02
        for index in 0..<90 {
            _ = engine.presentation(at: frameTime)
            if index == 30 {
                XCTAssertEqual(engine.displayFramesPerSecond(at: frameTime), 0, "No half-counted rate in the first second")
            }
            frameTime += 1.0 / 60
        }
        XCTAssertTrue((55...65).contains(engine.displayFramesPerSecond(at: frameTime)),
                      "\(engine.displayFramesPerSecond(at: frameTime))")
        XCTAssertEqual(engine.displayFramesPerSecond(at: frameTime + 0.5), 0, "Frames stopped: no chip")
        // Back after a pause (the app in the background): a new second of play first.
        _ = engine.presentation(at: frameTime + 2)
        XCTAssertEqual(engine.displayFramesPerSecond(at: frameTime + 2), 0)
    }

    /// The display clock keeps its pace through late and early snapshots: no render steps backward.
    func testDisplayNeverStepsBackwardUnderJitteredSnapshots() throws {
        let run = try jitteredFlight(readingDiagnostics: true)
        let diagnostics = run.diagnostics
        XCTAssertEqual(diagnostics.backwardDisplaySteps, 0)
        XCTAssertNotNil(diagnostics.displayJump)
        let interval = try XCTUnwrap(diagnostics.snapshotInterval)
        XCTAssertTrue((20...60).contains(interval.p50), "30 Hz stream: \(interval)")
        XCTAssertGreaterThan(interval.max, 60, "The ±40 ms jitter shows as long gaps")
        XCTAssertTrue((55...65).contains(diagnostics.displayFramesPerSecond), "\(diagnostics.displayFramesPerSecond)")
        XCTAssertEqual(diagnostics.remoteTeleports, 0)
        XCTAssertEqual(diagnostics.resyncRequests, 0)
        XCTAssertEqual(diagnostics.lines.count, 8)
        XCTAssertTrue(diagnostics.lines[3].hasPrefix("clock jump p95 "), diagnostics.lines[3])
    }

    func testReadingDiagnosticsNeverChangesTheFrames() throws {
        let read = try jitteredFlight(readingDiagnostics: true)
        let untouched = try jitteredFlight(readingDiagnostics: false)
        XCTAssertEqual(read.frames, untouched.frames)
    }

    func testDiagnosticsCountSwallowedSteeringAndControlLoss() throws {
        let (engine, _) = try flying()
        engine.steer(screenHeading: 0.4, now: 1.03)
        XCTAssertEqual(engine.diagnostics(at: 1.03).swallowedInputs, 0)
        for step in 0..<20 { engine.steer(screenHeading: 0.9 + Double(step) * 0.01, now: 2.1) }
        for at in [2.1, 2.125, 2.15, 2.175] { engine.tick(now: at) }
        let diagnostics = engine.diagnostics(at: 2.175)
        XCTAssertEqual(diagnostics.swallowedInputs, 1, "One blocked drag is one swallowed touch")
        engine.endSteering()
        engine.steer(screenHeading: 0.2, now: 2.2)
        XCTAssertEqual(engine.diagnostics(at: 2.2).swallowedInputs, 2, "A new blocked gesture counts again")
        XCTAssertEqual(diagnostics.controlLosses.stale, 1)
        XCTAssertEqual(diagnostics.controlLosses.total, 1)
        XCTAssertEqual(diagnostics.resyncRequests, 1)
    }

    func testPongsGiveRoundTripPercentiles() throws {
        let (engine, socket) = try connectedLobby()
        XCTAssertNil(engine.diagnostics(at: 1).roundTrip)
        for (pingAt, pongAt) in [(2.6, 2.7), (6.0, 6.2)] {
            _ = engine.drainEffects()
            engine.tick(now: pingAt)
            let ping = try XCTUnwrap(sent(engine).first { $0["type"] as? String == "realtime.ping" })
            let pingID = try XCTUnwrap((ping["payload"] as? [String: Any])?["pingId"] as? String)
            try receive(engine, socket, server("pong") { message in
                message["payload"] = ["pingId": pingID, "serverTime": "2026-10-03T12:00:33.125Z"]
            }, at: pongAt)
        }
        let spread = try XCTUnwrap(engine.diagnostics(at: 7).roundTrip)
        XCTAssertEqual(spread, GameDiagnosticsSpread(p50: 100, p95: 200, max: 200))
        XCTAssertEqual(engine.diagnostics(at: 7).lines.first, "RTT 100/200 ms (p50/p95)")
    }

    // MARK: Smooth flight

    /// A straight flight at each snapshot rate with ±40 ms arrival jitter and a 300 ms network
    /// stall (everything held back arrives together, a burst), drawn at 60 Hz.
    func testDisplayAndLocalRocketNeverGoBackwardsThroughJitterStallAndBurst() throws {
        for rate in [20.0, 30.0, 60.0] {
            ids = 0
            let (engine, socket) = try flying(snapshotRate: Int(rate))
            let stallStart = 1.5, stallEnd = 1.8
            let jitter: [TimeInterval] = [0.04, -0.04, 0.03, -0.03, 0, 0.04, -0.04, 0.02, -0.02, 0.04, -0.04, 0.01]
            var arrivals: [(index: Int, time: TimeInterval)] = []
            var previous = 1.0
            for index in 1...Int(rate * 1.5) {
                let nominal = 1 + Double(index) / rate
                let held = nominal >= stallStart && nominal < stallEnd
                let time = max(previous + 0.0005, held ? stallEnd : nominal + jitter[index % jitter.count])
                arrivals.append((index, time))
                previous = time
            }
            var lastElapsed = -Double.infinity
            var lastX = -Double.infinity
            var frameTime = 1.02
            func draw(until end: TimeInterval) throws {
                while frameTime < end {
                    let presentation = try XCTUnwrap(engine.presentation(at: frameTime))
                    let local = try XCTUnwrap(presentation.frame.players.first { $0.id == playerID })
                    XCTAssertGreaterThanOrEqual(presentation.frame.elapsedTime, lastElapsed, "elapsed at \(frameTime), \(rate) Hz")
                    XCTAssertGreaterThanOrEqual(local.worldX, lastX - 1e-9, "local x at \(frameTime), \(rate) Hz")
                    XCTAssertFalse(presentation.isSyncing, "a 300 ms stall is not a sync at \(frameTime), \(rate) Hz")
                    XCTAssertTrue(presentation.canSteer, "control at \(frameTime), \(rate) Hz")
                    lastElapsed = presentation.frame.elapsedTime
                    lastX = local.worldX
                    engine.tick(now: frameTime)
                    frameTime += 1.0 / 60
                }
            }
            for arrival in arrivals {
                try draw(until: arrival.time)
                try receive(engine, socket, steadySnapshot(index: arrival.index, rate: rate), at: arrival.time)
            }
            try draw(until: previous + 0.2)
            let diagnostics = engine.diagnostics(at: frameTime)
            XCTAssertEqual(diagnostics.backwardDisplaySteps, 0, "\(rate) Hz")
            XCTAssertEqual(diagnostics.resyncRequests, 0, "\(rate) Hz")
            XCTAssertEqual(diagnostics.controlLosses.total, 0, "\(rate) Hz")
            XCTAssertEqual(diagnostics.remoteTeleports, 0, "\(rate) Hz")
        }
    }

    func testAShortGapKeepsControlAndInputsAndALongOneDropsThemOnce() throws {
        let (engine, _) = try flying()
        _ = engine.drainEffects()
        engine.steer(screenHeading: 0.4, now: 1.02)
        var steers = try sent(engine).filter { $0["type"] as? String == "houseRockets.steer" }
        XCTAssertEqual(steers.count, 1)
        for step in 1...11 {
            engine.tick(now: 1.02 + Double(step) * 0.025)
            steers += try sent(engine).filter { $0["type"] as? String == "houseRockets.steer" }
        }
        XCTAssertGreaterThan(steers.count, 1, "The unacknowledged input is still retransmitted after 300 ms")
        XCTAssertTrue(try XCTUnwrap(engine.presentation(at: 1.3)).canSteer)
        XCTAssertEqual(engine.diagnostics(at: 1.3).resyncRequests, 0)
        XCTAssertEqual(engine.diagnostics(at: 1.3).controlLosses.total, 0)

        for now in [2.1, 2.125, 2.2, 2.5] { engine.tick(now: now) }
        let diagnostics = engine.diagnostics(at: 2.5)
        XCTAssertEqual(diagnostics.controlLosses.stale, 1)
        XCTAssertEqual(diagnostics.resyncRequests, 1, "Asked once")
        XCTAssertFalse(try XCTUnwrap(engine.presentation(at: 2.5)).canSteer)
    }

    func testALocalCorrectionEasesAndATeleportSnaps() throws {
        for (shift, snaps) in [(120.0, false), (250.0, true)] {
            ids = 0
            let (engine, socket) = try flying()
            let arrival = 1 + 1.0 / 30
            let before = try XCTUnwrap(localX(engine, at: arrival))
            try receive(engine, socket, steadySnapshot(index: 1, rate: 30, shift: shift), at: arrival)
            let after = try XCTUnwrap(localX(engine, at: arrival))
            if snaps {
                XCTAssertEqual(after - before, shift, accuracy: 1, "Beyond the limit it snaps")
                XCTAssertEqual(engine.diagnostics(at: arrival).localSnaps, 1)
            } else {
                XCTAssertEqual(after - before, 0, accuracy: 1, "Within the limit the display stays where it was")
                XCTAssertEqual(engine.diagnostics(at: arrival).localSnaps, 0)
                for wait in [0.15, 0.4] {
                    let offset = try XCTUnwrap(localX(engine, at: arrival + wait))
                        - (before + HouseRocketsSimulation.speed * wait)
                    XCTAssertEqual(offset, shift * (1 - exp(-wait / 0.15)), accuracy: 3, "Eases toward the server's line")
                }
            }
        }
    }

    func testALocalCorrectionAgainstTheFlightNeverDragsTheRocketBackwards() throws {
        let (engine, socket) = try flying(snapshotRate: 30)
        let arrival = 1 + 1.0 / 30
        let start = try XCTUnwrap(localX(engine, at: arrival))
        try receive(engine, socket, steadySnapshot(index: 1, rate: 30, shift: -120), at: arrival)
        var last = try XCTUnwrap(localX(engine, at: arrival))
        XCTAssertEqual(last, start, accuracy: 1, "Eased, not snapped")
        var now = arrival
        while now < arrival + 0.4 {
            now += 1.0 / 60
            let current = try XCTUnwrap(localX(engine, at: now))
            XCTAssertGreaterThanOrEqual(current, last - 1e-9, "x moved backwards at \(now)")
            last = current
        }
        XCTAssertGreaterThan(last, start + 10, "It keeps flying forward while the offset shrinks")
    }

    func testARemoteRocketExtrapolatedPastTheNewestSnapshotEasesToTheNextOne() throws {
        let eased = try stalledRemote(reduceMotion: false, remoteShift: 100)
        let raw = try stalledRemote(reduceMotion: true, remoteShift: 100)
        let jump = raw.after - raw.before
        XCTAssertGreaterThan(jump, 50, "The snapshot does move the rocket")
        XCTAssertLessThan(jump, 180)
        XCTAssertEqual(eased.after, eased.before, accuracy: 1, "No jump")
        var residual = abs(eased.after - raw.after)
        XCTAssertEqual(residual, jump, accuracy: 1)
        for step in 1...24 {
            let now = eased.arrival + Double(step) / 60
            let left = abs(try XCTUnwrap(x(of: otherID, eased.engine, at: now)) - (try XCTUnwrap(x(of: otherID, raw.engine, at: now))))
            XCTAssertLessThanOrEqual(left, residual + 1e-9, "The offset only shrinks, at step \(step)")
            residual = left
            if step == 9 { XCTAssertEqual(left, jump * exp(-1), accuracy: 2, "One time constant, applied once") }
        }
    }

    func testARemoteTeleportSnapsAndTheEasingDiesWithTheTimeline() throws {
        let snapped = try stalledRemote(reduceMotion: false, remoteShift: 300)
        let raw = try stalledRemote(reduceMotion: true, remoteShift: 300)
        XCTAssertEqual(snapped.after, raw.after, accuracy: 1e-9, "Beyond the limit it is drawn where it is")

        let easing = try stalledRemote(reduceMotion: false, remoteShift: 100)
        let at = easing.arrival + 0.05
        try receive(easing.engine, easing.socket, settingEpoch(steadySnapshot(index: 12, rate: 30), to: 8), at: at)
        XCTAssertEqual(try XCTUnwrap(x(of: otherID, easing.engine, at: at)),
                       250 + HouseRocketsSimulation.speed * (0.125 + 12.0 / 30), accuracy: 1e-9,
                       "A new epoch starts without the old offset")
    }

    func testARemoteRocketThatDiesStaysWhereTheServerLeftIt() throws {
        let run = try stalledRemote(reduceMotion: false, remoteShift: 100, dies: true)
        XCTAssertEqual(run.after, 600, accuracy: 1e-9)
        XCTAssertEqual(try XCTUnwrap(x(of: otherID, run.engine, at: run.arrival + 0.1)), 600, accuracy: 1e-9)
    }

    func testASnapshotBetweenAHalfAndAFullSecondOldStopsSteeringButKeepsControl() throws {
        let (engine, socket) = try flying()
        _ = engine.drainEffects()
        engine.steer(screenHeading: 0.4, now: 1.03)
        XCTAssertTrue(try XCTUnwrap(engine.presentation(at: 1.35)).canSteer, "Inside the 0.4 s freshness")
        XCTAssertFalse(try XCTUnwrap(engine.presentation(at: 1.6)).canSteer)
        let swallowed = engine.diagnostics(at: 1.6).swallowedInputs
        engine.steer(screenHeading: 0.9, now: 1.6)
        XCTAssertEqual(engine.diagnostics(at: 1.6).swallowedInputs, swallowed + 1, "The touch is counted as swallowed")
        for now in [1.6, 1.8, 1.99] { engine.tick(now: now) }
        let diagnostics = engine.diagnostics(at: 1.99)
        XCTAssertEqual(diagnostics.controlLosses.total, 0)
        XCTAssertEqual(diagnostics.resyncRequests, 0)
        try receive(engine, socket, steadySnapshot(index: 24, rate: 30), at: 1.995)
        XCTAssertTrue(try XCTUnwrap(engine.presentation(at: 2.0)).canSteer, "Control was kept")
    }

    func testTheFirstChangeAfterIdlingIsSentAtOnceAndLaterOnesKeepTheRate() throws {
        let (engine, _) = try flying()
        _ = engine.drainEffects()
        func steers() throws -> Int {
            try sent(engine).filter { $0["type"] as? String == "houseRockets.steer" }.count
        }
        engine.steer(screenHeading: 0.4, now: 1.03)
        XCTAssertEqual(try steers(), 1, "Sent by the steer call itself")
        engine.steer(screenHeading: 0.9, now: 1.04)
        XCTAssertEqual(try steers(), 0, "The rate gate is closed")
        engine.tick(now: 1.06)
        XCTAssertEqual(try steers(), 0)
        engine.tick(now: 1.09)
        XCTAssertEqual(try steers(), 1, "Left to the host tick, with the newest heading")
        engine.steer(screenHeading: 1.4, now: 1.2)
        XCTAssertEqual(try steers(), 1, "Idle for a while: immediate again")
    }

    func testTheInterpolationDelayFollowsTheSnapshotRate() throws {
        func lag(rate: Double) throws -> Double {
            ids = 0
            let (engine, socket) = try flying(snapshotRate: Int(rate))
            var last = 1.0
            for index in 1...Int(rate) {
                last = 1 + Double(index) / rate
                try receive(engine, socket, steadySnapshot(index: index, rate: rate), at: last)
            }
            let frame = try XCTUnwrap(engine.presentation(at: last)).frame
            return (last - 1) + 0.125 - frame.elapsedTime
        }
        XCTAssertEqual(try lag(rate: 60), 0.06, accuracy: 0.005, "At 60 Hz the floor")
        XCTAssertEqual(try lag(rate: 30), 2.0 / 30, accuracy: 0.005, "Two intervals without jitter")
        XCTAssertEqual(try lag(rate: 20), 0.1, accuracy: 0.005, "Two intervals")
    }

    // MARK: Helpers

    private func flying(snapshotRate: Int? = nil) throws -> (engine: HouseRocketsOnlineEngine, socket: Int) {
        let (engine, socket) = try connectedLobby(state: "running", snapshotRate: snapshotRate)
        try receive(engine, socket, server("playing"), at: 1)
        try receive(engine, socket, server("controlGranted"), at: 1.01)
        return (engine, socket)
    }

    /// Snapshot `index` of a straight flight at `rate` Hz: every rocket on the same line,
    /// the local one optionally off it by `shift`.
    private func steadySnapshot(index: Int, rate: Double, shift: Double = 0, remoteShift: Double = 0,
                                others: (inout [[String: Any]]) -> Void = { _ in }) throws -> Data {
        let elapsed = 0.125 + Double(index) / rate
        return try playing(sequence: 3 + index, tick: 15 + Int((Double(index) * 120 / rate).rounded()),
                           elapsed: elapsed) { players in
            for offset in players.indices {
                players[offset]["worldX"] = 250 + HouseRocketsSimulation.speed * elapsed
                    + (offset == 0 ? shift : (offset == 1 ? remoteShift : 0))
            }
            others(&players)
        }
    }

    private func x(of id: String, _ engine: HouseRocketsOnlineEngine, at now: TimeInterval) -> Double? {
        engine.presentation(at: now)?.frame.players.first { $0.id == id }?.worldX
    }

    /// A 300 ms silence (the other rockets are extrapolated), then the snapshot that is on
    /// the server's line for everyone except the second rocket, moved by `remoteShift`.
    /// Returns how it was drawn just before and just after that snapshot arrived.
    private func stalledRemote(reduceMotion: Bool, remoteShift: Double, dies: Bool = false)
        throws -> (engine: HouseRocketsOnlineEngine, socket: Int, arrival: TimeInterval, before: Double, after: Double) {
        ids = 0
        let (engine, socket) = try flying(snapshotRate: 30)
        engine.setReduceMotion(reduceMotion)
        let arrival = 1 + 10.0 / 30
        var frame = 1.02
        while frame < arrival - 0.001 { _ = engine.presentation(at: frame); frame += 1.0 / 60 }
        let before = try XCTUnwrap(x(of: otherID, engine, at: arrival))
        try receive(engine, socket, steadySnapshot(index: 10, rate: 30, remoteShift: remoteShift) { players in
            if dies {
                players[1]["worldX"] = 600.0
                players[1]["isAlive"] = false
                players[1]["eliminatedAtTick"] = 55
                players[1]["eliminationReason"] = "behindCamera"
            }
        }, at: arrival)
        return (engine, socket, arrival, before, try XCTUnwrap(x(of: otherID, engine, at: arrival)))
    }

    private func settingEpoch(_ data: Data, to epoch: Int) throws -> Data {
        var message = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        var payload = try XCTUnwrap(message["payload"] as? [String: Any])
        payload["runtimeEpoch"] = epoch
        message["payload"] = payload
        return try JSONSerialization.data(withJSONObject: message)
    }

    private func localX(_ engine: HouseRocketsOnlineEngine, at now: TimeInterval) -> Double? {
        engine.presentation(at: now)?.frame.players.first { $0.id == playerID }?.worldX
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

    /// A 30 Hz stream whose arrivals jitter ±40 ms, drawn at 60 Hz; optionally read like the overlay does.
    private func jitteredFlight(readingDiagnostics: Bool) throws
        -> (frames: [HouseRocketsOnlinePresentation?], diagnostics: GameOnlineDiagnostics) {
        ids = 0
        let (engine, socket) = try flying()
        let jitter: [TimeInterval] = [0.04, -0.04, 0.03, -0.03, 0, 0.04, -0.04, 0.02, -0.02, 0.04, -0.04, 0.01]
        var frames: [HouseRocketsOnlinePresentation?] = []
        var frameTime = 1.02
        var lastArrival = 1.0
        for index in 1...30 {
            let arrival = max(lastArrival + 0.001, 1 + Double(index) / 30 + jitter[index % jitter.count])
            while frameTime < arrival {
                frames.append(engine.presentation(at: frameTime))
                if readingDiagnostics { _ = engine.diagnostics(at: frameTime) }
                frameTime += 1.0 / 60
            }
            try receive(engine, socket, playing(sequence: 3 + index, tick: 15 + 4 * index,
                                                elapsed: 0.125 + Double(index) / 30), at: arrival)
            lastArrival = arrival
        }
        return (frames, engine.diagnostics(at: frameTime))
    }

    // MARK: Rocket colors

    /// The color claim matches the backend's fixture message byte for byte, and the
    /// fixture's claimed-colors snapshot reads back as the lobby's colors.
    func testColorClaimMatchesTheBackendFixture() throws {
        let encoded = try GameRealtimeCodec.encode(GameRealtimeClientMessageOf<HouseRocketsRealtime>(
            messageId: "color1", action: .gameplay(.selectColor(.teal))))
        let expected = try XCTUnwrap((Self.fixture["clientMessages"] as? [[String: Any]])?
            .first { $0["name"] as? String == "selectColor" }?["message"] as? NSDictionary)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: encoded) as? NSDictionary, expected)

        // The fixture's room is counting down; here it is still the lobby, one version on.
        let (engine, socket) = try connectedLobby()
        try receive(engine, socket, server("claimedColorsSessionSnapshot") { message in
            var payload = message["payload"] as! [String: Any]
            payload["version"] = 50
            payload["state"] = "lobby"
            message["payload"] = payload
        }, at: 1)
        XCTAssertEqual(engine.lobbyColors.claims["507f1f77bcf86cd799439021"], .teal)
        XCTAssertEqual(engine.lobbyColors.claims["507f1f77bcf86cd799439022"], .mint)
    }

    func testLobbySendsThePreferredColorAfterJoining() throws {
        let (engine, socket) = try connectedLobby(color: .teal)
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting"), at: 1)
        let claim = try XCTUnwrap(sent(engine).first)
        XCTAssertEqual(claim["type"] as? String, "houseRockets.selectColor")
        XCTAssertNil(claim["controlGeneration"])
        XCTAssertEqual((claim["payload"] as? [String: Any])?["color"] as? String, "teal")

        // The same pick is not repeated; a new pick is sent.
        try receive(engine, socket, session(version: 8, state: "lobby", localState: "waiting"), at: 1.1)
        XCTAssertEqual(try claims(engine), [])
        engine.selectColor(.violet, now: 1.2)
        XCTAssertEqual(try claims(engine), ["violet"])
    }

    /// Play Again: the color goes first, then ready, once the player sits in the new room;
    /// a later room change does not ask again.
    func testPlayAgainReadiesOnceSeatedAfterTheColor() throws {
        let (engine, socket) = try connectedLobby(color: .teal)
        engine.readyOnJoin(now: 0.9)
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting"), at: 1)
        XCTAssertEqual(try sent(engine).map { $0["type"] as? String }, ["houseRockets.selectColor"],
                       "Ready waits until the server holds the color")
        try receive(engine, socket, session(version: 8, state: "lobby", localState: "waiting", colors: [playerID: "teal"]), at: 1.05)
        XCTAssertEqual(try sent(engine).map { $0["type"] as? String }, ["gameSession.setReady"])

        try receive(engine, socket, session(version: 9, state: "lobby", localState: "ready", colors: [playerID: "teal"]), at: 1.1)
        try receive(engine, socket, session(version: 10, state: "lobby", localState: "waiting", colors: [playerID: "teal"]), at: 1.2)
        XCTAssertFalse(try sent(engine).contains { $0["type"] as? String == "gameSession.setReady" },
                       "Taking ready back afterwards stays the player's choice")
    }

    /// A server without lobby colors rejects the claim; the room goes on with seat colors.
    func testRejectedColorClaimKeepsTheRoom() throws {
        let (engine, socket) = try connectedLobby(color: .teal)
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting"), at: 1)
        let id = try XCTUnwrap(sent(engine).first?["messageId"] as? String)
        try receive(engine, socket, rejection(id: id, code: "game.error.invalid_command"), at: 1.1)
        XCTAssertNil(engine.lobby.issue)
        XCTAssertEqual(engine.lobby.connection, .connected)
        XCTAssertFalse(engine.isClosed)
        try receive(engine, socket, session(version: 8, state: "lobby", localState: "waiting"), at: 1.2)
        XCTAssertEqual(try claims(engine), [], "Not resent on the same connection")
        XCTAssertEqual(engine.lobbyColors.localColor(preferred: engine.preferredColor), .teal)
    }

    func testColorHeldByAnotherPlayerIsAskedForOnceItIsFree() throws {
        let (engine, socket) = try connectedLobby(color: .coral)
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting", colors: [otherID: "coral"]), at: 1)
        XCTAssertEqual(try claims(engine), [], "Coral is held: the claim would change nothing")
        XCTAssertTrue(engine.lobbyColors.isPreferredTaken(engine.preferredColor))
        XCTAssertNil(engine.lobbyColors.localColor(preferred: engine.preferredColor))
        XCTAssertEqual(engine.lobby.memberColor(of: otherID, localPlayerID: playerID, preferred: engine.preferredColor), .coral)

        try receive(engine, socket, session(version: 8, state: "lobby", localState: "waiting", colors: [otherID: "coral"],
                                            otherState: "left"), at: 1.1)
        XCTAssertEqual(try claims(engine), ["coral"])

        // Once the server shows the claim, it is not sent again.
        try receive(engine, socket, session(version: 9, state: "lobby", localState: "waiting", colors: [playerID: "coral"]), at: 1.2)
        engine.selectColor(.coral, now: 1.3)
        XCTAssertEqual(try claims(engine), [])
        XCTAssertEqual(engine.lobbyColors.localClaim, .coral)
    }

    func testReadyLocksTheColorUntilTheReadyIsTakenBack() throws {
        let (engine, socket) = try connectedLobby(color: .coral)
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "ready",
                                            colors: [otherID: "coral", playerID: "blue"]), at: 1)
        XCTAssertTrue(engine.lobbyColors.isLocked)
        XCTAssertEqual(try claims(engine), [])

        // A pick while ready changes nothing, and the freed color is not claimed either.
        engine.selectColor(.violet, now: 1.1)
        XCTAssertEqual(engine.preferredColor, .coral)
        try receive(engine, socket, session(version: 8, state: "lobby", localState: "ready",
                                            colors: [otherID: "coral", playerID: "blue"], otherState: "left"), at: 1.2)
        XCTAssertEqual(try claims(engine), [])

        // Not ready again: the wished color is asked for, and picks go through.
        try receive(engine, socket, session(version: 9, state: "lobby", localState: "waiting",
                                            colors: [otherID: "coral", playerID: "blue"], otherState: "left"), at: 1.3)
        XCTAssertFalse(engine.lobbyColors.isLocked)
        XCTAssertEqual(try claims(engine), ["coral"])
        engine.selectColor(.violet, now: 1.4)
        XCTAssertEqual(try claims(engine), ["violet"])
    }

    func testNoColorIsAskedForWithoutAPick() throws {
        let (engine, socket) = try connectedLobby()
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting"), at: 1)
        XCTAssertEqual(try claims(engine), [])
        XCTAssertNil(engine.lobbyColors.localColor(preferred: engine.preferredColor))
    }

    func testSeatedRocketsShowTheServerColor() throws {
        let (engine, socket) = try connectedLobby(state: "running", color: .teal)
        try receive(engine, socket, server("playing"), at: 1)
        let seated = try XCTUnwrap(engine.lobby.game?.players.first { $0.playerId == playerID })
        XCTAssertEqual(engine.lobby.memberColor(of: playerID, localPlayerID: playerID, preferred: .teal), seated.color)
    }

    // MARK: Helpers

    private var otherID: String { "507f1f77bcf86cd799439022" }

    /// The colors claimed since the last drain (other room messages are left out).
    private func claims(_ engine: HouseRocketsOnlineEngine) throws -> [String] {
        try sent(engine).filter { $0["type"] as? String == "houseRockets.selectColor" }
            .compactMap { ($0["payload"] as? [String: Any])?["color"] as? String }
    }

    private func rejection(id: String, code: String) throws -> Data {
        let message: [String: Any] = [
            "protocolVersion": 2, "type": "gameSession.commandRejected", "sentAt": "2026-10-03T12:00:50.125Z",
            "messageId": id, "error": ["code": code, "args": [String](), "retryable": false],
        ]
        return try JSONSerialization.data(withJSONObject: message)
    }

    private func makeEngine(color: HouseRocketsColor? = nil) -> HouseRocketsOnlineEngine {
        HouseRocketsOnlineEngine(
            context: HouseRocketsLaunchContext(houseID: houseID, localPlayerID: playerID, houseOwnerID: playerID),
            preferredColor: color,
            policy: HouseRocketsReconnectPolicy(jitter: { 0.8 }),
            makeID: { [unowned self] in ids += 1; return "id\(ids)" }
        )
    }

    private func connectedLobby(state: String = "lobby", color: HouseRocketsColor? = nil, snapshotRate: Int? = nil) throws
        -> (engine: HouseRocketsOnlineEngine, socket: Int) {
        let engine = makeEngine(color: color)
        engine.start(isForeground: true, isLandscape: true, now: 0)
        let connection = try ensureConnection(engine)
        engine.sessionResponse(try http("ensure", state: state), retryAfter: nil, connection: connection, now: 0.1)
        guard case .openSocket(let id, let socket) = try XCTUnwrap(engine.drainEffects().last) else {
            XCTFail("No socket opened")
            throw UnexpectedTestState()
        }
        XCTAssertEqual(id, sessionID)
        engine.socketOpened(connection: socket, now: 0.2)
        try receive(engine, socket, server("welcome") { message in
            guard let snapshotRate, var payload = message["payload"] as? [String: Any],
                  var settings = payload["settings"] as? [String: Any] else { return }
            settings["snapshotRateHz"] = snapshotRate
            payload["settings"] = settings
            message["payload"] = payload
        }, at: 0.3)
        let localState: String? = state == "lobby" ? nil : "playing"
        try receive(engine, socket, session(version: 6, state: state, localState: localState), at: 0.4)
        return (engine, socket)
    }

    private func ensureConnection(_ engine: HouseRocketsOnlineEngine) throws -> Int {
        guard case .ensureSession(let house, let connection) = try XCTUnwrap(engine.drainEffects().first) else {
            XCTFail("No ensure effect")
            throw UnexpectedTestState()
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
                         colors: [String: String]? = nil, otherState: String? = nil,
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
            if let otherState, let index = players.firstIndex(where: { $0["playerId"] as? String == self.otherID }) {
                players[index]["state"] = otherState
                if otherState == "left" { players[index]["leftAt"] = "2026-10-03T12:00:20Z" }
            }
            payload["players"] = players
            if let colors { payload["lobbyState"] = ["colors": colors] }
            if state == "lobby" { payload["countdownEndsAt"] = NSNull() }
            if state == "finished" || state == "cancelled" { payload["endedAt"] = "2026-10-03T12:00:40Z" }
            if state == "cancelled" { payload["startedAt"] = NSNull(); payload["endReason"] = "cancelledByUser" }
            message["payload"] = payload
        }
    }
}
