package com.fauscrew.platform

import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

/** The name rules run in Core; `BridgeRoundtripTest` and the bridge tests cover them through the bridge. */
class HouseCreationRulesTest {
    @Test
    fun addHouseOptionsHideAtTheHouseLimit() {
        assertTrue(HouseCreationRules.canAddHouse(0))
        assertTrue(HouseCreationRules.canAddHouse(HouseCreationRules.MAX_HOUSE_COUNT - 1))
        assertFalse(HouseCreationRules.canAddHouse(HouseCreationRules.MAX_HOUSE_COUNT))
    }

    @Test
    fun formNeedsATypeAndMemberCountBeforeTheBridgeIsAsked() {
        assertFalse(HouseCreationRules.isValid("Bahçeli Ev", null, 4))
        assertFalse(HouseCreationRules.isValid("Bahçeli Ev", 2, null))
    }
}
