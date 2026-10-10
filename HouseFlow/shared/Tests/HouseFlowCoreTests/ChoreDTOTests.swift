import Foundation
import XCTest
@testable import HouseFlowCore

final class ChoreDTOTests: XCTestCase {
    func testCreateChoreRequestEncodingPreservesWireKeys() throws {
        let request = CreateChoreRequest(
            assignedTo: "user-2",
            description: "Kitchen",
            dueDate: "2026-10-12T18:30:00Z",
            houseId: "house-1",
            isRecurring: true,
            level: ChoreLevel.medium.rawValue,
            recurringInterval: 7,
            title: "Wash dishes"
        )
        let object = try encodedObject(request)

        XCTAssertEqual(object["assignedTo"] as? String, "user-2")
        XCTAssertEqual(object["description"] as? String, "Kitchen")
        XCTAssertEqual(object["dueDate"] as? String, "2026-10-12T18:30:00Z")
        XCTAssertEqual(object["houseId"] as? String, "house-1")
        XCTAssertEqual(object["isRecurring"] as? Bool, true)
        XCTAssertEqual(object["level"] as? Int, 20)
        XCTAssertEqual(object["recurringInterval"] as? Int, 7)
        XCTAssertEqual(object["title"] as? String, "Wash dishes")
        XCTAssertEqual(object.count, 8)
    }

    func testUpdateChoreRequestEncodingPreservesWireKeys() throws {
        let request = UpdateChoreRequest(
            assignedTo: "user-3",
            description: "Living room",
            dueDate: "2026-10-13T18:30:00.123Z",
            houseId: "house-1",
            isRecurring: false,
            level: ChoreLevel.hard.rawValue,
            recurringInterval: 0,
            title: "Vacuum"
        )
        let object = try encodedObject(request)

        XCTAssertEqual(object["assignedTo"] as? String, "user-3")
        XCTAssertEqual(object["dueDate"] as? String, "2026-10-13T18:30:00.123Z")
        XCTAssertEqual(object["isRecurring"] as? Bool, false)
        XCTAssertEqual(object["level"] as? Int, 30)
        XCTAssertEqual(object["recurringInterval"] as? Int, 0)
        XCTAssertNil(object["choreId"])
        XCTAssertEqual(object.count, 8)
    }

    func testStatusUpdateEncodingPreservesNestedWireShape() throws {
        let request = UpdateChoreStatusRequest(
            chores: [
                ChoreStatusUpdateItem(
                    choreId: "chore-1",
                    status: ChoreStatus.completed.rawValue
                ),
            ],
            houseId: "house-1"
        )
        let object = try encodedObject(request)
        let chores = try XCTUnwrap(object["chores"] as? [[String: Any]])

        XCTAssertEqual(object["houseId"] as? String, "house-1")
        XCTAssertEqual(chores.count, 1)
        XCTAssertEqual(chores[0]["choreId"] as? String, "chore-1")
        XCTAssertEqual(chores[0]["status"] as? Int, 3)
    }

    func testReviewRequestEncodingPreservesWireKeys() throws {
        let object = try encodedObject(
            ReviewChoreRequest(choreId: "chore-1", isApproved: true)
        )

        XCTAssertEqual(object["choreId"] as? String, "chore-1")
        XCTAssertEqual(object["isApproved"] as? Bool, true)
        XCTAssertEqual(object.count, 2)
    }

    func testChoreResponseDecodesRawValuesNullOptionalsAndISOStrings() throws {
        let response = try JSONDecoder().decode(
            ChoreResponse.self,
            from: ChoreFixtures.responseWithMixedISOStringsAndNullOptionals
        )

        XCTAssertEqual(response.level, ChoreLevel.medium.rawValue)
        XCTAssertEqual(response.status, ChoreStatus.inTest.rawValue)
        XCTAssertEqual(response.dueDate, "2026-10-12T18:30:00.123Z")
        XCTAssertEqual(response.createdOn, "2026-10-10T09:00:00Z")
        XCTAssertNil(response.completedAt)
        XCTAssertNil(response.completedBy)
        XCTAssertEqual(response.statusHistories.first?.status, 2)
        XCTAssertEqual(response.statusHistories.first?.dateTime, "2026-10-10T10:00:00Z")
        XCTAssertEqual(response.reviewVotes.first?.reviewRound, 1)
        XCTAssertEqual(response.reviewVotes.first?.createdOn, "2026-10-10T10:30:00.456Z")
    }

    func testChoreReviewResponseDecodesVotes() throws {
        let response = try JSONDecoder().decode(
            ChoreReviewResponse.self,
            from: ChoreFixtures.reviewResponse
        )

        XCTAssertEqual(response.id, "chore-1")
        XCTAssertEqual(response.status, ChoreStatus.completed.rawValue)
        XCTAssertTrue(response.isCompleted)
        XCTAssertEqual(response.reviewRound, 2)
        XCTAssertEqual(response.reviewVotes.first?.isApproved, false)
    }

    func testKnownEnumRawValuesDecode() throws {
        XCTAssertEqual(try decode(ChoreLevel.self, rawValue: 10), .easy)
        XCTAssertEqual(try decode(ChoreLevel.self, rawValue: 20), .medium)
        XCTAssertEqual(try decode(ChoreLevel.self, rawValue: 30), .hard)
        XCTAssertEqual(try decode(ChoreStatus.self, rawValue: 0), .draft)
        XCTAssertEqual(try decode(ChoreStatus.self, rawValue: 1), .progress)
        XCTAssertEqual(try decode(ChoreStatus.self, rawValue: 2), .inTest)
        XCTAssertEqual(try decode(ChoreStatus.self, rawValue: 3), .completed)
    }

    func testUnknownEnumRawValuesKeepExistingThrowBehavior() throws {
        XCTAssertThrowsError(try decode(ChoreLevel.self, rawValue: 999))
        XCTAssertThrowsError(try decode(ChoreStatus.self, rawValue: 99))

        let response = try JSONDecoder().decode(
            ChoreResponse.self,
            from: ChoreFixtures.responseWithUnknownRawValues
        )
        XCTAssertEqual(response.level, 999)
        XCTAssertEqual(response.status, 99)
    }

    func testChoreResponseRejectsMissingRequiredFields() {
        XCTAssertThrowsError(
            try JSONDecoder().decode(ChoreResponse.self, from: ChoreFixtures.malformedResponse)
        )
    }

    func testChoreIdentityAndDefaultsRemainStable() {
        let assignee = User(id: "user-1", name: "Ada Lovelace")
        let serverChore = Chore(
            id: "local-id",
            choreApiId: "api-id",
            title: "Wash dishes",
            assignedTo: assignee,
            dueLabel: "Today"
        )
        let explicitLocalChore = Chore(
            id: "local-id",
            title: "Vacuum",
            assignedTo: assignee,
            dueLabel: "This week"
        )
        let generatedLocalChore = Chore(
            title: "Laundry",
            assignedTo: assignee,
            dueLabel: "Upcoming"
        )

        XCTAssertEqual(serverChore.id, "api-id")
        XCTAssertEqual(explicitLocalChore.id, "local-id")
        XCTAssertNotNil(UUID(uuidString: generatedLocalChore.id))
        XCTAssertEqual(generatedLocalChore.description, "")
        XCTAssertFalse(generatedLocalChore.isDone)
        XCTAssertEqual(generatedLocalChore.status, ChoreStatus.draft.rawValue)
        XCTAssertEqual(generatedLocalChore.level, ChoreLevel.easy.rawValue)
        XCTAssertEqual(generatedLocalChore.dueLabel, "Upcoming")
        XCTAssertTrue(generatedLocalChore.reviewVotes.isEmpty)
    }

    private func encodedObject<Value: Encodable>(_ value: Value) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: JSONEncoder().encode(value)) as? [String: Any]
        )
    }

    private func decode<Value: Decodable>(_ type: Value.Type, rawValue: Int) throws -> Value {
        try JSONDecoder().decode(type, from: Data(String(rawValue).utf8))
    }
}
