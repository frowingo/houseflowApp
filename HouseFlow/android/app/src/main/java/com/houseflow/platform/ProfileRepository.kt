package com.houseflow.platform

import android.content.Context
import com.houseflow.androidbridge.HouseFlowAndroidBridge
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

internal data class ProfileImage(val url: String, val publicId: String)

internal data class ProfileChange(
    val imageUrl: String? = null,
    val birthDay: String? = null,
    val firstName: String? = null,
    val lastName: String? = null,
    val phoneNumber: String? = null,
    val language: String? = null,
)

internal interface ProfileWire {
    fun body(change: ProfileChange): String
    fun update(status: Int, body: String): String
    fun images(status: Int, body: String): String
}

private object NativeProfileWire : ProfileWire {
    private val checked by lazy { check(HouseFlowAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }
    override fun body(change: ProfileChange): String {
        checked
        return HouseFlowAndroidBridge.profileUpdateRequestBody(
            change.imageUrl.orEmpty(), change.birthDay.orEmpty(), change.firstName.orEmpty(),
            change.lastName.orEmpty(), change.phoneNumber.orEmpty(), change.language.orEmpty(),
        )
    }
    override fun update(status: Int, body: String): String {
        checked
        return HouseFlowAndroidBridge.profileUpdateResponse(status, body)
    }
    override fun images(status: Int, body: String): String {
        checked
        return HouseFlowAndroidBridge.profileImagesResponse(status, body)
    }
}

/** Platform transport with Swift DTO validation at one JNI call per operation. */
internal class ProfileRepository(
    private val send: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    private val read: (SessionField) -> SessionReadResult,
    private val wire: ProfileWire = NativeProfileWire,
) {
    suspend fun update(userId: String, change: ProfileChange): ProfileChange = withContext(Dispatchers.IO) {
        val response = send(PlatformHttpRequest(
            "user/profile/$userId", "PUT", listOf(PlatformHttpQueryItem("userId", userId)),
            authHeaders() + ("Content-Type" to "application/json"), wire.body(change).toByteArray(),
        ))
        val result = JSONObject(wire.update(response.statusCode, response.body.decodeToString()))
        if (!result.optBoolean("ok")) throw AuthRequestException(result.optString("message").ifBlank { null })
        ProfileChange(
            imageUrl = result.optString("imageUrl"), birthDay = result.optString("birthDay"),
            firstName = result.optString("firstName"), lastName = result.optString("lastName"),
            phoneNumber = result.optString("phoneNumber"), language = result.optString("language"),
        )
    }

    suspend fun images(category: String): List<ProfileImage> = withContext(Dispatchers.IO) {
        val response = send(PlatformHttpRequest("user/getImages", "GET",
            listOf(PlatformHttpQueryItem("category", category)), authHeaders()))
        val result = JSONObject(wire.images(response.statusCode, response.body.decodeToString()))
        if (!result.optBoolean("ok")) throw AuthRequestException(result.optString("message").ifBlank { null })
        result.getJSONArray("images").let { array ->
            (0 until array.length()).map { index ->
                array.getJSONObject(index).let { ProfileImage(it.getString("url"), it.getString("publicId")) }
            }
        }
    }

    private fun authHeaders(): Map<String, String> {
        val token = (read(SessionField.AUTH_TOKEN) as? SessionReadResult.Value)?.value
            ?: throw AuthRequestException(null)
        return mapOf("Authorization" to "Bearer $token")
    }

    companion object {
        fun live(context: Context, http: AndroidHttpAdapter): ProfileRepository {
            val store = KeystoreSessionStore(context)
            return ProfileRepository(http::send, store::read)
        }
    }
}
