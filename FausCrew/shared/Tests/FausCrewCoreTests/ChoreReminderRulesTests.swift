import Foundation
import FausCrewCore
import XCTest

final class ChoreReminderRulesTests: XCTestCase {
    private let due = "2026-11-21T18:00:00Z"
    private var dueDate: Date { ISO8601DateFormatter().date(from: due)! }

    private func can(
        assignedTo: String? = "u2", currentUser: String? = "u1", status: Int = 1, due: String? = "2026-11-21T18:00:00Z", at now: Date
    ) -> Bool {
        ChoreReminderRules.canRemind(assignedToID: assignedTo, currentUserID: currentUser, status: status, dueDate: due, now: now)
    }

    func testWindowStartIsInclusiveAndEndExclusive() {
        let start = dueDate.addingTimeInterval(-ChoreReminderRules.window)
        XCTAssertEqual(ChoreReminderRules.window, 43_200)
        XCTAssertFalse(can(at: start.addingTimeInterval(-1)))
        XCTAssertTrue(can(at: start))
        XCTAssertTrue(can(at: dueDate.addingTimeInterval(-1)))
        XCTAssertFalse(can(at: dueDate))
        XCTAssertFalse(can(at: dueDate.addingTimeInterval(3_600)))
    }

    func testOnlyDraftAndProgressAreOpen() {
        let now = dueDate.addingTimeInterval(-3_600)
        XCTAssertTrue(can(status: 0, at: now))
        XCTAssertTrue(can(status: 1, at: now))
        for status in [2, 3, 4, -1] { XCTAssertFalse(can(status: status, at: now), "\(status)") }
    }

    func testAssigneeRules() {
        let now = dueDate.addingTimeInterval(-3_600)
        XCTAssertFalse(can(assignedTo: "u1", at: now), "Own chore")
        XCTAssertFalse(can(assignedTo: nil, at: now))
        XCTAssertFalse(can(assignedTo: " ", at: now))
        XCTAssertFalse(can(currentUser: nil, at: now))
        XCTAssertFalse(can(currentUser: "", at: now))
    }

    func testDueDateParsing() {
        let now = dueDate.addingTimeInterval(-3_600)
        XCTAssertFalse(can(due: nil, at: now))
        XCTAssertFalse(can(due: "tomorrow", at: now))
        XCTAssertTrue(can(due: "2026-11-21T18:00:00.500Z", at: dueDate.addingTimeInterval(0.4)), "Fractional seconds count")
        XCTAssertFalse(can(due: "2026-11-21T18:00:00.500Z", at: dueDate.addingTimeInterval(0.6)))
    }
}
