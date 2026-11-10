import Foundation
import FausCrewCore
import XCTest

/// The sans-IO online engine against `Fixtures/fausSwitchProtocol.json` (the backend contract).
final class FausSwitchOnlineEngineTests: XCTestCase {
    private let houseID = "507f1f77bcf86cd799439012"
    private let playerID = "507f1f77bcf86cd799439021"
    private let other = "507f1f77bcf86cd799439022"
    private let sessionID = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"
    private var ids = 0

    func testFixtureMessagesDecodeAndEncode() throws {
        let welcome = try GameRealtimeCodec.decode(try server("welcome"), as: FausSwitchRealtime.self)
        guard case .welcome(let payload) = welcome.payload else { return XCTFail("welcome") }
        XCTAssertEqual(payload.settings, FausSwitchRuntimeSettingsDTO.releaseDefaults)

        let playing = try GameRealtimeCodec.decode(try server("playing"), as: FausSwitchRealtime.self)
        guard case .snapshot(let snapshot) = playing.payload else { return XCTFail("snapshot") }
        XCTAssertEqual(snapshot.runners.map(\.color), [.ocean, .plum])
        XCTAssertEqual(snapshot.runnerScale, 1)
        XCTAssertEqual(snapshot.runnerStates.first, FausSwitchRunnerState(x: 605, y: 44.1, gravity: .down))

        // Eight robots start smaller, each on its own platform (course 7).
        let crowded = try GameRealtimeCodec.decode(try server("crowdedCountdown"), as: FausSwitchRealtime.self)
        guard case .snapshot(let start) = crowded.payload else { return XCTFail("crowded snapshot") }
        XCTAssertEqual(start.runnerScale, FausSwitchStartGrid.runnerScale(runnerCount: 8))
        XCTAssertEqual(start.runnerStates, FausSwitchStartGrid.lanes(count: 8, runnerScale: 0.75).map(\.spawn))
        XCTAssertEqual(Set(start.runners.map(\.color)).count, 8)

        let result = try GameRealtimeCodec.decode(try server("result"), as: FausSwitchRealtime.self)
        guard case .result(let final) = result.payload else { return XCTFail("result") }
        XCTAssertNoThrow(try final.validate(sessionID: sessionID, houseID: houseID))

        for (name, intent) in [("flip", FausSwitchRealtime.Intent.flip(controlGeneration: "controlA", inputSequence: 1, clientTick: 118)),
                               ("selectColor", .selectColor(.ocean))] {
            let encoded = try GameRealtimeCodec.encode(FausSwitchClientMessage(messageId: name == "flip" ? "flip1" : "color1",
                                                                                action: .gameplay(intent)))
            let expected = try XCTUnwrap((Self.fixture["clientMessages"] as? [[String: Any]])?
                .first { $0["name"] as? String == name }?["message"] as? NSDictionary)
            XCTAssertEqual(try JSONSerialization.jsonObject(with: encoded) as? NSDictionary, expected, name)
        }
    }

    func testOtherCourseVersionsAskForAnUpdate() throws {
        let data = try server("playing") { message in
            var payload = message["payload"] as! [String: Any]
            payload["courseVersion"] = 6
            message["payload"] = payload
        }
        XCTAssertThrowsError(try GameRealtimeCodec.decode(data, as: FausSwitchRealtime.self)) { error in
            XCTAssertEqual(error as? GameRealtimeError, .unsupportedCourse(6))
        }
    }

    func testSnapshotNeedsAKnownRobotSize() throws {
        for scale: Any in [0.5, NSNull()] {
            let data = try server("playing") { message in
                var payload = message["payload"] as! [String: Any]
                payload["runnerScale"] = scale
                message["payload"] = payload
            }
            XCTAssertThrowsError(try GameRealtimeCodec.decode(data, as: FausSwitchRealtime.self), "\(scale)")
        }
    }

    /// Never ready without a robot color the server holds: a pick another player has stays
    /// unready until a free color is claimed; taking ready back is always allowed.
    func testReadyWaitsForTheColorClaim() throws {
        let (engine, socket) = try connectedLobby(color: .ocean)
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting",
                                            colors: [other: "ocean"]), at: 1)
        XCTAssertFalse(engine.canChangeReady)
        engine.setReady(true, now: 1.01)
        XCTAssertFalse(try sent(engine).contains { $0["type"] as? String == "gameSession.setReady" })

        engine.selectColor(.plum, now: 1.02)
        try receive(engine, socket, session(version: 8, state: "lobby", localState: "waiting",
                                            colors: [other: "ocean", playerID: "plum"]), at: 1.1)
        XCTAssertTrue(engine.canChangeReady)
        engine.setReady(true, now: 1.11)
        XCTAssertEqual(try sent(engine).map { $0["type"] as? String }.last, "gameSession.setReady")
    }

    /// Play Again: the color goes first, then ready, once the player sits in the new room;
    /// a later room change does not ask again.
    func testPlayAgainReadiesOnceSeatedAfterTheColor() throws {
        let (engine, socket) = try connectedLobby(color: .ocean)
        engine.readyOnJoin(now: 0.9)
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting"), at: 1)
        XCTAssertEqual(try sent(engine).map { $0["type"] as? String }, ["fausSwitch.selectColor"],
                       "Ready waits until the server holds the color")
        try receive(engine, socket, session(version: 8, state: "lobby", localState: "waiting",
                                            colors: [playerID: "ocean"]), at: 1.05)
        XCTAssertEqual(try sent(engine).map { $0["type"] as? String }, ["gameSession.setReady"])

        try receive(engine, socket, session(version: 9, state: "lobby", localState: "ready",
                                            colors: [playerID: "ocean"]), at: 1.1)
        try receive(engine, socket, session(version: 10, state: "lobby", localState: "waiting",
                                            colors: [playerID: "ocean"]), at: 1.2)
        XCTAssertFalse(try sent(engine).contains { $0["type"] as? String == "gameSession.setReady" },
                       "Taking ready back afterwards stays the player's choice")
    }

    func testLobbySendsThePreferredColorAfterJoining() throws {
        let (engine, socket) = try connectedLobby(color: .ocean)
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting"), at: 1)
        let color = try XCTUnwrap(sent(engine).first)
        XCTAssertEqual(color["type"] as? String, "fausSwitch.selectColor")
        XCTAssertEqual((color["payload"] as? [String: Any])?["color"] as? String, "ocean")

        // The same pick is not repeated; a new pick is sent.
        try receive(engine, socket, session(version: 8, state: "lobby", localState: "waiting"), at: 1.1)
        XCTAssertTrue(try sent(engine).isEmpty)
        engine.selectColor(.berry, now: 1.2)
        XCTAssertEqual((try sent(engine).first?["payload"] as? [String: Any])?["color"] as? String, "berry")
    }

    func testSessionSnapshotCarriesTheLobbyColors() throws {
        let decoded = try GameRealtimeCodec.decode(try server("sessionSnapshot"), as: FausSwitchRealtime.self)
        guard case .session(let session) = decoded.payload else { return XCTFail("session") }
        XCTAssertEqual(session.lobbyState?.colors, [playerID: "ocean", other: "plum"])
        let colors = FausSwitchLobbyColors(session: session, localPlayerID: playerID)
        XCTAssertEqual(colors.localClaim, .ocean)
        XCTAssertEqual(colors.color(of: other), .plum)
        XCTAssertEqual(colors.takenByOthers, [.plum])

        // Malformed lobby state is no pick, never a failed session.
        for broken: Any in ["colors", ["colors": 5], ["colors": [playerID: 3]]] {
            let data = try server("sessionSnapshot") { message in
                var payload = message["payload"] as! [String: Any]
                payload["lobbyState"] = broken
                message["payload"] = payload
            }
            let message = try GameRealtimeCodec.decode(data, as: FausSwitchRealtime.self)
            guard case .session(let lenient) = message.payload else { return XCTFail("lenient session") }
            XCTAssertTrue(FausSwitchLobbyColors(session: lenient, localPlayerID: playerID).claims.isEmpty)
        }
    }

    func testLobbyColorsKeepOnlyPlayersInTheRoom() throws {
        let third = "507f1f77bcf86cd799439023"
        func colors(_ raw: [String: String], left: String? = nil) throws -> FausSwitchLobbyColors {
            let data = try session(version: 7, state: "lobby", localState: "waiting", colors: raw, leftPlayer: left)
            let message = try GameRealtimeCodec.decode(data, as: FausSwitchRealtime.self)
            guard case .session(let session) = message.payload else { throw XCTSkip("session") }
            return FausSwitchLobbyColors(session: session, localPlayerID: playerID)
        }
        // A leaver's claim stays in the field, but its color is free; unknown players and
        // colors are no claim.
        let left = try colors([playerID: "forest", other: "berry", third: "olive"], left: other)
        XCTAssertEqual(left.claims, [playerID: .forest])
        XCTAssertFalse(left.isTakenByOthers(.berry))
        XCTAssertTrue(try colors([playerID: "neon"]).claims.isEmpty)
        // Two claims of one color: the earlier seat (the local player, seated first) keeps it.
        XCTAssertEqual(try colors([playerID: "plum", other: "plum"]).claims, [playerID: .plum])

        // The shown color: the pick while it is free, else the server's claim (or none).
        let held = try colors([playerID: "forest", other: "plum"])
        XCTAssertEqual(held.localColor(preferred: .ocean), .ocean)
        XCTAssertEqual(held.localColor(preferred: .plum), .forest)
        XCTAssertTrue(held.isPreferredTaken(.plum))
        XCTAssertNil(try colors([other: "plum"]).localColor(preferred: .plum))
    }

    func testColorHeldByAnotherPlayerIsAskedForOnceItIsFree() throws {
        let (engine, socket) = try connectedLobby(color: .plum)
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "waiting", colors: [other: "plum"]), at: 1)
        XCTAssertTrue(try sent(engine).isEmpty, "Plum is held: the claim would change nothing")
        XCTAssertNil(engine.lobbyColors.localColor(preferred: engine.preferredColor))

        try receive(engine, socket, session(version: 8, state: "lobby", localState: "waiting", colors: [other: "plum"],
                                            leftPlayer: other), at: 1.1)
        let claim = try XCTUnwrap(sent(engine).first)
        XCTAssertEqual((claim["payload"] as? [String: Any])?["color"] as? String, "plum")

        // Once the server shows the claim, it is not sent again.
        try receive(engine, socket, session(version: 9, state: "lobby", localState: "waiting", colors: [playerID: "plum"],
                                            leftPlayer: other), at: 1.2)
        engine.selectColor(.plum, now: 1.3)
        XCTAssertTrue(try sent(engine).isEmpty)
        XCTAssertEqual(engine.lobbyColors.localClaim, .plum)
    }

    func testReadyLocksTheColorUntilTheReadyIsTakenBack() throws {
        let (engine, socket) = try connectedLobby(color: .plum)
        _ = engine.drainEffects()
        try receive(engine, socket, session(version: 7, state: "lobby", localState: "ready",
                                            colors: [other: "plum", playerID: "ocean"]), at: 1)
        XCTAssertTrue(engine.lobbyColors.isLocked)
        XCTAssertTrue(try sent(engine).isEmpty)

        // A pick while ready changes nothing, and the freed color is not claimed either.
        engine.selectColor(.berry, now: 1.1)
        XCTAssertEqual(engine.preferredColor, .plum)
        try receive(engine, socket, session(version: 8, state: "lobby", localState: "ready",
                                            colors: [other: "plum", playerID: "ocean"], leftPlayer: other), at: 1.2)
        XCTAssertTrue(try sent(engine).isEmpty)

        // Not ready again: the wished color is asked for, and picks go through.
        try receive(engine, socket, session(version: 9, state: "lobby", localState: "waiting",
                                            colors: [other: "plum", playerID: "ocean"], leftPlayer: other), at: 1.3)
        XCTAssertFalse(engine.lobbyColors.isLocked)
        XCTAssertEqual((try sent(engine).first?["payload"] as? [String: Any])?["color"] as? String, "plum")
        engine.selectColor(.berry, now: 1.4)
        XCTAssertEqual((try sent(engine).first?["payload"] as? [String: Any])?["color"] as? String, "berry")
    }

    func testFlipNeedsControlAndCarriesTheTickOnScreen() throws {
        let (engine, socket) = try running()
        XCTAssertEqual(engine.flip(now: 1.02), .ignored, "No grant yet")
        try receive(engine, socket, server("controlGranted"), at: 1.03)
        _ = engine.drainEffects()

        XCTAssertTrue(try XCTUnwrap(engine.presentation(at: 1.05)).canFlip)
        XCTAssertEqual(engine.flip(now: 1.05), .flipped)
        let flip = try XCTUnwrap(sent(engine).first)
        XCTAssertEqual(flip["type"] as? String, "fausSwitch.flip")
        let payload = try XCTUnwrap(flip["payload"] as? [String: Any])
        XCTAssertEqual(payload["controlGeneration"] as? String, "controlA")
        XCTAssertEqual((payload["inputSequence"] as? NSNumber)?.int64Value, 1)
        XCTAssertEqual((payload["clientTick"] as? NSNumber)?.int64Value, 126, "Snapshot tick 120 + 0.05 s at 120 Hz")

        // The flip shows at once on the predicted robot.
        let local = try XCTUnwrap(engine.presentation(at: 1.06)?.frame.localRunner)
        XCTAssertEqual(local.state.gravity, .up)
        XCTAssertEqual(engine.flip(now: 1.07), .unsupported, "Mid-air taps do nothing")
    }

    func testUnconfirmedFlipIsResentThenDroppedWhenAcknowledged() throws {
        let (engine, socket) = try running()
        try receive(engine, socket, server("controlGranted"), at: 1.01)
        _ = engine.drainEffects()
        XCTAssertEqual(engine.flip(now: 1.02), .flipped)
        let first = try XCTUnwrap(sent(engine).first)
        engine.tick(now: 1.3)
        let resent = try XCTUnwrap(sent(engine).first)
        XCTAssertEqual(resent["messageId"] as? String, first["messageId"] as? String, "Same message, same sequence")

        // The server ran it: the snapshot reports sequence 1 with the robot already flipped.
        try receive(engine, socket, playing(sequence: 3, tick: 150) { runners in
            runners[0]["lastProcessedInputSequence"] = 1
            runners[0]["gravity"] = "up"
            runners[0]["y"] = 120
            runners[0]["velocityY"] = 600
            runners[0]["x"] = 661.25
        }, at: 1.31)
        engine.tick(now: 1.7)
        XCTAssertFalse(try sent(engine).contains { $0["type"] as? String == "fausSwitch.flip" })
    }

    func testOtherRobotsRunForwardBetweenSnapshots() throws {
        let (engine, socket) = try running()
        _ = socket
        let start = try XCTUnwrap(engine.presentation(at: 1.0)?.frame)
        let later = try XCTUnwrap(engine.presentation(at: 1.2)?.frame)
        let other = "507f1f77bcf86cd799439022"
        let x0 = try XCTUnwrap(start.runners.first { $0.id == other }?.state.x)
        let x1 = try XCTUnwrap(later.runners.first { $0.id == other }?.state.x)
        XCTAssertEqual(x1 - x0, FausSwitchMetrics.runSpeed * 0.2, accuracy: 2)
        XCTAssertGreaterThan(later.cameraFocus, start.cameraFocus)
        // Never past the extrapolation budget.
        let stalled = try XCTUnwrap(engine.presentation(at: 5)?.frame)
        XCTAssertEqual(stalled.tick, 120 + 42)
        XCTAssertTrue(try XCTUnwrap(engine.presentation(at: 5)).isSyncing)
    }

    /// Snapshots every 50 ms that arrive up to 30 ms late: the tick and the camera on screen
    /// never go back, and stay within a few ticks of the server's pace.
    func testLateSnapshotsNeverMoveTheScreenBack() throws {
        let (engine, socket) = try running()
        let delays: [TimeInterval] = [0, 0.03, 0, 0.012, 0.025, 0, 0.03, 0.005, 0, 0.02, 0, 0.03]
        var lastTick: Int64 = 0
        var lastFocus = -Double.infinity
        var frameTime = 1.0
        for (index, delay) in delays.enumerated() {
            let sent = 1.0 + Double(index + 1) * 0.05
            let arrival = sent + delay
            while frameTime < arrival {
                let frame = try XCTUnwrap(engine.presentation(at: frameTime)?.frame)
                XCTAssertGreaterThanOrEqual(frame.tick, lastTick, "Frame at \(frameTime)")
                XCTAssertGreaterThanOrEqual(frame.cameraFocus, lastFocus)
                let serverTick = 120 + Int64((frameTime - 1) * 120)
                XCTAssertLessThanOrEqual(abs(frame.tick - serverTick), 4, "Frame at \(frameTime)")
                lastTick = frame.tick
                lastFocus = frame.cameraFocus
                frameTime += 1.0 / 60
            }
            try receive(engine, socket, playing(sequence: 3 + index, tick: 120 + 6 * (index + 1)) { _ in }, at: arrival)
        }
        // A stall far past the clock's pace jumps instead of crawling back.
        try receive(engine, socket, playing(sequence: 40, tick: 198) { _ in }, at: 2.2)
        XCTAssertEqual(engine.presentation(at: 2.2)?.frame.tick, 198)
    }

    func testStaleControlRejectionDropsControl() throws {
        let (engine, socket) = try running()
        try receive(engine, socket, server("controlGranted"), at: 1.01)
        ids = 0
        _ = engine.drainEffects()
        XCTAssertEqual(engine.flip(now: 1.02), .flipped)
        let flipID = try XCTUnwrap(sent(engine).first?["messageId"] as? String)
        try receive(engine, socket, server("rejected") { $0["messageId"] = flipID }, at: 1.05)
        XCTAssertFalse(try XCTUnwrap(engine.presentation(at: 1.06)).canFlip)
    }

    /// A stale grant is never bound again, but it is not a takeover either: the next frames
    /// decide, and without a takeover the control wait resyncs (which rebinds).
    func testStaleControlWaitsForTheNextFramesBeforeResyncing() throws {
        let (engine, socket) = try running()
        try receive(engine, socket, server("controlGranted"), at: 1.01)
        _ = engine.drainEffects()
        XCTAssertEqual(engine.flip(now: 1.02), .flipped)
        let flipID = try XCTUnwrap(sent(engine).first?["messageId"] as? String)
        try receive(engine, socket, server("rejected") { $0["messageId"] = flipID }, at: 1.05)
        XCTAssertFalse(engine.lobby.controlTransferred, "Not a takeover by itself")
        XCTAssertEqual(engine.flip(now: 1.06), .ignored)
        try receive(engine, socket, playing(sequence: 3, tick: 126) { _ in }, at: 1.1)
        XCTAssertEqual(engine.flip(now: 1.11), .ignored, "The refused grant stays unbound")
        engine.tick(now: 1.2)
        XCTAssertFalse(try sent(engine).contains { $0["type"] as? String == "fausSwitch.resync" }, "No resync at once")
        engine.tick(now: 1.7)
        XCTAssertTrue(try sent(engine).contains { $0["type"] as? String == "fausSwitch.resync" })
    }

    /// Every (re)bind starts the server's count at 0: the first flip of a new grant is 1.
    func testNewGrantStartsTheFlipSequenceAgain() throws {
        let (engine, socket) = try running()
        try receive(engine, socket, server("controlGranted"), at: 1.01)
        _ = engine.drainEffects()
        XCTAssertEqual(engine.flip(now: 1.02), .flipped)
        try receive(engine, socket, playing(sequence: 3, tick: 140) { runners in
            runners[0]["lastProcessedInputSequence"] = 1
        }, at: 1.2)
        // Rebind (reconnect or owner change): new generation, the server's count is 0 again.
        try receive(engine, socket, server("controlGranted") { message in
            var payload = message["payload"] as! [String: Any]
            payload["controlGeneration"] = "controlB"
            message["payload"] = payload
        }, at: 1.3)
        try receive(engine, socket, playing(sequence: 4, tick: 156) { runners in
            runners[0]["controlGeneration"] = "controlB"
            runners[0]["lastProcessedInputSequence"] = 0
        }, at: 1.31)
        _ = engine.drainEffects()
        XCTAssertEqual(engine.flip(now: 1.32), .flipped)
        let payload = try XCTUnwrap(sent(engine).first { $0["type"] as? String == "fausSwitch.flip" }?["payload"] as? [String: Any])
        XCTAssertEqual(payload["controlGeneration"] as? String, "controlB")
        XCTAssertEqual((payload["inputSequence"] as? NSNumber)?.int64Value, 1)
    }

    /// The owner changed: a new `runtimeEpoch` drops the old grant and its flips; a late
    /// `stale_control` for them is no takeover, and the new grant binds.
    func testOwnerChangeWaitsForTheNewGrant() throws {
        let (engine, socket) = try running()
        try receive(engine, socket, server("controlGranted"), at: 1.01)
        _ = engine.drainEffects()
        XCTAssertEqual(engine.flip(now: 1.02), .flipped)
        let oldFlip = try XCTUnwrap(sent(engine).first?["messageId"] as? String)
        let epoch8: (inout [String: Any]) -> Void = { message in
            var payload = message["payload"] as! [String: Any]
            payload["runtimeEpoch"] = 8
            message["payload"] = payload
        }
        try receive(engine, socket, server("playing") { message in
            epoch8(&message)
            var payload = message["payload"] as! [String: Any]
            var runners = payload["runners"] as! [[String: Any]]
            runners[0]["controlGeneration"] = NSNull()
            payload["runners"] = runners
            payload["stateSequence"] = 1
            message["payload"] = payload
        }, at: 1.2)
        XCTAssertEqual(engine.flip(now: 1.21), .ignored, "The old grant belongs to the old owner")
        try receive(engine, socket, server("rejected") { $0["messageId"] = oldFlip }, at: 1.22)
        XCTAssertFalse(engine.lobby.controlTransferred)
        try receive(engine, socket, server("controlGranted") { message in
            epoch8(&message)
            var payload = message["payload"] as! [String: Any]
            payload["controlGeneration"] = "controlB"
            message["payload"] = payload
        }, at: 1.25)
        try receive(engine, socket, server("playing") { message in
            epoch8(&message)
            var payload = message["payload"] as! [String: Any]
            var runners = payload["runners"] as! [[String: Any]]
            runners[0]["controlGeneration"] = "controlB"
            payload["runners"] = runners
            payload["stateSequence"] = 2
            message["payload"] = payload
        }, at: 1.26)
        _ = engine.drainEffects()
        XCTAssertEqual(engine.flip(now: 1.27), .flipped)
        let payload = try XCTUnwrap(sent(engine).first { $0["type"] as? String == "fausSwitch.flip" }?["payload"] as? [String: Any])
        XCTAssertEqual(payload["controlGeneration"] as? String, "controlB")
        XCTAssertEqual((payload["inputSequence"] as? NSNumber)?.int64Value, 1)
    }

    /// The last robot down is no result yet (a late flip can save it within 250 ms); a
    /// saved robot that crashes again plays no second haptic.
    func testLastRobotDownAwaitsTheResult() throws {
        let (engine, socket) = try running()
        _ = engine.drainEffects()
        func crashed(_ runners: inout [[String: Any]], _ index: Int, at tick: Int) {
            runners[index]["status"] = "crashed"
            runners[index]["eliminatedAtTick"] = tick
            runners[index]["eliminationReason"] = "boundary"
        }
        try receive(engine, socket, playing(sequence: 3, tick: 300) { runners in
            crashed(&runners, 0, at: 290); crashed(&runners, 1, at: 295)
        }, at: 2)
        let pending = try XCTUnwrap(engine.presentation(at: 2.01))
        XCTAssertTrue(pending.isAwaitingResult)
        XCTAssertEqual(FausSwitchOnlineCopyKeys.matchNotice(engine.lobby, pending)?.title, "faus_switch_online_awaiting_result")
        XCTAssertEqual(haptics(engine), [.warning])

        // A late flip saved the local robot: the race goes on.
        try receive(engine, socket, playing(sequence: 4, tick: 310) { runners in crashed(&runners, 1, at: 295) }, at: 2.1)
        XCTAssertFalse(try XCTUnwrap(engine.presentation(at: 2.11)).isAwaitingResult)
        try receive(engine, socket, playing(sequence: 5, tick: 400) { runners in
            crashed(&runners, 0, at: 390); crashed(&runners, 1, at: 295)
        }, at: 3)
        XCTAssertTrue(haptics(engine).isEmpty, "The same outcome plays once")
        try receive(engine, socket, playing(sequence: 6, tick: 500) { runners in
            runners[0]["status"] = "finished"; runners[0]["finishedAtTick"] = 480; crashed(&runners, 1, at: 295)
        }, at: 4)
        XCTAssertEqual(haptics(engine), [.success], "A different outcome still plays")
    }

    /// Only the rewind window can bring a stopped robot back; later it is a broken stream.
    func testStoppedRobotReturnsOnlyInsideTheRewindWindow() throws {
        func snapshot(tick: Int, crashedAt: Int?) throws -> FausSwitchSnapshotDTO {
            let data = try playing(sequence: tick, tick: tick) { runners in
                if let crashedAt {
                    runners[0]["status"] = "crashed"
                    runners[0]["eliminatedAtTick"] = crashedAt
                    runners[0]["eliminationReason"] = "boundary"
                }
            }
            guard case .snapshot(let value) = try GameRealtimeCodec.decode(data, as: FausSwitchRealtime.self).payload else {
                throw XCTSkip("snapshot")
            }
            return value
        }
        let down = try snapshot(tick: 300, crashedAt: 290)
        XCTAssertTrue(FausSwitchRealtime.isValidSuccessor(try snapshot(tick: 306, crashedAt: nil), of: down))
        XCTAssertTrue(FausSwitchRealtime.isValidSuccessor(try snapshot(tick: 290 + 36, crashedAt: nil), of: down))
        XCTAssertFalse(FausSwitchRealtime.isValidSuccessor(try snapshot(tick: 290 + 37, crashedAt: nil), of: down))
        XCTAssertTrue(FausSwitchRealtime.isValidSuccessor(try snapshot(tick: 400, crashedAt: 290), of: down))
    }

    /// A portal throw is an event of the presented frames, like demo's `humanTeleported`;
    /// a snapshot pulling the robot back is not.
    func testPortalThrowIsAFrameEvent() throws {
        let (engine, socket) = try running()
        let portal = try XCTUnwrap(FausSwitchCourse.standard.portals.first)
        XCTAssertEqual(portal.rail, .down)
        try receive(engine, socket, playing(sequence: 3, tick: 900) { runners in
            runners[0]["x"] = portal.x - 40
            runners[1]["x"] = portal.x - 200
        }, at: 2)
        XCTAssertTrue(try XCTUnwrap(engine.presentation(at: 2)).events.isEmpty)
        let thrown = try XCTUnwrap(engine.presentation(at: 2.2))
        XCTAssertEqual(thrown.events, [.humanTeleported])
        XCTAssertEqual(thrown.frame.localRunner?.state.gravity, portal.exitGravity)
        XCTAssertTrue(try XCTUnwrap(engine.presentation(at: 2.21)).events.isEmpty, "Once")

        try receive(engine, socket, playing(sequence: 4, tick: 1200) { runners in runners[0]["x"] = 2600 }, at: 4)
        _ = engine.presentation(at: 4)
        try receive(engine, socket, playing(sequence: 5, tick: 1201) { runners in runners[0]["x"] = 2560 }, at: 4.01)
        XCTAssertTrue(try XCTUnwrap(engine.presentation(at: 4.01)).events.isEmpty, "A correction is no portal")
    }

    func testResultEventIsTheAuthority() throws {
        let (engine, socket) = try running()
        try receive(engine, socket, server("result"), at: 40)
        XCTAssertEqual(engine.result.result?.winnerId, playerID)
        XCTAssertEqual(engine.result.identities[playerID]?.color, .ocean)
    }

    /// A result without a winner is valid for a shared first place or for a lone first who
    /// never finished (time limit), and invalid for a lone first who finished.
    func testResultWithoutWinnerNeedsNoLoneFinisherInFirst() throws {
        func validate(_ change: (inout [String: Any], inout [[String: Any]]) -> Void) throws {
            let data = try server("result") { message in
                var payload = message["payload"] as! [String: Any]
                var players = payload["players"] as! [[String: Any]]
                payload["winnerId"] = NSNull()
                change(&payload, &players)
                payload["players"] = players
                message["payload"] = payload
            }
            let decoded = try GameRealtimeCodec.decode(data, as: FausSwitchRealtime.self)
            guard case .result(let final) = decoded.payload else { return XCTFail("result") }
            try final.validate(sessionID: sessionID, houseID: houseID)
        }
        // Time limit: the leader is first alone but still running, so nobody won.
        XCTAssertNoThrow(try validate { payload, players in
            payload["endReason"] = "timeLimit"
            players[0]["finishedAtTick"] = NSNull()
        })
        // Two robots share first place.
        XCTAssertNoThrow(try validate { _, players in
            players[1]["rank"] = 1
            players[1]["finishedAtTick"] = 4920
            players[1]["eliminatedAtTick"] = NSNull()
            players[1]["eliminationReason"] = NSNull()
        })
        // A lone finisher in first is the winner and must be named.
        XCTAssertThrowsError(try validate { _, _ in })
    }

    func testCatalogOffersFausSwitchOnlyWithItsSettings() throws {
        let body = """
        {"success":true,"data":[{"gameKey":"fausSwitch","protocolVersion":2,"mode":"realtime","configVersion":1,
        "rules":{"minimumPlayers":2,"maximumPlayers":8,"readyWindowMilliseconds":30000,"countdownMilliseconds":3000},
        "settings":\(try String(decoding: JSONSerialization.data(withJSONObject: Self.fixture["settings"]!), as: UTF8.self))}]}
        """
        let catalog = try GameWireContract.decodeCatalog(houseId: houseID, response: HTTPResponse(
            statusCode: 200, headers: [:], body: Data(body.utf8)))
        XCTAssertEqual(catalog.fausSwitch?.fausSwitchSettings, .releaseDefaults)
        XCTAssertNil(catalog.houseRockets)
    }

    // MARK: Helpers

    private func running() throws -> (FausSwitchOnlineEngine, Int) {
        let (engine, socket) = try connectedLobby(state: "running")
        try receive(engine, socket, server("playing"), at: 1)
        return (engine, socket)
    }

    private func playing(sequence: Int, tick: Int, runners mutate: (inout [[String: Any]]) -> Void) throws -> Data {
        try server("playing") { message in
            var payload = message["payload"] as! [String: Any]
            payload["stateSequence"] = sequence
            payload["tick"] = tick
            payload["elapsedSeconds"] = Double(tick) / 120
            var runners = payload["runners"] as! [[String: Any]]
            mutate(&runners)
            payload["runners"] = runners
            message["payload"] = payload
            message["sequence"] = sequence
        }
    }

    private func makeEngine(color: FausSwitchColor? = nil) -> FausSwitchOnlineEngine {
        FausSwitchOnlineEngine(
            context: GameLaunchContext(houseID: houseID, localPlayerID: playerID, houseOwnerID: playerID),
            preferredColor: color, policy: GameReconnectPolicy(jitter: { 0.8 }),
            makeID: { [unowned self] in ids += 1; return "id\(ids)" })
    }

    private func connectedLobby(state: String = "lobby", color: FausSwitchColor? = nil) throws -> (FausSwitchOnlineEngine, Int) {
        let engine = makeEngine(color: color)
        engine.start(isForeground: true, isLandscape: true, now: 0)
        guard case .ensureSession(let house, let connection) = try XCTUnwrap(engine.drainEffects().first) else {
            throw XCTSkip("No ensure effect")
        }
        XCTAssertEqual(house, houseID)
        engine.sessionResponse(try http(state: state), retryAfter: nil, connection: connection, now: 0.1)
        guard case .openSocket(let id, let socket) = try XCTUnwrap(engine.drainEffects().last) else {
            throw XCTSkip("No socket opened")
        }
        XCTAssertEqual(id, sessionID)
        engine.socketOpened(connection: socket, now: 0.2)
        try receive(engine, socket, server("welcome"), at: 0.3)
        try receive(engine, socket, session(version: 6, state: state, localState: state == "lobby" ? nil : "playing"), at: 0.4)
        return (engine, socket)
    }

    private func haptics(_ engine: FausSwitchOnlineEngine) -> [GameOnlineHaptic] {
        engine.drainEffects().compactMap { effect in
            guard case .haptic(let haptic) = effect else { return nil }
            return haptic
        }
    }

    private func receive(_ engine: FausSwitchOnlineEngine, _ socket: Int, _ data: Data, at now: TimeInterval) throws {
        engine.received(text: String(decoding: data, as: UTF8.self), connection: socket, now: now)
    }

    private func sent(_ engine: FausSwitchOnlineEngine) throws -> [[String: Any]] {
        try engine.drainEffects().compactMap { effect in
            guard case .send(let text, _) = effect else { return nil }
            let message = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
            return message["type"] as? String == "realtime.ping" ? nil : message
        }
    }

    private static var fixture: [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Fixtures/fausSwitchProtocol.json")
        return (try? JSONSerialization.jsonObject(with: Data(contentsOf: url))) as? [String: Any] ?? [:]
    }

    private func server(_ name: String, mutate: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        let messages = try XCTUnwrap(Self.fixture["serverMessages"] as? [[String: Any]])
        var message = try XCTUnwrap(messages.first { $0["name"] as? String == name }?["message"] as? [String: Any])
        mutate(&message)
        return try JSONSerialization.data(withJSONObject: message)
    }

    private func http(state: String) throws -> HTTPResponse {
        let http = try XCTUnwrap(Self.fixture["http"] as? [String: [String: Any]])
        var response = try XCTUnwrap(http["ensure"]?["response"] as? [String: Any])
        if var data = response["data"] as? [String: Any] {
            data["state"] = state
            if state == "lobby" { data["players"] = []; data["countdownEndsAt"] = NSNull() }
            response["data"] = data
        }
        return HTTPResponse(statusCode: 200, headers: [:], body: try JSONSerialization.data(withJSONObject: response))
    }

    /// `colors` is the session's `lobbyState.colors`; `nil` leaves the field out.
    private func session(version: Int64, state: String, localState: String?, colors: [String: String]? = nil,
                         leftPlayer: String? = nil) throws -> Data {
        try server("sessionSnapshot") { message in
            var payload = message["payload"] as! [String: Any]
            payload["version"] = version
            payload["state"] = state
            payload["lobbyState"] = colors.map { ["colors": $0] }
            var players = (payload["players"] as! [[String: Any]]).filter { $0["playerId"] as? String != self.playerID }
            if let localState {
                players.insert(["playerId": self.playerID, "state": localState,
                                "joinedAt": "2026-11-05T12:00:00Z", "readyAt": NSNull(), "leftAt": NSNull()], at: 0)
            }
            if let leftPlayer, let index = players.firstIndex(where: { $0["playerId"] as? String == leftPlayer }) {
                players[index]["state"] = "left"
                players[index]["leftAt"] = "2026-11-05T12:00:20Z"
            }
            payload["players"] = players
            if state == "lobby" { payload["countdownEndsAt"] = NSNull() }
            message["payload"] = payload
        }
    }
}
