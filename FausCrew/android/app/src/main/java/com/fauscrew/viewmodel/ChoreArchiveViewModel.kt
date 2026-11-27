package com.fauscrew.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fauscrew.platform.AndroidHttpAdapter
import com.fauscrew.platform.ChoreArchiveRepository
import com.fauscrew.platform.ChoreArchiveRequestException
import com.fauscrew.platform.HouseChore
import com.fauscrew.platform.KeystoreSessionStore
import com.fauscrew.platform.SessionField
import com.fauscrew.platform.SessionReadResult
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.receiveAsFlow
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import java.time.LocalDate
import java.time.YearMonth
import java.time.ZoneId

internal enum class ChoreArchivePhase { LOADING, READY, ERROR }

internal data class ChoreArchiveUiState(
    val phase: ChoreArchivePhase = ChoreArchivePhase.LOADING,
    val month: YearMonth = YearMonth.now(),
    /** False in the current month: there is nothing to show past it. */
    val canShowNextMonth: Boolean = false,
    val chores: List<HouseChore> = emptyList(),
    val canLoadMore: Boolean = false,
    val loadingMore: Boolean = false,
    /** A retry of the same month is running behind the list that is already shown. */
    val refreshing: Boolean = false,
    /** Paging stops until the user retries, so a failing request is not repeated by scrolling. */
    val loadMoreFailed: Boolean = false,
    /** The server's localized text for a failed first page; null falls back to the generic error. */
    val errorMessage: String? = null,
)

/** Things the archive needs from the auth and house view models. */
internal sealed interface ChoreArchiveEffect {
    data object SessionRejected : ChoreArchiveEffect
    /** Not a member any more: refresh the profile and house list. */
    data object RefreshProfile : ChoreArchiveEffect
}

/**
 * Closed chores of the selected house, one calendar month at a time in pages. State is per
 * (user, house): [setContext] resets everything, and each month change starts over at page 1.
 * Nothing loads until [open]; answers that belong to an older month or context are dropped.
 */
internal class ChoreArchiveViewModel(
    private val repository: ChoreArchiveRepository,
    private val readJwt: suspend () -> String?,
    private val zone: () -> ZoneId = ZoneId::systemDefault,
    private val today: () -> LocalDate = { LocalDate.now() },
) : ViewModel() {
    private val mutableState = MutableStateFlow(ChoreArchiveUiState())
    val state: StateFlow<ChoreArchiveUiState> = mutableState.asStateFlow()
    private val effectChannel = Channel<ChoreArchiveEffect>(Channel.UNLIMITED)
    val effects: Flow<ChoreArchiveEffect> = effectChannel.receiveAsFlow()

    private var userId: String? = null
    private var houseId: String? = null
    private var generation = 0L
    private var nextUrl: String? = null
    private var firstJob: Job? = null
    private var moreJob: Job? = null

    /** The signed-in user and the selected house's id (null while none is loaded). Does not load. */
    fun setContext(userId: String?, houseId: String?) {
        val house = if (userId == null) null else houseId
        if (userId == this.userId && house == this.houseId) return
        generation++
        firstJob?.cancel(); moreJob?.cancel()
        this.userId = userId
        this.houseId = house
        nextUrl = null
        mutableState.value = emptyState(currentMonth())
    }

    /** The archive starts at the current month, page 1, every time it opens. */
    fun open() = loadFirst(currentMonth())

    fun previousMonth() = loadFirst(state.value.month.minusMonths(1))

    /** There is nothing to show past the current month. */
    fun nextMonth() {
        val next = state.value.month.plusMonths(1)
        if (next <= currentMonth()) loadFirst(next)
    }

    /** Retrying a loaded month keeps its list on screen; otherwise it starts over. */
    fun reload() {
        val current = state.value
        loadFirst(current.month, keepList = current.phase == ChoreArchivePhase.READY)
    }

    fun loadMore() {
        val current = state.value
        val url = nextUrl ?: return
        if (current.phase != ChoreArchivePhase.READY || current.loadingMore) return
        mutableState.value = current.copy(loadingMore = true, loadMoreFailed = false)
        val ticket = generation
        moreJob = viewModelScope.launch {
            try {
                val page = repository.nextPage(url, jwt())
                if (ticket != generation) return@launch
                nextUrl = page.nextUrl
                // A page that overlaps the list (a chore closed meanwhile) must not repeat rows.
                val known = state.value.chores.mapTo(mutableSetOf()) { it.id }
                mutableState.value = state.value.copy(
                    chores = state.value.chores + page.chores.filter { known.add(it.id) },
                    canLoadMore = page.nextUrl != null, loadingMore = false,
                )
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) {
                if (ticket != generation) return@launch
                mutableState.value = state.value.copy(loadingMore = false, loadMoreFailed = true)
                handle(error)
            }
        }
    }

    /**
     * Shows [month] from page 1 with no cursor, dropping whatever was loading before. With
     * [keepList] the shown list stays until the answer replaces it, and a failure leaves it alone.
     */
    private fun loadFirst(month: YearMonth, keepList: Boolean = false) {
        val house = houseId ?: return
        generation++
        firstJob?.cancel(); moreJob?.cancel()
        if (keepList) {
            mutableState.value = state.value.copy(refreshing = true, loadingMore = false, loadMoreFailed = false)
        } else {
            nextUrl = null
            mutableState.value = emptyState(month)
        }
        val ticket = generation
        firstJob = viewModelScope.launch {
            try {
                val zone = zone()
                val from = month.atDay(1).atStartOfDay(zone).toEpochSecond()
                val to = month.plusMonths(1).atDay(1).atStartOfDay(zone).toEpochSecond()
                val page = repository.firstPage(house, from, to, jwt())
                if (ticket != generation) return@launch
                nextUrl = page.nextUrl
                mutableState.value = state.value.copy(
                    phase = ChoreArchivePhase.READY, chores = page.chores.distinctBy { it.id }, canLoadMore = page.nextUrl != null,
                    refreshing = false,
                )
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) {
                if (ticket != generation) return@launch
                mutableState.value = if (keepList) {
                    state.value.copy(refreshing = false)
                } else {
                    state.value.copy(
                        phase = ChoreArchivePhase.ERROR, errorMessage = (error as? ChoreArchiveRequestException)?.message,
                    )
                }
                handle(error)
            }
        }
    }

    private fun currentMonth() = YearMonth.from(today())

    private fun emptyState(month: YearMonth) = ChoreArchiveUiState(month = month, canShowNextMonth = month < currentMonth())

    private fun handle(error: Exception) {
        when {
            error is MissingSession -> effectChannel.trySend(ChoreArchiveEffect.SessionRejected)
            error is ChoreArchiveRequestException && error.kind == "unauthorized" ->
                effectChannel.trySend(ChoreArchiveEffect.SessionRejected)
            error is ChoreArchiveRequestException && error.kind == "notMember" ->
                effectChannel.trySend(ChoreArchiveEffect.RefreshProfile)
        }
    }

    private class MissingSession : Exception("No session token")

    private suspend fun jwt(): String = readJwt() ?: throw MissingSession()

    class Factory(context: Context) : ViewModelProvider.Factory {
        private val appContext = context.applicationContext

        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            val store = KeystoreSessionStore(appContext)
            return ChoreArchiveViewModel(
                repository = ChoreArchiveRepository.live(AndroidHttpAdapter.live()),
                readJwt = { withContext(Dispatchers.IO) { (store.read(SessionField.AUTH_TOKEN) as? SessionReadResult.Value)?.value } },
            ) as T
        }
    }
}
