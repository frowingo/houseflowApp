import Foundation
import FausCrewCore
import XCTest

final class SocialAuthWireContractTests: XCTestCase {
    private func response(_ status: Int, _ json: String) -> HTTPResponse {
        HTTPResponse(statusCode: status, headers: [:], body: Data(json.utf8))
    }

    private func body(_ request: HTTPRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.body)) as? [String: Any])
    }

    func testSignInBodyOmitsUnsetFieldsAndCapsNames() throws {
        let long = String(repeating: "a", count: 80)
        let request = try SocialAuthWireContract.signInRequest(
            provider: .apple,
            credential: SocialCredential(idToken: "id", nonce: "raw", authorizationCode: "code", firstName: long, lastName: "  "),
            language: "tr"
        )
        XCTAssertEqual(request.path, "auth/social/apple")
        XCTAssertEqual(request.method, "POST")
        let json = try body(request)
        XCTAssertEqual(Set(json.keys), ["idToken", "nonce", "authorizationCode", "firstName", "language"])
        XCTAssertEqual((json["firstName"] as? String)?.count, 50)
    }

    func testEmailProviderHasNoSocialEndpoint() {
        XCTAssertThrowsError(try SocialAuthWireContract.signInRequest(provider: .email, credential: SocialCredential(), language: nil))
    }

    func testOutcomes() throws {
        XCTAssertEqual(
            try SocialAuthWireContract.signInOutcome(from: response(201, #"{"token":"t","isNewUser":true}"#)),
            .signedIn(token: "t", isNewUser: true)
        )
        XCTAssertEqual(
            try SocialAuthWireContract.signInOutcome(from: response(200, #"{"isNewUser":false,"needsEmail":true,"pendingToken":"p"}"#)),
            .needsEmail(pendingToken: "p")
        )
        XCTAssertThrowsError(try SocialAuthWireContract.signInOutcome(from: response(200, #"{"isNewUser":false}"#)))
    }

    func testFailureKeepsStatusAndDisplayText() {
        XCTAssertThrowsError(try SocialAuthWireContract.signInOutcome(from: response(409, #"{"success":false,"error":"Kayıtlı"}"#))) {
            XCTAssertEqual($0 as? SocialAuthError, SocialAuthError(statusCode: 409, message: "Kayıtlı"))
        }
    }

    func testLinkedProvidersAndDelete() throws {
        XCTAssertEqual(
            try SocialAuthWireContract.linkedProviders(from: response(200, #"{"linkedProviders":[1,2,9]}"#)),
            [.google, .apple]
        )
        let delete = SocialAuthWireContract.deleteAccountRequest(token: "jwt")
        XCTAssertEqual(delete.method, "DELETE")
        XCTAssertEqual(delete.path, "user/me")
        XCTAssertNoThrow(try SocialAuthWireContract.validateAccepted(response(204, "")))
    }

    func testIsAuthDecodesNewFieldsAndToleratesTheirAbsence() throws {
        let base = ##""createdOn":"","email":"a@b.c","firstName":"A","houseList":[],"id":"1","imageUrl":"","isActive":true,"isVerifyEmail":true,"isVerifyPhone":false,"lastLogin":"","lastName":"B","phoneNumber":"","updatedOn":"""##
        let old = try JSONDecoder().decode(IsAuthUserData.self, from: Data("{\(base)}".utf8))
        XCTAssertNil(old.linkedProviders)
        let new = try JSONDecoder().decode(
            IsAuthUserData.self,
            from: Data("{\(base),\"signUpProvider\":2,\"linkedProviders\":[1,2],\"hasPassword\":false}".utf8)
        )
        XCTAssertEqual(new.linkedProviders, [1, 2])
        XCTAssertEqual(new.hasPassword, false)
    }
}
