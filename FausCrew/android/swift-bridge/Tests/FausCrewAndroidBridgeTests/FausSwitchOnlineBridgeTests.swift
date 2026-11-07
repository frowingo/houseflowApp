import XCTest
import FausCrewCore
@testable import FausCrewAndroidBridge

/// The Faus Switch room over JNI, driven by `shared/Fixtures/fausSwitchProtocol.json`:
/// effects carry the Faus Switch routes, the lobby carries the robot colors, the race is
/// drawn in the demo's frame contract and the tap answers with its feedback.
final class FausSwitchOnlineBridgeTests: XCTestCase {
    private let house = "507f1f77bcf86cd799439012"
    private let player = "507f1f77bcf86cd799439021"
    private let session = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"

    private func object(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    private func event(_ handle: Int32, _ fields: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: fields)
        return try object(fausSwitchOnlineEvent(handle, String(decoding: data, as: UTF8.self)))
    }

    private static var fixture: [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("shared/Fixtures/fausSwitchProtocol.json")
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

    /// The session in `state`; the local player is `local` (or absent when nil).
    private func sessionChange(state: String, local: String?) -> (inout [String: Any]) -> Void {
        { [player] payload in
            payload["state"] = state
            var players = (payload["players"] as? [[String: Any]] ?? []).filter { $0["playerId"] as? String != player }
            if let local {
                players.insert(["playerId": player, "state": local, "joinedAt": "2026-11-05T12:00:00Z",
                                "readyAt": NSNull(), "leftAt": NSNull()], at: 0)
            }
            players = players.map { var other = $0; if other["playerId"] as? String != player, state == "lobby" { other["state"] = "waiting" }; return other }
            payload["players"] = players
            if state == "lobby" { payload["countdownEndsAt"] = NSNull() }
        }
    }

    private func ensureBody(state: String) throws -> String {
        let http = try XCTUnwrap(Self.fixture["http"] as? [String: [String: Any]])
        var response = try XCTUnwrap(http["ensure"]?["response"] as? [String: Any])
        var data = try XCTUnwrap(response["data"] as? [String: Any])
        sessionChange(state: state, local: state == "lobby" ? nil : "playing")(&data)
        response["data"] = data
        return String(decoding: try JSONSerialization.data(withJSONObject: response), as: UTF8.self)
    }

    /// Start → session → socket → welcome → session snapshot; returns the handle's socket.
    private func connect(_ handle: Int32, state: String, local: String?) throws -> (socket: Int32, lobby: [String: Any]?) {
        let started = try event(handle, ["type": "start", "foreground": true, "landscape": true, "now": 0])
        let ensure = try XCTUnwrap((started["effects"] as? [[String: Any]])?.first)
        XCTAssertEqual(ensure["type"] as? String, "ensureSession")
        XCTAssertEqual(ensure["path"] as? String, "game/fausSwitch/session")
        let opened = try event(handle, ["type": "sessionResponse", "status": 200, "body": try ensureBody(state: state),
                                        "connection": try XCTUnwrap(ensure["connection"] as? Int), "now": 0.1])
        let socket = try XCTUnwrap((opened["effects"] as? [[String: Any]])?.last)
        XCTAssertEqual(socket["path"] as? String, "game/sessions/\(session)/realtime")
        let connection = Int32(try XCTUnwrap(socket["connection"] as? Int))
        _ = try event(handle, ["type": "socketOpened", "connection": Int(connection), "now": 0.2])
        _ = try object(fausSwitchOnlineReceive(handle, try serverText("welcome"), connection, 0.3))
        // Newer than the HTTP session (version 5), like a server push after the join.
        let snapshot = try object(fausSwitchOnlineReceive(handle, try serverText("sessionSnapshot") { payload in
            self.sessionChange(state: state, local: local)(&payload)
            payload["version"] = 6
        }, connection, 0.4))
        return (connection, snapshot["lobby"] as? [String: Any])
    }

    func testLobbyCarriesTheRobotColorsAndSkipsAHeldColor() throws {
        let handle = fausSwitchOnlineCreate(house, player, player, "", "ocean")
        defer { XCTAssertTrue(fausSwitchOnlineDestroy(handle)) }
        let (_, lobby) = try connect(handle, state: "lobby", local: "waiting")
        let room = try XCTUnwrap(lobby)
        XCTAssertEqual(room["isLobby"] as? Bool, true)
        XCTAssertEqual(room["isRematchRoom"] as? Bool, false)
        // The fixture's lobbyState: this player holds ocean, the housemate plum.
        let colors = try XCTUnwrap(room["colors"] as? [String: Any])
        XCTAssertEqual(colors["local"] as? String, "ocean")
        XCTAssertEqual(colors["localClaim"] as? String, "ocean")
        XCTAssertEqual(colors["takenByOthers"] as? [String], ["plum"])
        let participants = try XCTUnwrap(room["participants"] as? [[String: Any]])
        XCTAssertEqual(participants.first { $0["isLocal"] as? Bool == true }?["color"] as? String, "ocean")
        XCTAssertEqual(participants.first { $0["isLocal"] as? Bool == false }?["color"] as? String, "plum")

        // Plum is held: the pick is remembered but no claim is sent.
        let picked = try event(handle, ["type": "selectColor", "color": "plum", "now": 1])
        let sends = (picked["effects"] as? [[String: Any]] ?? []).filter { $0["type"] as? String == "send" }
        XCTAssertTrue(sends.isEmpty, "\(sends)")
        let after = try XCTUnwrap(picked["lobby"] as? [String: Any])
        let afterColors = try XCTUnwrap(after["colors"] as? [String: Any])
        XCTAssertEqual(afterColors["preferred"] as? String, "plum")
        XCTAssertEqual(afterColors["isPreferredTaken"] as? Bool, true)
        XCTAssertEqual(afterColors["local"] as? String, "ocean", "The server's claim stays until plum is free")

        // A free color is claimed.
        let free = try event(handle, ["type": "selectColor", "color": "forest", "now": 1.1])
        let claim = try XCTUnwrap((free["effects"] as? [[String: Any]])?.first { $0["type"] as? String == "send" })
        XCTAssertTrue((claim["text"] as? String ?? "").contains("forest"))
        XCTAssertEqual(try event(handle, ["type": "selectColor", "color": "rainbow", "now": 1.2])["ok"] as? Bool, false)
    }

    func testRaceFrameDrawsTheServerRaceAndTheTapFlips() throws {
        let handle = fausSwitchOnlineCreate(house, player, player, "", "")
        defer { XCTAssertTrue(fausSwitchOnlineDestroy(handle)) }
        XCTAssertEqual(try object(fausSwitchOnlineViewport(handle, 844, 390))["changed"] as? Bool, true)
        let (socket, _) = try connect(handle, state: "running", local: "playing")

        let before = try object(fausSwitchOnlineFrame(handle, 0.5))
        XCTAssertNil(before["frame"], "No race before its first snapshot")
        _ = try object(fausSwitchOnlineReceive(handle, try serverText("playing"), socket, 1))

        let first = try object(fausSwitchOnlineFrame(handle, 1.01))
        let frame = try XCTUnwrap(first["frame"] as? [String: Any])
        XCTAssertEqual(frame["phase"] as? String, "playing")
        let runners = try XCTUnwrap(frame["runners"] as? [[String: Any]])
        XCTAssertEqual(runners.map { $0["color"] as? String }, ["ocean", "plum"])
        XCTAssertEqual(runners.first { $0["local"] as? Bool == true }?["id"] as? String, player)
        XCTAssertEqual((frame["platforms"] as? [[String: Any]])?.count, 2)
        let match = try XCTUnwrap(first["match"] as? [String: Any])
        XCTAssertEqual(match["canFlip"] as? Bool, false, "No control yet")
        XCTAssertEqual(try event(handle, ["type": "flip", "now": 1.02])["flip"] as? String, "ignored")

        _ = try object(fausSwitchOnlineReceive(handle, try serverText("controlGranted"), socket, 1.03))
        XCTAssertEqual((try object(fausSwitchOnlineFrame(handle, 1.05))["match"] as? [String: Any])?["canFlip"] as? Bool, true)
        let flipped = try event(handle, ["type": "flip", "now": 1.05])
        XCTAssertEqual(flipped["flip"] as? String, "flipped")
        let send = try XCTUnwrap((flipped["effects"] as? [[String: Any]])?.first { $0["type"] as? String == "send" })
        XCTAssertTrue((send["text"] as? String ?? "").contains("fausSwitch.flip"))
        let local = try XCTUnwrap(((try object(fausSwitchOnlineFrame(handle, 1.06))["frame"] as? [String: Any])?["runners"]
            as? [[String: Any]])?.first { $0["local"] as? Bool == true })
        XCTAssertEqual(local["gravity"] as? String, "up", "The flip shows at once")
        XCTAssertEqual(try event(handle, ["type": "flip", "now": 1.07])["flip"] as? String, "unsupported")
    }

    func testResultPanelShowsThePersistedStandings() throws {
        let handle = fausSwitchOnlineCreate(house, player, player, "", "")
        defer { XCTAssertTrue(fausSwitchOnlineDestroy(handle)) }
        let (socket, _) = try connect(handle, state: "running", local: "playing")
        _ = try object(fausSwitchOnlineReceive(handle, try serverText("playing"), socket, 1))
        _ = try object(fausSwitchOnlineFrame(handle, 1.01))
        let ended = try object(fausSwitchOnlineReceive(handle, try serverText("result"), socket, 40))
        let haptics = (ended["effects"] as? [[String: Any]] ?? []).filter { $0["type"] as? String == "haptic" }
        XCTAssertEqual(haptics.first?["haptic"] as? String, "success", "This player won")

        let frame = try object(fausSwitchOnlineFrame(handle, 40.01))
        let match = try XCTUnwrap(frame["match"] as? [String: Any])
        XCTAssertEqual(match["showsResult"] as? Bool, true)
        XCTAssertTrue(match["noticeTitleKey"] is NSNull)
        let result = try XCTUnwrap(match["result"] as? [String: Any])
        let standings = try XCTUnwrap(result["standings"] as? [[String: Any]])
        XCTAssertEqual(standings.first?["id"] as? String, player)
        XCTAssertEqual(standings.first?["rank"] as? Int, 1)
        XCTAssertEqual(standings.first?["local"] as? Bool, true)
        XCTAssertNotNil(result["titleKey"] as? String)
        XCTAssertNotNil(frame["frame"], "The race stays drawn under the panel")
    }

    func testRematchRoomShowsItsOwnStatusUntilTheRace() throws {
        let handle = fausSwitchOnlineCreate(house, player, player, "previous-session", "")
        defer { XCTAssertTrue(fausSwitchOnlineDestroy(handle)) }
        let started = try event(handle, ["type": "start", "foreground": true, "landscape": true, "now": 0])
        let lobby = try XCTUnwrap(started["lobby"] as? [String: Any])
        XCTAssertEqual(lobby["isRematchRoom"] as? Bool, true)
        XCTAssertEqual(lobby["statusKey"] as? String, "faus_switch_online_rematch_room")
        XCTAssertEqual((try object(fausSwitchOnlineFrame(handle, 0.1))["match"] as? [String: Any])?["showsRematchRoom"] as? Bool,
                       true)
    }

    func testCatalogSaysWhetherTheRoomIsOpen() throws {
        let settings = String(decoding: try JSONSerialization.data(withJSONObject: Self.fixture["settings"] ?? [:]),
                              as: UTF8.self)
        let open = """
        {"success":true,"data":[{"gameKey":"fausSwitch","protocolVersion":2,"mode":"realtime","configVersion":1,
        "rules":{"minimumPlayers":2,"maximumPlayers":8,"readyWindowMilliseconds":30000,"countdownMilliseconds":3000},
        "settings":\(settings)}]}
        """
        let available = try object(fausSwitchCatalogResponse(house, 200, open))
        XCTAssertEqual(available["available"] as? Bool, true)
        XCTAssertEqual(available["maximumPlayers"] as? Int, 8)
        XCTAssertEqual(try object(fausSwitchCatalogResponse(house, 200, #"{"success":true,"data":[]}"#))["available"] as? Bool,
                       false)
        XCTAssertTrue(try object(fausSwitchCatalogResponse(house, 500, "oops"))["available"] is NSNull)
    }

    func testUnknownHandleFailsCleanly() throws {
        XCTAssertEqual(try object(fausSwitchOnlineFrame(9_999, 0))["ok"] as? Bool, false)
        XCTAssertEqual(try object(fausSwitchOnlineEvent(9_999, #"{"type":"tick","now":0}"#))["ok"] as? Bool, false)
        XCTAssertFalse(fausSwitchOnlineDestroy(9_999))
    }
}
