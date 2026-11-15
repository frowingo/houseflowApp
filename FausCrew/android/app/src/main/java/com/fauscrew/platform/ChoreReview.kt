package com.fauscrew.platform

import com.fauscrew.androidbridge.FausCrewAndroidBridge
import org.json.JSONArray
import org.json.JSONObject

/** One round of a chore's review, tallied by Core (`ChoreReviewSummary.Round`). */
internal data class ReviewRound(
    val number: Int, val isActive: Boolean, val votes: List<HouseVote>,
    val approved: Int, val rejected: Int, val pending: Int,
    val approvedRatio: Float, val rejectedRatio: Float, val completionRatio: Float,
)

/** How a chore's review stands for the signed-in user (Core `ChoreReviewSummary`). */
internal data class ChoreReview(
    val eligibleReviewerCount: Int,
    /** Newest round first. */
    val rounds: List<ReviewRound>,
    val currentUserVote: HouseVote?,
    val canReview: Boolean,
) {
    companion object {
        /** Nothing to show: what a rejected bridge call degrades to. */
        private val NONE = ChoreReview(0, emptyList(), null, false)

        /**
         * One bridge call per opened chore, never per dashboard item. [userId] is `""` for an
         * unknown user (the bridge reads it as none).
         */
        fun of(chore: HouseChore, members: List<HouseMember>, userId: String, wire: ChoreReviewWire = NativeChoreReviewWire): ChoreReview {
            val input = JSONObject().put("status", chore.status).put("reviewRound", chore.reviewRound)
                .put("assigneeId", chore.assignedTo).put("userId", userId)
                .put("memberIds", JSONArray(members.map { it.id }))
                .put("votes", JSONArray(chore.reviewVotes.map {
                    JSONObject().put("reviewRound", it.reviewRound).put("reviewerId", it.reviewerId).put("isApproved", it.isApproved)
                }))
            val result = JSONObject(wire.summary(input.toString()))
            if (!result.optBoolean("ok")) return NONE
            return ChoreReview(
                eligibleReviewerCount = result.getInt("eligibleReviewerCount"),
                rounds = result.getJSONArray("rounds").objects { it.toReviewRound() },
                currentUserVote = result.optJSONObject("currentUserVote")?.toHouseVote(),
                canReview = result.getBoolean("canReview"),
            )
        }
    }
}

private fun JSONObject.toReviewRound() = ReviewRound(
    number = getInt("number"), isActive = getBoolean("isActive"),
    votes = getJSONArray("votes").objects { it.toHouseVote() },
    approved = getInt("approved"), rejected = getInt("rejected"), pending = getInt("pending"),
    approvedRatio = getDouble("approvedRatio").toFloat(), rejectedRatio = getDouble("rejectedRatio").toFloat(),
    completionRatio = getDouble("completionRatio").toFloat(),
)

internal interface ChoreReviewWire {
    fun summary(inputJson: String): String
}

internal object NativeChoreReviewWire : ChoreReviewWire {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    override fun summary(inputJson: String): String {
        checked
        return FausCrewAndroidBridge.choreReviewSummary(inputJson)
    }
}
