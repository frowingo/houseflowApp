package com.fauscrew.viewmodel

import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import com.fauscrew.platform.HouseTanksEngine
import com.fauscrew.platform.HouseTanksNative
import com.fauscrew.platform.TanksColor
import com.fauscrew.platform.TanksDifficulty
import com.fauscrew.platform.TanksFrame
import com.fauscrew.platform.TanksMap
import com.fauscrew.platform.TanksPhase
import com.fauscrew.platform.TanksUpdate
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

/** `HouseTanksMode`. */
internal enum class TanksMode { DEMO, ONLINE }

/** `HouseTanksSetupStep`: the demo picks the player must make; nothing is preselected. */
internal enum class TanksSetupStep { MAP, PLAYERS, COLOR, DIFFICULTY }

internal enum class TanksHaptic { HIT, ROUND_END, WIN, LOSS }

internal data class HouseTanksUiState(
    val selectedMode: TanksMode? = null,
    val map: TanksMap? = null,
    val color: TanksColor? = null,
    val difficulty: TanksDifficulty? = null,
    /** Tanks in the match, the human included; asked only on maps with a player range. */
    val playerCount: Int? = null,
    /** The selected map's player range (from Core's catalog). */
    val playerChoices: IntRange? = null,
    /** Online rooms draw their arena at random. */
    val onlineMap: TanksMap? = null,
) {
    val needsPlayerCount: Boolean
        get() = selectedMode != TanksMode.ONLINE && playerChoices != null && playerChoices.first != playerChoices.last

    /** The picks this setup asks for: the player count appears only on crowded-match maps. */
    val setupSteps: List<TanksSetupStep>
        get() = TanksSetupStep.entries.filter { it != TanksSetupStep.PLAYERS || needsPlayerCount }

    /** Four tanks on the standard maps; the chosen (or smallest) count on crowded-match maps. */
    val rosterSize: Int
        get() = playerChoices?.let { range -> (playerCount ?: range.first).coerceIn(range) } ?: 4

    /** The arena the next match uses: the player's pick in demo, the drawn one online. */
    val matchMap: TanksMap? get() = if (selectedMode == TanksMode.ONLINE) onlineMap else map

    /** The first pick still missing, in the order the setup screen asks for them. */
    val pendingSetupStep: TanksSetupStep? get() = setupSteps.firstOrNull { !isComplete(it) }

    val completedSetupSteps: Int get() = setupSteps.count(::isComplete)

    fun isComplete(step: TanksSetupStep): Boolean = when (step) {
        TanksSetupStep.MAP -> matchMap != null
        TanksSetupStep.PLAYERS -> playerCount != null
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
    private val drawMap: () -> TanksMap = { TanksMap.entries.random() },
    private val playerRange: (TanksMap) -> IntRange = { map -> HouseTanksNative.maps[map]?.playerCounts ?: 4..4 },
) : ViewModel() {
    private val mutableState = MutableStateFlow(HouseTanksUiState())
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

    fun selectMode(mode: TanksMode) {
        if (mutableFrame.value != null) return
        // Until the online service assigns arenas, each room visit draws one locally.
        mutableState.update { it.copy(selectedMode = mode, onlineMap = if (mode == TanksMode.ONLINE) drawMap() else null) }
    }

    fun returnToModeSelection() {
        if (mutableFrame.value != null) return
        mutableState.update { it.copy(selectedMode = null, onlineMap = null) }
    }

    fun selectMap(map: TanksMap) = mutableState.update { it.copy(map = map, playerChoices = playerRange(map)) }
    fun selectPlayerCount(count: Int) = mutableState.update { it.copy(playerCount = count) }
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
        apply(engine.start(difficulty, color, map, if (current.needsPlayerCount) current.rosterSize else 4))
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
        countdownJob?.cancel()
        countdownJob = null
        isPressing = false
        lastFrameNanos = null
        engine?.close()
        engine = null
        mutableFrame.value = null
    }

    override fun onCleared() {
        stop()
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
