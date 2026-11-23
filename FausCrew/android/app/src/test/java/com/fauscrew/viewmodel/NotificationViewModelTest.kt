package com.fauscrew.viewmodel

import com.fauscrew.platform.NotificationItem
import com.fauscrew.platform.NotificationRepository
import com.fauscrew.platform.NotificationRules
import com.fauscrew.platform.NotificationWire
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import java.util.concurrent.CountDownLatch
import java.util.concurrent.Executors
import java.util.concurrent.TimeUnit
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.asCoroutineDispatcher
import kotlinx.coroutines.ExperimentalCoroutinesApi
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
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.BeforeClass
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class NotificationViewModelTest {
    private companion object {
        // One real thread stands in for the main thread: the view model's state updates are not atomic
        // across threads, and the repository hops to Dispatchers.IO for real. Set once for the class,
        // because a request still in flight from one test may touch Main while the next one starts.
        private val mainThread = Executors.newSingleThreadExecutor()

        @JvmStatic @BeforeClass fun setUpMain() = Dispatchers.setMain(mainThread.asCoroutineDispatcher())

        @JvmStatic @AfterClass fun tearDownMain() {
            Dispatchers.resetMain()
            mainThread.shutdown()
        }
    }

    private val requests = mutableListOf<PlatformHttpRequest>()
    private val seen = mutableMapOf<String, String>()
    private var jwt: String? = "jwt"
    /** Answers a request with a status and the bridge-shaped body for a 2xx. */
    private var answer: (PlatformHttpRequest) -> Pair<Int, String> = { page(emptyList()) }

    private fun item(id: String, createdAt: String, choreId: String? = null) = NotificationItem(
        id = id, type = if (choreId == null) "announcement" else "chore_reminder", houseId = "h1", senderUserId = "u2",
        choreId = choreId, title = "T$id", message = "M$id", createdAt = createdAt,
    )

    private fun page(items: List<NotificationItem>, next: String? = null): Pair<Int, String> {
        val body = JSONObject().put("ok", true).put("items", JSONArray(items.map { it.toJson() }))
        if (next != null) body.put("nextCursor", next)
        return 200 to body.toString()
    }

    private val wire = object : NotificationWire {
        override fun request(action: String, fieldsJson: String): String {
            val fields = JSONObject(fieldsJson)
            val query = JSONArray()
            if (action == "list") {
                query.put(JSONObject().put("name", "houseId").put("value", fields.getString("houseId")))
                if (fields.has("before")) query.put(JSONObject().put("name", "before").put("value", fields.getString("before")))
            }
            val path = if (action == "list") "notification" else "chore/${fields.getString("choreId")}/remind"
            return JSONObject().put("ok", true).put("path", path).put("method", if (action == "list") "GET" else "POST")
                .put("query", query).toString()
        }

        override fun response(action: String, status: Int, body: String): String = when (status) {
            in 200..299 -> body
            400 -> """{"ok":false,"kind":"invalidRequest","message":"Too early"}"""
            401 -> """{"ok":false,"kind":"unauthorized"}"""
            403 -> """{"ok":false,"kind":"notMember"}"""
            404 -> """{"ok":false,"kind":"notFound","message":"Gone"}"""
            409 -> """{"ok":false,"kind":"alreadyReminded"}"""
            else -> """{"ok":false,"kind":"server"}"""
        }
    }

    // The marker is the newest createdAt itself; Core's real comparison is covered in Core's tests.
    private val rules = object : NotificationRules {
        override fun unreadCount(items: List<NotificationItem>, markerJson: String?) =
            items.count { markerJson == null || it.createdAt > markerJson }
        override fun seenMarker(items: List<NotificationItem>) = items.maxOfOrNull { it.createdAt }
    }

    private val repository = NotificationRepository(
        send = { request ->
            requests += request
            val (status, body) = answer(request)
            PlatformHttpResponse(status, emptyMap(), body.toByteArray())
        },
        wire = wire,
    )

    private fun model() = NotificationViewModel(repository, rules, { seen[it] }, { key, value -> seen[key] = value }, { jwt })

    /** Waits until no request was sent for a moment, so a test's own answers are not consumed by an earlier load. */
    private fun quiet() {
        var last = -1
        while (last != requests.size) { last = requests.size; Thread.sleep(150) }
    }

    /** View model calls come from the main thread, like in the app. */
    private fun main(block: () -> Unit) = runBlocking(Dispatchers.Main) { block() }

    private fun NotificationViewModel.await(predicate: (NotificationUiState) -> Boolean) = runBlocking {
        withTimeout(5_000) { state.first(predicate) }
    }

    private val key = "fauscrew.notifications-seen.u1.h1"
    private val three = listOf(item("n3", "2026-11-21T11:00:00Z"), item("n2", "2026-11-21T10:00:00Z"), item("n1", "2026-11-21T09:00:00Z"))

    @Test fun badgeCountsPageOneAgainstTheStoredMarker() {
        seen[key] = "2026-11-21T10:00:00Z"
        answer = { page(three) }
        val model = model()
        main { model.setContext("u1", "h1") }
        assertEquals(1, model.await { it.badge > 0 }.badge)
        assertEquals("h1", requests.single().queryItems.first { it.name == "houseId" }.value)
        assertEquals("Bearer jwt", requests.single().headers["Authorization"])
    }

    @Test fun withoutAMarkerEveryItemIsUnread() {
        answer = { page(three) }
        val model = model()
        main { model.setContext("u1", "h1") }
        assertEquals(3, model.await { it.badge > 0 }.badge)
    }

    @Test fun openingSavesTheNewestMarkerResetsTheBadgeAndKeepsTheOldUnreadItems() {
        seen[key] = "2026-11-21T10:00:00Z"
        answer = { page(three) }
        val model = model()
        main { model.setContext("u1", "h1") }
        model.await { it.badge == 1 }
        main { model.open() }
        val panel = model.await { it.panel?.phase == NotificationPhase.READY && !it.panel.refreshing && it.badge == 0 }.panel!!
        assertEquals(setOf("n3"), panel.unreadIds)
        assertEquals(listOf("n3", "n2", "n1"), panel.items.map { it.id })
        assertEquals("2026-11-21T11:00:00Z", seen[key])
    }

    @Test fun openingWithoutACachedPageShowsTheSkeletonThenTheItems() {
        answer = { page(three) }
        val model = model()
        main { model.setContext(null, null) }
        main { model.setContext("u1", "h1") }
        main { model.open() }
        val panel = model.await { it.panel?.phase == NotificationPhase.READY && !it.panel.refreshing }.panel!!
        assertEquals(3, panel.items.size)
        assertEquals(setOf("n3", "n2", "n1"), panel.unreadIds)
        assertEquals(0, model.state.value.badge)
    }

    @Test fun pagingUsesTheCursorAndStopsWhenItIsGone() {
        answer = { request ->
            if (request.queryItems.any { it.name == "before" }) page(listOf(item("n0", "2026-11-20T09:00:00Z")))
            else page(three, next = "cursor-1")
        }
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.open() }
        model.await { it.panel?.hasMore == true && !it.panel.refreshing }
        main { model.loadMore() }
        val panel = model.await { it.panel?.items?.size == 4 && !it.panel.loadingMore }.panel!!
        assertFalse(panel.hasMore)
        assertEquals("cursor-1", requests.last().queryItems.first { it.name == "before" }.value)
        val before = requests.size
        main { model.loadMore() }
        assertEquals(before, requests.size)
    }

    @Test fun aFailedPageKeepsTheItemsAndStopsAutomaticPaging() {
        answer = { request -> if (request.queryItems.any { it.name == "before" }) 500 to "" else page(three, next = "c") }
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.open() }
        model.await { it.panel?.hasMore == true && !it.panel.refreshing }
        main { model.loadMore() }
        val panel = model.await { it.panel?.moreFailed == true }.panel!!
        assertEquals(3, panel.items.size)
        assertFalse(panel.loadingMore)
    }

    @Test fun aFirstLoadFailureShowsTheErrorAndReloadRetries() {
        answer = { 500 to "" }
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.open() }
        assertEquals(NotificationPhase.ERROR, model.await { it.panel?.phase == NotificationPhase.ERROR }.panel!!.phase)
        answer = { page(three) }
        main { model.reload() }
        assertEquals(3, model.await { it.panel?.phase == NotificationPhase.READY && !it.panel.refreshing }.panel!!.items.size)
    }

    @Test fun forbiddenClosesThePanelAndAsksForAProfileRefresh() {
        answer = { 403 to "" }
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.open() }
        model.await { it.panel == null }
        assertEquals(NotificationEffect.RefreshProfile, runBlocking { withTimeout(5_000) { model.effects.first() } })
        assertEquals(0, model.state.value.badge)
    }

    @Test fun anExpiredSessionIsReported() {
        answer = { 401 to "" }
        val model = model()
        main { model.setContext("u1", "h1") }
        assertEquals(NotificationEffect.SessionRejected, runBlocking { withTimeout(5_000) { model.effects.first() } })
        assertEquals(0, model.state.value.badge)
    }

    @Test fun aMissingJwtSendsNothingAndDoesNotRejectTheSession() {
        jwt = null
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.remind("c1") }
        model.await { it.sendingChoreId == null }
        assertNull(runBlocking { withTimeoutOrNull(300) { model.effects.first() } })
        assertTrue(requests.isEmpty())
        assertNull(model.state.value.toast)
    }

    @Test fun houseSwitchAndSignOutResetEverything() {
        answer = { page(three) }
        val model = model()
        main { model.setContext("u1", "h1") }
        model.await { it.badge == 3 }
        main { model.open() }
        model.await { it.panel?.phase == NotificationPhase.READY }
        answer = { page(emptyList()) }
        main { model.setContext("u1", "h2") }
        assertNull(model.state.value.panel)
        assertEquals(0, model.state.value.badge)
        main { model.setContext(null, null) }
        assertEquals(NotificationUiState(), model.state.value)
        main { model.refresh() }
        assertEquals(NotificationUiState(), model.state.value)
    }

    @Test fun foregroundPushesRefreshOnlyTheSelectedHouse() {
        answer = { page(three) }
        val model = model()
        main { model.setContext("u1", "h1") }
        model.await { it.badge == 3 }
        val before = requests.size
        main { model.onForegroundPush(mapOf("houseId" to "h9")) }
        assertEquals(before, requests.size)
        answer = { page(three + item("n4", "2026-11-21T12:00:00Z")) }
        main { model.onForegroundPush(mapOf("houseId" to "h1")) }
        assertEquals(4, model.await { it.badge == 4 }.badge)
    }

    @Test fun remindSucceedsOnceAndMarksTheChoreReminded() {
        answer = { if (it.path.startsWith("chore")) 200 to """{"ok":true}""" else page(emptyList()) }
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.remind("c1") }
        val state = model.await { "c1" in it.remindedChoreIds && it.sendingChoreId == null }
        assertEquals(ReminderToast.Sent, state.toast)
        assertEquals("chore/c1/remind", requests.last().path)
        val before = requests.size
        main { model.remind("c1") }
        assertEquals(before, requests.size)
        main { model.clearToast() }
        assertNull(model.state.value.toast)
    }

    @Test fun aConflictIsRemindedWithoutAToast() {
        answer = { if (it.path.startsWith("chore")) 409 to "" else page(emptyList()) }
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.remind("c1") }
        val state = model.await { "c1" in it.remindedChoreIds && it.sendingChoreId == null }
        assertNull(state.toast)
    }

    @Test fun rejectedRemindersShowTheServerMessageAndNotFoundRefreshesTheHouse() {
        answer = { if (it.path.startsWith("chore")) 400 to "" else page(emptyList()) }
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.remind("c1") }
        val state = model.await { it.toast != null && it.sendingChoreId == null }
        assertEquals(ReminderToast.Failed("Too early"), state.toast)
        assertTrue(state.remindedChoreIds.isEmpty())
        main { model.clearToast() }
        answer = { if (it.path.startsWith("chore")) 404 to "" else page(emptyList()) }
        main { model.remind("c1") }
        model.await { it.toast != null && it.sendingChoreId == null }
        assertEquals(NotificationEffect.RefreshHouse("h1"), runBlocking { withTimeout(5_000) { model.effects.first() } })
    }

    @Test fun remindedChoresAreForgottenOnSignOut() {
        answer = { if (it.path.startsWith("chore")) 200 to """{"ok":true}""" else page(emptyList()) }
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.remind("c1") }
        model.await { "c1" in it.remindedChoreIds }
        main { model.setContext(null, null) }
        assertTrue(model.state.value.remindedChoreIds.isEmpty())
        main { model.setContext("u1", "h1") }
        assertTrue(model.state.value.remindedChoreIds.isEmpty())
    }

    @Test fun aSilentRefreshMergesIntoThePagedListInsteadOfReplacingIt() {
        val older = listOf(item("n0", "2026-11-20T09:00:00Z"))
        answer = { request ->
            if (request.queryItems.any { it.name == "before" }) page(older) else page(three, next = "cursor-1")
        }
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.open() }
        model.await { it.panel?.hasMore == true && it.panel.items.size == 3 }
        quiet()
        main { model.loadMore() }
        model.await { it.panel?.items?.size == 4 && !it.panel.loadingMore }
        val fresh = item("n4", "2026-11-21T12:00:00Z")
        answer = { page(listOf(fresh) + three.take(2), next = "cursor-1") }
        main { model.refresh("h1") }
        val panel = model.await { it.panel?.items?.firstOrNull()?.id == "n4" }.panel!!
        assertEquals(listOf("n4", "n3", "n2", "n1", "n0"), panel.items.map { it.id })
        assertFalse(panel.hasMore)
        assertTrue("n4" in panel.unreadIds)
    }

    @Test fun aSilentRefreshDoesNotCancelAPageInFlight() {
        val release = CountDownLatch(1)
        answer = { request ->
            if (request.queryItems.any { it.name == "before" }) { release.await(5, TimeUnit.SECONDS); page(listOf(item("n0", "2026-11-20T09:00:00Z"))) }
            else page(three, next = "c")
        }
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.open() }
        model.await { it.panel?.hasMore == true && it.panel.items.size == 3 }
        quiet()
        main { model.loadMore() }
        model.await { it.panel?.loadingMore == true }
        main { model.refresh("h1") }
        release.countDown()
        val panel = model.await { it.panel?.items?.size == 4 && !it.panel.loadingMore }.panel!!
        assertEquals("n0", panel.items.last().id)
    }

    @Test fun aFailedReloadClearsAPageInFlight() {
        val release = CountDownLatch(1)
        answer = { request ->
            if (request.queryItems.any { it.name == "before" }) { release.await(5, TimeUnit.SECONDS); page(emptyList()) }
            else page(three, next = "c")
        }
        val model = model()
        main { model.setContext("u1", "h1") }
        main { model.open() }
        model.await { it.panel?.hasMore == true && it.panel.items.size == 3 }
        quiet()
        main { model.loadMore() }
        model.await { it.panel?.loadingMore == true }
        answer = { 500 to "" }
        main { model.reload() }
        val panel = model.await { it.panel?.refreshing == false && it.panel.loadingMore == false }.panel!!
        assertEquals(3, panel.items.size)
        release.countDown()
    }

    @Test fun openingWithACachedPageShowsNoPullSpinner() {
        answer = { page(three) }
        val model = model()
        main { model.setContext("u1", "h1") }
        model.await { it.badge == 3 }
        main { model.open() }
        val panel = model.state.value.panel!!
        assertEquals(NotificationPhase.READY, panel.phase)
        assertFalse(panel.refreshing)
    }
}
