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
        assertEquals("faus_bloom", FausThemeId.FAUS_BLOOM.storageValue)
        assertEquals(FausThemeId.FAUS_BLOOM, FausThemeId.fromStorage("faus_bloom"))
        assertEquals("Faus Bloom", FausThemeId.FAUS_BLOOM.displayName)
        // Saved before the rename; its remote description copy keeps the old key too.
        assertEquals(FausThemeId.FAUS_BLOOM, FausThemeId.fromStorage("fause_bloom"))
        assertEquals("theme_fause_bloom_description", FausThemeId.FAUS_BLOOM.descriptionKey)
        assertEquals("theme_faus_web_description", FausThemeId.FAUS_WEB.descriptionKey)
        assertEquals("faus_web", FausThemeId.FAUS_WEB.storageValue)
        assertEquals(FausThemeId.FAUS_WEB, FausThemeId.fromStorage("faus_web"))
        assertEquals("Faus Web", FausThemeId.FAUS_WEB.displayName)
    }

    @Test
    fun launcherAliasesMatchTheManifest() {
        assertEquals("LauncherFausLight", FausThemeId.FAUS_LIGHT.launcherAlias)
        assertEquals("LauncherFausDark", FausThemeId.FAUS_DARK.launcherAlias)
        assertEquals("LauncherFausBloom", FausThemeId.FAUS_BLOOM.launcherAlias)
        assertEquals("LauncherFausWeb", FausThemeId.FAUS_WEB.launcherAlias)
    }

    @Test
    fun everyThemeHasItsOwnLaunchColorAndStyle() {
        assertEquals(FausThemeId.entries.size, FausThemeId.entries.map { it.launchColor }.distinct().size)
        assertEquals(FausThemeId.entries.size, FausThemeId.entries.map { it.launchStyle }.distinct().size)
        assertEquals(com.fauscrew.R.color.launch_web, FausThemeId.FAUS_WEB.launchColor)
        assertEquals(com.fauscrew.R.style.Theme_FausCrew_Launch_Web, FausThemeId.FAUS_WEB.launchStyle)
    }

    @Test
    fun everyThemeIdHasAThemeInPickerOrder() {
        assertEquals(FausThemeId.entries, FausThemes.all.map { it.id })
        assertFalse(FausThemes.theme(FausThemeId.FAUS_LIGHT).isDark)
        assertTrue(FausThemes.theme(FausThemeId.FAUS_DARK).isDark)
        assertFalse(FausThemes.theme(FausThemeId.FAUS_BLOOM).isDark)
        assertTrue(FausThemes.theme(FausThemeId.FAUS_WEB).isDark)
    }

    @Test
    fun pageTextFallsBackToTextTokensUnlessOverridden() {
        val light = FausThemes.light.palette
        assertEquals(light.textPrimary, light.pageText)
        assertEquals(light.accentOrangeInk, light.pageAccent)
        val web = FausThemes.web.palette
        assertEquals(androidx.compose.ui.graphics.Color(0xFF001D51), web.pageText)
        assertEquals(androidx.compose.ui.graphics.Color(0xFF0F3A93), web.pageAccent)
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
