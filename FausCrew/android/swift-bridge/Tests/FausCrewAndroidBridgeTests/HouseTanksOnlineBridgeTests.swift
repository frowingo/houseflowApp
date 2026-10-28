import XCTest
@testable import FausCrewAndroidBridge

/// The FauseTanks room over JNI: effects carry the tanks routes, the lobby model uses
/// the shared keys, and the countdown snapshot sends the drawn arena once.
final class HouseTanksOnlineBridgeTests: XCTestCase {
    private let house = "507f1f77bcf86cd799439012"
    private let player = "507f1f77bcf86cd799439021"
    private let session = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"

    private func object(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    private func event(_ handle: Int32, _ fields: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: fields)
        return try object(houseTanksOnlineEvent(handle, String(decoding: data, as: UTF8.self)))
    }

    private static var fixture: [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("shared/Fixtures/houseTanksProtocol.json")
        return (try? JSONSerialization.jsonObject(with: Data(contentsOf: url))) as? [String: Any] ?? [:]
    }

    private func serverText(_ name: String, _ change: (inout [String: Any]) -> Void = { _ in }) throws -> String {
        let messages = try XCTUnwrap(Self.fixture["serverMessages"] as? [[String: Any]])
        var message = try XCTUnwrap(messages.first { $0["name"] as? String == name }?["message"] as? [String: Any])
        if var payload = message["payload"] as? [String: Any] {
            change(&payload)
            message["payload"] = payload
        }
        return String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
    }

    private func sessionPayload(state: String, version: Int) -> [String: Any] {
        [
            "sessionId": session, "houseId": house, "gameKey": "houseTanks", "protocolVersion": 2,
            "mode": "realtime", "state": state,
            "rules": ["minimumPlayers": 2, "maximumPlayers": 8, "readyWindowMilliseconds": 30_000, "countdownMilliseconds": 3_000],
            // Before the join only the housemate is in the room.
            "players": [["playerId": state == "countdown" ? player : "507f1f77bcf86cd799439022",
                         "state": state == "countdown" ? "playing" : "waiting",
                         "joinedAt": "2026-10-24T12:00:00Z", "readyAt": NSNull(), "leftAt": NSNull()]],
            "createdBy": player, "createdAt": "2026-10-24T12:00:00Z", "updatedAt": "2026-10-24T12:00:30Z",
            "readyWindowEndsAt": NSNull(), "countdownEndsAt": state == "countdown" ? "2026-10-24T12:00:33Z" : NSNull(),
            "startedAt": NSNull(), "endedAt": NSNull(), "endReason": NSNull(), "version": version,
        ]
    }

    private func sessionText(state: String, version: Int) throws -> String {
        let message: [String: Any] = ["protocolVersion": 2, "type": "gameSession.snapshot", "sequence": version,
                                      "sentAt": "2026-10-24T12:00:30.125Z", "payload": sessionPayload(state: state, version: version)]
        return String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
    }

    func testRoomFlowSendsTanksRoutesAndTheDrawnArena() throws {
        let handle = houseTanksOnlineCreate(house, player, "", "")
        defer { XCTAssertTrue(houseTanksOnlineDestroy(handle)) }

        let started = try event(handle, ["type": "start", "foreground": true, "landscape": false, "now": 0])
        let ensure = try XCTUnwrap((started["effects"] as? [[String: Any]])?.first)
        XCTAssertEqual(ensure["type"] as? String, "ensureSession")
        XCTAssertEqual(ensure["path"] as? String, "game/houseTanks/session")
        XCTAssertEqual(ensure["method"] as? String, "PUT")
        XCTAssertEqual((started["lobby"] as? [String: Any])?["statusKey"] as? String, "house_tanks_online_connecting")
        XCTAssertTrue(started["preview"] is NSNull, "The first output says there is no arena yet")

        let body = String(decoding: try JSONSerialization.data(withJSONObject: ["success": true,
            "data": sessionPayload(state: "lobby", version: 5)]), as: UTF8.self)
        let connection = try XCTUnwrap(ensure["connection"] as? Int)
        let opened = try event(handle, ["type": "sessionResponse", "status": 200, "body": body,
                                        "connection": connection, "now": 0.1])
        let socket = try XCTUnwrap((opened["effects"] as? [[String: Any]])?.last)
        XCTAssertEqual(socket["path"] as? String, "game/sessions/\(session)/realtime")
        let socketConnection = try XCTUnwrap(socket["connection"] as? Int)
        XCTAssertNil(opened["preview"], "An unchanged arena is not resent")

        _ = try event(handle, ["type": "socketOpened", "connection": socketConnection, "now": 0.2])
        _ = try object(houseTanksOnlineReceive(handle, serverText("welcome"), Int32(socketConnection), 0.3))
        let joined = try object(houseTanksOnlineReceive(handle, sessionText(state: "lobby", version: 6),
                                                        Int32(socketConnection), 0.4))
        let join = try XCTUnwrap((joined["effects"] as? [[String: Any]])?.first { $0["type"] as? String == "send" })
        XCTAssertTrue((join["text"] as? String)?.contains("gameSession.join") == true)
        let lobby = try XCTUnwrap(joined["lobby"] as? [String: Any])
        XCTAssertEqual(lobby["requiresUpdate"] as? Bool, false)
        XCTAssertEqual(lobby["minimumPlayers"] as? Int, 2)

        _ = try object(houseTanksOnlineReceive(handle, sessionText(state: "countdown", version: 7),
                                               Int32(socketConnection), 0.5))
        let countdown = try object(houseTanksOnlineReceive(handle, serverText("countdown"), Int32(socketConnection), 0.6))
        let preview = try XCTUnwrap(countdown["preview"] as? [String: Any])
        XCTAssertEqual(preview["mapId"] as? String, "livingRoom")
        let seats = try XCTUnwrap(preview["seats"] as? [[String: Any]])
        XCTAssertEqual(seats.map { $0["color"] as? String }, ["plum", "orange", "blue"])
        XCTAssertEqual(try XCTUnwrap(seats.first?["x"] as? Double), 0.1, accuracy: 1e-9)
        let participants = try XCTUnwrap((countdown["lobby"] as? [String: Any])?["participants"] as? [[String: Any]])
        XCTAssertEqual(participants.first?["name"] as? String, "Deniz")
        XCTAssertEqual(participants.first?["color"] as? String, "plum")
        XCTAssertNotNil((countdown["lobby"] as? [String: Any])?["flightCountdownUptime"] as? Double)
    }

    func testMatchFrameDrawsTheServerArenaAndTheButtonSendsPresses() throws {
        let handle = houseTanksOnlineCreate(house, player, "", "")
        defer { XCTAssertTrue(houseTanksOnlineDestroy(handle)) }
        let started = try event(handle, ["type": "start", "foreground": true, "landscape": true, "now": 0])
        let connection = try XCTUnwrap((started["effects"] as? [[String: Any]])?.first?["connection"] as? Int)
        var running = sessionPayload(state: "running", version: 8)
        running["players"] = [["playerId": player, "state": "playing", "joinedAt": "2026-10-24T12:00:00Z",
                               "readyAt": NSNull(), "leftAt": NSNull()]]
        let body = String(decoding: try JSONSerialization.data(withJSONObject: ["success": true, "data": running]), as: UTF8.self)
        let opened = try event(handle, ["type": "sessionResponse", "status": 200, "body": body, "connection": connection, "now": 0.1])
        let socket = try XCTUnwrap((opened["effects"] as? [[String: Any]])?.last?["connection"] as? Int)
        _ = try event(handle, ["type": "socketOpened", "connection": socket, "now": 0.2])
        _ = try object(houseTanksOnlineReceive(handle, serverText("welcome"), Int32(socket), 0.3))
        let sessionMessage: [String: Any] = ["protocolVersion": 2, "type": "gameSession.snapshot", "sequence": 9,
                                             "sentAt": "2026-10-24T12:00:30.125Z", "payload": running]
        _ = try object(houseTanksOnlineReceive(handle, String(decoding: try JSONSerialization.data(withJSONObject: sessionMessage),
                                                                as: UTF8.self), Int32(socket), 0.35))
        _ = try object(houseTanksOnlineReceive(handle, serverText("controlGranted"), Int32(socket), 0.4))

        var empty = try object(houseTanksOnlineFrame(handle, 0.45))
        XCTAssertNil(empty["frame"], "No arena before the first snapshot")
        XCTAssertEqual((empty["match"] as? [String: Any])?["canPress"] as? Bool, false)

        _ = try object(houseTanksOnlineReceive(handle, serverText("roundPlaying"), Int32(socket), 0.5))
        let first = try object(houseTanksOnlineFrame(handle, 0.55))
        let frame = try XCTUnwrap(first["frame"] as? [String: Any])
        XCTAssertNotNil(frame["arena"], "The first frame of a round carries the static arena")
        XCTAssertEqual((frame["tanks"] as? [[String: Any]])?.count, 3)
        XCTAssertEqual((frame["tanks"] as? [[String: Any]])?.first?["role"] as? String, "human")
        XCTAssertEqual((frame["players"] as? [[String: Any]])?.first?["nameKey"] as? String, "Deniz")
        let match = try XCTUnwrap(first["match"] as? [String: Any])
        XCTAssertEqual(match["canPress"] as? Bool, true)
        XCTAssertEqual(match["roundPhase"] as? String, "roundPlaying")
        XCTAssertEqual(match["isSpectating"] as? Bool, false)
        XCTAssertEqual((match["seats"] as? [[String: Any]])?.map { $0["name"] as? String }, ["Deniz", "Ece", "Ada"])
        empty = try object(houseTanksOnlineFrame(handle, 0.56))
        XCTAssertNil((empty["frame"] as? [String: Any])?["arena"], "The arena is not resent within a round")
        XCTAssertEqual(empty["fps"] as? Int, 3, "Every frame carries the HUD's frame rate: three drawn this second")
        XCTAssertEqual(try event(handle, ["type": "setDiagnostics", "enabled": true, "now": 0.57])["ok"] as? Bool, false,
                       "The debug panel is gone; the FPS chip replaced it")

        let pressed = try event(handle, ["type": "press", "now": 0.6])
        let send = try XCTUnwrap((pressed["effects"] as? [[String: Any]])?.first { $0["type"] as? String == "send" })
        XCTAssertTrue((send["text"] as? String)?.contains("houseTanks.press") == true)

        // Between rounds: the panel and the vote.
        _ = try object(houseTanksOnlineReceive(handle, serverText("roundPlaying") { payload in
            payload["stateSequence"] = (payload["stateSequence"] as! Int) + 1
            payload["tick"] = (payload["tick"] as! Int) + 6
            payload["roundPhase"] = "roundReady"
            payload["roundWinnerId"] = self.player
        }, Int32(socket), 0.65))
        let between = try XCTUnwrap(try object(houseTanksOnlineFrame(handle, 0.66))["match"] as? [String: Any])
        XCTAssertEqual(between["showsRoundPanel"] as? Bool, true)
        XCTAssertEqual(between["roundTitleKey"] as? String, "house_tanks_online_round_won")
        XCTAssertEqual(between["canVote"] as? Bool, true)
        XCTAssertTrue(between["noticeTitleKey"] is NSNull)
        let voted = try event(handle, ["type": "setRoundReady", "ready": true, "now": 0.67])
        let vote = try XCTUnwrap((voted["effects"] as? [[String: Any]])?.first { $0["type"] as? String == "send" })
        XCTAssertTrue((vote["text"] as? String)?.contains("houseTanks.roundReady") == true)
        let shown = try XCTUnwrap(try object(houseTanksOnlineFrame(handle, 0.68))["match"] as? [String: Any])
        XCTAssertEqual(shown["isLocalReady"] as? Bool, true)
        XCTAssertEqual((shown["seats"] as? [[String: Any]])?.first?["roundReady"] as? Bool, true)

        // The result replaces the banners; the seat bar stays.
        _ = try object(houseTanksOnlineReceive(handle, serverText("result"), Int32(socket), 0.8))
        let ended = try XCTUnwrap(try object(houseTanksOnlineFrame(handle, 0.81))["match"] as? [String: Any])
        XCTAssertEqual(ended["showsResult"] as? Bool, true)
        XCTAssertEqual(ended["isFinished"] as? Bool, true)
        XCTAssertEqual((ended["seats"] as? [[String: Any]])?.count, 3)
        let result = try XCTUnwrap(ended["result"] as? [String: Any])
        XCTAssertEqual(result["titleKey"] as? String, "house_tanks_champion_you")
        XCTAssertEqual(result["canRematch"] as? Bool, true)
        XCTAssertEqual((result["players"] as? [[String: Any]])?.map { $0["rank"] as? Int }, [1, 2, 2])
        XCTAssertEqual((result["players"] as? [[String: Any]])?.first?["name"] as? String, "Deniz")
    }

    func testCatalogSaysWhetherTheRoomIsOpen() throws {
        let closed = try object(houseTanksCatalogResponse(house, 200, #"{"success":true,"data":[]}"#))
        XCTAssertEqual(closed["available"] as? Bool, false)
        let unreadable = try object(houseTanksCatalogResponse(house, 500, "{}"))
        XCTAssertTrue(unreadable["available"] is NSNull)
    }
}
