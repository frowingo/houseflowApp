package com.fauscrew.platform

import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class ChoreReviewTest {
    private val chore = HouseChore(
        id = "c", houseId = "h", title = "Dishes", description = "", assignedTo = "a", dueDate = "",
        status = 2, isCompleted = false, isRecurring = false, level = 10, recurringInterval = 0, reviewRound = 2,
        reviewVotes = listOf(HouseVote(1, "b", false), HouseVote(2, "c", true)),
    )
    private val members = listOf("a", "b", "c").map { HouseMember(it, it, "", "") }

    @Test fun theBridgeIsAskedOnceWithTheChoreMembersAndUser() {
        val inputs = mutableListOf<JSONObject>()
        ChoreReview.of(chore, members, "b", wire { inputs += JSONObject(it); SUMMARY })

        val input = inputs.single()
        assertEquals(2, input.getInt("status"))
        assertEquals(2, input.getInt("reviewRound"))
        assertEquals("a", input.getString("assigneeId"))
        assertEquals("b", input.getString("userId"))
        assertEquals(listOf("a", "b", "c"), (0 until 3).map { input.getJSONArray("memberIds").getString(it) })
        val votes = input.getJSONArray("votes")
        assertEquals(2, votes.length())
        assertEquals("b", votes.getJSONObject(0).getString("reviewerId"))
        assertFalse(votes.getJSONObject(0).getBoolean("isApproved"))
    }

    @Test fun theSummaryIsReadAsCoreSentIt() {
        val review = ChoreReview.of(chore, members, "c", wire { SUMMARY })

        assertEquals(2, review.eligibleReviewerCount)
        assertFalse(review.canReview)
        assertEquals(HouseVote(2, "c", true), review.currentUserVote)
        val (current, earlier) = review.rounds
        assertEquals(ReviewRound(2, true, listOf(HouseVote(2, "c", true)), 1, 0, 1, .5f, 0f, .5f), current)
        assertEquals(1, earlier.number)
        assertFalse(earlier.isActive)
        assertEquals(1, earlier.rejected)
    }

    @Test fun noCurrentUserVoteMeansNone() {
        val review = ChoreReview.of(chore, members, "b", wire { SUMMARY_WITHOUT_VOTE })
        assertNull(review.currentUserVote)
        assertTrue(review.canReview)
    }

    @Test fun aRejectedCallDegradesToNothingToReview() {
        val review = ChoreReview.of(chore, members, "b", wire { """{"ok":false}""" })
        assertEquals(ChoreReview(0, emptyList(), null, false), review)
    }

    private fun wire(summary: (String) -> String) = object : ChoreReviewWire {
        override fun summary(inputJson: String) = summary(inputJson)
    }

    private companion object {
        const val ROUNDS = """"rounds":[
            {"number":2,"isActive":true,"approved":1,"rejected":0,"pending":1,"approvedRatio":0.5,"rejectedRatio":0,"completionRatio":0.5,
             "votes":[{"reviewRound":2,"reviewerId":"c","isApproved":true}]},
            {"number":1,"isActive":false,"approved":0,"rejected":1,"pending":1,"approvedRatio":0,"rejectedRatio":0.5,"completionRatio":0.5,
             "votes":[{"reviewRound":1,"reviewerId":"b","isApproved":false}]}]"""
        const val SUMMARY = """{"ok":true,"eligibleReviewerCount":2,"canReview":false,$ROUNDS,
            "currentUserVote":{"reviewRound":2,"reviewerId":"c","isApproved":true}}"""
        const val SUMMARY_WITHOUT_VOTE = """{"ok":true,"eligibleReviewerCount":2,"canReview":true,$ROUNDS}"""
    }
}
