import Foundation
@testable import FausCrewCore
import XCTest

/// The sans-IO online engine against `Fixtures/fausSwitchProtocol.json` (the backend contract).
final class FausSwitchOnlineEngineTests: XCTestCase {
    private struct UnexpectedTestState: Error {}

    private let houseID = "507f1f77bcf86cd799439012"
    private let playerID = "507f1f77bcf86cd799439021"
    private let other = "507f1f77bcf86cd799439022"
    private let sessionID = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"
    private var ids = 0

    func testSnapshotRejectsUnsafeTicksBeforePrediction() throws {
        for field in ["tick", "boostedUntilTick", "slowedUntilTick", "finishedAtTick", "eliminatedAtTick"] {
            for value in [Int64.min, -1, FausSwitchRealtime.maximumSnapshotTick + 1, Int64.max] {
                let data = try snapshotData(field: field, value: value)
                XCTAssertThrowsError(try GameRealtimeCodec.decode(data, as: FausSwitchRealtime.self), "\(field)=\(value)") {
                    XCTAssertEqual($0 as? GameRealtimeError, .invalidResponse)
                }
            }
        }
    }

    func testSnapshotRejectsDuplicateEmptyAndExcessRunners() throws {
        for count in [2, FausSwitchStartGrid.maximumRunners + 1] {
            let data = try server("playing") { message in
                var payload = message["payload"] as! [String: Any]
                let runner = (payload["runners"] as! [[String: Any]])[0]
                payload["runners"] = (0..<count).map { index in
                    var item = runner
                    item["playerId"] = count == 2 ? "duplicate" : "player\(index)"
                    return item
                }
                message["payload"] = payload
            }
            XCTAssertThrowsError(try GameRealtimeCodec.decode(data, as: FausSwitchRealtime.self), "\(count) runners") {
                XCTAssertEqual($0 as? GameRealtimeError, .invalidResponse)
            }
        }
        XCTAssertThrowsError(try GameRealtimeCodec.decode(snapshotData(field: "playerId", value: ""), as: FausSwitchRealtime.self)) {
            XCTAssertEqual($0 as? GameRealtimeError, .invalidResponse)
        }
    }

    func testSnapshotRejectsNonFiniteButAcceptsAllFinitePhysics() throws {
        let decoder = GameRealtimeCodec.makeDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        for field in ["x", "y", "velocityY", "elapsedSeconds"] {
            for value in ["NaN", "Infinity", "-Infinity"] {
                let data = try snapshotData(field: field, value: value)
                XCTAssertThrowsError(try decoder.decode(FausSwitchServerMessage.self, from: data), "\(field)=\(value)") {
                    XCTAssertEqual($0 as? GameRealtimeError, .invalidResponse)
                }
            }
            for value in [-Double.greatestFiniteMagnitude, -1, 1e9, Double.greatestFiniteMagnitude] {
                let snapshot = try XCTUnwrap(GameRealtimeCodec.decode(snapshotData(field: field, value: value),
                                                                     as: FausSwitchRealtime.self).payload.snapshot)
                var states = snapshot.runnerStates
                _ = FausSwitchPhysics.isSupported(states, index: 0, course: .standard)
                FausSwitchPhysics.step(&states, tick: snapshot.tick, course: .standard)
            }
        }
        let overflow = String(decoding: try snapshotData(field: "x", value: "OVERFLOW"), as: UTF8.self)
            .replacingOccurrences(of: "\"OVERFLOW\"", with: "1e400")
        // JSONDecoder rejects 1e400 as unrepresentable before checkCompatibility.
        XCTAssertThrowsError(try GameRealtimeCodec.decode(Data(overflow.utf8), as: FausSwitchRealtime.self)) {
            XCTAssertTrue($0 is DecodingError)
        }
    }

    func testSnapshotAcceptsTickAndRunnerBoundariesAndPredicts() throws {
        let threeHours: Int64 = 3 * 3_600 * 120
        for tick in [Int64(0), threeHours, FausSwitchRealtime.maximumSnapshotTick] {
            for status in ["running", "finished", "crashed"] {
                let data = try server("crowdedCountdown") { message in
                    var payload = message["payload"] as! [String: Any]
                    payload["tick"] = tick
                    payload["elapsedSeconds"] = FausSwitchMetrics.seconds(tick)
                    var runners = payload["runners"] as! [[String: Any]]
                    for index in runners.indices {
                        runners[index]["boostedUntilTick"] = tick
                        runners[index]["slowedUntilTick"] = tick
                        runners[index]["status"] = status
                        runners[index]["finishedAtTick"] = status == "finished" ? tick : NSNull()
                        runners[index]["eliminatedAtTick"] = status == "crashed" ? tick : NSNull()
                        runners[index]["eliminationReason"] = status == "crashed" ? "boundary" : NSNull()
                    }
                    payload["runners"] = runners
                    message["payload"] = payload
                }
                let snapshot = try XCTUnwrap(GameRealtimeCodec.decode(data, as: FausSwitchRealtime.self).payload.snapshot)
                XCTAssertEqual(snapshot.runners.count, FausSwitchStartGrid.maximumRunners)
                var states = snapshot.runnerStates
                // Prediction can step beyond the accepted snapshot boundary, including effect expiry.
                FausSwitchPhysics.step(&states, tick: tick, course: FausSwitchCourse.standard)
                XCTAssertTrue(states.allSatisfy { $0.x.isFinite && $0.y.isFinite })
                XCTAssertTrue(FausSwitchRealtime.isValidSuccessor(snapshot, of: snapshot))
            }
        }
        for tick in [threeHours, FausSwitchRealtime.maximumSnapshotTick] {
            let latest = try XCTUnwrap(GameRealtimeCodec.decode(snapshotData(field: "tick", value: tick),
                                                               as: FausSwitchRealtime.self).payload.snapshot)
            for end in [Int64(0), tick - 42] {
                let stopped = try XCTUnwrap(GameRealtimeCodec.decode(snapshotData(field: "eliminatedAtTick", value: end),
                                                                    as: FausSwitchRealtime.self).payload.snapshot)
                XCTAssertFalse(FausSwitchRealtime.isValidSuccessor(latest, of: stopped), "Long-session next.tick - end is safe")
            }
        }
    }

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
            guard case .session(let session) = message.payload else {
                XCTFail("Expected session payload")
                throw UnexpectedTestState()
            }
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

    /// The HUD's FPS chip counts the playing frames drawn in the last second.
    func testDisplayFramesPerSecondCountsPlayingFrames() throws {
        let (engine, _) = try running()
        XCTAssertEqual(engine.displayFramesPerSecond(at: 1.0), 0)
        var frameTime = 1.0
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
        // A stall far past the clock's pace jumps instead of crawling back, once it has lasted
        // a snapshot interval (a held-back burst arrives oldest first within a few milliseconds).
        try receive(engine, socket, playing(sequence: 40, tick: 198) { _ in }, at: 2.2)
        XCTAssertEqual(engine.presentation(at: 2.2)?.frame.tick, 240)
        try receive(engine, socket, playing(sequence: 41, tick: 204) { _ in }, at: 2.26)
        XCTAssertEqual(engine.presentation(at: 2.26)?.frame.tick, 204)
    }

    /// An opponent's flip learned late moves its predicted height by 120 units: the screen
    /// eases there over the remote time and never draws the robot against its new motion.
    func testOpponentsLateFlipEasesWithoutRunningBackward() throws {
        for rate in [20, 30, 60] {
            for shift in [-120.0, 120.0] {
                let (engine, twin, arrival) = try correctedPair(rate: rate) { old, runners in
                    runners[1]["y"] = (old[other]?.y ?? 0) + shift
                }
                let frames = try (0...12).map { index -> (time: TimeInterval, y: Double, residual: Double, velocity: Double) in
                    let time = arrival + Double(index) / 60
                    let shown = try state(engine, other, at: time)
                    let predicted = try state(twin, other, at: time)
                    return (time, shown.y, shown.y - predicted.y, predicted.velocityY)
                }
                let diagnostics = engine.diagnostics(at: arrival)
                XCTAssertEqual(diagnostics.remoteSnaps, 0, "rate \(rate) shift \(shift)")
                XCTAssertEqual(try XCTUnwrap(diagnostics.remoteCorrection?.max), 120, accuracy: 20)
                XCTAssertEqual(abs(frames[0].residual), 120, accuracy: 20, "Starts where the screen was")
                for (previous, next) in zip(frames, frames.dropFirst()) {
                    XCTAssertLessThanOrEqual(abs(next.residual), abs(previous.residual) + 0.001)
                    XCTAssertGreaterThanOrEqual((next.y - previous.y) * (previous.velocity < 0 ? -1.0 : 1.0), -0.5,
                                                "rate \(rate) shift \(shift): moving against its new velocity")
                }
                if shift > 0 {
                    XCTAssertLessThan(abs(frames[12].residual), 120 * 0.5, "Eased by 0.2 s")
                    XCTAssertGreaterThan(abs(frames[12].residual), 120 * 0.2, "Not a snap")
                }
            }
        }
    }

    /// A correction that pulls a robot backward is held to a share of its run speed.
    func testBackwardCorrectionNeverRunsTheRobotBack() throws {
        for rate in [20, 30, 60] {
            let (engine, twin, arrival) = try correctedPair(rate: rate) { old, runners in
                runners[1]["x"] = (old[other]?.x ?? 0) - 100
            }
            var previous = try state(engine, other, at: arrival).x
            for index in 1...20 {
                let time = arrival + Double(index) / 60
                let shown = try state(engine, other, at: time).x
                XCTAssertGreaterThan(shown, previous, "rate \(rate) frame \(index)")
                previous = shown
                if index == 12 {
                    let residual = shown - (try state(twin, other, at: time).x)
                    XCTAssertGreaterThan(residual, 100 - FausSwitchMetrics.runSpeed * 0.75 * 0.2 - 1, "Slower than the free ease")
                    XCTAssertLessThan(residual, 100)
                }
            }
        }
    }

    func testCorrectionBeyondTheRemoteLimitSnaps() throws {
        for rate in [20, 30, 60] {
            let (engine, twin, arrival) = try correctedPair(rate: rate) { old, runners in
                runners[1]["x"] = (old[other]?.x ?? 0) + 250
            }
            XCTAssertEqual(engine.diagnostics(at: arrival).remoteSnaps, 1, "rate \(rate)")
            let shown = try state(engine, other, at: arrival).x
            XCTAssertEqual(shown, try state(twin, other, at: arrival).x, accuracy: 0.5)
        }
    }

    /// The local robot's own corrections are smaller and ease faster than an opponent's.
    func testLocalCorrectionEasesFasterThanAnOpponents() throws {
        for rate in [20, 30, 60] {
            let (engine, twin, arrival) = try correctedPair(rate: rate) { old, runners in
                runners[0]["x"] = (old[playerID]?.x ?? 0) + 100
                runners[1]["x"] = (old[other]?.x ?? 0) + 100
            }
            let diagnostics = engine.diagnostics(at: arrival)
            XCTAssertEqual(diagnostics.localSnaps, 0)
            XCTAssertEqual(try XCTUnwrap(diagnostics.localCorrection?.max), 100, accuracy: 5)
            func residual(_ id: String, after seconds: TimeInterval) throws -> Double {
                try state(engine, id, at: arrival + seconds).x - state(twin, id, at: arrival + seconds).x
            }
            XCTAssertEqual(try residual(playerID, after: 0), -100, accuracy: 5)
            XCTAssertEqual(try residual(playerID, after: 0.11), -36.8, accuracy: 6, "rate \(rate)")
            XCTAssertEqual(try residual(other, after: 0.11), -100 * exp(-0.55), accuracy: 6, "rate \(rate)")
            XCTAssertGreaterThan(try residual(playerID, after: 0.33), -8)
        }
    }

    /// Jitter of up to 80 ms, a 300 ms gap whose snapshots arrive together, a burst of three
    /// and an extra snapshot one tick after another: the tick on screen only moves forward.
    func testDisplayTickStaysMonotonicWithJitterGapAndBurst() throws {
        let jitter: [TimeInterval] = [0.04, 0, 0.08, 0.02, 0.06, 0, 0.08, 0.01, 0.05, 0.03, 0, 0.07]
        for rate in [20, 30, 60] {
            let (engine, socket) = try playingEngine(snapshotRateHz: rate)
            let interval = 120 / rate
            var stream: [(tick: Int, arrival: TimeInterval)] = []
            var previous = 1.0
            for index in 1...(rate * 5 / 2) {
                let sent = 1 + Double(index * interval) / 120
                var arrival = sent + jitter[index % jitter.count]
                if (1.5..<1.8).contains(sent) { arrival = 1.84 + 0.0003 * Double(stream.count) }
                if sent >= 2.2, sent < 2.2 + 3 * Double(interval) / 120 { arrival = 2.2 + 3 * Double(interval) / 120 + 0.02 }
                arrival = max(previous, arrival)
                stream.append((120 + index * interval, arrival))
                if index == 8 { stream.append((120 + index * interval + 1, arrival + 0.002)) }
                previous = arrival
            }
            var frame = 1.0
            var lastTick: Int64 = 0
            var lastFocus = -Double.infinity
            for (sequence, snapshot) in stream.enumerated() {
                while frame < snapshot.arrival {
                    let shown = try XCTUnwrap(engine.presentation(at: frame)?.frame)
                    XCTAssertGreaterThanOrEqual(shown.tick, lastTick, "rate \(rate) frame at \(frame)")
                    XCTAssertGreaterThanOrEqual(shown.cameraFocus, lastFocus, "rate \(rate) frame at \(frame)")
                    lastTick = shown.tick
                    lastFocus = shown.cameraFocus
                    frame += 1.0 / 60
                }
                try receive(engine, socket, playing(sequence: 3 + sequence, tick: snapshot.tick) { _ in }, at: snapshot.arrival)
                // Rendered between the callbacks of a held-back burst, 0.3 ms apart.
                let shown = try XCTUnwrap(engine.presentation(at: snapshot.arrival)?.frame)
                XCTAssertGreaterThanOrEqual(shown.tick, lastTick, "rate \(rate) arrival at \(snapshot.arrival)")
                lastTick = shown.tick
            }
            XCTAssertEqual(engine.diagnostics(at: frame).resyncRequests, 0, "A late stream is no reason to resync")
            XCTAssertEqual(engine.diagnostics(at: frame).clockSnaps, 0, "Held-back snapshots are no stall")
        }
    }

    /// The lobby machine judges a stopped robot's return by the welcome's rewind window:
    /// 400 ms is 48 + 6 ticks, beyond the 36 of the release defaults.
    func testLobbyAcceptsAStoppedRobotReturningInsideTheWelcomeRewindWindow() throws {
        func stoppedThenReturned(after ticks: Int) throws -> Bool {
            let (engine, socket) = try connectedLobby(state: "running", settings: ["maximumRewindMilliseconds": 400])
            try receive(engine, socket, playing(sequence: 2, tick: 300) { runners in
                runners[0]["status"] = "crashed"
                runners[0]["eliminatedAtTick"] = 290
                runners[0]["eliminationReason"] = "boundary"
            }, at: 1)
            try receive(engine, socket, playing(sequence: 3, tick: 290 + ticks) { _ in }, at: 1.05)
            return try state(engine, playerID, at: 1.05).isRunning
        }
        XCTAssertTrue(try stoppedThenReturned(after: 54))
        XCTAssertFalse(try stoppedThenReturned(after: 55))
    }

    func testSuccessorAndClipEstimateFollowTheWelcomeSettings() throws {
        func snapshot(tick: Int, crashedAt: Int?) throws -> FausSwitchSnapshotDTO {
            let data = try playing(sequence: tick, tick: tick) { runners in
                if let crashedAt {
                    runners[0]["status"] = "crashed"
                    runners[0]["eliminatedAtTick"] = crashedAt
                    runners[0]["eliminationReason"] = "boundary"
                }
            }
            return try XCTUnwrap(GameRealtimeCodec.decode(data, as: FausSwitchRealtime.self).payload.snapshot)
        }
        func settings(rate: Int, rewind: Int64) -> FausSwitchRuntimeSettingsDTO {
            let base = FausSwitchRuntimeSettingsDTO.releaseDefaults
            return FausSwitchRuntimeSettingsDTO(
                physicsRateHz: base.physicsRateHz, snapshotRateHz: rate, maximumInputRateHz: base.maximumInputRateHz,
                maximumRewindMilliseconds: rewind, controlHeartbeatMilliseconds: base.controlHeartbeatMilliseconds,
                controlTimeoutMilliseconds: base.controlTimeoutMilliseconds,
                reconnectGraceMilliseconds: base.reconnectGraceMilliseconds,
                maximumMatchMilliseconds: base.maximumMatchMilliseconds)
        }
        let down = try snapshot(tick: 300, crashedAt: 290)
        // 30 Hz / 250 ms: 30 rewind + 4 snapshot ticks. 60 Hz / 100 ms: 12 + 2.
        for (rate, rewind, window) in [(30, Int64(250), 34), (60, Int64(100), 14)] {
            let configured = settings(rate: rate, rewind: rewind)
            XCTAssertTrue(FausSwitchRealtime.isValidSuccessor(try snapshot(tick: 290 + window, crashedAt: nil), of: down,
                                                             settings: configured))
            XCTAssertFalse(FausSwitchRealtime.isValidSuccessor(try snapshot(tick: 290 + window + 1, crashedAt: nil), of: down,
                                                              settings: configured))
            // The flip sent at tick 126 is clipped once its ACK is older than the window.
            for (ackTick, clipped) in [(126 + window, 0), (126 + window + 1, 1)] {
                let (engine, socket) = try playingEngine(snapshotRateHz: rate, rewindMilliseconds: rewind)
                try receive(engine, socket, server("controlGranted"), at: 1.01)
                XCTAssertEqual(engine.flip(now: 1.05), .flipped)
                try receive(engine, socket, playing(sequence: 3, tick: ackTick) { runners in
                    runners[0]["lastProcessedInputSequence"] = 1
                }, at: 1.07)
                XCTAssertEqual(engine.diagnostics(at: 1.1).clippedFlips, clipped, "rate \(rate) ack \(ackTick)")
            }
        }
    }

    func testDiagnosticsCountSwallowedAndUnsupportedFlipsApart() throws {
        let (engine, socket) = try running()
        XCTAssertEqual(engine.flip(now: 1.02), .ignored, "No grant yet")
        try receive(engine, socket, server("controlGranted"), at: 1.03)
        XCTAssertEqual(engine.flip(now: 1.05), .flipped)
        XCTAssertEqual(engine.flip(now: 1.07), .unsupported, "Mid-air")
        XCTAssertEqual(engine.flip(now: 1.9), .ignored, "The snapshot is older than the extrapolation budget")
        let diagnostics = engine.diagnostics(at: 1.9)
        XCTAssertEqual(diagnostics.swallowedInputs, 2)
        XCTAssertEqual(diagnostics.unsupportedInputs, 1)
        XCTAssertEqual(diagnostics.lines.count, 9)
        XCTAssertEqual(diagnostics.lines[7], "swallowed 2 · unsupported 1")
    }

    func testDiagnosticsKeepRemoteCorrectionsApartFromLocalOnes() throws {
        let (engine, socket) = try running()
        try receive(engine, socket, playing(sequence: 3, tick: 120) { runners in
            runners[1]["x"] = ((runners[1]["x"] as? NSNumber)?.doubleValue ?? 0) + 30
        }, at: 1.0)
        let diagnostics = engine.diagnostics(at: 1.0)
        XCTAssertEqual(diagnostics.remoteCorrection?.max, 30)
        XCTAssertEqual(diagnostics.localCorrection?.max, 0)
        XCTAssertEqual(diagnostics.remoteSnaps, 0)
        XCTAssertEqual(diagnostics.localSnaps, 0)
    }

    func testDiagnosticsRecordSnapshotIntervalsAndAckLatency() throws {
        let (engine, socket) = try running()
        try receive(engine, socket, server("controlGranted"), at: 1.01)
        XCTAssertEqual(engine.flip(now: 1.02), .flipped)
        try receive(engine, socket, playing(sequence: 3, tick: 126) { runners in
            runners[0]["lastProcessedInputSequence"] = 1
        }, at: 1.07)
        let diagnostics = engine.diagnostics(at: 1.1)
        XCTAssertEqual(diagnostics.acknowledgement, GameDiagnosticsSpread(p50: 50, p95: 50, max: 50))
        XCTAssertEqual(diagnostics.snapshotInterval?.max, 70, "The grant is no snapshot: 1.0 to 1.07")
        XCTAssertEqual(diagnostics.clippedFlips, 0)
        XCTAssertEqual(diagnostics.snapshotRateHz, 20)
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
                XCTFail("Expected snapshot payload")
                throw UnexpectedTestState()
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

    private func snapshotData(field: String, value: Any) throws -> Data {
        try server("playing") { message in
            var payload = message["payload"] as! [String: Any]
            if field == "tick" || field == "elapsedSeconds" { payload[field] = value }
            else {
                var runners = payload["runners"] as! [[String: Any]]
                runners[0][field] = value
                if field == "finishedAtTick" { runners[0]["status"] = "finished" }
                if field == "eliminatedAtTick" {
                    runners[0]["status"] = "crashed"
                    runners[0]["eliminationReason"] = "boundary"
                }
                payload["runners"] = runners
            }
            message["payload"] = payload
        }
    }

    /// A match at tick 120 whose opponent is in the air, rising toward the ceiling.
    private func playingEngine(snapshotRateHz: Int, rewindMilliseconds: Int64 = 250) throws -> (FausSwitchOnlineEngine, Int) {
        let (engine, socket) = try connectedLobby(state: "running", settings: [
            "snapshotRateHz": snapshotRateHz, "maximumRewindMilliseconds": rewindMilliseconds])
        try receive(engine, socket, playing(sequence: 2, tick: 120) { runners in
            runners[1]["x"] = 700
            runners[1]["y"] = 190
            runners[1]["gravity"] = "up"
        }, at: 1)
        return (engine, socket)
    }

    /// Two engines on the same stream: one has the screen at the old prediction when the next
    /// snapshot arrives, the twin only ever saw that snapshot and so shows the prediction
    /// itself. The snapshot repeats both robots as displayed (`old`, by player) and then
    /// `change`s them (the opponent is the second runner).
    private func correctedPair(rate: Int,
                               change: ([String: FausSwitchRunnerState], inout [[String: Any]]) -> Void) throws
        -> (engine: FausSwitchOnlineEngine, twin: FausSwitchOnlineEngine, arrival: TimeInterval) {
        let (engine, socket) = try playingEngine(snapshotRateHz: rate)
        let interval = 120 / rate
        let arrival = 1 + Double(interval) / 120
        let old = [playerID: try state(engine, playerID, at: arrival), other: try state(engine, other, at: arrival)]
        let next = try playing(sequence: 3, tick: 120 + interval) { runners in
            for (index, id) in [playerID, other].enumerated() {
                runners[index]["x"] = old[id]?.x
                runners[index]["y"] = old[id]?.y
                runners[index]["velocityY"] = old[id]?.velocityY
            }
            change(old, &runners)
        }
        try receive(engine, socket, next, at: arrival)
        let (twin, twinSocket) = try connectedLobby(state: "running", settings: ["snapshotRateHz": rate])
        try receive(twin, twinSocket, next, at: arrival)
        return (engine, twin, arrival)
    }

    private func state(_ engine: FausSwitchOnlineEngine, _ id: String, at time: TimeInterval) throws -> FausSwitchRunnerState {
        try XCTUnwrap(engine.presentation(at: time)?.frame.runners.first { $0.id == id }?.state)
    }

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

    /// `settings` overrides fields of the welcome's runtime settings.
    private func connectedLobby(state: String = "lobby", color: FausSwitchColor? = nil, settings: [String: Any] = [:])
        throws -> (FausSwitchOnlineEngine, Int) {
        let engine = makeEngine(color: color)
        engine.start(isForeground: true, isLandscape: true, now: 0)
        guard case .ensureSession(let house, let connection) = try XCTUnwrap(engine.drainEffects().first) else {
            XCTFail("No ensure effect")
            throw UnexpectedTestState()
        }
        XCTAssertEqual(house, houseID)
        engine.sessionResponse(try http(state: state), retryAfter: nil, connection: connection, now: 0.1)
        guard case .openSocket(let id, let socket) = try XCTUnwrap(engine.drainEffects().last) else {
            XCTFail("No socket opened")
            throw UnexpectedTestState()
        }
        XCTAssertEqual(id, sessionID)
        engine.socketOpened(connection: socket, now: 0.2)
        try receive(engine, socket, server("welcome") { message in
            var payload = message["payload"] as! [String: Any]
            payload["settings"] = (payload["settings"] as! [String: Any]).merging(settings) { $1 }
            message["payload"] = payload
        }, at: 0.3)
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
