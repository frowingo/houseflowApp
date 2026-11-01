import Foundation
import XCTest
@testable import FausCrewCore

final class ChoreReviewPhotoTests: XCTestCase {
    // MARK: - House flag

    func testHouseDetailsDecodesReviewPhotoFlagAndDefaultsToFalse() throws {
        let enabled = try JSONDecoder().decode(
            HouseDetailsResponse.self,
            from: adding(["isChoreReviewPhotoRequired": true], to: HouseFixtures.detailsWithStringDates)
        )
        let legacy = try JSONDecoder().decode(
            HouseDetailsResponse.self,
            from: HouseFixtures.detailsWithStringDates
        )

        XCTAssertTrue(enabled.isChoreReviewPhotoRequired)
        XCTAssertFalse(legacy.isChoreReviewPhotoRequired)
    }

    func testHouseInfoDecodesReviewPhotoFlagAndKeepsItWhenRemovingMember() throws {
        let info = try JSONDecoder().decode(
            HouseInfoData.self,
            from: adding(["isChoreReviewPhotoRequired": true], to: HouseFixtures.houseInfo)
        )
        let legacy = try JSONDecoder().decode(HouseInfoData.self, from: HouseFixtures.houseInfo)

        XCTAssertTrue(info.isChoreReviewPhotoRequired)
        XCTAssertTrue(info.removingMember(userId: "user-2").isChoreReviewPhotoRequired)
        XCTAssertFalse(legacy.isChoreReviewPhotoRequired)
    }

    func testProfileBodyCarriesReviewPhotoFlagOnlyWhenProvided() throws {
        let withFlag = try object(HouseWireContract.profileBody(
            name: "City Home", type: 1, maxMemberCount: 4, profileImage: "",
            isChoreReviewPhotoRequired: true
        ))
        let withoutFlag = try object(HouseWireContract.profileBody(
            name: "City Home", type: 1, maxMemberCount: 4, profileImage: ""
        ))

        XCTAssertEqual(withFlag["isChoreReviewPhotoRequired"] as? Bool, true)
        XCTAssertEqual(withFlag.count, 5)
        XCTAssertNil(withoutFlag["isChoreReviewPhotoRequired"])
        XCTAssertEqual(withoutFlag.count, 4)
    }

    // MARK: - Chore rounds

    func testChoreResponseDecodesReviewPhotoRoundsAndDefaultsToEmpty() throws {
        let response = try JSONDecoder().decode(
            ChoreResponse.self,
            from: adding(
                ["reviewPhotoRounds": [1, 2]],
                to: ChoreFixtures.responseWithMixedISOStringsAndNullOptionals
            )
        )
        let legacy = try JSONDecoder().decode(
            ChoreResponse.self,
            from: ChoreFixtures.responseWithMixedISOStringsAndNullOptionals
        )

        XCTAssertEqual(response.reviewPhotoRounds, [1, 2])
        XCTAssertEqual(legacy.reviewPhotoRounds, [])
    }

    func testHouseChoreDecodesReviewPhotoRoundsAndDefaultsToEmpty() throws {
        let details = try JSONDecoder().decode(
            HouseDetailsResponse.self,
            from: HouseFixtures.detailsWithObjectDatesAndNullOptionals
        )
        XCTAssertEqual(details.chores.first?.reviewPhotoRounds, [])

        var payload = try XCTUnwrap(
            JSONSerialization.jsonObject(with: HouseFixtures.detailsWithObjectDatesAndNullOptionals) as? [String: Any]
        )
        var chores = try XCTUnwrap(payload["chores"] as? [[String: Any]])
        chores[0]["reviewPhotoRounds"] = [2]
        payload["chores"] = chores
        let updated = try JSONDecoder().decode(
            HouseDetailsResponse.self,
            from: JSONSerialization.data(withJSONObject: payload)
        )
        XCTAssertEqual(updated.chores.first?.reviewPhotoRounds, [2])
    }

    // MARK: - Multipart status

    func testReviewPhotoChoresFieldIsSingleInTestJSONString() throws {
        let field = try DashboardWireContract.reviewPhotoChoresField(choreId: "CHORE_ID")

        XCTAssertEqual(field, #"[{"choreId":"CHORE_ID","status":2}]"#)
    }

    func testRequiresPhotoOnlyForInTestWhenHouseRequiresIt() {
        XCTAssertTrue(ChoreReviewPhotoRules.requiresPhoto(isChoreReviewPhotoRequired: true, targetStatus: .inTest))
        XCTAssertFalse(ChoreReviewPhotoRules.requiresPhoto(isChoreReviewPhotoRequired: false, targetStatus: .inTest))
        XCTAssertFalse(ChoreReviewPhotoRules.requiresPhoto(isChoreReviewPhotoRequired: true, targetStatus: .progress))
        XCTAssertFalse(ChoreReviewPhotoRules.requiresPhoto(isChoreReviewPhotoRequired: true, targetStatus: .completed))
    }

    func testUploadAcceptsSupportedFormatsBySignature() throws {
        XCTAssertEqual(try ChoreReviewPhotoUpload(data: Self.jpeg).mimeType, "image/jpeg")
        XCTAssertEqual(try ChoreReviewPhotoUpload(data: Self.png).mimeType, "image/png")
        XCTAssertEqual(try ChoreReviewPhotoUpload(data: Self.webp).mimeType, "image/webp")
        XCTAssertEqual(try ChoreReviewPhotoUpload(data: Self.webp).fileName, "review-photo.webp")
    }

    func testUploadRejectsUnsupportedEmptyAndOversizedFiles() {
        XCTAssertThrowsError(try ChoreReviewPhotoUpload(data: Data("GIF89a".utf8))) {
            XCTAssertEqual($0 as? ChoreReviewPhotoError, .unsupportedFormat)
        }
        XCTAssertThrowsError(try ChoreReviewPhotoUpload(data: Data())) {
            XCTAssertEqual($0 as? ChoreReviewPhotoError, .missing)
        }
        let oversized = Self.jpeg + Data(count: ChoreReviewPhotoRules.maxByteCount)
        XCTAssertThrowsError(try ChoreReviewPhotoUpload(data: oversized)) {
            XCTAssertEqual($0 as? ChoreReviewPhotoError, .tooLarge)
        }
        let atLimit = Self.jpeg + Data(count: ChoreReviewPhotoRules.maxByteCount - Self.jpeg.count)
        XCTAssertNoThrow(try ChoreReviewPhotoUpload(data: atLimit))
    }

    func testStatusPhotoResponseUsesSameValidationAsStatus() throws {
        let body = try JSONSerialization.data(withJSONObject: [
            JSONSerialization.jsonObject(with: ChoreFixtures.responseWithMixedISOStringsAndNullOptionals),
        ])
        XCTAssertNoThrow(try DashboardWireContract.validate(
            action: "statusPhoto",
            response: HTTPResponse(statusCode: 200, headers: [:], body: body)
        ))
        XCTAssertThrowsError(try DashboardWireContract.validate(
            action: "statusPhoto",
            response: HTTPResponse(
                statusCode: 503, headers: [:],
                body: Data(#"{"success":false,"error":"Storage unavailable"}"#.utf8)
            )
        )) {
            XCTAssertEqual(($0 as? HTTPStatusFailure)?.message, "Storage unavailable")
        }
    }

    // MARK: - Presigned URL

    func testPresignedURLResponseDecodesAndValidates() throws {
        let body = Data(#"{"url":"https://signed.example/photo?X-Sig=abc","expiresAt":"2026-10-29T10:20:00Z"}"#.utf8)
        let response = try JSONDecoder().decode(ChoreReviewPhotoURLResponse.self, from: body)

        XCTAssertEqual(response.url, "https://signed.example/photo?X-Sig=abc")
        XCTAssertEqual(response.expiresAt, "2026-10-29T10:20:00Z")
        XCTAssertNoThrow(try DashboardWireContract.validate(
            action: "reviewPhoto",
            response: HTTPResponse(statusCode: 200, headers: [:], body: body)
        ))
        XCTAssertThrowsError(try DashboardWireContract.validate(
            action: "reviewPhoto",
            response: HTTPResponse(statusCode: 404, headers: [:], body: Data(#"{"success":false,"error":"No photo"}"#.utf8))
        )) {
            XCTAssertEqual(($0 as? HTTPStatusFailure)?.message, "No photo")
        }
    }

    func testPresignedURLExpiryUsesLeewayAndToleratesFractionalSeconds() throws {
        let response = ChoreReviewPhotoURLResponse(url: "https://signed.example", expiresAt: "2026-10-29T10:20:00.500Z")
        let expiry = try XCTUnwrap(response.expiresAtDate)

        XCTAssertFalse(response.isExpired(at: expiry.addingTimeInterval(-60)))
        XCTAssertTrue(response.isExpired(at: expiry.addingTimeInterval(-2)))
        XCTAssertTrue(response.isExpired(at: expiry.addingTimeInterval(1)))
        XCTAssertFalse(ChoreReviewPhotoURLResponse(url: "", expiresAt: "soon").isExpired(at: Date()))
    }

    // MARK: - Helpers

    static let jpeg = Data([0xFF, 0xD8, 0xFF, 0xE0, 0x00, 0x10, 0x4A, 0x46, 0x49, 0x46, 0x00, 0x01])
    static let png = Data([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0x00, 0x00, 0x00, 0x0D])
    static let webp = Data([0x52, 0x49, 0x46, 0x46, 0x24, 0x00, 0x00, 0x00, 0x57, 0x45, 0x42, 0x50])

    private func adding(_ fields: [String: Any], to fixture: Data) throws -> Data {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: fixture) as? [String: Any])
        if var data = object["data"] as? [String: Any] {
            data.merge(fields) { _, new in new }
            object["data"] = data
        } else {
            object.merge(fields) { _, new in new }
        }
        return try JSONSerialization.data(withJSONObject: object)
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
