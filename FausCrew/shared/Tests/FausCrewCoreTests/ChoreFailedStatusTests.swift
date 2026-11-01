import Foundation
import XCTest
@testable import FausCrewCore

final class ChoreFailedStatusTests: XCTestCase {
    // MARK: - Parsing

    func testFailedChoreResponseParses() throws {
        let response = try JSONDecoder().decode(ChoreResponse.self, from: failedChoreJSON(updater: "system"))

        XCTAssertEqual(response.status, 4)
        XCTAssertEqual(ChoreStatus(apiValue: response.status), .failed)
        XCTAssertFalse(response.isCompleted)
        XCTAssertEqual(response.completedBy, "")
        XCTAssertEqual(response.statusHistories.last?.status, 4)
        XCTAssertEqual(response.statusHistories.last?.updater, "system")
    }

    func testFailedHouseChoreParsesWithTimeObjects() throws {
        let chore = try JSONDecoder().decode(HouseChoreDTO.self, from: failedChoreJSON(updater: "system", wrapsTimes: true))

        XCTAssertEqual(ChoreStatus(apiValue: chore.status), .failed)
        XCTAssertEqual(chore.completedAt, "0001-01-01T00:00:00Z")
        XCTAssertEqual(chore.failureReason, .dueDatePassed)
    }

    // MARK: - Enum and unknown fallback

    func testRawValuesMapToStatuses() {
        XCTAssertEqual(ChoreStatus(apiValue: 0), .draft)
        XCTAssertEqual(ChoreStatus(apiValue: 1), .progress)
        XCTAssertEqual(ChoreStatus(apiValue: 2), .inTest)
        XCTAssertEqual(ChoreStatus(apiValue: 3), .completed)
        XCTAssertEqual(ChoreStatus(apiValue: 4), .failed)
    }

    func testUnknownRawValuesFallBackWithoutFailing() throws {
        XCTAssertEqual(ChoreStatus(apiValue: 99), .unknown)
        XCTAssertEqual(ChoreStatus(apiValue: -7), .unknown)

        let response = try JSONDecoder().decode(ChoreResponse.self, from: ChoreFixtures.responseWithUnknownRawValues)
        let chore = Chore(title: response.title, assignedTo: User(name: "Ada"), dueLabel: "Today", status: response.status)
        XCTAssertEqual(chore.choreStatus, .unknown)
        XCTAssertFalse(chore.choreStatus.acceptsActions)
        XCTAssertNil(chore.choreStatus.nextAssigneeStatus)
    }

    // MARK: - List groups

    func testListGroupsFollowStatusNotIsCompleted() {
        XCTAssertEqual(ChoreStatus.draft.listGroup, .active)
        XCTAssertEqual(ChoreStatus.progress.listGroup, .active)
        XCTAssertEqual(ChoreStatus.inTest.listGroup, .active)
        XCTAssertEqual(ChoreStatus.completed.listGroup, .completed)
        XCTAssertEqual(ChoreStatus.failed.listGroup, .failed)
        XCTAssertEqual(ChoreStatus.unknown.listGroup, .unknown)

        // Failed arrives with isCompleted = false and must still leave the active list.
        let chores = [
            chore("a", status: 1, isDone: false),
            chore("b", status: 4, isDone: false),
            chore("c", status: 3, isDone: true),
            chore("d", status: 0, isDone: false),
            chore("e", status: 99, isDone: false),
        ]
        XCTAssertEqual(chores.activeChores.map(\.id), ["a", "d"])
        XCTAssertEqual(chores.historyChores.map(\.id), ["b", "c", "e"])
    }

    // MARK: - Terminal actions

    func testOnlyActiveStatusesAcceptActions() {
        XCTAssertTrue(ChoreStatus.draft.acceptsActions)
        XCTAssertTrue(ChoreStatus.progress.acceptsActions)
        XCTAssertTrue(ChoreStatus.inTest.acceptsActions)
        XCTAssertFalse(ChoreStatus.completed.acceptsActions)
        XCTAssertFalse(ChoreStatus.failed.acceptsActions)
        XCTAssertFalse(ChoreStatus.unknown.acceptsActions)
    }

    func testAssigneeFlowNeverOffersFailed() {
        XCTAssertEqual(ChoreStatus.draft.nextAssigneeStatus, .progress)
        XCTAssertEqual(ChoreStatus.progress.nextAssigneeStatus, .inTest)
        XCTAssertNil(ChoreStatus.inTest.nextAssigneeStatus)
        XCTAssertNil(ChoreStatus.completed.nextAssigneeStatus)
        XCTAssertNil(ChoreStatus.failed.nextAssigneeStatus)
        XCTAssertFalse(ChoreStatus.pipeline.contains(.failed))
    }

    // MARK: - Failure reason

    func testSystemFailureAfterDueDateReadsAsDueDatePassed() {
        XCTAssertEqual(reason(updater: "system", failedAt: "2026-10-12T18:30:01Z"), .dueDatePassed)
        XCTAssertEqual(reason(updater: " System ", failedAt: "2026-10-12T18:30:00Z"), .dueDatePassed)
    }

    func testAmbiguousFailuresStayUnspecified() {
        // Not written by the system.
        XCTAssertEqual(reason(updater: "user-1", failedAt: "2026-10-13T00:00:00Z"), .unspecified)
        // Before the due date, so it cannot be the deadline.
        XCTAssertEqual(reason(updater: "system", failedAt: "2026-10-12T10:00:00Z"), .unspecified)
        // A rejection in the third round makes a review failure just as likely.
        XCTAssertEqual(
            reason(updater: "system", failedAt: "2026-10-13T00:00:00Z", reviewRound: 3, rejectedInRound: 3),
            .unspecified
        )
        // No Failed entry, or an unreadable date.
        XCTAssertEqual(ChoreFailureReason.reason(statusHistories: [], dueDate: dueDate, reviewRound: 0, reviewVotes: []), .unspecified)
        XCTAssertEqual(reason(updater: "system", failedAt: "not a date"), .unspecified)
    }

    func testEarlierRoundRejectionsDoNotHideTheDeadline() {
        XCTAssertEqual(
            reason(updater: "system", failedAt: "2026-10-13T00:00:00Z", reviewRound: 2, rejectedInRound: 1),
            .dueDatePassed
        )
    }

    func testOnlyFailedHouseChoresCarryAReason() throws {
        let completed = HouseChoreDTO(
            id: "c", title: "", description: "", houseId: "h", houseOwnerId: "o", assignedTo: "u",
            dueDate: dueDate, isCompleted: true, isRecurring: false, level: 10, recurringInterval: 0,
            status: 3, createdOn: dueDate, completedAt: dueDate, completedBy: "u",
            statusHistories: [], reviewRound: 1, reviewVotes: []
        )
        XCTAssertNil(completed.failureReason)
    }

    // MARK: - Helpers

    private let dueDate = "2026-10-12T18:30:00.000Z"

    private func reason(
        updater: String,
        failedAt: String,
        reviewRound: Int = 1,
        rejectedInRound: Int? = nil
    ) -> ChoreFailureReason {
        let votes = rejectedInRound.map {
            [ChoreReviewVote(id: "v", choreId: "c", houseId: "h", reviewRound: $0, reviewerId: "r", isApproved: false, createdOn: failedAt)]
        } ?? []
        return ChoreFailureReason.reason(
            statusHistories: [
                ChoreStatusHistory(id: "h1", choreId: "c", status: 1, updater: "u", dateTime: "2026-10-11T09:00:00Z"),
                ChoreStatusHistory(id: "h2", choreId: "c", status: 4, updater: updater, dateTime: failedAt),
            ],
            dueDate: dueDate,
            reviewRound: reviewRound,
            reviewVotes: votes
        )
    }

    private func chore(_ id: String, status: Int, isDone: Bool) -> Chore {
        Chore(id: id, title: id, assignedTo: User(name: "Ada"), dueLabel: "Today", isDone: isDone, status: status)
    }

    private func failedChoreJSON(updater: String, wrapsTimes: Bool = false) -> Data {
        func time(_ value: String) -> String { wrapsTimes ? #"{ "time.Time": "\#(value)" }"# : #""\#(value)""# }
        return Data(
            """
            {
              "id": "chore-failed",
              "title": "Take out trash",
              "description": "",
              "houseId": "house-1",
              "houseOwnerId": "user-1",
              "assignedTo": "user-2",
              "dueDate": \(time("2026-10-12T18:30:00Z")),
              "isCompleted": false,
              "isRecurring": false,
              "level": 10,
              "recurringInterval": 0,
              "status": 4,
              "createdOn": \(time("2026-10-10T09:00:00Z")),
              "completedAt": \(time("0001-01-01T00:00:00Z")),
              "completedBy": "",
              "statusHistories": [
                { "id": "h1", "choreId": "chore-failed", "status": 1, "updater": "user-2", "dateTime": \(time("2026-10-11T09:00:00Z")) },
                { "id": "h2", "choreId": "chore-failed", "status": 4, "updater": "\(updater)", "dateTime": \(time("2026-10-12T18:30:05Z")) }
              ],
              "reviewRound": 0,
              "reviewVotes": []
            }
            """.utf8
        )
    }
}
