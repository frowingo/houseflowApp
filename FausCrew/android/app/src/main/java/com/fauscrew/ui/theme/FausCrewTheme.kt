package com.fauscrew.ui.theme

import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

/**
 * Android counterpart of the iOS design tokens in `Views/Shared/DesignSystem.swift`
 * (`AppDesign`, `HouseJourneyTheme`) and the brand palette shared by the hero cards,
 * popup headers, tab bar and `MainScreenBackground`. iOS system colors are the light
 * appearance values so both platforms resolve the same pixels.
 */
internal object FausCrewColors {
    // AppDesign.Colors
    val primary = Color(0xFF007AFF)
    val secondary = Color(0xFF34C759)
    val success = secondary
    val warning = Color(0xFFFF9500)
    val error = Color(0xFFFF3B30)
    val background = Color.White
    val secondaryBackground = Color(0xFFF2F2F7)
    val cardBackground = secondaryBackground
    val textPrimary = Color.Black
    val textSecondary = Color(0x993C3C43)
    val textTertiary = Color(0xFF8E8E93)
    val separator = Color(0x4A3C3C43)

    // HouseJourneyTheme
    val accentOrange = Color(0xFFFF7A26)
    val accentOrangeInk = Color(0xFFBA400B)
    val indigo = Color(0xFF45579E)
    val deepIndigo = Color(0xFF33407A)
    val blue = Color(0xFF3D7AB8)
    val teal = Color(0xFF2E9187)
    val deepTeal = Color(0xFF1A665E)
    val buttonBlue = Color(0xFF2E5C96)
    val purple = Color(0xFF7A61AD)
    val errorRed = Color(0xFFD1454F)
    val pageBackground = Color(0xFFF2F2F7)
    val surface = Color.White

    // Brand treatment (BrandHeroCardBackground, CustomTabBar, MainScreenBackground)
    val brandLight = Color(0xFFFF9138)
    val brandOrange = accentOrange
    val deepBerry = Color(0xFF611A38)
    val softApricot = Color(0xFFF59E59)
    val softOrange = Color(0xFFED7D40)
    val softBerry = Color(0xFF75304D)
    /** SwiftUI `Color.orange`, used by the decorative capsules. */
    val systemOrange = warning
    val systemGray3 = Color(0xFFC7C7CC)
    val systemGray4 = Color(0xFFD1D1D6)
}

internal object FausCrewBrushes {
    val brandHero = Brush.linearGradient(
        listOf(FausCrewColors.brandLight, FausCrewColors.brandOrange, FausCrewColors.deepBerry),
    )
    val tabBar = Brush.linearGradient(
        listOf(FausCrewColors.softApricot, FausCrewColors.softOrange, FausCrewColors.softBerry),
    )
    val indigoTeal = Brush.linearGradient(listOf(FausCrewColors.indigo, FausCrewColors.teal))
    val orangeAction = Brush.horizontalGradient(
        listOf(FausCrewColors.accentOrange, FausCrewColors.accentOrange.copy(alpha = .75f)),
    )
    val disabledAction = Brush.horizontalGradient(
        listOf(Color.Gray.copy(alpha = .4f), Color.Gray.copy(alpha = .4f)),
    )
}

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
internal fun FausCrewTheme(content: @Composable () -> Unit) {
    MaterialTheme(
        colorScheme = lightColorScheme(
            primary = FausCrewColors.primary,
            onPrimary = Color.White,
            secondary = FausCrewColors.accentOrange,
            background = FausCrewColors.background,
            surface = FausCrewColors.background,
            onSurface = FausCrewColors.textPrimary,
            onSurfaceVariant = FausCrewColors.textSecondary,
            error = FausCrewColors.error,
        ),
        content = content,
    )
}
