package com.fauscrew.platform

import com.fauscrew.androidbridge.FausCrewAndroidBridge

/** Versioned, narrow Kotlin boundary. Never call it once per rendered frame. */
object InviteCodeBridge {
    const val API_VERSION = 14
    private const val MAX_INPUT_LENGTH = 64
    private val versionChecked: Unit by lazy(LazyThreadSafetyMode.SYNCHRONIZED) {
        check(FausCrewAndroidBridge.bridgeVersion() == API_VERSION) {
            "Incompatible FausCrew Swift bridge"
        }
    }

    fun normalize(input: String?): String {
        requireNotNull(input) { "Invite code cannot be null" }
        require(input.length <= MAX_INPUT_LENGTH) { "Invite code is too long" }
        versionChecked
        return FausCrewAndroidBridge.normalizeInviteCode(input)
    }
}
