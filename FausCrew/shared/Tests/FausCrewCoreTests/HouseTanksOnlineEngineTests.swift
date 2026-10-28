import Foundation
@testable import FausCrewCore
import XCTest

/// The FauseTanks room through the engine, with a mock server: PUT → socket →
/// welcome and session → join → ready → countdown preview, the heartbeat, the
/// update warning for an unknown map and the server arena.
final class HouseTanksOnlineEngineTests: XCTestCase {
    private let houseID = "507f1f77bcf86cd799439012"
    private let playerID = "507f1f77bcf86cd799439021"
    private let sessionID = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"
    private var ids = 0

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
        XCTAssertEqual(HouseTanksOnlineCopyKeys.roomStatus(engine.lobby), "house_tanks_online_lobby")
        engine.setReady(true, now: 0.6)
        let ready = try XCTUnwrap(sent(engine).first)
        XCTAssertEqual(ready["type"] as? String, "gameSession.setReady")
        XCTAssertEqual((ready["payload"] as? [String: Any])?["ready"] as? Bool, true)

        engine.received(text: try session(version: 8, state: "readyWindow", localState: "ready",
                                          readyWindowEndsAt: "2026-10-24T12:01:00Z"), connection: socket, now: 0.7)
        XCTAssertEqual(HouseTanksOnlineCopyKeys.roomStatus(engine.lobby), "house_tanks_online_ready_window")
        XCTAssertEqual(engine.lobby.readyCount, 1)
        XCTAssertEqual(engine.roomCountdown(at: 0.7), 30, "The window's end on the server clock")

        engine.received(text: try session(version: 9, state: "countdown", localState: "playing",
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

    // MARK: Helpers

    private func makeEngine() -> HouseTanksOnlineEngine {
        HouseTanksOnlineEngine(context: .init(houseID: houseID, localPlayerID: playerID),
                               policy: .init(jitter: { 1 }), makeID: { [unowned self] in ids += 1; return "id\(ids)" })
    }

    private func connectedEngine() throws -> (HouseTanksOnlineEngine, Int) {
        let engine = makeEngine()
        engine.start(isForeground: true, isLandscape: false, now: 0)
        guard case .ensureSession(_, let connection) = try XCTUnwrap(engine.drainEffects().first) else { throw XCTSkip("No ensure") }
        engine.sessionResponse(try envelope(sessionPayload(version: 5, state: "lobby", localState: nil)),
                               retryAfter: nil, connection: connection, now: 0.1)
        guard case .openSocket(_, let socket) = try XCTUnwrap(engine.drainEffects().last) else { throw XCTSkip("No socket") }
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
                                readyWindowEndsAt: String? = nil, countdownEndsAt: String? = nil) -> [String: Any] {
        let other = state == "countdown" || state == "running" ? "playing" : "waiting"
        var players: [[String: Any]] = [
            ["playerId": "507f1f77bcf86cd799439022", "state": other,
             "joinedAt": "2026-10-24T12:00:00Z", "readyAt": NSNull(), "leftAt": NSNull()],
        ]
        if let localState {
            players.insert(["playerId": playerID, "state": localState, "joinedAt": "2026-10-24T12:00:00Z",
                            "readyAt": NSNull(), "leftAt": localState == "left" ? "2026-10-24T12:00:31Z" : NSNull()], at: 0)
        }
        return [
            "sessionId": sessionID, "houseId": houseID, "gameKey": "houseTanks", "protocolVersion": 2,
            "mode": "realtime", "state": state,
            "rules": ["minimumPlayers": 2, "maximumPlayers": 8, "readyWindowMilliseconds": 30_000, "countdownMilliseconds": 3_000],
            "players": players, "createdBy": playerID, "createdAt": "2026-10-24T12:00:00Z", "updatedAt": "2026-10-24T12:00:30Z",
            "readyWindowEndsAt": readyWindowEndsAt ?? NSNull(), "countdownEndsAt": countdownEndsAt ?? NSNull(),
            "startedAt": NSNull(), "endedAt": NSNull(), "endReason": NSNull(), "version": version,
        ]
    }

    private func session(version: Int64, state: String, localState: String?,
                         readyWindowEndsAt: String? = nil, countdownEndsAt: String? = nil) throws -> String {
        let message: [String: Any] = [
            "protocolVersion": 2, "type": "gameSession.snapshot", "sentAt": "2026-10-24T12:00:30.125Z", "sequence": version,
            "payload": sessionPayload(version: version, state: state, localState: localState,
                                      readyWindowEndsAt: readyWindowEndsAt, countdownEndsAt: countdownEndsAt),
        ]
        return String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
    }
}
