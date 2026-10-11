import XCTest
@testable import HouseFlowAndroidBridge

final class InviteCodeBridgeTests: XCTestCase {
    func testVersionAndCoreRule() {
        XCTAssertEqual(bridgeVersion(), 2)
        XCTAssertEqual(normalizeInviteCode("ab-12 cd34xyz"), "AB12CD34")
        XCTAssertEqual(normalizeInviteCode(""), "")
        XCTAssertEqual(normalizeInviteCode("１２３４５６７８ 12345678"), "12345678")
    }

    func testAuthWireFacadePreservesCoreLoginAndFailureRules() throws {
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(loginRequestBody("ada@example.com", "s3cret").utf8)) as? [String: String])
        XCTAssertEqual(body["email"], "ada@example.com")
        XCTAssertEqual(body["password"], "s3cret")

        let token = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(loginResponse(200, #"{"token":"abc"}"#).utf8)) as? [String: Any])
        XCTAssertEqual(token["ok"] as? Bool, true)
        XCTAssertEqual(token["token"] as? String, "abc")

        let failure = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(loginResponse(401, #"{"message":"Invalid credentials"}"#).utf8)) as? [String: Any])
        XCTAssertEqual(failure["ok"] as? Bool, false)
        XCTAssertEqual(failure["message"] as? String, "Invalid credentials")
    }
}
