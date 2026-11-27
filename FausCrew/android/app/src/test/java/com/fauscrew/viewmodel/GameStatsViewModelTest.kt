package com.fauscrew.viewmodel

import com.fauscrew.platform.GameStatsRepository
import com.fauscrew.platform.GameStatsWire
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import java.util.concurrent.CopyOnWriteArrayList
import java.util.concurrent.Executors
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withTimeout
import kotlinx.coroutines.withTimeoutOrNull
import org.json.JSONArray
import org.json.JSONObject
import org.junit.AfterClass
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.BeforeClass
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class GameStatsViewModelTest {
    private companion object {
        // One real thread stands in for the main thread, like in ChoreArchiveViewModelTest.
        private val mainThread = Executors.newSingleThreadExecutor()

        @JvmStatic @BeforeClass fun setUpMain() = Dispatchers.setMain(mainThread.asCoroutineDispatcher())

        @JvmStatic @AfterClass fun tearDownMain() {
            Dispatchers.resetMain()
            mainThread.shutdown()
        }
    }

    private val requests = CopyOnWriteArrayList<PlatformHttpRequest>()
    private val contexts = CopyOnWriteArrayList<String>()
    private val pauses = CopyOnWriteArrayList<Long>()
    private var jwt: String? = "jwt"
    /** Answers in order; the last one repeats. A 2xx body is the bridge-shaped board itself. */
    private var answers: List<Pair<Int, String>> = listOf(board("u1"))

    private fun board(vararg users: String): Pair<Int, String> {
        val standings = JSONArray(users.map { JSONObject().put("userId", it).put("wins", 1).put("matchesPlayed", 1).put("isLeader", false) })
        val game = JSONObject().put("gameKey", "fausSwitch").put("standings", standings)
        return 200 to JSONObject().put("ok", true).put("games", JSONArray(listOf(game))).toString()
    }

    private val wire = object : GameStatsWire {
        override fun request(houseId: String): String = JSONObject().put("ok", true).put("path", "game/stats").put("method", "GET")
            .put("query", JSONArray(listOf(JSONObject().put("name", "houseId").put("value", houseId)))).toString()

        override fun response(status: Int, body: String, contextJson: String): String {
            contexts += contextJson
            return when (status) {
                in 200..299 -> body
                401 -> """{"ok":false,"kind":"unauthorized"}"""
                403, 404 -> """{"ok":false,"kind":"accessLost"}"""
                429 -> """{"ok":false,"kind":"rateLimited","message":"Yavaş"}"""
                else -> """{"ok":false,"kind":"server","message":"Down"}"""
            }
        }
    }

    private val repository = GameStatsRepository(
        send = { request ->
            requests += request
            val (status, body) = answers[minOf(requests.size - 1, answers.size - 1)]
            PlatformHttpResponse(status, emptyMap(), body.toByteArray())
        },
        wire = wire,
    )

    private fun model() = GameStatsViewModel(repository, { jwt }, setOf("fausSwitch"), 2_000, { pauses += it })

    private fun main(block: () -> Unit) = runBlocking(Dispatchers.Main) { block() }

    private fun GameStatsViewModel.await(predicate: (GameStatsUiState) -> Boolean) = runBlocking {
        withTimeout(5_000) { state.first(predicate) }
    }

    private fun GameStatsViewModel.loaded(): GameStatsViewModel {
        main { setContext("u1", "h1") }
        main { refresh() }
        await { it.phase == GameStatsPhase.READY || it.phase == GameStatsPhase.ERROR }
        return this
    }

    private fun GameStatsViewModel.nextEffect(): GameStatsEffect? = runBlocking { withTimeoutOrNull(500) { effects.first() } }

    @Test fun nothingLoadsUntilRefresh() {
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.setMembers(listOf("u1")) }
        assertTrue(requests.isEmpty())
        assertEquals(GameStatsPhase.IDLE, model.state.value.phase)
    }

    @Test fun refreshLoadsTheHouseWithTheJwtAndMembers() {
        val model = model()
        main { model.setMembers(listOf("u1", "u2")) }
        model.loaded()
        val request = requests.single()
        assertEquals("game/stats", request.path)
        assertEquals("h1", request.queryItems.single().value)
        assertEquals("Bearer jwt", request.headers["Authorization"])
        assertEquals("fausSwitch", model.state.value.board?.games?.single()?.gameKey)
        val context = JSONObject(contexts.last())
        assertEquals(2, context.getJSONArray("memberIds").length())
    }

    @Test fun memberChangeRebuildsTheBoardWithoutARequest() {
        val model = model().loaded()
        main { model.setMembers(listOf("u9")) }
        assertEquals(1, requests.size)
        assertEquals("u9", JSONObject(contexts.last()).getJSONArray("memberIds").getString(0))
    }

    @Test fun firstLoadFailureShowsTheServerMessage() {
        answers = listOf(500 to "")
        val state = model().loaded().state.value
        assertEquals(GameStatsPhase.ERROR, state.phase)
        assertEquals("Down", state.errorMessage)
    }

    @Test fun failedRefreshKeepsTheBoard() {
        answers = listOf(board("u1"), 500 to "")
        val model = model().loaded()
        main { model.refresh() }
        runBlocking { withTimeout(5_000) { while (requests.size < 2) kotlinx.coroutines.delay(10) } }
        Thread.sleep(100)
        val state = model.state.value
        assertEquals(GameStatsPhase.READY, state.phase)
        assertEquals("fausSwitch", state.board?.games?.single()?.gameKey)
    }

    @Test fun rateLimitWithNothingShownRetriesOnce() {
        answers = listOf(429 to "", board("u1"))
        val model = model().loaded()
        assertEquals(listOf(2_000L), pauses.toList())
        assertEquals(2, requests.size)
        assertEquals(GameStatsPhase.READY, model.state.value.phase)
    }

    @Test fun rateLimitTwiceFails() {
        answers = listOf(429 to "")
        val model = model().loaded()
        assertEquals(2, requests.size)
        assertEquals(GameStatsPhase.ERROR, model.state.value.phase)
        assertEquals("Yavaş", model.state.value.errorMessage)
    }

    @Test fun rateLimitWithABoardShownIsQuiet() {
        answers = listOf(board("u1"), 429 to "")
        val model = model().loaded()
        main { model.refresh() }
        runBlocking { withTimeout(5_000) { while (requests.size < 2) kotlinx.coroutines.delay(10) } }
        Thread.sleep(100)
        assertTrue(pauses.isEmpty())
        assertEquals(GameStatsPhase.READY, model.state.value.phase)
    }

    @Test fun accessLostAsksForAProfileRefreshOncePerContext() {
        answers = listOf(403 to "")
        val model = model().loaded()
        assertEquals(GameStatsEffect.RefreshProfile, model.nextEffect())
        main { model.refresh() }
        model.await { it.phase == GameStatsPhase.ERROR }
        Thread.sleep(100)
        assertNull(model.nextEffect())
        main { model.setContext("u1", "h2") }
        main { model.refresh() }
        assertEquals(GameStatsEffect.RefreshProfile, model.nextEffect())
    }

    @Test fun unauthorizedOrNoSessionRejectsTheSession() {
        answers = listOf(401 to "")
        assertEquals(GameStatsEffect.SessionRejected, model().loaded().nextEffect())
        jwt = null
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.refresh() }
        assertEquals(GameStatsEffect.SessionRejected, model.nextEffect())
    }

    @Test fun contextChangeClearsTheBoard() {
        val model = model().loaded()
        main { model.setContext("u1", "h2") }
        assertEquals(GameStatsUiState(), model.state.value)
    }
}
