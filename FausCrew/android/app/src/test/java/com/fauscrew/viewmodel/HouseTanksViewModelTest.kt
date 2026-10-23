package com.fauscrew.viewmodel

import com.fauscrew.platform.HouseTanksEngine
import com.fauscrew.platform.TanksColor
import com.fauscrew.platform.TanksDifficulty
import com.fauscrew.platform.TanksFrame
import com.fauscrew.platform.TanksMap
import com.fauscrew.platform.TanksPhase
import com.fauscrew.platform.TanksPlayer
import com.fauscrew.platform.TanksRole
import com.fauscrew.platform.TanksUpdate
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
import org.junit.Assert.assertNotNull
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

@OptIn(ExperimentalCoroutinesApi::class)
class HouseTanksViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    /** Mirrors HouseTanksBotMatch's phases without the arena. */
    private class FakeEngine : HouseTanksEngine {
        var phase = TanksPhase.COUNTDOWN
        var countdown: Int? = 3
        var humanArmor = 5
        var started = 0
        var revision = 0
        val presses = mutableListOf<Boolean>()
        val steps = mutableListOf<Double>()
        var lastStart: Triple<TanksDifficulty, TanksColor, TanksMap>? = null
        var closed = false

        fun frame() = TanksFrame(
            "m$started", "m$started-1", ++revision, phase, countdown, 1, null, null,
            listOf(TanksPlayer("h", "house_tanks_you", TanksRole.HUMAN, TanksColor.PLUM, humanArmor, 0, humanArmor > 0)),
            844.0, 390.0, 0.0, emptyList(), emptyList(), emptyList(), null, emptyList(), null,
        )

        override fun viewport(width: Float, height: Float) = TanksUpdate(if (started > 0) frame() else null)
        override fun start(difficulty: TanksDifficulty, color: TanksColor, map: TanksMap): TanksUpdate {
            started += 1; phase = TanksPhase.COUNTDOWN; countdown = 3; humanArmor = 5
            lastStart = Triple(difficulty, color, map)
            return TanksUpdate(frame())
        }
        override fun countdown(): TanksUpdate {
            val value = countdown ?: 3
            if (value > 1) countdown = value - 1 else { countdown = null; phase = TanksPhase.PLAYING }
            return TanksUpdate(frame(), started = phase == TanksPhase.PLAYING)
        }
        override fun step(deltaSeconds: Double): TanksUpdate { steps += deltaSeconds; return TanksUpdate(frame()) }
        override fun press(pressed: Boolean): TanksUpdate { presses += pressed; return TanksUpdate(frame(), changed = true) }
        override fun nextRound(): TanksUpdate { phase = TanksPhase.COUNTDOWN; countdown = 3; return TanksUpdate(frame(), changed = true) }
        override fun restart() = start(lastStart!!.first, lastStart!!.second, lastStart!!.third).copy(changed = true)
        override fun pause(): TanksUpdate { phase = TanksPhase.PAUSED; return TanksUpdate(frame(), changed = true) }
        override fun resume(): TanksUpdate { phase = TanksPhase.PLAYING; return TanksUpdate(frame(), changed = true) }
        override fun close() { closed = true }
    }

    private fun model(engine: FakeEngine) = HouseTanksViewModel({ engine }, { 720L }, { TanksMap.WAREHOUSE })

    @Test fun demoSetupStartsEmptyAndWillNotStartUntilEveryPickIsMade() {
        val engine = FakeEngine()
        val model = model(engine)
        model.selectMode(TanksMode.DEMO)
        assertEquals(TanksSetupStep.MAP, model.state.value.pendingSetupStep)
        model.startMatch()
        assertNull(model.frame.value)

        model.selectColor(TanksColor.BLUE)
        assertEquals(TanksSetupStep.MAP, model.state.value.pendingSetupStep)
        model.selectMap(TanksMap.COURTYARD)
        assertEquals(TanksSetupStep.DIFFICULTY, model.state.value.pendingSetupStep)
        model.selectDifficulty(TanksDifficulty.HARD)
        assertNull(model.state.value.pendingSetupStep)
        assertEquals(3, model.state.value.completedSetupSteps)

        model.startMatch()
        assertEquals(Triple(TanksDifficulty.HARD, TanksColor.BLUE, TanksMap.COURTYARD), engine.lastStart)
        assertNotNull(model.frame.value)
    }

    @Test fun onlineRoomDrawsItsMap() {
        val model = model(FakeEngine())
        model.selectMode(TanksMode.ONLINE)
        assertEquals(TanksMap.WAREHOUSE, model.state.value.onlineMap)
        assertEquals(TanksMap.WAREHOUSE, model.state.value.matchMap)
        model.returnToModeSelection()
        assertNull(model.state.value.onlineMap)
    }

    @Test fun countdownStepsEvery720msThenFramesAdvanceTheArena() = runTest(dispatcher) {
        val engine = FakeEngine()
        val model = model(engine).ready()
        model.startMatch()
        advanceTimeBy(721); runCurrent()
        assertEquals(2, model.frame.value?.countdown)
        advanceTimeBy(1_440); runCurrent()
        assertEquals(TanksPhase.PLAYING, model.frame.value?.phase)

        model.onFrame(1_000_000_000L)
        model.onFrame(1_016_000_000L)
        model.onFrame(2_000_000_000L)
        assertEquals(listOf(0.016, 0.05), engine.steps.map { Math.round(it * 1_000) / 1_000.0 })
    }

    @Test fun pressesAreForwardedOnceAndPauseReleasesThem() = runTest(dispatcher) {
        val engine = FakeEngine()
        val model = model(engine).ready()
        model.startMatch()
        advanceTimeBy(3_000); runCurrent()
        model.beginPress(); model.beginPress()
        assertEquals(listOf(true), engine.presses)
        model.pause()
        assertEquals(listOf(true, false), engine.presses)
        assertEquals(TanksPhase.PAUSED, model.frame.value?.phase)
    }

    @Test fun armorLossFlashesAndBuzzes() = runTest(dispatcher) {
        val engine = FakeEngine()
        val model = model(engine).ready()
        val hits = mutableListOf<String>()
        val haptics = mutableListOf<TanksHaptic>()
        backgroundScope.launch { model.hits.collect { hits += it } }
        backgroundScope.launch { model.haptics.collect { haptics += it } }
        model.startMatch()
        advanceTimeBy(3_000); runCurrent()
        engine.humanArmor = 4
        model.onFrame(1L); model.onFrame(16_000_001L)
        runCurrent()
        assertEquals(listOf("h"), hits)
        assertTrue(TanksHaptic.HIT in haptics)
    }

    @Test fun drillSetupKeepsPicksAndClosesTheMatch() = runTest(dispatcher) {
        val engine = FakeEngine()
        val model = model(engine).ready()
        model.startMatch()
        model.returnToDemoSetup()
        assertNull(model.frame.value)
        assertTrue(engine.closed)
        assertEquals(TanksMode.DEMO, model.state.value.selectedMode)
        assertEquals(TanksMap.LIVING_ROOM, model.state.value.map)
    }

    private fun HouseTanksViewModel.ready() = apply {
        selectMode(TanksMode.DEMO)
        selectMap(TanksMap.LIVING_ROOM)
        selectColor(TanksColor.PLUM)
        selectDifficulty(TanksDifficulty.NORMAL)
    }
}
