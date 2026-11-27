package com.fauscrew.platform

import com.fauscrew.androidbridge.FausCrewAndroidBridge
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

internal interface ChoreArchiveWire {
    fun request(action: String, fieldsJson: String): String
    fun response(status: Int, body: String): String
}

private object NativeChoreArchiveWire : ChoreArchiveWire {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    override fun request(action: String, fieldsJson: String): String {
        checked
        return FausCrewAndroidBridge.choreArchiveRequest(action, fieldsJson)
    }

    override fun response(status: Int, body: String): String {
        checked
        return FausCrewAndroidBridge.choreArchiveResponse(status, body)
    }
}

/** A failed archive request; [kind] is Core's `ChoreArchiveFailure.Kind` raw value. */
internal class ChoreArchiveRequestException(val kind: String, val status: Int?, message: String?) : Exception(message)

/** [nextUrl] is the server's cursor link, kept opaque; null on the last page. */
internal data class ChoreArchivePageData(val chores: List<HouseChore>, val nextUrl: String?)

/** Closed chores of a house by date range, in pages. The caller passes the JWT. */
internal class ChoreArchiveRepository(
    private val send: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    private val wire: ChoreArchiveWire = NativeChoreArchiveWire,
) {
    /** The first page of `[fromEpochSeconds, toEpochSeconds)`. */
    suspend fun firstPage(houseId: String, fromEpochSeconds: Long, toEpochSeconds: Long, jwt: String): ChoreArchivePageData =
        call("first", JSONObject().put("houseId", houseId)
            .put("fromEpochSeconds", fromEpochSeconds).put("toEpochSeconds", toEpochSeconds), jwt)

    /** The page after the one that returned [nextUrl]. */
    suspend fun nextPage(nextUrl: String, jwt: String): ChoreArchivePageData =
        call("next", JSONObject().put("nextUrl", nextUrl), jwt)

    // No logging: the cursor in the URL is opaque and must not reach the log.
    private suspend fun call(action: String, fields: JSONObject, jwt: String): ChoreArchivePageData =
        withContext(Dispatchers.IO) {
            val request = JSONObject(wire.request(action, fields.toString()))
            if (!request.optBoolean("ok")) throw ChoreArchiveRequestException(request.optString("kind"), null, null)
            val query = request.optJSONArray("query")
            val response = send(PlatformHttpRequest(
                path = request.getString("path"), method = request.getString("method"),
                queryItems = List(query?.length() ?: 0) { index ->
                    query!!.getJSONObject(index).let { PlatformHttpQueryItem(it.getString("name"), it.getString("value")) }
                },
                headers = mapOf("Authorization" to "Bearer $jwt"),
                encodedQuery = request.optString("percentEncodedQuery").ifEmpty { null },
            ))
            val result = JSONObject(wire.response(response.statusCode, response.body.decodeToString()))
            if (!result.optBoolean("ok")) {
                throw ChoreArchiveRequestException(
                    result.optString("kind"), response.statusCode, result.optString("message").ifEmpty { null })
            }
            ChoreArchivePageData(
                chores = result.getJSONArray("chores").objects { it.toHouseChore() },
                nextUrl = result.optString("nextUrl").ifEmpty { null },
            )
        }

    companion object {
        fun live(http: AndroidHttpAdapter) = ChoreArchiveRepository(http::send)
    }
}
