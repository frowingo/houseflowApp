import SwiftUI

/// Merkezi tasarım sistemi - Tüm renkler, spacing, fontlar ve corner radius değerleri
/// Uygulama genelinde tutarlılık sağlamak için bu değerleri kullanın
enum AppDesign {
    
    // MARK: - Colors
    enum Colors {
        static let primary = Color.blue
        static let secondary = Color.green
        static let tertiary = Color.orange
        static let error = Color.red
        static let success = Color.green
        static let warning = Color.orange
        
        static let background = Color(.systemBackground)
        static let secondaryBackground = Color(.systemGray6)
        static let cardBackground = Color(.systemGray6)
        static let surface = Color(.systemBackground)
        
        static let text = Color.primary
        static let textPrimary = Color.primary
        static let textSecondary = Color.secondary
        static let textTertiary = Color.gray
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
        
        static let light = Shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
        static let medium = Shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 6)
        static let heavy = Shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
    }
    
    // MARK: - Animation
    enum Animation {
        static let quick = SwiftUI.Animation.easeInOut(duration: 0.2)
        static let standard = SwiftUI.Animation.easeInOut(duration: 0.3)
        static let slow = SwiftUI.Animation.easeInOut(duration: 0.4)
        static let spring = SwiftUI.Animation.interpolatingSpring(stiffness: 300, damping: 20)
    }
    
    // MARK: - Sizes
    enum Size {
        static let buttonHeight: CGFloat = 48
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
