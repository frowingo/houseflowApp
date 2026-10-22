package com.fauscrew.platform

import com.fauscrew.androidbridge.FausCrewAndroidBridge
import org.json.JSONObject

internal sealed interface AppEventsEffect {
    data class OpenSocket(val connection: Int, val path: String) : AppEventsEffect
    data object CloseSocket : AppEventsEffect
    /** Forced HTTP refresh of the profile/house list and/or the selected house's details. */
    data class Refresh(val profile: Boolean, val houseId: String?) : AppEventsEffect
    data object SignedOut : AppEventsEffect
}

/** FausCrewCore's `/api/v1/events` channel rules behind a handle. */
internal interface AppEventsEngine {
    fun event(type: String, now: Double, fields: Map<String, Any?> = emptyMap()): List<AppEventsEffect>
    fun close()
}

internal object AppEventsNative {
    private val checked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    fun engine(): AppEventsEngine {
        checked
        val handle = FausCrewAndroidBridge.appEventsCreate()
        return object : AppEventsEngine {
            override fun event(type: String, now: Double, fields: Map<String, Any?>): List<AppEventsEffect> {
                val json = JSONObject().put("type", type).put("now", now)
                fields.forEach { (key, value) -> json.put(key, value ?: JSONObject.NULL) }
                return AppEventsParser.parse(FausCrewAndroidBridge.appEventsEvent(handle, json.toString()))
            }
            override fun close() {
                FausCrewAndroidBridge.appEventsDestroy(handle)
            }
        }
    }
}

internal object AppEventsParser {
    fun parse(json: String): List<AppEventsEffect> {
        val root = JSONObject(json)
        check(root.optBoolean("ok", false)) { root.optString("message", "App events bridge failed") }
        val path = root.optString("path", "events")
        val effects = root.optJSONArray("effects") ?: return emptyList()
        return List(effects.length()) { index ->
            val effect = effects.getJSONObject(index)
            when (val type = effect.getString("type")) {
                "openSocket" -> AppEventsEffect.OpenSocket(effect.getInt("connection"), path)
                "closeSocket" -> AppEventsEffect.CloseSocket
                "refresh" -> AppEventsEffect.Refresh(effect.getBoolean("profile"), effect.optNullableString("houseId"))
                "signedOut" -> AppEventsEffect.SignedOut
                else -> error("Unknown app events effect $type")
            }
        }
    }
}
