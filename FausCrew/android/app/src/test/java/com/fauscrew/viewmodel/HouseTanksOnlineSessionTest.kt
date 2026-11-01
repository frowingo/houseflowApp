package com.fauscrew.viewmodel

import com.fauscrew.platform.OnlineEffect
import com.fauscrew.platform.TanksOnlineEngine
import com.fauscrew.platform.TanksOnlineFrame
import com.fauscrew.platform.TanksOnlineMatch
import com.fauscrew.platform.OnlineLobbyUi
import com.fauscrew.platform.OnlineOutput
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.RealtimeSocket
import com.fauscrew.platform.RealtimeSocketFactory
import com.fauscrew.platform.RealtimeSocketListener
import com.fauscrew.platform.TanksColor
import com.fauscrew.platform.TanksMap
import com.fauscrew.platform.TanksOnlinePreview
import com.fauscrew.platform.TanksOnlineSeat
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Before
import org.junit.Test

/** The FauseTanks room host: the shared effect loop plus the drawn arena. */
@OptIn(ExperimentalCoroutinesApi::class)
class HouseTanksOnlineSessionTest {
    private val dispatcher = StandardTestDispatcher()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    private val drawn = TanksOnlinePreview(TanksMap.LIVING_ROOM, listOf(TanksOnlineSeat("u", 0.1, 0.36, 0.19, TanksColor.PLUM)))

    /** Sends the drawn arena with the countdown frame, then an unchanged frame, then clears it. */
    private inner class ScriptedEngine : TanksOnlineEngine {
        val events = mutableListOf<String>()
        var frames = 0

        override fun event(type: String, now: Double, fields: Map<String, Any?>): OnlineOutput {
            events += type
            val effects = when (type) {
                "start" -> listOf(OnlineEffect.EnsureSession(1, "game/houseTanks/session", "PUT", """{"houseId":"h"}"""))
                "sessionResponse" -> listOf(OnlineEffect.OpenSocket(1, "game/sessions/s/realtime", "protocolVersion=2"))
                else -> emptyList()
            }
            return OnlineOutput(effects, OnlineLobbyUi(statusKey = "house_tanks_online_connecting"), null, false, null)
        }

        override fun receive(text: String, connection: Int, now: Double): OnlineOutput {
            frames += 1
            return when (frames) {
                1 -> OnlineOutput(emptyList(), null, null, false, null, previewChanged = true, preview = drawn)
                2 -> OnlineOutput(emptyList(), null, null, false, null)
                else -> OnlineOutput(emptyList(), null, null, false, null, previewChanged = true, preview = null)
            }
        }

        override fun frame(now: Double): TanksOnlineFrame {
            events += "frame@$now"
            return TanksOnlineFrame(null, TanksOnlineMatch(canPress = true))
        }

        override fun close() = Unit
    }

    @Test fun ensuresTheTanksSessionAndFollowsTheDrawnArena() = runTest(dispatcher) {
        val engine = ScriptedEngine()
        val requests = mutableListOf<PlatformHttpRequest>()
        var listener: RealtimeSocketListener? = null
        val sockets = RealtimeSocketFactory { _, _, _, socketListener ->
            listener = socketListener
            object : RealtimeSocket {
                override fun send(text: String) = true
                override fun close() = Unit
            }
        }
        val session = HouseTanksOnlineSession(
            scope = this, engine = engine,
            http = { requests += it; PlatformHttpResponse(200, emptyMap(), "{}".toByteArray()) },
            token = { "token-1" }, sockets = sockets, onHaptic = {}, clock = { 2.0 }, tickMillis = 25,
        )
        session.start(isForeground = true, isLandscape = false)
        runCurrent()
        assertEquals("game/houseTanks/session", requests.single().path)
        assertEquals("house_tanks_online_connecting", session.lobby.value.statusKey)
        assertEquals(2.0, session.uptime(), 0.0)

        val frame: (String) -> Unit = { text -> listener!!.onText(text); runCurrent() }
        frame("countdown")
        assertEquals(drawn, session.preview.value)
        frame("unchanged")
        assertEquals("An absent preview keeps the arena", drawn, session.preview.value)
        frame("cleared")
        assertNull(session.preview.value)

        session.press()
        session.release()
        assertEquals(true, session.frame()?.match?.canPress)
        assertEquals(listOf("press", "release", "frame@2.0"), engine.events.takeLast(3))
        session.dispose()
        assertNull("No frames after dispose", session.frame())
    }
}
