import Foundation
@testable import FausCrewCore
import XCTest

/// The Faus Tanks room through the engine, with a mock server: PUT → socket →
/// welcome and session → join → ready → countdown preview, the heartbeat, the
/// update warning for an unknown map and the server arena.
final class HouseTanksOnlineEngineTests: XCTestCase {
    private struct UnexpectedTestState: Error {}

    private let houseID = "507f1f77bcf86cd799439012"
    private let playerID = "507f1f77bcf86cd799439021"
    private let sessionID = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"
    private var ids = 0

    func testSnapshotRejectsUnsafeTicksBeforeWorldArithmetic() throws {
        for (collection, field) in [("", "tick"), ("projectiles", "spawnTick"),
                                    ("players", "powerUpExpiresAtTick"), ("token", "expiresAtTick"), ("events", "tick")] {
            for value in [Int64.min, -1, HouseTanksRealtime.maximumSnapshotTick + 1, Int64.max] {
                let data = try snapshotData(collection: collection, field: field, value: value)
                XCTAssertThrowsError(try GameRealtimeCodec.decode(data, as: HouseTanksRealtime.self), "\(collection).\(field)=\(value)") {
                    XCTAssertEqual($0 as? GameRealtimeError, .invalidResponse)
                }
            }
        }
    }

    func testSnapshotRejectsDuplicateEmptyAndExcessIdentities() throws {
        for (collection, field) in [("players", "playerId"), ("tanks", "playerId"),
                                    ("projectiles", "id"), ("crates", "index")] {
            XCTAssertThrowsError(try HouseTanksWireContractTests.decode("roundPlaying") { payload in
                var items = payload[collection] as! [[String: Any]]
                items[1][field] = items[0][field]
                payload[collection] = items
            }, "duplicate \(collection).\(field)") { XCTAssertEqual($0 as? GameRealtimeError, .invalidResponse) }
        }
        for (collection, field) in [("players", "playerId"), ("tanks", "playerId"), ("projectiles", "ownerId")] {
            XCTAssertThrowsError(try GameRealtimeCodec.decode(snapshotData(collection: collection, field: field, value: ""),
                                                              as: HouseTanksRealtime.self), "empty \(collection).\(field)") {
                XCTAssertEqual($0 as? GameRealtimeError, .invalidResponse)
            }
        }
        for collection in ["players", "tanks"] {
            XCTAssertThrowsError(try HouseTanksWireContractTests.decode("roundPlaying") { payload in
                let template = (payload[collection] as! [[String: Any]])[0]
                payload[collection] = (0...HouseTanksMapCatalog.maximumPlayers).map { index in
                    var item = template
                    item["playerId"] = "player\(index)"
                    if collection == "players" { item["seat"] = index % HouseTanksMapCatalog.maximumPlayers }
                    return item
                }
            }, "too many \(collection)") { XCTAssertEqual($0 as? GameRealtimeError, .invalidResponse) }
        }
    }

    func testSnapshotRejectsNonFinitePhysics() throws {
        // A permissive decoder exercises DTO validation itself; production's
        // default decoder rejects these non-JSON numbers before compatibility.
        let decoder = GameRealtimeCodec.makeDecoder()
        decoder.nonConformingFloatDecodingStrategy = .convertFromString(
            positiveInfinity: "Infinity", negativeInfinity: "-Infinity", nan: "NaN")
        for (collection, fields) in [("tanks", ["x", "y", "vx", "vy", "rotation"]),
                                     ("projectiles", ["x", "y", "vx", "vy"]), ("crates", ["x", "y"]),
                                     ("token", ["x", "y"]), ("events", ["x", "y", "angle"])] {
            for field in fields {
                for value in ["NaN", "Infinity", "-Infinity"] {
                    let data = try snapshotData(collection: collection, field: field, value: value)
                    XCTAssertThrowsError(try decoder.decode(HouseTanksServerMessage.self, from: data), "\(collection).\(field)=\(value)") {
                        XCTAssertEqual($0 as? GameRealtimeError, .invalidResponse)
                    }
                }
            }
        }
        let huge = try snapshotData(collection: "tanks", field: "rotation", value: Double.greatestFiniteMagnitude)
        XCTAssertThrowsError(try GameRealtimeCodec.decode(huge, as: HouseTanksRealtime.self), "Finite angle must not stall normalization") {
            XCTAssertEqual($0 as? GameRealtimeError, .invalidResponse)
        }
        let overflow = String(decoding: try snapshotData(collection: "tanks", field: "x", value: "OVERFLOW"), as: UTF8.self)
            .replacingOccurrences(of: "\"OVERFLOW\"", with: "1e400")
        // JSONDecoder rejects 1e400 as unrepresentable before checkCompatibility.
        XCTAssertThrowsError(try GameRealtimeCodec.decode(Data(overflow.utf8), as: HouseTanksRealtime.self)) {
            XCTAssertTrue($0 is DecodingError)
        }
    }

    func testSnapshotAllowsWideFiniteFieldsAndOnlyBoundsUnsafeIntegers() throws {
        for (collection, fields) in [("tanks", ["x", "y", "vx", "vy"]), ("projectiles", ["x", "y", "vx", "vy"]),
                                     ("crates", ["x", "y"]), ("token", ["x", "y"]), ("events", ["x", "y", "angle"])] {
            for field in fields {
                for value in [-Double.greatestFiniteMagnitude, Double.greatestFiniteMagnitude] {
                    XCTAssertNoThrow(try GameRealtimeCodec.decode(snapshotData(collection: collection, field: field, value: value),
                                                                 as: HouseTanksRealtime.self), "\(collection).\(field)=\(value)")
                }
            }
        }
        for (collection, field, values) in [
            ("players", "seat", [Int.min, Int.max]), ("players", "roundsWon", [Int.min, Int.max]),
            ("players", "armor", [Int.min / 2, Int.max]), ("players", "lastProcessedInputSequence", [Int.min, Int.max]),
            ("tanks", "aimLocks", [Int.min, Int.max / 2]), ("tanks", "rotationDirection", [-100_000, 100_000]),
            ("crates", "index", [Int.min, Int.max]), ("projectiles", "id", [Int.min, Int.max]),
        ] {
            for value in values {
                XCTAssertNoThrow(try GameRealtimeCodec.decode(snapshotData(collection: collection, field: field, value: value),
                                                             as: HouseTanksRealtime.self), "\(collection).\(field)=\(value)")
            }
        }
        for (collection, field, value) in [("players", "armor", Int.min / 2 - 1),
                                           ("tanks", "aimLocks", Int.max / 2 + 1),
                                           ("tanks", "rotationDirection", -100_001), ("tanks", "rotationDirection", 100_001)] {
            XCTAssertThrowsError(try GameRealtimeCodec.decode(snapshotData(collection: collection, field: field, value: value),
                                                              as: HouseTanksRealtime.self), "\(collection).\(field)=\(value)") {
                XCTAssertEqual($0 as? GameRealtimeError, .invalidResponse)
            }
        }
        for rotation in [-HouseTanksTankDTO.maximumRotationMagnitude, HouseTanksTankDTO.maximumRotationMagnitude] {
            XCTAssertNoThrow(try GameRealtimeCodec.decode(snapshotData(collection: "tanks", field: "rotation", value: rotation),
                                                         as: HouseTanksRealtime.self))
            XCTAssertTrue(HouseTanksPlayMath.lerpAngle(rotation, -rotation, 0.5).isFinite)
            let outside = rotation < 0 ? rotation.nextDown : rotation.nextUp
            XCTAssertThrowsError(try GameRealtimeCodec.decode(snapshotData(collection: "tanks", field: "rotation", value: outside),
                                                              as: HouseTanksRealtime.self)) {
                XCTAssertEqual($0 as? GameRealtimeError, .invalidResponse)
            }
        }
    }

    func testSnapshotAcceptsTickAndSeatBoundariesAndBuildsWorld() throws {
        let threeHours: Int64 = 3 * 3_600 * 120
        for tick in [Int64(0), threeHours, HouseTanksRealtime.maximumSnapshotTick] {
            let snapshot = try XCTUnwrap(HouseTanksWireContractTests.decode("roundPlaying") { payload in
                payload["tick"] = tick
                for (collection, field) in [("projectiles", "spawnTick"), ("players", "powerUpExpiresAtTick"), ("events", "tick")] {
                    var items = payload[collection] as! [[String: Any]]
                    for index in items.indices {
                        items[index][field] = field == "spawnTick" && tick == threeHours ? tick - 9 : tick
                    }
                    payload[collection] = items
                }
                var token = payload["token"] as! [String: Any]
                token["expiresAtTick"] = tick
                payload["token"] = token
                let player = (payload["players"] as! [[String: Any]])[0]
                let tank = (payload["tanks"] as! [[String: Any]])[0]
                payload["players"] = (0..<HouseTanksMapCatalog.maximumPlayers).map { index in
                    var item = player; item["playerId"] = "player\(index)"; item["seat"] = index; return item
                }
                payload["tanks"] = (0..<HouseTanksMapCatalog.maximumPlayers).map { index in
                    var item = tank; item["playerId"] = "player\(index)"; return item
                }
            }.payload.snapshot)
            let world = try XCTUnwrap(HouseTanksWorld(server: snapshot))
            XCTAssertEqual(world.tick, Int(tick))
            XCTAssertEqual(world.tanks.count, HouseTanksMapCatalog.maximumPlayers)
            XCTAssertEqual(world.projectiles.map(\.age), tick == threeHours ? [9, 9] : [0, 0])
            XCTAssertEqual(world.tokenFraction, 0)
            XCTAssertTrue(snapshot.events.allSatisfy { HouseTanksPlayMath.event($0) != nil || $0.kind == .roundEnded })
            var predicted = world.withoutShots
            predicted.step()
            XCTAssertEqual(predicted.tick, Int(tick) + 1)
        }
        // The widest accepted subtraction (tick - spawnTick) is safe too.
        let snapshot = try XCTUnwrap(HouseTanksWireContractTests.decode("roundPlaying") { payload in
            payload["tick"] = HouseTanksRealtime.maximumSnapshotTick
            var shots = payload["projectiles"] as! [[String: Any]]
            for index in shots.indices { shots[index]["spawnTick"] = 0 }
            payload["projectiles"] = shots
        }.payload.snapshot)
        XCTAssertEqual(try XCTUnwrap(HouseTanksWorld(server: snapshot)).projectiles.first?.age,
                       Int(HouseTanksRealtime.maximumSnapshotTick))
    }

    func testRoomFlowFromSessionRequestToTheCountdownPreview() throws {
        let engine = makeEngine()
        engine.start(isForeground: true, isLandscape: false, now: 0)
        guard case .ensureSession(let house, let connection) = try XCTUnwrap(engine.drainEffects().first) else {
            return XCTFail("The room starts with PUT /game/houseTanks/session")
        }
        XCTAssertEqual(house, houseID)

        engine.sessionResponse(try envelope(sessionPayload(version: 5, state: "lobby", localState: nil)),
                               retryAfter: nil, connection: connection, now: 0.1)
        guard case .openSocket(let id, let socket) = try XCTUnwrap(engine.drainEffects().last) else {
            return XCTFail("The session response opens the socket")
        }
        XCTAssertEqual(id, sessionID)
        engine.socketOpened(connection: socket, now: 0.2)
        engine.received(text: try fixture("welcome"), connection: socket, now: 0.3)
        engine.received(text: try session(version: 6, state: "lobby", localState: nil), connection: socket, now: 0.4)
        XCTAssertEqual(types(engine), ["gameSession.join"], "Welcome and session first, then join")
        XCTAssertEqual(HouseTanksOnlineCopyKeys.roomStatus(engine.lobby), "house_tanks_online_joining")

        engine.received(text: try session(version: 7, state: "lobby", localState: "waiting"), connection: socket, now: 0.5)
        XCTAssertTrue(engine.lobby.canChangeReady(playerID: playerID))
        XCTAssertFalse(engine.canChangeReady, "No ready before the server holds a tank color")
        engine.setReady(true, now: 0.55)
        XCTAssertEqual(types(engine), [], "A ready without a color stays on the client")
        engine.received(text: try session(version: 8, state: "lobby", localState: "waiting", colors: [playerID: "plum"]),
                        connection: socket, now: 0.56)
        XCTAssertTrue(engine.canChangeReady)
        XCTAssertEqual(HouseTanksOnlineCopyKeys.roomStatus(engine.lobby), "house_tanks_online_lobby")
        engine.setReady(true, now: 0.6)
        let ready = try XCTUnwrap(sent(engine).first)
        XCTAssertEqual(ready["type"] as? String, "gameSession.setReady")
        XCTAssertEqual((ready["payload"] as? [String: Any])?["ready"] as? Bool, true)

        engine.received(text: try session(version: 9, state: "readyWindow", localState: "ready",
                                          readyWindowEndsAt: "2026-10-24T12:01:00Z"), connection: socket, now: 0.7)
        XCTAssertEqual(HouseTanksOnlineCopyKeys.roomStatus(engine.lobby), "house_tanks_online_ready_window")
        XCTAssertEqual(engine.lobby.readyCount, 1)
        XCTAssertEqual(engine.roomCountdown(at: 0.7), 30, "The window's end on the server clock")

        engine.received(text: try session(version: 10, state: "countdown", localState: "playing",
                                          countdownEndsAt: "2026-10-24T12:00:33Z"), connection: socket, now: 0.8)
        XCTAssertNil(engine.arena, "No map until the countdown snapshot")
        engine.received(text: try fixture("countdown"), connection: socket, now: 0.9)
        let arena = try XCTUnwrap(engine.arena)
        XCTAssertEqual(arena.map.id, .livingRoom)
        XCTAssertEqual(arena.tanks.map(\.color), [.plum, .orange, .blue])
        XCTAssertNil(engine.lobby.game?.roundPhase, "The lobby preview has no round phase")
        XCTAssertEqual(HouseTanksOnlineCopyKeys.roomStatus(engine.lobby), "house_tanks_online_countdown")
        XCTAssertEqual(engine.roomCountdown(at: 0.9), 3)
        XCTAssertFalse(engine.lobby.requiresUpdate)
    }

    func testPingEveryTwoSecondsWhileTheServerAnswers() throws {
        let (engine, socket) = try connectedEngine()
        _ = engine.drainEffects()
        var pings: [Double] = []
        for step in 1...240 {
            let now = 0.4 + Double(step) * 0.025
            engine.tick(now: now)
            guard let ping = try sent(engine).first(where: { $0["type"] as? String == "realtime.ping" }),
                  let id = (ping["payload"] as? [String: Any])?["pingId"] as? String else { continue }
            pings.append(now)
            engine.received(text: try fixture("pong") { $0["pingId"] = id }, connection: socket, now: now + 0.01)
        }
        XCTAssertEqual(pings.count, 3, "6 s of ticks")
        for (first, second) in zip(pings, pings.dropFirst()) {
            XCTAssertEqual(second - first, 2, accuracy: 0.03)
        }
    }

    func testUnknownMapStopsTheRoomWithAnUpdateWarning() throws {
        let (engine, socket) = try connectedEngine()
        engine.received(text: try fixture("countdown") { $0["mapVersion"] = 99 }, connection: socket, now: 1)
        XCTAssertTrue(engine.lobby.requiresUpdate)
        XCTAssertNil(engine.arena)
        XCTAssertEqual(HouseTanksOnlineCopyKeys.roomStatus(engine.lobby), "house_tanks_online_update_title")
        XCTAssertEqual(HouseTanksOnlineCopyKeys.roomDetail(engine.lobby), "house_tanks_online_update_required")
        XCTAssertFalse(engine.lobby.canReconnect(at: 100))
        _ = engine.drainEffects()
        engine.tick(now: 40)
        XCTAssertFalse(engine.drainEffects().contains { if case .openSocket = $0 { return true }; return false })
    }

    func testCountdownSeatsMatchTheCatalogSpawns() throws {
        let snapshot = try XCTUnwrap(HouseTanksWireContractTests.decode("countdown").payload.snapshot)
        let server = try XCTUnwrap(HouseTanksWorld(server: snapshot))
        let local = HouseTanksWorld(map: HouseTanksMapCatalog.definition(for: .livingRoom),
                                    playerIDs: snapshot.players.map(\.playerId))
        XCTAssertEqual(server.tanks.count, 3)
        for (lhs, rhs) in zip(server.tanks, local.tanks) {
            XCTAssertEqual(lhs.id, rhs.id)
            XCTAssertEqual(lhs.position.x, rhs.position.x, accuracy: 1e-6)
            XCTAssertEqual(lhs.position.y, rhs.position.y, accuracy: 1e-6)
        }
        for (lhs, rhs) in zip(server.obstacles, local.obstacles) {
            XCTAssertEqual(lhs.position.x, rhs.position.x, accuracy: 1e-6, "Crates rest on their map spots")
            XCTAssertEqual(lhs.position.y, rhs.position.y, accuracy: 1e-6)
        }
    }

    func testServerArenaCarriesBodiesShotsAndToken() throws {
        let snapshot = try XCTUnwrap(HouseTanksWireContractTests.decode("roundPlaying") { payload in
            var crates = payload["crates"] as! [[String: Any]]
            crates[0]["destroyed"] = true
            payload["crates"] = crates
        }.payload.snapshot)
        let world = try XCTUnwrap(HouseTanksWorld(server: snapshot))
        XCTAssertEqual(world.tick, 1_200)
        let first = try XCTUnwrap(world.tanks.first)
        XCTAssertEqual(first.position, HouseTanksVector(x: 222.62, y: 180.31))
        XCTAssertEqual(first.velocity, HouseTanksVector(x: 180.5, y: 82.25))
        XCTAssertTrue(first.isDriving)
        XCTAssertEqual(world.obstacles[4].isDestroyed, true)
        XCTAssertEqual(world.projectiles.map(\.id), [31, 32])
        XCTAssertEqual(world.projectiles[0].age, 9)
        XCTAssertEqual(world.projectiles[1].color, .blue, "Shots wear the owner's color")
        XCTAssertTrue(world.projectiles[1].isRocket)
        XCTAssertEqual(world.token?.kind, .shield)
        XCTAssertEqual(world.token?.expiresAtTick, 2_420)
    }

    func testLeavingTheRoomSendsLeaveAndCloses() throws {
        let (engine, socket) = try connectedEngine()
        engine.received(text: try session(version: 7, state: "lobby", localState: "waiting"), connection: socket, now: 0.5)
        _ = engine.drainEffects()
        engine.leave(now: 1)
        XCTAssertEqual(types(engine), ["gameSession.leave"])
        XCTAssertEqual(HouseTanksOnlineCopyKeys.roomStatus(engine.lobby), "house_tanks_online_leaving")
        engine.received(text: try session(version: 8, state: "lobby", localState: "left"), connection: socket, now: 1.1)
        XCTAssertTrue(engine.isClosed)
    }

    // MARK: Lobby colors

    func testLobbySendsThePreferredColorAfterJoining() throws {
        let (engine, socket) = try connectedEngine(color: .sky)
        _ = engine.drainEffects()
        engine.received(text: try session(version: 7, state: "lobby", localState: "waiting"), connection: socket, now: 1)
        let claim = try XCTUnwrap(sent(engine).first)
        XCTAssertEqual(claim["type"] as? String, "houseTanks.selectColor")
        XCTAssertNil(claim["controlGeneration"])
        XCTAssertEqual((claim["payload"] as? [String: Any])?["color"] as? String, "sky")

        // The same pick is not repeated; a new pick is sent.
        engine.received(text: try session(version: 8, state: "lobby", localState: "waiting"), connection: socket, now: 1.1)
        XCTAssertTrue(try sent(engine).isEmpty)
        engine.selectColor(.olive, now: 1.2)
        XCTAssertEqual((try sent(engine).first?["payload"] as? [String: Any])?["color"] as? String, "olive")
    }

    /// A server without lobby colors rejects the claim; the room goes on with seat colors.
    func testRejectedColorClaimKeepsTheRoom() throws {
        let (engine, socket) = try connectedEngine(color: .sky)
        _ = engine.drainEffects()
        engine.received(text: try session(version: 7, state: "lobby", localState: "waiting"), connection: socket, now: 1)
        let id = try XCTUnwrap(sent(engine).first?["messageId"] as? String)
        engine.received(text: try rejection(id: id, code: "game.error.invalid_command"), connection: socket, now: 1.1)
        XCTAssertNil(engine.lobby.issue)
        XCTAssertEqual(engine.lobby.connection, .connected)
        XCTAssertFalse(engine.isClosed)
        engine.received(text: try session(version: 8, state: "lobby", localState: "waiting"), connection: socket, now: 1.2)
        XCTAssertTrue(try sent(engine).isEmpty, "Not resent on the same connection")
        XCTAssertEqual(engine.lobbyColors.localColor(preferred: engine.preferredColor), .sky)
    }

    func testColorHeldByAnotherPlayerIsAskedForOnceItIsFree() throws {
        let (engine, socket) = try connectedEngine(color: .plum)
        _ = engine.drainEffects()
        engine.received(text: try session(version: 7, state: "lobby", localState: "waiting", colors: [otherID: "plum"]),
                        connection: socket, now: 1)
        XCTAssertTrue(try sent(engine).isEmpty, "Plum is held: the claim would change nothing")
        XCTAssertTrue(engine.lobbyColors.isPreferredTaken(engine.preferredColor))
        XCTAssertNil(engine.lobbyColors.localColor(preferred: engine.preferredColor))
        XCTAssertEqual(engine.lobbyColors.color(of: otherID), .plum)

        engine.received(text: try session(version: 8, state: "lobby", localState: "waiting", colors: [otherID: "plum"],
                                          otherState: "left"), connection: socket, now: 1.1)
        XCTAssertEqual((try sent(engine).first?["payload"] as? [String: Any])?["color"] as? String, "plum")

        // Once the server shows the claim, it is not sent again.
        engine.received(text: try session(version: 9, state: "lobby", localState: "waiting", colors: [playerID: "plum"]),
                        connection: socket, now: 1.2)
        engine.selectColor(.plum, now: 1.3)
        XCTAssertTrue(try sent(engine).isEmpty)
        XCTAssertEqual(engine.lobbyColors.localClaim, .plum)
    }

    func testReadyLocksTheColorUntilTheReadyIsTakenBack() throws {
        let (engine, socket) = try connectedEngine(color: .plum)
        _ = engine.drainEffects()
        engine.received(text: try session(version: 7, state: "lobby", localState: "ready",
                                          colors: [otherID: "plum", playerID: "sky"]), connection: socket, now: 1)
        XCTAssertTrue(engine.lobbyColors.isLocked)
        XCTAssertEqual(try claims(engine), [])

        // A pick while ready changes nothing, and the freed color is not claimed either.
        engine.selectColor(.olive, now: 1.1)
        XCTAssertEqual(engine.preferredColor, .plum)
        engine.received(text: try session(version: 8, state: "lobby", localState: "ready",
                                          colors: [otherID: "plum", playerID: "sky"], otherState: "left"),
                        connection: socket, now: 1.2)
        XCTAssertEqual(try claims(engine), [])

        // Not ready again: the wished color is asked for, and picks go through.
        engine.received(text: try session(version: 9, state: "lobby", localState: "waiting",
                                          colors: [otherID: "plum", playerID: "sky"], otherState: "left"),
                        connection: socket, now: 1.3)
        XCTAssertFalse(engine.lobbyColors.isLocked)
        XCTAssertEqual(try claims(engine), ["plum"])
        engine.selectColor(.olive, now: 1.4)
        XCTAssertEqual(try claims(engine), ["olive"])
    }

    func testNoColorIsAskedForWithoutAPick() throws {
        let (engine, socket) = try connectedEngine()
        _ = engine.drainEffects()
        engine.received(text: try session(version: 7, state: "lobby", localState: "waiting"), connection: socket, now: 1)
        XCTAssertTrue(try sent(engine).isEmpty)
        XCTAssertNil(engine.lobbyColors.localColor(preferred: engine.preferredColor))
    }

    // MARK: Helpers

    private func snapshotData(collection: String, field: String, value: Any) throws -> Data {
        try HouseTanksWireContractTests.data("roundPlaying") { payload in
            if collection.isEmpty { payload[field] = value }
            else if var items = payload[collection] as? [[String: Any]] {
                items[0][field] = value
                payload[collection] = items
            } else {
                var item = payload[collection] as! [String: Any]
                item[field] = value
                payload[collection] = item
            }
        }
    }

    private var otherID: String { "507f1f77bcf86cd799439022" }

    /// The colors claimed since the last drain (other room messages are left out).
    private func claims(_ engine: HouseTanksOnlineEngine) throws -> [String] {
        try sent(engine).filter { $0["type"] as? String == "houseTanks.selectColor" }
            .compactMap { ($0["payload"] as? [String: Any])?["color"] as? String }
    }

    private func rejection(id: String, code: String) throws -> String {
        let message: [String: Any] = [
            "protocolVersion": 2, "type": "gameSession.commandRejected", "sentAt": "2026-10-24T12:00:50.125Z",
            "messageId": id, "error": ["code": code, "args": [String](), "retryable": false],
        ]
        return String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
    }

    private func makeEngine(color: HouseTanksColor? = nil) -> HouseTanksOnlineEngine {
        HouseTanksOnlineEngine(context: .init(houseID: houseID, localPlayerID: playerID), preferredColor: color,
                               policy: .init(jitter: { 1 }), makeID: { [unowned self] in ids += 1; return "id\(ids)" })
    }

    private func connectedEngine(color: HouseTanksColor? = nil) throws -> (HouseTanksOnlineEngine, Int) {
        let engine = makeEngine(color: color)
        engine.start(isForeground: true, isLandscape: false, now: 0)
        guard case .ensureSession(_, let connection) = try XCTUnwrap(engine.drainEffects().first) else {
            XCTFail("No ensure effect")
            throw UnexpectedTestState()
        }
        engine.sessionResponse(try envelope(sessionPayload(version: 5, state: "lobby", localState: nil)),
                               retryAfter: nil, connection: connection, now: 0.1)
        guard case .openSocket(_, let socket) = try XCTUnwrap(engine.drainEffects().last) else {
            XCTFail("No socket opened")
            throw UnexpectedTestState()
        }
        engine.socketOpened(connection: socket, now: 0.2)
        engine.received(text: try fixture("welcome"), connection: socket, now: 0.3)
        engine.received(text: try session(version: 6, state: "lobby", localState: nil), connection: socket, now: 0.4)
        return (engine, socket)
    }

    private func sent(_ engine: HouseTanksOnlineEngine) throws -> [[String: Any]] {
        try engine.drainEffects().compactMap { effect in
            guard case .send(let text, _) = effect else { return nil }
            return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        }
    }

    private func types(_ engine: HouseTanksOnlineEngine) -> [String] {
        ((try? sent(engine)) ?? []).compactMap { $0["type"] as? String }
    }

    private func fixture(_ name: String, _ change: (inout [String: Any]) -> Void = { _ in }) throws -> String {
        String(decoding: try HouseTanksWireContractTests.data(name, change), as: UTF8.self)
    }

    private func envelope(_ payload: [String: Any]) throws -> HTTPResponse {
        .init(statusCode: 200, headers: [:], body: try JSONSerialization.data(withJSONObject: ["success": true, "data": payload]))
    }

    /// The shared session DTO with the local player in `localState` and a second member.
    private func sessionPayload(version: Int64, state: String, localState: String?,
                                readyWindowEndsAt: String? = nil, countdownEndsAt: String? = nil,
                                colors: [String: String]? = nil, otherState: String? = nil) -> [String: Any] {
        let other = otherState ?? (state == "countdown" || state == "running" ? "playing" : "waiting")
        var players: [[String: Any]] = [
            ["playerId": "507f1f77bcf86cd799439022", "state": other,
             "joinedAt": "2026-10-24T12:00:00Z", "readyAt": NSNull(),
             "leftAt": other == "left" ? "2026-10-24T12:00:20Z" : NSNull()],
        ]
        if let localState {
            players.insert(["playerId": playerID, "state": localState, "joinedAt": "2026-10-24T12:00:00Z",
                            "readyAt": NSNull(), "leftAt": localState == "left" ? "2026-10-24T12:00:31Z" : NSNull()], at: 0)
        }
        var payload: [String: Any] = [
            "sessionId": sessionID, "houseId": houseID, "gameKey": "houseTanks", "protocolVersion": 2,
            "mode": "realtime", "state": state,
            "rules": ["minimumPlayers": 2, "maximumPlayers": 8, "readyWindowMilliseconds": 30_000, "countdownMilliseconds": 3_000],
            "players": players, "createdBy": playerID, "createdAt": "2026-10-24T12:00:00Z", "updatedAt": "2026-10-24T12:00:30Z",
            "readyWindowEndsAt": readyWindowEndsAt ?? NSNull(), "countdownEndsAt": countdownEndsAt ?? NSNull(),
            "startedAt": NSNull(), "endedAt": NSNull(), "endReason": NSNull(), "version": version,
        ]
        if let colors { payload["lobbyState"] = ["colors": colors] }
        return payload
    }

    private func session(version: Int64, state: String, localState: String?,
                         readyWindowEndsAt: String? = nil, countdownEndsAt: String? = nil,
                         colors: [String: String]? = nil, otherState: String? = nil) throws -> String {
        let message: [String: Any] = [
            "protocolVersion": 2, "type": "gameSession.snapshot", "sentAt": "2026-10-24T12:00:30.125Z", "sequence": version,
            "payload": sessionPayload(version: version, state: state, localState: localState,
                                      readyWindowEndsAt: readyWindowEndsAt, countdownEndsAt: countdownEndsAt,
                                      colors: colors, otherState: otherState),
        ]
        return String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
    }
}
