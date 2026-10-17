import XCTest
@testable import HouseFlowAndroidBridge

final class InviteCodeBridgeTests: XCTestCase {
    func testVersionAndCoreRule() {
        XCTAssertEqual(bridgeVersion(), 9)
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

    func testAdditionalAuthFacadeUsesCoreDtosAndActions() throws {
        let signup = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(signupRequestBody("ada@example.com", "secret", "Ada", "A").utf8)) as? [String: String])
        XCTAssertEqual(signup["lastName"], "A")
        let reset = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(resetPasswordRequestBody("ada@example.com", "123456", "new").utf8)) as? [String: String])
        XCTAssertEqual(reset["newPassword"], "new")
        let success = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(authActionResponse("verifyEmail", 200, #"{"success":true}"#).utf8)) as? [String: Any])
        XCTAssertEqual(success["ok"] as? Bool, true)
        let invalidCode = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(authActionResponse("verifyEmail", 200, #"{"success":false}"#).utf8)) as? [String: Any])
        XCTAssertEqual(invalidCode["ok"] as? Bool, false)
        XCTAssertEqual(invalidCode["message"] as? String, "The verification code is invalid.")
        let failure = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(authActionResponse("verifyEmail", 400, #"{"message":"Wrong code"}"#).utf8)) as? [String: Any])
        XCTAssertEqual(failure["message"] as? String, "Wrong code")
    }

    func testHouseFacadeValidatesCreateAndDetailsBeforeAndroidRoute() throws {
        let create = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
            houseRequestBody("create", "", "", "Home", "", 2, 5, "").utf8
        )) as? [String: Any])
        XCTAssertEqual(create["name"] as? String, "Home")
        let join = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
            houseRequestBody("join", "", "", "", "ab-12 cd34", 0, 0, "").utf8
        )) as? [String: Any])
        XCTAssertEqual(join["inviteCode"] as? String, "AB12CD34")
        let validHouse = #"{"success":true,"data":{"id":"h","name":"Home","inviteCode":null,"maxMemberCount":4,"memberIds":[],"ownerId":"u","profileImage":"","type":1,"createdOn":"2026-01-01","updatedOn":"2026-01-02"}}"#
        XCTAssertEqual(houseResponse("create", 200, validHouse), validHouse)
        let malformed = #"{"success":true,"data":{"id":"h","name":"Home"}}"#
        let failure = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(houseResponse("details", 200, malformed).utf8)) as? [String: Any])
        XCTAssertEqual(failure["success"] as? Bool, false)
    }

    func testDashboardFacadeUsesCoreRequestAndRejectsMalformedResult() throws {
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(dashboardRequestBody(
            "create", "h", "", "u", "Kitchen", "Dishes", "2026-10-12T00:00:00Z",
            true, 20, 7, 0, false
        ).utf8)) as? [String: Any])
        XCTAssertEqual(body["houseId"] as? String, "h")
        XCTAssertEqual(body["recurringInterval"] as? Int, 7)
        let denied = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(dashboardResponse(
            "announcement", 200, #"{"success":false,"error":"Denied"}"#
        ).utf8)) as? [String: Any])
        XCTAssertEqual(denied["ok"] as? Bool, false)
        XCTAssertEqual(denied["message"] as? String, "Denied")
    }

    func testProfileFacadeUsesOptionalFieldsAndRejectsMissingPayload() throws {
        let body = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
            profileUpdateRequestBody("", "", "Ada", "", "", "tr").utf8
        )) as? [String: String])
        XCTAssertEqual(body, ["firstName": "Ada", "language": "tr"])
        let rejected = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
            profileUpdateResponse(200, #"{"success":true,"data":null}"#).utf8
        )) as? [String: Any])
        XCTAssertEqual(rejected["ok"] as? Bool, false)
        let serverError = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
            profileUpdateResponse(200, #"{"success":false,"error":"Denied","data":null}"#).utf8
        )) as? [String: Any])
        XCTAssertEqual(serverError["message"] as? String, "Denied")
        let images = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(
            profileImagesResponse(200, #"{"success":true,"data":[]}"#).utf8
        )) as? [String: Any])
        XCTAssertEqual(images["ok"] as? Bool, true)
    }
}
