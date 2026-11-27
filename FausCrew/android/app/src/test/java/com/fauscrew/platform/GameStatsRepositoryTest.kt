package com.fauscrew.platform

import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Assert.assertTrue
import org.junit.Test

class GameStatsRepositoryTest {
    private val requests = mutableListOf<PlatformHttpRequest>()
    private val responses = mutableListOf<Triple<Int, String, String>>()
    private var status = 200
    private var requestJson = """{"ok":true,"path":"game/stats","method":"GET","query":[{"name":"houseId","value":"h1"}]}"""
    private var responseJson = """{"ok":true,"games":[]}"""
    private val wire = object : GameStatsWire {
        override fun request(houseId: String): String = requestJson
        override fun response(status: Int, body: String, contextJson: String): String {
            responses += Triple(status, body, contextJson)
            return responseJson
        }
    }
    private val repo = GameStatsRepository(
        send = { request -> requests += request; PlatformHttpResponse(status, emptyMap(), "raw".toByteArray()) }, wire = wire,
    )

    @Test fun fetchSendsCoreRequestWithTheJwtAndReturnsTheCheckedBody() = runBlocking {
        val body = repo.fetch("h1", "jwt")
        val request = requests.single()
        assertEquals("game/stats", request.path)
        assertEquals("GET", request.method)
        assertEquals(listOf(PlatformHttpQueryItem("houseId", "h1")), request.queryItems)
        assertNull(request.encodedQuery)
        assertEquals(mapOf("Authorization" to "Bearer jwt"), request.headers)
        assertEquals("raw", body)
        assertEquals(200, responses.single().first)
    }

    @Test fun refusedRequestIsNotSent() {
        requestJson = """{"ok":false,"kind":"invalidRequest"}"""
        val error = assertThrows(GameStatsRequestException::class.java) { runBlocking { repo.fetch("a/b", "jwt") } }
        assertEquals("invalidRequest", error.kind)
        assertTrue(requests.isEmpty())
    }

    @Test fun failureCarriesKindStatusAndServerMessage() {
        status = 429
        responseJson = """{"ok":false,"kind":"rateLimited","message":"Yavaş"}"""
        val error = assertThrows(GameStatsRequestException::class.java) { runBlocking { repo.fetch("h1", "jwt") } }
        assertEquals("rateLimited", error.kind)
        assertEquals(429, error.status)
        assertEquals("Yavaş", error.message)
    }

    @Test fun boardPassesMembersAndKnownGamesAndParsesSections() {
        responseJson = """
            {"ok":true,
             "games":[{"gameKey":"fausSwitch","standings":[{"userId":"u2","wins":5,"matchesPlayed":9,"isLeader":true},{"userId":"u1","wins":0,"matchesPlayed":0,"isLeader":false}]},
                      {"gameKey":"houseTanks","standings":[{"userId":"u1","wins":1,"matchesPlayed":1,"isLeader":true}]}],
             "overall":{"standings":[{"userId":"u2","wins":5,"matchesPlayed":9,"isLeader":true},{"userId":"u1","wins":1,"matchesPlayed":1,"isLeader":false}]}}
        """.trimIndent()
        val board = repo.board("raw", listOf("u1", "u2"), setOf("houseTanks", "fausSwitch"))

        val context = JSONObject(responses.single().third)
        assertEquals(listOf("u1", "u2"), List(context.getJSONArray("memberIds").length()) { context.getJSONArray("memberIds").getString(it) })
        assertEquals(listOf("fausSwitch", "houseTanks"),
            List(context.getJSONArray("knownGameKeys").length()) { context.getJSONArray("knownGameKeys").getString(it) })
        assertEquals(listOf("fausSwitch", "houseTanks"), board.games.map { it.gameKey })
        assertEquals(GameStanding("u2", 5, 9, true), board.games[0].standings[0])
        assertEquals(false, board.games[0].standings[1].hasPlayed)
        assertNull(board.overall?.gameKey)
        assertEquals(listOf("u2", "u1"), board.overall?.standings?.map { it.userId })
    }

    @Test fun emptyBoardHasNoOverall() {
        val board = repo.board("raw", listOf("u1"), setOf("fausSwitch"))
        assertTrue(board.isEmpty)
        assertNull(board.overall)
    }
}
