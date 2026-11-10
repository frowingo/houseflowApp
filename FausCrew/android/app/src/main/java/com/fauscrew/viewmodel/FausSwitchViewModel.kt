package com.fauscrew.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fauscrew.platform.AndroidHttpAdapter
import com.fauscrew.platform.FausSwitchAudio
import com.fauscrew.platform.FausSwitchEngine
import com.fauscrew.platform.FausSwitchNative
import com.fauscrew.platform.FausSwitchOnlineNative
import com.fauscrew.platform.FausSwitchSettings
import com.fauscrew.platform.FausSwitchSound
import com.fauscrew.platform.KeystoreSessionStore
import com.fauscrew.platform.OkHttpRealtimeSocketFactory
import com.fauscrew.platform.OnlineClock
import com.fauscrew.platform.PlatformHttpQueryItem
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.RealtimeSocketFactory
import com.fauscrew.platform.SessionField
import com.fauscrew.platform.SessionReadResult
import com.fauscrew.platform.SharedPreferencesSwitchSettings
import com.fauscrew.platform.SwitchColor
import com.fauscrew.platform.SwitchEventType
import com.fauscrew.platform.SwitchFlip
import com.fauscrew.platform.SwitchMatchUi
import com.fauscrew.platform.SwitchOnlineEngine
import com.fauscrew.platform.SwitchOnlineMatch
import com.fauscrew.platform.SwitchPhase
import com.fauscrew.platform.SwitchUpdate
import com.fauscrew.platform.SwitchWorld
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableSharedFlow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharedFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asSharedFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** `FausSwitchMode`. */
internal enum class SwitchMode { DEMO, ONLINE }

/** iOS's feedback generators by their use; the screen picks the Android constant. */
internal enum class SwitchHaptic { LIGHT, RIGID, SOFT, MEDIUM, WARNING, ERROR, SUCCESS }

/** Platform I/O for the online room; the rules live in FausCrewCore's `FausSwitchOnlineEngine`. */
internal class FausSwitchOnlineDependencies(
    val makeEngine: (houseId: String, userId: String, houseOwnerId: String, excludingSessionId: String?,
                     preferredColor: SwitchColor?) -> SwitchOnlineEngine,
    val http: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    val token: suspend () -> String?,
    val sockets: RealtimeSocketFactory,
    val catalogAvailability: (houseId: String, status: Int, body: String) -> Boolean?,
    /** The host's uptime in seconds (tests substitute a fixed clock). */
    val clock: () -> Double = OnlineClock::now,
)

internal data class FausSwitchUiState(
    val selectedMode: SwitchMode? = null,
    /** The robot color: the demo robot (and, from Phase 7, the online request). */
    val color: SwitchColor = SwitchColor.LAVENDER,
    val botCount: Int = 3,
    val botRange: IntRange = 1..3,
    val bestTime: Double? = null,
    /** The robot's flip and portal sounds (HUD speaker button, remembered). */
    val isSoundEnabled: Boolean = true,
    /** The background track (HUD music button, remembered). */
    val isMusicEnabled: Boolean = true,
    /** True while a demo race is on screen (countdown to result). */
    val isDemoVisible: Boolean = false,
    val isPaused: Boolean = false,
    /** The demo result panel; dismissing it keeps watching the bots until the race ends. */
    val showsDemoResult: Boolean = false,
    val isWatchingDemo: Boolean = false,
    /** This build can open online rooms (iOS: an online factory). */
    val onlineServiceAvailable: Boolean = false,
    val houseId: String? = null,
    val userId: String? = null,
    val houseOwnerId: String? = null,
    /** Server catalog: `false` when Faus Switch is closed for this house; `null` = unknown. */
    val catalogAvailable: Boolean? = null,
    /** From the online race's first snapshot (its countdown) until the player leaves it. */
    val isOnlineMatchVisible: Boolean = false,
    /** A rematch's new session before its first snapshot: the lobby shows the new room. */
    val isOnlineRematchRoom: Boolean = false,
    /**
     * Play Again: the next session's room shown over the finished race until its first
     * snapshot with a game, when the new race starts in place (no portrait room between).
     */
    val isOnlineReplayRoom: Boolean = false,
)

/**
 * `FausSwitchViewModel`: a demo race against local bots (FausCrewCore's `FausSwitchBotMatch`)
 * and an online race run by the server through `FausSwitchOnlineEngine`. One canvas draws
 * both; this model schedules them on the display clock, turns their events into haptics and
 * sounds and keeps the lobby's picks.
 */
internal class FausSwitchViewModel(
    private val makeEngine: () -> FausSwitchEngine,
    private val settings: FausSwitchSettings,
    private val audio: FausSwitchSound,
    botRange: IntRange,
    defaultBots: Int,
    private val online: FausSwitchOnlineDependencies? = null,
) : ViewModel() {
    private val mutableState = MutableStateFlow(
        FausSwitchUiState(
            color = SwitchColor.from(settings.color) ?: SwitchColor.LAVENDER,
            botCount = defaultBots.coerceIn(botRange),
            botRange = botRange,
            bestTime = settings.bestTime?.takeIf { it > 0 },
            isSoundEnabled = audio.isEffectsEnabled,
            isMusicEnabled = audio.isMusicEnabled,
            onlineServiceAvailable = online != null,
        ),
    )
    val state: StateFlow<FausSwitchUiState> = mutableState.asStateFlow()

    private val mutableFrame = MutableStateFlow<SwitchWorld?>(null)
    /** The moving world, read by the canvas in the draw phase. */
    val frame: StateFlow<SwitchWorld?> = mutableFrame.asStateFlow()

    private val mutableMatch = MutableStateFlow<SwitchMatchUi?>(null)
    /** The overlays; it changes only when something they show changes. */
    val match: StateFlow<SwitchMatchUi?> = mutableMatch.asStateFlow()

    private val mutableHaptics = MutableSharedFlow<SwitchHaptic>(extraBufferCapacity = 8)
    val haptics: SharedFlow<SwitchHaptic> = mutableHaptics.asSharedFlow()

    private val mutableOnline = MutableStateFlow<FausSwitchOnlineSession?>(null)
    /** The current online room, or null. */
    val onlineSession: StateFlow<FausSwitchOnlineSession?> = mutableOnline.asStateFlow()

    private val mutableOnlineMatch = MutableStateFlow<SwitchOnlineMatch?>(null)
    /** The online overlays (notice, result, room countdown); equal values do not recompose. */
    val onlineMatch: StateFlow<SwitchOnlineMatch?> = mutableOnlineMatch.asStateFlow()

    private var engine: FausSwitchEngine? = null
    private var viewport: Pair<Double, Double>? = null
    private var lastFrameNanos: Long? = null
    private var catalogJob: Job? = null
    private var lobbyJob: Job? = null
    private var isForeground = true
    private var isLandscape = false
    private var reduceMotion = false

    // Lobby

    /** The signed-in player and their house; another house or account closes the room, a running race included. */
    fun updateContext(houseId: String?, userId: String?, houseOwnerId: String? = null) {
        val current = mutableState.value
        if (current.houseId == houseId && current.userId == userId && current.houseOwnerId == houseOwnerId) return
        // A new owner only changes who may cancel a lobby; it never takes a running race away.
        if (current.houseId == houseId && current.userId == userId && current.isOnlineMatchVisible) {
            mutableState.update { it.copy(houseOwnerId = houseOwnerId) }
            return
        }
        leaveOnlineRoom()
        mutableState.update {
            it.copy(houseId = houseId, userId = userId, houseOwnerId = houseOwnerId,
                catalogAvailable = if (it.houseId == houseId) it.catalogAvailable else null)
        }
        if (current.selectedMode == SwitchMode.ONLINE) enterOnlineRoom()
    }

    fun selectMode(mode: SwitchMode) {
        if (state.value.isDemoVisible || state.value.isOnlineMatchVisible) return
        mutableState.update { it.copy(selectedMode = mode) }
        if (mode == SwitchMode.ONLINE) enterOnlineRoom()
    }

    fun returnToModeSelection() {
        if (state.value.isDemoVisible) return
        leaveOnlineRoom()
        mutableState.update { it.copy(selectedMode = null) }
    }

    /** The demo robot and the online request (first claim wins). A ready online player's color is locked. */
    fun selectColor(color: SwitchColor) {
        if (color == state.value.color) return
        if (state.value.selectedMode == SwitchMode.ONLINE && mutableOnline.value?.room?.value?.colors?.isLocked == true) return
        settings.color = color.raw
        mutableState.update { it.copy(color = color) }
        mutableOnline.value?.selectColor(color)
    }

    fun selectBotCount(count: Int) {
        mutableState.update { it.copy(botCount = count.coerceIn(it.botRange)) }
    }

    /** Flip and portal sounds only. */
    fun toggleSound() {
        audio.setEffectsEnabled(!audio.isEffectsEnabled)
        mutableState.update { it.copy(isSoundEnabled = audio.isEffectsEnabled) }
    }

    /** Music only. */
    fun toggleMusic() {
        audio.setMusicEnabled(!audio.isMusicEnabled)
        mutableState.update { it.copy(isMusicEnabled = audio.isMusicEnabled) }
    }

    /** The app left or returned to the foreground; a paused demo stays silent until resumed. */
    fun setForeground(foreground: Boolean) {
        if (foreground) {
            if (!state.value.isPaused) audio.setMusicPaused(false)
        } else {
            audio.setMusicPaused(true)
        }
        lastFrameNanos = null
        isForeground = foreground
        mutableOnline.value?.intent("setForeground", mapOf("foreground" to foreground))
    }

    /** The playfield's size in dp; Core's camera fits the course to it. */
    fun setViewport(width: Double, height: Double) {
        if (width <= 0 || height <= 0 || viewport == width to height) return
        viewport = width to height
        engine?.let { apply(it.viewport(width, height)) }
        mutableOnline.value?.viewport(width, height)
    }

    // Demo

    fun startDemo() {
        val race = engine ?: makeEngine().also { engine = it }
        viewport?.let { (width, height) -> race.viewport(width, height) }
        val current = state.value
        lastFrameNanos = null
        mutableState.update {
            it.copy(isPaused = false, showsDemoResult = false, isWatchingDemo = false, isDemoVisible = true)
        }
        apply(race.start(current.color, current.botCount))
        audio.startMusic()
    }

    /** A new race with the same picks. */
    fun restartDemo() = startDemo()

    fun pauseDemo() {
        val current = state.value
        if (!current.isDemoVisible || current.isPaused || current.showsDemoResult) return
        if (mutableMatch.value?.phase == SwitchPhase.ENDED) return
        val race = engine ?: return
        apply(race.pause())
        mutableState.update { it.copy(isPaused = true) }
        audio.setMusicPaused(true)
    }

    fun resumeDemo() {
        if (!state.value.isPaused) return
        val race = engine ?: return
        lastFrameNanos = null
        apply(race.resume())
        mutableState.update { it.copy(isPaused = false) }
        audio.setMusicPaused(false)
    }

    /** Hides the result panel and keeps the camera on the bots until the race ends. */
    fun watchDemo() {
        if (!state.value.showsDemoResult || mutableMatch.value?.phase == SwitchPhase.ENDED) return
        lastFrameNanos = null
        mutableState.update { it.copy(showsDemoResult = false, isWatchingDemo = true) }
    }

    fun exitDemo() {
        engine?.close()
        engine = null
        lastFrameNanos = null
        mutableFrame.value = null
        mutableMatch.value = null
        val wasVisible = state.value.isDemoVisible
        mutableState.update {
            it.copy(isDemoVisible = false, isPaused = false, showsDemoResult = false, isWatchingDemo = false)
        }
        if (wasVisible) audio.stopMusic()
    }

    /** The single input: flip from a surface. Mid-air taps give a soft "no". */
    fun flip() {
        if (state.value.isOnlineMatchVisible) {
            val feedback = mutableOnline.value?.flip() ?: return
            playFlipFeedback(feedback)
            // The flip goes to the rail opposite the one last drawn (no extra presentation).
            if (feedback == SwitchFlip.FLIPPED) {
                mutableFrame.value?.runners?.firstOrNull { it.isLocal }?.gravity?.let { audio.playFlip(it.opposite) }
            }
            return
        }
        val current = state.value
        if (!current.isDemoVisible || current.isPaused) return
        val race = engine ?: return
        val update = race.flip()
        apply(update)
        if (update.flip == SwitchFlip.FLIPPED) update.gravity?.let(audio::playFlip)
        update.flip?.let(::playFlipFeedback)
    }

    private fun playFlipFeedback(feedback: SwitchFlip) {
        when (feedback) {
            SwitchFlip.FLIPPED -> mutableHaptics.tryEmit(SwitchHaptic.LIGHT)
            SwitchFlip.UNSUPPORTED -> mutableHaptics.tryEmit(SwitchHaptic.RIGID)
            SwitchFlip.IGNORED -> Unit
        }
    }

    /** One step per display frame; the delta is clamped so a stall never jumps the race. */
    fun onFrame(frameNanos: Long) {
        if (state.value.isOnlineMatchVisible) return onOnlineFrame()
        val current = state.value
        if (!current.isDemoVisible || current.isPaused) {
            lastFrameNanos = null
            return
        }
        val race = engine ?: return
        val delta = lastFrameNanos?.let { ((frameNanos - it) / 1_000_000_000.0).coerceIn(0.0, 1.0 / 20.0) } ?: 0.0
        lastFrameNanos = frameNanos
        val update = race.step(delta)
        apply(update)
        handleEvents(update)
        audio.setMusicDucked(state.value.showsDemoResult)
    }

    private fun handleEvents(update: SwitchUpdate) {
        for (event in update.events) {
            when (event.type) {
                SwitchEventType.COUNTDOWN -> mutableHaptics.tryEmit(SwitchHaptic.SOFT)
                SwitchEventType.STARTED, SwitchEventType.HUMAN_BOOSTED -> mutableHaptics.tryEmit(SwitchHaptic.MEDIUM)
                SwitchEventType.HUMAN_SLOWED -> mutableHaptics.tryEmit(SwitchHaptic.SOFT)
                SwitchEventType.HUMAN_TELEPORTED -> {
                    audio.playPortal()
                    mutableHaptics.tryEmit(SwitchHaptic.WARNING)
                }
                SwitchEventType.HUMAN_CRASHED -> {
                    mutableHaptics.tryEmit(SwitchHaptic.ERROR)
                    mutableState.update { it.copy(showsDemoResult = true) }
                }
                SwitchEventType.HUMAN_FINISHED -> {
                    mutableHaptics.tryEmit(SwitchHaptic.SUCCESS)
                    update.match?.localTime?.let(::recordBestTime)
                    mutableState.update { it.copy(showsDemoResult = true) }
                }
                SwitchEventType.ENDED -> mutableState.update { it.copy(isWatchingDemo = false, showsDemoResult = true) }
            }
        }
    }

    private fun recordBestTime(time: Double) {
        val best = state.value.bestTime
        if (time <= 0 || (best != null && time >= best)) return
        settings.bestTime = time
        mutableState.update { it.copy(bestTime = time) }
    }

    private fun apply(update: SwitchUpdate) {
        update.world?.let { mutableFrame.value = it }
        update.match?.let { mutableMatch.value = it }
    }

    // Online room

    fun setOnlineReady(ready: Boolean) = mutableOnline.value?.intent("setReady", mapOf("ready" to ready))
    fun cancelOnlineMatch() = mutableOnline.value?.intent("cancel")
    fun retryOnline() = mutableOnline.value?.intent("retry")
    fun reclaimOnlineControl() = mutableOnline.value?.intent("reclaim")
    fun retryOnlineResult() = mutableOnline.value?.intent("retryResult")

    /** The race takes control only in landscape (shared control rule). */
    fun setOnlineLandscape(landscape: Boolean) {
        if (isLandscape == landscape) return
        isLandscape = landscape
        mutableOnline.value?.intent("setLandscape", mapOf("landscape" to landscape))
    }

    fun setReduceMotion(enabled: Boolean) {
        if (reduceMotion == enabled) return
        reduceMotion = enabled
        mutableOnline.value?.setReduceMotion(enabled)
    }

    /** The server no longer accepts this sign-in (HTTP 401). */
    fun requiresOnlineSignIn(): Boolean {
        val session = mutableOnline.value ?: return false
        return session.lobby.value.requiresAuthentication ||
            mutableOnlineMatch.value?.result?.let { it.isFailed && it.detailKey == SIGN_IN_KEY } == true
    }

    /**
     * A new session that excludes the finished one, joined from the result panel; the
     * screen returns to the portrait room until the new race's first snapshot.
     */
    fun rematchOnline() {
        val old = mutableOnline.value ?: return
        val result = mutableOnlineMatch.value?.result ?: return
        if (!result.canRematch) return
        val excluded = old.rematchExcludedSessionId ?: result.sessionId ?: return
        lobbyJob?.cancel()
        lobbyJob = null
        mutableOnline.value = null
        old.dispose()
        clearOnlineRace()
        mutableState.update { it.copy(isOnlineMatchVisible = false, isOnlineRematchRoom = true) }
        openOnlineSession(excludingSessionId = excluded)
    }

    /**
     * Play Again from the result panel: the room's next session, joined and readied (after
     * the color) without leaving the arena; the race starts in place from its countdown.
     */
    fun playOnlineAgain() {
        val old = mutableOnline.value ?: return
        val result = mutableOnlineMatch.value?.result ?: return
        if (!result.canRematch) return
        val excluded = old.rematchExcludedSessionId ?: result.sessionId ?: return
        lobbyJob?.cancel()
        lobbyJob = null
        mutableOnline.value = null
        old.dispose()
        audio.stopMusic()
        mutableState.update { it.copy(isOnlineReplayRoom = true, isOnlineRematchRoom = false) }
        openOnlineSession(excludingSessionId = excluded)
        mutableOnline.value?.intent("readyOnJoin")
    }

    /** Back to Lobby: the portrait online room, in the next session (or the one being joined). */
    fun returnToOnlineLobby() {
        if (!state.value.isOnlineReplayRoom) return rematchOnline()
        clearOnlineRace()
        mutableState.update {
            it.copy(isOnlineMatchVisible = false, isOnlineReplayRoom = false, isOnlineRematchRoom = true)
        }
    }

    /** The explicit, permanent leave from a running race; the screen returns to the modes. */
    fun leaveOnlineMatch() {
        leaveOnlineRoom()
        mutableState.update { it.copy(selectedMode = null) }
    }

    /** One engine presentation per rendered frame: the race, the local robot's portal throw and the overlays. */
    private fun onOnlineFrame() {
        val drawn = mutableOnline.value?.frame() ?: return
        drawn.world?.let { mutableFrame.value = it }
        if (drawn.events.any { it.type == SwitchEventType.HUMAN_TELEPORTED }) {
            audio.playPortal()
            mutableHaptics.tryEmit(SwitchHaptic.WARNING)
        }
        if (mutableOnlineMatch.value != drawn.match) mutableOnlineMatch.value = drawn.match
        if (mutableMatch.value != drawn.match.ui) mutableMatch.value = drawn.match.ui
        audio.setMusicDucked(drawn.match.ui.showsResult || drawn.match.ui.noticeTitleKey != null)
    }

    /** Reads the catalog, then opens the room unless the house has Faus Switch closed. */
    private fun enterOnlineRoom() {
        val deps = online ?: return
        val current = mutableState.value
        val houseId = current.houseId?.takeIf(String::isNotEmpty) ?: return
        if (current.userId.isNullOrEmpty() || mutableOnline.value != null) return
        catalogJob?.cancel()
        catalogJob = viewModelScope.launch {
            val availability = catalogAvailability(deps, houseId)
            if (availability != null && mutableState.value.houseId == houseId) {
                mutableState.update { it.copy(catalogAvailable = availability) }
            }
            if (availability == false || mutableState.value.selectedMode != SwitchMode.ONLINE) return@launch
            openOnlineSession(excludingSessionId = null)
        }
    }

    private fun openOnlineSession(excludingSessionId: String?) {
        val deps = online ?: return
        val current = mutableState.value
        val houseId = current.houseId?.takeIf(String::isNotEmpty) ?: return
        val userId = current.userId?.takeIf(String::isNotEmpty) ?: return
        if (mutableOnline.value != null) return
        val session = FausSwitchOnlineSession(
            scope = viewModelScope,
            engine = deps.makeEngine(houseId, userId, current.houseOwnerId.orEmpty(), excludingSessionId, current.color),
            http = deps.http, token = deps.token, sockets = deps.sockets,
            onHaptic = { mutableHaptics.tryEmit(if (it) SwitchHaptic.SUCCESS else SwitchHaptic.WARNING) },
            clock = deps.clock,
        )
        mutableOnline.value = session
        viewport?.let { (width, height) -> session.viewport(width, height) }
        if (reduceMotion) session.setReduceMotion(true)
        lobbyJob = viewModelScope.launch {
            session.lobby.collect { lobby ->
                if (!lobby.hasGame) return@collect
                if (mutableState.value.isOnlineReplayRoom) {
                    clearOnlineRace()
                    mutableState.update { it.copy(isOnlineReplayRoom = false, isOnlineRematchRoom = false) }
                    audio.startMusic()
                } else if (!mutableState.value.isOnlineMatchVisible) {
                    clearOnlineRace()
                    mutableState.update { it.copy(isOnlineMatchVisible = true, isOnlineRematchRoom = false) }
                    audio.startMusic()
                } else if (mutableState.value.isOnlineRematchRoom) {
                    mutableState.update { it.copy(isOnlineRematchRoom = false) }
                }
            }
        }
        session.start(isForeground, isLandscape = isLandscape)
    }

    /** A failed read keeps the last answer (`null`): the session request is still guarded by the server. */
    private suspend fun catalogAvailability(deps: FausSwitchOnlineDependencies, houseId: String): Boolean? {
        val token = deps.token() ?: return null
        return try {
            val response = deps.http(PlatformHttpRequest(path = "game/catalog", method = "GET",
                queryItems = listOf(PlatformHttpQueryItem("houseId", houseId)),
                headers = mapOf("Authorization" to "Bearer $token", "Accept" to "application/json")))
            deps.catalogAvailability(houseId, response.statusCode, response.body.decodeToString())
        } catch (cancel: CancellationException) {
            throw cancel
        } catch (_: Exception) {
            null
        }
    }

    private fun clearOnlineRace() {
        val wasVisible = state.value.isOnlineMatchVisible
        mutableOnlineMatch.value = null
        if (!state.value.isDemoVisible) {
            mutableFrame.value = null
            mutableMatch.value = null
            if (wasVisible) audio.stopMusic()
        }
    }

    /**
     * A business leave, then cleanup: the session stays alive until the server confirms or
     * the engine's own limit closes it, so the seat is freed for the others.
     */
    private fun leaveOnlineRoom() {
        catalogJob?.cancel()
        catalogJob = null
        lobbyJob?.cancel()
        lobbyJob = null
        val finished = mutableOnlineMatch.value?.result?.canRematch == true
        clearOnlineRace()
        mutableState.update {
            it.copy(isOnlineMatchVisible = false, isOnlineRematchRoom = false, isOnlineReplayRoom = false)
        }
        val session = mutableOnline.value ?: return
        mutableOnline.value = null
        // A finished race (result final) has nothing to leave: its socket is already done.
        if (session.closed.value || finished) return session.dispose()
        session.intent("leave")
        viewModelScope.launch {
            var waited = 0L
            while (!session.closed.value && waited < LEAVE_TIMEOUT_MILLIS) {
                delay(50)
                waited += 50
            }
            session.dispose()
        }
    }

    fun stop() {
        exitDemo()
        leaveOnlineRoom()
    }

    override fun onCleared() {
        val session = mutableOnline.value
        stop()
        // viewModelScope is gone: no confirmation will arrive, so close the room now.
        session?.dispose()
        audio.release()
    }

    private companion object {
        const val SIGN_IN_KEY = "faus_switch_online_sign_in"
        const val LEAVE_TIMEOUT_MILLIS = 3_000L
    }
}

internal class FausSwitchViewModelFactory(context: Context) : ViewModelProvider.Factory {
    private val appContext = context.applicationContext

    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        val settings = SharedPreferencesSwitchSettings(appContext)
        val constants = FausSwitchNative.constants
        val http = AndroidHttpAdapter.live()
        val store = KeystoreSessionStore(appContext)
        return FausSwitchViewModel(
            makeEngine = FausSwitchNative::engine,
            settings = settings,
            audio = FausSwitchAudio(appContext, settings),
            botRange = constants.botRange,
            defaultBots = constants.defaultBots,
            online = FausSwitchOnlineDependencies(
                makeEngine = FausSwitchOnlineNative::engine,
                http = http::send,
                token = {
                    withContext(Dispatchers.IO) { (store.read(SessionField.AUTH_TOKEN) as? SessionReadResult.Value)?.value }
                },
                sockets = OkHttpRealtimeSocketFactory(),
                catalogAvailability = FausSwitchOnlineNative::catalogAvailability,
            ),
        ) as T
    }
}
