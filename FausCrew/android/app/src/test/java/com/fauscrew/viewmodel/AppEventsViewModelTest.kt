package com.fauscrew.viewmodel

import com.fauscrew.platform.AppEventsEffect
import com.fauscrew.platform.AppEventsEngine
import com.fauscrew.platform.AppEventsParser
import com.fauscrew.platform.OnlineFailure
import com.fauscrew.platform.RealtimeSocket
import com.fauscrew.platform.RealtimeSocketFactory
import com.fauscrew.platform.RealtimeSocketListener
import java.io.IOException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.Job
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class AppEventsViewModelTest {
    private val dispatcher = StandardTestDispatcher()
    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    @Test fun parsesEffects() {
        assertEquals(
            listOf(AppEventsEffect.OpenSocket(2, "events"), AppEventsEffect.CloseSocket,
                AppEventsEffect.Refresh(true, null), AppEventsEffect.Refresh(false, "h1"), AppEventsEffect.RefreshNotifications("h1"),
                AppEventsEffect.SignedOut),
            AppEventsParser.parse("""{"ok":true,"path":"events","effects":[{"type":"openSocket","connection":2},
                {"type":"closeSocket"},{"type":"refresh","profile":true,"houseId":null},
                {"type":"refresh","profile":false,"houseId":"h1"},{"type":"refreshNotifications","houseId":"h1"},
                {"type":"signedOut"}]}"""),
        )
    }

    @Test fun opensTheEventsSocketWithTheTokenAndForwardsTagsAndRequests() = runTest(dispatcher) {
        val events = mutableListOf<Pair<String, Map<String, Any?>>>()
        val engine = object : AppEventsEngine {
            override fun event(type: String, now: Double, fields: Map<String, Any?>): List<AppEventsEffect> {
                events += type to fields
                return when (type) {
                    "setActive" -> listOf(AppEventsEffect.OpenSocket(3, "events"))
                    "received" -> listOf(AppEventsEffect.Refresh(true, "h1"))
                    "connectionFailed" -> listOf(AppEventsEffect.CloseSocket, AppEventsEffect.SignedOut)
                    else -> emptyList()
                }
            }
            override fun close() = Unit
        }
        var listener: RealtimeSocketListener? = null
        var opened: Triple<String, String, String>? = null
        var closes = 0
        val sockets = RealtimeSocketFactory { path, query, token, l ->
            opened = Triple(path, query, token); listener = l
            object : RealtimeSocket {
                override fun send(text: String) = true
                override fun close() { closes += 1 }
            }
        }
        val model = AppEventsViewModel(engine, sockets, token = { "t" }, clock = { 1.0 })
        model.update(foreground = true, authenticated = true)
        runCurrent()
        assertEquals(Triple("events", "", "t"), opened)
        listener!!.onOpen(); runCurrent()
        listener!!.onText("""{"type":"ready"}"""); runCurrent()
        assertEquals(3, events.first { it.first == "received" }.second["connection"])
        assertEquals(AppEventsRequest.Refresh(true, "h1"), model.requests.first())
        listener!!.onFailure(OnlineFailure.Http(401, null)); runCurrent()
        assertEquals(401, events.first { it.first == "connectionFailed" }.second["status"])
        assertEquals(AppEventsRequest.SignOut, model.requests.first())
        assertTrue(closes >= 1)
        model.update(foreground = false, authenticated = true)
    }

    @Test fun tokenReadFailureReportsTransportWithoutSigningOut() = runTest(dispatcher) {
        val events = mutableListOf<Pair<String, Map<String, Any?>>>()
        val engine = object : AppEventsEngine {
            override fun event(type: String, now: Double, fields: Map<String, Any?>): List<AppEventsEffect> {
                events += type to fields
                return when {
                    type == "setActive" && fields["foreground"] == true -> listOf(AppEventsEffect.OpenSocket(3, "events"))
                    type == "connectionFailed" && fields["status"] == 401 ->
                        listOf(AppEventsEffect.CloseSocket, AppEventsEffect.SignedOut)
                    type == "connectionFailed" || type == "setActive" -> listOf(AppEventsEffect.CloseSocket)
                    else -> emptyList()
                }
            }
            override fun close() = Unit
        }
        var socketCalls = 0
        val sockets = RealtimeSocketFactory { _, _, _, _ -> socketCalls += 1; error("No socket without a token") }
        // No exception handler: runTest also reports uncaught viewModelScope exceptions on this dispatcher.
        val model = AppEventsViewModel(engine, sockets, token = { throw IOException("Token read failed") }, clock = { 1.0 })
        val requests = mutableListOf<AppEventsRequest>()
        backgroundScope.launch { model.requests.collect { requests += it } }
        model.update(foreground = true, authenticated = true)
        runCurrent()
        assertEquals(mapOf<String, Any?>("status" to null, "connection" to 3),
            events.single { it.first == "connectionFailed" }.second)
        assertEquals(0, socketCalls)
        assertTrue("Token storage failure must not sign the user out", requests.isEmpty())
        model.update(foreground = false, authenticated = true)
    }

    @Test fun tokenReadCancellationDoesNotReportConnectionFailure() = runTest(dispatcher) {
        val events = mutableListOf<String>()
        val engine = object : AppEventsEngine {
            override fun event(type: String, now: Double, fields: Map<String, Any?>): List<AppEventsEffect> {
                events += type
                return if (type == "setActive" && fields["foreground"] == true)
                    listOf(AppEventsEffect.OpenSocket(3, "events")) else emptyList()
            }
            override fun close() = Unit
        }
        val tokenJobs = mutableListOf<Job>()
        val model = AppEventsViewModel(engine, sockets = { _, _, _, _ -> error("No socket after cancellation") },
            token = { tokenJobs += currentCoroutineContext()[Job]!!; throw CancellationException("Cancelled token read") }, clock = { 1.0 })
        model.update(foreground = true, authenticated = true)
        runCurrent()
        assertEquals(1, tokenJobs.size)
        assertTrue(tokenJobs.single().isCancelled)
        assertEquals(listOf("setActive"), events)
        model.update(foreground = false, authenticated = true)
    }

    @Test fun forwardsNotificationRefreshesForTheSelectedHouse() = runTest(dispatcher) {
        val engine = object : AppEventsEngine {
            override fun event(type: String, now: Double, fields: Map<String, Any?>): List<AppEventsEffect> =
                if (type == "setSelectedHouse") listOf(AppEventsEffect.RefreshNotifications(fields["houseId"] as String)) else emptyList()
            override fun close() = Unit
        }
        val model = AppEventsViewModel(engine, sockets = { _, _, _, _ -> error("No socket") }, token = { "t" }, clock = { 1.0 })
        model.setSelectedHouse("h1")
        assertEquals(AppEventsRequest.RefreshNotifications("h1"), model.requests.first())
    }
}
