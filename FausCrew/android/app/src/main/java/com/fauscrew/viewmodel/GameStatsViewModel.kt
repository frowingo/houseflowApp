package com.fauscrew.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fauscrew.platform.AndroidHttpAdapter
import com.fauscrew.platform.GameStatsBoardData
import com.fauscrew.platform.GameStatsRepository
import com.fauscrew.platform.GameStatsRequestException
import com.fauscrew.platform.KeystoreSessionStore
import com.fauscrew.platform.SessionField
import com.fauscrew.platform.SessionReadResult
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext

internal enum class GameStatsPhase { IDLE, LOADING, READY, ERROR }

internal data class GameStatsUiState(
    val phase: GameStatsPhase = GameStatsPhase.IDLE,
    /** Present once a load succeeded; a failed refresh keeps it. */
    val board: GameStatsBoardData? = null,
    /** The server's localized text for a failed first load; null falls back to the generic error. */
    val errorMessage: String? = null,
)

/** Things the stats card needs from the auth and house view models. */
internal sealed interface GameStatsEffect {
    data object SessionRejected : GameStatsEffect
    /** 403 or 404: no longer a member, or the house is gone. Refresh the profile and house list. */
    data object RefreshProfile : GameStatsEffect
}

/**
 * iOS `GameStatsStore`: the selected house's game standings for the dashboard card, per (user,
 * house). Nothing loads until [refresh]; there is no live update. A 429 with nothing shown is
 * retried once after a short wait; with standings shown it is ignored and they stay.
 */
internal class GameStatsViewModel(
    private val repository: GameStatsRepository,
    private val readJwt: suspend () -> String?,
    private val knownGameKeys: Set<String>,
    private val rateLimitDelayMillis: Long = 2_000,
    private val pause: suspend (Long) -> Unit = { delay(it) },
) : ViewModel() {
    private val mutableState = MutableStateFlow(GameStatsUiState())
    val state: StateFlow<GameStatsUiState> = mutableState.asStateFlow()
    private val effectChannel = Channel<GameStatsEffect>(Channel.UNLIMITED)
    val effects: Flow<GameStatsEffect> = effectChannel.receiveAsFlow()

    private var userId: String? = null
    private var houseId: String? = null
    private var memberIds: List<String> = emptyList()
    /** The last successful body, so a member change rebuilds the board without a request. */
    private var lastBody: String? = null
    private var generation = 0L
    private var job: Job? = null
    private var reportedAccessLost = false

    /** The signed-in user and the selected house's id (null while none is loaded). Does not load. */
    fun setContext(userId: String?, houseId: String?) {
        val house = if (userId == null) null else houseId
        if (userId == this.userId && house == this.houseId) return
        generation++
        job?.cancel()
        this.userId = userId
        this.houseId = house
        lastBody = null
        reportedAccessLost = false
        mutableState.value = GameStatsUiState()
    }

    /** The house's members in membership order; names and the overall tie-break follow it. */
    fun setMembers(ids: List<String>) {
        if (ids == memberIds) return
        memberIds = ids
        val body = lastBody ?: return
        runCatching { repository.board(body, ids, knownGameKeys) }.onSuccess {
            mutableState.value = state.value.copy(board = it)
        }
    }

    fun refresh() {
        val house = houseId ?: return
        generation++
        job?.cancel()
        val ticket = generation
        if (state.value.phase != GameStatsPhase.READY) mutableState.value = state.value.copy(phase = GameStatsPhase.LOADING)
        job = viewModelScope.launch {
            var retried = false
            while (true) {
                try {
                    val body = repository.fetch(house, jwt())
                    if (ticket != generation) return@launch
                    val board = repository.board(body, memberIds, knownGameKeys)
                    lastBody = body
                    mutableState.value = GameStatsUiState(GameStatsPhase.READY, board, null)
                    return@launch
                } catch (cancel: CancellationException) { throw cancel }
                catch (error: Exception) {
                    if (ticket != generation) return@launch
                    val failure = error as? GameStatsRequestException
                    if (failure?.kind == "rateLimited" && state.value.phase == GameStatsPhase.LOADING && !retried) {
                        retried = true
                        pause(rateLimitDelayMillis)
                        if (ticket != generation) return@launch
                        continue
                    }
                    // A failed refresh keeps the standings on screen.
                    if (state.value.phase == GameStatsPhase.LOADING) {
                        mutableState.value = state.value.copy(phase = GameStatsPhase.ERROR, errorMessage = failure?.message)
                    }
                    handle(error)
                    return@launch
                }
            }
        }
    }

    private fun handle(error: Exception) {
        val kind = (error as? GameStatsRequestException)?.kind
        when {
            error is MissingSession || kind == "unauthorized" -> effectChannel.trySend(GameStatsEffect.SessionRejected)
            // Once per context, so an unchanged house cannot loop.
            kind == "accessLost" && !reportedAccessLost -> {
                reportedAccessLost = true
                effectChannel.trySend(GameStatsEffect.RefreshProfile)
            }
        }
    }

    private class MissingSession : Exception("No session token")

    private suspend fun jwt(): String = readJwt() ?: throw MissingSession()

    class Factory(context: Context, private val knownGameKeys: Set<String>) : ViewModelProvider.Factory {
        private val appContext = context.applicationContext

        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            val store = KeystoreSessionStore(appContext)
            return GameStatsViewModel(
                repository = GameStatsRepository.live(AndroidHttpAdapter.live()),
                readJwt = { withContext(Dispatchers.IO) { (store.read(SessionField.AUTH_TOKEN) as? SessionReadResult.Value)?.value } },
                knownGameKeys = knownGameKeys,
            ) as T
        }
    }
}
