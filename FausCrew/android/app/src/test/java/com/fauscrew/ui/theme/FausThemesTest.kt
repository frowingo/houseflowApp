package com.fauscrew.ui.theme

import org.junit.Assert.assertEquals
import org.junit.Assert.assertFalse
import org.junit.Assert.assertTrue
import org.junit.Test

class FausThemesTest {
    @Test
    fun firstLaunchAndUnknownValuesUseFausLight() {
        assertEquals(FausThemeId.FAUS_LIGHT, FausThemeId.DEFAULT)
        assertEquals(FausThemeId.FAUS_LIGHT, FausThemeId.fromStorage(null))
        assertEquals(FausThemeId.FAUS_LIGHT, FausThemeId.fromStorage("neon"))
    }

    @Test
    fun storageValuesMatchTheIosContract() {
        assertEquals("faus_light", FausThemeId.FAUS_LIGHT.storageValue)
        assertEquals("faus_dark", FausThemeId.FAUS_DARK.storageValue)
        assertEquals(FausThemeId.FAUS_DARK, FausThemeId.fromStorage("faus_dark"))
        assertEquals("Faus Light", FausThemeId.FAUS_LIGHT.displayName)
        assertEquals("Faus Dark", FausThemeId.FAUS_DARK.displayName)
    }

    @Test
    fun launcherAliasesMatchTheManifest() {
        assertEquals("LauncherFausLight", FausThemeId.FAUS_LIGHT.launcherAlias)
        assertEquals("LauncherFausDark", FausThemeId.FAUS_DARK.launcherAlias)
    }

    @Test
    fun everyThemeIdHasAThemeInPickerOrder() {
        assertEquals(FausThemeId.entries, FausThemes.all.map { it.id })
        assertFalse(FausThemes.theme(FausThemeId.FAUS_LIGHT).isDark)
        assertTrue(FausThemes.theme(FausThemeId.FAUS_DARK).isDark)
    }

    @Test
    fun controllerPersistsOnlyRealChanges() {
        val saved = mutableListOf<FausThemeId>()
        val controller = FausThemeController(FausThemeId.FAUS_LIGHT) { saved += it }
        controller.select(FausThemeId.FAUS_LIGHT)
        controller.select(FausThemeId.FAUS_DARK)
        assertEquals(FausThemeId.FAUS_DARK, controller.themeId)
        assertEquals(listOf(FausThemeId.FAUS_DARK), saved)
    }
}
