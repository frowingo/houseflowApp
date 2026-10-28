import Foundation
@testable import FausCrewCore
import XCTest

/// The shared online lobby machine running FauseTanks: connection, update
/// checks, HTTP failures, cancellation and the control gate for gameplay.
final class HouseTanksOnlineLobbyTests: XCTestCase {
    private let houseID = "507f1f77bcf86cd799439012"
    private let playerID = "507f1f77bcf86cd799439021"
    private let sessionID = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"
    private var effects: [GameOnlineEffect] = []
    private var states: [HouseTanksOnlineLobbyState] = []
    private var ids = 0

    func testLobbyConnectsAndJoinsWithTheSharedCommands() throws {
        let (lobby, socket) = try connectedLobby()
        XCTAssertEqual(lobby.state.connection, .connected)
        XCTAssertTrue(lobby.state.isSynced)
        XCTAssertEqual(lobby.state.runtimeSettings, .releaseDefaults)
        XCTAssertEqual(try sent().map { $0["type"] as? String }, ["gameSession.join"])

        lobby.received(text: try session(version: 7, localState: "waiting"), connection: socket, now: 1)
        XCTAssertNil(lobby.state.pendingCommand, "Roster proof confirms the join")
        lobby.setReady(true, now: 1.1)
        XCTAssertEqual(try sent().first?["type"] as? String, "gameSession.setReady")

        lobby.tick(now: 2.6)
        XCTAssertEqual(try sent().first?["type"] as? String, "realtime.ping", "Heartbeat follows controlHeartbeatMilliseconds")
    }

    func testIncompatibleWelcomeAsksForAnUpdateWithoutRetrying() throws {
        let (lobby, socket) = try openedLobby()
        lobby.received(text: try fixture("welcome") { $0["contractRevision"] = "houseTanks.v3" }, connection: socket, now: 0.3)
        XCTAssertEqual(lobby.state.connection, .failed)
        XCTAssertTrue(lobby.state.requiresUpdate)
        XCTAssertFalse(lobby.state.canReconnect(at: 100))
        effects = []
        lobby.tick(now: 30)
        XCTAssertFalse(effects.contains { if case .openSocket = $0 { return true }; return false }, "No automatic reconnect")
    }

    func testUnknownMapInASnapshotAsksForAnUpdate() throws {
        let (lobby, socket) = try connectedLobby(state: "running")
        lobby.received(text: try fixture("roundPlaying") { $0["mapId"] = "attic" }, connection: socket, now: 1)
        XCTAssertEqual(lobby.state.issue, .connection(.protocolFailure(.unsupportedMap("attic", 3))))
        XCTAssertTrue(lobby.state.requiresUpdate)
    }

    func testHTTPFailuresOfTheSessionRequest() throws {
        func ensure(_ status: Int, code: String? = nil, retryAfter: TimeInterval? = nil) throws -> HouseTanksOnlineLobbyState {
            effects = []
            let lobby = makeLobby()
            lobby.start(isForeground: true, isLandscape: true, now: 0)
            let connection = try ensureConnection()
            let body = code.map { #"{"success":false,"error":"\#($0)"}"# } ?? #"{"success":false}"#
            lobby.sessionResponse(.init(statusCode: status, headers: [:], body: Data(body.utf8)),
                                  retryAfter: retryAfter, connection: connection, now: 0.1)
            return lobby.state
        }
        let unauthorized = try ensure(401)
        XCTAssertTrue(unauthorized.requiresAuthentication)
        XCTAssertEqual(unauthorized.connection, .failed)
        XCTAssertFalse(unauthorized.canReconnect(at: 100))

        let forbidden = try ensure(403)
        XCTAssertEqual(forbidden.connection, .failed)
        XCTAssertFalse(forbidden.canReconnect(at: 100))

        let missing = try ensure(404)
        XCTAssertEqual(missing.connection, .failed)
        XCTAssertTrue(missing.canReconnect(at: 100), "The player may try again")

        let unavailable = try ensure(409, code: GameErrorCode.unavailable)
        XCTAssertEqual(unavailable.issue, .connection(.protocolFailure(.gameUnavailable)))
        XCTAssertFalse(unavailable.canReconnect(at: 100))
        XCTAssertFalse(unavailable.requiresUpdate)

        let limited = try ensure(429, retryAfter: 3)
        XCTAssertEqual(limited.connection, .reconnecting)
        XCTAssertGreaterThanOrEqual(limited.retryNotBefore ?? 0, 3.1, "Retry-After is the floor")

        let busy = try ensure(503)
        XCTAssertEqual(busy.connection, .reconnecting)
    }

    func testCreatorCancelsTheMatch() throws {
        let (lobby, socket) = try connectedLobby()
        lobby.received(text: try session(version: 7, localState: "waiting"), connection: socket, now: 0.5)
        _ = try sent()
        XCTAssertTrue(lobby.state.canCancel(context: context))
        lobby.cancelMatch(now: 1)
        XCTAssertEqual(try sent().first?["type"] as? String, "gameSession.cancel")
    }

    func testGameplayNeedsTheCurrentGrantAndAPlayingSnapshot() throws {
        let (lobby, socket) = try connectedLobby(state: "running")
        lobby.received(text: try fixture("controlGranted"), connection: socket, now: 1)
        let grant = try XCTUnwrap(lobby.state.controlGrant)
        XCTAssertNil(lobby.state.validControl(playerID: playerID), "No playing snapshot yet")

        lobby.received(text: try fixture("roundPlaying"), connection: socket, now: 1.05)
        XCTAssertEqual(lobby.state.validControl(playerID: playerID), grant)
        _ = try sent()
        XCTAssertTrue(lobby.sendGameplay(press(generation: "controlA"), grant: grant, now: 1.1))
        let message = try XCTUnwrap(try sent().first)
        XCTAssertEqual(message["type"] as? String, "houseTanks.press")
        XCTAssertFalse(lobby.sendGameplay(press(generation: "controlB"), grant: grant, now: 1.2), "Another generation")
        XCTAssertTrue(try sent().isEmpty)

        // The tank's own generation disappears in the same epoch: another device took control.
        lobby.received(text: try fixture("roundPlaying") { payload in
            payload["stateSequence"] = 211
            var players = payload["players"] as! [[String: Any]]
            players[0]["controlGeneration"] = NSNull()
            payload["players"] = players
        }, connection: socket, now: 1.3)
        XCTAssertTrue(lobby.state.controlTransferred)
        XCTAssertNil(lobby.state.validControl(playerID: playerID))
    }

    func testEndedSnapshotIsTerminalAndLeftPlayersStayLeft() throws {
        let (lobby, socket) = try connectedLobby(state: "running")
        lobby.received(text: try fixture("ended"), connection: socket, now: 1)
        XCTAssertTrue(lobby.state.isTerminal)

        let (other, otherSocket) = try connectedLobby(state: "running")
        other.received(text: try fixture("ended") { $0["phase"] = "playing"; $0["roundPhase"] = "roundReady"; $0["championId"] = NSNull() },
                       connection: otherSocket, now: 1)
        other.received(text: try fixture("ended") { payload in
            payload["phase"] = "playing"; payload["roundPhase"] = "roundReady"; payload["championId"] = NSNull()
            payload["stateSequence"] = 3_306
            var players = payload["players"] as! [[String: Any]]
            players[2]["hasLeft"] = false
            payload["players"] = players
        }, connection: otherSocket, now: 1.1)
        XCTAssertEqual(other.state.issue, .connection(.invalidPayload), "A player who left cannot come back")
    }

    // MARK: Helpers

    private var context: GameLaunchContext { .init(houseID: houseID, localPlayerID: playerID, houseOwnerID: nil) }

    private func makeLobby() -> HouseTanksOnlineLobbyMachine {
        let lobby = HouseTanksOnlineLobbyMachine(context: context, excludingSessionID: nil,
            policy: .init(jitter: { 1 }), makeID: { [unowned self] in ids += 1; return "id\(ids)" },
            emit: { [unowned self] in effects.append($0) })
        lobby.onStateChange = { [unowned self] in states.append($0) }
        return lobby
    }

    private func openedLobby(state: String = "lobby") throws -> (HouseTanksOnlineLobbyMachine, Int) {
        effects = []
        let lobby = makeLobby()
        lobby.start(isForeground: true, isLandscape: true, now: 0)
        let connection = try ensureConnection()
        let response = try JSONSerialization.data(withJSONObject: ["success": true, "data": sessionPayload(version: 5, state: state, localState: nil)])
        lobby.sessionResponse(.init(statusCode: 200, headers: [:], body: response), retryAfter: nil, connection: connection, now: 0.1)
        guard case .openSocket(let id, let socket) = try XCTUnwrap(effects.last) else { throw XCTSkip("No socket") }
        XCTAssertEqual(id, sessionID)
        lobby.socketOpened(connection: socket, now: 0.2)
        return (lobby, socket)
    }

    private func connectedLobby(state: String = "lobby") throws -> (HouseTanksOnlineLobbyMachine, Int) {
        let (lobby, socket) = try openedLobby(state: state)
        lobby.received(text: try fixture("welcome"), connection: socket, now: 0.3)
        lobby.received(text: try session(version: 6, state: state, localState: state == "lobby" ? nil : "playing"),
                       connection: socket, now: 0.4)
        return (lobby, socket)
    }

    private func ensureConnection() throws -> Int {
        guard case .ensureSession(let house, let connection) = try XCTUnwrap(effects.first) else { throw XCTSkip("No ensure") }
        XCTAssertEqual(house, houseID)
        return connection
    }

    private func sent() throws -> [[String: Any]] {
        defer { effects.removeAll() }
        return try effects.compactMap { effect in
            guard case .send(let text, _) = effect else { return nil }
            return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        }
    }

    private func press(generation: String) -> HouseTanksClientMessage {
        .init(messageId: "p\(ids)", action: .gameplay(.press(controlGeneration: generation, inputSequence: 1,
                                                            pressed: true, clientTick: 1_200, heading: 0.42)))
    }

    private func fixture(_ name: String, _ change: (inout [String: Any]) -> Void = { _ in }) throws -> String {
        String(decoding: try HouseTanksWireContractTests.data(name, change), as: UTF8.self)
    }

    /// The shared session DTO (identical for every game) with the local player in `localState`.
    private func sessionPayload(version: Int64, state: String, localState: String?) -> [String: Any] {
        var players: [[String: Any]] = [
            ["playerId": "507f1f77bcf86cd799439022", "state": state == "lobby" ? "waiting" : "playing",
             "joinedAt": "2026-10-24T12:00:00Z", "readyAt": NSNull(), "leftAt": NSNull()],
        ]
        if let localState {
            players.insert(["playerId": playerID, "state": localState, "joinedAt": "2026-10-24T12:00:00Z",
                            "readyAt": NSNull(), "leftAt": NSNull()], at: 0)
        }
        return [
            "sessionId": sessionID, "houseId": houseID, "gameKey": "houseTanks", "protocolVersion": 2,
            "mode": "realtime", "state": state,
            "rules": ["minimumPlayers": 2, "maximumPlayers": 8, "readyWindowMilliseconds": 30_000, "countdownMilliseconds": 3_000],
            "players": players, "createdBy": playerID, "createdAt": "2026-10-24T12:00:00Z", "updatedAt": "2026-10-24T12:00:30Z",
            "readyWindowEndsAt": NSNull(), "countdownEndsAt": NSNull(), "startedAt": state == "running" ? "2026-10-24T12:00:33Z" : NSNull(),
            "endedAt": NSNull(), "endReason": NSNull(), "version": version,
        ]
    }

    private func session(version: Int64, state: String = "lobby", localState: String?) throws -> String {
        let message: [String: Any] = [
            "protocolVersion": 2, "type": "gameSession.snapshot", "sentAt": "2026-10-24T12:00:30.125Z", "sequence": version,
            "payload": sessionPayload(version: version, state: state, localState: localState),
        ]
        return String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
    }
}
