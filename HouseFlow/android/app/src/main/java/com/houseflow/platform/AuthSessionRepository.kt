package com.houseflow.platform

import android.content.Context
import com.houseflow.androidbridge.HouseFlowAndroidBridge
import java.io.IOException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

internal enum class AuthDestination { EMAIL_VERIFICATION, BIRTHDAY_SETUP, HOUSE_SELECTION, DASHBOARD }

internal data class AuthProfile(
    val destination: AuthDestination,
    val email: String,
    val language: String?,
    val userId: String = "",
    val firstName: String = "",
    val lastName: String = "",
    val houses: List<HouseSummary> = emptyList(),
    val imageUrl: String = "",
    val birthDay: String = "",
    val createdOn: String = "",
    val phoneNumber: String = "",
    val isVerifyEmail: Boolean = false,
    val isVerifyPhone: Boolean = false,
)

internal sealed interface AuthRestoreResult {
    data object SignedOut : AuthRestoreResult
    data class PendingEmailVerification(val email: String) : AuthRestoreResult
    data class SignedIn(val profile: AuthProfile) : AuthRestoreResult
    data class Error(val message: String?) : AuthRestoreResult
}

internal class AuthRequestException(val serverMessage: String?) : IOException(serverMessage ?: "Authentication failed")
internal class AuthProfileException(val serverMessage: String?) : IOException(serverMessage ?: "Profile load failed")

/** Testable orchestration; Core owns JSON wire interpretation and route priority. */
internal class AuthSessionRepository(
    private val send: suspend (PlatformHttpRequest) -> PlatformHttpResponse,
    private val read: (SessionField) -> SessionReadResult,
    private val write: (SessionField, String?) -> Unit,
    private val clear: () -> Unit,
    private val wire: AuthWire = NativeAuthWire,
) {
    suspend fun login(email: String, password: String): AuthProfile = withContext(Dispatchers.IO) {
        val response = send(
            PlatformHttpRequest(
                path = "auth/login",
                method = "POST",
                headers = mapOf("Content-Type" to "application/json"),
                body = wire.loginBody(email, password).toByteArray(Charsets.UTF_8),
            ),
        )
        val tokenResult = JSONObject(wire.loginResult(response.statusCode, response.body.decodeToString()))
        if (!tokenResult.optBoolean("ok")) throw AuthRequestException(tokenResult.optString("message").ifBlank { null })
        val token = tokenResult.getString("token")
        write(SessionField.AUTH_TOKEN, token)
        write(SessionField.USER_EMAIL, email)
        write(SessionField.PENDING_EMAIL_VERIFICATION, null)
        try { profile(token) } catch (cancel: CancellationException) {
            throw cancel
        } catch (error: AuthRequestException) {
            throw AuthProfileException(error.serverMessage)
        } catch (_: Exception) {
            throw AuthProfileException(null)
        }
    }

    suspend fun signup(email: String, password: String, firstName: String, lastName: String) = withContext(Dispatchers.IO) {
        val response = send(jsonRequest("auth/signup", "POST", wire.signupBody(email, password, firstName, lastName)))
        val result = JSONObject(wire.loginResult(response.statusCode, response.body.decodeToString()))
        requireOk(result)
        write(SessionField.AUTH_TOKEN, result.getString("token"))
        write(SessionField.USER_EMAIL, email)
        write(SessionField.USER_FIRST_NAME, firstName)
        write(SessionField.USER_LAST_NAME, lastName)
        write(SessionField.PENDING_EMAIL_VERIFICATION, email)
    }

    suspend fun forgotPassword(email: String) = withContext(Dispatchers.IO) {
        // iOS transitions to code entry on a decoded response, even when success is false.
        val response = send(jsonRequest("auth/forget", "POST", wire.forgotBody(email)))
        requireOk(JSONObject(wire.actionResult("forgot", response.statusCode, response.body.decodeToString())))
    }

    suspend fun resetPassword(email: String, code: String, newPassword: String) = withContext(Dispatchers.IO) {
        val response = send(jsonRequest("auth/reset", "POST", wire.resetBody(email, code, newPassword)))
        requireOk(JSONObject(wire.actionResult("reset", response.statusCode, response.body.decodeToString())))
    }

    suspend fun sendVerificationCode() = withContext(Dispatchers.IO) {
        val response = send(PlatformHttpRequest("auth/validate-email", "GET", headers = authHeader()))
        requireOk(JSONObject(wire.actionResult("sendVerification", response.statusCode, response.body.decodeToString())))
    }

    suspend fun verifyEmail(code: String): AuthProfile = withContext(Dispatchers.IO) {
        val response = send(jsonRequest("auth/validate-email", "POST", wire.verifyBody(code), authHeader()))
        requireOk(JSONObject(wire.actionResult("verifyEmail", response.statusCode, response.body.decodeToString())))
        val token = currentToken()
        val profile = profile(token)
        if (profile.destination == AuthDestination.EMAIL_VERIFICATION) throw AuthRequestException(null)
        write(SessionField.PENDING_EMAIL_VERIFICATION, null)
        profile
    }

    suspend fun updateBirthday(birthDay: String): AuthProfile = withContext(Dispatchers.IO) {
        val token = currentToken()
        val before = profile(token)
        if (before.userId.isBlank()) throw AuthProfileException(null)
        val response = send(PlatformHttpRequest(
            path = "user/profile/${before.userId}", method = "PUT",
            queryItems = listOf(PlatformHttpQueryItem("userId", before.userId)),
            headers = authHeader() + ("Content-Type" to "application/json"),
            body = wire.birthdayBody(birthDay).toByteArray(Charsets.UTF_8),
        ))
        requireOk(JSONObject(wire.actionResult("birthday", response.statusCode, response.body.decodeToString())))
        profile(token)
    }

    suspend fun restore(): AuthRestoreResult = withContext(Dispatchers.IO) {
        when (val pending = read(SessionField.PENDING_EMAIL_VERIFICATION)) {
            is SessionReadResult.Value -> return@withContext AuthRestoreResult.PendingEmailVerification(pending.value)
            SessionReadResult.ReauthenticationRequired -> return@withContext AuthRestoreResult.SignedOut
            SessionReadResult.Missing -> Unit
        }
        when (val token = read(SessionField.AUTH_TOKEN)) {
            SessionReadResult.Missing, SessionReadResult.ReauthenticationRequired -> AuthRestoreResult.SignedOut
            is SessionReadResult.Value -> try {
                AuthRestoreResult.SignedIn(profile(token.value))
            } catch (error: AuthRequestException) {
                // iOS keeps the token on HTTP/offline failure and offers a retry.
                AuthRestoreResult.Error(error.serverMessage)
            } catch (_: IOException) {
                AuthRestoreResult.Error(null)
            }
        }
    }

    suspend fun logout() = withContext(Dispatchers.IO) { clear() }

    private suspend fun profile(token: String): AuthProfile {
        val response = send(
            PlatformHttpRequest(
                path = "auth/isAuth",
                method = "GET",
                headers = mapOf("Authorization" to "Bearer $token"),
            ),
        )
        val result = JSONObject(wire.profileResult(response.statusCode, response.body.decodeToString()))
        if (!result.optBoolean("ok")) throw AuthRequestException(result.optString("message").ifBlank { null })
        write(SessionField.USER_EMAIL, result.getString("email"))
        write(SessionField.USER_FIRST_NAME, result.getString("firstName"))
        write(SessionField.USER_LAST_NAME, result.getString("lastName"))
        val destination = AuthDestination.valueOf(result.getString("destination").camelToEnum())
        if (destination == AuthDestination.EMAIL_VERIFICATION) {
            write(SessionField.PENDING_EMAIL_VERIFICATION, result.getString("email").trim())
        }
        return AuthProfile(
            destination,
            result.getString("email"),
            result.optString("language").ifBlank { null },
            result.optString("userId"),
            result.optString("firstName"),
            result.optString("lastName"),
            result.optJSONArray("houseList")?.let { houses ->
                (0 until houses.length()).map { index ->
                    val house = houses.getJSONObject(index)
                    HouseSummary(house.getString("houseId"), house.getString("houseName"), house.optString("houseProfile"))
                }
            } ?: emptyList(),
            result.optString("imageUrl"), result.optString("birthDay"), result.optString("createdOn"),
            result.optString("phoneNumber"), result.optBoolean("isVerifyEmail"), result.optBoolean("isVerifyPhone"),
        )
    }

    private fun currentToken(): String = when (val result = read(SessionField.AUTH_TOKEN)) {
        is SessionReadResult.Value -> result.value
        else -> throw AuthRequestException(null)
    }

    private fun authHeader() = mapOf("Authorization" to "Bearer ${currentToken()}")

    private fun jsonRequest(path: String, method: String, body: String, headers: Map<String, String> = emptyMap()) =
        PlatformHttpRequest(path, method, headers = headers + ("Content-Type" to "application/json"), body = body.toByteArray(Charsets.UTF_8))

    private fun requireOk(result: JSONObject) {
        if (!result.optBoolean("ok")) throw AuthRequestException(result.optString("message").ifBlank { null })
    }

    companion object {
        fun live(context: Context, http: AndroidHttpAdapter): AuthSessionRepository {
            val store = KeystoreSessionStore(context)
            return AuthSessionRepository(http::send, store::read, store::write, store::clearSession)
        }
    }
}

private fun String.camelToEnum(): String = replace(Regex("([a-z])([A-Z])"), "$1_$2").uppercase()

internal interface AuthWire {
    fun loginBody(email: String, password: String): String
    fun loginResult(status: Int, body: String): String
    fun profileResult(status: Int, body: String): String
    fun signupBody(email: String, password: String, firstName: String, lastName: String): String
    fun forgotBody(email: String): String
    fun resetBody(email: String, code: String, newPassword: String): String
    fun verifyBody(code: String): String
    fun birthdayBody(birthDay: String): String
    fun actionResult(action: String, status: Int, body: String): String
}

private object NativeAuthWire : AuthWire {
    private val checked by lazy {
        check(HouseFlowAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION)
    }
    override fun loginBody(email: String, password: String): String {
        checked
        return HouseFlowAndroidBridge.loginRequestBody(email, password)
    }
    override fun loginResult(status: Int, body: String): String {
        checked
        return HouseFlowAndroidBridge.loginResponse(status, body)
    }
    override fun profileResult(status: Int, body: String): String {
        checked
        return HouseFlowAndroidBridge.profileResponse(status, body)
    }
    override fun signupBody(email: String, password: String, firstName: String, lastName: String): String {
        checked
        return HouseFlowAndroidBridge.signupRequestBody(email, password, firstName, lastName)
    }
    override fun forgotBody(email: String): String {
        checked
        return HouseFlowAndroidBridge.forgotPasswordRequestBody(email)
    }
    override fun resetBody(email: String, code: String, newPassword: String): String {
        checked
        return HouseFlowAndroidBridge.resetPasswordRequestBody(email, code, newPassword)
    }
    override fun verifyBody(code: String): String {
        checked
        return HouseFlowAndroidBridge.verifyEmailRequestBody(code)
    }
    override fun birthdayBody(birthDay: String): String {
        checked
        return HouseFlowAndroidBridge.birthdayRequestBody(birthDay)
    }
    override fun actionResult(action: String, status: Int, body: String): String {
        checked
        return HouseFlowAndroidBridge.authActionResponse(action, status, body)
    }
}
