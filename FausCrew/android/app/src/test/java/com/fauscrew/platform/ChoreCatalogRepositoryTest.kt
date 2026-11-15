package com.fauscrew.platform

import kotlinx.coroutines.Job
import kotlinx.coroutines.async
import kotlinx.coroutines.runBlocking
import org.json.JSONArray
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertNull
import org.junit.Assert.assertTrue
import org.junit.Assert.fail
import org.junit.Test
import java.io.IOException
import kotlin.coroutines.cancellation.CancellationException

/**
 * `ChoreCatalogRepository` with a stand-in for the bridge: the request, the session header, the
 * records as the server sent them (`shared/Fixtures/choreCatalogApi.json`) and the failures.
 * The bridge itself is covered by `ChoreCatalogBridgeTests` in `android/swift-bridge`.
 */
class ChoreCatalogRepositoryTest {
    private val fixture: JSONObject by lazy {
        val stream = requireNotNull(javaClass.classLoader?.getResourceAsStream("choreCatalogApi.json"))
        JSONObject(stream.bufferedReader().use { it.readText() })
    }

    private val requests = mutableListOf<PlatformHttpRequest>()
    private var status = 200
    private var responseBody = "[]"
    private var bridgeResult: JSONObject? = null
    private var refuseBody = false
    private var token: String? = "token"
    private var transportError: Exception? = null
    private var preparingBody: (() -> Unit)? = null
    private val wireCalls = mutableListOf<Triple<String, String, String>>()

    private val wire = object : ChoreCatalogWire {
        override fun body(recordsJson: String): String {
            preparingBody?.invoke()
            return if (refuseBody) JSONObject().put("ok", false).put("kind", "validation").put("rule", "titleLength").toString()
            else JSONObject().put("ok", true).put("body", "SENT:$recordsJson").toString()
        }

        override fun response(action: String, status: Int, body: String, recordsJson: String, localJson: String): String {
            wireCalls += Triple(action, recordsJson, localJson)
            bridgeResult?.let { return it.toString() }
            return JSONObject().put("ok", true).put("records", JSONArray(body)).toString()
        }
    }

    private val repository = ChoreCatalogRepository(
        send = { request ->
            requests += request
            transportError?.let { throw it }
            PlatformHttpResponse(status, emptyMap(), responseBody.toByteArray())
        },
        read = { token?.let { SessionReadResult.Value(it) } ?: SessionReadResult.Missing },
        wire = wire,
    )

    private suspend fun failureOf(block: suspend () -> Unit): ChoreCatalogFailure {
        try {
            block()
        } catch (error: ChoreCatalogException) {
            return error.failure
        }
        fail("expected a ChoreCatalogException")
        error("unreachable")
    }

    @Test fun fetchReadsTheListWithTheSession() = runBlocking {
        responseBody = fixture.getJSONArray("list").toString()
        val records = repository.fetch()
        assertEquals("chore/catalog", requests.single().path)
        assertEquals("GET", requests.single().method)
        assertEquals("Bearer token", requests.single().headers["Authorization"])
        assertNull(requests.single().body)

        assertEquals(listOf("6730f1c2a1b2c3d4e5f60701", "6730f1c2a1b2c3d4e5f60702"), records.systemRecords.map { it.id })
        // Newest first: 10:00 before 09:15:00.250.
        assertEquals(listOf("6730f1c2a1b2c3d4e5f60719", "6730f1c2a1b2c3d4e5f60718"), records.userRecords.map { it.id })
        val system = records.first()
        assertEquals("", records[1].description)
        assertEquals(ChoreCategoryKind.KITCHEN, system.categoryKind)
        assertEquals("6730f1c2a1b2c3d4e5f60001", system.userId)
        assertEquals("2026-11-12T08:30:00Z", system.updatedOn)
    }

    @Test fun upsertSendsTheBridgeBodyAndThePatchInputs() = runBlocking {
        val local = ChoreCatalogRecord.decode(fixture.getJSONArray("list"))
        val record = ChoreCatalogRecord(title = "Balkonu süpür", level = 20, category = 8, recurringInterval = 14)
        responseBody = fixture.getJSONObject("upsert").getJSONArray("response").toString()
        repository.upsert(listOf(record), local)
        val request = requests.single()
        assertEquals("PUT", request.method)
        assertEquals("application/json", request.headers["Content-Type"])
        assertTrue(request.body!!.decodeToString().startsWith("SENT:"))
        val (action, sent, sentLocal) = wireCalls.single()
        assertEquals("upsert", action)
        assertEquals(listOf(record), ChoreCatalogRecord.decode(JSONArray(sent)))
        assertEquals(local, ChoreCatalogRecord.decode(JSONArray(sentLocal)))
    }

    @Test fun upsertKeepsTheTokenCapturedBeforeBodyPreparation() = runBlocking {
        token = "A"
        preparingBody = { token = "B" }
        repository.upsert(listOf(ChoreCatalogRecord(title = "Yeni", category = 1)), emptyList())
        assertEquals("Bearer A", requests.single().headers["Authorization"])

        repository.fetch()
        assertEquals("Bearer B", requests.last().headers["Authorization"])
    }

    @Test fun cancellationDuringBodyPreparationNeverSendsTheRequest() = runBlocking {
        val work = Job(coroutineContext[Job])
        preparingBody = { token = "B"; work.cancel() }
        val request = async(work) {
            repository.upsert(listOf(ChoreCatalogRecord(title = "Yeni", category = 1)), emptyList())
        }
        try {
            request.await()
            fail("expected CancellationException")
        } catch (_: CancellationException) {
            assertTrue(request.isCancelled)
        }
        assertTrue(requests.isEmpty())
    }

    @Test fun recordsKeepEveryFieldThroughJson() {
        val records = ChoreCatalogRecord.decode(fixture.getJSONArray("list"))
        assertEquals(records, ChoreCatalogRecord.decode(JSONArray(ChoreCatalogRecord.encode(records))))
        val fresh = ChoreCatalogRecord(title = "Yeni", category = 1)
        assertFalse(fresh.toJson().has("id"))
        assertNull(ChoreCatalogRecord.fromJson(JSONObject(fresh.toJson().toString()).put("id", "")).id)
    }

    @Test fun failuresCarryTheirKindAndServerMessage() = runBlocking {
        val errors = fixture.getJSONArray("errors")
        for (index in 0 until errors.length()) {
            val error = errors.getJSONObject(index)
            val message = error.getJSONObject("body").getString("error")
            bridgeResult = JSONObject().put("ok", false).put("kind", error.getString("kind")).put("message", message)
            val failure = failureOf { repository.fetch() }
            assertEquals(error.getString("kind"), failure.kind.wire)
            assertEquals(message, failure.message)
            assertEquals(error.getString("kind") == "notFound", failure.refreshesList)
        }
    }

    @Test fun noSessionNoConnectionAndRefusedBodiesNeverReachTheServerAsSuch() = runBlocking {
        token = null
        assertEquals(ChoreCatalogFailure.Kind.UNAUTHORIZED, failureOf { repository.fetch() }.kind)
        assertTrue(requests.isEmpty())

        token = "token"
        refuseBody = true
        assertEquals(ChoreCatalogFailure.Kind.VALIDATION,
            failureOf { repository.upsert(listOf(ChoreCatalogRecord(title = "ab", category = 1)), emptyList()) }.kind)
        assertTrue(requests.isEmpty())

        transportError = IOException("offline")
        val offline = failureOf { repository.fetch() }
        assertEquals(ChoreCatalogFailure.Kind.SERVER, offline.kind)
        assertNull(offline.message)
    }

    @Test fun rulesMirrorTheServer() {
        val valid = ChoreCatalogRecord(title = "Toz al", category = 4)
        assertTrue(ChoreCatalogRules.isValid(valid))
        assertTrue(ChoreCatalogRules.isValid(valid.copy(title = "  abc  ")))
        assertFalse(ChoreCatalogRules.isValid(valid.copy(title = " ab ")))
        assertFalse(ChoreCatalogRules.isValid(valid.copy(title = "a".repeat(201))))
        assertFalse(ChoreCatalogRules.isValid(valid.copy(description = "a".repeat(1001))))
        assertTrue(ChoreCatalogRules.isValid(valid.copy(description = "a".repeat(1000))))
        assertFalse(ChoreCatalogRules.isValid(valid.copy(recurringInterval = 366)))
        assertFalse(ChoreCatalogRules.isValid(valid.copy(level = 15)))
        assertFalse(ChoreCatalogRules.isValid(valid.copy(category = 0)))
        assertFalse(ChoreCatalogRules.isValid(valid.copy(category = 10)))
        assertFalse(ChoreCatalogRules.isValid(valid.copy(isSystem = true)))
        assertFalse(ChoreCatalogRules.isValid(valid.copy(isDeleted = true)))
        assertFalse(ChoreCatalogRules.isValid(valid.copy(id = "short")))
        assertTrue(ChoreCatalogRules.isValid(valid.copy(id = "6730f1c2a1b2c3d4e5f60718", isDeleted = true)))
    }
}
