package com.fauscrew.platform

import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertArrayEquals
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Test

class DashboardRepositoryTest {
    private val requests = mutableListOf<PlatformHttpRequest>()
    private var response = ""
    private val wire = object : DashboardWire {
        override fun body(action: String, houseId: String, choreId: String, assignedTo: String,
            title: String, description: String, dueDate: String, isRecurring: Boolean, level: Int,
            recurringInterval: Int, status: Int, isApproved: Boolean): String =
            if (action == "statusPhoto") """[{"choreId":"$choreId","status":$status}]""" else JSONObject().put("action", action).put("houseId", houseId).put("choreId", choreId)
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

    @Test fun reviewPhotoStatusSendsSingleInTestMultipart() = runBlocking {
        response = JSONArray().put(JSONObject(chore).put("status", 2).put("reviewRound", 1)
            .put("reviewPhotoRounds", JSONArray().put(1))).toString()
        val photo = ReviewPhoto.from(ReviewPhotoTest.jpeg)

        val updated = repo.updateStatusWithReviewPhoto("h", "c", photo).single()

        assertEquals(listOf(1), updated.reviewPhotoRounds)
        val request = requests.single()
        assertEquals("chore/status", request.path)
        assertEquals("PUT", request.method)
        assertEquals("Bearer token", request.headers["Authorization"])
        assertNull(request.headers["Content-Type"])
        assertNull(request.body)
        val parts = requireNotNull(request.multipart)
        assertEquals(listOf("houseId", "chores", "file"), parts.map { it.name })
        assertEquals("h", parts[0].value.decodeToString())
        val chores = JSONArray(parts[1].value.decodeToString())
        assertEquals(1, chores.length())
        assertEquals("c", chores.getJSONObject(0).getString("choreId"))
        assertEquals(2, chores.getJSONObject(0).getInt("status"))
        assertNull(parts[1].fileName)
        assertEquals("review-photo.jpg", parts[2].fileName)
        assertEquals("image/jpeg", parts[2].contentType)
        assertArrayEquals(ReviewPhotoTest.jpeg, parts[2].value)
    }

    @Test fun storage403RefreshesSignedUrlExactlyOnce() = runBlocking {
        val downloads = mutableListOf<String>()
        val photoRepo = reviewPhotoRepo(downloads) { if (downloads.size == 1) 403 else 200 }

        assertArrayEquals(ReviewPhotoTest.jpeg, photoRepo.loadReviewPhoto("c", 2))
        assertEquals(listOf("chore/c/review-photo/2", "chore/c/review-photo/2"), requests.map { it.path })
        assertEquals(listOf("GET", "GET"), requests.map { it.method })
        assertNull(requests.first().body)
        assertEquals(listOf("https://signed.example/1", "https://signed.example/2"), downloads)
    }

    @Test fun repeated403NeverLoops() = runBlocking {
        val downloads = mutableListOf<String>()
        val photoRepo = reviewPhotoRepo(downloads) { 403 }

        assertTrue(runCatching { photoRepo.loadReviewPhoto("c", 1) }.exceptionOrNull() is HouseRequestException)
        assertEquals(2, requests.size)
        assertEquals(2, downloads.size)
    }

    @Test fun expiredSignedUrlIsReplacedBeforeDownloadAndUsesTheOnlyRefresh() = runBlocking {
        val downloads = mutableListOf<String>()
        val photoRepo = reviewPhotoRepo(downloads, expiresAt = { index ->
            if (index == 1) "2026-10-29T10:00:00Z" else "2026-10-29T10:20:00Z"
        }, now = java.time.Instant.parse("2026-10-29T10:10:00Z").toEpochMilli()) { 403 }

        assertTrue(runCatching { photoRepo.loadReviewPhoto("c", 1) }.exceptionOrNull() is HouseRequestException)
        assertEquals(2, requests.size)
        assertEquals(listOf("https://signed.example/2"), downloads)
    }

    @Test fun reviewPhotoEndpointErrorsKeepServerMessage() = runBlocking {
        for (status in listOf(403, 404, 503)) {
            requests.clear()
            val failing = DashboardRepository(
                send = { request -> requests += request; PlatformHttpResponse(status, emptyMap(), byteArrayOf()) },
                read = { SessionReadResult.Value("token") }, wire = wire,
                download = { error("must not download") },
            )
            val failure = runCatching { failing.loadReviewPhoto("c", 1) }.exceptionOrNull()
            assertEquals("Denied", (failure as HouseRequestException).serverMessage)
            assertEquals(1, requests.size)
        }
    }

    private fun reviewPhotoRepo(
        downloads: MutableList<String>,
        expiresAt: (Int) -> String = { "2099-01-01T00:00:00Z" },
        now: Long = System.currentTimeMillis(),
        downloadStatus: () -> Int,
    ): DashboardRepository = DashboardRepository(
        send = { request ->
            requests += request
            val body = JSONObject().put("url", "https://signed.example/${requests.size}")
                .put("expiresAt", expiresAt(requests.size)).toString()
            PlatformHttpResponse(200, emptyMap(), body.toByteArray())
        },
        read = { SessionReadResult.Value("token") }, wire = wire,
        download = { url ->
            downloads += url
            val status = downloadStatus()
            PlatformHttpResponse(status, emptyMap(), if (status == 200) ReviewPhotoTest.jpeg else byteArrayOf())
        },
        nowMillis = { now },
    )

    @Test fun detailProjectionRetainsReviewAndAssignment() {
        val parsed = JSONObject(chore).put("reviewRound", 2).put("reviewVotes", JSONArray().put(
            JSONObject().put("reviewRound", 2).put("reviewerId", "v").put("isApproved", false)))
            .toHouseChore()
        assertEquals("u", parsed.assignedTo)
        assertEquals(2, parsed.reviewVotes.single().reviewRound)
        assertFalse(parsed.reviewVotes.single().isApproved)
    }
}
