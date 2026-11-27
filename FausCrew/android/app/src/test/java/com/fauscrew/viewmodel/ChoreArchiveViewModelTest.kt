package com.fauscrew.viewmodel

import com.fauscrew.platform.ChoreArchiveRepository
import com.fauscrew.platform.ChoreArchiveWire
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId
import java.util.concurrent.Executors
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.runBlocking
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withContext
import kotlinx.coroutines.withTimeout
import org.json.JSONArray
import org.json.JSONObject
import org.junit.AfterClass
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.BeforeClass
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class ChoreArchiveViewModelTest {
    private companion object {
        // One real thread stands in for the main thread, like in NotificationViewModelTest.
        private val mainThread = Executors.newSingleThreadExecutor()

        @JvmStatic @BeforeClass fun setUpMain() = Dispatchers.setMain(mainThread.asCoroutineDispatcher())

        @JvmStatic @AfterClass fun tearDownMain() {
            Dispatchers.resetMain()
            mainThread.shutdown()
        }
    }

    private val requests = java.util.concurrent.CopyOnWriteArrayList<PlatformHttpRequest>()
    private var jwt: String? = "jwt"
    private var zone: ZoneId = ZoneId.of("Europe/Istanbul")
    private var today: LocalDate = LocalDate.of(2026, 11, 24)
    /** Answers a request with a status and the bridge-shaped body for a 2xx. */
    private var answer: suspend (PlatformHttpRequest) -> Pair<Int, String> = { page(emptyList()) }

    private fun page(ids: List<String>, next: String? = null): Pair<Int, String> {
        val chores = ids.map { JSONObject().put("id", it).put("houseId", "h1").put("title", "T$it") }
        val body = JSONObject().put("ok", true).put("chores", JSONArray(chores))
        if (next != null) body.put("nextUrl", next)
        return 200 to body.toString()
    }

    private fun item(name: String, value: String) = JSONObject().put("name", name).put("value", value)

    // The fake request carries the epochs as query values and the nextUrl as the encoded query,
    // so tests read back what the view model asked Core for.
    private val wire = object : ChoreArchiveWire {
        override fun request(action: String, fieldsJson: String): String {
            val fields = JSONObject(fieldsJson)
            val request = JSONObject().put("ok", true).put("path", "chore/archive").put("method", "GET")
            return if (action == "first") {
                request.put("query", JSONArray()
                    .put(item("houseId", fields.getString("houseId")))
                    .put(item("from", fields.getLong("fromEpochSeconds").toString()))
                    .put(item("to", fields.getLong("toEpochSeconds").toString()))).toString()
            } else {
                request.put("query", JSONArray()).put("percentEncodedQuery", fields.getString("nextUrl")).toString()
            }
        }

        override fun response(status: Int, body: String): String = when (status) {
            in 200..299 -> body
            400 -> """{"ok":false,"kind":"invalidRequest","message":"Bad range"}"""
            401 -> """{"ok":false,"kind":"unauthorized"}"""
            403 -> """{"ok":false,"kind":"notMember"}"""
            else -> """{"ok":false,"kind":"server"}"""
        }
    }

    private val repository = ChoreArchiveRepository(
        send = { request ->
            requests += request
            val (status, body) = answer(request)
            PlatformHttpResponse(status, emptyMap(), body.toByteArray())
        },
        wire = wire,
    )

    private fun model() = ChoreArchiveViewModel(repository, { jwt }, { zone }, { today })

    /** View model calls come from the main thread, like in the app. */
    private fun main(block: () -> Unit) = runBlocking(Dispatchers.Main) { block() }

    private fun ChoreArchiveViewModel.await(predicate: (ChoreArchiveUiState) -> Boolean) = runBlocking {
        withTimeout(5_000) { state.first(predicate) }
    }

    private fun ChoreArchiveViewModel.opened(): ChoreArchiveViewModel {
        main { setContext("u1", "h1") }
        main { open() }
        await { it.phase == ChoreArchivePhase.READY }
        return this
    }

    private fun PlatformHttpRequest.query(name: String) = queryItems.first { it.name == name }.value!!

    /** The epoch bounds the first request for [month] carried. */
    private fun bounds(zoneId: String, month: YearMonth): Pair<Long, Long> {
        requests.clear()
        zone = ZoneId.of(zoneId)
        today = month.atDay(10)
        model().opened()
        val request = requests.single()
        return request.query("from").toLong() to request.query("to").toLong()
    }

    @Test fun monthBoundsFollowTheZoneThroughDstAndTheYearEnd() {
        assertEquals(1772312400L to 1774990800L, bounds("Europe/Istanbul", YearMonth.of(2026, 3)))
        assertEquals(1790802000L to 1793480400L, bounds("Europe/Istanbul", YearMonth.of(2026, 10)))
        assertEquals(1772319600L to 1774994400L, bounds("Europe/Berlin", YearMonth.of(2026, 3)))
        assertEquals(1790805600L to 1793487600L, bounds("Europe/Berlin", YearMonth.of(2026, 10)))
        assertEquals(1796072400L to 1798750800L, bounds("Europe/Istanbul", YearMonth.of(2026, 12)))
        assertEquals(1796079600L to 1798758000L, bounds("Europe/Berlin", YearMonth.of(2026, 12)))
    }

    @Test fun openStartsAtTheCurrentMonthWithTheJwtAndHouse() {
        answer = { page(listOf("a", "b"), next = "cursor=x") }
        val model = model().opened()
        val state = model.state.value
        assertEquals(YearMonth.of(2026, 11), state.month)
        assertEquals(listOf("a", "b"), state.chores.map { it.id })
        assertTrue(state.canLoadMore)
        assertEquals("h1", requests.single().query("houseId"))
        assertEquals("Bearer jwt", requests.single().headers["Authorization"])
    }

    @Test fun settingTheContextDoesNotLoadAndClearsWhatWasShown() {
        answer = { page(listOf("a")) }
        val model = model().opened()
        main { model.setContext("u1", "h2") }
        assertEquals(1, requests.size)
        assertEquals(ChoreArchiveUiState(month = YearMonth.of(2026, 11)), model.state.value)
        main { model.setContext("u1", "h2") }
        main { model.reload() }
        model.await { it.phase == ChoreArchivePhase.READY }
        assertEquals("h2", requests.last().query("houseId"))
    }

    @Test fun loadMoreAppendsTheNextPageByCursorAndSkipsKnownIds() {
        answer = { request ->
            if (request.encodedQuery == null) page(listOf("a", "b"), next = "cursor=1")
            else page(listOf("b", "c"), next = null)
        }
        val model = model().opened()
        main { model.loadMore() }
        val state = model.await { it.chores.size == 3 && !it.loadingMore }
        assertEquals(listOf("a", "b", "c"), state.chores.map { it.id })
        assertFalse(state.canLoadMore)
        assertEquals("cursor=1", requests.last().encodedQuery)
        val before = requests.size
        main { model.loadMore() }
        assertEquals(before, requests.size)
    }

    @Test fun aFailedPageKeepsTheListAndLoadMoreRetries() {
        var fail = true
        answer = { request ->
            if (request.encodedQuery == null) page(listOf("a"), next = "cursor=1")
            else if (fail) 500 to "" else page(listOf("b"))
        }
        val model = model().opened()
        main { model.loadMore() }
        val failed = model.await { it.loadMoreFailed }
        assertEquals(listOf("a"), failed.chores.map { it.id })
        assertTrue(failed.canLoadMore)
        assertFalse(failed.loadingMore)
        fail = false
        main { model.loadMore() }
        val state = model.await { it.chores.size == 2 && !it.loadingMore }
        assertFalse(state.loadMoreFailed)
        assertFalse(state.canLoadMore)
    }

    @Test fun aMonthChangeStartsOverWithoutACursor() {
        answer = { request ->
            when {
                request.encodedQuery != null -> page(listOf("oct2"))
                request.query("from").toLong() == 1790802000L -> page(listOf("oct"), next = "cursor=oct")
                else -> page(listOf("nov"), next = "cursor=nov")
            }
        }
        val model = model().opened()
        main { model.previousMonth() }
        val state = model.await { it.month == YearMonth.of(2026, 10) && it.phase == ChoreArchivePhase.READY }
        assertEquals(listOf("oct"), state.chores.map { it.id })
        assertEquals(null, requests.last().encodedQuery)
        main { model.loadMore() }
        assertEquals(listOf("oct", "oct2"), model.await { it.chores.size == 2 && !it.loadingMore }.chores.map { it.id })
        assertEquals("cursor=oct", requests.last().encodedQuery)
    }

    @Test fun aSlowFirstPageAnsweredAfterAMonthChangeIsDropped() {
        val gate = CompletableDeferred<Unit>()
        val answered = CompletableDeferred<Unit>()
        answer = { request ->
            if (request.query("from").toLong() == 1793480400L) {
                // Not cancellable: only the view model's own check can drop this answer.
                withContext(NonCancellable) { gate.await() }
                answered.complete(Unit)
                page(listOf("nov"))
            } else page(listOf("oct"))
        }
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.open() }
        main { model.previousMonth() }
        model.await { it.month == YearMonth.of(2026, 10) && it.phase == ChoreArchivePhase.READY }
        gate.complete(Unit)
        runBlocking { withTimeout(5_000) { answered.await() } }
        Thread.sleep(300)
        val state = model.state.value
        assertEquals(YearMonth.of(2026, 10), state.month)
        assertEquals(listOf("oct"), state.chores.map { it.id })
    }

    @Test fun aLoadMoreAnswerAfterAContextChangeIsDropped() {
        val gate = CompletableDeferred<Unit>()
        val answered = CompletableDeferred<Unit>()
        answer = { request ->
            if (request.encodedQuery == null) page(listOf("a"), next = "cursor=1")
            else {
                withContext(NonCancellable) { gate.await() }
                answered.complete(Unit)
                page(listOf("late"))
            }
        }
        val model = model().opened()
        main { model.loadMore() }
        model.await { it.loadingMore }
        main { model.setContext("u1", "h2") }
        gate.complete(Unit)
        runBlocking { withTimeout(5_000) { answered.await() } }
        Thread.sleep(300)
        assertEquals(ChoreArchiveUiState(month = YearMonth.of(2026, 11)), model.state.value)
    }

    @Test fun unauthorizedAndMissingJwtRejectTheSession() {
        answer = { 401 to "" }
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.open() }
        model.await { it.phase == ChoreArchivePhase.ERROR }
        assertEquals(ChoreArchiveEffect.SessionRejected, effect(model))
        jwt = null
        main { model.reload() }
        assertEquals(ChoreArchiveEffect.SessionRejected, effect(model))
    }

    @Test fun notMemberRefreshesTheProfileFromBothLoads() {
        answer = { request -> if (request.encodedQuery == null) page(listOf("a"), next = "cursor=1") else 403 to "" }
        val model = model().opened()
        main { model.loadMore() }
        model.await { it.loadMoreFailed }
        assertEquals(ChoreArchiveEffect.RefreshProfile, effect(model))
        answer = { 403 to "" }
        main { model.reload() }
        assertEquals(ChoreArchiveEffect.RefreshProfile, effect(model))
    }

    @Test fun aFirstPageFailureShowsTheServerMessageAndReloadRetries() {
        answer = { 400 to "" }
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.open() }
        assertEquals("Bad range", model.await { it.phase == ChoreArchivePhase.ERROR }.errorMessage)
        answer = { page(listOf("a")) }
        main { model.reload() }
        val state = model.await { it.phase == ChoreArchivePhase.READY }
        assertEquals(null, state.errorMessage)
        assertEquals(listOf("a"), state.chores.map { it.id })
    }

    @Test fun nextMonthStopsAtTheCurrentMonth() {
        val model = model().opened()
        main { model.nextMonth() }
        assertEquals(1, requests.size)
        assertEquals(YearMonth.of(2026, 11), model.state.value.month)
        main { model.previousMonth() }
        model.await { it.month == YearMonth.of(2026, 10) && it.phase == ChoreArchivePhase.READY }
        main { model.nextMonth() }
        model.await { it.month == YearMonth.of(2026, 11) && it.phase == ChoreArchivePhase.READY }
        assertEquals(3, requests.size)
    }

    @Test fun reloadFromReadyKeepsTheListUntilTheAnswerAndOnFailure() {
        val gate = CompletableDeferred<Unit>()
        answer = { page(listOf("a"), next = "cursor=1") }
        val model = model().opened()
        answer = { withContext(NonCancellable) { gate.await() }; page(listOf("b")) }
        main { model.reload() }
        val waiting = model.await { it.refreshing }
        assertEquals(ChoreArchivePhase.READY, waiting.phase)
        assertEquals(listOf("a"), waiting.chores.map { it.id })
        gate.complete(Unit)
        val replaced = model.await { !it.refreshing }
        assertEquals(listOf("b"), replaced.chores.map { it.id })
        assertFalse(replaced.canLoadMore)
        answer = { 500 to "" }
        main { model.reload() }
        val failed = model.await { !it.refreshing && requests.size == 3 }
        assertEquals(ChoreArchivePhase.READY, failed.phase)
        assertEquals(listOf("b"), failed.chores.map { it.id })
        assertEquals(null, failed.errorMessage)
    }

    @Test fun reloadDuringLoadMoreDropsTheLoadMoreAnswer() {
        val gate = CompletableDeferred<Unit>()
        val answered = CompletableDeferred<Unit>()
        answer = { request ->
            if (request.encodedQuery == null) page(listOf("a"), next = "cursor=1")
            else {
                withContext(NonCancellable) { gate.await() }
                answered.complete(Unit)
                page(listOf("late"))
            }
        }
        val model = model().opened()
        main { model.loadMore() }
        model.await { it.loadingMore }
        main { model.reload() }
        model.await { !it.refreshing && !it.loadingMore && requests.size == 3 }
        gate.complete(Unit)
        runBlocking { withTimeout(5_000) { answered.await() } }
        Thread.sleep(300)
        assertEquals(listOf("a"), model.state.value.chores.map { it.id })
        assertFalse(model.state.value.loadingMore)
    }

    @Test fun nextMonthIsOnlyOfferedBeforeTheCurrentMonth() {
        val model = model().opened()
        assertFalse(model.state.value.canShowNextMonth)
        main { model.previousMonth() }
        assertTrue(model.await { it.month == YearMonth.of(2026, 10) }.canShowNextMonth)
    }

    private fun effect(model: ChoreArchiveViewModel) = runBlocking { withTimeout(5_000) { model.effects.first() } }
}
