import XCTest
@testable import HouseFlowAndroidBridge

final class AppEventsBridgeTests: XCTestCase {
    private func event(_ handle: Int32, _ fields: [String: Any]) throws -> [String: Any] {
        let json = String(decoding: try JSONSerialization.data(withJSONObject: fields), as: UTF8.self)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(appEventsEvent(handle, json).utf8)) as? [String: Any])
    }

    func testChannelThroughTheFacade() throws {
        let handle = appEventsCreate()
        defer { XCTAssertTrue(appEventsDestroy(handle)) }
        _ = try event(handle, ["type": "setSelectedHouse", "houseId": "h1"])
        let opened = try event(handle, ["type": "setActive", "foreground": true, "authenticated": true, "now": 0])
        XCTAssertEqual(opened["path"] as? String, "events")
        let open = try XCTUnwrap((opened["effects"] as? [[String: Any]])?.last)
        XCTAssertEqual(open["type"] as? String, "openSocket")
        let connection = try XCTUnwrap(open["connection"] as? Int)
        _ = try event(handle, ["type": "received", "text": #"{"type":"ready"}"#, "connection": connection, "now": 0.1])
        let refreshed = try event(handle, ["type": "tick", "now": 1])
        let refresh = try XCTUnwrap((refreshed["effects"] as? [[String: Any]])?.first)
        XCTAssertEqual(refresh["type"] as? String, "refresh")
        XCTAssertEqual(refresh["profile"] as? Bool, true)
        XCTAssertEqual(refresh["houseId"] as? String, "h1")
        let refused = try event(handle, ["type": "connectionFailed", "status": 401, "connection": connection, "now": 2])
        XCTAssertEqual((refused["effects"] as? [[String: Any]])?.map { $0["type"] as? String }, ["closeSocket", "signedOut"])
        XCTAssertEqual(try event(-3, ["type": "tick"])["ok"] as? Bool, false)
    }
}
