package com.fauscrew.platform

/** Mirrors `HouseCreationRules` in FausCrewCore: add-house limit and Create house form checks. */
internal object HouseCreationRules {
    /** Join / Create are offered only while the user is in fewer houses than this. */
    const val MAX_HOUSE_COUNT = 3
    const val NAME_MAX_LENGTH = 30
    val memberCountRange = 2..8
    private val houseTypes = setOf(1, 2, 3)

    fun canAddHouse(currentHouseCount: Int): Boolean = currentHouseCount < MAX_HOUSE_COUNT

    fun isValid(name: String, type: Int?, memberCount: Int?): Boolean {
        val trimmed = name.trim()
        return trimmed.isNotEmpty() && trimmed.length <= NAME_MAX_LENGTH &&
            type in houseTypes && memberCount != null && memberCount in memberCountRange
    }
}
