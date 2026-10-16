package com.houseflow.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.houseflow.platform.HouseRocketsEngine
import com.houseflow.platform.HouseRocketsNative
import com.houseflow.platform.RocketsFrame
import com.houseflow.platform.RocketsPhase
import com.houseflow.platform.RocketsUpdate
import kotlin.math.abs
import kotlin.math.atan2
import kotlin.math.cos
import kotlin.math.sin
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

/** `HouseRocketsMode`. Housemates (online) mode arrives with the realtime transport. */
internal enum class RocketsMode { LOCAL_BOTS, HOUSEMATES }

/** iOS `HouseRocketsOnlineBlocker`; Android has no online session yet. */
internal enum class RocketsOnlineBlocker { SIGN_IN_REQUIRED, HOUSE_REQUIRED, SERVICE_UNAVAILABLE }

internal enum class RocketsHaptic { SUCCESS, WARNING }

internal data class HouseRocketsUiState(
    val selectedMode: RocketsMode? = null,
    val botCount: Int = 3,
    val houseId: String? = null,
    val userId: String? = null,
) {
    val onlineBlocker: RocketsOnlineBlocker
        get() = when {
            userId.isNullOrEmpty() -> RocketsOnlineBlocker.SIGN_IN_REQUIRED
            houseId.isNullOrEmpty() -> RocketsOnlineBlocker.HOUSE_REQUIRED
            else -> RocketsOnlineBlocker.SERVICE_UNAVAILABLE
        }
}

/**
 * `HouseRocketsViewModel` for the local bot match. The rules run in HouseFlowCore; this
 * type schedules them: a 0.75 s countdown timer and one physics step per rendered frame,
 * plus iOS's steering de-duplication and haptic cues. The screen owns orientation.
 */
internal class HouseRocketsViewModel(
    private val makeEngine: () -> HouseRocketsEngine = HouseRocketsNative::engine,
    private val countdownStepMillis: () -> Long = { HouseRocketsNative.countdownStepMillis },
) : ViewModel() {
    private val mutableState = MutableStateFlow(HouseRocketsUiState())
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

    fun updateContext(houseId: String?, userId: String?) {
        val current = mutableState.value
        if (current.houseId == houseId && current.userId == userId) return
        if (current.houseId != null || current.userId != null) returnToModeSelection()
        mutableState.update { it.copy(houseId = houseId, userId = userId) }
    }

    fun selectMode(mode: RocketsMode) {
        if (mutableFrame.value != null) return
        mutableState.update { it.copy(selectedMode = mode) }
    }

    fun returnToModeSelection() {
        stop()
        mutableState.update { it.copy(selectedMode = null) }
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
    }

    fun adjustHeading(amount: Double) {
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
