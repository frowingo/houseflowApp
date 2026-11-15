package com.fauscrew.platform

import android.content.Context
import com.fauscrew.androidbridge.FausCrewAndroidBridge
import java.io.IOException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

internal data class HouseSummary(val id: String, val name: String, val profileImage: String)
internal data class HouseDetails(
    val id: String, val name: String,
    val ownerId: String = "",
    val members: List<HouseMember> = emptyList(),
    val chores: List<HouseChore> = emptyList(),
    val announcements: List<HouseAnnouncement> = emptyList(),
    val isChoreReviewPhotoRequired: Boolean = false,
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
    /** Review rounds that carry a photo; storage keys never reach the client. */
    val reviewPhotoRounds: List<Int> = emptyList(),
    /** Raw `ChoreCategoryKind`; `0` when absent (backends before categories) or uncategorized. */
    val category: Int = 0,
    /** Set for Failed chores only; Core decides it (`HouseChoreDTO.failureReason`). */
    val failureReason: ChoreFailureReason? = null,
) {
    val categoryKind: ChoreCategoryKind get() = ChoreCategoryKind.of(category)
}

/**
 * Wire `ChoreCategory` (iOS/Core `ChoreCategoryKind`). `0` means no category; values this build
 * does not know are read as uncategorized too. Names are localized by the catalog UI.
 */
internal enum class ChoreCategoryKind(val raw: Int) {
    UNCATEGORIZED(0), KITCHEN(1), BATH_LAUNDRY(2), TOILET(3), ROOMS(4), FLOORS_GENERAL(5),
    PETS(6), TRASH_RECYCLING(7), PLANTS_BALCONY(8), SHOPPING_HOME(9);

    /** The values a request may carry (1–9). */
    val isAssignable: Boolean get() = this != UNCATEGORIZED

    companion object {
        fun of(raw: Int?): ChoreCategoryKind = entries.firstOrNull { it.raw == raw } ?: UNCATEGORIZED
        val assignable: List<ChoreCategoryKind> get() = entries.filter { it.isAssignable }
    }
}

/** `ChoreStatus.failed`: terminal and backend-owned; the client never sends it. */
internal const val CHORE_STATUS_FAILED = 4

/**
 * Why a chore failed (Core `ChoreFailureReason`). The API does not say, so Core names a reason
 * only when the status history proves it; anything else stays [UNSPECIFIED].
 */
internal enum class ChoreFailureReason(val wire: String) {
    DUE_DATE_PASSED("dueDatePassed"),
    UNSPECIFIED("unspecified"),
    ;

    companion object {
        fun fromWire(value: String?): ChoreFailureReason? = entries.firstOrNull { it.wire == value }
    }
}
internal data class HouseAnnouncement(
    val id: String, val houseId: String?, val title: String, val message: String,
    val createdOn: String, val isActive: Boolean, val publisherId: String?, val publisherName: String?,
)
internal data class HouseInvite(val code: String, val expiresInSeconds: Int)
internal data class HouseInfoMember(val userId: String, val name: String, val profileImage: String, val isOwner: Boolean)
internal data class HouseInfo(
    val payload: String,
    val houseName: String = "",
    val houseProfileImage: String = "",
    val houseType: Int = 0,
    val houseMemberCount: Int = 0,
    val houseMemberCountLimit: Int = 2,
    val members: List<HouseInfoMember> = emptyList(),
    val isChoreReviewPhotoRequired: Boolean = false,
) {
    val ownerId: String? get() = members.firstOrNull { it.isOwner }?.userId
}

private fun JSONObject.toHouseInfo() = HouseInfo(
    payload = toString(), houseName = getString("houseName"),
    houseProfileImage = optString("houseProfileImage"), houseType = getInt("houseType"),
    houseMemberCount = getInt("houseMemberCount"), houseMemberCountLimit = getInt("houseMemberCountLimit"),
    members = optJSONArray("houseMembers").objects {
        HouseInfoMember(it.getString("userId"), it.getString("name"), it.optString("profileImage"), it.getBoolean("isOwner"))
    },
    isChoreReviewPhotoRequired = optBoolean("isChoreReviewPhotoRequired", false),
)

internal class HouseRequestException(val serverMessage: String?, val status: Int? = null) : IOException(serverMessage ?: "House request failed")

/**
 * Core decodes the house and chore responses and the bridge hands Android their normalized form
 * (one key per field, aliases and time shapes resolved); Android owns transport and screens.
 */
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
        HouseDetails(id, data.getString("name"), data.optString("ownerId"),
            data.optJSONArray("members").objects { it.toHouseMember() },
            data.optJSONArray("chores").objects { it.toHouseChore() },
            data.optJSONArray("announcements").objects { it.toHouseAnnouncement() },
            data.optBoolean("isChoreReviewPhotoRequired", false))
    }

    suspend fun info(houseId: String): HouseInfo = withContext(Dispatchers.IO) {
        call("info", "house/infos", "GET", queryHouse = houseId).toHouseInfo()
    }

    suspend fun invite(houseId: String): HouseInvite = withContext(Dispatchers.IO) {
        val data = call("invite", "house/inviteCode", "POST", body = wire.body("invite", houseId = houseId))
        HouseInvite(data.getString("inviteCode"), data.getInt("expiresInSeconds"))
    }

    suspend fun exit(houseId: String, userId: String) = withContext(Dispatchers.IO) {
        call("exit", "house/exit", "POST", body = wire.body("exit", houseId = houseId, userId = userId))
    }

    suspend fun updateProfile(
        houseId: String, name: String, type: Int, maxMemberCount: Int, profileImage: String,
        isChoreReviewPhotoRequired: Boolean,
    ): HouseInfo = withContext(Dispatchers.IO) {
        call("profile", "house/profile", "PUT", queryHouse = houseId,
            body = wire.body("profile", houseId = houseId, name = name, type = type,
                maxMemberCount = maxMemberCount, profileImage = profileImage,
                isChoreReviewPhotoRequired = isChoreReviewPhotoRequired)).toHouseInfo()
    }

    private suspend fun call(
        action: String, path: String, method: String, queryHouse: String? = null, body: String? = null,
    ): JSONObject {
        val token = when (val value = read(SessionField.AUTH_TOKEN)) {
            is SessionReadResult.Value -> value.value
            else -> throw HouseRequestException(null, 401)
        }
        val response = send(PlatformHttpRequest(
            path = path, method = method,
            queryItems = if (queryHouse == null) emptyList() else listOf(PlatformHttpQueryItem("houseId", queryHouse)),
            headers = mapOf("Authorization" to "Bearer $token") +
                (if (body != null) mapOf("Content-Type" to "application/json") else emptyMap()),
            body = body?.toByteArray(Charsets.UTF_8),
        ))
        val result = JSONObject(wire.response(action, response.statusCode, response.body.decodeToString()))
        if (!result.optBoolean("success")) throw HouseRequestException(result.optString("error").ifBlank { null }, response.statusCode)
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
    dueDate = optString("dueDate"), status = optInt("status"), isCompleted = optBoolean("isCompleted"),
    isRecurring = optBoolean("isRecurring"), level = optInt("level", 10),
    recurringInterval = optInt("recurringInterval"), reviewRound = optInt("reviewRound"),
    reviewVotes = optJSONArray("reviewVotes").objects { it.toHouseVote() },
    reviewPhotoRounds = optJSONArray("reviewPhotoRounds")?.let { rounds ->
        (0 until rounds.length()).mapNotNull { index -> (rounds.opt(index) as? Number)?.toInt() }
    }.orEmpty(),
    category = optInt("category", 0),
    failureReason = ChoreFailureReason.fromWire(optString("failureReason")),
)

internal fun JSONObject.toHouseVote() = HouseVote(optInt("reviewRound"), optString("reviewerId"), optBoolean("isApproved"))

internal fun JSONObject.toHouseAnnouncement() = HouseAnnouncement(
    id = getString("id"), houseId = optString("houseId").takeIf(String::isNotBlank), title = getString("title"),
    message = optString("message"), createdOn = optString("createdOn"), isActive = optBoolean("isActive", true),
    publisherId = optString("publisherId").takeIf(String::isNotBlank),
    publisherName = optString("publisherName").takeIf(String::isNotBlank),
)

internal interface HouseWire {
    fun body(action: String, houseId: String = "", userId: String = "", name: String = "", inviteCode: String = "",
        type: Int = 0, maxMemberCount: Int = 0, profileImage: String = "",
        isChoreReviewPhotoRequired: Boolean = false): String
    fun response(action: String, status: Int, body: String): String
}

private object NativeHouseWire : HouseWire {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    override fun body(action: String, houseId: String, userId: String, name: String, inviteCode: String,
        type: Int, maxMemberCount: Int, profileImage: String, isChoreReviewPhotoRequired: Boolean): String {
        checked
        return FausCrewAndroidBridge.houseRequestBody(action, houseId, userId, name, inviteCode,
            type, maxMemberCount, profileImage, isChoreReviewPhotoRequired)
    }

    override fun response(action: String, status: Int, body: String): String {
        checked
        return FausCrewAndroidBridge.houseResponse(action, status, body)
    }
}
