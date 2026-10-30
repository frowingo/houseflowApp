package com.fauscrew.ui.theme

import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.setValue
import androidx.compose.runtime.staticCompositionLocalOf

/**
 * Owns the user's theme choice for the running app (iOS `ThemeStore`): the root reads [theme]
 * into [FausCrewTheme], and the Profile theme picker calls [select], which also persists it.
 */
internal class FausThemeController(initial: FausThemeId, private val persist: (FausThemeId) -> Unit) {
    var themeId by mutableStateOf(initial)
        private set

    val theme: FausTheme get() = FausThemes.theme(themeId)

    fun select(id: FausThemeId) {
        if (id == themeId) return
        themeId = id
        persist(id)
    }
}

internal val LocalFausThemeController = staticCompositionLocalOf { FausThemeController(FausThemeId.DEFAULT) {} }
