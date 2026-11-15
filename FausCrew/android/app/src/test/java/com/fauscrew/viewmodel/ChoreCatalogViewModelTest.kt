package com.fauscrew.viewmodel

import com.fauscrew.platform.ChoreCatalogFailure
import com.fauscrew.platform.ChoreCatalogRecord
import com.fauscrew.platform.ChoreCatalogRepository
import com.fauscrew.platform.ChoreCatalogWire
import com.fauscrew.platform.PlatformHttpRequest
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.SessionReadResult
import kotlinx.coroutines.CompletableDeferred
import kotlinx.coroutines.CoroutineStart
import kotlinx.coroutines.Deferred
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.NonCancellable
import kotlinx.coroutines.async
import kotlinx.coroutines.channels.Channel
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runCurrent
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Before
import org.junit.Test
import java.util.concurrent.atomic.AtomicReference
import kotlin.coroutines.cancellation.CancellationException

/**
 * `ChoreCatalogViewModel` against a fake server (iOS `ChoreCatalogStoreTests`): the list is the
 * server's, PUT results patch it, a refused delete comes back, and a 404 fetches the list again.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ChoreCatalogViewModelTest {
    /** Stands in for the server and the bridge; patches like Core's `ChoreCatalogPatch`. */
    private class FakeServer(
        send: suspend (PlatformHttpRequest) -> PlatformHttpResponse = { PlatformHttpResponse(200, emptyMap(), ByteArray(0)) },
        token: () -> String = { "token" },
    ) {
        var list = listOf<ChoreCatalogRecord>()
        var fetchFailure: ChoreCatalogFailure? = null
        var upsertFailure: ChoreCatalogFailure? = null
        var fetchCount = 0
        val sent = mutableListOf<List<ChoreCatalogRecord>>()
        val locals = mutableListOf<List<ChoreCatalogRecord>>()
        private var nextId = 0

        private fun ok(records: List<ChoreCatalogRecord>): String =
            JSONObject().put("ok", true).put("records", JSONArray(ChoreCatalogRecord.encode(records))).toString()

        private fun failed(failure: ChoreCatalogFailure): String =
            JSONObject().put("ok", false).put("kind", failure.kind.wire).put("message", failure.message ?: JSONObject.NULL).toString()

        val repository = ChoreCatalogRepository(
            send = send,
            read = { SessionReadResult.Value(token()) },
            wire = object : ChoreCatalogWire {
                override fun body(recordsJson: String): String = JSONObject().put("ok", true).put("body", recordsJson).toString()

                override fun response(action: String, status: Int, body: String, recordsJson: String, localJson: String): String {
                    if (action == "list") {
                        fetchCount += 1
                        return fetchFailure?.let(::failed) ?: ok(if (body.isEmpty()) list else ChoreCatalogRecord.decode(JSONArray(body)))
                    }
                    val records = ChoreCatalogRecord.decode(JSONArray(recordsJson))
                    sent += records
                    upsertFailure?.let { return failed(it) }
                    val local = ChoreCatalogRecord.decode(JSONArray(localJson)).toMutableList()
                    locals += local.toList()
                    records.forEach { record ->
                        val saved = (if (record.id == null) record.copy(id = "%024d".format(++nextId)) else record)
                            .copy(updatedOn = "2026-11-12T12:00:%02dZ".format(nextId))
                        val index = local.indexOfFirst { it.id == saved.id }
                        when {
                            saved.isDeleted -> if (index >= 0) local.removeAt(index)
                            index >= 0 -> local[index] = saved
                            else -> local += saved
                        }
                    }
                    return ok(local)
                }
            },
        )
    }

    private class PendingRequest(val request: PlatformHttpRequest) {
        val response = CompletableDeferred<PlatformHttpResponse>()

        fun complete(records: List<ChoreCatalogRecord>? = null) {
            response.complete(PlatformHttpResponse(200, emptyMap(), records?.let { ChoreCatalogRecord.encode(it).toByteArray() } ?: ByteArray(0)))
        }
    }

    private fun delayedServer(
        requests: Channel<PendingRequest>, ignoreCancellation: Boolean = false, token: () -> String = { "token" },
    ) = FakeServer(
        send = { request ->
            val pending = PendingRequest(request)
            requests.send(pending)
            // A late transport response may still arrive after the session was cancelled.
            if (ignoreCancellation) withContext(NonCancellable) { pending.response.await() } else pending.response.await()
        },
        token = token,
    )

    private suspend fun assertCancelled(job: Deferred<*>) {
        try {
            job.await()
            fail("expected CancellationException")
        } catch (_: CancellationException) {
            assertTrue(job.isCancelled)
        }
    }

    private val system = ChoreCatalogRecord(id = "6730f1c2a1b2c3d4e5f60701", title = "Bulaşıkları yıka", category = 1, isSystem = true)
    private val draft = ChoreCatalogRecord(id = "6730f1c2a1b2c3d4e5f60718", title = "Nevresimler", category = 2,
        updatedOn = "2026-11-12T09:00:00Z")

    @Before fun setUp() = Dispatchers.setMain(UnconfinedTestDispatcher())
    @After fun tearDown() = Dispatchers.resetMain()

    @Test fun refreshLoadsSystemTemplatesAndDrafts() = runTest {
        val server = FakeServer().apply { list = listOf(system, draft) }
        val model = ChoreCatalogViewModel(server.repository)
        assertFalse(model.state.value.hasLoaded)

        model.refresh("u1")
        assertEquals(ChoreCatalogUiState.Phase.Loaded, model.state.value.phase)
        assertEquals(listOf(system.id), model.state.value.systemRecords.map { it.id })
        assertEquals(listOf(draft.id), model.state.value.userRecords.map { it.id })
    }

    @Test fun aFailedRefreshKeepsTheLastListAndAnotherUserStartsEmpty() = runTest {
        val server = FakeServer().apply { list = listOf(system) }
        val model = ChoreCatalogViewModel(server.repository)
        model.refresh("u1")

        val down = ChoreCatalogFailure(ChoreCatalogFailure.Kind.SERVER, "Down")
        server.fetchFailure = down
        model.refresh("u1")
        assertEquals(1, model.state.value.records.size)
        assertEquals(ChoreCatalogUiState.Phase.Failed(down), model.state.value.phase)
        assertTrue(model.state.value.hasLoaded)

        model.refresh("u2")
        assertTrue("never shows the previous user's drafts", model.state.value.records.isEmpty())
    }

    @Test fun savingASystemTemplateAddsANewDraft() = runTest {
        val server = FakeServer().apply { list = listOf(system) }
        val model = ChoreCatalogViewModel(server.repository)
        model.refresh("u1")

        assertNull(model.save(system.asNewUserRecord))
        assertNull(server.sent.last().first().id)
        assertFalse(server.sent.last().first().isSystem)
        assertEquals(1, model.state.value.userRecords.size)
        assertEquals("the system template is untouched", listOf(system), model.state.value.systemRecords)

        // Saving it again adds another draft: there is no link to the template.
        model.save(system.asNewUserRecord)
        assertEquals(2, model.state.value.userRecords.size)
    }

    @Test fun updatingADraftKeepsItsIdAndPlace() = runTest {
        val server = FakeServer().apply { list = listOf(system, draft) }
        val model = ChoreCatalogViewModel(server.repository)
        model.refresh("u1")

        assertNull(model.save(draft.copy(title = "Nevresimleri değiştir")))
        assertEquals(listOf(system.id, draft.id), model.state.value.records.map { it.id })
        assertEquals("Nevresimleri değiştir", model.state.value.userRecords.first().title)
    }

    @Test fun aRefusedDeleteRestoresTheDraft() = runTest {
        val server = FakeServer().apply { list = listOf(system, draft) }
        val model = ChoreCatalogViewModel(server.repository)
        model.refresh("u1")

        server.upsertFailure = ChoreCatalogFailure(ChoreCatalogFailure.Kind.SERVER, "Nope")
        assertEquals("Nope", model.delete(draft)?.message)
        assertEquals(listOf(system.id, draft.id), model.state.value.records.map { it.id })
        assertTrue(server.sent.last().first().isDeleted)
        assertTrue(model.state.value.pendingDeletes.isEmpty())
    }

    @Test fun deleteRemovesTheDraftAndNeverTouchesSystemTemplates() = runTest {
        val server = FakeServer().apply { list = listOf(system, draft) }
        val model = ChoreCatalogViewModel(server.repository)
        model.refresh("u1")

        model.delete(system)
        assertTrue(server.sent.isEmpty())
        assertNull(model.delete(draft))
        assertEquals(listOf(system.id), model.state.value.records.map { it.id })
    }

    @Test fun notFoundFetchesTheListAgain() = runTest {
        val server = FakeServer().apply { list = listOf(system, draft) }
        val model = ChoreCatalogViewModel(server.repository)
        model.refresh("u1")

        server.list = listOf(system)
        server.upsertFailure = ChoreCatalogFailure(ChoreCatalogFailure.Kind.NOT_FOUND, "Görev kataloğu kaydı bulunamadı veya silinmiş.")
        val failure = model.save(draft.copy(title = "Başka"))
        assertEquals(ChoreCatalogFailure.Kind.NOT_FOUND, failure?.kind)
        assertEquals(2, server.fetchCount)
        assertEquals(listOf(system.id), model.state.value.records.map { it.id })
    }

    @Test fun aSaveWaitsForTheGetAndPatchesItsFreshList() = runTest {
        val requests = Channel<PlatformHttpRequest>(Channel.UNLIMITED)
        val getResponse = CompletableDeferred<PlatformHttpResponse>()
        val putResponse = CompletableDeferred<PlatformHttpResponse>()
        val server = FakeServer(send = { request ->
            requests.send(request)
            if (request.method == "GET") getResponse.await() else putResponse.await()
        })
        val model = ChoreCatalogViewModel(server.repository)
        val refresh = async { model.refresh("u1") }
        val get = requests.receive()
        assertEquals("GET", get.method)

        val save = async(start = CoroutineStart.UNDISPATCHED) { model.save(system.asNewUserRecord) }
        // Try to return the PUT first: it must not even be sent until the GET finishes.
        putResponse.complete(PlatformHttpResponse(200, emptyMap(), ByteArray(0)))
        runCurrent()
        assertTrue("PUT cannot overtake the GET", requests.tryReceive().isFailure)
        assertFalse(save.isCompleted)

        getResponse.complete(PlatformHttpResponse(200, emptyMap(), ChoreCatalogRecord.encode(listOf(system, draft)).toByteArray()))
        val put = requests.receive()
        assertEquals("PUT", put.method)
        refresh.await()
        assertNull(save.await())
        assertEquals(listOf(system, draft), server.locals.single())
        assertEquals(3, model.state.value.records.size)
        assertEquals(2, model.state.value.userRecords.size)
    }

    @Test fun aRefreshWaitsForThePutAndKeepsTheSavedDraft() = runTest {
        val requests = Channel<PendingRequest>(Channel.UNLIMITED)
        val server = delayedServer(requests)
        val model = ChoreCatalogViewModel(server.repository)
        model.setOwner("u1")
        val save = async { model.save(draft) }
        val put = requests.receive()

        val refresh = async(start = CoroutineStart.UNDISPATCHED) { model.refresh("u1") }
        runCurrent()
        assertTrue("GET cannot overtake the PUT", requests.tryReceive().isFailure)
        put.complete()
        assertNull(save.await())
        val saved = model.state.value.records.single()
        val get = requests.receive()
        assertEquals("GET", get.request.method)
        get.complete(listOf(saved))
        refresh.await()
        assertEquals(listOf(saved), model.state.value.records)
    }

    @Test fun aGetDoesNotBringBackADraftWhoseDeleteIsQueued() = runTest {
        val requests = Channel<PendingRequest>(Channel.UNLIMITED)
        val model = ChoreCatalogViewModel(delayedServer(requests).repository)
        val initial = async { model.refresh("u1") }
        requests.receive().complete(listOf(system, draft))
        initial.await()

        val refresh = async { model.refresh("u1") }
        val get = requests.receive()
        val delete = async(start = CoroutineStart.UNDISPATCHED) { model.delete(draft) }
        runCurrent()
        assertEquals(setOf(draft.id), model.state.value.pendingDeletes)
        assertEquals(listOf(system), model.state.value.records)

        get.complete(listOf(system, draft))
        val put = requests.receive()
        refresh.await()
        assertEquals("PUT", put.request.method)
        assertEquals("the GET must keep the optimistic deletion", listOf(system), model.state.value.records)
        put.complete()
        assertNull(delete.await())
        assertEquals(listOf(system), model.state.value.records)
        assertTrue(model.state.value.pendingDeletes.isEmpty())
    }

    @Test fun aPutDoesNotBringBackADraftWhoseDeleteIsQueued() = runTest {
        val requests = Channel<PendingRequest>(Channel.UNLIMITED)
        val model = ChoreCatalogViewModel(delayedServer(requests).repository)
        val initial = async { model.refresh("u1") }
        requests.receive().complete(listOf(system, draft))
        initial.await()

        val save = async { model.save(system.asNewUserRecord) }
        val firstPut = requests.receive()
        val delete = async(start = CoroutineStart.UNDISPATCHED) { model.delete(draft) }
        runCurrent()
        firstPut.complete()
        val deletePut = requests.receive()
        assertNull(save.await())
        assertFalse(model.state.value.records.any { it.id == draft.id })
        deletePut.complete()
        assertNull(delete.await())
        assertEquals(2, model.state.value.records.size)
    }

    @Test fun signOutCancelsAnOldPutAndAllQueuedWorkBeforeTheNewAccountSends() = runTest {
        val requests = Channel<PendingRequest>(Channel.UNLIMITED)
        val token = AtomicReference("A")
        val server = delayedServer(requests, ignoreCancellation = true, token = token::get)
        val model = ChoreCatalogViewModel(server.repository)
        model.setOwner("A")
        val oldSave = async { model.save(draft) }
        val oldPut = requests.receive()
        assertEquals("Bearer A", oldPut.request.headers["Authorization"])

        val queuedSave = async(start = CoroutineStart.UNDISPATCHED) { model.save(system.asNewUserRecord) }
        val queuedDelete = async(start = CoroutineStart.UNDISPATCHED) { model.delete(draft) }
        val queuedRefresh = async(start = CoroutineStart.UNDISPATCHED) { model.refresh("A") }
        runCurrent()
        assertEquals(setOf(draft.id), model.state.value.pendingDeletes)
        model.setOwner(null)
        assertEquals(ChoreCatalogUiState(), model.state.value)
        token.set("B")
        model.setOwner("B")
        val fresh = async { model.refresh("B") }

        oldPut.complete()
        val newGet = requests.receive()
        assertEquals("GET", newGet.request.method)
        assertEquals("Bearer B", newGet.request.headers["Authorization"])
        assertTrue("old PUT results are discarded", model.state.value.records.isEmpty())
        val bDraft = draft.copy(title = "B taslağı", userId = "B")
        newGet.complete(listOf(bDraft))
        fresh.await()
        listOf(oldSave, queuedSave, queuedDelete, queuedRefresh).forEach { assertCancelled(it) }
        assertEquals(listOf(bDraft), model.state.value.records)
        assertTrue(model.state.value.pendingDeletes.isEmpty())
        assertTrue("only A's first PUT and B's GET were sent", requests.tryReceive().isFailure)
    }

    @Test fun signOutDiscardsALateGetAndCancelsItsQueuedSave() = runTest {
        val requests = Channel<PendingRequest>(Channel.UNLIMITED)
        val token = AtomicReference("A")
        val server = delayedServer(requests, ignoreCancellation = true, token = token::get)
        val model = ChoreCatalogViewModel(server.repository)
        val oldRefresh = async { model.refresh("A") }
        val oldGet = requests.receive()
        val queuedSave = async(start = CoroutineStart.UNDISPATCHED) { model.save(draft) }
        runCurrent()

        model.setOwner(null)
        assertEquals(ChoreCatalogUiState(), model.state.value)
        token.set("B")
        val fresh = async { model.refresh("B") }
        oldGet.complete(listOf(draft))
        val newGet = requests.receive()
        assertEquals("Bearer A", oldGet.request.headers["Authorization"])
        assertEquals("Bearer B", newGet.request.headers["Authorization"])
        assertEquals("GET", newGet.request.method)
        assertTrue(model.state.value.records.isEmpty())
        newGet.complete(listOf(system))
        fresh.await()
        assertCancelled(oldRefresh)
        assertCancelled(queuedSave)
        assertEquals(listOf(system), model.state.value.records)
        assertTrue(server.sent.isEmpty())
        assertTrue(requests.tryReceive().isFailure)
    }

    @Test fun signOutDoesNotRestoreADraftFromALateDeleteFailure() = runTest {
        val requests = Channel<PendingRequest>(Channel.UNLIMITED)
        val server = delayedServer(requests, ignoreCancellation = true)
        val model = ChoreCatalogViewModel(server.repository)
        val initial = async { model.refresh("A") }
        requests.receive().complete(listOf(draft))
        initial.await()
        val delete = async { model.delete(draft) }
        val oldPut = requests.receive()
        assertEquals(setOf(draft.id), model.state.value.pendingDeletes)

        model.setOwner(null)
        model.setOwner("B")
        assertEquals(ChoreCatalogUiState(), model.state.value)
        val refresh = async { model.refresh("B") }
        server.upsertFailure = ChoreCatalogFailure(ChoreCatalogFailure.Kind.SERVER)
        oldPut.complete()
        val newGet = requests.receive()
        assertTrue(model.state.value.records.isEmpty())
        newGet.complete(listOf(system))
        refresh.await()
        assertCancelled(delete)
        assertEquals(listOf(system), model.state.value.records)
        assertTrue(model.state.value.pendingDeletes.isEmpty())
        assertTrue(requests.tryReceive().isFailure)
    }

    @Test fun signOutClearsTheListBeforeTheSameUserSignsInAgain() = runTest {
        val server = FakeServer().apply { list = listOf(system) }
        val model = ChoreCatalogViewModel(server.repository)
        model.refresh("A")
        model.setOwner(null)
        assertEquals(ChoreCatalogUiState(), model.state.value)
        model.setOwner("A")
        assertEquals(ChoreCatalogUiState(), model.state.value)

        val translated = system.copy(title = "Wash the dishes")
        server.list = listOf(translated)
        model.refresh("A")
        assertEquals(listOf(translated), model.state.value.records)
    }

    @Test fun cancellingThePopupCallerDoesNotCancelItsPut() = runTest {
        val requests = Channel<PendingRequest>(Channel.UNLIMITED)
        val model = ChoreCatalogViewModel(delayedServer(requests).repository)
        model.setOwner("u1")
        val popup = async { model.save(draft) }
        val put = requests.receive()
        popup.cancel()
        assertCancelled(popup)

        put.complete()
        model.state.first { it.records.any { record -> record.id == draft.id } }
        assertEquals("PUT", put.request.method)
        assertEquals(draft.title, model.state.value.records.single().title)
    }

    @Test fun concurrentRefreshesWaitForOneGet() = runTest {
        val requests = Channel<PendingRequest>(Channel.UNLIMITED)
        val server = delayedServer(requests)
        val model = ChoreCatalogViewModel(server.repository)
        val first = async { model.refresh("u1") }
        val get = requests.receive()
        val second = async(start = CoroutineStart.UNDISPATCHED) { model.refresh("u1") }
        runCurrent()
        assertFalse(second.isCompleted)
        assertTrue(requests.tryReceive().isFailure)
        get.complete(listOf(system))
        first.await()
        second.await()
        assertEquals(1, server.fetchCount)
        assertTrue(requests.tryReceive().isFailure)
    }

    @Test fun withoutARepositoryTheCatalogShowsItsErrorState() = runTest {
        val model = ChoreCatalogViewModel(null)
        model.refresh("u1")
        assertEquals(ChoreCatalogUiState.Phase.Failed(ChoreCatalogFailure(ChoreCatalogFailure.Kind.SERVER)), model.state.value.phase)
    }
}
