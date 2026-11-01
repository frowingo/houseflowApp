import XCTest
@testable import FausCrewAndroidBridge

final class SocialAuthBridgeTests: XCTestCase {
    private func object(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    func testSlugsAndBodiesOmitAbsentFields() throws {
        XCTAssertEqual(socialProviderSlug(1), "google")
        XCTAssertEqual(socialProviderSlug(0), "")
        XCTAssertEqual(socialProviderSlug(9), "")
        let body = try object(socialSignInRequestBody("", "fb-token", "", "", "", "", "tr"))
        XCTAssertEqual(Set(body.keys), ["accessToken", "language"])
        let complete = try object(socialCompleteRequestBody("p", "a@b.c", "ABC123", "Ada", "", "en"))
        XCTAssertEqual(complete["code"] as? String, "ABC123")
        XCTAssertNil(complete["lastName"])
    }

    func testOutcomesCarryStatus() throws {
        let created = try object(socialResponse("signIn", 201, #"{"token":"t","isNewUser":true}"#))
        XCTAssertEqual(created["token"] as? String, "t")
        XCTAssertEqual(created["isNewUser"] as? Bool, true)
        let pending = try object(socialResponse("signIn", 200, #"{"isNewUser":false,"needsEmail":true,"pendingToken":"p"}"#))
        XCTAssertEqual(pending["needsEmail"] as? Bool, true)
        XCTAssertEqual(pending["pendingToken"] as? String, "p")
        let conflict = try object(socialResponse("signIn", 409, #"{"success":false,"error":"Kayıtlı"}"#))
        XCTAssertEqual(conflict["ok"] as? Bool, false)
        XCTAssertEqual(conflict["status"] as? Int, 409)
        XCTAssertEqual(conflict["message"] as? String, "Kayıtlı")
        XCTAssertEqual(try object(socialResponse("accepted", 204, ""))["ok"] as? Bool, true)
        XCTAssertEqual(try object(socialResponse("linked", 200, #"{"linkedProviders":[1,3]}"#))["linkedProviders"] as? [Int], [1, 3])
    }

    func testProfileCarriesSignInMethods() throws {
        let body = #"{"success":true,"data":{"createdOn":"","email":"a@b.c","firstName":"A","houseList":[],"id":"1","imageUrl":"","isActive":true,"isVerifyEmail":true,"isVerifyPhone":false,"lastLogin":"","lastName":"B","phoneNumber":"","updatedOn":"","signUpProvider":4,"linkedProviders":[4],"hasPassword":false}}"#
        let profile = try object(profileResponse(200, body))
        XCTAssertEqual(profile["linkedProviders"] as? [Int], [4])
        XCTAssertEqual(profile["hasPassword"] as? Bool, false)
        XCTAssertEqual(profile["signUpProvider"] as? Int, 4)
    }
}
