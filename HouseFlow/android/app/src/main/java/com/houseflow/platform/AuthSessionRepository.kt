package com.houseflow.platform

import android.content.Context
import com.houseflow.androidbridge.HouseFlowAndroidBridge
import java.io.IOException
import kotlinx.coroutines.CancellationException
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import org.json.JSONObject

internal enum class AuthDestination { EMAIL_VERIFICATION, BIRTHDAY_SETUP, HOUSE_SELECTION, DASHBOARD }

internal data class AuthProfile(val destination: AuthDestination, val email: String, val language: String?)

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
        return AuthProfile(
            AuthDestination.valueOf(result.getString("destination").camelToEnum()),
            result.getString("email"),
            result.optString("language").ifBlank { null },
        )
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
}
