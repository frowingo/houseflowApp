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
