import SwiftUI

/// Merkezi tasarım sistemi - Tüm renkler, spacing, fontlar ve corner radius değerleri
/// Uygulama genelinde tutarlılık sağlamak için bu değerleri kullanın
enum AppDesign {
    
    // MARK: - Colors
    /// Theme-aware tokens; values live in `FausTheme` (Views/Shared/Theme).
    enum Colors {
        static let primary = Color.faus(\.primary)
        static let secondary = Color.faus(\.secondary)
        static let tertiary = Color.faus(\.tertiary)
        static let error = Color.faus(\.error)
        static let success = Color.faus(\.success)
        static let warning = Color.faus(\.warning)
        
        static let background = Color.faus(\.background)
        static let secondaryBackground = Color.faus(\.secondaryBackground)
        static let cardBackground = Color.faus(\.cardBackground)
        static let surface = Color.faus(\.surface)
        static let elevatedSurface = Color.faus(\.elevatedSurface)
        static let popupBackground = Color.faus(\.popupBackground)
        static let menuBackground = Color.faus(\.menuBackground)
        static let controlFill = Color.faus(\.controlFill)
        static let controlFillStrong = Color.faus(\.controlFillStrong)
        static let segmentSelected = Color.faus(\.segmentSelected)
        
        static let text = Color.faus(\.textPrimary)
        static let textPrimary = Color.faus(\.textPrimary)
        static let textSecondary = Color.faus(\.textSecondary)
        static let textTertiary = Color.faus(\.textTertiary)
        static let onAccent = Color.faus(\.onAccent)
        static let onHero = Color.faus(\.onHero)

        static let separator = Color.faus(\.separator)
        static let hairline = Color.faus(\.hairline)
        static let shadow = Color.faus(\.shadow)
        static let scrim = Color.faus(\.scrim)
    }
    
    // MARK: - Spacing
    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let huge: CGFloat = 40
    }
    
    // MARK: - Corner Radius
    enum CornerRadius {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let circle: CGFloat = 999
    }
    
    // MARK: - Typography
    enum Typography {
        static let largeTitle = Font.largeTitle.weight(.bold)
        static let title = Font.title.weight(.bold)
        static let title2 = Font.title2.weight(.bold)
        static let title3 = Font.title3.weight(.semibold)
        static let headline = Font.headline.weight(.semibold)
        static let body = Font.body
        static let bodyBold = Font.body.weight(.medium)
        static let subheadline = Font.subheadline
        static let caption = Font.caption
        static let caption2 = Font.caption2
    }
    
    // MARK: - Shadows
    struct Shadow {
        let color: Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
        
        static let light = Shadow(color: AppDesign.Colors.shadow.opacity(0.1), radius: 8, x: 0, y: 2)
        static let medium = Shadow(color: AppDesign.Colors.shadow.opacity(0.12), radius: 16, x: 0, y: 6)
        static let heavy = Shadow(color: AppDesign.Colors.shadow.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Animation
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.interpolatingSpring(stiffness: 300, damping: 20)
    }
    
    // MARK: - Sizes
    enum Size {        static let buttonHeight: CGFloat = 48
        static let buttonHeightSmall: CGFloat = 44
        static let buttonHeightLarge: CGFloat = 56
        static let avatarSmall: CGFloat = 32
        static let avatarMedium: CGFloat = 40
        static let avatarLarge: CGFloat = 50
        static let fabSize: CGFloat = 56
        static let iconSmall: CGFloat = 16
        static let iconMedium: CGFloat = 20
        static let iconLarge: CGFloat = 24
        static let iconExtraLarge: CGFloat = 60
    }
}

// MARK: - House Journey Theme

/// Shared visual palette for the create / join / house-state journey.
/// Cool colors carry the screens while orange is reserved for small brand accents.
enum HouseJourneyTheme {
    static let accentOrange = Color.faus(\.accentOrange)
    static let accentOrangeInk = Color.faus(\.accentOrangeInk)
    static let indigo = Color.faus(\.indigo)
    static let deepIndigo = Color.faus(\.deepIndigo)
    static let blue = Color.faus(\.blue)
    static let teal = Color.faus(\.teal)
    static let deepTeal = Color.faus(\.deepTeal)
    static let buttonBlue = Color.faus(\.buttonBlue)
    static let purple = Color.faus(\.purple)
    static let indigoFill = Color.faus(\.indigoFill)
    static let deepIndigoFill = Color.faus(\.deepIndigoFill)
    static let tealFill = Color.faus(\.tealFill)
    static let errorRed = Color.faus(\.errorRed)

    static let pageBackground = Color.faus(\.groupedBackground)
    static let surface = Color.faus(\.groupedSurface)

    static var pageGradient: LinearGradient {
        LinearGradient(
            colors: [
                indigo.opacity(0.08),
                teal.opacity(0.035),
                pageBackground
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var primaryButtonGradient: LinearGradient {
        LinearGradient(
            colors: [indigoFill, deepIndigoFill],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    static var joinButtonGradient: LinearGradient {
        LinearGradient(
            colors: [tealFill, buttonBlue],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Hex Color helper
extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >>  8) & 0xFF) / 255
        let b = Double( int        & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}
