package com.fauscrew.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fauscrew.platform.AndroidHttpAdapter
import com.fauscrew.platform.HouseTanksEngine
import com.fauscrew.platform.HouseTanksNative
import com.fauscrew.platform.HouseTanksOnlineNative
import com.fauscrew.platform.KeystoreSessionStore
import com.fauscrew.platform.OkHttpRealtimeSocketFactory
import com.fauscrew.platform.PlatformHttpQueryItem
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.RealtimeSocketFactory
import com.fauscrew.platform.SessionField
import com.fauscrew.platform.SessionReadResult
import com.fauscrew.platform.TanksColor
import com.fauscrew.platform.TanksDifficulty
import com.fauscrew.platform.TanksEvent
import com.fauscrew.platform.TanksFrame
import com.fauscrew.platform.TanksMap
import com.fauscrew.platform.TanksOnlineEngine
import com.fauscrew.platform.TanksOnlineMatch
import com.fauscrew.platform.TanksPhase
import com.fauscrew.platform.TanksUpdate
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

/** `HouseTanksMode`. */
internal enum class TanksMode { DEMO, ONLINE }

/** `HouseTanksSetupStep`: the demo picks the player must make; nothing is preselected. */
internal enum class TanksSetupStep { MAP, COLOR, DIFFICULTY }

internal enum class TanksHaptic { HIT, ROUND_END, WIN, LOSS }

/** `HouseTanksMapDefinition.demoStandardPlayerCount`: the human and three bots. */
internal const val DEMO_TANKS = 4

/** Platform I/O for the online room; the rules live in FausCrewCore's online engine. */
internal class HouseTanksOnlineDependencies(
    val makeEngine: (houseId: String, userId: String, houseOwnerId: String, excludingSessionId: String?) -> TanksOnlineEngine,
    val http: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    val token: suspend () -> String?,
    val sockets: RealtimeSocketFactory,
    val catalogAvailability: (houseId: String, status: Int, body: String) -> Boolean?,
)

internal data class HouseTanksUiState(
    val selectedMode: TanksMode? = null,
    val map: TanksMap? = null,
    val color: TanksColor? = null,
    val difficulty: TanksDifficulty? = null,
    /** The server's draw, known from the match countdown on. */
    val onlineMap: TanksMap? = null,
    val houseId: String? = null,
    val userId: String? = null,
    val houseOwnerId: String? = null,
    /** Server catalog: `false` when FauseTanks is closed for this house; `null` = unknown. */
    val catalogAvailable: Boolean? = null,
    /** This build can open rooms (the live dependencies are present). */
    val onlineServiceAvailable: Boolean = false,
    /** From the first round countdown of an online match until the player leaves it. */
    val isOnlineMatchVisible: Boolean = false,
    /** A rematch's new session before its first snapshot: the room is drawn on the match screen. */
    val isOnlineRematchRoom: Boolean = false,
) {
    /** The picks this setup asks for; a demo match is always [DEMO_TANKS] tanks. */
    val setupSteps: List<TanksSetupStep> get() = TanksSetupStep.entries

    /** The arena the next match uses: the player's pick in demo, the drawn one online. */
    val matchMap: TanksMap? get() = if (selectedMode == TanksMode.ONLINE) onlineMap else map

    /** The first pick still missing, in the order the setup screen asks for them. */
    val pendingSetupStep: TanksSetupStep? get() = setupSteps.firstOrNull { !isComplete(it) }

    val completedSetupSteps: Int get() = setupSteps.count(::isComplete)

    fun isComplete(step: TanksSetupStep): Boolean = when (step) {
        TanksSetupStep.MAP -> matchMap != null
        TanksSetupStep.COLOR -> color != null
        TanksSetupStep.DIFFICULTY -> difficulty != null
    }
}

/**
 * `HouseTanksViewModel` plus the iOS demo session's scheduling. The rules, physics and bots
 * run in FausCrewCore; this type drives them — a countdown timer and one engine step per
 * rendered frame — and turns armor and phase changes into haptics. The screen owns orientation.
 */
internal class HouseTanksViewModel(
    private val makeEngine: () -> HouseTanksEngine = HouseTanksNative::engine,
    private val countdownStepMillis: () -> Long = { HouseTanksNative.countdownStepMillis },
    private val online: HouseTanksOnlineDependencies? = null,
) : ViewModel() {
    private val mutableState = MutableStateFlow(HouseTanksUiState(onlineServiceAvailable = online != null))
    val state: StateFlow<HouseTanksUiState> = mutableState.asStateFlow()

    /** Changes every rendered frame; the renderer reads it in the draw phase only. */
    private val mutableFrame = MutableStateFlow<TanksFrame?>(null)
    val frame: StateFlow<TanksFrame?> = mutableFrame.asStateFlow()

    private val mutableHaptics = MutableSharedFlow<TanksHaptic>(extraBufferCapacity = 4)
    val haptics: SharedFlow<TanksHaptic> = mutableHaptics.asSharedFlow()

    /** Hull flashes for armor lost since the previous frame (the iOS hit flash). */
    private val mutableHits = MutableSharedFlow<String>(extraBufferCapacity = 8)
    val hits: SharedFlow<String> = mutableHits.asSharedFlow()

    private var engine: HouseTanksEngine? = null
    private var countdownJob: Job? = null
    private var lastFrameNanos: Long? = null
    private var isPressing = false
    private var catalogJob: Job? = null
    private var previewJob: Job? = null
    private var isForeground = true

    /** The online arena, refreshed every rendered frame; the renderer reads it in the draw phase. */
    private val mutableOnlineFrame = MutableStateFlow<TanksFrame?>(null)
    val onlineFrame: StateFlow<TanksFrame?> = mutableOnlineFrame.asStateFlow()
    /** The bars and banners over the online arena; equal values do not recompose. */
    private val mutableOnlineMatch = MutableStateFlow<TanksOnlineMatch?>(null)
    val onlineMatch: StateFlow<TanksOnlineMatch?> = mutableOnlineMatch.asStateFlow()

    /** The HUD's frame rate: presentations drawn in the last second, refreshed twice a second. */
    private val mutableOnlineFps = MutableStateFlow<Int?>(null)
    val onlineFps: StateFlow<Int?> = mutableOnlineFps.asStateFlow()
    private var lastFpsNanos = 0L
    private var lobbyJob: Job? = null
    private var isLandscape = false

    private val mutableOnline = MutableStateFlow<HouseTanksOnlineSession?>(null)
    /** The current online room, or null. */
    val onlineSession: StateFlow<HouseTanksOnlineSession?> = mutableOnline.asStateFlow()

    /** The signed-in player and their house; a change closes the room it belonged to. */
    fun updateContext(houseId: String?, userId: String?, houseOwnerId: String? = null) {
        val current = mutableState.value
        if (current.houseId == houseId && current.userId == userId && current.houseOwnerId == houseOwnerId) return
        // A new owner only changes who may cancel a lobby; it never takes a running match away.
        if (current.houseId == houseId && current.userId == userId && current.isOnlineMatchVisible) {
            mutableState.update { it.copy(houseOwnerId = houseOwnerId) }
            return
        }
        leaveOnlineRoom()
        mutableState.update {
            it.copy(houseId = houseId, userId = userId, houseOwnerId = houseOwnerId,
                catalogAvailable = if (it.houseId == houseId) it.catalogAvailable else null)
        }
        if (current.selectedMode == TanksMode.ONLINE) enterOnlineRoom()
    }

    fun selectMode(mode: TanksMode) {
        if (mutableFrame.value != null) return
        mutableState.update { it.copy(selectedMode = mode, onlineMap = null) }
        if (mode == TanksMode.ONLINE) enterOnlineRoom()
    }

    fun returnToModeSelection() {
        if (mutableFrame.value != null) return
        leaveOnlineRoom()
        mutableState.update { it.copy(selectedMode = null, onlineMap = null) }
    }

    // ---- Online room ---------------------------------------------------------------------

    fun setOnlineReady(ready: Boolean) = mutableOnline.value?.intent("setReady", mapOf("ready" to ready))
    fun cancelOnlineMatch() = mutableOnline.value?.intent("cancel")
    fun retryOnline() = mutableOnline.value?.intent("retry")

    // ---- Online match ----------------------------------------------------------------------

    fun onlinePress() = mutableOnline.value?.press()
    fun onlineRelease() = mutableOnline.value?.release()
    fun reclaimOnlineControl() = mutableOnline.value?.intent("reclaim")
    fun setOnlineReduceMotion(enabled: Boolean) = mutableOnline.value?.intent("setReduceMotion", mapOf("enabled" to enabled))

    /** The vote for the next round from the in-game panel. */
    fun setOnlineRoundReady(ready: Boolean) = mutableOnline.value?.setRoundReady(ready)
    fun retryOnlineResult() = mutableOnline.value?.intent("retryResult")

    /**
     * A new session that excludes the finished one, joined from the result panel; the match
     * screen stays and shows the new room until its first snapshot.
     */
    fun rematchOnline() {
        val old = mutableOnline.value ?: return
        val result = mutableOnlineMatch.value?.result ?: return
        if (!result.canRematch) return
        val excluded = old.rematchExcludedSessionId ?: result.sessionId ?: return
        previewJob?.cancel()
        lobbyJob?.cancel()
        mutableOnline.value = null
        old.dispose()
        mutableOnlineFrame.value = null
        mutableOnlineMatch.value = null
        mutableOnlineFps.value = null
        mutableState.update { it.copy(isOnlineRematchRoom = true, onlineMap = null) }
        openOnlineSession(excludingSessionId = excluded)
    }

    /** The button opens only in landscape (shared control rule). */
    fun setOnlineLandscape(landscape: Boolean) {
        if (isLandscape == landscape) return
        isLandscape = landscape
        mutableOnline.value?.intent("setLandscape", mapOf("landscape" to landscape))
    }

    /** One engine presentation per rendered frame: the arena, server hits and the bars. */
    fun onOnlineFrame() {
        val session = mutableOnline.value ?: return
        val drawn = session.frame() ?: return
        drawn.fps?.let { fps ->
            val nanos = System.nanoTime()
            if (nanos - lastFpsNanos >= 500_000_000L) {
                lastFpsNanos = nanos
                mutableOnlineFps.value = fps
            }
        }
        drawn.frame?.let { frame ->
            mutableOnlineFrame.value = frame
            val local = frame.human?.id
            frame.events.filterIsInstance<TanksEvent.Hit>().forEach { hit ->
                if (hit.playerId == local) mutableHaptics.tryEmit(TanksHaptic.HIT)
            }
        }
        if (mutableOnlineMatch.value != drawn.match) mutableOnlineMatch.value = drawn.match
    }

    /** The explicit, permanent leave from a running match; the screen returns to the modes. */
    fun leaveOnlineMatch() {
        leaveOnlineRoom()
        mutableState.update { it.copy(selectedMode = null, onlineMap = null) }
    }

    fun setForeground(active: Boolean) {
        isForeground = active
        mutableOnline.value?.intent("setForeground", mapOf("foreground" to active))
    }

    /** Reads the catalog, then opens the room unless the house has FauseTanks closed. */
    private fun enterOnlineRoom() {
        val deps = online ?: return
        val current = mutableState.value
        val houseId = current.houseId?.takeIf(String::isNotEmpty) ?: return
        val userId = current.userId?.takeIf(String::isNotEmpty) ?: return
        if (mutableOnline.value != null) return
        catalogJob?.cancel()
        catalogJob = viewModelScope.launch {
            val availability = catalogAvailability(deps, houseId)
            if (availability != null && mutableState.value.houseId == houseId) {
                mutableState.update { it.copy(catalogAvailable = availability) }
            }
            if (availability == false || mutableState.value.selectedMode != TanksMode.ONLINE) return@launch
            openOnlineSession(excludingSessionId = null)
        }
    }

    private fun openOnlineSession(excludingSessionId: String?) {
        val deps = online ?: return
        val current = mutableState.value
        val houseId = current.houseId?.takeIf(String::isNotEmpty) ?: return
        val userId = current.userId?.takeIf(String::isNotEmpty) ?: return
        val session = HouseTanksOnlineSession(
            scope = viewModelScope,
            engine = deps.makeEngine(houseId, userId, current.houseOwnerId.orEmpty(), excludingSessionId),
            http = deps.http, token = deps.token, sockets = deps.sockets,
            onHaptic = { mutableHaptics.tryEmit(if (it) TanksHaptic.WIN else TanksHaptic.LOSS) },
        )
        mutableOnline.value = session
        previewJob = viewModelScope.launch {
            session.preview.collect { preview -> mutableState.update { it.copy(onlineMap = preview?.map) } }
        }
        lobbyJob = viewModelScope.launch {
            session.lobby.collect { lobby ->
                val started = lobby.gamePhase != null && lobby.gamePhase != "countdown"
                if (started && !mutableState.value.isOnlineMatchVisible) {
                    mutableState.update { it.copy(isOnlineMatchVisible = true) }
                }
                if (lobby.gamePhase != null && mutableState.value.isOnlineRematchRoom) {
                    mutableState.update { it.copy(isOnlineRematchRoom = false) }
                }
            }
        }
        session.start(isForeground, isLandscape = isLandscape)
    }

    /** A failed read keeps the last answer (`null`): the session request is still guarded by the server. */
    private suspend fun catalogAvailability(deps: HouseTanksOnlineDependencies, houseId: String): Boolean? {
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

    /**
     * A business leave, then cleanup: the session stays alive until the server confirms or
     * the engine's own limit closes it, so the seat is freed for the others.
     */
    private fun leaveOnlineRoom() {
        catalogJob?.cancel()
        catalogJob = null
        previewJob?.cancel()
        previewJob = null
        lobbyJob?.cancel()
        lobbyJob = null
        val finished = mutableOnlineMatch.value?.result?.canRematch == true
        mutableOnlineFrame.value = null
        mutableOnlineMatch.value = null
        mutableOnlineFps.value = null
        mutableState.update { it.copy(isOnlineMatchVisible = false, isOnlineRematchRoom = false) }
        val session = mutableOnline.value ?: return
        mutableOnline.value = null
        mutableState.update { it.copy(onlineMap = null) }
        // A finished match (result final) has nothing to leave: its socket is already done.
        if (session.closed.value || finished) return session.dispose()
        session.intent("leave")
        viewModelScope.launch {
            val deadline = 3_000L
            var waited = 0L
            while (!session.closed.value && waited < deadline) {
                delay(50)
                waited += 50
            }
            session.dispose()
        }
    }

    fun selectMap(map: TanksMap) = mutableState.update { it.copy(map = map) }
    fun selectColor(color: TanksColor) = mutableState.update { it.copy(color = color) }
    fun selectDifficulty(difficulty: TanksDifficulty) = mutableState.update { it.copy(difficulty = difficulty) }

    /** Starts a demo match once every pick is made. */
    fun startMatch() {
        val current = mutableState.value
        if (current.pendingSetupStep != null) return
        val map = current.matchMap ?: return
        val color = current.color ?: return
        val difficulty = current.difficulty ?: return
        val engine = engine ?: makeEngine().also { engine = it }
        isPressing = false
        lastFrameNanos = null
        apply(engine.start(difficulty, color, map, DEMO_TANKS))
        beginCountdown()
    }

    /** One engine step per display frame while playing. */
    fun onFrame(frameNanos: Long) {
        val engine = engine ?: return
        val previous = lastFrameNanos
        lastFrameNanos = frameNanos
        if (mutableFrame.value?.phase != TanksPhase.PLAYING || previous == null) return
        val delta = ((frameNanos - previous) / 1_000_000_000.0).coerceIn(0.0, 1.0 / 20.0)
        if (delta > 0) apply(engine.step(delta))
    }

    fun beginPress() {
        val engine = engine ?: return
        if (isPressing || mutableFrame.value?.phase != TanksPhase.PLAYING) return
        isPressing = true
        apply(engine.press(true))
    }

    fun endPress() {
        if (!isPressing) return
        isPressing = false
        engine?.let { apply(it.press(false)) }
    }

    /** TalkBack's activation: a short press that fires and advances briefly. */
    fun performAccessiblePress() {
        beginPress()
        viewModelScope.launch {
            delay(420)
            endPress()
        }
    }

    fun pause() {
        endPress()
        val engine = engine ?: return
        val update = engine.pause()
        apply(update)
        lastFrameNanos = null
    }

    fun resume() {
        val engine = engine ?: return
        lastFrameNanos = null
        apply(engine.resume())
    }

    fun nextRound() {
        val engine = engine ?: return
        isPressing = false
        val update = engine.nextRound()
        apply(update)
        if (update.changed) beginCountdown()
    }

    fun restartMatch() {
        val engine = engine ?: return
        isPressing = false
        val update = engine.restart()
        apply(update)
        if (update.changed) beginCountdown()
    }

    /** Ends the match and reopens the demo setup with the same map, color and difficulty. */
    fun returnToDemoSetup() {
        stop()
        mutableState.update { it.copy(selectedMode = TanksMode.DEMO, onlineMap = null) }
    }

    fun stop() {
        leaveOnlineRoom()
        countdownJob?.cancel()
        countdownJob = null
        isPressing = false
        lastFrameNanos = null
        engine?.close()
        engine = null
        mutableFrame.value = null
    }

    override fun onCleared() {
        val session = mutableOnline.value
        stop()
        // viewModelScope is gone: no confirmation will arrive, so close the room now.
        session?.dispose()
    }

    private fun beginCountdown() {
        countdownJob?.cancel()
        countdownJob = viewModelScope.launch {
            while (mutableFrame.value?.phase == TanksPhase.COUNTDOWN) {
                delay(countdownStepMillis())
                val engine = engine ?: return@launch
                val update = engine.countdown()
                apply(update)
                if (update.started) {
                    lastFrameNanos = null
                    return@launch
                }
            }
        }
    }

    private fun apply(update: TanksUpdate) {
        val incoming = update.frame ?: return
        val previous = mutableFrame.value
        mutableFrame.value = incoming
        if (previous == null || previous.matchId != incoming.matchId) return
        val human = incoming.human
        val oldHuman = previous.human
        incoming.players.forEach { player ->
            val old = previous.players.firstOrNull { it.id == player.id } ?: return@forEach
            if (player.armor < old.armor && player.isAlive) mutableHits.tryEmit(player.id)
        }
        if (human != null && oldHuman != null && human.armor < oldHuman.armor) mutableHaptics.tryEmit(TanksHaptic.HIT)
        if (previous.phase != incoming.phase) {
            when (incoming.phase) {
                TanksPhase.ROUND_ENDED -> mutableHaptics.tryEmit(TanksHaptic.ROUND_END)
                TanksPhase.MATCH_ENDED -> mutableHaptics.tryEmit(
                    if (incoming.championId == human?.id) TanksHaptic.WIN else TanksHaptic.LOSS,
                )
                else -> Unit
            }
        }
    }
}

internal class HouseTanksViewModelFactory(context: Context) : ViewModelProvider.Factory {
    private val appContext = context.applicationContext

    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        val http = AndroidHttpAdapter.live()
        val store = KeystoreSessionStore(appContext)
        return HouseTanksViewModel(online = HouseTanksOnlineDependencies(
            makeEngine = HouseTanksOnlineNative::engine,
            http = http::send,
            token = {
                withContext(Dispatchers.IO) { (store.read(SessionField.AUTH_TOKEN) as? SessionReadResult.Value)?.value }
            },
            sockets = OkHttpRealtimeSocketFactory(),
            catalogAvailability = HouseTanksOnlineNative::catalogAvailability,
        )) as T
    }
}
