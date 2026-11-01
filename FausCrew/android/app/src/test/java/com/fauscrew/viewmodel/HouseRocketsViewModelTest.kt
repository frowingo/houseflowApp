package com.fauscrew.viewmodel

import com.fauscrew.platform.HouseRocketsEngine
import com.fauscrew.platform.RocketsColor
import com.fauscrew.platform.RocketsFrame
import com.fauscrew.platform.RocketsPhase
import com.fauscrew.platform.RocketsPlayer
import com.fauscrew.platform.RocketsRole
import com.fauscrew.platform.RocketsUpdate
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.advanceTimeBy
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class HouseRocketsViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    /** Mirrors HouseRocketsBotMatch's phases without physics. */
    private class FakeEngine : HouseRocketsEngine {
        var phase = RocketsPhase.COUNTDOWN
        var countdown: Int? = 3
        var humanAlive = true
        var winner: String? = null
        var revision = 0
        val steps = mutableListOf<Triple<Double, Double?, Int>>()
        var viewports = mutableListOf<List<Float>>()
        var closed = false
        var started = 0

        fun frame() = RocketsFrame(
            "m$started", ++revision, phase, countdown, 0.0, 0.0, 0.0, if (humanAlive) 2 else 1, winner, null, null,
            listOf(RocketsPlayer("h", "house_rockets_you", RocketsRole.HUMAN, RocketsColor.MINT, humanAlive,
                0.0, 0.0, 0.0, 0.2, null)),
            emptyList(), emptyList(), null, emptyList(),
        )

        override fun viewport(width: Float, height: Float, hudWidth: Float, hudHeight: Float): RocketsUpdate {
            viewports += listOf(width, height, hudWidth, hudHeight)
            return RocketsUpdate(if (started > 0) frame() else null)
        }
        override fun start(botCount: Int): RocketsUpdate {
            started += 1; phase = RocketsPhase.COUNTDOWN; countdown = 3; humanAlive = true; winner = null
            return RocketsUpdate(frame())
        }
        override fun countdown(): RocketsUpdate {
            val value = countdown ?: 3
            if (value > 1) countdown = value - 1 else { countdown = null; phase = RocketsPhase.PLAYING }
            return RocketsUpdate(frame(), started = phase == RocketsPhase.PLAYING)
        }
        override fun step(deltaSeconds: Double, heading: Double?, sequence: Int): RocketsUpdate {
            steps += Triple(deltaSeconds, heading, sequence)
            return RocketsUpdate(frame())
        }
        override fun pause(): RocketsUpdate {
            val changed = phase == RocketsPhase.PLAYING || phase == RocketsPhase.COUNTDOWN
            if (changed) { paused = phase; phase = RocketsPhase.PAUSED }
            return RocketsUpdate(frame(), changed = changed)
        }
        private var paused: RocketsPhase? = null
        override fun resume(): RocketsUpdate {
            val previous = paused ?: return RocketsUpdate(frame())
            phase = previous; paused = null
            return RocketsUpdate(frame(), resumed = previous)
        }
        override fun restart(): RocketsUpdate =
            if (phase == RocketsPhase.ENDED) start(3).copy(changed = true) else RocketsUpdate(frame())
        override fun close() { closed = true }
    }

    private fun model(engine: FakeEngine) = HouseRocketsViewModel({ engine }, { 750L }).apply {
        updateContext("house", "user")
        selectMode(RocketsMode.LOCAL_BOTS)
        setViewport(844f, 390f, 800f, 369f)
    }

    @Test fun countdownRunsEveryStepThenFramesAdvanceWithRealDelta() = runTest(dispatcher) {
        val engine = FakeEngine()
        val model = model(engine)
        model.startMatch()
        assertEquals(listOf(844f, 390f, 800f, 369f), engine.viewports.single())
        assertEquals(3, model.frame.value?.countdown)
        advanceTimeBy(751); runCurrent()
        assertEquals(2, model.frame.value?.countdown)
        advanceTimeBy(1_500); runCurrent()
        assertEquals(RocketsPhase.PLAYING, model.frame.value?.phase)

        model.onFrame(1_000_000_000L)
        model.steer(0.5)
        model.steer(0.505) // Below iOS's 0.01 rad threshold.
        model.onFrame(1_016_000_000L)
        model.onFrame(1_032_000_000L)
        assertEquals(listOf(0.0 to null, 0.016 to 0.5, 0.016 to null),
            engine.steps.map { (it.first * 1000).toLong() / 1000.0 to it.second })
        assertEquals(1, engine.steps[1].third)
        model.stop()
        assertTrue(engine.closed)
        assertNull(model.frame.value)
    }

    @Test fun pauseDuringCountdownResumesTheCountdown() = runTest(dispatcher) {
        val engine = FakeEngine()
        val model = model(engine)
        model.startMatch()
        model.pause()
        advanceTimeBy(3_000); runCurrent()
        assertEquals(RocketsPhase.PAUSED, model.frame.value?.phase)
        assertEquals(3, engine.countdown)
        model.resume()
        advanceTimeBy(751); runCurrent()
        assertEquals(2, model.frame.value?.countdown)
        model.stop()
    }

    @Test fun hapticsFollowHumanEliminationAndResult() = runTest(dispatcher) {
        val engine = FakeEngine()
        val model = model(engine)
        val events = mutableListOf<RocketsHaptic>()
        val collector = launch(kotlinx.coroutines.Dispatchers.Unconfined) { model.haptics.collect { events += it } }
        model.startMatch()
        advanceTimeBy(2_300); runCurrent()
        engine.humanAlive = false
        model.onFrame(1L)
        engine.phase = RocketsPhase.ENDED
        engine.winner = "bot"
        model.onFrame(2L)
        assertEquals(listOf(RocketsHaptic.WARNING, RocketsHaptic.WARNING), events)
        model.restart()
        assertEquals(RocketsPhase.COUNTDOWN, model.frame.value?.phase)
        collector.cancel()
        model.stop()
    }

    @Test fun onlineBlockersFollowContextSupportAndTheServerCatalog() {
        assertEquals(RocketsOnlineBlocker.SIGN_IN_REQUIRED, HouseRocketsUiState().onlineBlocker)
        assertEquals(RocketsOnlineBlocker.HOUSE_REQUIRED, HouseRocketsUiState(userId = "u").onlineBlocker)
        assertEquals(RocketsOnlineBlocker.SERVICE_UNAVAILABLE, HouseRocketsUiState(userId = "u", houseId = "h").onlineBlocker)
        val supported = HouseRocketsUiState(userId = "u", houseId = "h", onlineSupported = true)
        assertNull("An unknown catalog never blocks", supported.onlineBlocker)
        assertNull(supported.copy(catalogAvailable = true).onlineBlocker)
        assertEquals(RocketsOnlineBlocker.GAME_UNAVAILABLE, supported.copy(catalogAvailable = false).onlineBlocker)
    }
}
