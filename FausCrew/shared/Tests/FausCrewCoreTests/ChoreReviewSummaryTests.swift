import XCTest
@testable import FausCrewCore

final class ChoreReviewSummaryTests: XCTestCase {
    func testRoundsCombineVoteRoundsWithTheCurrentOneNewestFirst() {
        let summary = makeSummary(reviewRound: 3, votes: [vote("a", round: 1), vote("b", round: 2)])
        XCTAssertEqual(summary.rounds.map(\.number), [3, 2, 1])
    }

    func testCurrentRoundWithoutVotesIsStillListed() {
        let summary = makeSummary(reviewRound: 2, votes: [vote("a", round: 1)])
        XCTAssertEqual(summary.rounds.map(\.number), [2, 1])
        XCTAssertEqual(summary.rounds.first?.votes, [])
    }

    func testRoundZeroIsListedOnlyWhenItHasVotes() {
        XCTAssertEqual(makeSummary(reviewRound: 0, votes: []).rounds, [])
        XCTAssertEqual(makeSummary(reviewRound: 0, votes: [vote("a", round: 0)]).rounds.map(\.number), [0])
    }

    func testOnlyTheCurrentRoundOfAnInTestChoreIsActive() {
        let votes = [vote("a", round: 1)]
        XCTAssertEqual(makeSummary(reviewRound: 2, votes: votes).rounds.map(\.isActive), [true, false])
        XCTAssertEqual(makeSummary(status: .completed, reviewRound: 2, votes: votes).rounds.map(\.isActive), [false, false])
        XCTAssertEqual(makeSummary(reviewRound: 0, votes: [vote("a", round: 0)]).rounds.map(\.isActive), [false])
    }

    func testEligibleReviewersExcludeTheAssignee() {
        XCTAssertEqual(makeSummary(reviewRound: 1, votes: []).eligibleReviewerCount, 2)
        XCTAssertEqual(makeSummary(assigneeId: "nobody", reviewRound: 1, votes: []).eligibleReviewerCount, 3)
        XCTAssertEqual(makeSummary(assigneeId: nil, reviewRound: 1, votes: []).eligibleReviewerCount, 3)
    }

    func testRoundTalliesIgnoreVotesFromOtherRounds() throws {
        let summary = makeSummary(reviewRound: 2, votes: [
            vote("b", round: 1, approved: false), vote("b", round: 2), vote("c", round: 2, approved: false),
        ])
        let current = try XCTUnwrap(summary.rounds.first)
        XCTAssertEqual(current.approvedCount, 1)
        XCTAssertEqual(current.rejectedCount, 1)
        XCTAssertEqual(current.pendingCount, 0)
        let earlier = try XCTUnwrap(summary.rounds.last)
        XCTAssertEqual(earlier.approvedCount, 0)
        XCTAssertEqual(earlier.rejectedCount, 1)
        XCTAssertEqual(earlier.pendingCount, 1)
    }

    func testPendingNeverGoesNegative() throws {
        // The assignee's own vote, or a member who left, can push votes past the eligible count.
        let summary = makeSummary(reviewRound: 1, votes: [vote("a", round: 1), vote("b", round: 1), vote("c", round: 1)])
        let round = try XCTUnwrap(summary.rounds.first)
        XCTAssertEqual(round.pendingCount, 0)
        XCTAssertEqual(round.completionRatio, 1)
        XCTAssertEqual(round.approvedRatio, 1)
    }

    func testRatiosFollowEligibleReviewers() throws {
        let summary = makeSummary(reviewRound: 1, votes: [vote("b", round: 1), vote("c", round: 1, approved: false)])
        let round = try XCTUnwrap(summary.rounds.first)
        XCTAssertEqual(round.approvedRatio, 0.5)
        XCTAssertEqual(round.rejectedRatio, 0.5)
        XCTAssertEqual(round.completionRatio, 1)

        let waiting = try XCTUnwrap(makeSummary(reviewRound: 1, votes: [vote("b", round: 1)]).rounds.first)
        XCTAssertEqual(waiting.completionRatio, 0.5)
    }

    func testWithoutEligibleReviewersNobodyIsWaitedFor() throws {
        let summary = makeSummary(memberIds: ["a"], reviewRound: 1, votes: [])
        let round = try XCTUnwrap(summary.rounds.first)
        XCTAssertEqual(summary.eligibleReviewerCount, 0)
        XCTAssertEqual(round.pendingCount, 0)
        XCTAssertEqual(round.approvedRatio, 0)
        XCTAssertEqual(round.rejectedRatio, 0)
        XCTAssertEqual(round.completionRatio, 1)
    }

    func testRoundFindsAReviewersVote() throws {
        let round = try XCTUnwrap(makeSummary(reviewRound: 1, votes: [vote("b", round: 1)]).rounds.first)
        XCTAssertEqual(round.vote(by: "b")?.reviewerId, "b")
        XCTAssertNil(round.vote(by: "c"))
    }

    // MARK: - Who may review

    func testAnotherMemberCanReviewAnInTestChoreOnce() {
        let open = makeSummary(reviewRound: 1, votes: [], currentUserId: "b")
        XCTAssertTrue(open.canReview)
        XCTAssertNil(open.currentUserVote)

        let voted = makeSummary(reviewRound: 1, votes: [vote("b", round: 1, approved: false)], currentUserId: "b")
        XCTAssertFalse(voted.canReview)
        XCTAssertEqual(voted.currentUserVote?.isApproved, false)
    }

    func testAnEarlierRoundVoteDoesNotBlockTheCurrentRound() {
        let summary = makeSummary(reviewRound: 2, votes: [vote("b", round: 1)], currentUserId: "b")
        XCTAssertTrue(summary.canReview)
        XCTAssertNil(summary.currentUserVote)
    }

    func testTheAssigneeCannotReview() {
        XCTAssertFalse(makeSummary(reviewRound: 1, votes: [], currentUserId: "a").canReview)
    }

    func testAnUnknownUserCannotReview() {
        XCTAssertFalse(makeSummary(reviewRound: 1, votes: [], currentUserId: nil).canReview)
        XCTAssertFalse(makeSummary(assigneeId: nil, reviewRound: 1, votes: [], currentUserId: nil).canReview)
    }

    func testOnlyInTestChoresTakeReviews() {
        for status in [ChoreStatus.draft, .progress, .completed, .failed, .unknown] {
            XCTAssertFalse(makeSummary(status: status, reviewRound: 1, votes: [], currentUserId: "b").canReview, "\(status)")
        }
    }

    // MARK: - Helpers

    private func makeSummary(
        status: ChoreStatus = .inTest,
        assigneeId: String? = "a",
        memberIds: [String] = ["a", "b", "c"],
        reviewRound: Int,
        votes: [ChoreReviewVote],
        currentUserId: String? = "b"
    ) -> ChoreReviewSummary {
        ChoreReviewSummary(
            status: status, reviewRound: reviewRound, votes: votes,
            assigneeId: assigneeId, memberIds: memberIds, currentUserId: currentUserId
        )
    }

    private func vote(_ reviewerId: String, round: Int, approved: Bool = true) -> ChoreReviewVote {
        ChoreReviewVote(
            id: "\(reviewerId)-\(round)", choreId: "c", houseId: "h", reviewRound: round,
            reviewerId: reviewerId, isApproved: approved, createdOn: "2026-10-12T18:30:00Z"
        )
    }
}
