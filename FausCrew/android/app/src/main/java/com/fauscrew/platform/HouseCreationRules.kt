package com.fauscrew.platform

import com.fauscrew.androidbridge.FausCrewAndroidBridge

/**
 * Add-house limit and Create house form checks. The name rules come from `HouseCreationRules` in
 * FausCrewCore, which counts characters (grapheme clusters) as iOS does; one UTF-16 unit is not one
 * character for emoji or combining accents.
 */
internal object HouseCreationRules {
    /** Join / Create are offered only while the user is in fewer houses than this. */
    const val MAX_HOUSE_COUNT = 3
    const val NAME_MAX_LENGTH = 30
    val memberCountRange = 2..8
    private val versionChecked by lazy { check(FausCrewAndroidBridge.bridgeVersion() == InviteCodeBridge.API_VERSION) }

    fun canAddHouse(currentHouseCount: Int): Boolean = currentHouseCount < MAX_HOUSE_COUNT

    /** [name] cut to [NAME_MAX_LENGTH] characters, never inside an emoji or an accented letter. */
    fun limitedName(name: String): String {
        versionChecked
        return FausCrewAndroidBridge.limitedHouseName(name)
    }

    /** The number shown against [NAME_MAX_LENGTH]. */
    fun nameLength(name: String): Int {
        versionChecked
        return FausCrewAndroidBridge.houseNameLength(name)
    }

    fun isValid(name: String, type: Int?, memberCount: Int?): Boolean {
        if (type == null || memberCount == null) return false
        versionChecked
        return FausCrewAndroidBridge.isHouseCreationValid(name, type, memberCount)
    }
}
