package com.fauscrew.viewmodel

import com.fauscrew.platform.HouseRocketsOnlineEngine
import com.fauscrew.platform.OnlineEffect
import com.fauscrew.platform.OnlineFailure
import com.fauscrew.platform.OnlineFlightUi
import com.fauscrew.platform.OnlineLobbyUi
import com.fauscrew.platform.OnlineOutput
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.RealtimeSocket
import com.fauscrew.platform.RealtimeSocketFactory
import com.fauscrew.platform.RealtimeSocketListener
import com.fauscrew.platform.RocketsFrame
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
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
class HouseRocketsOnlineSessionTest {
    private val dispatcher = StandardTestDispatcher()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    /** Scripted engine: returns queued effects and records every event it receives. */
    private class ScriptedEngine : HouseRocketsOnlineEngine {
        val events = mutableListOf<Pair<String, Map<String, Any?>>>()
        val received = mutableListOf<Pair<String, Int>>()
        var next: (String) -> List<OnlineEffect> = { emptyList() }
        var lobby = OnlineLobbyUi()
        var closed = false
        var disposed = false

        override fun event(type: String, now: Double, fields: Map<String, Any?>): OnlineOutput {
            events += type to fields
            if (type == "disconnect") disposed = true
            return OnlineOutput(next(type), lobby, null, closed, null)
        }
        override fun receive(text: String, connection: Int, now: Double): OnlineOutput {
            received += text to connection
            return OnlineOutput(emptyList(), lobby, null, false, null)
        }
        override fun viewport(width: Float, height: Float, hudWidth: Float, hudHeight: Float) = Unit
        override fun frame(now: Double): Pair<RocketsFrame, OnlineFlightUi>? = null
        override fun close() = Unit
    }

    private class FakeSockets : RealtimeSocketFactory {
        val opened = mutableListOf<Triple<String, String, String>>()
        val sent = mutableListOf<String>()
        var listener: RealtimeSocketListener? = null
        var closes = 0
        override fun open(path: String, query: String, token: String, listener: RealtimeSocketListener): RealtimeSocket {
            opened += Triple(path, query, token)
            this.listener = listener
            return object : RealtimeSocket {
                override fun send(text: String): Boolean { sent += text; return true }
                override fun close() { closes += 1 }
            }
        }
    }

    private fun TestScope.session(engine: ScriptedEngine, sockets: FakeSockets, requests: MutableList<PlatformHttpRequest>,
                                  status: Int = 200) =
        HouseRocketsOnlineSession(
            scope = this, engine = engine,
            http = { requests += it; PlatformHttpResponse(status, mapOf("retry-after" to "2"), """{"success":true}""".toByteArray()) },
            token = { "token-1" }, sockets = sockets, onHaptic = {}, clock = { 1.0 }, tickMillis = 25,
        )

    @Test fun performsEnsureSocketSendAndReportsOutcomesWithTags() = runTest(dispatcher) {
        val engine = ScriptedEngine()
        val sockets = FakeSockets()
        val requests = mutableListOf<PlatformHttpRequest>()
        engine.next = { type ->
            when (type) {
                "start" -> listOf(OnlineEffect.EnsureSession(4, "game/houseRockets/session", "PUT", """{"houseId":"h"}"""))
                "sessionResponse" -> listOf(OnlineEffect.CloseSocket,
                    OnlineEffect.OpenSocket(4, "game/sessions/s/realtime", "protocolVersion=2"))
                "socketOpened" -> listOf(OnlineEffect.Send(4, """{"type":"gameSession.join"}"""))
                else -> emptyList()
            }
        }
        val session = session(engine, sockets, requests)
        session.start(isForeground = true, isLandscape = false)
        runCurrent()
        assertEquals("PUT", requests.single().method)
        assertEquals("Bearer token-1", requests.single().headers["Authorization"])
        val response = engine.events.first { it.first == "sessionResponse" }.second
        assertEquals(200, response["status"])
        assertEquals(2.0, response["retryAfter"])
        assertEquals(4, response["connection"])
        assertEquals(Triple("game/sessions/s/realtime", "protocolVersion=2", "token-1"), sockets.opened.single())

        sockets.listener!!.onOpen()
        runCurrent()
        assertEquals(listOf("""{"type":"gameSession.join"}"""), sockets.sent)
        sockets.listener!!.onText("""{"type":"realtime.welcome"}""")
        runCurrent()
        assertEquals(listOf("""{"type":"realtime.welcome"}""" to 4), engine.received)

        sockets.listener!!.onFailure(OnlineFailure.Http(503, 3.0))
        runCurrent()
        val failure = engine.events.last { it.first == "connectionFailed" }.second
        assertEquals("http", failure["failure"])
        assertEquals(503, failure["status"])
        assertEquals(4, failure["connection"])

        advanceTimeBy(60); runCurrent()
        assertTrue(engine.events.count { it.first == "tick" } >= 2)
        session.dispose()
        assertTrue(engine.disposed)
        val ticks = engine.events.count { it.first == "tick" }
        advanceTimeBy(100); runCurrent()
        assertEquals("No ticks after dispose", ticks, engine.events.count { it.first == "tick" })
    }

    @Test fun sendWithoutTheMatchingSocketIsReportedAsNotConnected() = runTest(dispatcher) {
        val engine = ScriptedEngine()
        engine.next = { type -> if (type == "start") listOf(OnlineEffect.Send(9, "{}")) else emptyList() }
        val session = session(engine, FakeSockets(), mutableListOf())
        session.start(true, true)
        runCurrent()
        val failed = engine.events.first { it.first == "sendFailed" }.second
        assertEquals("notConnected", failed["failure"])
        assertEquals(9, failed["connection"])
        session.dispose()
    }

    @Test fun resultLookupsCarryTheirRequestTag() = runTest(dispatcher) {
        val engine = ScriptedEngine()
        val requests = mutableListOf<PlatformHttpRequest>()
        engine.next = { type -> if (type == "start") listOf(OnlineEffect.FetchResult(7, "game/sessions/s/result", "GET")) else emptyList() }
        val session = session(engine, FakeSockets(), requests, status = 404)
        session.start(true, true)
        runCurrent()
        assertEquals("game/sessions/s/result", requests.single().path)
        val response = engine.events.first { it.first == "resultResponse" }.second
        assertEquals(404, response["status"])
        assertEquals(7, response["request"])
        session.dispose()
    }
}
