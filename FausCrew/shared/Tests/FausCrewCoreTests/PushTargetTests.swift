import FausCrewCore
import XCTest

final class PushTargetTests: XCTestCase {
    func testFullData() throws {
        let target = try XCTUnwrap(PushTarget(data: [
            "houseId": "h1", "choreId": "c1", "notificationId": "n1", "type": "chore_reminder",
        ]))
        XCTAssertEqual(target.houseID, "h1")
        XCTAssertEqual(target.choreID, "c1")
        XCTAssertEqual(target.notificationID, "n1")
        XCTAssertEqual(target.kind, .choreReminder)
    }

    func testHouseIsRequired() {
        XCTAssertNil(PushTarget(data: [:]))
        XCTAssertNil(PushTarget(data: ["houseId": "  ", "choreId": "c1"]))
        XCTAssertNil(PushTarget(data: ["choreId": "c1"]))
    }

    func testBlankOptionalsAreAbsent() throws {
        let target = try XCTUnwrap(PushTarget(data: ["houseId": "h1", "choreId": "", "notificationId": " ", "type": ""]))
        XCTAssertNil(target.choreID)
        XCTAssertNil(target.notificationID)
        XCTAssertNil(target.kind)
    }

    func testUnknownTypeIsKept() throws {
        XCTAssertEqual(try XCTUnwrap(PushTarget(data: ["houseId": "h1", "type": "badge"])).kind, .unknown("badge"))
    }

    func testUserInfoKeepsOnlyStringValuesOfKnownKeys() throws {
        let userInfo: [AnyHashable: Any] = [
            "houseId": "h1", "choreId": 42, "notificationId": "n1", "type": "announcement",
            "aps": ["alert": "x"], "gcm.message_id": "m", 1: "odd",
        ]
        let target = try XCTUnwrap(PushTarget(userInfo: userInfo))
        XCTAssertEqual(target, PushTarget(data: ["houseId": "h1", "notificationId": "n1", "type": "announcement"]))
        XCTAssertNil(target.choreID)
        XCTAssertNil(PushTarget(userInfo: ["houseId": 7]))
    }
}
