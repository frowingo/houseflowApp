package com.fauscrew.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fauscrew.platform.AndroidHttpAdapter
import com.fauscrew.platform.HouseRocketsEngine
import com.fauscrew.platform.HouseRocketsNative
import com.fauscrew.platform.HouseRocketsOnlineEngine
import com.fauscrew.platform.HouseRocketsOnlineNative
import com.fauscrew.platform.KeystoreSessionStore
import com.fauscrew.platform.OkHttpRealtimeSocketFactory
import com.fauscrew.platform.PlatformHttpQueryItem
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.RealtimeSocketFactory
import com.fauscrew.platform.SessionField
import com.fauscrew.platform.SessionReadResult
import com.fauscrew.platform.RocketsFrame
import com.fauscrew.platform.RocketsPhase
import com.fauscrew.platform.RocketsUpdate
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
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
import kotlinx.coroutines.isActive
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

/** `HouseRocketsMode`. */
internal enum class RocketsMode { LOCAL_BOTS, HOUSEMATES }

/** iOS `HouseRocketsOnlineBlocker`. */
internal enum class RocketsOnlineBlocker { SIGN_IN_REQUIRED, HOUSE_REQUIRED, SERVICE_UNAVAILABLE, GAME_UNAVAILABLE }

/** Platform I/O for online play; the rules live in FausCrewCore's online engine. */
internal class HouseRocketsOnlineDependencies(
    val makeEngine: (houseId: String, userId: String, houseOwnerId: String, excludingSessionId: String?) -> HouseRocketsOnlineEngine,
    val http: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    val token: suspend () -> String?,
    val sockets: RealtimeSocketFactory,
    val catalogAvailability: (houseId: String, status: Int, body: String) -> Boolean?,
)

internal enum class RocketsHaptic { SUCCESS, WARNING }

internal data class HouseRocketsUiState(
    val selectedMode: RocketsMode? = null,
    val botCount: Int = 3,
    val houseId: String? = null,
    val userId: String? = null,
    val houseOwnerId: String? = null,
    val onlineSupported: Boolean = false,
    /** Server catalog: `false` when House Rockets is closed for this house; `null` = unknown. */
    val catalogAvailable: Boolean? = null,
) {
    /** `null` when housemates mode can connect. An unknown catalog never blocks. */
    val onlineBlocker: RocketsOnlineBlocker?
        get() = when {
            userId.isNullOrEmpty() -> RocketsOnlineBlocker.SIGN_IN_REQUIRED
            houseId.isNullOrEmpty() -> RocketsOnlineBlocker.HOUSE_REQUIRED
            !onlineSupported -> RocketsOnlineBlocker.SERVICE_UNAVAILABLE
            catalogAvailable == false -> RocketsOnlineBlocker.GAME_UNAVAILABLE
            else -> null
        }
}

/**
 * `HouseRocketsViewModel` for the local bot match. The rules run in FausCrewCore; this
 * type schedules them: a 0.75 s countdown timer and one physics step per rendered frame,
 * plus iOS's steering de-duplication and haptic cues. The screen owns orientation.
 */
internal class HouseRocketsViewModel(
    private val makeEngine: () -> HouseRocketsEngine = HouseRocketsNative::engine,
    private val countdownStepMillis: () -> Long = { HouseRocketsNative.countdownStepMillis },
    private val online: HouseRocketsOnlineDependencies? = null,
) : ViewModel() {
    private val mutableState = MutableStateFlow(HouseRocketsUiState(onlineSupported = online != null))
    val state: StateFlow<HouseRocketsUiState> = mutableState.asStateFlow()

    /** Changes every rendered frame; the renderer reads it in the draw phase only. */
    private val mutableFrame = MutableStateFlow<RocketsFrame?>(null)
    val frame: StateFlow<RocketsFrame?> = mutableFrame.asStateFlow()

    private val mutableHaptics = MutableSharedFlow<RocketsHaptic>(extraBufferCapacity = 4)
    val haptics: SharedFlow<RocketsHaptic> = mutableHaptics.asSharedFlow()

    private var engine: HouseRocketsEngine? = null
    private var countdownJob: Job? = null
    private var lastFrameNanos: Long? = null
    private var commandSequence = 0
    private var lastHeading: Double? = null
    private var pendingHeading: Double? = null
    private var viewport = FloatArray(4)
    private var isForeground = true
    private var isLandscape = false
    private var catalogJob: Job? = null
    private var closedJob: Job? = null
    private var afterLeave: (() -> Unit)? = null

    private val mutableOnline = MutableStateFlow<HouseRocketsOnlineSession?>(null)
    /** The current online match (housemates mode), or null. */
    val onlineSession: StateFlow<HouseRocketsOnlineSession?> = mutableOnline.asStateFlow()

    fun updateContext(houseId: String?, userId: String?, houseOwnerId: String? = null) {
        val current = mutableState.value
        if (current.houseId == houseId && current.userId == userId && current.houseOwnerId == houseOwnerId) return
        if (current.houseId != null || current.userId != null) returnToModeSelection()
        mutableState.update {
            it.copy(houseId = houseId, userId = userId, houseOwnerId = houseOwnerId,
                catalogAvailable = if (it.houseId == houseId) it.catalogAvailable else null)
        }
        refreshCatalog()
    }

    fun selectMode(mode: RocketsMode) {
        if (mutableFrame.value != null || mutableOnline.value != null) return
        mutableState.update { it.copy(selectedMode = mode) }
        if (mode == RocketsMode.HOUSEMATES) connectOnline(excludingSessionId = null)
    }

    fun returnToModeSelection() {
        stop()
        mutableState.update { it.copy(selectedMode = null) }
    }

    /** Reads the server catalog for the current house; a failed read keeps the last answer. */
    fun refreshCatalog() {
        val deps = online ?: return
        val houseId = mutableState.value.houseId?.takeIf(String::isNotEmpty) ?: return
        catalogJob?.cancel()
        catalogJob = viewModelScope.launch {
            val token = deps.token() ?: return@launch
            val availability = try {
                val response = deps.http(PlatformHttpRequest(path = "game/catalog", method = "GET",
                    queryItems = listOf(PlatformHttpQueryItem("houseId", houseId)),
                    headers = mapOf("Authorization" to "Bearer $token", "Accept" to "application/json")))
                deps.catalogAvailability(houseId, response.statusCode, response.body.decodeToString())
            } catch (cancel: CancellationException) {
                throw cancel
            } catch (_: Exception) {
                null
            } ?: return@launch
            if (mutableState.value.houseId == houseId) mutableState.update { it.copy(catalogAvailable = availability) }
        }
    }

    // ---- Online (housemates) -------------------------------------------------------------

    private fun connectOnline(excludingSessionId: String?) {
        val deps = online ?: return
        val current = mutableState.value
        if (current.onlineBlocker != null) return
        val houseId = current.houseId ?: return
        val userId = current.userId ?: return
        disposeOnline()
        val session = HouseRocketsOnlineSession(
            scope = viewModelScope,
            engine = deps.makeEngine(houseId, userId, current.houseOwnerId.orEmpty(), excludingSessionId),
            http = deps.http, token = deps.token, sockets = deps.sockets,
            onHaptic = { mutableHaptics.tryEmit(if (it) RocketsHaptic.SUCCESS else RocketsHaptic.WARNING) },
        )
        mutableOnline.value = session
        session.viewport(viewport[0], viewport[1], viewport[2], viewport[3])
        session.start(isForeground, isLandscape)
        closedJob = viewModelScope.launch {
            session.closed.collect { closed ->
                if (!closed || mutableOnline.value !== session) return@collect
                disposeOnline()
                mutableState.update { it.copy(selectedMode = null) }
                afterLeave?.also { afterLeave = null }?.invoke()
            }
        }
    }

    fun setOnlineReady(ready: Boolean) = mutableOnline.value?.intent("setReady", mapOf("ready" to ready))
    fun cancelOnlineMatch() = mutableOnline.value?.intent("cancel")
    fun retryOnline() = mutableOnline.value?.intent("retry")
    fun retryOnlineResult() = mutableOnline.value?.intent("retryResult")
    fun reclaimOnlineControl() = mutableOnline.value?.intent("reclaim")

    fun rematchOnline() {
        val session = mutableOnline.value ?: return
        if (!session.result.value.canRematch) return
        connectOnline(excludingSessionId = session.rematchExcludedSessionId ?: session.result.value.sessionId)
    }

    /**
     * Explicit exit: a business leave, then cleanup. [then] runs once the engine has
     * closed (at most two seconds), or at once when no online match is open.
     */
    fun leaveOnline(then: () -> Unit) {
        val session = mutableOnline.value
        if (session == null) {
            then()
            return
        }
        if (session.lobby.value.isLeaving) return
        afterLeave = then
        session.intent("leave")
    }

    fun setLandscape(landscape: Boolean) {
        isLandscape = landscape
        mutableOnline.value?.intent("setLandscape", mapOf("landscape" to landscape))
    }

    fun setForeground(active: Boolean) {
        isForeground = active
        mutableOnline.value?.intent("setForeground", mapOf("foreground" to active))
    }

    fun setReduceMotion(enabled: Boolean) {
        mutableOnline.value?.intent("reduceMotion", mapOf("enabled" to enabled))
    }

    /** One rendered frame of the online flight. */
    fun onOnlineFrame() {
        mutableOnline.value?.sampleFrame()
    }

    private fun disposeOnline() {
        closedJob?.cancel()
        closedJob = null
        mutableOnline.value?.dispose()
        mutableOnline.value = null
    }

    fun setBotCount(count: Int) {
        mutableState.update { it.copy(botCount = count.coerceIn(1, 3)) }
    }

    /** Canvas size and the safe-area HUD size, both in dp. */
    fun setViewport(width: Float, height: Float, hudWidth: Float, hudHeight: Float) {
        val next = floatArrayOf(width, height, hudWidth, hudHeight)
        if (next.contentEquals(viewport)) return
        viewport = next
        engine?.let { apply(it.viewport(width, height, hudWidth, hudHeight)) }
        mutableOnline.value?.viewport(width, height, hudWidth, hudHeight)
    }

    fun startMatch() {
        if (mutableState.value.selectedMode != RocketsMode.LOCAL_BOTS || engine != null) return
        val created = makeEngine()
        engine = created
        commandSequence = 0
        lastHeading = null
        pendingHeading = null
        lastFrameNanos = null
        created.viewport(viewport[0], viewport[1], viewport[2], viewport[3])
        apply(created.start(mutableState.value.botCount))
        runCountdown()
    }

    /** One display frame while playing; the delta is real time, capped inside Core. */
    fun onFrame(frameTimeNanos: Long) {
        val active = engine ?: return
        if (mutableFrame.value?.phase != RocketsPhase.PLAYING) {
            lastFrameNanos = null
            return
        }
        val delta = lastFrameNanos?.let { (frameTimeNanos - it).coerceAtLeast(0L) / 1_000_000_000.0 } ?: 0.0
        lastFrameNanos = frameTimeNanos
        val heading = pendingHeading
        pendingHeading = null
        if (heading != null) commandSequence += 1
        apply(active.step(delta, heading, commandSequence))
        if (mutableFrame.value?.phase != RocketsPhase.PLAYING) lastFrameNanos = null
    }

    fun steer(heading: Double) {
        if (mutableState.value.selectedMode == RocketsMode.HOUSEMATES) {
            mutableOnline.value?.intent("steer", mapOf("heading" to heading))
            return
        }
        val current = mutableFrame.value ?: return
        if (!heading.isFinite() || mutableState.value.selectedMode != RocketsMode.LOCAL_BOTS ||
            current.phase != RocketsPhase.PLAYING || current.human?.isAlive != true) return
        lastHeading?.let { previous ->
            if (abs(atan2(sin(heading - previous), cos(heading - previous))) < 0.01) return
        }
        lastHeading = heading
        pendingHeading = heading
    }

    /** A fresh touch must be able to reapply the same screen direction after a course turn. */
    fun endSteering() {
        lastHeading = null
        mutableOnline.value?.intent("endSteering")
    }

    fun adjustHeading(amount: Double) {
        if (mutableState.value.selectedMode == RocketsMode.HOUSEMATES) {
            mutableOnline.value?.intent("adjust", mapOf("amount" to amount))
            return
        }
        steer((lastHeading ?: mutableFrame.value?.human?.heading ?: 0.0) + amount)
    }

    fun pause() {
        if (mutableState.value.selectedMode != RocketsMode.LOCAL_BOTS) return
        val active = engine ?: return
        endSteering()
        pendingHeading = null
        val update = active.pause()
        if (update.changed) {
            countdownJob?.cancel()
            lastFrameNanos = null
        }
        apply(update)
    }

    fun resume() {
        if (mutableState.value.selectedMode != RocketsMode.LOCAL_BOTS) return
        val active = engine ?: return
        val update = active.resume()
        lastFrameNanos = null
        apply(update)
        if (update.resumed == RocketsPhase.COUNTDOWN) runCountdown()
    }

    fun restart() {
        val active = engine ?: return
        if (mutableFrame.value?.phase != RocketsPhase.ENDED) return
        lastHeading = null
        pendingHeading = null
        val update = active.restart()
        if (!update.changed) return
        lastFrameNanos = null
        apply(update)
        runCountdown()
    }

    fun stop() {
        disposeOnline()
        afterLeave = null
        countdownJob?.cancel()
        countdownJob = null
        engine?.close()
        engine = null
        lastFrameNanos = null
        lastHeading = null
        pendingHeading = null
        mutableFrame.value = null
    }

    override fun onCleared() {
        stop()
    }

    private fun runCountdown() {
        countdownJob?.cancel()
        countdownJob = viewModelScope.launch {
            while (isActive) {
                delay(countdownStepMillis())
                val active = engine ?: return@launch
                if (mutableFrame.value?.phase != RocketsPhase.COUNTDOWN) return@launch
                val update = active.countdown()
                apply(update)
                if (update.started) {
                    lastFrameNanos = null
                    return@launch
                }
            }
        }
    }

    private fun apply(update: RocketsUpdate) {
        val incoming = update.frame ?: return
        val previous = mutableFrame.value
        if (previous != null && previous.matchId == incoming.matchId) {
            if (previous.human?.isAlive == true && incoming.human?.isAlive == false) {
                mutableHaptics.tryEmit(RocketsHaptic.WARNING)
            } else if (previous.phase != RocketsPhase.ENDED && incoming.phase == RocketsPhase.ENDED) {
                mutableHaptics.tryEmit(
                    if (incoming.winnerId == incoming.human?.id) RocketsHaptic.SUCCESS else RocketsHaptic.WARNING,
                )
            }
        }
        mutableFrame.value = incoming
    }
}

internal class HouseRocketsViewModelFactory(context: Context) : ViewModelProvider.Factory {
    private val appContext = context.applicationContext

    @Suppress("UNCHECKED_CAST")
    override fun <T : ViewModel> create(modelClass: Class<T>): T {
        val http = AndroidHttpAdapter.live()
        val store = KeystoreSessionStore(appContext)
        return HouseRocketsViewModel(online = HouseRocketsOnlineDependencies(
            makeEngine = HouseRocketsOnlineNative::engine,
            http = http::send,
            token = {
                withContext(Dispatchers.IO) { (store.read(SessionField.AUTH_TOKEN) as? SessionReadResult.Value)?.value }
            },
            sockets = OkHttpRealtimeSocketFactory(),
            catalogAvailability = HouseRocketsOnlineNative::catalogAvailability,
        )) as T
    }
}
