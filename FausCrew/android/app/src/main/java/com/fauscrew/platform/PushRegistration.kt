package com.fauscrew.platform

import com.fauscrew.androidbridge.FausCrewAndroidBridge
import org.json.JSONObject

/** Why the session ends; Core decides from it whether the device token is unregistered. */
internal enum class PushSignOutReason(val wire: String) {
    /** The JWT is still valid: logout, language-change re-login, leaving email verification. */
    UserInitiated("userInitiated"),
    /** 401 or a rejected token: the JWT is no longer valid. */
    SessionRejected("sessionRejected"),
    /** The backend already deleted the device tokens with the account. */
    AccountDeleted("accountDeleted"),
}

internal sealed interface PushRegistrationEffect {
    data class Register(val token: String) : PushRegistrationEffect
    data class Unregister(val token: String) : PushRegistrationEffect
    data object DeleteLocalToken : PushRegistrationEffect
}

internal data class PushRegistrationResult(val cleaningUp: Boolean, val effects: List<PushRegistrationEffect>)

/** FausCrewCore's device-token registration rules behind a handle. */
internal interface PushRegistrationEngine {
    fun event(type: String, fields: Map<String, Any?> = emptyMap()): PushRegistrationResult
}

internal object PushRegistrationNative {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    fun engine(): PushRegistrationEngine {
        checked
        val handle = FausCrewAndroidBridge.pushRegistrationCreate()
        return object : PushRegistrationEngine {
            override fun event(type: String, fields: Map<String, Any?>): PushRegistrationResult {
                val json = JSONObject().put("type", type)
                fields.forEach { (key, value) -> json.put(key, value ?: JSONObject.NULL) }
                return PushRegistrationParser.parse(FausCrewAndroidBridge.pushRegistrationEvent(handle, json.toString()))
            }
        }
    }
}

internal object PushRegistrationParser {
    fun parse(json: String): PushRegistrationResult {
        val root = JSONObject(json)
        check(root.optBoolean("ok", false)) { root.optString("message", "Push registration bridge failed") }
        val effects = root.optJSONArray("effects")
        return PushRegistrationResult(
            cleaningUp = root.getBoolean("cleaningUp"),
            effects = List(effects?.length() ?: 0) { index ->
                val effect = effects!!.getJSONObject(index)
                when (val type = effect.getString("type")) {
                    "register" -> PushRegistrationEffect.Register(effect.getString("token"))
                    "unregister" -> PushRegistrationEffect.Unregister(effect.getString("token"))
                    "deleteLocalToken" -> PushRegistrationEffect.DeleteLocalToken
                    else -> error("Unknown push registration effect $type")
                }
            },
        )
    }
}
