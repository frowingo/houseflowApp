package com.fauscrew.platform

import kotlinx.coroutines.runBlocking
import org.json.JSONObject
import org.junit.Assert.assertEquals
import org.junit.Assert.assertNull
import org.junit.Assert.assertThrows
import org.junit.Test

class NotificationRepositoryTest {
    private val requests = mutableListOf<PlatformHttpRequest>()
    private val fields = mutableListOf<Pair<String, String>>()
    private var status = 200
    private var requestJson = """{"ok":true,"path":"notification/devices","method":"POST","query":[],"body":"{\"token\":\"t1\"}"}"""
    private val wire = object : NotificationWire {
        override fun request(action: String, fieldsJson: String): String {
            fields += action to fieldsJson
            return requestJson
        }
        override fun response(action: String, status: Int, body: String): String =
            if (status in 200..299) """{"ok":true}"""
            else """{"ok":false,"kind":"notMember","message":"Denied"}"""
    }
    private val repo = NotificationRepository(
        send = { request -> requests += request; PlatformHttpResponse(status, emptyMap(), ByteArray(0)) }, wire = wire,
    )

    @Test fun registerPassesTheTokenAndPlatformToCoreAndSendsItsRequestWithTheJwt() = runBlocking {
        assertEquals(200, repo.registerDevice("t1", "jwt"))
        val (action, json) = fields.single()
        assertEquals("register", action)
        assertEquals("t1", JSONObject(json).getString("token"))
        assertEquals("android", JSONObject(json).getString("platform"))
        val request = requests.single()
        assertEquals("notification/devices", request.path)
        assertEquals("POST", request.method)
        assertEquals(mapOf("Authorization" to "Bearer jwt", "Content-Type" to "application/json"), request.headers)
        assertEquals("""{"token":"t1"}""", request.body!!.decodeToString())
    }

    @Test fun unregisterSendsTheDeleteBodyWithTheGivenJwt() = runBlocking {
        requestJson = """{"ok":true,"path":"notification/devices","method":"DELETE","query":[],"body":"{\"token\":\"t1\"}"}"""
        repo.unregisterDevice("t1", "old-jwt")
        assertEquals("unregister", fields.single().first)
        assertNull(JSONObject(fields.single().second).optString("platform").ifEmpty { null })
        assertEquals("DELETE", requests.single().method)
        assertEquals("Bearer old-jwt", requests.single().headers["Authorization"])
    }

    @Test fun aBodylessRequestGetsNoContentType() = runBlocking {
        requestJson = """{"ok":true,"path":"notification/devices","method":"POST","query":[]}"""
        repo.registerDevice("t1", "jwt")
        assertEquals(mapOf("Authorization" to "Bearer jwt"), requests.single().headers)
        assertNull(requests.single().body)
    }

    @Test fun serverRefusalsKeepKindStatusAndMessage() {
        status = 403
        val error = assertThrows(NotificationRequestException::class.java) { runBlocking { repo.registerDevice("t1", "jwt") } }
        assertEquals("notMember", error.kind)
        assertEquals(403, error.status)
        assertEquals("Denied", error.message)
    }

    @Test fun aRequestCoreRefusesIsNeverSent() {
        requestJson = """{"ok":false,"kind":"invalidRequest"}"""
        val error = assertThrows(NotificationRequestException::class.java) { runBlocking { repo.registerDevice(" ", "jwt") } }
        assertEquals("invalidRequest", error.kind)
        assertNull(error.status)
        assertEquals(0, requests.size)
    }

    private fun listRepo(responseJson: String, onSend: (PlatformHttpRequest) -> Unit = {}) = NotificationRepository(
        send = { request -> onSend(request); PlatformHttpResponse(status, emptyMap(), ByteArray(0)) },
        wire = object : NotificationWire {
            override fun request(action: String, fieldsJson: String): String {
                fields += action to fieldsJson
                return requestJson
            }
            override fun response(action: String, status: Int, body: String) = responseJson
        },
    )

    @Test fun listSendsTheQueryAndParsesThePage() = runBlocking {
        requestJson = """{"ok":true,"path":"notification","method":"GET","query":[{"name":"houseId","value":"h1"},{"name":"limit","value":"20"}]}"""
        val sent = mutableListOf<PlatformHttpRequest>()
        val page = listRepo("""{"ok":true,"items":[
            {"id":"n2","type":"chore_reminder","houseId":"h1","senderUserId":"u2","title":"T","message":"M","createdAt":"2026-11-21T10:00:00Z","choreId":"c1"},
            {"id":"n1","type":"announcement","houseId":"h1","senderUserId":"u3","title":"A","message":"B","createdAt":"2026-11-20T10:00:00Z"}],
            "nextCursor":"cur"}""", sent::add).list("h1", "before-1", 20, "jwt")
        val (action, json) = fields.single()
        assertEquals("list", action)
        assertEquals("h1", JSONObject(json).getString("houseId"))
        assertEquals("before-1", JSONObject(json).getString("before"))
        assertEquals(20, JSONObject(json).getInt("limit"))
        assertEquals(listOf(PlatformHttpQueryItem("houseId", "h1"), PlatformHttpQueryItem("limit", "20")), sent.single().queryItems)
        assertEquals("GET", sent.single().method)
        assertEquals("Bearer jwt", sent.single().headers["Authorization"])
        assertEquals("cur", page.nextCursor)
        assertEquals(listOf("n2", "n1"), page.items.map { it.id })
        assertEquals("c1", page.items[0].choreId)
        assertNull(page.items[1].choreId)
        assertEquals(true, page.items[0].isChoreReminder)
    }

    @Test fun listWithoutCursorHasNoNextPageAndNoBeforeField() = runBlocking {
        requestJson = """{"ok":true,"path":"notification","method":"GET","query":[]}"""
        val page = listRepo("""{"ok":true,"items":[]}""").list("h1", null, 20, "jwt")
        assertNull(page.nextCursor)
        assertEquals(true, page.items.isEmpty())
        assertEquals(false, JSONObject(fields.single().second).has("before"))
    }

    @Test fun remindPostsAndMapsAConflict() {
        requestJson = """{"ok":true,"path":"chore/c1/remind","method":"POST","query":[]}"""
        val sent = mutableListOf<PlatformHttpRequest>()
        runBlocking { listRepo("""{"ok":true}""", sent::add).remind("c1", "jwt") }
        assertEquals("chore/c1/remind", sent.single().path)
        assertEquals("c1", JSONObject(fields.single().second).getString("choreId"))
        status = 409
        val error = assertThrows(NotificationRequestException::class.java) {
            runBlocking { listRepo("""{"ok":false,"kind":"alreadyReminded"}""").remind("c1", "jwt") }
        }
        assertEquals("alreadyReminded", error.kind)
        assertEquals(409, error.status)
    }
}
