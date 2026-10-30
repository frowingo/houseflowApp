import Combine
import FausCrewCore
import SwiftUI
import UIKit

// MARK: - Theme

/// One renderable theme: the color scheme it runs in, its semantic color tokens and the
/// decoration recipes of the brand surfaces. Adding a theme means adding an `AppThemeID` case
/// in Core and one `FausTheme` value below (Android mirrors it in `FausThemes.kt`).
struct FausTheme: Identifiable {
    let id: AppThemeID
    let colorScheme: ColorScheme
    let palette: FausPalette
    let decor: FausDecor

    var displayName: String { id.displayName }

    /// Picker copy (`ThemeSettingsPopup`); Android uses the same keys and fallbacks.
    var descriptionKey: String { "theme_\(id.rawValue)_description" }
    var descriptionFallback: String {
        switch id {
        case .fausLight: "Bright and warm, the classic FausCrew look."
        case .fausDark: "Ember glow on deep berry, easy on the eyes at night."
        }
    }

    /// Home-screen icon set (`ASSETCATALOG_COMPILER_ALTERNATE_APPICON_NAMES`); nil is the primary
    /// `AppIcon`. Android swaps the matching launcher alias (`FausThemeId.launcherAlias`).
    var alternateIconName: String? {
        switch id {
        case .fausLight: nil
        case .fausDark: "AppIconDark"
        }
    }

    static let all: [FausTheme] = [.fausLight, .fausDark]

    static func theme(for id: AppThemeID) -> FausTheme {
        all.first { $0.id == id } ?? .fausLight
    }
}

// MARK: - Semantic Colors

/// Semantic color tokens. Faus Light keeps the UIKit system colors the app has always used,
/// so subtrees that force the other color scheme (game scenes) render exactly as before.
struct FausPalette {
    // Surfaces
    let background: UIColor
    let secondaryBackground: UIColor
    let cardBackground: UIColor
    let surface: UIColor
    let elevatedSurface: UIColor
    let groupedBackground: UIColor
    let groupedSurface: UIColor
    let popupBackground: UIColor
    let menuBackground: UIColor
    /// Disabled buttons, inactive tracks and quiet borders.
    let controlFill: UIColor
    let controlFillStrong: UIColor
    /// The raised segment of a segmented switch.
    let segmentSelected: UIColor

    // Text
    let textPrimary: UIColor
    let textSecondary: UIColor
    let textTertiary: UIColor
    /// Text and glyphs on accent fills (orange buttons, FAB, selection badges).
    let onAccent: UIColor
    /// Text and glyphs on hero surfaces.
    let onHero: UIColor

    // Lines and effects
    let separator: UIColor
    let hairline: UIColor
    let shadow: UIColor
    let scrim: UIColor

    // Semantic
    let primary: UIColor
    let secondary: UIColor
    let tertiary: UIColor
    let success: UIColor
    let warning: UIColor
    let error: UIColor

    // House journey accents
    let accentOrange: UIColor
    let accentOrangeInk: UIColor
    let indigo: UIColor
    let deepIndigo: UIColor
    let blue: UIColor
    let teal: UIColor
    let deepTeal: UIColor
    let buttonBlue: UIColor
    let purple: UIColor
    let errorRed: UIColor
    /// Fills behind white text; in light themes they equal the accents above.
    let indigoFill: UIColor
    let deepIndigoFill: UIColor
    let tealFill: UIColor

    // Brand
    let brandOrangeLight: UIColor
    let brandOrange: UIColor
    let brandDeepBerry: UIColor
    let brandMarkBerry: UIColor
    let spinnerRed: UIColor
    let spinnerBerry: UIColor

    // Chore status
    let statusDraft: UIColor
    let statusProgress: UIColor
    let statusInTest: UIColor
    let statusCompleted: UIColor
    let statusFailed: UIColor
}

// MARK: - Decoration Recipes

/// How the brand surfaces are painted. Components read these through `@Environment(\.fausTheme)`
/// instead of branching on a theme id, so a new theme only supplies new values.
struct FausDecor {
    /// Top cards of the main tabs, popup headers and the tab bar.
    var heroStops: [Gradient.Stop]
    /// Bloom from the top-trailing corner over `heroStops`; `.clear` turns it off.
    var heroGlow: Color
    var heroBorder: [Color]
    /// Circles and capsules on hero surfaces (components apply their own opacity).
    var heroOrnament: Color
    var heroShadow: Color
    /// Hero subtitle / greeting text.
    var heroAccentText: Color
    /// Ring around the house picture on the dashboard hero.
    var heroFrame: [Color]
    /// Fill behind the house glyph when there is no house picture.
    var heroTile: Color

    /// Full-bleed headers: auth hero and the splash.
    var headerStops: [Gradient.Stop]
    /// Center bloom behind the logo on full-bleed headers.
    var headerGlow: Color

    var tabBarStops: [Gradient.Stop]
    var tabBarGlow: Color
    var tabBarBorder: [Color]
    var tabBarShadow: Color
    var tabItem: Color
    var tabItemSelected: Color
    var tabSelectedFill: Color
    var tabSelectedBorder: Color
    /// Selected tab glyph fill; `nil` uses `tabItemSelected`.
    var tabSelectedIconGradient: LinearGradient?
    /// The Home tab (long-press house switcher) has a larger, warmer capsule and glyph.
    var homeItem: Color
    var homeSelectedFill: Color
    var homeSelectedBorder: Color

    /// Primary floating action (new chore).
    var fabColors: [Color]
    var fabShadow: Color

    /// Popup body: a top-trailing bloom and an outline, both `.clear` when unused.
    var popupGlow: Color
    var popupBorder: Color

    /// Brand badge disc behind the logo (auth) and the framed loading mark.
    var badgeFill: [Color]
    var badgeHalo: Color
    var badgeBorder: Color
    var framedMarkFill: Color
    var framedMarkRing: Color
    var framedMarkGlow: Color

    var splash: FausSplashStyle

    /// The form sheet that rises over a full-bleed header (auth).
    var sheetStops: [Gradient.Stop]
    var sheetEdge: Color
    var sheetEdgeGlow: Color
    var sheetMesh: FausMeshTexture?

    var backdrop: FausBackdrop
    /// Popup bodies (`MainScreenBackground(surface: .popup)`).
    var popupBackdrop: FausBackdrop
}

/// How the intro leaves the system launch screen, which is always `LaunchBackground` orange:
/// iOS caches it and cannot follow an in-app theme, so every theme starts from the same frame.
enum FausLaunchHandOff {
    /// The header gradient fades in over the orange (themes whose header is orange).
    case fade
    /// The orange condenses into the ember glow behind the mark, uncovering the dark header.
    case condense
}

/// Cold-start intro (`FausSplashView`): starts on the `LaunchBackground` launch screen and hands
/// off to the theme's header gradient.
struct FausSplashStyle {
    var launchHandOff: FausLaunchHandOff
    /// Roof-F fill, roof to stem foot; one color draws it solid.
    var mark: [Color]
    var markGlow: Color
    var wordmark: Color
    var wordmarkAccent: Color
    var motto: Color
    var ripple: Color
    /// Ring traced along the closing circle so the edge reads against a dark app.
    var revealRim: Color
}

/// The page backdrop behind the primary screens (`MainScreenBackground`).
struct FausBackdrop {
    var baseStops: [Gradient.Stop]
    var baseStart: UnitPoint
    var baseEnd: UnitPoint
    /// Faint diagonal wash over the base.
    var wash: [Color]
    /// Bloom from the top-trailing corner; `.clear` turns it off.
    var glow: Color
    /// Ambient line inks and how strongly each one is drawn relative to the shared geometry.
    var apricotInk: Color
    var orangeInk: Color
    var berryInk: Color
    var apricotStrength: Double
    var orangeStrength: Double
    var berryStrength: Double
    var lineWidthBoost: CGFloat
    /// Perforated hex-mesh texture under the lines.
    var mesh: FausMeshTexture?

    var drawsLines: Bool { apricotStrength + orangeStrength + berryStrength > 0 }
}

/// A hex grid of small holes with a warm rim, faded by a radial mask toward the bottom-leading edge.
struct FausMeshTexture {
    var hole: Color
    var rim: Color
    var sheen: Color
    var pitch: CGFloat = 5.4
    var rowPitch: CGFloat = 4.675
    var holeRadius: CGFloat = 1.6
    var rimRadius: CGFloat = 2.05
}

// MARK: - Faus Light

extension FausTheme {
    private static let lightBackdrop = FausBackdrop(
        baseStops: [.init(color: Color(uiColor: .systemBackground), location: 0)],
        baseStart: .top,
        baseEnd: .bottom,
        wash: [
            Color(red: 0.96, green: 0.62, blue: 0.35).opacity(0.035),
            .clear,
            Color(red: 0.46, green: 0.19, blue: 0.30).opacity(0.018)
        ],
        glow: .clear,
        apricotInk: Color(red: 0.96, green: 0.62, blue: 0.35),
        orangeInk: Color(red: 0.93, green: 0.49, blue: 0.25),
        berryInk: Color(red: 0.46, green: 0.19, blue: 0.30),
        apricotStrength: 1,
        orangeStrength: 1,
        berryStrength: 1,
        lineWidthBoost: 0,
        mesh: nil
    )

    static let fausLight = FausTheme(
        id: .fausLight,
        colorScheme: .light,
        palette: FausPalette(
            background: .systemBackground,
            secondaryBackground: .systemGray6,
            cardBackground: .systemGray6,
            surface: .systemBackground,
            elevatedSurface: .systemGray5,
            groupedBackground: .systemGroupedBackground,
            groupedSurface: .secondarySystemGroupedBackground,
            popupBackground: .systemBackground,
            menuBackground: .secondarySystemBackground,
            controlFill: .systemGray4,
            controlFillStrong: .systemGray3,
            segmentSelected: .systemBackground,
            textPrimary: .label,
            textSecondary: .secondaryLabel,
            textTertiary: .systemGray,
            onAccent: .white,
            onHero: .white,
            separator: .separator,
            hairline: UIColor.black.withAlphaComponent(0.06),
            shadow: .black,
            scrim: UIColor.black.withAlphaComponent(0.55),
            primary: .systemBlue,
            secondary: .systemGreen,
            tertiary: .systemOrange,
            success: .systemGreen,
            warning: .systemOrange,
            error: .systemRed,
            accentOrange: UIColor(red: 1.0, green: 0.48, blue: 0.15, alpha: 1),
            accentOrangeInk: UIColor(red: 0.73, green: 0.25, blue: 0.045, alpha: 1),
            indigo: UIColor(red: 0.27, green: 0.34, blue: 0.62, alpha: 1),
            deepIndigo: UIColor(red: 0.20, green: 0.25, blue: 0.48, alpha: 1),
            blue: UIColor(red: 0.24, green: 0.48, blue: 0.72, alpha: 1),
            teal: UIColor(red: 0.18, green: 0.57, blue: 0.53, alpha: 1),
            deepTeal: UIColor(red: 0.10, green: 0.40, blue: 0.37, alpha: 1),
            buttonBlue: UIColor(red: 0.18, green: 0.36, blue: 0.59, alpha: 1),
            purple: UIColor(red: 0.48, green: 0.38, blue: 0.68, alpha: 1),
            errorRed: UIColor(red: 0.82, green: 0.27, blue: 0.31, alpha: 1),
            indigoFill: UIColor(red: 0.27, green: 0.34, blue: 0.62, alpha: 1),
            deepIndigoFill: UIColor(red: 0.20, green: 0.25, blue: 0.48, alpha: 1),
            tealFill: UIColor(red: 0.10, green: 0.40, blue: 0.37, alpha: 1),
            brandOrangeLight: UIColor(red: 1.0, green: 0.57, blue: 0.22, alpha: 1),
            brandOrange: UIColor(red: 1.0, green: 0.48, blue: 0.15, alpha: 1),
            brandDeepBerry: UIColor(red: 0.38, green: 0.10, blue: 0.22, alpha: 1),
            brandMarkBerry: UIColor(red: 0.54, green: 0.14, blue: 0.25, alpha: 1),
            spinnerRed: UIColor(red: 1.0, green: 0.37, blue: 0.18, alpha: 1),
            spinnerBerry: UIColor(red: 0.64, green: 0.14, blue: 0.29, alpha: 1),
            statusDraft: UIColor(red: 0.55, green: 0.55, blue: 0.6, alpha: 1),
            statusProgress: UIColor(red: 1.0, green: 0.48, blue: 0.15, alpha: 1),
            statusInTest: UIColor(red: 0.5, green: 0.2, blue: 0.85, alpha: 1),
            statusCompleted: UIColor(red: 0.2, green: 0.75, blue: 0.4, alpha: 1),
            statusFailed: UIColor(red: 0.82, green: 0.27, blue: 0.31, alpha: 1)
        ),
        decor: FausDecor(
            heroStops: [
                .init(color: Color(red: 1.0, green: 0.57, blue: 0.22), location: 0),
                .init(color: Color(red: 1.0, green: 0.48, blue: 0.15), location: 0.5),
                .init(color: Color(red: 0.38, green: 0.10, blue: 0.22), location: 1)
            ],
            heroGlow: .clear,
            heroBorder: [Color.white.opacity(0.42), Color.white.opacity(0.06)],
            heroOrnament: .white,
            heroShadow: Color(red: 0.38, green: 0.10, blue: 0.22).opacity(0.28),
            heroAccentText: Color.white.opacity(0.88),
            heroFrame: [Color.white.opacity(0.95)],
            heroTile: Color(red: 1.0, green: 0.95, blue: 0.91),
            headerStops: [
                .init(color: Color(red: 1.0, green: 0.57, blue: 0.22), location: 0),
                .init(color: Color(red: 1.0, green: 0.48, blue: 0.15), location: 0.4),
                .init(color: Color(red: 0.38, green: 0.10, blue: 0.22), location: 1)
            ],
            headerGlow: .clear,
            tabBarStops: [
                .init(color: Color(red: 0.96, green: 0.62, blue: 0.35), location: 0),
                .init(color: Color(red: 0.93, green: 0.49, blue: 0.25), location: 0.5),
                .init(color: Color(red: 0.46, green: 0.19, blue: 0.30), location: 1)
            ],
            tabBarGlow: .clear,
            tabBarBorder: [Color.white.opacity(0.35), Color.white.opacity(0.10)],
            tabBarShadow: Color(red: 0.46, green: 0.19, blue: 0.30).opacity(0.3),
            tabItem: Color.white.opacity(0.55),
            tabItemSelected: .white,
            tabSelectedFill: Color.white.opacity(0.2),
            tabSelectedBorder: Color.white.opacity(0.24),
            tabSelectedIconGradient: nil,
            homeItem: Color.white.opacity(0.62),
            homeSelectedFill: Color(red: 1.0, green: 0.88, blue: 0.70).opacity(0.30),
            homeSelectedBorder: Color.white.opacity(0.30),
            fabColors: [Color.green, Color.green.opacity(0.8)],
            fabShadow: Color.green.opacity(0.3),
            popupGlow: .clear,
            popupBorder: .clear,
            badgeFill: [.white],
            badgeHalo: .white,
            badgeBorder: .clear,
            framedMarkFill: Color(uiColor: .systemBackground),
            framedMarkRing: Color(red: 1.0, green: 0.48, blue: 0.15).opacity(0.55),
            framedMarkGlow: .clear,
            splash: FausSplashStyle(
                launchHandOff: .fade,
                mark: [.white],
                markGlow: .clear,
                wordmark: .white,
                wordmarkAccent: Color.white.opacity(0.9),
                motto: Color.white.opacity(0.82),
                ripple: Color.white.opacity(0.55),
                revealRim: .clear
            ),
            sheetStops: [.init(color: Color(uiColor: .systemBackground), location: 0)],
            sheetEdge: .clear,
            sheetEdgeGlow: .clear,
            sheetMesh: nil,
            backdrop: lightBackdrop,
            popupBackdrop: lightBackdrop
        )
    )
}

// MARK: - Faus Dark

/// Ember on deep berry, from Design/AppIcon/FausCrew-AppIcon-Dark.svg. No neutral gray or black.
extension FausTheme {
    private static let darkBackdrop = FausBackdrop(
        baseStops: [
            .init(color: Color(fausHex: 0x24091A), location: 0),
            .init(color: Color(fausHex: 0x16070E), location: 0.40),
            .init(color: Color(fausHex: 0x14060C), location: 1)
        ],
        baseStart: UnitPoint(x: 0.33, y: 0),
        baseEnd: UnitPoint(x: 0.67, y: 1),
        wash: [.clear],
        glow: Color(fausHex: 0xFF7A26).opacity(0.18),
        apricotInk: Color(fausHex: 0xFFA45C),
        orangeInk: Color(fausHex: 0xFF7A26),
        berryInk: Color(fausHex: 0xE24A80),
        apricotStrength: 2.5,
        orangeStrength: 2.35,
        berryStrength: 3.35,
        lineWidthBoost: 0.6,
        mesh: FausMeshTexture(
            hole: Color(fausHex: 0x040102).opacity(0.75),
            rim: Color(fausHex: 0xFFB080).opacity(0.16),
            sheen: Color(fausHex: 0xFFBE96)
        )
    )

    static let fausDark = FausTheme(
        id: .fausDark,
        colorScheme: .dark,
        palette: FausPalette(
            background: UIColor(fausHex: 0x14060C),
            secondaryBackground: UIColor(fausHex: 0x321522),
            cardBackground: UIColor(fausHex: 0x261019),
            surface: UIColor(fausHex: 0x261019),
            elevatedSurface: UIColor(fausHex: 0x3E1A2A),
            groupedBackground: UIColor(fausHex: 0x14060C),
            groupedSurface: UIColor(fausHex: 0x261019),
            popupBackground: UIColor(fausHex: 0x14060C),
            menuBackground: UIColor(fausHex: 0x2A111C),
            controlFill: UIColor(fausHex: 0x4A2232),
            controlFillStrong: UIColor(fausHex: 0x5C2E40),
            segmentSelected: UIColor(fausHex: 0x3E1A2A),
            textPrimary: UIColor(fausHex: 0xFFF1E8),
            textSecondary: UIColor(fausHex: 0xD9B8B2),
            textTertiary: UIColor(fausHex: 0xA88A90),
            onAccent: UIColor(fausHex: 0x2A0A14),
            onHero: UIColor(fausHex: 0xFFF1E8),
            separator: UIColor(fausHex: 0xFF9A66, alpha: 0.14),
            hairline: UIColor(fausHex: 0xFF9A66, alpha: 0.14),
            shadow: UIColor(fausHex: 0x040102),
            scrim: UIColor(fausHex: 0x0A0306, alpha: 0.72),
            primary: UIColor(fausHex: 0x7DB9F2),
            secondary: UIColor(fausHex: 0x5FD8A2),
            tertiary: UIColor(fausHex: 0xFF8A3D),
            success: UIColor(fausHex: 0x5FD8A2),
            warning: UIColor(fausHex: 0xFF8A3D),
            error: UIColor(fausHex: 0xFF6B80),
            accentOrange: UIColor(fausHex: 0xFF7A26),
            accentOrangeInk: UIColor(fausHex: 0xFFB27A),
            indigo: UIColor(fausHex: 0x9FA8FF),
            deepIndigo: UIColor(fausHex: 0xB9BFFF),
            blue: UIColor(fausHex: 0x7DB9F2),
            teal: UIColor(fausHex: 0x4FD1BE),
            deepTeal: UIColor(fausHex: 0x36B5A2),
            buttonBlue: UIColor(fausHex: 0x4A86C8),
            purple: UIColor(fausHex: 0xC3A2FF),
            errorRed: UIColor(fausHex: 0xFF6B80),
            indigoFill: UIColor(fausHex: 0x6470D8),
            deepIndigoFill: UIColor(fausHex: 0x4A55B8),
            tealFill: UIColor(fausHex: 0x2FA894),
            brandOrangeLight: UIColor(fausHex: 0xFFA04D),
            brandOrange: UIColor(fausHex: 0xFF7A26),
            brandDeepBerry: UIColor(fausHex: 0x5A1A33),
            brandMarkBerry: UIColor(fausHex: 0xFF6A2A),
            spinnerRed: UIColor(fausHex: 0xFF5E2E),
            spinnerBerry: UIColor(fausHex: 0xE24A80),
            statusDraft: UIColor(fausHex: 0xC2A7AF),
            statusProgress: UIColor(fausHex: 0xFF8A3D),
            statusInTest: UIColor(fausHex: 0xBA9DFF),
            statusCompleted: UIColor(fausHex: 0x5FD8A2),
            statusFailed: UIColor(fausHex: 0xFF6B80)
        ),
        decor: FausDecor(
            heroStops: [
                .init(color: Color(fausHex: 0x8A2A48), location: 0),
                .init(color: Color(fausHex: 0x5A1A33), location: 0.34),
                .init(color: Color(fausHex: 0x2C0D1A), location: 0.70),
                .init(color: Color(fausHex: 0x14060C), location: 1)
            ],
            heroGlow: Color(fausHex: 0xFF7A26).opacity(0.46),
            heroBorder: [Color(fausHex: 0xFFA04D).opacity(0.40), Color(fausHex: 0xFFA04D).opacity(0.12)],
            heroOrnament: Color(fausHex: 0xFFA04D),
            heroShadow: Color(fausHex: 0x040102).opacity(0.6),
            heroAccentText: Color(fausHex: 0xFFB27A),
            heroFrame: [Color(fausHex: 0xFFA04D), Color(fausHex: 0xFF6A2A)],
            heroTile: Color(fausHex: 0x2A111C),
            headerStops: [
                .init(color: Color(fausHex: 0x8A2A48), location: 0),
                .init(color: Color(fausHex: 0x5A1A33), location: 0.34),
                .init(color: Color(fausHex: 0x2C0D1A), location: 0.70),
                .init(color: Color(fausHex: 0x14060C), location: 1)
            ],
            headerGlow: Color(fausHex: 0xFF7A26).opacity(0.26),
            tabBarStops: [
                .init(color: Color(fausHex: 0x8A2A48), location: 0),
                .init(color: Color(fausHex: 0x5A1A33), location: 0.34),
                .init(color: Color(fausHex: 0x2C0D1A), location: 0.70),
                .init(color: Color(fausHex: 0x14060C), location: 1)
            ],
            tabBarGlow: Color(fausHex: 0xFF7A26).opacity(0.46),
            tabBarBorder: [Color(fausHex: 0xFFA04D).opacity(0.55), Color(fausHex: 0xFFA04D).opacity(0.10)],
            tabBarShadow: Color(fausHex: 0x040102).opacity(0.7),
            tabItem: Color(fausHex: 0xD9B8B2),
            tabItemSelected: Color(fausHex: 0xFFB27A),
            tabSelectedFill: Color(fausHex: 0xFF7A26).opacity(0.17),
            tabSelectedBorder: Color(fausHex: 0xFFA04D).opacity(0.38),
            tabSelectedIconGradient: LinearGradient(
                colors: [Color(fausHex: 0xFFA04D), Color(fausHex: 0xFF6A2A)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            homeItem: Color(fausHex: 0xD9B8B2),
            homeSelectedFill: Color(fausHex: 0xFF7A26).opacity(0.18),
            homeSelectedBorder: Color(fausHex: 0xFFA04D).opacity(0.40),
            fabColors: [Color(fausHex: 0xFFA04D), Color(fausHex: 0xFF7A26), Color(fausHex: 0xFF6A2A)],
            fabShadow: Color(fausHex: 0xFF6A2A).opacity(0.4),
            popupGlow: Color(fausHex: 0xFF7A26).opacity(0.08),
            popupBorder: Color(fausHex: 0xFFA04D).opacity(0.26),
            badgeFill: [Color(fausHex: 0x3D1426), Color(fausHex: 0x14060C)],
            badgeHalo: Color(fausHex: 0xFFA04D),
            badgeBorder: Color(fausHex: 0xFFA04D).opacity(0.55),
            framedMarkFill: Color(fausHex: 0x170710),
            framedMarkRing: Color(fausHex: 0xFFA04D).opacity(0.62),
            framedMarkGlow: Color(fausHex: 0xFF6A2A).opacity(0.22),
            splash: FausSplashStyle(
                launchHandOff: .condense,
                mark: [Color(fausHex: 0xFFB060), Color(fausHex: 0xFF8A3D), Color(fausHex: 0xFF6A2A)],
                markGlow: Color(fausHex: 0xFF6A2A).opacity(0.40),
                wordmark: Color(fausHex: 0xFFF1E8),
                wordmarkAccent: Color(fausHex: 0xFFB27A),
                motto: Color(fausHex: 0xF2D3C8),
                ripple: Color(fausHex: 0xFFA04D).opacity(0.60),
                revealRim: Color(fausHex: 0xFFA04D).opacity(0.60)
            ),
            sheetStops: [
                .init(color: Color(fausHex: 0x1E0A13), location: 0),
                .init(color: Color(fausHex: 0x14060C), location: 0.18)
            ],
            sheetEdge: Color(fausHex: 0xFFA04D).opacity(0.55),
            sheetEdgeGlow: Color(fausHex: 0xFF6A2A).opacity(0.22),
            sheetMesh: FausMeshTexture(
                hole: Color(fausHex: 0x040102).opacity(0.75),
                rim: Color(fausHex: 0xFFB080).opacity(0.13),
                sheen: Color(fausHex: 0xFFBE96)
            ),
            backdrop: darkBackdrop,
            // Popups sit on the same base as the page in dark themes.
            popupBackdrop: darkBackdrop
        )
    )
}

// MARK: - Runtime Resolution

/// The theme the dynamic color tokens resolve against. `ThemeStore` updates it before the
/// root color scheme flips, so every token re-resolves with the new palette.
enum FausThemeRuntime {
    private static let lock = NSLock()
    nonisolated(unsafe) private static var activeTheme: FausTheme = .fausLight

    static var active: FausTheme {
        lock.lock(); defer { lock.unlock() }
        return activeTheme
    }

    static func activate(_ theme: FausTheme) {
        lock.lock(); defer { lock.unlock() }
        activeTheme = theme
    }

    /// A subtree that forces the other color scheme (game scenes) resolves Faus Light's system
    /// colors in that scheme, which is how it rendered before themes existed.
    static func palette(for traits: UITraitCollection) -> FausPalette {
        let theme = active
        let style: UIUserInterfaceStyle = theme.colorScheme == .dark ? .dark : .light
        let traitStyle: UIUserInterfaceStyle = traits.userInterfaceStyle == .dark ? .dark : .light
        return traitStyle == style ? theme.palette : FausTheme.fausLight.palette
    }
}

extension Color {
    /// A token that follows the active theme, e.g. `Color.faus(\.background)`.
    static func faus(_ token: KeyPath<FausPalette, UIColor>) -> Color {
        Color(uiColor: UIColor { traits in
            FausThemeRuntime.palette(for: traits)[keyPath: token].resolvedColor(with: traits)
        })
    }

    init(fausHex hex: UInt32, opacity: Double = 1) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

extension UIColor {
    convenience init(fausHex hex: UInt32, alpha: CGFloat = 1) {
        self.init(
            red: CGFloat((hex >> 16) & 0xFF) / 255,
            green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255,
            alpha: alpha
        )
    }
}

// MARK: - Environment

private struct FausSelectedThemeKey: EnvironmentKey {
    static let defaultValue: FausTheme = .fausLight
}

extension EnvironmentValues {
    /// The user's theme, injected once at the app root.
    var fausSelectedTheme: FausTheme {
        get { self[FausSelectedThemeKey.self] }
        set { self[FausSelectedThemeKey.self] = newValue }
    }

    /// The theme this subtree renders. Like the color tokens, a subtree that forces the other
    /// color scheme falls back to Faus Light.
    var fausTheme: FausTheme {
        fausSelectedTheme.colorScheme == colorScheme ? fausSelectedTheme : .fausLight
    }
}

// MARK: - Store

/// Owns the persisted theme choice (Faus Light on first launch) and keeps the token runtime in sync.
@MainActor
final class ThemeStore: ObservableObject {
    @Published private(set) var themeID: AppThemeID

    private let preferences: any PreferencesStore

    init(preferences: any PreferencesStore = UserDefaults.standard) {
        self.preferences = preferences
        let stored = AppThemePreference.load(from: preferences)
        themeID = stored
        FausThemeRuntime.activate(FausTheme.theme(for: stored))
    }

    var theme: FausTheme { FausTheme.theme(for: themeID) }

    func select(_ id: AppThemeID) {
        guard id != themeID else { return }
        AppThemePreference.save(id, to: preferences)
        FausThemeRuntime.activate(FausTheme.theme(for: id))
        themeID = id
        syncAppIcon()
    }

    /// Points the home-screen icon at the theme's icon set. Also runs whenever the app becomes
    /// active, so a switch the system refused (or a restored backup) catches up later.
    func syncAppIcon() {
        let application = UIApplication.shared
        let name = theme.alternateIconName
        guard application.supportsAlternateIcons, application.alternateIconName != name else { return }
        // A failed switch is retried on the next activation.
        application.setAlternateIconName(name) { _ in }
    }
}
