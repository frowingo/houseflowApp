package com.fauscrew.viewmodel

import com.fauscrew.platform.FausSwitchEngine
import com.fauscrew.platform.FausSwitchSettings
import com.fauscrew.platform.FausSwitchSound
import com.fauscrew.platform.SwitchCamera
import com.fauscrew.platform.SwitchColor
import com.fauscrew.platform.SwitchDemoOutcome
import com.fauscrew.platform.SwitchEvent
import com.fauscrew.platform.SwitchEventType
import com.fauscrew.platform.SwitchFlip
import com.fauscrew.platform.SwitchGravity
import com.fauscrew.platform.SwitchMatchUi
import com.fauscrew.platform.SwitchPhase
import com.fauscrew.platform.SwitchUpdate
import com.fauscrew.platform.SwitchWorld
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class FausSwitchViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    /** Mirrors FausSwitchBotMatch's phases; the test queues the events each step returns. */
    private class FakeEngine : FausSwitchEngine {
        var phase = SwitchPhase.COUNTDOWN
        var started = 0
        var lastStart: Pair<SwitchColor, Int>? = null
        val viewports = mutableListOf<Pair<Double, Double>>()
        val steps = mutableListOf<Double>()
        var nextEvents: List<SwitchEvent> = emptyList()
        var localTime: Double? = null
        var flipAnswer = SwitchFlip.FLIPPED
        var gravity = SwitchGravity.DOWN
        var closed = false

        private fun update(events: List<SwitchEvent> = emptyList(), flip: SwitchFlip? = null) = SwitchUpdate(
            world = SwitchWorld("m$started", 1, 0.0, phase, null, SwitchCamera(1.0, 0.0, 0.0, 844.0, 390.0, 1.0),
                0.0, 0.0, 0.0, 0.0, 0.0, emptyList(), emptyList(), null),
            match = SwitchMatchUi(phase, null, emptyList(), emptyList(), null, null, 1, localTime, 2,
                phase == SwitchPhase.PLAYING, null, null, false, false, false, false, false, SwitchDemoOutcome.TIME_UP,
                "faus_switch_time_up", "faus_switch_time_up_detail"),
            events = events,
            flip = flip,
            gravity = if (flip != null) gravity else null,
        )

        override fun viewport(width: Double, height: Double): SwitchUpdate {
            viewports += width to height
            return if (started > 0) update() else SwitchUpdate(null, null, changed = true)
        }
        override fun start(color: SwitchColor, botCount: Int): SwitchUpdate {
            started += 1; phase = SwitchPhase.COUNTDOWN; lastStart = color to botCount
            return update()
        }
        override fun step(deltaSeconds: Double): SwitchUpdate {
            steps += deltaSeconds
            val events = nextEvents
            nextEvents = emptyList()
            return update(events)
        }
        override fun flip(): SwitchUpdate {
            if (flipAnswer == SwitchFlip.FLIPPED) gravity = gravity.opposite
            return update(flip = flipAnswer)
        }
        override fun pause(): SwitchUpdate { phase = SwitchPhase.PAUSED; return update() }
        override fun resume(): SwitchUpdate { phase = SwitchPhase.PLAYING; return update() }
        override fun restart() = start(lastStart!!.first, lastStart!!.second)
        override fun close() { closed = true }
    }

    private class FakeSettings : FausSwitchSettings {
        override var color: String? = null
        override var bestTime: Double? = null
        override var effectsEnabled: Boolean? = null
        override var musicEnabled: Boolean? = null
    }

    private class FakeSound : FausSwitchSound {
        private var effects = true
        private var music = true
        override val isEffectsEnabled get() = effects
        override val isMusicEnabled get() = music
        val log = mutableListOf<String>()
        override fun setEffectsEnabled(enabled: Boolean) { effects = enabled }
        override fun setMusicEnabled(enabled: Boolean) { music = enabled }
        override fun startMusic() { log += "start" }
        override fun stopMusic() { log += "stop" }
        override fun setMusicPaused(paused: Boolean) { log += "paused=$paused" }
        override fun setMusicDucked(ducked: Boolean) { if (ducked) log += "ducked" }
        override fun playFlip(toward: SwitchGravity) { log += "flip-${toward.raw}" }
        override fun playPortal() { log += "portal" }
        override fun release() { log += "release" }
    }

    private val engine = FakeEngine()
    private val settings = FakeSettings()
    private val sound = FakeSound()
    private fun model() = FausSwitchViewModel({ engine }, settings, sound, 1..3, 3)

    @Test
    fun startsWithTheRememberedColorAndDefaults() {
        settings.color = "ocean"
        settings.bestTime = 52.5
        val model = model()
        assertEquals(SwitchColor.OCEAN, model.state.value.color)
        assertEquals(3, model.state.value.botCount)
        assertEquals(52.5, model.state.value.bestTime!!, 0.0)
        assertFalse(model.state.value.onlineServiceAvailable)
        assertEquals(SwitchColor.LAVENDER, FausSwitchViewModel({ engine }, FakeSettings(), sound, 1..3, 3).state.value.color)
    }

    @Test
    fun lobbyPicksAreRememberedAndClamped() {
        val model = model()
        model.selectMode(SwitchMode.DEMO)
        model.selectColor(SwitchColor.BERRY)
        model.selectBotCount(12)
        assertEquals("berry", settings.color)
        assertEquals(3, model.state.value.botCount)
        model.selectBotCount(0)
        assertEquals(1, model.state.value.botCount)
        model.returnToModeSelection()
        assertNull(model.state.value.selectedMode)
    }

    @Test
    fun startDemoUsesThePicksTheViewportAndTheMusic() {
        val model = model()
        model.setViewport(844.0, 390.0)
        model.selectColor(SwitchColor.FOREST)
        model.selectBotCount(2)
        model.startDemo()
        assertEquals(SwitchColor.FOREST to 2, engine.lastStart)
        assertEquals(listOf(844.0 to 390.0), engine.viewports)
        assertTrue(model.state.value.isDemoVisible)
        assertNotNull(model.frame.value)
        assertEquals(SwitchPhase.COUNTDOWN, model.match.value!!.phase)
        assertEquals(listOf("start"), sound.log)
        // A rotation mid-race resizes the camera.
        model.setViewport(390.0, 844.0)
        assertEquals(390.0 to 844.0, engine.viewports.last())
    }

    @Test
    fun framesStepTheRaceWithAClampedDelta() {
        val model = model()
        model.startDemo()
        model.onFrame(1_000_000_000)
        model.onFrame(1_016_000_000)
        model.onFrame(2_000_000_000)
        assertEquals(listOf(0.0, 0.016, 0.05), engine.steps.map { Math.round(it * 1000) / 1000.0 })
    }

    @Test
    fun eventsDriveHapticsSoundsTheResultAndTheBestTime() = runTest(dispatcher) {
        val model = model()
        val haptics = mutableListOf<SwitchHaptic>()
        val job = launch { model.haptics.collect { haptics += it } }
        runCurrent()
        model.startDemo()
        engine.nextEvents = listOf(SwitchEvent(SwitchEventType.COUNTDOWN, 2), SwitchEvent(SwitchEventType.STARTED))
        model.onFrame(1)
        engine.phase = SwitchPhase.PLAYING
        engine.nextEvents = listOf(SwitchEvent(SwitchEventType.HUMAN_SLOWED), SwitchEvent(SwitchEventType.HUMAN_TELEPORTED))
        model.onFrame(2)
        engine.localTime = 48.25
        engine.nextEvents = listOf(SwitchEvent(SwitchEventType.HUMAN_FINISHED))
        model.onFrame(3)
        runCurrent()
        assertEquals(listOf(SwitchHaptic.SOFT, SwitchHaptic.MEDIUM, SwitchHaptic.SOFT, SwitchHaptic.WARNING, SwitchHaptic.SUCCESS),
            haptics)
        assertTrue("portal" in sound.log)
        assertTrue(model.state.value.showsDemoResult)
        assertEquals(48.25, settings.bestTime!!, 0.0)
        // The result panel ducks the music.
        assertTrue("ducked" in sound.log)

        // A slower finish keeps the record.
        model.restartDemo()
        engine.localTime = 60.0
        engine.nextEvents = listOf(SwitchEvent(SwitchEventType.HUMAN_FINISHED))
        model.onFrame(10)
        assertEquals(48.25, model.state.value.bestTime!!, 0.0)
        job.cancel()
    }

    @Test
    fun watchingHidesTheResultUntilTheRaceEnds() {
        val model = model()
        model.startDemo()
        engine.phase = SwitchPhase.PLAYING
        engine.nextEvents = listOf(SwitchEvent(SwitchEventType.HUMAN_CRASHED, reason = "boundary"))
        model.onFrame(1)
        assertTrue(model.state.value.showsDemoResult)
        model.watchDemo()
        assertFalse(model.state.value.showsDemoResult)
        assertTrue(model.state.value.isWatchingDemo)
        engine.phase = SwitchPhase.ENDED
        engine.nextEvents = listOf(SwitchEvent(SwitchEventType.ENDED))
        model.onFrame(2)
        assertTrue(model.state.value.showsDemoResult)
        assertFalse(model.state.value.isWatchingDemo)
        // Nothing left to watch.
        model.watchDemo()
        assertTrue(model.state.value.showsDemoResult)
    }

    @Test
    fun flipsPlayTheSoundTowardTheNewRail() = runTest(dispatcher) {
        val model = model()
        val haptics = mutableListOf<SwitchHaptic>()
        val job = launch { model.haptics.collect { haptics += it } }
        runCurrent()
        model.flip()
        assertTrue("A tap before the race does nothing", sound.log.none { it.startsWith("flip") })
        model.startDemo()
        model.flip()
        engine.flipAnswer = SwitchFlip.UNSUPPORTED
        model.flip()
        runCurrent()
        assertEquals(listOf("start", "flip-up"), sound.log)
        assertEquals(listOf(SwitchHaptic.LIGHT, SwitchHaptic.RIGID), haptics)
        job.cancel()
    }

    @Test
    fun pauseResumeAndExit() {
        val model = model()
        model.startDemo()
        model.pauseDemo()
        assertTrue(model.state.value.isPaused)
        assertEquals(SwitchPhase.PAUSED, model.match.value!!.phase)
        model.onFrame(5)
        assertTrue("A paused race does not step", engine.steps.isEmpty())
        model.setForeground(false)
        model.setForeground(true)
        assertEquals(listOf("start", "paused=true", "paused=true"), sound.log)
        model.resumeDemo()
        assertFalse(model.state.value.isPaused)
        assertEquals("paused=false", sound.log.last())
        model.exitDemo()
        assertTrue(engine.closed)
        assertFalse(model.state.value.isDemoVisible)
        assertNull(model.frame.value)
        assertNull(model.match.value)
        assertEquals("stop", sound.log.last())
    }

    @Test
    fun soundAndMusicSwitchSeparately() {
        val model = model()
        model.toggleSound()
        assertFalse(model.state.value.isSoundEnabled)
        assertTrue(model.state.value.isMusicEnabled)
        model.toggleMusic()
        assertFalse(model.state.value.isMusicEnabled)
    }
}
