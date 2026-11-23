import XCTest
@testable import FausCrewAndroidBridge

final class PushRegistrationBridgeTests: XCTestCase {
    private func event(_ handle: Int32, _ fields: [String: Any]) throws -> [String: Any] {
        let json = String(decoding: try JSONSerialization.data(withJSONObject: fields), as: UTF8.self)
        return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(pushRegistrationEvent(handle, json).utf8)) as? [String: Any])
    }

    private func effects(_ result: [String: Any]) -> [[String: String]] {
        result["effects"] as? [[String: String]] ?? []
    }

    func testRegistrationAndSignOutThroughTheFacade() throws {
        let handle = pushRegistrationCreate()
        defer { XCTAssertTrue(pushRegistrationDestroy(handle)) }
        XCTAssertEqual(effects(try event(handle, ["type": "setSession", "userId": "u1"])), [])
        let registered = try event(handle, ["type": "setToken", "token": "t1"])
        XCTAssertEqual(effects(registered), [["type": "register", "token": "t1"]])
        XCTAssertEqual(registered["cleaningUp"] as? Bool, false)
        XCTAssertEqual(effects(try event(handle, ["type": "setToken", "token": "t1"])), [])

        let signedOut = try event(handle, ["type": "signOut", "reason": "userInitiated"])
        XCTAssertEqual(effects(signedOut), [["type": "unregister", "token": "t1"], ["type": "deleteLocalToken"]])
        XCTAssertEqual(signedOut["cleaningUp"] as? Bool, true)
        XCTAssertEqual(try event(handle, ["type": "unregisterFinished"])["cleaningUp"] as? Bool, true)
        XCTAssertEqual(try event(handle, ["type": "localTokenDeleted"])["cleaningUp"] as? Bool, false)
        _ = try event(handle, ["type": "setSession", "userId": "u2"])
        XCTAssertEqual(effects(try event(handle, ["type": "setToken", "token": "t2"])), [["type": "register", "token": "t2"]])
    }

    func testNullUserAndTokenClear() throws {
        let handle = pushRegistrationCreate()
        defer { _ = pushRegistrationDestroy(handle) }
        _ = try event(handle, ["type": "setSession", "userId": NSNull()])
        _ = try event(handle, ["type": "setToken", "token": NSNull()])
        XCTAssertEqual(effects(try event(handle, ["type": "signOut", "reason": "sessionRejected"])), [])
    }

    func testRejectedSessionOnlyDeletesTheLocalToken() throws {
        let handle = pushRegistrationCreate()
        defer { _ = pushRegistrationDestroy(handle) }
        _ = try event(handle, ["type": "setSession", "userId": "u1"])
        _ = try event(handle, ["type": "setToken", "token": "t1"])
        XCTAssertEqual(effects(try event(handle, ["type": "signOut", "reason": "accountDeleted"])), [["type": "deleteLocalToken"]])
    }

    func testBadInputIsRefused() throws {
        let handle = pushRegistrationCreate()
        defer { _ = pushRegistrationDestroy(handle) }
        for fields: [String: Any] in [["type": "nope"], ["type": "signOut", "reason": "other"], ["type": "signOut"],
                                      [:]] {
            XCTAssertEqual(try event(handle, fields)["ok"] as? Bool, false, "\(fields)")
        }
        XCTAssertEqual(pushRegistrationEvent(handle, "nope").contains(#""ok":false"#), true)
        XCTAssertEqual(try event(-3, ["type": "setToken"])["ok"] as? Bool, false)
        XCTAssertFalse(pushRegistrationDestroy(-3))
    }
}
