package com.fauscrew.platform

import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import com.fauscrew.ui.theme.FausThemeId

/** Carries the Faus theme to the launcher icon (iOS alternate app icons). */
internal object ThemeAppearance {
    /**
     * Enables the theme's launcher alias and disables the rest. Called when the app leaves the
     * foreground: some launchers close a task whose launcher entry changes under it.
     */
    fun applyLauncherIcon(context: Context, theme: FausThemeId) {
        val packages = context.packageManager
        // Enable the new entry before disabling the old one so the app always has a launcher icon.
        val ordered = FausThemeId.entries.sortedByDescending { it == theme }
        for (id in ordered) {
            val component = ComponentName(context.packageName, "com.fauscrew.${id.launcherAlias}")
            val wanted = id == theme
            val enabled = when (packages.getComponentEnabledSetting(component)) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> id == FausThemeId.DEFAULT
                else -> false
            }
            if (enabled == wanted) continue
            packages.setComponentEnabledSetting(
                component,
                if (wanted) PackageManager.COMPONENT_ENABLED_STATE_ENABLED else PackageManager.COMPONENT_ENABLED_STATE_DISABLED,
                PackageManager.DONT_KILL_APP,
            )
        }
    }
}
