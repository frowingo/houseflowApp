package com.fauscrew.ui.theme

import androidx.annotation.ColorRes
import androidx.annotation.DrawableRes
import androidx.annotation.StyleRes
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import com.fauscrew.R

/**
 * The visual themes the app can render. `storageValue` is the on-device contract shared with
 * iOS (`AppThemeID` in FausCrewCore), so a new theme is one entry here plus one [FausTheme]
 * below, mirroring `FausTheme.swift`.
 */
internal enum class FausThemeId(val storageValue: String, val displayName: String) {
    FAUS_LIGHT("faus_light", "Faus Light"),
    FAUS_DARK("faus_dark", "Faus Dark"),
    FAUS_BLOOM("faus_bloom", "Faus Bloom"),
    FAUS_WEB("faus_web", "Faus Web"),
    ;

    /**
     * Picker copy key; iOS `AppThemeID.descriptionKey`. Faus Bloom keeps the key it had under
     * its former storage value, so copy already published for it stays in use.
     */
    val descriptionKey: String
        get() = if (this == FAUS_BLOOM) "theme_fause_bloom_description" else "theme_${storageValue}_description"

    val descriptionFallback: String
        get() = when (this) {
            FAUS_LIGHT -> "Bright and warm, the classic FausCrew look."
            FAUS_DARK -> "Ember glow on deep berry, easy on the eyes at night."
            FAUS_BLOOM -> "A calm morning garden of vines and flowers on marbled blush."
            FAUS_WEB -> "Imperial blue cards on a sky of webs, lit by a crimson city glow."
        }

    /** Manifest `activity-alias` that carries this theme's launcher icon; iOS `alternateIconName`. */
    val launcherAlias: String
        get() = when (this) {
            FAUS_LIGHT -> "LauncherFausLight"
            FAUS_DARK -> "LauncherFausDark"
            FAUS_BLOOM -> "LauncherFausBloom"
            FAUS_WEB -> "LauncherFausWeb"
        }

    /**
     * The system launch window's color on Android 12+: a stop near the middle of the header
     * gradient, where the splash mark sits. iOS cannot follow the theme and starts from black.
     */
    @get:ColorRes
    val launchColor: Int
        get() = when (this) {
            FAUS_LIGHT -> R.color.launch_light
            FAUS_DARK -> R.color.launch_dark
            FAUS_BLOOM -> R.color.launch_bloom
            FAUS_WEB -> R.color.launch_web
        }

    /** The style handed to `SplashScreen.setSplashScreenTheme`, which shows [launchColor]. */
    @get:StyleRes
    val launchStyle: Int
        get() = when (this) {
            FAUS_LIGHT -> R.style.Theme_FausCrew_Launch_Light
            FAUS_DARK -> R.style.Theme_FausCrew_Launch_Dark
            FAUS_BLOOM -> R.style.Theme_FausCrew_Launch_Bloom
            FAUS_WEB -> R.style.Theme_FausCrew_Launch_Web
        }

    companion object {
        /** First launch, and any stored value this build does not know, use Faus Light. */
        val DEFAULT = FAUS_LIGHT

        /** Names a theme was saved under before it was renamed (iOS `AppThemeID(storageValue:)`). */
        private val legacyStorageValues = mapOf("fause_bloom" to FAUS_BLOOM)

        fun fromStorage(value: String?): FausThemeId =
            entries.firstOrNull { it.storageValue == value } ?: legacyStorageValues[value] ?: DEFAULT
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
    /** Deep end of accent gradients such as the publish button (iOS `accentOrangeDeep`). */
    val accentOrangeDeep: Color,
    /** Chore difficulty chips (easy, medium, hard). */
    val levelEasy: Color,
    val levelMedium: Color,
    val levelHard: Color,
    /** Profile and house accents: create house, notifications, owner badge, birthday. */
    val tintCreate: Color,
    val tintNotifications: Color,
    val tintOwner: Color,
    val tintBirthday: Color,
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
    /**
     * Text drawn straight on the page backdrop (screen titles, empty states, onboarding). Only
     * themes whose backdrop and cards contrast differently (Faus Web: sky page, imperial
     * cards) set these; null uses the regular text tokens.
     */
    val pageTextOverride: Color? = null,
    val pageTextSecondaryOverride: Color? = null,
    val pageTextTertiaryOverride: Color? = null,
    /** Links drawn on the page backdrop; null uses [accentOrangeInk]. */
    val pageAccentOverride: Color? = null,
) {
    val pageText: Color get() = pageTextOverride ?: textPrimary
    val pageTextSecondary: Color get() = pageTextSecondaryOverride ?: textSecondary
    val pageTextTertiary: Color get() = pageTextTertiaryOverride ?: textTertiary
    val pageAccent: Color get() = pageAccentOverride ?: accentOrangeInk
}

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
    /** What the hero surfaces (cards, popup headers, tab bar, full-bleed headers) are decorated with. */
    val ornament: FausOrnament = FausOrnament.GEOMETRIC,
    /** Pulsing ring around the profile avatar. */
    val avatarRing: List<Color> = listOf(Color(0xFFFFC766), Color(0xFFFF7A26), Color(0xFFA6330D), Color(0xFFFFC766)),
    /** Profile avatar fill when there is no photo. */
    val avatarFallback: List<Color> = listOf(Color(0xFFF27F14), Color(0xFFC75208)),
    /** A small blossom tucked on the brand badge halo (auth, house selection); null draws none. */
    val badgeBlossom: FausGarden? = null,
    /** Texture and corner garden of the auth form sheet. */
    val sheetMarble: FausMarble? = null,
    val sheetGarden: FausGarden? = null,
    /** Lighter tone the main cards fade from at their top-end corner; transparent keeps them flat. */
    val cardSheen: Color = Color.Transparent,
    /** The roof-F mark ends in a small orb web instead of a dot (Faus Web). */
    val webDotMark: Boolean = false,
    /** Small selected labels, chevrons and chips on dark cards; null keeps the brand orange. */
    val accentOnCard: Color? = null,
)

/** Decoration family of the hero surfaces (iOS `FausOrnament`). */
internal enum class FausOrnament {
    /** Layered circles and tilted capsules (Faus Light, Faus Dark). */
    GEOMETRIC,
    /** A large petal flower, its outline, a leaf and a blush sprig (Faus Bloom). */
    BLOOM,
    /** A corner orb web, an angled silk strand and crimson/sky glows (Faus Web). */
    WEB,
}

/** A marbled (ebru) texture image laid over a backdrop base, top-aligned and filling it. */
@Immutable
internal data class FausMarble(@DrawableRes val image: Int, val opacity: Float)

/** Vines, leaves and flowers drawn at the edges of a backdrop (iOS `FausGarden`). */
@Immutable
internal data class FausGarden(
    val vine: Color,
    val leaf: Color,
    val leafAlt: Color,
    /** Daisies and drifting petals. */
    val petal: Color,
    /** Wild roses and tulips. */
    val rose: Color,
    /** Buds and berries. */
    val mauve: Color,
    val wine: Color,
    val sky: Color,
    val pollen: Color,
    val blossomHeart: Color,
)

/**
 * Cold-start intro. It starts on the launch window's color ([FausThemeId.launchColor] on
 * Android 12+, black before that) and fades the theme's header gradient in over it.
 */
@Immutable
internal data class FausSplashStyle(
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
    /** Marbled texture over the base. */
    val marble: FausMarble? = null,
    /** Vines and flowers over everything else. */
    val garden: FausGarden? = null,
    /** Soft light high in the middle of the page, over the texture; transparent turns it off. */
    val centerGlow: Color = Color.Transparent,
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
            accentOrangeDeep = Color(0xFFE65714),
            levelEasy = Color(0xFF33BF66),
            levelMedium = Color(0xFFFF7A26),
            levelHard = Color(0xFFE63340),
            tintCreate = Color(0xFFE5620F),
            tintNotifications = Color(0xFFF2731A),
            tintOwner = Color(0xFFEB782E),
            tintBirthday = Color(0xFFE6731A),
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
            accentOrangeDeep = Color(0xFFE65714),
            levelEasy = Color(0xFF33BF66),
            levelMedium = Color(0xFFFF7A26),
            levelHard = Color(0xFFE63340),
            tintCreate = Color(0xFFE5620F),
            tintNotifications = Color(0xFFF2731A),
            tintOwner = Color(0xFFEB782E),
            tintBirthday = Color(0xFFE6731A),
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

    /**
     * Flowers, vines and calm: a blush, marbled light theme. Green (#336063) carries and
     * completes, wine (#6A122F) takes the accent-orange role, every gradient runs green → wine.
     */
    private val bloomGarden = FausGarden(
        vine = Color(0xFF336063),
        leaf = Color(0xFF336063),
        leafAlt = Color(0xFF4D869B),
        petal = Color(0xFFEBC3CF),
        rose = Color(0xFFC98399),
        mauve = Color(0xFF94506D),
        wine = Color(0xFF6A122F),
        sky = Color(0xFF88BAC8),
        pollen = Color(0xFFD9A441),
        blossomHeart = Color(0xFFFFF4E6),
    )

    private val bloomBackdrop = FausBackdrop(
        baseStops = listOf(0f to Color(0xFFFAF0F3), 1f to Color(0xFFF6E7EC)),
        wash = listOf(Color.Transparent, Color.Transparent, Color(0xFF88BAC8).copy(alpha = .10f)),
        glow = Color(0xFFC98399).copy(alpha = .16f),
        apricotStrength = 1.6f,
        orangeStrength = .9f,
        berryStrength = .7f,
        lineWidthBoost = .2f,
        mesh = null,
        marble = FausMarble(R.drawable.bloom_marble, .23f),
        garden = bloomGarden,
    )

    private val bloomPopupBackdrop = FausBackdrop(
        baseStops = listOf(0f to Color(0xFFF8EBEF)),
        wash = listOf(Color.Transparent, Color.Transparent),
        glow = Color.Transparent,
        apricotStrength = 1.4f,
        orangeStrength = .6f,
        berryStrength = .5f,
        lineWidthBoost = .2f,
        mesh = null,
        marble = FausMarble(R.drawable.bloom_marble, .18f),
        garden = bloomGarden,
    )

    val bloom = FausTheme(
        id = FausThemeId.FAUS_BLOOM,
        isDark = false,
        palette = FausPalette(
            background = Color(0xFFF8EBEF),
            secondaryBackground = Color(0xFFF1E1E7),
            cardBackground = Color(0xFFF1E1E7),
            surface = Color(0xFFFFF9FA),
            elevatedSurface = Color(0xFFEAD5DD),
            pageBackground = Color(0xFFF8EBEF),
            popupBackground = Color(0xFFF8EBEF),
            menuBackground = Color(0xFFFDF3F6),
            controlFill = Color(0xFFDDC3CC),
            controlFillStrong = Color(0xFFCDAEBA),
            segmentSelected = Color(0xFFFFF9FA),
            textPrimary = Color(0xFF2C3350),
            textSecondary = Color(0xFF4E566B),
            textTertiary = Color(0xFF8A93A6),
            onAccent = Color.White,
            onHero = Color.White,
            separator = Color(0xFF6A122F).copy(alpha = .12f),
            hairline = Color(0xFF2C3350).copy(alpha = .08f),
            shadow = Color(0xFF422C47),
            scrim = Color(0xFF1E2338).copy(alpha = .55f),
            primary = Color(0xFF4D869B),
            secondary = Color(0xFF336063),
            warning = Color(0xFFA86F2A),
            error = Color(0xFF8E1F42),
            accentOrange = Color(0xFF6A122F),
            accentOrangeInk = Color(0xFF6A122F),
            accentOrangeDeep = Color(0xFF4A0D22),
            levelEasy = Color(0xFF2F6F5E),
            levelMedium = Color(0xFFA86F2A),
            levelHard = Color(0xFF8E1F42),
            tintCreate = Color(0xFF6A122F),
            tintNotifications = Color(0xFFA23C5E),
            tintOwner = Color(0xFF6A122F),
            tintBirthday = Color(0xFFC0577A),
            indigo = Color(0xFF333A57),
            deepIndigo = Color(0xFF2A3049),
            blue = Color(0xFF4D869B),
            teal = Color(0xFF336063),
            deepTeal = Color(0xFF2A5053),
            buttonBlue = Color(0xFF3E6F80),
            purple = Color(0xFF422C47),
            errorRed = Color(0xFF8E1F42),
            indigoFill = Color(0xFF333A57),
            deepIndigoFill = Color(0xFF2A3049),
            tealFill = Color(0xFF336063),
            brandLight = Color(0xFF4D869B),
            brandOrange = Color(0xFF336063),
            deepBerry = Color(0xFF4A0D22),
            markBerry = Color(0xFF6A122F),
            spinnerRed = Color(0xFF94506D),
            spinnerBerry = Color(0xFF6A122F),
            softApricot = Color(0xFF88BAC8),
            softOrange = Color(0xFFC98399),
            softBerry = Color(0xFF336063),
            // The top-start sprig of the hero surfaces.
            systemOrange = Color(0xFFF2D6DE),
            statusDraft = Color(0xFF6B7489),
            statusProgress = Color(0xFFA86F2A),
            statusInTest = Color(0xFF6E4A7C),
            statusCompleted = Color(0xFF2F6F5E),
            statusFailed = Color(0xFF8E1F42),
        ),
        decor = FausDecor(
            heroStops = listOf(0f to Color(0xFF4D869B), .45f to Color(0xFF336063), 1f to Color(0xFF6A122F)),
            heroGlow = Color(0xFF88BAC8).copy(alpha = .34f),
            heroBorder = listOf(Color.White.copy(alpha = .42f), Color.White.copy(alpha = .06f)),
            heroOrnament = Color.White,
            heroShadow = Color(0xFF6A122F).copy(alpha = .26f),
            heroAccentText = Color(0xFFD7E9EE),
            heroFrame = listOf(Color.White.copy(alpha = .95f)),
            heroTile = Color(0xFFFCEFF3),
            headerStops = listOf(0f to Color(0xFF4D869B), .48f to Color(0xFF336063), 1f to Color(0xFF6A122F)),
            headerGlow = Color.Transparent,
            tabBarStops = listOf(0f to Color(0xFF5E97A8), .5f to Color(0xFF3E6F72), 1f to Color(0xFF6E2A44)),
            tabBarGlow = Color.Transparent,
            tabBarBorder = listOf(Color.White.copy(alpha = .35f), Color.White.copy(alpha = .10f)),
            tabBarShadow = Color(0xFF6E2A44).copy(alpha = .3f),
            tabItem = Color.White.copy(alpha = .6f),
            tabItemSelected = Color.White,
            tabSelectedFill = Color.White.copy(alpha = .2f),
            tabSelectedBorder = Color.White.copy(alpha = .24f),
            tabSelectedIcon = null,
            homeItem = Color.White.copy(alpha = .62f),
            homeSelectedFill = Color(0xFFF2D6DE).copy(alpha = .30f),
            homeSelectedBorder = Color.White.copy(alpha = .30f),
            fabColors = listOf(Color(0xFF336063), Color(0xFF336063).copy(alpha = .8f)),
            fabShadow = Color(0xFF336063).copy(alpha = .3f),
            popupGlow = Color.Transparent,
            popupBorder = Color.Transparent,
            badgeFill = listOf(Color.White, Color(0xFFFCEFF3)),
            badgeHalo = Color.White,
            badgeBorder = Color.Transparent,
            framedMarkFill = Color(0xFFFFF9FA),
            framedMarkRing = Color(0xFF6A122F).copy(alpha = .45f),
            framedMarkGlow = Color.Transparent,
            splash = FausSplashStyle(
                mark = listOf(Color.White),
                markGlow = Color(0xFF2A0A1A).copy(alpha = .25f),
                wordmark = Color.White,
                wordmarkAccent = Color(0xFFF6D9E1),
                motto = Color.White.copy(alpha = .82f),
                ripple = Color(0xFFF2D6DE).copy(alpha = .55f),
                revealRim = Color.Transparent,
            ),
            sheetStops = listOf(0f to Color(0xFFFAF0F3), 1f to Color(0xFFF6E7EC)),
            sheetEdge = Color.Transparent,
            sheetEdgeGlow = Color.Transparent,
            sheetMesh = null,
            backdrop = bloomBackdrop,
            popupBackdrop = bloomPopupBackdrop,
            ornament = FausOrnament.BLOOM,
            avatarRing = listOf(Color(0xFFF2D6DE), Color(0xFF88BAC8), Color(0xFF6A122F), Color(0xFFF2D6DE)),
            avatarFallback = listOf(Color(0xFF4D869B), Color(0xFF336063)),
            badgeBlossom = bloomGarden,
            sheetMarble = FausMarble(R.drawable.bloom_marble, .23f),
            sheetGarden = bloomGarden,
        ),
    )

    /**
     * Imperial blue (#001D51) cards on a sky page woven with one big orb web, noble crimson reds
     * (#C8161F → #4E0000) for accents and cream (#FCEBE5) for chips and dividers on the cards.
     * Dark system chrome so card and popup text is light; text straight on the sky page uses the
     * `pageText` tokens.
     */
    private val webCream = Color(0xFFFCEBE5)

    private val webHeroStops = listOf(
        0f to Color(0xFFC8161F),
        .26f to Color(0xFFA30F17),
        .46f to Color(0xFF7A0610),
        .60f to Color(0xFF4E0000),
        .76f to Color(0xFF1E0B3A),
        .92f to Color(0xFF0F3A93),
        1f to Color(0xFF2459C4),
    )

    private val webSkyStops = listOf(0f to Color(0xFF7FA6F7), .5f to Color(0xFF6690EC), 1f to Color(0xFF5781DE))

    private val webBackdrop = FausBackdrop(
        baseStops = webSkyStops,
        wash = listOf(Color.Transparent, Color.Transparent),
        glow = Color.Transparent,
        apricotStrength = 0f,
        orangeStrength = 0f,
        berryStrength = 0f,
        lineWidthBoost = 0f,
        mesh = null,
        marble = FausMarble(R.drawable.web_orb, 1f),
        centerGlow = webCream.copy(alpha = .5f),
    )

    /** Imperial, lighter at the top end, with the small-webs texture. */
    private val webPopupBackdrop = FausBackdrop(
        baseStops = listOf(0f to Color(0xFF0D3170), .72f to Color(0xFF001D51)),
        baseStartX = 1f,
        baseEndX = 0f,
        wash = listOf(Color.Transparent, Color.Transparent),
        glow = Color(0xFFE23A42).copy(alpha = .06f),
        apricotStrength = 0f,
        orangeStrength = 0f,
        berryStrength = 0f,
        lineWidthBoost = 0f,
        mesh = null,
        marble = FausMarble(R.drawable.web_scatter, .55f),
    )

    val web = FausTheme(
        id = FausThemeId.FAUS_WEB,
        isDark = true,
        palette = FausPalette(
            background = Color(0xFF001D51),
            secondaryBackground = Color(0xFF0A2B68),
            cardBackground = Color(0xFF001D51),
            surface = Color(0xFF0A2B68),
            elevatedSurface = Color(0xFF0A2B68),
            pageBackground = Color(0xFF001D51),
            popupBackground = Color(0xFF001D51),
            menuBackground = Color(0xFF0A2B68),
            controlFill = Color(0xFF123A80),
            controlFillStrong = Color(0xFF1B4790),
            segmentSelected = Color(0xFF123A80),
            textPrimary = Color(0xFFF3F6FF),
            textSecondary = Color(0xFFB8C6E8),
            textTertiary = Color(0xFF9AAAD6),
            onAccent = Color.White,
            onHero = Color.White,
            separator = webCream.copy(alpha = .4f),
            hairline = Color(0xFF8FB2FF).copy(alpha = .14f),
            shadow = Color(0xFF000820),
            scrim = Color(0xFF000820).copy(alpha = .62f),
            primary = Color(0xFF8FB2FF),
            secondary = Color(0xFF4FD6A0),
            warning = Color(0xFFFFB547),
            error = Color(0xFFF07F86),
            accentOrange = Color(0xFFC8161F),
            accentOrangeInk = Color(0xFFE8757C),
            accentOrangeDeep = Color(0xFF7A0610),
            levelEasy = Color(0xFF4FD6A0),
            levelMedium = Color(0xFFFFB547),
            levelHard = Color(0xFFC8161F),
            tintCreate = Color(0xFFC8161F),
            tintNotifications = Color(0xFFE23A42),
            tintOwner = Color(0xFFC8161F),
            tintBirthday = Color(0xFFE8757C),
            indigo = Color(0xFFA9B8FF),
            deepIndigo = Color(0xFFB9C6FF),
            blue = Color(0xFF8FB2FF),
            teal = Color(0xFF4FD6C2),
            deepTeal = Color(0xFF36B5A2),
            buttonBlue = Color(0xFF2E5FC4),
            purple = Color(0xFFC6A9FF),
            errorRed = Color(0xFFF07F86),
            indigoFill = Color(0xFF3F6FD1),
            deepIndigoFill = Color(0xFF2E5FC4),
            tealFill = Color(0xFF2FA894),
            brandLight = Color(0xFFD42A33),
            brandOrange = Color(0xFFC8161F),
            deepBerry = Color(0xFF4E0000),
            markBerry = Color(0xFF7A0610),
            spinnerRed = Color(0xFFE23A42),
            spinnerBerry = Color(0xFF8FB2FF),
            softApricot = Color.Transparent,
            softOrange = Color.Transparent,
            softBerry = Color.Transparent,
            // The top-start accent of the hero surfaces.
            systemOrange = webCream,
            statusDraft = Color(0xFFA3ABBF),
            statusProgress = Color(0xFFFFC46B),
            statusInTest = Color(0xFFC79BFF),
            statusCompleted = Color(0xFF6FE0B2),
            statusFailed = Color(0xFFF07F86),
            pageTextOverride = Color(0xFF001D51),
            pageTextSecondaryOverride = Color(0xFF1A3A78),
            pageTextTertiaryOverride = Color(0xFF2C4C8C),
            pageAccentOverride = Color(0xFF0F3A93),
        ),
        decor = FausDecor(
            heroStops = webHeroStops,
            heroGlow = Color.Transparent,
            heroBorder = listOf(webCream.copy(alpha = .34f), webCream.copy(alpha = .10f)),
            heroOrnament = webCream,
            heroShadow = Color(0xFF000820).copy(alpha = .5f),
            heroAccentText = webCream.copy(alpha = .88f),
            heroFrame = listOf(Color.White, webCream),
            heroTile = Color(0xFF001D51),
            headerStops = webHeroStops,
            headerGlow = Color(0xFFC8161F).copy(alpha = .22f),
            tabBarStops = listOf(0f to Color(0xFFC8161F), .35f to Color(0xFFA30F17), .65f to Color(0xFF7A0610), 1f to Color(0xFF4E0000)),
            tabBarGlow = Color(0xFFE23A42).copy(alpha = .34f),
            tabBarBorder = listOf(Color(0xFFE23A42).copy(alpha = .5f), Color(0xFFE23A42).copy(alpha = .12f)),
            tabBarShadow = Color(0xFF000820).copy(alpha = .55f),
            tabItem = Color.White.copy(alpha = .6f),
            tabItemSelected = Color.White,
            tabSelectedFill = webCream.copy(alpha = .26f),
            tabSelectedBorder = Color.White.copy(alpha = .24f),
            tabSelectedIcon = null,
            homeItem = Color.White.copy(alpha = .66f),
            homeSelectedFill = webCream.copy(alpha = .26f),
            homeSelectedBorder = Color.White.copy(alpha = .30f),
            fabColors = listOf(Color(0xFF3F6FD1), Color(0xFF0F3A93), Color(0xFF001D51)),
            fabShadow = Color(0xFF001D51).copy(alpha = .45f),
            popupGlow = Color(0xFFE23A42).copy(alpha = .06f),
            popupBorder = Color(0xFF8FB2FF).copy(alpha = .18f),
            badgeFill = listOf(Color(0xFF0F3A93), Color(0xFF001D51)),
            badgeHalo = webCream,
            badgeBorder = webCream.copy(alpha = .55f),
            framedMarkFill = Color(0xFF001D51),
            framedMarkRing = Color(0xFFC8161F).copy(alpha = .6f),
            framedMarkGlow = Color(0xFFE23A42).copy(alpha = .3f),
            splash = FausSplashStyle(
                mark = listOf(Color.White),
                markGlow = Color(0xFF1A0000).copy(alpha = .35f),
                wordmark = Color.White,
                wordmarkAccent = webCream,
                motto = webCream.copy(alpha = .88f),
                ripple = webCream.copy(alpha = .3f),
                revealRim = webCream.copy(alpha = .4f),
            ),
            sheetStops = webSkyStops,
            sheetEdge = Color(0xFFE23A42).copy(alpha = .55f),
            sheetEdgeGlow = Color(0xFF000820).copy(alpha = .3f),
            sheetMesh = null,
            backdrop = webBackdrop,
            popupBackdrop = webPopupBackdrop,
            ornament = FausOrnament.WEB,
            avatarRing = listOf(Color(0xFFC8161F), Color(0xFF8FB2FF), Color(0xFF4E0000), Color(0xFFC8161F)),
            avatarFallback = listOf(Color(0xFFC8161F), Color(0xFF4E0000)),
            sheetMarble = FausMarble(R.drawable.web_orb, 1f),
            cardSheen = Color(0xFF0D3170),
            webDotMark = true,
            accentOnCard = webCream,
        ),
    )

    val all: List<FausTheme> = listOf(light, dark, bloom, web)

    fun theme(id: FausThemeId): FausTheme = all.firstOrNull { it.id == id } ?: light
}
