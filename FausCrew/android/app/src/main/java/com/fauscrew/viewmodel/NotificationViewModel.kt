package com.fauscrew.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fauscrew.platform.AndroidHttpAdapter
import com.fauscrew.platform.AndroidPreferencesStore
import com.fauscrew.platform.KeystoreSessionStore
import com.fauscrew.platform.NativeNotificationRules
import com.fauscrew.platform.NotificationItem
import com.fauscrew.platform.NotificationPageData
import com.fauscrew.platform.NotificationRepository
import com.fauscrew.platform.NotificationRequestException
import com.fauscrew.platform.NotificationRules
import com.fauscrew.platform.SessionField
import com.fauscrew.platform.SessionReadResult
import com.fauscrew.push.PushLog
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

internal enum class NotificationPhase { LOADING, READY, ERROR }

/** The open panel; the panel is closed while [NotificationUiState.panel] is null. */
internal data class NotificationPanelState(
    val phase: NotificationPhase = NotificationPhase.LOADING,
    val items: List<NotificationItem> = emptyList(),
    /** Items newer than the marker stored before the panel opened. */
    val unreadIds: Set<String> = emptySet(),
    val hasMore: Boolean = false,
    val refreshing: Boolean = false,
    val loadingMore: Boolean = false,
    /** Paging stops until the user retries, so a failing request is not repeated by scrolling. */
    val moreFailed: Boolean = false,
)

internal sealed interface ReminderToast {
    data object Sent : ReminderToast
    /** [message] is the server's localized text; null falls back to the generic error. */
    data class Failed(val message: String?) : ReminderToast
}

internal data class NotificationUiState(
    val badge: Int = 0,
    val panel: NotificationPanelState? = null,
    val sendingChoreId: String? = null,
    /** Chores the current user already reminded in this process. */
    val remindedChoreIds: Set<String> = emptySet(),
    val toast: ReminderToast? = null,
)

/** Things the notification flows need from the auth and house view models. */
internal sealed interface NotificationEffect {
    data object SessionRejected : NotificationEffect
    /** Not a member any more, or the house is gone: refresh the profile and house list. */
    data object RefreshProfile : NotificationEffect
    data class RefreshHouse(val houseId: String) : NotificationEffect
}

private const val PAGE_SIZE = 20

/**
 * Unread badge, notification panel pages and chore reminders for the selected house. State is per
 * (user, house): [setContext] resets everything on a house switch or sign-out. Badge refreshes are
 * silent (errors only logged); the panel shows its own states.
 */
internal class NotificationViewModel(
    private val repository: NotificationRepository,
    private val rules: NotificationRules,
    private val loadSeen: suspend (String) -> String?,
    private val saveSeen: suspend (String, String) -> Unit,
    private val readJwt: suspend () -> String?,
) : ViewModel() {
    private val mutableState = MutableStateFlow(NotificationUiState())
    val state: StateFlow<NotificationUiState> = mutableState.asStateFlow()
    private val effectChannel = Channel<NotificationEffect>(Channel.UNLIMITED)
    val effects: Flow<NotificationEffect> = effectChannel.receiveAsFlow()

    private var userId: String? = null
    private var houseId: String? = null
    private var generation = 0L
    private var firstSerial = 0L
    private var firstPage: NotificationPageData? = null
    private var nextCursor: String? = null
    private var seenBefore: String? = null
    private var firstJob: Job? = null
    private var silentJob: Job? = null
    private var silentSerial = 0L
    private var moreJob: Job? = null
    private var openJob: Job? = null
    private val reminded = mutableSetOf<String>()

    /** The signed-in user and the selected house's id (null while none is loaded). */
    fun setContext(userId: String?, houseId: String?) {
        val house = if (userId == null) null else houseId
        if (userId == this.userId && house == this.houseId) return
        if (userId != this.userId) reminded.clear()
        generation++
        firstSerial++
        silentSerial++
        firstJob?.cancel(); silentJob?.cancel(); moreJob?.cancel(); openJob?.cancel()
        this.userId = userId
        this.houseId = house
        firstPage = null
        nextCursor = null
        seenBefore = null
        mutableState.value = NotificationUiState(remindedChoreIds = reminded.toSet())
        if (house != null) loadFirst(replace = false)
    }

    /**
     * Silent refresh (events, foreground push): page 1 becomes the badge, or is merged into the
     * open panel's list without touching later pages. Other houses are ignored.
     */
    fun refresh(forHouseId: String? = null) {
        if (forHouseId != null && forHouseId != houseId) return
        loadFirst(replace = false)
    }

    fun open() {
        val user = userId ?: return
        val house = houseId ?: return
        if (state.value.panel != null) return
        val cached = firstPage
        // Cached rows show at once and are refreshed behind them, without the pull spinner.
        mutableState.value = state.value.copy(
            panel = NotificationPanelState(
                phase = if (cached == null) NotificationPhase.LOADING else NotificationPhase.READY,
                items = cached?.items.orEmpty(), hasMore = nextCursor != null, refreshing = false,
            ),
        )
        val ticket = generation
        openJob = viewModelScope.launch {
            // The marker before this open decides what counts as unread; saving comes after.
            seenBefore = try { loadSeen(seenKey(user, house)) } catch (cancel: CancellationException) { throw cancel }
                catch (error: Exception) { null }
            if (ticket != generation) return@launch
            if (cached != null) {
                showFirst(cached.items)
                try { markSeen(user, house, cached.items) } catch (cancel: CancellationException) { throw cancel }
                catch (error: Exception) { PushLog.d("Notification marker failed: ${error.javaClass.simpleName}") }
            }
            loadFirst(replace = true)
        }
    }

    fun close() {
        moreJob?.cancel()
        // Paging may have moved the cursor past page 1; the cached first page starts over.
        nextCursor = firstPage?.nextCursor
        mutableState.value = state.value.copy(panel = null)
    }

    /** Pull to refresh: the only refresh that replaces the paged list. */
    fun reload() {
        val panel = state.value.panel ?: return
        if (panel.refreshing) return
        // Retrying from the error card shows the skeleton again.
        val phase = if (panel.phase == NotificationPhase.ERROR) NotificationPhase.LOADING else panel.phase
        mutableState.value = state.value.copy(panel = panel.copy(phase = phase, refreshing = true))
        loadFirst(replace = true)
    }

    fun loadMore() {
        val panel = state.value.panel ?: return
        val cursor = nextCursor ?: return
        val house = houseId ?: return
        if (panel.phase != NotificationPhase.READY || panel.loadingMore || panel.refreshing) return
        mutableState.value = state.value.copy(panel = panel.copy(loadingMore = true, moreFailed = false))
        val ticket = generation
        val serial = firstSerial
        moreJob = viewModelScope.launch {
            try {
                val page = repository.list(house, cursor, PAGE_SIZE, jwt())
                if (ticket != generation || serial != firstSerial) return@launch
                val ids = unreadIds(page.items)
                if (ticket != generation || serial != firstSerial) return@launch
                nextCursor = page.nextCursor
                updatePanel {
                    it.copy(
                        items = (it.items + page.items).distinctBy { item -> item.id }, unreadIds = it.unreadIds + ids,
                        hasMore = page.nextCursor != null, loadingMore = false,
                    )
                }
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) {
                if (ticket != generation || serial != firstSerial) return@launch
                updatePanel { it.copy(loadingMore = false, moreFailed = true) }
                handle(error)
            }
        }
    }

    /** A push arrived while the app is open. */
    fun onForegroundPush(data: Map<String, String>) = refresh(data["houseId"])

    fun remind(choreId: String) {
        val user = userId ?: return
        val house = houseId ?: return
        if (state.value.sendingChoreId != null || choreId in reminded) return
        mutableState.value = state.value.copy(sendingChoreId = choreId, toast = null)
        val ticket = generation
        viewModelScope.launch {
            try {
                repository.remind(choreId, jwt())
                if (userId == user) markReminded(choreId)
                if (ticket == generation) mutableState.value = state.value.copy(toast = ReminderToast.Sent)
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) {
                if (ticket != generation) return@launch
                if (error is MissingSession) {
                    handle(error)
                    return@launch
                }
                val failure = error as? NotificationRequestException
                when (failure?.kind) {
                    "alreadyReminded" -> markReminded(choreId)
                    "unauthorized" -> effectChannel.trySend(NotificationEffect.SessionRejected)
                    else -> {
                        mutableState.value = state.value.copy(toast = ReminderToast.Failed(failure?.message))
                        if (failure?.kind == "notFound") effectChannel.trySend(NotificationEffect.RefreshHouse(house))
                    }
                }
            } finally {
                if (ticket == generation) mutableState.value = state.value.copy(sendingChoreId = null)
            }
        }
    }

    fun clearToast() { mutableState.value = state.value.copy(toast = null) }

    private fun markReminded(choreId: String) {
        reminded += choreId
        mutableState.value = state.value.copy(remindedChoreIds = reminded.toSet())
    }

    /** [replace]: the panel's list becomes page 1 (open, pull to refresh); otherwise page 1 is merged in. */
    private fun loadFirst(replace: Boolean) {
        val user = userId ?: return
        val house = houseId ?: return
        val ticket = generation
        val serial: Long
        if (replace) {
            serial = ++firstSerial
            silentSerial++
            firstJob?.cancel()
            moreJob?.cancel()
        } else {
            serial = ++silentSerial
            silentJob?.cancel()
        }
        fun stale() = ticket != generation || serial != (if (replace) firstSerial else silentSerial)
        val job = viewModelScope.launch {
            try {
                val page = repository.list(house, null, PAGE_SIZE, jwt())
                if (stale()) return@launch
                val panel = state.value.panel
                if (panel == null) {
                    firstPage = page
                    nextCursor = page.nextCursor
                    val stored = loadSeen(seenKey(user, house))
                    val count = unreadCount(page.items, stored)
                    if (stale()) return@launch
                    mutableState.value = state.value.copy(badge = count)
                } else if (openJob?.isActive != true) {
                    // While the open is still reading the old marker, its own load follows.
                    firstPage = page
                    if (replace || panel.phase != NotificationPhase.READY) {
                        nextCursor = page.nextCursor
                        showFirst(page.items)
                    } else {
                        val ids = unreadIds(page.items)
                        if (stale()) return@launch
                        updatePanel {
                            it.copy(
                                items = (page.items + it.items).distinctBy { item -> item.id }.sortedByDescending { item -> item.createdAt },
                                unreadIds = it.unreadIds + ids,
                            )
                        }
                    }
                    if (state.value.panel != null) markSeen(user, house, page.items)
                }
            } catch (cancel: CancellationException) { throw cancel }
            catch (error: Exception) {
                if (stale()) return@launch
                if (replace) {
                    updatePanel {
                        it.copy(
                            refreshing = false, loadingMore = false,
                            phase = if (it.phase == NotificationPhase.LOADING) NotificationPhase.ERROR else it.phase,
                        )
                    }
                }
                handle(error)
            }
        }
        if (replace) firstJob = job else silentJob = job
    }

    /** Shows [items] as page 1 of the open panel. */
    private suspend fun showFirst(items: List<NotificationItem>) {
        val ids = unreadIds(items)
        updatePanel {
            it.copy(
                phase = NotificationPhase.READY, items = items, unreadIds = ids,
                hasMore = nextCursor != null, refreshing = false, loadingMore = false, moreFailed = false,
            )
        }
    }

    private suspend fun markSeen(user: String, house: String, items: List<NotificationItem>) {
        val marker = withContext(Dispatchers.Default) { rules.seenMarker(items) }
        marker?.let { saveSeen(seenKey(user, house), it) }
        if (userId == user && houseId == house) mutableState.value = state.value.copy(badge = 0)
    }

    // The rules go through JNI once per item; keep that off the main thread.
    private suspend fun unreadIds(items: List<NotificationItem>): Set<String> {
        val marker = seenBefore
        return withContext(Dispatchers.Default) {
            items.filter { rules.unreadCount(listOf(it), marker) > 0 }.mapTo(mutableSetOf()) { it.id }
        }
    }

    private suspend fun unreadCount(items: List<NotificationItem>, marker: String?): Int =
        withContext(Dispatchers.Default) { rules.unreadCount(items, marker) }

    private fun updatePanel(change: (NotificationPanelState) -> NotificationPanelState) {
        val panel = state.value.panel ?: return
        mutableState.value = state.value.copy(panel = change(panel))
    }

    private fun handle(error: Exception) {
        val failure = error as? NotificationRequestException
        PushLog.d("Notification request failed: ${failure?.kind ?: error.javaClass.simpleName} status=${failure?.status}")
        when (failure?.kind) {
            // Only a real 401 response; a missing token is the sign-out's own business.
            "unauthorized" -> effectChannel.trySend(NotificationEffect.SessionRejected)
            "notMember", "notFound" -> {
                moreJob?.cancel()
                mutableState.value = state.value.copy(panel = null, badge = 0)
                effectChannel.trySend(NotificationEffect.RefreshProfile)
            }
        }
    }

    private class MissingSession : Exception("No session token")

    private suspend fun jwt(): String = readJwt() ?: throw MissingSession()

    private fun seenKey(user: String, house: String) = "fauscrew.notifications-seen.$user.$house"

    class Factory(context: Context) : ViewModelProvider.Factory {
        private val appContext = context.applicationContext

        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T {
            val store = KeystoreSessionStore(appContext)
            val preferences = AndroidPreferencesStore(appContext)
            return NotificationViewModel(
                repository = NotificationRepository.live(AndroidHttpAdapter.live()),
                rules = NativeNotificationRules,
                loadSeen = preferences::notificationSeen,
                saveSeen = preferences::setNotificationSeen,
                readJwt = { withContext(Dispatchers.IO) { (store.read(SessionField.AUTH_TOKEN) as? SessionReadResult.Value)?.value } },
            ) as T
        }
    }
}
