package com.fauscrew.platform

import com.fauscrew.androidbridge.FausCrewAndroidBridge
import com.fauscrew.push.PushLog
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

internal interface NotificationWire {
    fun request(action: String, fieldsJson: String): String
    fun response(action: String, status: Int, body: String): String
}

private object NativeNotificationWire : NotificationWire {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    override fun request(action: String, fieldsJson: String): String {
        checked
        return FausCrewAndroidBridge.notificationRequest(action, fieldsJson)
    }

    override fun response(action: String, status: Int, body: String): String {
        checked
        return FausCrewAndroidBridge.notificationResponse(action, status, body)
    }
}

/** A failed notification request; [kind] is Core's `NotificationFailure.Kind` raw value. */
internal class NotificationRequestException(val kind: String, val status: Int?, message: String?) : Exception(message)

/** One panel row as the bridge returns it (the wire shape, so it can be handed back to Core unchanged). */
internal data class NotificationItem(
    val id: String, val type: String, val houseId: String, val senderUserId: String,
    val choreId: String?, val title: String, val message: String, val createdAt: String,
) {
    val isChoreReminder: Boolean get() = type == "chore_reminder"

    fun toJson(): JSONObject = JSONObject().put("id", id).put("type", type).put("houseId", houseId)
        .put("senderUserId", senderUserId).put("title", title).put("message", message).put("createdAt", createdAt)
        .also { if (choreId != null) it.put("choreId", choreId) }
}

internal data class NotificationPageData(val items: List<NotificationItem>, val nextCursor: String?)

/** Device registration, the notification list and chore reminders. The caller passes the JWT, so sign-out can use the one from before the session was cleared. */
internal class NotificationRepository(
    private val send: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    private val wire: NotificationWire = NativeNotificationWire,
) {
    /** Returns the HTTP status of the accepted request. */
    suspend fun registerDevice(token: String, jwt: String): Int =
        call("register", JSONObject().put("token", token).put("platform", "android"), jwt, PushLog.shortToken(token)).first

    suspend fun unregisterDevice(token: String, jwt: String): Int =
        call("unregister", JSONObject().put("token", token), jwt, PushLog.shortToken(token)).first

    /** One page, newest first; [before] is the previous page's cursor. */
    suspend fun list(houseId: String, before: String?, limit: Int, jwt: String): NotificationPageData {
        val fields = JSONObject().put("houseId", houseId).put("limit", limit)
        if (before != null) fields.put("before", before)
        val result = call("list", fields, jwt).second
        val items = result.getJSONArray("items")
        return NotificationPageData(
            items = List(items.length()) { index ->
                items.getJSONObject(index).let {
                    NotificationItem(
                        id = it.getString("id"), type = it.getString("type"), houseId = it.getString("houseId"),
                        senderUserId = it.getString("senderUserId"), choreId = it.optString("choreId").ifEmpty { null },
                        title = it.getString("title"), message = it.getString("message"), createdAt = it.getString("createdAt"),
                    )
                }
            },
            nextCursor = result.optString("nextCursor").ifEmpty { null },
        )
    }

    /** Throws [NotificationRequestException] kind `alreadyReminded` on 409. */
    suspend fun remind(choreId: String, jwt: String) {
        call("remind", JSONObject().put("choreId", choreId), jwt)
    }

    private suspend fun call(action: String, fields: JSONObject, jwt: String, tokenForLog: String? = null): Pair<Int, JSONObject> =
        withContext(Dispatchers.IO) {
            val request = JSONObject(wire.request(action, fields.toString()))
            if (!request.optBoolean("ok")) throw NotificationRequestException(request.optString("kind"), null, null)
            val body = request.optString("body").ifEmpty { null }
            val query = request.optJSONArray("query")
            val response = send(PlatformHttpRequest(
                path = request.getString("path"), method = request.getString("method"),
                queryItems = List(query?.length() ?: 0) { index ->
                    query!!.getJSONObject(index).let { PlatformHttpQueryItem(it.getString("name"), it.getString("value")) }
                },
                headers = mapOf("Authorization" to "Bearer $jwt") +
                    (if (body != null) mapOf("Content-Type" to "application/json") else emptyMap()),
                body = body?.toByteArray(Charsets.UTF_8),
            ))
            PushLog.d("${request.getString("method")} ${request.getString("path")} " +
                (if (tokenForLog != null) "platform=android token=$tokenForLog " else "") + "-> ${response.statusCode}")
            val result = JSONObject(wire.response(action, response.statusCode, response.body.decodeToString()))
            if (!result.optBoolean("ok")) {
                throw NotificationRequestException(
                    result.optString("kind"), response.statusCode, result.optString("message").ifEmpty { null })
            }
            response.statusCode to result
        }

    companion object {
        fun live(http: AndroidHttpAdapter) = NotificationRepository(http::send)
    }
}
