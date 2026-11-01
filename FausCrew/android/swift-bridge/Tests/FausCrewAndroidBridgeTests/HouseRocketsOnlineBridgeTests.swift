import XCTest
@testable import FausCrewAndroidBridge

final class HouseRocketsOnlineBridgeTests: XCTestCase {
    private let house = "507f1f77bcf86cd799439012"
    private let player = "507f1f77bcf86cd799439021"
    private let session = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"

    private func object(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    private func event(_ handle: Int32, _ fields: [String: Any]) throws -> [String: Any] {
        let data = try JSONSerialization.data(withJSONObject: fields)
        return try object(houseRocketsOnlineEvent(handle, String(decoding: data, as: UTF8.self)))
    }

    private static var fixture: [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("shared/Fixtures/houseRocketsProtocol.json")
        return (try? JSONSerialization.jsonObject(with: Data(contentsOf: url))) as? [String: Any] ?? [:]
    }

    private func serverText(_ name: String) throws -> String {
        let messages = try XCTUnwrap(Self.fixture["serverMessages"] as? [[String: Any]])
        let message = try XCTUnwrap(messages.first { $0["name"] as? String == name }?["message"])
        return String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
    }

    func testEffectsCarryRoutesAndTheLobbyModelFollowsTheEngine() throws {
        let handle = houseRocketsOnlineCreate(house, player, player, "")
        defer { XCTAssertTrue(houseRocketsOnlineDestroy(handle)) }

        let started = try event(handle, ["type": "start", "foreground": true, "landscape": false, "now": 0])
        let ensure = try XCTUnwrap((started["effects"] as? [[String: Any]])?.first)
        XCTAssertEqual(ensure["type"] as? String, "ensureSession")
        XCTAssertEqual(ensure["path"] as? String, "game/houseRockets/session")
        XCTAssertEqual(ensure["method"] as? String, "PUT")
        XCTAssertEqual(ensure["body"] as? String, #"{"houseId":"507f1f77bcf86cd799439012"}"#)
        XCTAssertEqual((started["lobby"] as? [String: Any])?["statusKey"] as? String, "house_rockets_online_connecting")

        let http = try XCTUnwrap(Self.fixture["http"] as? [String: [String: Any]])
        let body = String(decoding: try JSONSerialization.data(withJSONObject: XCTUnwrap(http["ensure"]?["response"])), as: UTF8.self)
        let connection = try XCTUnwrap(ensure["connection"] as? Int)
        let opened = try event(handle, ["type": "sessionResponse", "status": 200, "body": body,
                                        "connection": connection, "now": 0.1])
        let socket = try XCTUnwrap((opened["effects"] as? [[String: Any]])?.last)
        XCTAssertEqual(socket["type"] as? String, "openSocket")
        XCTAssertEqual(socket["path"] as? String, "game/sessions/\(session)/realtime")
        XCTAssertEqual(socket["query"] as? String, "protocolVersion=2")

        _ = try event(handle, ["type": "socketOpened", "connection": connection, "now": 0.2])
        let welcome = try object(houseRocketsOnlineReceive(handle, serverText("welcome"), Int32(connection), 0.3))
        XCTAssertEqual(welcome["ok"] as? Bool, true)
        let unchanged = try event(handle, ["type": "tick", "now": 0.31])
        XCTAssertNil(unchanged["lobby"], "Unchanged lobby state is not resent")

        let closed = try event(handle, ["type": "connectionFailed", "failure": "http", "status": 409,
                                        "connection": connection, "now": 0.4])
        let lobby = try XCTUnwrap(closed["lobby"] as? [String: Any])
        XCTAssertEqual(lobby["connection"] as? String, "failed")
        XCTAssertEqual((closed["effects"] as? [[String: Any]])?.first?["type"] as? String, "closeSocket")
        XCTAssertEqual(try object(houseRocketsOnlineFrame(handle, 0.5))["ok"] as? Bool, true)
        XCTAssertEqual(try event(handle, ["type": "mystery", "now": 1])["ok"] as? Bool, false)
    }

    func testUnknownHandle() throws {
        XCTAssertEqual(try object(houseRocketsOnlineFrame(-7, 0))["ok"] as? Bool, false)
        XCTAssertFalse(houseRocketsOnlineDestroy(-7))
        XCTAssertFalse(houseRocketsOnlineViewport(-7, 1, 1, 1, 1))
    }
}

final class GameCatalogBridgeTests: XCTestCase {
    func testCatalogAvailability() throws {
        func object(_ json: String) throws -> [String: Any] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
        }
        let listed = #"{"success":true,"data":[{"gameKey":"houseRockets","protocolVersion":2,"mode":"realtime","rules":{"minimumPlayers":2,"maximumPlayers":6,"readyWindowMilliseconds":30000,"countdownMilliseconds":3000}}]}"#
        XCTAssertEqual(try object(gameCatalogResponse("h", 200, listed))["available"] as? Bool, true)
        XCTAssertEqual(try object(gameCatalogResponse("h", 200, listed))["maximumPlayers"] as? Int, 6)
        XCTAssertEqual(try object(gameCatalogResponse("h", 200, #"{"success":true,"data":[]}"#))["available"] as? Bool, false)
        XCTAssertTrue(try object(gameCatalogResponse("h", 503, ""))["available"] is NSNull)
    }
}
