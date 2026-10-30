package com.fauscrew.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

/**
 * The visual themes the app can render. `storageValue` is the on-device contract shared with
 * iOS (`AppThemeID` in FausCrewCore), so a new theme is one entry here plus one [FausTheme]
 * below, mirroring `FausTheme.swift`.
 */
internal enum class FausThemeId(val storageValue: String, val displayName: String) {
    FAUS_LIGHT("faus_light", "Faus Light"),
    FAUS_DARK("faus_dark", "Faus Dark"),
    ;

    /** Picker copy key; iOS `FausTheme.descriptionKey`. */
    val descriptionKey: String get() = "theme_${storageValue}_description"

    val descriptionFallback: String
        get() = when (this) {
            FAUS_LIGHT -> "Bright and warm, the classic FausCrew look."
            FAUS_DARK -> "Ember glow on deep berry, easy on the eyes at night."
        }

    /** Manifest `activity-alias` that carries this theme's launcher icon; iOS `alternateIconName`. */
    val launcherAlias: String
        get() = when (this) {
            FAUS_LIGHT -> "LauncherFausLight"
            FAUS_DARK -> "LauncherFausDark"
        }

    companion object {
        /** First launch, and any stored value this build does not know, use Faus Light. */
        val DEFAULT = FAUS_LIGHT

        fun fromStorage(value: String?): FausThemeId = entries.firstOrNull { it.storageValue == value } ?: DEFAULT
    }
}

/** A gradient stop: position in 0..1 and its color. */
internal typealias Stop = Pair<Float, Color>

/** One renderable theme: dark/light system chrome, semantic colors and brand-surface recipes. */
@Immutable
internal data class FausTheme(
    val id: FausThemeId,
    val isDark: Boolean,
    val palette: FausPalette,
    val decor: FausDecor,
)

/**
 * Semantic color tokens (iOS `FausPalette`). Faus Light keeps the iOS light-appearance system
 * values the app has always used, so both platforms resolve the same pixels.
 */
@Immutable
internal data class FausPalette(
    // Surfaces
    val background: Color,
    val secondaryBackground: Color,
    val cardBackground: Color,
    val surface: Color,
    val elevatedSurface: Color,
    val pageBackground: Color,
    val popupBackground: Color,
    val menuBackground: Color,
    /** Disabled buttons, inactive tracks and quiet borders (iOS systemGray4 / systemGray3). */
    val controlFill: Color,
    val controlFillStrong: Color,
    val segmentSelected: Color,
    // Text
    val textPrimary: Color,
    val textSecondary: Color,
    val textTertiary: Color,
    /** Text and glyphs on accent fills (orange buttons, FAB, selection badges). */
    val onAccent: Color,
    /** Text and glyphs on hero surfaces. */
    val onHero: Color,
    // Lines and effects
    val separator: Color,
    val hairline: Color,
    val shadow: Color,
    val scrim: Color,
    // Semantic
    val primary: Color,
    val secondary: Color,
    val warning: Color,
    val error: Color,
    // House journey accents
    val accentOrange: Color,
    val accentOrangeInk: Color,
    val indigo: Color,
    val deepIndigo: Color,
    val blue: Color,
    val teal: Color,
    val deepTeal: Color,
    val buttonBlue: Color,
    val purple: Color,
    val errorRed: Color,
    /** Fills behind white text; in light themes they equal the accents above. */
    val indigoFill: Color,
    val deepIndigoFill: Color,
    val tealFill: Color,
    // Brand
    val brandLight: Color,
    val brandOrange: Color,
    val deepBerry: Color,
    val markBerry: Color,
    val spinnerRed: Color,
    val spinnerBerry: Color,
    /** Ambient line inks of [FausBackdrop]. */
    val softApricot: Color,
    val softOrange: Color,
    val softBerry: Color,
    /** SwiftUI `Color.orange`, used by the decorative capsules. */
    val systemOrange: Color,
    // Chore status
    val statusDraft: Color,
    val statusProgress: Color,
    val statusInTest: Color,
    val statusCompleted: Color,
    val statusFailed: Color,
)

/** How the brand surfaces are painted (iOS `FausDecor`); components read these, not the id. */
@Immutable
internal data class FausDecor(
    /** Top cards of the main tabs, popup headers. */
    val heroStops: List<Stop>,
    /** Bloom from the top-end corner over [heroStops]; transparent turns it off. */
    val heroGlow: Color,
    val heroBorder: List<Color>,
    /** Circles and capsules on hero surfaces (components apply their own alpha). */
    val heroOrnament: Color,
    val heroShadow: Color,
    val heroAccentText: Color,
    val heroFrame: List<Color>,
    val heroTile: Color,
    /** Full-bleed headers: auth hero and the splash. */
    val headerStops: List<Stop>,
    val headerGlow: Color,
    val tabBarStops: List<Stop>,
    val tabBarGlow: Color,
    val tabBarBorder: List<Color>,
    val tabBarShadow: Color,
    val tabItem: Color,
    val tabItemSelected: Color,
    val tabSelectedFill: Color,
    val tabSelectedBorder: Color,
    /** Selected tab glyph gradient; null uses [tabItemSelected]. */
    val tabSelectedIcon: List<Color>?,
    val homeItem: Color,
    val homeSelectedFill: Color,
    val homeSelectedBorder: Color,
    val fabColors: List<Color>,
    val fabShadow: Color,
    val popupGlow: Color,
    val popupBorder: Color,
    val badgeFill: List<Color>,
    val badgeHalo: Color,
    val badgeBorder: Color,
    val framedMarkFill: Color,
    val framedMarkRing: Color,
    val framedMarkGlow: Color,
    val splash: FausSplashStyle,
    /** The form sheet that rises over a full-bleed header (auth). */
    val sheetStops: List<Stop>,
    val sheetEdge: Color,
    val sheetEdgeGlow: Color,
    val sheetMesh: FausMeshTexture?,
    val backdrop: FausBackdrop,
    val popupBackdrop: FausBackdrop,
)

/**
 * Cold-start intro. The launch window stays brand orange; the header gradient fades in over
 * it, so dark themes cross-fade instead of flashing.
 */
@Immutable
/**
 * How the intro leaves the launch window, which is always `launch_background` orange so both
 * platforms start from the same frame (iOS caches its launch screen and cannot follow the theme).
 */
internal enum class FausLaunchHandOff {
    /** The header gradient fades in over the orange (themes whose header is orange). */
    FADE,
    /** The orange condenses into the ember glow behind the mark, uncovering the dark header. */
    CONDENSE,
}

internal data class FausSplashStyle(
    val launchHandOff: FausLaunchHandOff,
    /** Roof-F fill, roof to stem foot; one color draws it solid. */
    val mark: List<Color>,
    val markGlow: Color,
    val wordmark: Color,
    val wordmarkAccent: Color,
    val motto: Color,
    val ripple: Color,
    /** Ring traced along the closing circle so the edge reads against a dark app. */
    val revealRim: Color,
)

/** The page backdrop behind the primary screens (`mainScreenBackground`). */
@Immutable
internal data class FausBackdrop(
    val baseStops: List<Stop>,
    /** Base gradient direction as fractions of the size (start, end). */
    val baseStartX: Float = .5f,
    val baseEndX: Float = .5f,
    val wash: List<Color>,
    val glow: Color,
    val apricotStrength: Float,
    val orangeStrength: Float,
    val berryStrength: Float,
    val lineWidthBoost: Float,
    val mesh: FausMeshTexture?,
) {
    val drawsLines: Boolean get() = apricotStrength + orangeStrength + berryStrength > 0f
}

/** A hex grid of small holes with a warm rim (Faus Dark's perforated metal), in dp. */
@Immutable
internal data class FausMeshTexture(
    val hole: Color,
    val rim: Color,
    val sheen: Color,
    val pitch: Float = 5.4f,
    val rowPitch: Float = 4.675f,
    val holeRadius: Float = 1.6f,
    val rimRadius: Float = 2.05f,
)

internal val LocalFausTheme = staticCompositionLocalOf { FausThemes.light }

internal object FausThemes {
    private val lightBackdrop = FausBackdrop(
        baseStops = listOf(0f to Color.White),
        wash = listOf(Color(0xFFF59E59).copy(alpha = .035f), Color.Transparent, Color(0xFF75304D).copy(alpha = .018f)),
        glow = Color.Transparent,
        apricotStrength = 1f,
        orangeStrength = 1f,
        berryStrength = 1f,
        lineWidthBoost = 0f,
        mesh = null,
    )

    val light = FausTheme(
        id = FausThemeId.FAUS_LIGHT,
        isDark = false,
        palette = FausPalette(
            background = Color.White,
            secondaryBackground = Color(0xFFF2F2F7),
            cardBackground = Color(0xFFF2F2F7),
            surface = Color.White,
            elevatedSurface = Color(0xFFE5E5EA),
            pageBackground = Color(0xFFF2F2F7),
            popupBackground = Color.White,
            menuBackground = Color(0xFFF2F2F7),
            controlFill = Color(0xFFD1D1D6),
            controlFillStrong = Color(0xFFC7C7CC),
            segmentSelected = Color.White,
            textPrimary = Color.Black,
            textSecondary = Color(0x993C3C43),
            textTertiary = Color(0xFF8E8E93),
            onAccent = Color.White,
            onHero = Color.White,
            separator = Color(0x4A3C3C43),
            hairline = Color.Black.copy(alpha = .06f),
            shadow = Color.Black,
            scrim = Color.Black.copy(alpha = .55f),
            primary = Color(0xFF007AFF),
            secondary = Color(0xFF34C759),
            warning = Color(0xFFFF9500),
            error = Color(0xFFFF3B30),
            accentOrange = Color(0xFFFF7A26),
            accentOrangeInk = Color(0xFFBA400B),
            indigo = Color(0xFF45579E),
            deepIndigo = Color(0xFF33407A),
            blue = Color(0xFF3D7AB8),
            teal = Color(0xFF2E9187),
            deepTeal = Color(0xFF1A665E),
            buttonBlue = Color(0xFF2E5C96),
            purple = Color(0xFF7A61AD),
            errorRed = Color(0xFFD1454F),
            indigoFill = Color(0xFF45579E),
            deepIndigoFill = Color(0xFF33407A),
            tealFill = Color(0xFF1A665E),
            brandLight = Color(0xFFFF9138),
            brandOrange = Color(0xFFFF7A26),
            deepBerry = Color(0xFF611A38),
            markBerry = Color(0xFF8A2440),
            spinnerRed = Color(0xFFFF5F2E),
            spinnerBerry = Color(0xFFA3244A),
            softApricot = Color(0xFFF59E59),
            softOrange = Color(0xFFED7D40),
            softBerry = Color(0xFF75304D),
            systemOrange = Color(0xFFFF9500),
            statusDraft = Color(0xFF8C8C99),
            statusProgress = Color(0xFFFF7A26),
            statusInTest = Color(0xFF8033D9),
            statusCompleted = Color(0xFF33BF66),
            statusFailed = Color(0xFFD1454F),
        ),
        decor = FausDecor(
            heroStops = listOf(0f to Color(0xFFFF9138), .5f to Color(0xFFFF7A26), 1f to Color(0xFF611A38)),
            heroGlow = Color.Transparent,
            heroBorder = listOf(Color.White.copy(alpha = .42f), Color.White.copy(alpha = .06f)),
            heroOrnament = Color.White,
            heroShadow = Color(0xFF611A38).copy(alpha = .28f),
            heroAccentText = Color.White.copy(alpha = .88f),
            heroFrame = listOf(Color.White.copy(alpha = .95f)),
            heroTile = Color(0xFFFFF2E8),
            headerStops = listOf(0f to Color(0xFFFF9138), .4f to Color(0xFFFF7A26), 1f to Color(0xFF611A38)),
            headerGlow = Color.Transparent,
            tabBarStops = listOf(0f to Color(0xFFF59E59), .5f to Color(0xFFED7D40), 1f to Color(0xFF75304D)),
            tabBarGlow = Color.Transparent,
            tabBarBorder = listOf(Color.White.copy(alpha = .35f), Color.White.copy(alpha = .10f)),
            tabBarShadow = Color(0xFF75304D).copy(alpha = .3f),
            tabItem = Color.White.copy(alpha = .55f),
            tabItemSelected = Color.White,
            tabSelectedFill = Color.White.copy(alpha = .2f),
            tabSelectedBorder = Color.White.copy(alpha = .24f),
            tabSelectedIcon = null,
            homeItem = Color.White.copy(alpha = .62f),
            homeSelectedFill = Color(0xFFFFE0B3).copy(alpha = .30f),
            homeSelectedBorder = Color.White.copy(alpha = .30f),
            fabColors = listOf(Color(0xFF34C759), Color(0xFF34C759).copy(alpha = .8f)),
            fabShadow = Color(0xFF34C759).copy(alpha = .3f),
            popupGlow = Color.Transparent,
            popupBorder = Color.Transparent,
            badgeFill = listOf(Color.White),
            badgeHalo = Color.White,
            badgeBorder = Color.Transparent,
            framedMarkFill = Color.White,
            framedMarkRing = Color(0xFFFF7A26).copy(alpha = .55f),
            framedMarkGlow = Color.Transparent,
            splash = FausSplashStyle(
                launchHandOff = FausLaunchHandOff.FADE,
                mark = listOf(Color.White),
                markGlow = Color.Transparent,
                wordmark = Color.White,
                wordmarkAccent = Color.White.copy(alpha = .9f),
                motto = Color.White.copy(alpha = .82f),
                ripple = Color.White.copy(alpha = .55f),
                revealRim = Color.Transparent,
            ),
            sheetStops = listOf(0f to Color.White),
            sheetEdge = Color.Transparent,
            sheetEdgeGlow = Color.Transparent,
            sheetMesh = null,
            backdrop = lightBackdrop,
            popupBackdrop = lightBackdrop,
        ),
    )

    /** Ember on deep berry, from Design/AppIcon/FausCrew-AppIcon-Dark.svg. No neutral gray or black. */
    private val darkBackdrop = FausBackdrop(
        baseStops = listOf(0f to Color(0xFF24091A), .40f to Color(0xFF16070E), 1f to Color(0xFF14060C)),
        baseStartX = .33f,
        baseEndX = .67f,
        wash = listOf(Color.Transparent, Color.Transparent),
        glow = Color(0xFFFF7A26).copy(alpha = .18f),
        apricotStrength = 2.5f,
        orangeStrength = 2.35f,
        berryStrength = 3.35f,
        lineWidthBoost = .6f,
        mesh = FausMeshTexture(
            hole = Color(0xFF040102).copy(alpha = .75f),
            rim = Color(0xFFFFB080).copy(alpha = .16f),
            sheen = Color(0xFFFFBE96),
        ),
    )

    val dark = FausTheme(
        id = FausThemeId.FAUS_DARK,
        isDark = true,
        palette = FausPalette(
            background = Color(0xFF14060C),
            secondaryBackground = Color(0xFF321522),
            cardBackground = Color(0xFF261019),
            surface = Color(0xFF261019),
            elevatedSurface = Color(0xFF3E1A2A),
            pageBackground = Color(0xFF14060C),
            popupBackground = Color(0xFF14060C),
            menuBackground = Color(0xFF2A111C),
            controlFill = Color(0xFF4A2232),
            controlFillStrong = Color(0xFF5C2E40),
            segmentSelected = Color(0xFF3E1A2A),
            textPrimary = Color(0xFFFFF1E8),
            textSecondary = Color(0xFFD9B8B2),
            textTertiary = Color(0xFFA88A90),
            onAccent = Color(0xFF2A0A14),
            onHero = Color(0xFFFFF1E8),
            separator = Color(0xFFFF9A66).copy(alpha = .14f),
            hairline = Color(0xFFFF9A66).copy(alpha = .14f),
            shadow = Color(0xFF040102),
            scrim = Color(0xFF0A0306).copy(alpha = .72f),
            primary = Color(0xFF7DB9F2),
            secondary = Color(0xFF5FD8A2),
            warning = Color(0xFFFF8A3D),
            error = Color(0xFFFF6B80),
            accentOrange = Color(0xFFFF7A26),
            accentOrangeInk = Color(0xFFFFB27A),
            indigo = Color(0xFF9FA8FF),
            deepIndigo = Color(0xFFB9BFFF),
            blue = Color(0xFF7DB9F2),
            teal = Color(0xFF4FD1BE),
            deepTeal = Color(0xFF36B5A2),
            buttonBlue = Color(0xFF4A86C8),
            purple = Color(0xFFC3A2FF),
            errorRed = Color(0xFFFF6B80),
            indigoFill = Color(0xFF6470D8),
            deepIndigoFill = Color(0xFF4A55B8),
            tealFill = Color(0xFF2FA894),
            brandLight = Color(0xFFFFA04D),
            brandOrange = Color(0xFFFF7A26),
            deepBerry = Color(0xFF5A1A33),
            markBerry = Color(0xFFFF6A2A),
            spinnerRed = Color(0xFFFF5E2E),
            spinnerBerry = Color(0xFFE24A80),
            softApricot = Color(0xFFFFA45C),
            softOrange = Color(0xFFFF7A26),
            softBerry = Color(0xFFE24A80),
            systemOrange = Color(0xFFFF7A26),
            statusDraft = Color(0xFFC2A7AF),
            statusProgress = Color(0xFFFF8A3D),
            statusInTest = Color(0xFFBA9DFF),
            statusCompleted = Color(0xFF5FD8A2),
            statusFailed = Color(0xFFFF6B80),
        ),
        decor = FausDecor(
            heroStops = listOf(0f to Color(0xFF8A2A48), .34f to Color(0xFF5A1A33), .70f to Color(0xFF2C0D1A), 1f to Color(0xFF14060C)),
            heroGlow = Color(0xFFFF7A26).copy(alpha = .46f),
            heroBorder = listOf(Color(0xFFFFA04D).copy(alpha = .40f), Color(0xFFFFA04D).copy(alpha = .12f)),
            heroOrnament = Color(0xFFFFA04D),
            heroShadow = Color(0xFF040102).copy(alpha = .6f),
            heroAccentText = Color(0xFFFFB27A),
            heroFrame = listOf(Color(0xFFFFA04D), Color(0xFFFF6A2A)),
            heroTile = Color(0xFF2A111C),
            headerStops = listOf(0f to Color(0xFF8A2A48), .34f to Color(0xFF5A1A33), .70f to Color(0xFF2C0D1A), 1f to Color(0xFF14060C)),
            headerGlow = Color(0xFFFF7A26).copy(alpha = .26f),
            tabBarStops = listOf(0f to Color(0xFF8A2A48), .34f to Color(0xFF5A1A33), .70f to Color(0xFF2C0D1A), 1f to Color(0xFF14060C)),
            tabBarGlow = Color(0xFFFF7A26).copy(alpha = .46f),
            tabBarBorder = listOf(Color(0xFFFFA04D).copy(alpha = .55f), Color(0xFFFFA04D).copy(alpha = .10f)),
            tabBarShadow = Color(0xFF040102).copy(alpha = .7f),
            tabItem = Color(0xFFD9B8B2),
            tabItemSelected = Color(0xFFFFB27A),
            tabSelectedFill = Color(0xFFFF7A26).copy(alpha = .17f),
            tabSelectedBorder = Color(0xFFFFA04D).copy(alpha = .38f),
            tabSelectedIcon = listOf(Color(0xFFFFA04D), Color(0xFFFF6A2A)),
            homeItem = Color(0xFFD9B8B2),
            homeSelectedFill = Color(0xFFFF7A26).copy(alpha = .18f),
            homeSelectedBorder = Color(0xFFFFA04D).copy(alpha = .40f),
            fabColors = listOf(Color(0xFFFFA04D), Color(0xFFFF7A26), Color(0xFFFF6A2A)),
            fabShadow = Color(0xFFFF6A2A).copy(alpha = .4f),
            popupGlow = Color(0xFFFF7A26).copy(alpha = .08f),
            popupBorder = Color(0xFFFFA04D).copy(alpha = .26f),
            badgeFill = listOf(Color(0xFF3D1426), Color(0xFF14060C)),
            badgeHalo = Color(0xFFFFA04D),
            badgeBorder = Color(0xFFFFA04D).copy(alpha = .55f),
            framedMarkFill = Color(0xFF170710),
            framedMarkRing = Color(0xFFFFA04D).copy(alpha = .62f),
            framedMarkGlow = Color(0xFFFF6A2A).copy(alpha = .22f),
            splash = FausSplashStyle(
                launchHandOff = FausLaunchHandOff.CONDENSE,
                mark = listOf(Color(0xFFFFB060), Color(0xFFFF8A3D), Color(0xFFFF6A2A)),
                markGlow = Color(0xFFFF6A2A).copy(alpha = .40f),
                wordmark = Color(0xFFFFF1E8),
                wordmarkAccent = Color(0xFFFFB27A),
                motto = Color(0xFFF2D3C8),
                ripple = Color(0xFFFFA04D).copy(alpha = .60f),
                revealRim = Color(0xFFFFA04D).copy(alpha = .60f),
            ),
            sheetStops = listOf(0f to Color(0xFF1E0A13), .18f to Color(0xFF14060C)),
            sheetEdge = Color(0xFFFFA04D).copy(alpha = .55f),
            sheetEdgeGlow = Color(0xFFFF6A2A).copy(alpha = .22f),
            sheetMesh = FausMeshTexture(
                hole = Color(0xFF040102).copy(alpha = .75f),
                rim = Color(0xFFFFB080).copy(alpha = .13f),
                sheen = Color(0xFFFFBE96),
            ),
            backdrop = darkBackdrop,
            // Popups sit on the same base as the page in dark themes.
            popupBackdrop = darkBackdrop,
        ),
    )

    val all: List<FausTheme> = listOf(light, dark)

    fun theme(id: FausThemeId): FausTheme = all.firstOrNull { it.id == id } ?: light
}
