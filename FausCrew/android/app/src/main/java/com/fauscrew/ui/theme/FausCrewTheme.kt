package com.fauscrew.ui.theme

import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.ReadOnlyComposable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Android counterpart of the iOS design tokens in `Views/Shared/DesignSystem.swift`
 * (`AppDesign`, `HouseJourneyTheme`) and the brand palette shared by the hero cards,
 * popup headers, tab bar and `MainScreenBackground`. Every token reads the active theme
 * ([LocalFausTheme], values in `FausThemes.kt`), so they are only available in composition.
 */
internal object FausCrewColors {
    private val palette: FausPalette @Composable @ReadOnlyComposable get() = LocalFausTheme.current.palette

    // AppDesign.Colors
    val primary: Color @Composable @ReadOnlyComposable get() = palette.primary
    val secondary: Color @Composable @ReadOnlyComposable get() = palette.secondary
    val success: Color @Composable @ReadOnlyComposable get() = palette.secondary
    val warning: Color @Composable @ReadOnlyComposable get() = palette.warning
    val error: Color @Composable @ReadOnlyComposable get() = palette.error
    val background: Color @Composable @ReadOnlyComposable get() = palette.background
    val secondaryBackground: Color @Composable @ReadOnlyComposable get() = palette.secondaryBackground
    val cardBackground: Color @Composable @ReadOnlyComposable get() = palette.cardBackground
    val elevatedSurface: Color @Composable @ReadOnlyComposable get() = palette.elevatedSurface
    val popupBackground: Color @Composable @ReadOnlyComposable get() = palette.popupBackground
    val menuBackground: Color @Composable @ReadOnlyComposable get() = palette.menuBackground
    val segmentSelected: Color @Composable @ReadOnlyComposable get() = palette.segmentSelected
    val textPrimary: Color @Composable @ReadOnlyComposable get() = palette.textPrimary
    val textSecondary: Color @Composable @ReadOnlyComposable get() = palette.textSecondary
    val textTertiary: Color @Composable @ReadOnlyComposable get() = palette.textTertiary
    val onAccent: Color @Composable @ReadOnlyComposable get() = palette.onAccent
    val onHero: Color @Composable @ReadOnlyComposable get() = palette.onHero
    val separator: Color @Composable @ReadOnlyComposable get() = palette.separator
    val hairline: Color @Composable @ReadOnlyComposable get() = palette.hairline
    val shadow: Color @Composable @ReadOnlyComposable get() = palette.shadow
    val scrim: Color @Composable @ReadOnlyComposable get() = palette.scrim

    // HouseJourneyTheme
    val accentOrange: Color @Composable @ReadOnlyComposable get() = palette.accentOrange
    val accentOrangeInk: Color @Composable @ReadOnlyComposable get() = palette.accentOrangeInk
    val indigo: Color @Composable @ReadOnlyComposable get() = palette.indigo
    val deepIndigo: Color @Composable @ReadOnlyComposable get() = palette.deepIndigo
    val blue: Color @Composable @ReadOnlyComposable get() = palette.blue
    val teal: Color @Composable @ReadOnlyComposable get() = palette.teal
    val deepTeal: Color @Composable @ReadOnlyComposable get() = palette.deepTeal
    val buttonBlue: Color @Composable @ReadOnlyComposable get() = palette.buttonBlue
    val purple: Color @Composable @ReadOnlyComposable get() = palette.purple
    val errorRed: Color @Composable @ReadOnlyComposable get() = palette.errorRed
    val indigoFill: Color @Composable @ReadOnlyComposable get() = palette.indigoFill
    val deepIndigoFill: Color @Composable @ReadOnlyComposable get() = palette.deepIndigoFill
    val tealFill: Color @Composable @ReadOnlyComposable get() = palette.tealFill
    val pageBackground: Color @Composable @ReadOnlyComposable get() = palette.pageBackground
    val surface: Color @Composable @ReadOnlyComposable get() = palette.surface

    // Brand treatment (BrandHeroCardBackground, CustomTabBar, MainScreenBackground)
    val brandLight: Color @Composable @ReadOnlyComposable get() = palette.brandLight
    val brandOrange: Color @Composable @ReadOnlyComposable get() = palette.brandOrange
    val deepBerry: Color @Composable @ReadOnlyComposable get() = palette.deepBerry
    val markBerry: Color @Composable @ReadOnlyComposable get() = palette.markBerry
    val spinnerRed: Color @Composable @ReadOnlyComposable get() = palette.spinnerRed
    val spinnerBerry: Color @Composable @ReadOnlyComposable get() = palette.spinnerBerry
    val softApricot: Color @Composable @ReadOnlyComposable get() = palette.softApricot
    val softOrange: Color @Composable @ReadOnlyComposable get() = palette.softOrange
    val softBerry: Color @Composable @ReadOnlyComposable get() = palette.softBerry
    /** SwiftUI `Color.orange`, used by the decorative capsules. */
    val systemOrange: Color @Composable @ReadOnlyComposable get() = palette.systemOrange
    /** iOS systemGray3 / systemGray4: disabled fills and quiet borders. */
    val systemGray3: Color @Composable @ReadOnlyComposable get() = palette.controlFillStrong
    val systemGray4: Color @Composable @ReadOnlyComposable get() = palette.controlFill

    // ChoreStatus.color
    val statusDraft: Color @Composable @ReadOnlyComposable get() = palette.statusDraft
    val statusProgress: Color @Composable @ReadOnlyComposable get() = palette.statusProgress
    val statusInTest: Color @Composable @ReadOnlyComposable get() = palette.statusInTest
    val statusCompleted: Color @Composable @ReadOnlyComposable get() = palette.statusCompleted
    val statusFailed: Color @Composable @ReadOnlyComposable get() = palette.statusFailed
}

internal object FausCrewBrushes {
    val brandHero: Brush @Composable @ReadOnlyComposable get() = LocalFausTheme.current.decor.heroStops.linear()
    val tabBar: Brush @Composable @ReadOnlyComposable get() = LocalFausTheme.current.decor.tabBarStops.linear()
    val indigoTeal: Brush @Composable @ReadOnlyComposable
        get() = Brush.linearGradient(listOf(FausCrewColors.indigo, FausCrewColors.teal))
    val orangeAction: Brush @Composable @ReadOnlyComposable
        get() = Brush.horizontalGradient(listOf(FausCrewColors.accentOrange, FausCrewColors.accentOrange.copy(alpha = .75f)))
    val disabledAction: Brush @Composable @ReadOnlyComposable
        get() = Brush.horizontalGradient(listOf(FausCrewColors.systemGray3, FausCrewColors.systemGray4))
}

/** Top-start → bottom-end gradient through the stops (SwiftUI `.topLeading` → `.bottomTrailing`). */
internal fun List<Stop>.linear(): Brush =
    if (size == 1) androidx.compose.ui.graphics.SolidColor(first().second) else Brush.linearGradient(*toTypedArray())

/** `AppDesign.Spacing`. */
internal object Spacing {
    val xs = 4.dp
    val sm = 8.dp
    val md = 12.dp
    val lg = 16.dp
    val xl = 20.dp
    val xxl = 24.dp
    val xxxl = 32.dp
    val huge = 40.dp
}

/** `AppDesign.CornerRadius`. */
internal object Radius {
    val xs = 4.dp
    val sm = 8.dp
    val md = 12.dp
    val lg = 16.dp
    val xl = 20.dp
    val xxl = 24.dp
}

/** `AppDesign.Size`. */
internal object Sizes {
    val buttonHeight = 48.dp
    val buttonHeightSmall = 44.dp
    val fab = 56.dp
    val iconSmall = 16.dp
    val iconMedium = 20.dp
}

/** `AppDesign.Typography`, sized like iOS Dynamic Type at the default (Large) setting. */
internal object FausCrewType {
    val largeTitle = TextStyle(fontSize = 34.sp, lineHeight = 41.sp, fontWeight = FontWeight.Bold)
    val title = TextStyle(fontSize = 28.sp, lineHeight = 34.sp, fontWeight = FontWeight.Bold)
    val title2 = TextStyle(fontSize = 22.sp, lineHeight = 28.sp, fontWeight = FontWeight.Bold)
    val title3 = TextStyle(fontSize = 20.sp, lineHeight = 25.sp, fontWeight = FontWeight.SemiBold)
    val headline = TextStyle(fontSize = 17.sp, lineHeight = 22.sp, fontWeight = FontWeight.SemiBold)
    val body = TextStyle(fontSize = 17.sp, lineHeight = 22.sp)
    val bodyBold = body.copy(fontWeight = FontWeight.Medium)
    val subheadline = TextStyle(fontSize = 15.sp, lineHeight = 20.sp)
    val caption = TextStyle(fontSize = 12.sp, lineHeight = 16.sp)
    val caption2 = TextStyle(fontSize = 11.sp, lineHeight = 13.sp)
}

/** `AppDesign.Animation` springs/curves. */
internal object Motion {
    /** `interpolatingSpring(stiffness: 300, damping: 20)` → damping ratio ≈ 0.58. */
    fun <T> spring() = spring<T>(dampingRatio = 0.58f, stiffness = 300f)
    /** `.spring(response: 0.6, dampingFraction: 0.78)`, used for card entrance. */
    fun <T> entrance() = spring<T>(dampingRatio = 0.78f, stiffness = 110f)
    /** `.spring(response: 0.42, dampingFraction: 0.86)`, used by expanding cards. */
    fun <T> expand() = spring<T>(dampingRatio = 0.86f, stiffness = 224f)
    fun <T> quick() = tween<T>(200)
    fun <T> standard() = tween<T>(300)
}

/**
 * Material defaults (text cursor, switches, date pickers) follow the iOS default tint so
 * stock controls inside FausCrew surfaces do not fall back to the Material baseline purple.
 */
@Composable
internal fun FausCrewTheme(theme: FausTheme = FausThemes.light, content: @Composable () -> Unit) {
    val palette = theme.palette
    val colorScheme = if (theme.isDark) {
        darkColorScheme(
            primary = palette.accentOrange,
            onPrimary = palette.onAccent,
            secondary = palette.accentOrange,
            background = palette.background,
            surface = palette.popupBackground,
            surfaceVariant = palette.secondaryBackground,
            surfaceContainerHigh = palette.menuBackground,
            onBackground = palette.textPrimary,
            onSurface = palette.textPrimary,
            onSurfaceVariant = palette.textSecondary,
            outline = palette.hairline,
            outlineVariant = palette.hairline,
            error = palette.error,
        )
    } else {
        lightColorScheme(
            primary = palette.primary,
            onPrimary = Color.White,
            secondary = palette.accentOrange,
            background = palette.background,
            surface = palette.background,
            onSurface = palette.textPrimary,
            onSurfaceVariant = palette.textSecondary,
            error = palette.error,
        )
    }
    CompositionLocalProvider(LocalFausTheme provides theme) {
        MaterialTheme(colorScheme = colorScheme, content = content)
    }
}
