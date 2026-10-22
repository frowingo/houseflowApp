package com.fauscrew.viewmodel

import com.fauscrew.platform.AppEventsEffect
import com.fauscrew.platform.AppEventsEngine
import com.fauscrew.platform.AppEventsParser
import com.fauscrew.platform.OnlineFailure
import com.fauscrew.platform.RealtimeSocket
import com.fauscrew.platform.RealtimeSocketFactory
import com.fauscrew.platform.RealtimeSocketListener
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.flow.first
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
                AppEventsEffect.Refresh(true, null), AppEventsEffect.Refresh(false, "h1"), AppEventsEffect.SignedOut),
            AppEventsParser.parse("""{"ok":true,"path":"events","effects":[{"type":"openSocket","connection":2},
                {"type":"closeSocket"},{"type":"refresh","profile":true,"houseId":null},
                {"type":"refresh","profile":false,"houseId":"h1"},{"type":"signedOut"}]}"""),
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
}
