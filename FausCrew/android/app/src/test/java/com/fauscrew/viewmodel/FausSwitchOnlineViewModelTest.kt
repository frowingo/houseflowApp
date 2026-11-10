package com.fauscrew.viewmodel

import com.fauscrew.platform.FausSwitchSettings
import com.fauscrew.platform.FausSwitchSound
import com.fauscrew.platform.OnlineLobbyUi
import com.fauscrew.platform.OnlineOutput
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.RealtimeSocket
import com.fauscrew.platform.RealtimeSocketFactory
import com.fauscrew.platform.SwitchCamera
import com.fauscrew.platform.SwitchColor
import com.fauscrew.platform.SwitchDemoOutcome
import com.fauscrew.platform.SwitchEvent
import com.fauscrew.platform.SwitchEventType
import com.fauscrew.platform.SwitchFlip
import com.fauscrew.platform.SwitchGravity
import com.fauscrew.platform.SwitchLobbyColors
import com.fauscrew.platform.SwitchMatchUi
import com.fauscrew.platform.SwitchOnlineEngine
import com.fauscrew.platform.SwitchOnlineFrame
import com.fauscrew.platform.SwitchOnlineMatch
import com.fauscrew.platform.SwitchOnlineResult
import com.fauscrew.platform.SwitchPhase
import com.fauscrew.platform.SwitchRoom
import com.fauscrew.platform.SwitchRunner
import com.fauscrew.platform.SwitchRunnerStatus
import com.fauscrew.platform.SwitchWorld
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.launch
import kotlinx.coroutines.test.StandardTestDispatcher
import kotlinx.coroutines.test.TestScope
import kotlinx.coroutines.test.advanceTimeBy
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

/** The online room in [FausSwitchViewModel]: catalog, colors, the race screen, flips, rematch, leave and sign-in. */
@OptIn(ExperimentalCoroutinesApi::class)
class FausSwitchOnlineViewModelTest {
    private val dispatcher = StandardTestDispatcher()

    @Before fun setUp() = Dispatchers.setMain(dispatcher)
    @After fun tearDown() = Dispatchers.resetMain()

    private class Created(val houseId: String, val userId: String, val ownerId: String, val excluding: String?,
                          val preferred: SwitchColor?)

    /** Answers each event with the lobby the test set; the race frame is scripted too. */
    private class ScriptedEngine : SwitchOnlineEngine {
        val events = mutableListOf<Pair<String, Map<String, Any?>>>()
        var lobby: OnlineLobbyUi? = OnlineLobbyUi(statusKey = "faus_switch_online_lobby")
        var nextRoom = SwitchRoom()
        var closedAfterLeave = false
        var flipAnswer = SwitchFlip.FLIPPED
        var world: SwitchWorld? = null
        var frameEvents: List<SwitchEvent> = emptyList()
        var match = SwitchOnlineMatch(ui(), null, null)
        val viewports = mutableListOf<Pair<Double, Double>>()
        var isClosed = false
        private var closed = false

        override var room = SwitchRoom()
            private set
        override var lastFlip: SwitchFlip? = null
            private set

        override fun event(type: String, now: Double, fields: Map<String, Any?>): OnlineOutput {
            events += type to fields
            if (type == "leave" && closedAfterLeave) closed = true
            lastFlip = if (type == "flip") flipAnswer else null
            val sent = lobby
            if (sent != null) room = nextRoom
            return OnlineOutput(emptyList(), sent, null, closed, "old-session")
        }

        override fun receive(text: String, connection: Int, now: Double) = OnlineOutput(emptyList(), null, null, false, null)

        override fun viewport(width: Double, height: Double) {
            viewports += width to height
        }

        override fun frame(now: Double): SwitchOnlineFrame {
            val events = frameEvents
            frameEvents = emptyList()
            return SwitchOnlineFrame(world, match, events)
        }

        override fun close() {
            isClosed = true
        }

        fun types() = events.map { it.first }
    }

    private class FakeSettings : FausSwitchSettings {
        override var color: String? = null
        override var bestTime: Double? = null
        override var effectsEnabled: Boolean? = null
        override var musicEnabled: Boolean? = null
    }

    private class FakeSound : FausSwitchSound {
        override val isEffectsEnabled = true
        override val isMusicEnabled = true
        val log = mutableListOf<String>()
        override fun setEffectsEnabled(enabled: Boolean) = Unit
        override fun setMusicEnabled(enabled: Boolean) = Unit
        override fun startMusic() { log += "start" }
        override fun stopMusic() { log += "stop" }
        override fun setMusicPaused(paused: Boolean) = Unit
        override fun setMusicDucked(ducked: Boolean) { if (ducked) log += "ducked" }
        override fun playFlip(toward: SwitchGravity) { log += "flip-${toward.raw}" }
        override fun playPortal() { log += "portal" }
        override fun release() = Unit
    }

    private val engines = mutableListOf<ScriptedEngine>()
    private val created = mutableListOf<Created>()
    private val requests = mutableListOf<PlatformHttpRequest>()
    private var catalog: Boolean? = true
    private val settings = FakeSettings()
    private val sound = FakeSound()
    private val sockets = RealtimeSocketFactory { _, _, _, _ ->
        object : RealtimeSocket {
            override fun send(text: String) = true
            override fun close() = Unit
        }
    }

    private fun model(): FausSwitchViewModel {
        settings.color = "ocean"
        return FausSwitchViewModel(
            makeEngine = { throw AssertionError("No demo here") },
            settings = settings, audio = sound, botRange = 1..3, defaultBots = 3,
            online = FausSwitchOnlineDependencies(
                makeEngine = { house, user, owner, excluding, preferred ->
                    created += Created(house, user, owner, excluding, preferred)
                    ScriptedEngine().also { engines += it }
                },
                http = { request ->
                    requests += request
                    PlatformHttpResponse(200, emptyMap(), "{}".toByteArray())
                },
                token = { "token" },
                sockets = sockets,
                catalogAvailability = { _, _, _ -> catalog },
                clock = { 100.0 },
            ),
        )
    }

    /** Opens the room of house `h` for `u` and lets the catalog read finish. */
    private fun TestScope.openRoom(model: FausSwitchViewModel): ScriptedEngine? {
        model.updateContext("h", "u", "owner")
        model.selectMode(SwitchMode.ONLINE)
        runCurrent()
        return engines.lastOrNull()
    }

    /** The first race snapshot opens the race screen. */
    private fun TestScope.startRace(engine: ScriptedEngine) {
        engine.lobby = OnlineLobbyUi(hasGame = true, gamePhase = "countdown")
        engine.world = world(SwitchGravity.DOWN)
        engine.match = SwitchOnlineMatch(ui(phase = SwitchPhase.COUNTDOWN), 3, null)
        engines.last().events.clear()
        model?.retryOnline()
        runCurrent()
    }

    private var model: FausSwitchViewModel? = null

    @Test
    fun theRoomOpensAfterTheCatalogWithTheRememberedColor() = runTest(dispatcher) {
        val model = model().also { this@FausSwitchOnlineViewModelTest.model = it }
        assertTrue(model.state.value.onlineServiceAvailable)
        model.setViewport(844.0, 390.0)
        val engine = openRoom(model)!!

        assertEquals("game/catalog", requests.single().path)
        assertEquals("Bearer token", requests.single().headers["Authorization"])
        assertEquals("h", requests.single().queryItems.single().value)
        assertEquals(true, model.state.value.catalogAvailable)
        val made = created.single()
        assertEquals(listOf("h", "u", "owner"), listOf(made.houseId, made.userId, made.ownerId))
        assertNull(made.excluding)
        assertEquals(SwitchColor.OCEAN, made.preferred)
        assertEquals("start", engine.types().first())
        assertEquals(listOf(844.0 to 390.0), engine.viewports)
        assertNotNull(model.onlineSession.value)

        // A new pick is remembered and sent to the room; the room's colors follow the lobby.
        engine.nextRoom = SwitchRoom(colors = SwitchLobbyColors(local = SwitchColor.BERRY, takenByOthers = setOf(SwitchColor.PLUM)))
        model.selectColor(SwitchColor.BERRY)
        assertEquals("berry", settings.color)
        assertEquals("selectColor" to mapOf("color" to "berry"), engine.events.last())
        assertEquals(SwitchColor.BERRY, model.onlineSession.value!!.room.value.colors.local)

        model.setOnlineReady(true)
        assertEquals("setReady" to mapOf("ready" to true), engine.events.last())

        // Ready locks the color: a pick changes nothing until the ready is taken back.
        engine.nextRoom = SwitchRoom(colors = SwitchLobbyColors(local = SwitchColor.BERRY, isLocked = true))
        model.setOnlineReady(true)
        model.selectColor(SwitchColor.FOREST)
        assertEquals("berry", settings.color)
        assertEquals(SwitchColor.BERRY, model.state.value.color)
        assertEquals("setReady", engine.events.last().first)
        model.stop()
    }

    @Test
    fun aClosedHouseOpensNoRoom() = runTest(dispatcher) {
        catalog = false
        val model = model()
        openRoom(model)
        assertTrue(created.isEmpty())
        assertEquals(false, model.state.value.catalogAvailable)
        assertNull(model.onlineSession.value)
    }

    @Test
    fun theFirstSnapshotOpensTheRaceAndFramesDriveIt() = runTest(dispatcher) {
        val model = model().also { this@FausSwitchOnlineViewModelTest.model = it }
        val haptics = mutableListOf<SwitchHaptic>()
        val job = launch { model.haptics.collect { haptics += it } }
        val engine = openRoom(model)!!
        assertFalse(model.state.value.isOnlineMatchVisible)
        startRace(engine)
        assertTrue(model.state.value.isOnlineMatchVisible)
        assertEquals(listOf("start"), sound.log)
        // Selecting a mode is locked during the race.
        model.selectMode(SwitchMode.DEMO)
        assertEquals(SwitchMode.ONLINE, model.state.value.selectedMode)

        engine.frameEvents = listOf(SwitchEvent(SwitchEventType.HUMAN_TELEPORTED))
        model.onFrame(1)
        assertNotNull(model.frame.value)
        assertEquals(SwitchPhase.COUNTDOWN, model.match.value!!.phase)
        assertEquals(3, model.onlineMatch.value!!.roomCountdown)
        assertTrue("portal" in sound.log)

        // A flip sounds toward the rail opposite the last drawn one.
        model.flip()
        engine.flipAnswer = SwitchFlip.UNSUPPORTED
        model.flip()
        runCurrent()
        assertTrue("flip-up" in sound.log)
        assertEquals(listOf(SwitchHaptic.WARNING, SwitchHaptic.LIGHT, SwitchHaptic.RIGID), haptics)

        model.setOnlineLandscape(true)
        model.setForeground(false)
        model.setReduceMotion(true)
        assertTrue(engine.events.contains("setLandscape" to mapOf("landscape" to true)))
        assertTrue(engine.types().containsAll(listOf("flip", "setForeground", "setReduceMotion")))
        job.cancel()
        model.stop()
    }

    @Test
    fun rematchOpensANewRoomThatExcludesTheFinishedOne() = runTest(dispatcher) {
        val model = model().also { this@FausSwitchOnlineViewModelTest.model = it }
        val first = openRoom(model)!!
        startRace(first)
        first.match = SwitchOnlineMatch(ui(phase = SwitchPhase.ENDED, showsResult = true), null, result(canRematch = true))
        model.onFrame(1)
        assertTrue("ducked" in sound.log)

        model.rematchOnline()
        runCurrent()
        assertTrue(first.isClosed)
        assertEquals("old-session", created.last().excluding)
        assertEquals(2, engines.size)
        assertFalse(model.state.value.isOnlineMatchVisible)
        assertTrue(model.state.value.isOnlineRematchRoom)
        assertNull(model.frame.value)
        assertEquals("stop", sound.log.last())

        // The new race's first snapshot ends the rematch room.
        startRace(engines.last())
        assertTrue(model.state.value.isOnlineMatchVisible)
        assertFalse(model.state.value.isOnlineRematchRoom)
        model.stop()
    }

    @Test
    fun playAgainReadiesTheNextSessionOverTheFinishedRace() = runTest(dispatcher) {
        val model = model().also { this@FausSwitchOnlineViewModelTest.model = it }
        val first = openRoom(model)!!
        startRace(first)
        first.match = SwitchOnlineMatch(ui(phase = SwitchPhase.ENDED, showsResult = true), null, result(canRematch = true))
        model.onFrame(1)

        model.playOnlineAgain()
        runCurrent()
        assertTrue(first.isClosed)
        assertEquals("old-session", created.last().excluding)
        // The arena stays (landscape, last frame) with the replay room over it; the ready goes out.
        assertTrue(model.state.value.isOnlineMatchVisible)
        assertTrue(model.state.value.isOnlineReplayRoom)
        assertFalse(model.state.value.isOnlineRematchRoom)
        assertNotNull(model.frame.value)
        assertTrue("readyOnJoin" in engines.last().types())

        // The new race's first snapshot starts it in place.
        startRace(engines.last())
        assertTrue(model.state.value.isOnlineMatchVisible)
        assertFalse(model.state.value.isOnlineReplayRoom)
        assertEquals("start", sound.log.last())
        model.stop()
    }

    @Test
    fun backToLobbyFromThePlayAgainRoomShowsThePortraitRoom() = runTest(dispatcher) {
        val model = model().also { this@FausSwitchOnlineViewModelTest.model = it }
        val first = openRoom(model)!!
        startRace(first)
        first.match = SwitchOnlineMatch(ui(phase = SwitchPhase.ENDED, showsResult = true), null, result(canRematch = true))
        model.onFrame(1)
        model.playOnlineAgain()
        runCurrent()

        model.returnToOnlineLobby()
        assertFalse(model.state.value.isOnlineMatchVisible)
        assertFalse(model.state.value.isOnlineReplayRoom)
        assertTrue(model.state.value.isOnlineRematchRoom)
        assertNull(model.frame.value)
        // The joined session stays: the lobby shows it.
        assertEquals(2, engines.size)
        assertNotNull(model.onlineSession.value)
        model.stop()
    }

    @Test
    fun leavingSendsALeaveAndClosesOnTheServersAnswer() = runTest(dispatcher) {
        val model = model().also { this@FausSwitchOnlineViewModelTest.model = it }
        val engine = openRoom(model)!!
        startRace(engine)
        engine.closedAfterLeave = true
        model.leaveOnlineMatch()
        assertNull(model.onlineSession.value)
        assertNull(model.state.value.selectedMode)
        assertFalse(model.state.value.isOnlineMatchVisible)
        assertEquals("leave", engine.types().last())
        advanceTimeBy(100)
        runCurrent()
        assertTrue(engine.isClosed)
    }

    @Test
    fun anotherHouseClosesTheRoomButANewOwnerDoesNotStopTheRace() = runTest(dispatcher) {
        val model = model().also { this@FausSwitchOnlineViewModelTest.model = it }
        val engine = openRoom(model)!!
        startRace(engine)
        model.updateContext("h", "u", "new-owner")
        assertTrue(model.state.value.isOnlineMatchVisible)
        assertEquals("new-owner", model.state.value.houseOwnerId)

        model.updateContext("other", "u", "new-owner")
        assertFalse(model.state.value.isOnlineMatchVisible)
        assertEquals("leave", engine.types().last())
        runCurrent()
        assertEquals("other", created.last().houseId)
        model.stop()
    }

    @Test
    fun aRejectedSignInIsReported() = runTest(dispatcher) {
        val model = model().also { this@FausSwitchOnlineViewModelTest.model = it }
        val engine = openRoom(model)!!
        assertFalse(model.requiresOnlineSignIn())
        engine.lobby = OnlineLobbyUi(requiresAuthentication = true)
        model.retryOnline()
        assertTrue(model.requiresOnlineSignIn())
        model.stop()
    }

    private companion object {
        fun ui(phase: SwitchPhase = SwitchPhase.PLAYING, showsResult: Boolean = false) = SwitchMatchUi(
            phase, if (phase == SwitchPhase.COUNTDOWN) 3 else null, emptyList(), emptyList(), SwitchRunnerStatus.RUNNING, null,
            null, null, 2, phase == SwitchPhase.PLAYING, null, null, false, false, false, showsResult, false,
            SwitchDemoOutcome.TIME_UP, "faus_switch_time_up", "faus_switch_time_up_detail",
        )

        fun world(gravity: SwitchGravity) = SwitchWorld(
            "m", 1, 0.0, SwitchPhase.COUNTDOWN, 3, SwitchCamera(1.0, 0.0, 0.0, 844.0, 390.0, 1.0), 0.0, 0.0, 0.0, 0.0, 0.0,
            listOf(SwitchRunner("u", null, null, SwitchColor.OCEAN, true, true, false, null, SwitchRunnerStatus.RUNNING,
                gravity, 1.0, null, 0.0, 0.0, 0.0, 0.0, 0.0, false)),
            emptyList(), null,
        )

        fun result(canRematch: Boolean) = SwitchOnlineResult(
            phase = "final", isWaiting = false, isFailed = false, titleKey = "faus_switch_online_won",
            detailKey = "faus_switch_online_final_detail", canRematch = canRematch, canRetry = false, retryNotBefore = 0.0,
            sessionId = "s1", winnerId = "u", winnerName = null, standings = emptyList(),
        )
    }
}
