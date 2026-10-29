package com.fauscrew.platform

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class HouseCreationRulesTest {
    @Test
    fun addHouseOptionsHideAtTheHouseLimit() {
        assertTrue(HouseCreationRules.canAddHouse(0))
        assertTrue(HouseCreationRules.canAddHouse(HouseCreationRules.MAX_HOUSE_COUNT - 1))
        assertFalse(HouseCreationRules.canAddHouse(HouseCreationRules.MAX_HOUSE_COUNT))
    }

    @Test
    fun formNeedsNameTypeAndMemberCount() {
        assertTrue(HouseCreationRules.isValid("Bahçeli Ev", 2, 4))
        assertFalse(HouseCreationRules.isValid("   ", 2, 4))
        assertFalse(HouseCreationRules.isValid("Bahçeli Ev", null, 4))
        assertFalse(HouseCreationRules.isValid("Bahçeli Ev", 2, null))
    }

    @Test
    fun formRejectsOutOfRangeValues() {
        assertFalse(HouseCreationRules.isValid("a".repeat(HouseCreationRules.NAME_MAX_LENGTH + 1), 2, 4))
        assertFalse(HouseCreationRules.isValid("Ev", 9, 4))
        assertFalse(HouseCreationRules.isValid("Ev", 2, 1))
        assertFalse(HouseCreationRules.isValid("Ev", 2, 9))
    }
}
