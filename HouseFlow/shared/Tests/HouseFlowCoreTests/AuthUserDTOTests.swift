import Foundation
import XCTest
@testable import HouseFlowCore

final class AuthUserDTOTests: XCTestCase {
    func testSignupRequestEncodingPreservesWireKeys() throws {
        let request = SignupRequest(
            email: "ada@example.com",
            password: "secret",
            firstName: "Ada",
            lastName: "Lovelace"
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: String]
        )

        XCTAssertEqual(
            object,
            [
                "email": "ada@example.com",
                "password": "secret",
                "firstName": "Ada",
                "lastName": "Lovelace",
            ]
        )
    }

    func testResetPasswordEncodingPreservesNewPasswordKey() throws {
        let request = ResetPasswordRequest(
            email: "ada@example.com",
            code: "123456",
            newPassword: "new-secret"
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: String]
        )

        XCTAssertEqual(object["email"], "ada@example.com")
        XCTAssertEqual(object["code"], "123456")
        XCTAssertEqual(object["newPassword"], "new-secret")
        XCTAssertEqual(object.count, 3)
    }

    func testUpdateProfileEncodingUsesBirthDayAndOmitsNilValues() throws {
        let request = UpdateProfileRequest(
            imageUrl: nil,
            birthDay: "1990-01-01T00:00:00Z",
            firstName: "Ada",
            lastName: nil,
            phoneNumber: nil,
            language: "en"
        )

        let object = try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(request)) as? [String: String]
        )

        XCTAssertEqual(object["birthDay"], "1990-01-01T00:00:00Z")
        XCTAssertEqual(object["firstName"], "Ada")
        XCTAssertEqual(object["language"], "en")
        XCTAssertNil(object["birthDate"])
        XCTAssertNil(object["imageUrl"])
        XCTAssertNil(object["lastName"])
        XCTAssertNil(object["phoneNumber"])
    }

    func testAuthenticatedUserDecodingMapsBirthDayAndHouseSummary() throws {
        let response = try JSONDecoder().decode(
            IsAuthResponse.self,
            from: AuthUserFixtures.authenticatedUser
        )

        XCTAssertTrue(response.success)
        let profile = try XCTUnwrap(response.data)
        XCTAssertEqual(profile.birthDate, "1990-01-01T00:00:00Z")
        XCTAssertEqual(profile.fullName, "Ada Lovelace")
        XCTAssertEqual(profile.houseList.count, 1)
        XCTAssertEqual(profile.houseList.first?.id, "house-1")
        XCTAssertEqual(profile.houseList.first?.houseName, "Analytical House")
    }

    func testUserProfileDecodingAcceptsNullOptionalFields() throws {
        let profile = try JSONDecoder().decode(
            UserResultModel.self,
            from: AuthUserFixtures.userProfileWithNullOptionals
        )

        XCTAssertNil(profile.birthDate)
        XCTAssertNil(profile.language)
        XCTAssertEqual(profile.fullName, "Grace Hopper")
        XCTAssertEqual(profile.houseIds, [])
    }

    func testImageResponsePreservesFileURLWireKey() throws {
        let response = try JSONDecoder().decode(
            GetImagesResponse.self,
            from: AuthUserFixtures.imagesResponse
        )

        XCTAssertTrue(response.success)
        XCTAssertEqual(response.data.first?.fileURL, "https://example.com/avatar.png")
        XCTAssertEqual(response.data.first?.publicId, "avatar-1")
    }

    func testAuthenticatedUserDecodingRejectsMissingRequiredFields() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(
                IsAuthResponse.self,
                from: AuthUserFixtures.malformedAuthenticatedUser
            )
        )
    }

    func testUserInitializersPreserveExistingIdentityRules() {
        let apiUser = User(
            id: "local-id",
            firstName: "Ada",
            lastName: "Lovelace",
            apiId: "api-id",
            points: 12,
            imageUrl: "ada.png"
        )
        let previewUser = User(name: "Grace Hopper")

        XCTAssertEqual(apiUser.id, "api-id")
        XCTAssertEqual(apiUser.name, "Ada Lovelace")
        XCTAssertEqual(apiUser.initials, "AL")
        XCTAssertEqual(previewUser.id, "grace hopper")
        XCTAssertEqual(previewUser.firstName, "Grace")
        XCTAssertEqual(previewUser.lastName, "Hopper")
        XCTAssertEqual(previewUser.initials, "GH")
    }
}
