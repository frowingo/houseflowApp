package com.fauscrew.platform

import org.junit.Assert.assertEquals
import org.junit.Test

class AndroidLocalizationStateTest {
    private fun language(prefix: String, default: Boolean = false) = PlatformLanguage(
        image = "", isActive = true, isDefault = default, name = prefix, nativeName = prefix, prefix = prefix,
    )

    @Test fun exactThenBaseThenDefaultThenFirst() {
        val languages = listOf(language("en", true), language("tr-TR"), language("fr"))
        assertEquals("tr-TR", AndroidLocalizationState.chooseInitial(languages, "tr_TR"))
        assertEquals("tr-TR", AndroidLocalizationState.chooseInitial(languages, "tr-CY"))
        assertEquals("en", AndroidLocalizationState.chooseInitial(languages, "de-DE"))
        assertEquals("fr", AndroidLocalizationState.chooseInitial(listOf(language("fr")), "de-DE"))
    }
}
