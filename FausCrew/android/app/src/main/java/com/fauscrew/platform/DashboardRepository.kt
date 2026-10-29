package com.fauscrew.platform

import android.content.Context
import com.fauscrew.androidbridge.FausCrewAndroidBridge
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONArray
import org.json.JSONObject

internal data class ChoreInput(
    val houseId: String, val assignedTo: String, val title: String, val description: String,
    val dueDate: String, val isRecurring: Boolean, val level: Int, val recurringInterval: Int,
)

internal interface DashboardWire {
    fun body(action: String, houseId: String = "", choreId: String = "", assignedTo: String = "",
        title: String = "", description: String = "", dueDate: String = "", isRecurring: Boolean = false,
        level: Int = 10, recurringInterval: Int = 0, status: Int = 0, isApproved: Boolean = false): String
    fun response(action: String, status: Int, body: String): String
}

private object NativeDashboardWire : DashboardWire {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    override fun body(action: String, houseId: String, choreId: String, assignedTo: String, title: String,
        description: String, dueDate: String, isRecurring: Boolean, level: Int, recurringInterval: Int,
        status: Int, isApproved: Boolean): String {
        checked
        return FausCrewAndroidBridge.dashboardRequestBody(action, houseId, choreId, assignedTo, title,
            description, dueDate, isRecurring, level, recurringInterval, status, isApproved)
    }

    override fun response(action: String, status: Int, body: String): String {
        checked
        return FausCrewAndroidBridge.dashboardResponse(action, status, body)
    }
}

/** A coarse JNI call for each mutation; the returned DTO is merged without a second fetch. */
internal class DashboardRepository(
    private val send: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    private val read: (SessionField) -> SessionReadResult,
    private val wire: DashboardWire = NativeDashboardWire,
    /** Fetches a signed storage URL with no Bearer token and no cache. */
    private val download: suspend (String) -> PlatformHttpResponse = { throw HouseRequestException(null) },
    private val nowMillis: () -> Long = System::currentTimeMillis,
) {
    suspend fun createChore(input: ChoreInput): HouseChore = withContext(Dispatchers.IO) {
        choreCall("create", "chore", "POST", input)
    }

    suspend fun updateChore(choreId: String, input: ChoreInput): HouseChore =
        withContext(Dispatchers.IO) { choreCall("update", "chore/$choreId", "PUT", input) }

    private suspend fun choreCall(action: String, path: String, method: String, input: ChoreInput): HouseChore {
        val data = call(action, path, method, wire.body(action, houseId = input.houseId,
            choreId = if (action == "update") path.substringAfterLast('/') else "",
            assignedTo = input.assignedTo, title = input.title, description = input.description,
            dueDate = input.dueDate, isRecurring = input.isRecurring, level = input.level,
            recurringInterval = input.recurringInterval))
        return JSONObject(data).toHouseChore()
    }

    suspend fun updateStatus(houseId: String, choreId: String, status: Int): List<HouseChore> = withContext(Dispatchers.IO) {
        val data = call("status", "chore/status", "PUT", wire.body("status", houseId, choreId, status = status))
        JSONArray(data).objects { it.toHouseChore() }
    }

    /** Multipart `PUT chore/status`: exactly one chore moving to InTest with its photo. */
    suspend fun updateStatusWithReviewPhoto(houseId: String, choreId: String, photo: ReviewPhoto): List<HouseChore> =
        withContext(Dispatchers.IO) {
            val chores = wire.body("statusPhoto", houseId, choreId, status = 2)
            val data = call("statusPhoto", "chore/status", "PUT", multipart = listOf(
                PlatformMultipartPart("houseId", houseId.toByteArray(Charsets.UTF_8)),
                PlatformMultipartPart("chores", chores.toByteArray(Charsets.UTF_8)),
                PlatformMultipartPart("file", photo.bytes, photo.fileName, photo.mimeType),
            ))
            JSONArray(data).objects { it.toHouseChore() }
        }

    /**
     * Asks for a fresh signed URL each time; the URL never leaves this call. An already
     * expired URL or a storage 403 gets exactly one refresh.
     */
    suspend fun loadReviewPhoto(choreId: String, round: Int): ByteArray = withContext(Dispatchers.IO) {
        var canRefresh = true
        var signed = reviewPhotoUrl(choreId, round)
        if (signed.isExpired(nowMillis())) {
            canRefresh = false
            signed = reviewPhotoUrl(choreId, round)
        }
        var response = download(signed.url)
        if (response.statusCode == 403 && canRefresh) {
            signed = reviewPhotoUrl(choreId, round)
            response = download(signed.url)
        }
        if (response.statusCode !in 200..299) throw HouseRequestException(null)
        response.body
    }

    private suspend fun reviewPhotoUrl(choreId: String, round: Int): SignedReviewPhotoUrl {
        val data = JSONObject(call("reviewPhoto", "chore/$choreId/review-photo/$round", "GET"))
        return SignedReviewPhotoUrl(data.getString("url"), data.getString("expiresAt"))
    }

    suspend fun review(choreId: String, isApproved: Boolean): HouseChore = withContext(Dispatchers.IO) {
        JSONObject(call("review", "chore/review", "PUT",
            wire.body("review", choreId = choreId, isApproved = isApproved))).toHouseChore()
    }

    suspend fun announce(houseId: String, title: String, message: String): HouseAnnouncement = withContext(Dispatchers.IO) {
        val data = JSONObject(call("announcement", "house/announcement", "POST",
            wire.body("announcement", houseId = houseId, title = title, description = message)))
        data.getJSONObject("data").toHouseAnnouncement()
    }

    private suspend fun call(
        action: String, path: String, method: String, body: String? = null,
        multipart: List<PlatformMultipartPart>? = null,
    ): String = withContext(Dispatchers.IO) {
        val token = (read(SessionField.AUTH_TOKEN) as? SessionReadResult.Value)?.value
            ?: throw HouseRequestException(null)
        val response = send(PlatformHttpRequest(path = path, method = method,
            headers = mapOf("Authorization" to "Bearer $token") +
                (if (body != null) mapOf("Content-Type" to "application/json") else emptyMap()),
            body = body?.toByteArray(Charsets.UTF_8), multipart = multipart))
        val result = JSONObject(wire.response(action, response.statusCode, response.body.decodeToString()))
        if (!result.optBoolean("ok")) throw HouseRequestException(result.optString("message").ifBlank { null })
        result.getString("data")
    }

    companion object {
        fun live(context: Context, http: AndroidHttpAdapter): DashboardRepository {
            val store = KeystoreSessionStore(context)
            return DashboardRepository(http::send, store::read, download = RemoteImageLoader::fetchUncached)
        }
    }
}
