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
import kotlinx.coroutines.async
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
 * PUT requests go one at a time, so each response is matched to its own request by index.
 * A `null` [repository] (previews, UI tests) leaves the catalog in its error state.
 */
internal class ChoreCatalogViewModel(private val repository: ChoreCatalogRepository?) : ViewModel() {
    private val mutableState = MutableStateFlow(ChoreCatalogUiState())
    val state: StateFlow<ChoreCatalogUiState> = mutableState.asStateFlow()

    /** The user the list belongs to; another user's list is never shown. */
    private var ownerId: String? = null
    private var refreshJob: Deferred<Unit>? = null
    private val queue = Mutex()

    /** Fetches the list again. A failure keeps the last list on screen. */
    suspend fun refresh(ownerId: String?) {
        if (ownerId != this.ownerId) {
            this.ownerId = ownerId
            refreshJob = null
            mutableState.value = ChoreCatalogUiState()
        }
        refreshJob?.takeIf { it.isActive }?.let { it.await(); return }
        val job = viewModelScope.async { load() }
        refreshJob = job
        job.await()
    }

    private suspend fun load() {
        val repository = repository ?: run {
            mutableState.update { it.copy(phase = ChoreCatalogUiState.Phase.Failed(ChoreCatalogFailure(ChoreCatalogFailure.Kind.SERVER))) }
            return
        }
        val owner = ownerId
        mutableState.update { it.copy(phase = ChoreCatalogUiState.Phase.Loading) }
        val phase = try {
            val fetched = repository.fetch()
            if (owner != ownerId) return
            mutableState.update { it.copy(records = fetched) }
            ChoreCatalogUiState.Phase.Loaded
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            if (owner != ownerId) return
            ChoreCatalogUiState.Phase.Failed(failure(error))
        }
        mutableState.update { it.copy(phase = phase) }
    }

    /**
     * Adds a draft (no id) or updates one (with id). Returns the failure, if any; after a 404 the
     * list is fetched again. Runs in the ViewModel's scope, so closing the popup does not cut a
     * request off halfway.
     */
    suspend fun save(record: ChoreCatalogRecord): ChoreCatalogFailure? = viewModelScope.async { performSave(record) }.await()

    /** Removes the draft at once and restores it if the server refuses. */
    suspend fun delete(record: ChoreCatalogRecord): ChoreCatalogFailure? = viewModelScope.async { performDelete(record) }.await()

    private suspend fun performSave(record: ChoreCatalogRecord): ChoreCatalogFailure? = queue.withLock {
        val repository = repository ?: return@withLock ChoreCatalogFailure(ChoreCatalogFailure.Kind.SERVER)
        try {
            val patched = repository.upsert(listOf(record), mutableState.value.records)
            mutableState.update { it.copy(records = patched) }
            null
        } catch (error: CancellationException) {
            throw error
        } catch (error: Exception) {
            handle(error)
        }
    }

    private suspend fun performDelete(record: ChoreCatalogRecord): ChoreCatalogFailure? {
        val id = record.id ?: return null
        if (record.isSystem) return null
        val index = mutableState.value.records.indexOfFirst { it.id == id }.takeIf { it >= 0 }
        mutableState.update { state ->
            state.copy(records = state.records.filterNot { it.id == id }, pendingDeletes = state.pendingDeletes + id)
        }
        try {
            return queue.withLock {
                val repository = repository
                    ?: return@withLock restore(record, index, ChoreCatalogFailure(ChoreCatalogFailure.Kind.SERVER))
                try {
                    val patched = repository.upsert(listOf(record.markedDeleted), mutableState.value.records)
                    mutableState.update { it.copy(records = patched) }
                    null
                } catch (error: CancellationException) {
                    throw error
                } catch (error: Exception) {
                    val failure = failure(error)
                    // Already gone on the server: nothing to restore.
                    if (failure.refreshesList) handle(error) else restore(record, index, failure)
                }
            }
        } finally {
            mutableState.update { it.copy(pendingDeletes = it.pendingDeletes - id) }
        }
    }

    private fun restore(record: ChoreCatalogRecord, index: Int?, failure: ChoreCatalogFailure): ChoreCatalogFailure {
        mutableState.update { state ->
            if (state.records.any { it.id == record.id }) state
            else state.copy(records = state.records.toMutableList().apply { add(minOf(index ?: 0, size), record) })
        }
        return failure
    }

    private suspend fun handle(error: Exception): ChoreCatalogFailure {
        val failure = failure(error)
        if (failure.refreshesList) load()
        return failure
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
