import Foundation
import XCTest
@testable import HouseFlowCore

final class HouseDTOTests: XCTestCase {
    func testCreateHouseRequestEncodingPreservesWireKeys() throws {
        let request = CreateHouseRequest(name: "Analytical House", maxMemberCount: 6, type: 2)
        let object = try encodedObject(request)

        XCTAssertEqual(object["name"] as? String, "Analytical House")
        XCTAssertEqual(object["maxMemberCount"] as? Int, 6)
        XCTAssertEqual(object["type"] as? Int, 2)
        XCTAssertEqual(object.count, 3)
    }

    func testHouseActionRequestsPreserveBackendWireKeys() throws {
        let join = try encodedObject(JoinHouseRequest(inviteCode: "AB12CD34"))
        let invite = try encodedObject(CreateHouseInviteCodeRequest(houseId: "house-1"))
        let exit = try encodedObject(ExitHouseRequest(houseId: "house-1", userId: "user-2"))
        let announcement = try encodedObject(
            CreateAnnouncementRequest(
                description: "Welcome home",
                houseId: "house-1",
                title: "Welcome"
            )
        )

        XCTAssertEqual(join as NSDictionary, ["inviteCode": "AB12CD34"] as NSDictionary)
        XCTAssertEqual(invite as NSDictionary, ["houseId": "house-1"] as NSDictionary)
        XCTAssertEqual(
            exit as NSDictionary,
            ["houseId": "house-1", "userId": "user-2"] as NSDictionary
        )
        XCTAssertEqual(announcement["description"] as? String, "Welcome home")
        XCTAssertEqual(announcement["houseId"] as? String, "house-1")
        XCTAssertEqual(announcement["title"] as? String, "Welcome")
    }

    func testUpdateHouseProfileEncodingPreservesWireKeys() throws {
        let request = UpdateHouseProfileRequest(
            houseMemberCountLimit: 8,
            houseName: "New House",
            houseProfileImage: "house.png",
            houseType: 3
        )
        let object = try encodedObject(request)

        XCTAssertEqual(object["houseMemberCountLimit"] as? Int, 8)
        XCTAssertEqual(object["houseName"] as? String, "New House")
        XCTAssertEqual(object["houseProfileImage"] as? String, "house.png")
        XCTAssertEqual(object["houseType"] as? Int, 3)
        XCTAssertEqual(object.count, 4)
    }

    func testHouseResponseDecodesStringDates() throws {
        let house = try JSONDecoder().decode(
            HouseResponse.self,
            from: HouseFixtures.responseWithStringDates
        )

        XCTAssertEqual(house.id, "house-1")
        XCTAssertEqual(house.inviteCode, "AB12CD34")
        XCTAssertEqual(house.createdOn, "2026-09-01T08:00:00Z")
        XCTAssertEqual(house.updatedOn, "2026-09-02T08:00:00Z")
    }

    func testHouseResponseDecodesTimeObjectsAndNullInviteCode() throws {
        let house = try JSONDecoder().decode(
            HouseResponse.self,
            from: HouseFixtures.responseWithObjectDatesAndNullInvite
        )

        XCTAssertEqual(house.id, "house-2")
        XCTAssertNil(house.inviteCode)
        XCTAssertEqual(house.createdOn, "2026-10-01T08:00:00Z")
        XCTAssertEqual(house.updatedOn, "2026-10-02T08:00:00Z")
    }

    func testHouseDetailsDecodesStringDatesAndActiveAnnouncementAliases() throws {
        let details = try JSONDecoder().decode(
            HouseDetailsResponse.self,
            from: HouseFixtures.detailsWithStringDates
        )

        XCTAssertEqual(details.members.first?.birthDate, "1990-01-01T00:00:00Z")
        XCTAssertEqual(details.members.first?.createdOn, "2026-09-01T08:00:00Z")
        XCTAssertEqual(details.announcements.first?.id, "announcement-1")
        XCTAssertEqual(details.announcements.first?.message, "Welcome home")
        XCTAssertEqual(details.announcements.first?.publisherId, "user-1")
        XCTAssertEqual(details.announcements.first?.publisherName, "Ada Lovelace")
        XCTAssertNil(details.announcements.first?.updatedOn)
    }

    func testHouseDetailsDecodesTimeObjectsAndNullOptionals() throws {
        let details = try JSONDecoder().decode(
            HouseDetailsResponse.self,
            from: HouseFixtures.detailsWithObjectDatesAndNullOptionals
        )

        XCTAssertEqual(details.createdOn, "2026-10-01T08:00:00Z")
        XCTAssertNil(details.members.first?.birthDate)
        XCTAssertNil(details.members.first?.language)
        XCTAssertEqual(details.chores.first?.dueDate, "2026-10-04T18:00:00Z")
        XCTAssertNil(details.chores.first?.completedAt)
        XCTAssertNil(details.chores.first?.completedBy)
        XCTAssertEqual(
            details.chores.first?.statusHistories.first?.dateTime,
            "2026-10-01T09:00:00Z"
        )
        XCTAssertEqual(
            details.chores.first?.reviewVotes.first?.createdOn,
            "2026-10-01T10:00:00Z"
        )
        XCTAssertNil(details.announcements.first?.updatedOn)
    }

    func testHouseInfoDecodingAndExistingMemberRules() throws {
        let info = try JSONDecoder().decode(HouseInfoData.self, from: HouseFixtures.houseInfo)

        XCTAssertTrue(info.isOwner(userId: "user-1"))
        XCTAssertFalse(info.isOwner(userId: "user-2"))
        XCTAssertFalse(info.isOwner(userId: nil))

        let updated = info.removingMember(userId: "user-2")
        XCTAssertEqual(updated.houseMemberCount, 1)
        XCTAssertEqual(updated.houseMembers.map(\.userId), ["user-1"])
        XCTAssertEqual(updated.houseMemberCountLimit, 8)
    }

    func testInviteCodeRulesPreserveExistingNormalizationAndValidation() {
        XCTAssertEqual(InviteCodeRules.normalized("ab-12 cd34xyz"), "AB12CD34")
        XCTAssertEqual(InviteCodeRules.requiredLength, 8)
        XCTAssertTrue(InviteCodeRules.isValid("AB12CD34"))
        XCTAssertFalse(InviteCodeRules.isValid("AB12CD3"))
    }

    func testHouseResponseRejectsMissingRequiredFields() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(HouseResponse.self, from: HouseFixtures.malformedResponse)
        )
    }

    private func encodedObject<Value: Encodable>(_ value: Value) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]
        )
    }
}
