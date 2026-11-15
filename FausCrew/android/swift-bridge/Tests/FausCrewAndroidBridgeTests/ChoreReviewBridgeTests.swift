import XCTest
@testable import FausCrewAndroidBridge

final class ChoreReviewBridgeTests: XCTestCase {
    func testSummaryComesFromCoreRules() throws {
        let summary = try object(choreReviewSummary(input(userId: "user-2")))

        XCTAssertEqual(summary["ok"] as? Bool, true)
        XCTAssertEqual(summary["eligibleReviewerCount"] as? Int, 2)
        XCTAssertEqual(summary["canReview"] as? Bool, true)
        XCTAssertNil(summary["currentUserVote"])

        let rounds = try XCTUnwrap(summary["rounds"] as? [[String: Any]])
        XCTAssertEqual(rounds.map { $0["number"] as? Int }, [2, 1])
        XCTAssertEqual(rounds.map { $0["isActive"] as? Bool }, [true, false])
        let current = rounds[0]
        XCTAssertEqual(current["approved"] as? Int, 1)
        XCTAssertEqual(current["rejected"] as? Int, 0)
        XCTAssertEqual(current["pending"] as? Int, 1)
        XCTAssertEqual(current["approvedRatio"] as? Double, 0.5)
        XCTAssertEqual(current["completionRatio"] as? Double, 0.5)
        XCTAssertEqual((current["votes"] as? [[String: Any]])?.first?["reviewerId"] as? String, "user-3")
    }

    func testTheCurrentUsersVoteStopsThem() throws {
        let summary = try object(choreReviewSummary(input(userId: "user-3")))

        XCTAssertEqual(summary["canReview"] as? Bool, false)
        XCTAssertEqual((summary["currentUserVote"] as? [String: Any])?["isApproved"] as? Bool, true)
    }

    func testAssigneeAndUnknownUserCannotReview() throws {
        for userId in ["user-1", ""] {
            XCTAssertEqual(try object(choreReviewSummary(input(userId: userId)))["canReview"] as? Bool, false, userId)
        }
    }

    func testUnreadableInputIsRejected() throws {
        XCTAssertEqual(try object(choreReviewSummary("{}"))["ok"] as? Bool, false)
    }

    private func input(userId: String) -> String {
        """
        {"status":2,"reviewRound":2,"assigneeId":"user-1","memberIds":["user-1","user-2","user-3"],"userId":"\(userId)",
         "votes":[{"reviewRound":1,"reviewerId":"user-2","isApproved":false},{"reviewRound":2,"reviewerId":"user-3","isApproved":true}]}
        """
    }

    private func object(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }
}
