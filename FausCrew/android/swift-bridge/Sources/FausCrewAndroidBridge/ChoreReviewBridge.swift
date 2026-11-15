import Foundation
import FausCrewCore

// The review section of Android's chore detail, from Core's `ChoreReviewSummary`. One call per
// opened chore, never per dashboard item.

/// The chore's review state, the house's member ids and the signed-in user (`""` when unknown).
private struct ChoreReviewInput: Decodable {
    struct Vote: Decodable {
        let reviewRound: Int
        let reviewerId: String
        let isApproved: Bool
    }

    let status: Int
    let reviewRound: Int
    let votes: [Vote]
    let assigneeId: String
    let memberIds: [String]
    let userId: String
}

/// `inputJson` is a `ChoreReviewInput`. Returns the summary as JSON, or `{"ok":false}`.
public func choreReviewSummary(_ inputJson: String) -> String {
    guard let input = try? JSONDecoder().decode(ChoreReviewInput.self, from: Data(inputJson.utf8)) else {
        return json(["ok": false])
    }
    let summary = ChoreReviewSummary(
        status: ChoreStatus(apiValue: input.status),
        reviewRound: input.reviewRound,
        votes: input.votes.map {
            ChoreReviewVote(
                id: "", choreId: "", houseId: "", reviewRound: $0.reviewRound,
                reviewerId: $0.reviewerId, isApproved: $0.isApproved, createdOn: ""
            )
        },
        assigneeId: input.assigneeId,
        memberIds: input.memberIds,
        currentUserId: input.userId.isEmpty ? nil : input.userId
    )
    var object: [String: Any] = [
        "ok": true,
        "eligibleReviewerCount": summary.eligibleReviewerCount,
        "canReview": summary.canReview,
        "rounds": summary.rounds.map(roundObject),
    ]
    if let vote = summary.currentUserVote { object["currentUserVote"] = voteObject(vote) }
    return json(object)
}

private func roundObject(_ round: ChoreReviewSummary.Round) -> [String: Any] {
    [
        "number": round.number,
        "isActive": round.isActive,
        "approved": round.approvedCount,
        "rejected": round.rejectedCount,
        "pending": round.pendingCount,
        "approvedRatio": round.approvedRatio,
        "rejectedRatio": round.rejectedRatio,
        "completionRatio": round.completionRatio,
        "votes": round.votes.map(voteObject),
    ]
}
