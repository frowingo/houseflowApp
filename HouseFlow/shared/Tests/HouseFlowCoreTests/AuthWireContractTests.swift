import Foundation
import XCTest
@testable import HouseFlowCore

final class AuthWireContractTests: XCTestCase {
    func testLoginRequestAndTokenResponseMatchIosWireShape() throws {
        let request = try AuthWireContract.loginRequest(email: "ada@example.com", password: "p@ss")
        XCTAssertEqual(request.path, "auth/login")
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.headers["Content-Type"], "application/json")
        let body = try XCTUnwrap(request.body)
        let payload = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [String: String])
        XCTAssertEqual(payload, ["email": "ada@example.com", "password": "p@ss"])

        let token = try AuthWireContract.loginToken(from: HTTPResponse(
            statusCode: 200, headers: [:], body: Data(#"{"token":"session-token"}"#.utf8)
        ))
        XCTAssertEqual(token, "session-token")
    }

    func testLoginFailurePreservesServerMessageWithoutRequestSecrets() throws {
        let response = HTTPResponse(
            statusCode: 401, headers: [:], body: Data(#"{"message":"Invalid credentials"}"#.utf8)
        )
        XCTAssertThrowsError(try AuthWireContract.loginToken(from: response)) { error in
            let failure = error as? HTTPStatusFailure
            XCTAssertEqual(failure?.statusCode, 401)
            XCTAssertEqual(failure?.message, "Invalid credentials")
        }
    }

    func testProfileRoutePriorityMatchesIosCoordinator() throws {
        let profile = try AuthWireContract.profile(from: HTTPResponse(
            statusCode: 200, headers: [:], body: AuthUserFixtures.authenticatedUser
        ))
        XCTAssertEqual(AuthWireContract.destination(for: profile), .dashboard)

        let unverified = profileWithChanges(to: profile, isVerified: false)
        XCTAssertEqual(AuthWireContract.destination(for: unverified), .emailVerification)
        let noBirthday = profileWithChanges(to: profile, birthDate: .some(nil))
        XCTAssertEqual(AuthWireContract.destination(for: noBirthday), .birthdaySetup)
        let noHouse = profileWithChanges(to: profile, houseList: [])
        XCTAssertEqual(AuthWireContract.destination(for: noHouse), .houseSelection)
    }

    func testRemainingAuthRequestsMatchIosEndpointsAndBodies() throws {
        let signup = try AuthWireContract.signupRequest(email: "ada@example.com", password: "secret", firstName: "Ada", lastName: "A")
        XCTAssertEqual(signup.path, "auth/signup")
        XCTAssertEqual(signup.method, "POST")
        XCTAssertEqual(try body(signup)["firstName"] as? String, "Ada")

        let forgot = try AuthWireContract.forgotPasswordRequest(email: "ada@example.com")
        XCTAssertEqual(forgot.path, "auth/forget")
        XCTAssertEqual(try body(forgot)["email"] as? String, "ada@example.com")

        let reset = try AuthWireContract.resetPasswordRequest(email: "ada@example.com", code: "123456", newPassword: "new")
        XCTAssertEqual(reset.path, "auth/reset")
        XCTAssertEqual(try body(reset)["newPassword"] as? String, "new")

        let send = AuthWireContract.sendVerificationRequest(token: "token")
        XCTAssertEqual(send.method, "GET")
        XCTAssertEqual(send.headers["Authorization"], "Bearer token")

        let verify = try AuthWireContract.verifyEmailRequest(token: "token", code: "ABC123")
        XCTAssertEqual(verify.path, "auth/validate-email")
        XCTAssertEqual(try body(verify)["code"] as? String, "ABC123")

        let birthday = try AuthWireContract.birthdayRequest(token: "token", userId: "u", birthDay: "2000-01-01T00:00:00Z")
        XCTAssertEqual(birthday.path, "user/profile/u")
        XCTAssertEqual(birthday.queryItems.first?.name, "userId")
        XCTAssertEqual(birthday.queryItems.first?.value, "u")
        XCTAssertEqual(try body(birthday)["birthDay"] as? String, "2000-01-01T00:00:00Z")
    }

    func testRemainingAuthResponsesRejectFalseAndPreserveStatus() throws {
        let ok = HTTPResponse(statusCode: 200, headers: [:], body: Data(#"{"success":true}"#.utf8))
        XCTAssertTrue(try AuthWireContract.forgotPasswordAccepted(from: ok))
        XCTAssertTrue(try AuthWireContract.verificationAccepted(from: ok))
        let rejected = HTTPResponse(statusCode: 200, headers: [:], body: Data(#"{"success":false}"#.utf8))
        XCTAssertFalse(try AuthWireContract.verificationAccepted(from: rejected))
        XCTAssertEqual(try AuthWireContract.resetMessage(from: HTTPResponse(
            statusCode: 200, headers: [:], body: Data(#"{"message":"Changed"}"#.utf8))), "Changed")
        XCTAssertThrowsError(try AuthWireContract.verificationAccepted(from: HTTPResponse(
            statusCode: 400, headers: [:], body: Data(#"{"message":"Wrong code"}"#.utf8)))) { error in
            XCTAssertEqual((error as? HTTPStatusFailure)?.message, "Wrong code")
        }
    }

    func testBirthdayResponseRequiresSuccessfulProfilePayload() throws {
        let user = try JSONSerialization.jsonObject(with: AuthUserFixtures.userProfileWithNullOptionals)
        let acceptedBody = try JSONSerialization.data(withJSONObject: ["success": true, "data": user])
        XCTAssertTrue(try AuthWireContract.birthdayAccepted(from: HTTPResponse(
            statusCode: 200, headers: [:], body: acceptedBody)))
        XCTAssertFalse(try AuthWireContract.birthdayAccepted(from: HTTPResponse(
            statusCode: 200, headers: [:], body: Data(#"{"success":true,"data":null}"#.utf8))))
    }

    private func body(_ request: HTTPRequest) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: XCTUnwrap(request.body)) as? [String: Any])
    }

    private func profileWithChanges(
        to profile: IsAuthUserData,
        isVerified: Bool? = nil,
        birthDate: String?? = nil,
        houseList: [AuthHouseSummary]? = nil
    ) -> IsAuthUserData {
        IsAuthUserData(
            birthDate: birthDate ?? profile.birthDate,
            createdOn: profile.createdOn,
            email: profile.email,
            firstName: profile.firstName,
            houseList: houseList ?? profile.houseList,
            id: profile.id,
            imageUrl: profile.imageUrl,
            isActive: profile.isActive,
            isVerifyEmail: isVerified ?? profile.isVerifyEmail,
            isVerifyPhone: profile.isVerifyPhone,
            language: profile.language,
            lastLogin: profile.lastLogin,
            lastName: profile.lastName,
            phoneNumber: profile.phoneNumber,
            updatedOn: profile.updatedOn
        )
    }
}
