package com.houseflow.platform

import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class DashboardRepositoryTest {
    private val requests = mutableListOf<PlatformHttpRequest>()
    private var response = ""
    private val wire = object : DashboardWire {
        override fun body(action: String, houseId: String, choreId: String, assignedTo: String,
            title: String, description: String, dueDate: String, isRecurring: Boolean, level: Int,
            recurringInterval: Int, status: Int, isApproved: Boolean): String =
            JSONObject().put("action", action).put("houseId", houseId).put("choreId", choreId)
                .put("assignedTo", assignedTo).put("isRecurring", isRecurring)
                .put("recurringInterval", recurringInterval).put("status", status)
                .put("isApproved", isApproved).toString()
        override fun response(action: String, status: Int, body: String): String =
            if (status >= 400) JSONObject().put("ok", false).put("message", "Denied").toString()
            else JSONObject().put("ok", true).put("data", body).toString()
    }
    private val repo = DashboardRepository(
        send = { request -> requests += request; PlatformHttpResponse(200, emptyMap(), response.toByteArray()) },
        read = { SessionReadResult.Value("token") }, wire = wire,
    )
    private val input = ChoreInput("h", "u", "Dishes", "Kitchen", "2026-10-12T00:00:00Z", true, 20, 7)
    private val chore = """{"id":"c","houseId":"h","title":"Dishes","description":"Kitchen","assignedTo":"u","dueDate":"2026-10-12T00:00:00Z","status":0,"isCompleted":false,"isRecurring":true,"level":20,"recurringInterval":7,"reviewRound":0,"reviewVotes":[]}"""

    @Test fun createUpdateStatusAndReviewUseIosPathsAndTypedResults() = runBlocking {
        response = chore
        assertEquals("c", repo.createChore(input).id)
        assertEquals(7, repo.updateChore("c", input).recurringInterval)
        response = JSONArray().put(JSONObject(chore).put("status", 1)).toString()
        assertEquals(1, repo.updateStatus("h", "c", 1).single().status)
        response = JSONObject(chore).put("status", 2).toString()
        assertEquals(2, repo.review("c", true).status)
        assertEquals(listOf("chore", "chore/c", "chore/status", "chore/review"), requests.map { it.path })
        assertEquals(listOf("POST", "PUT", "PUT", "PUT"), requests.map { it.method })
        assertTrue(JSONObject(requests.first().body!!.decodeToString()).getBoolean("isRecurring"))
        assertEquals(7, JSONObject(requests.first().body!!.decodeToString()).getInt("recurringInterval"))
        assertEquals("h", JSONObject(requests[2].body!!.decodeToString()).getString("houseId"))
        assertEquals("Bearer token", requests.first().headers["Authorization"])
    }

    @Test fun announcementUsesHouseEndpointAndAliases() = runBlocking {
        response = """{"success":true,"data":{"announcementId":"a","houseId":"h","title":"Note","description":"Hello","createdAt":{"time.Time":"2026-10-12T10:00:00Z"}}}"""
        val item = repo.announce("h", "Note", "Hello")
        assertEquals("a", item.id)
        assertEquals("Hello", item.message)
        assertEquals("2026-10-12T10:00:00Z", item.createdOn)
        assertEquals("house/announcement", requests.single().path)
        assertEquals("h", JSONObject(requests.single().body!!.decodeToString()).getString("houseId"))
    }

    @Test fun noTokenNeverSendsMutation() = runBlocking {
        val noToken = DashboardRepository(
            send = { request -> requests += request; PlatformHttpResponse(200, emptyMap(), response.toByteArray()) },
            read = { SessionReadResult.Missing }, wire = wire,
        )
        assertTrue(runCatching { noToken.createChore(input) }.exceptionOrNull() is HouseRequestException)
        assertTrue(requests.isEmpty())
    }

    @Test fun detailProjectionRetainsReviewAndAssignment() {
        val parsed = JSONObject(chore).put("reviewRound", 2).put("reviewVotes", JSONArray().put(
            JSONObject().put("reviewRound", 2).put("reviewerId", "v").put("isApproved", false)))
            .toHouseChore()
        assertEquals("u", parsed.assignedTo)
        assertEquals(2, parsed.reviewVotes.single().reviewRound)
        assertFalse(parsed.reviewVotes.single().isApproved)
    }
}
