package com.fauscrew.platform

import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class ChoreArchiveRepositoryTest {
    private val requests = mutableListOf<PlatformHttpRequest>()
    private val fields = mutableListOf<Pair<String, String>>()
    private var status = 200
    private var requestJson = """{"ok":true,"path":"chore/archive","method":"GET","query":[{"name":"houseId","value":"h1"},{"name":"from","value":"2026-10-31T21:00:00Z"}]}"""
    private var responseJson = """{"ok":true,"chores":[{"id":"c1","houseId":"h1","title":"Dishes","status":4,"failureReason":"reviewRejected","completedAt":"2026-11-14T08:00:00Z","completedBy":"system"}],"nextUrl":"/api/v1/chore/archive?cursor=a%2Bb"}"""
    private val responses = mutableListOf<Triple<Int, String, String>>()
    private val wire = object : ChoreArchiveWire {
        override fun request(action: String, fieldsJson: String): String {
            fields += action to fieldsJson
            return requestJson
        }
        override fun response(status: Int, body: String): String {
            responses += Triple(status, body, "")
            return responseJson
        }
    }
    private val repo = ChoreArchiveRepository(
        send = { request -> requests += request; PlatformHttpResponse(status, emptyMap(), "raw".toByteArray()) }, wire = wire,
    )

    @Test fun firstPagePassesEpochsToCoreAndSendsItsRequestWithTheJwt() = runBlocking {
        val page = repo.firstPage("h1", 1793480400L, 1796072400L, "jwt")
        val (action, json) = fields.single()
        assertEquals("first", action)
        assertEquals("h1", JSONObject(json).getString("houseId"))
        assertEquals(1793480400L, JSONObject(json).getLong("fromEpochSeconds"))
        assertEquals(1796072400L, JSONObject(json).getLong("toEpochSeconds"))
        val request = requests.single()
        assertEquals("chore/archive", request.path)
        assertEquals("GET", request.method)
        assertEquals(listOf(PlatformHttpQueryItem("houseId", "h1"), PlatformHttpQueryItem("from", "2026-10-31T21:00:00Z")), request.queryItems)
        assertNull(request.encodedQuery)
        assertEquals(mapOf("Authorization" to "Bearer jwt"), request.headers)
        assertEquals(listOf(Triple(200, "raw", "")), responses)
        assertEquals("c1", page.chores.single().id)
        assertEquals(ChoreFailureReason.REVIEW_REJECTED, page.chores.single().failureReason)
        assertEquals("system", page.chores.single().completedBy)
        assertEquals("2026-11-14T08:00:00Z", page.chores.single().completedAt)
        assertEquals("/api/v1/chore/archive?cursor=a%2Bb", page.nextUrl)
    }

    @Test fun nextPageSendsTheEncodedQueryAsIs() = runBlocking {
        requestJson = """{"ok":true,"path":"chore/archive","method":"GET","query":[],"percentEncodedQuery":"cursor=a%2Bb+c/d%3D"}"""
        responseJson = """{"ok":true,"chores":[]}"""
        val page = repo.nextPage("/api/v1/chore/archive?cursor=a%2Bb+c/d%3D", "jwt")
        assertEquals("next", fields.single().first)
        assertEquals("/api/v1/chore/archive?cursor=a%2Bb+c/d%3D", JSONObject(fields.single().second).getString("nextUrl"))
        assertEquals("cursor=a%2Bb+c/d%3D", requests.single().encodedQuery)
        assertEquals(emptyList<PlatformHttpQueryItem>(), requests.single().queryItems)
        assertEquals(emptyList<HouseChore>(), page.chores)
        assertNull(page.nextUrl)
    }

    @Test fun serverRefusalsKeepKindStatusAndMessage() {
        status = 403
        responseJson = """{"ok":false,"kind":"notMember","message":"Denied"}"""
        val error = assertThrows(ChoreArchiveRequestException::class.java) { runBlocking { repo.firstPage("h1", 1, 2, "jwt") } }
        assertEquals("notMember", error.kind)
        assertEquals(403, error.status)
        assertEquals("Denied", error.message)
    }

    @Test fun aRequestCoreRefusesIsNeverSent() {
        requestJson = """{"ok":false,"kind":"invalidRequest"}"""
        val error = assertThrows(ChoreArchiveRequestException::class.java) { runBlocking { repo.nextPage("/bad", "jwt") } }
        assertEquals("invalidRequest", error.kind)
        assertNull(error.status)
        assertEquals(0, requests.size)
    }
}
