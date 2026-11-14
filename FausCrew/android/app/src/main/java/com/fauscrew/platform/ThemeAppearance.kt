package com.fauscrew.platform

import android.app.Activity
import android.content.ComponentName
import android.content.Context
import android.content.pm.PackageManager
import android.os.Build
import com.fauscrew.ui.theme.FausThemeId

/** Carries the Faus theme to the launcher icon (iOS alternate app icons) and the launch window. */
internal object ThemeAppearance {
    /**
     * Enables the theme's launcher alias and disables the rest. Called when the app leaves the
     * foreground: some launchers close a task whose launcher entry changes under it.
     */
    fun applyLauncherIcon(context: Context, theme: FausThemeId) {
        val packages = context.packageManager
        // Walk aliases, not themes, so two themes may share one icon.
        // Enable the new entry before disabling the old one so the app always has a launcher icon.
        val ordered = FausThemeId.entries.map { it.launcherAlias }.distinct().sortedByDescending { it == theme.launcherAlias }
        for (alias in ordered) {
            val component = ComponentName(context.packageName, "com.fauscrew.$alias")
            val wanted = alias == theme.launcherAlias
            val enabled = when (packages.getComponentEnabledSetting(component)) {
                PackageManager.COMPONENT_ENABLED_STATE_ENABLED -> true
                PackageManager.COMPONENT_ENABLED_STATE_DEFAULT -> alias == FausThemeId.DEFAULT.launcherAlias
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

    /**
     * Makes the system launch window of the next cold start show the theme's color
     * ([FausThemeId.launchColor]) instead of the manifest default. The system persists the style
     * for the whole app. Android 11 has no such API and keeps the neutral black window.
     */
    fun applyLaunchScreen(activity: Activity, theme: FausThemeId) {
        if (Build.VERSION.SDK_INT < Build.VERSION_CODES.S) return
        activity.splashScreen.setSplashScreenTheme(theme.launchStyle)
    }
}
