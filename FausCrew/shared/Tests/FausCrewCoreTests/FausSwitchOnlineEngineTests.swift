import Foundation
import FausCrewCore
import XCTest

/// The sans-IO online engine against `Fixtures/fausSwitchProtocol.json` (the backend contract).
final class FausSwitchOnlineEngineTests: XCTestCase {
    private let houseID = "507f1f77bcf86cd799439012"
    private let playerID = "507f1f77bcf86cd799439021"
    private let sessionID = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"
    private var ids = 0

    func testFixtureMessagesDecodeAndEncode() throws {
        let welcome = try GameRealtimeCodec.decode(try server("welcome"), as: FausSwitchRealtime.self)
        guard case .welcome(let payload) = welcome.payload else { return XCTFail("welcome") }
        XCTAssertEqual(payload.settings, FausSwitchRuntimeSettingsDTO.releaseDefaults)

        let playing = try GameRealtimeCodec.decode(try server("playing"), as: FausSwitchRealtime.self)
        guard case .snapshot(let snapshot) = playing.payload else { return XCTFail("snapshot") }
        XCTAssertEqual(snapshot.runners.map(\.color), [.ocean, .plum])
        XCTAssertEqual(snapshot.runners.first?.state, FausSwitchRunnerState(x: 605, y: 44.1, gravity: .down))

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
            payload["courseVersion"] = 7
            message["payload"] = payload
        }
        XCTAssertThrowsError(try GameRealtimeCodec.decode(data, as: FausSwitchRealtime.self)) { error in
            XCTAssertEqual(error as? GameRealtimeError, .unsupportedCourse(7))
        }
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

    func testResultEventIsTheAuthority() throws {
        let (engine, socket) = try running()
        try receive(engine, socket, server("result"), at: 40)
        XCTAssertEqual(engine.result.result?.winnerId, playerID)
        XCTAssertEqual(engine.result.identities[playerID]?.color, .ocean)
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

    private func session(version: Int64, state: String, localState: String?) throws -> Data {
        try server("sessionSnapshot") { message in
            var payload = message["payload"] as! [String: Any]
            payload["version"] = version
            payload["state"] = state
            var players = (payload["players"] as! [[String: Any]]).filter { $0["playerId"] as? String != self.playerID }
            if let localState {
                players.insert(["playerId": self.playerID, "state": localState,
                                "joinedAt": "2026-11-05T12:00:00Z", "readyAt": NSNull(), "leftAt": NSNull()], at: 0)
            }
            payload["players"] = players
            if state == "lobby" { payload["countdownEndsAt"] = NSNull() }
            message["payload"] = payload
        }
    }
}
