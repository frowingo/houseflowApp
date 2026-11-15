package com.fauscrew.viewmodel

import android.content.Context
import androidx.lifecycle.ViewModel
import androidx.lifecycle.ViewModelProvider
import androidx.lifecycle.viewModelScope
import com.fauscrew.platform.AndroidHttpAdapter
import com.fauscrew.platform.ChoreCatalogException
import com.fauscrew.platform.ChoreCatalogFailure
import com.fauscrew.platform.ChoreCatalogRecord
import com.fauscrew.platform.ChoreCatalogRepository
import com.fauscrew.platform.systemRecords
import com.fauscrew.platform.userRecords
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.async
import kotlinx.coroutines.currentCoroutineContext
import kotlinx.coroutines.ensureActive
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.update
import kotlinx.coroutines.sync.Mutex
import kotlinx.coroutines.sync.withLock
import kotlin.coroutines.cancellation.CancellationException

/** What the catalog shows (iOS `ChoreCatalogStore`'s published state). */
internal data class ChoreCatalogUiState(
    val records: List<ChoreCatalogRecord> = emptyList(),
    val phase: Phase = Phase.Idle,
    /** Ids of drafts whose delete is on its way to the server. */
    val pendingDeletes: Set<String> = emptySet(),
) {
    sealed interface Phase {
        data object Idle : Phase
        data object Loading : Phase
        data object Loaded : Phase
        data class Failed(val failure: ChoreCatalogFailure) : Phase
    }

    val systemRecords: List<ChoreCatalogRecord> get() = records.systemRecords
    val userRecords: List<ChoreCatalogRecord> get() = records.userRecords
    val hasLoaded: Boolean get() = phase == Phase.Loaded || records.isNotEmpty()
}

/**
 * iOS `ChoreCatalogStore`: the chore catalog as the server last sent it, system templates and
 * the signed-in user's drafts. The server is the only source of truth; this keeps the last list
 * in memory so the popup reopens without a blank state, and patches it with each PUT result.
 * GET and PUT requests go one at a time; each PUT response matches its request by index.
 * A `null` [repository] (previews, UI tests) leaves the catalog in its error state.
 */
internal class ChoreCatalogViewModel(private val repository: ChoreCatalogRepository?) : ViewModel() {
    private val mutableState = MutableStateFlow(ChoreCatalogUiState())
    val state: StateFlow<ChoreCatalogUiState> = mutableState.asStateFlow()

    /** The user the list belongs to; another user's list is never shown. */
    private var ownerId: String? = null
    private var ownerWork = SupervisorJob(viewModelScope.coroutineContext[Job])
    private var refreshJob: Deferred<Unit>? = null
    private val queue = Mutex()

    /** Called on the main thread for session changes, even while the popup is closed. */
    fun setOwner(ownerId: String?) {
        if (ownerId != this.ownerId) {
            ownerWork.cancel()
            this.ownerId = ownerId
            ownerWork = SupervisorJob(viewModelScope.coroutineContext[Job])
            refreshJob = null
            mutableState.value = ChoreCatalogUiState()
        }
    }

    /** Fetches the list again. A failure keeps the last list on screen. */
    suspend fun refresh(ownerId: String?) {
        setOwner(ownerId)
        if (ownerId == null) return
        refreshJob?.takeIf { it.isActive }?.let { it.await(); return }
        val job = viewModelScope.async(ownerWork) { queue.withLock { load(ownerId) } }
        refreshJob = job
        job.await()
    }

    /** The caller holds [queue], including the refetch after a PUT's 404. */
    private suspend fun load(owner: String?) {
        ensureOwner(owner)
        val repository = repository ?: run {
            mutableState.update { it.copy(phase = ChoreCatalogUiState.Phase.Failed(ChoreCatalogFailure(ChoreCatalogFailure.Kind.SERVER))) }
            return
        }
        mutableState.update { it.copy(phase = ChoreCatalogUiState.Phase.Loading) }
        val phase = try {
            val fetched = repository.fetch()
            ensureOwner(owner)
            mutableState.update { state -> state.copy(records = fetched.filterNot { it.id in state.pendingDeletes }) }
            ChoreCatalogUiState.Phase.Loaded
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            ensureOwner(owner)
            ChoreCatalogUiState.Phase.Failed(failure(error))
        }
        mutableState.update { it.copy(phase = phase) }
    }

    /**
     * Adds a draft (no id) or updates one (with id). Returns the failure, if any; after a 404 the
     * list is fetched again. Runs in the ViewModel's scope, so closing the popup does not cut a
     * request off halfway. An owner change cancels the work and the caller's await.
     */
    suspend fun save(record: ChoreCatalogRecord): ChoreCatalogFailure? {
        val owner = ownerId
        return viewModelScope.async(ownerWork) { performSave(record, owner) }.await()
    }

    /** Removes the draft at once and restores it if the server refuses. */
    suspend fun delete(record: ChoreCatalogRecord): ChoreCatalogFailure? {
        val owner = ownerId
        val work = ownerWork
        return viewModelScope.async(work) { performDelete(record, owner, work) }.await()
    }

    private suspend fun performSave(record: ChoreCatalogRecord, owner: String?): ChoreCatalogFailure? = queue.withLock {
        ensureOwner(owner)
        val repository = repository ?: return@withLock ChoreCatalogFailure(ChoreCatalogFailure.Kind.SERVER)
        try {
            val patched = repository.upsert(listOf(record), mutableState.value.records)
            ensureOwner(owner)
            mutableState.update { state -> state.copy(records = patched.filterNot { it.id in state.pendingDeletes }) }
            null
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            ensureOwner(owner)
            handle(error, owner)
        }
    }

    private suspend fun performDelete(record: ChoreCatalogRecord, owner: String?, work: Job): ChoreCatalogFailure? {
        ensureOwner(owner)
        val id = record.id ?: return null
        if (record.isSystem) return null
        val index = mutableState.value.records.indexOfFirst { it.id == id }.takeIf { it >= 0 }
        mutableState.update { state ->
            state.copy(records = state.records.filterNot { it.id == id }, pendingDeletes = state.pendingDeletes + id)
        }
        try {
            return queue.withLock {
                ensureOwner(owner)
                val repository = repository
                    ?: return@withLock restore(record, index, ChoreCatalogFailure(ChoreCatalogFailure.Kind.SERVER))
                try {
                    val patched = repository.upsert(listOf(record.markedDeleted), mutableState.value.records)
                    ensureOwner(owner)
                    mutableState.update { state -> state.copy(records = patched.filterNot { it.id in state.pendingDeletes }) }
                    null
                } catch (error: CancellationException) {
                    throw error
                } catch (error: Exception) {
                    ensureOwner(owner)
                    val failure = failure(error)
                    // Already gone on the server: nothing to restore.
                    if (failure.refreshesList) handle(error, owner) else restore(record, index, failure)
                }
            }
        } finally {
            if (work === ownerWork) mutableState.update { it.copy(pendingDeletes = it.pendingDeletes - id) }
        }
    }

    private fun restore(record: ChoreCatalogRecord, index: Int?, failure: ChoreCatalogFailure): ChoreCatalogFailure {
        mutableState.update { state ->
            if (state.records.any { it.id == record.id }) state
            else state.copy(records = state.records.toMutableList().apply { add(minOf(index ?: 0, size), record) })
        }
        return failure
    }

    private suspend fun handle(error: Exception, owner: String?): ChoreCatalogFailure {
        val failure = failure(error)
        if (failure.refreshesList) load(owner)
        return failure
    }

    private suspend fun ensureOwner(owner: String?) {
        currentCoroutineContext().ensureActive()
        if (owner == null || owner != ownerId) throw CancellationException("Catalog owner changed")
    }

    private fun failure(error: Exception): ChoreCatalogFailure =
        (error as? ChoreCatalogException)?.failure ?: ChoreCatalogFailure(ChoreCatalogFailure.Kind.SERVER)

    class Factory(context: Context) : ViewModelProvider.Factory {
        private val applicationContext = context.applicationContext

        @Suppress("UNCHECKED_CAST")
        override fun <T : ViewModel> create(modelClass: Class<T>): T =
            ChoreCatalogViewModel(ChoreCatalogRepository.live(applicationContext, AndroidHttpAdapter.live())) as T
    }
}
