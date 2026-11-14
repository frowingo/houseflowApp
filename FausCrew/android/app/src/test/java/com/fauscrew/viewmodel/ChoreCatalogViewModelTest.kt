package com.fauscrew.viewmodel

import com.fauscrew.platform.ChoreCatalogFailure
import com.fauscrew.platform.ChoreCatalogRecord
import com.fauscrew.platform.ChoreCatalogRepository
import com.fauscrew.platform.ChoreCatalogWire
import com.fauscrew.platform.PlatformHttpResponse
import com.fauscrew.platform.SessionReadResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.ExperimentalCoroutinesApi
import kotlinx.coroutines.test.UnconfinedTestDispatcher
import kotlinx.coroutines.test.resetMain
import kotlinx.coroutines.test.runTest
import kotlinx.coroutines.test.setMain
import org.json.JSONArray
import org.json.JSONObject
import org.junit.After
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Before
import org.junit.Test

/**
 * `ChoreCatalogViewModel` against a fake server (iOS `ChoreCatalogStoreTests`): the list is the
 * server's, PUT results patch it, a refused delete comes back, and a 404 fetches the list again.
 */
@OptIn(ExperimentalCoroutinesApi::class)
class ChoreCatalogViewModelTest {
    /** Stands in for the server and the bridge; patches like Core's `ChoreCatalogPatch`. */
    private class FakeServer {
        var list = listOf<ChoreCatalogRecord>()
        var fetchFailure: ChoreCatalogFailure? = null
        var upsertFailure: ChoreCatalogFailure? = null
        var fetchCount = 0
        val sent = mutableListOf<List<ChoreCatalogRecord>>()
        private var nextId = 0

        private fun ok(records: List<ChoreCatalogRecord>): String =
            JSONObject().put("ok", true).put("records", JSONArray(ChoreCatalogRecord.encode(records))).toString()

        private fun failed(failure: ChoreCatalogFailure): String =
            JSONObject().put("ok", false).put("kind", failure.kind.wire).put("message", failure.message ?: JSONObject.NULL).toString()

        val repository = ChoreCatalogRepository(
            send = { PlatformHttpResponse(200, emptyMap(), ByteArray(0)) },
            read = { SessionReadResult.Value("token") },
            wire = object : ChoreCatalogWire {
                override fun body(recordsJson: String): String = JSONObject().put("ok", true).put("body", recordsJson).toString()

                override fun response(action: String, status: Int, body: String, recordsJson: String, localJson: String): String {
                    if (action == "list") {
                        fetchCount += 1
                        return fetchFailure?.let(::failed) ?: ok(list)
                    }
                    val records = ChoreCatalogRecord.decode(JSONArray(recordsJson))
                    sent += records
                    upsertFailure?.let { return failed(it) }
                    val local = ChoreCatalogRecord.decode(JSONArray(localJson)).toMutableList()
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

    @Test fun withoutARepositoryTheCatalogShowsItsErrorState() = runTest {
        val model = ChoreCatalogViewModel(null)
        model.refresh("u1")
        assertEquals(ChoreCatalogUiState.Phase.Failed(ChoreCatalogFailure(ChoreCatalogFailure.Kind.SERVER)), model.state.value.phase)
    }
}
