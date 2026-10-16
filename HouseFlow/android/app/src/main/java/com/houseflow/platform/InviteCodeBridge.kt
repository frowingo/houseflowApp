package com.houseflow.platform

import com.houseflow.androidbridge.HouseFlowAndroidBridge

/** Versioned, narrow Kotlin boundary. Never call it once per rendered frame. */
object InviteCodeBridge {
    const val API_VERSION = 7
    private const val MAX_INPUT_LENGTH = 64
    private val versionChecked: Unit by lazy(LazyThreadSafetyMode.SYNCHRONIZED) {
        check(HouseFlowAndroidBridge.bridgeVersion() == API_VERSION) {
            "Incompatible HouseFlow Swift bridge"
        }
    }

    fun normalize(input: String?): String {
        requireNotNull(input) { "Invite code cannot be null" }
        require(input.length <= MAX_INPUT_LENGTH) { "Invite code is too long" }
        versionChecked
        return HouseFlowAndroidBridge.normalizeInviteCode(input)
    }
}
