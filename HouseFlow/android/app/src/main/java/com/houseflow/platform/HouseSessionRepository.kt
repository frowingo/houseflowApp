package com.houseflow.platform

import android.content.Context
import com.houseflow.androidbridge.HouseFlowAndroidBridge
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

internal data class HouseSummary(val id: String, val name: String, val profileImage: String)
internal data class HouseDetails(
    val id: String, val name: String, val payload: String,
    val ownerId: String = "",
    val members: List<HouseMember> = emptyList(),
    val chores: List<HouseChore> = emptyList(),
    val announcements: List<HouseAnnouncement> = emptyList(),
)
internal data class HouseMember(val id: String, val firstName: String, val lastName: String, val imageUrl: String) {
    val name: String get() = listOf(firstName, lastName).filter(String::isNotBlank).joinToString(" ")
}
internal data class HouseVote(val reviewRound: Int, val reviewerId: String, val isApproved: Boolean)
internal data class HouseChore(
    val id: String, val houseId: String, val title: String, val description: String,
    val assignedTo: String, val dueDate: String, val status: Int, val isCompleted: Boolean,
    val isRecurring: Boolean, val level: Int, val recurringInterval: Int,
    val reviewRound: Int, val reviewVotes: List<HouseVote>,
)
internal data class HouseAnnouncement(
    val id: String, val houseId: String?, val title: String, val message: String,
    val createdOn: String, val isActive: Boolean, val publisherId: String?, val publisherName: String?,
)
internal data class HouseInvite(val code: String, val expiresInSeconds: Int)
internal data class HouseInfo(val payload: String)

internal class HouseRequestException(val serverMessage: String?) : IOException(serverMessage ?: "House request failed")

/** Swift validates the existing DTOs; Android owns transport and screen projections. */
internal class HouseSessionRepository(
    private val send: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    private val read: (SessionField) -> SessionReadResult,
    private val wire: HouseWire = NativeHouseWire,
) {
    suspend fun create(name: String, type: Int, maxMemberCount: Int): HouseSummary = withContext(Dispatchers.IO) {
        val data = call("create", "house/create", "POST", body = wire.body("create", name = name,
            type = type, maxMemberCount = maxMemberCount))
        HouseSummary(data.getString("id"), data.getString("name"), data.optString("profileImage"))
    }

    suspend fun join(code: String): HouseSummary = withContext(Dispatchers.IO) {
        val data = call("join", "house/join", "POST", body = wire.body("join", inviteCode = code))
        HouseSummary(data.getString("id"), data.getString("name"), data.optString("profileImage"))
    }

    suspend fun details(houseId: String): HouseDetails = withContext(Dispatchers.IO) {
        val data = call("details", "house/details", "GET", queryHouse = houseId)
        val id = data.getString("id")
        if (id != houseId) throw HouseRequestException(null)
        HouseDetails(id, data.getString("name"), data.toString(), data.optString("ownerId"),
            data.optJSONArray("members").objects { it.toHouseMember() },
            data.optJSONArray("chores").objects { it.toHouseChore() },
            (data.optJSONArray("announcements") ?: data.optJSONArray("activeAnnouncements"))
                .objects { it.toHouseAnnouncement() })
    }

    suspend fun info(houseId: String): HouseInfo = withContext(Dispatchers.IO) {
        HouseInfo(call("info", "house/infos", "GET", queryHouse = houseId).toString())
    }

    suspend fun invite(houseId: String): HouseInvite = withContext(Dispatchers.IO) {
        val data = call("invite", "house/inviteCode", "POST", body = wire.body("invite", houseId = houseId))
        HouseInvite(data.getString("inviteCode"), data.getInt("expiresInSeconds"))
    }

    suspend fun exit(houseId: String, userId: String) = withContext(Dispatchers.IO) {
        call("exit", "house/exit", "POST", body = wire.body("exit", houseId = houseId, userId = userId))
    }

    suspend fun updateProfile(houseId: String, name: String, type: Int, maxMemberCount: Int, profileImage: String): HouseInfo =
        withContext(Dispatchers.IO) {
            HouseInfo(call("profile", "house/profile", "PUT", queryHouse = houseId,
                body = wire.body("profile", houseId = houseId, name = name, type = type,
                    maxMemberCount = maxMemberCount, profileImage = profileImage)).toString())
        }

    private suspend fun call(
        action: String, path: String, method: String, queryHouse: String? = null, body: String? = null,
    ): JSONObject {
        val token = when (val value = read(SessionField.AUTH_TOKEN)) {
            is SessionReadResult.Value -> value.value
            else -> throw HouseRequestException(null)
        }
        val response = send(PlatformHttpRequest(
            path = path, method = method,
            queryItems = if (queryHouse == null) emptyList() else listOf(PlatformHttpQueryItem("houseId", queryHouse)),
            headers = mapOf("Authorization" to "Bearer $token") +
                (if (body != null) mapOf("Content-Type" to "application/json") else emptyMap()),
            body = body?.toByteArray(Charsets.UTF_8),
        ))
        val result = JSONObject(wire.response(action, response.statusCode, response.body.decodeToString()))
        if (!result.optBoolean("success")) throw HouseRequestException(result.optString("error").ifBlank { null })
        return if (action == "exit") JSONObject() else result.getJSONObject("data")
    }

    companion object {
        fun live(context: Context, http: AndroidHttpAdapter): HouseSessionRepository {
            val store = KeystoreSessionStore(context)
            return HouseSessionRepository(http::send, store::read)
        }
    }
}

internal fun <T> org.json.JSONArray?.objects(select: (JSONObject) -> T): List<T> =
    if (this == null) emptyList() else (0 until length()).mapNotNull { index -> optJSONObject(index)?.let(select) }

internal fun JSONObject.toHouseMember() = HouseMember(
    getString("id"), optString("firstName"), optString("lastName"), optString("imageUrl"),
)

internal fun JSONObject.toHouseChore() = HouseChore(
    id = getString("id"), houseId = getString("houseId"), title = getString("title"),
    description = optString("description"), assignedTo = optString("assignedTo"),
    dueDate = apiTime("dueDate"), status = optInt("status"), isCompleted = optBoolean("isCompleted"),
    isRecurring = optBoolean("isRecurring"), level = optInt("level", 10),
    recurringInterval = optInt("recurringInterval"), reviewRound = optInt("reviewRound"),
    reviewVotes = optJSONArray("reviewVotes").objects {
        HouseVote(it.optInt("reviewRound"), it.optString("reviewerId"), it.optBoolean("isApproved"))
    },
)

internal fun JSONObject.toHouseAnnouncement() = HouseAnnouncement(
    id = optString("id").ifBlank { getString("announcementId") },
    houseId = optString("houseId").takeIf(String::isNotBlank), title = getString("title"),
    message = listOf("message", "content", "description", "body").firstNotNullOfOrNull { key ->
        optString(key).takeIf(String::isNotBlank)
    } ?: "",
    createdOn = apiTime("createdOn").ifBlank { apiTime("createdAt") },
    isActive = optBoolean("isActive", true),
    publisherId = listOf("announcedBy", "createdById", "createdByUserId", "creatorId", "publisherId", "userId", "memberId")
        .firstNotNullOfOrNull { key -> optString(key).takeIf(String::isNotBlank) },
    publisherName = listOf("publisherName", "createdByName", "authorName")
        .firstNotNullOfOrNull { key -> optString(key).takeIf(String::isNotBlank) }
        ?: listOf(optString("createdByFirstName"), optString("createdByLastName"))
            .filter(String::isNotBlank).joinToString(" ").takeIf(String::isNotBlank)
        ?: listOf("createdByUser", "creator", "publisher", "author", "createdBy")
            .firstNotNullOfOrNull { key -> optJSONObject(key)?.let { nested ->
                nested.optString("fullName").takeIf(String::isNotBlank)
                    ?: nested.optString("name").takeIf(String::isNotBlank)
                    ?: listOf(nested.optString("firstName"), nested.optString("lastName"))
                        .filter(String::isNotBlank).joinToString(" ").takeIf(String::isNotBlank)
            } },
)

private fun JSONObject.apiTime(key: String): String = when (val value = opt(key)) {
    is JSONObject -> value.optString("time.Time")
    is String -> value
    else -> ""
}

internal interface HouseWire {
    fun body(action: String, houseId: String = "", userId: String = "", name: String = "", inviteCode: String = "",
        type: Int = 0, maxMemberCount: Int = 0, profileImage: String = ""): String
    fun response(action: String, status: Int, body: String): String
}

private object NativeHouseWire : HouseWire {
    private val checked by lazy { check(HouseFlowAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    override fun body(action: String, houseId: String, userId: String, name: String, inviteCode: String,
        type: Int, maxMemberCount: Int, profileImage: String): String {
        checked
        return HouseFlowAndroidBridge.houseRequestBody(action, houseId, userId, name, inviteCode,
            type, maxMemberCount, profileImage)
    }

    override fun response(action: String, status: Int, body: String): String {
        checked
        return HouseFlowAndroidBridge.houseResponse(action, status, body)
    }
}
