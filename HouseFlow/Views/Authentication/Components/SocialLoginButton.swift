import FacebookCore
import HouseFlowCore
import SCSDKLoginKit
import SwiftUI

// MARK: - Social Login Button

struct SocialLoginButton<Icon: View>: View {
    private let iconView: Icon
    let name: String
    let backgroundColor: Color
    let foregroundColor: Color
    let borderColor: Color?
    let action: () -> Void

    init(
        name: String,
        backgroundColor: Color,
        foregroundColor: Color,
        borderColor: Color? = nil,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) {
        self.iconView = icon()
        self.name = name
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.borderColor = borderColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppDesign.Spacing.xs) {
                iconView
                    .frame(width: 22, height: 22)
                Text(name)
                    .font(AppDesign.Typography.caption)
                    .foregroundColor(foregroundColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .stroke(borderColor ?? Color.clear, lineWidth: 1)
            )
            .cornerRadius(AppDesign.CornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
            .stroke(borderColor ?? Color.clear, lineWidth: 1)
    }
}

// MARK: - Brand Logos

/// The providers' own marks, never redrawn: Google's "G" ships in GoogleSignIn's resources and is
/// copied into Assets.xcassets; Facebook's "f" is drawn by the Facebook SDK; Snapchat's ghost comes
/// from Snap Login Kit's asset catalog; Apple's logo is the system glyph.
struct SocialBrandLogo: View {
    let provider: SocialProvider
    var size: CGFloat = 22

    var body: some View {
        switch provider {
        case .google:
            // Google's guidelines size the mark at 18pt inside the button.
            Image("GoogleLogo")
                .resizable()
                .interpolation(.high)
                .frame(width: 18, height: 18)
        case .apple:
            Image(systemName: "applelogo")
                .font(.system(size: size - 2))
                .foregroundColor(.white)
        case .facebook:
            if let image = Self.facebookLogo(size: size) {
                Image(uiImage: image)
            }
        case .snapchat:
            if let image = Self.snapchatGhost {
                Image(uiImage: image)
                    .resizable()
                    .scaledToFit()
                    .frame(width: size, height: size)
            }
        case .email:
            EmptyView()
        }
    }

    /// The white "f" Facebook's own login button draws. `_FBLogo` is SDK-internal, so recheck it
    /// on each Facebook SDK upgrade.
    private static func facebookLogo(size: CGFloat) -> UIImage? {
        _FBLogo().image(size: CGSize(width: size, height: size), color: .white)
    }

    private static let snapchatGhost = UIImage(
        named: "snaplogin_button_ghost", in: Bundle(for: SCSDKLoginClient.self), compatibleWith: nil
    )
}

/// Brand background colors from each provider's guidelines.
enum SocialBrandColor {
    static let facebook = Color(red: 0x18 / 255, green: 0x77 / 255, blue: 0xF2 / 255)   // #1877F2
    static let snapchat = Color(red: 0xFF / 255, green: 0xFC / 255, blue: 0x00 / 255)   // #FFFC00
}

// MARK: - Previews

#Preview("All Social Buttons") {
    HStack(spacing: 16) {
        SocialLoginButton(name: "Google", backgroundColor: .white, foregroundColor: .black,
                          borderColor: .gray.opacity(0.3), action: {}) { SocialBrandLogo(provider: .google) }
        SocialLoginButton(name: "Apple", backgroundColor: .black, foregroundColor: .white,
                          action: {}) { SocialBrandLogo(provider: .apple) }
        SocialLoginButton(name: "Facebook", backgroundColor: SocialBrandColor.facebook, foregroundColor: .white,
                          action: {}) { SocialBrandLogo(provider: .facebook) }
        SocialLoginButton(name: "Snapchat", backgroundColor: SocialBrandColor.snapchat, foregroundColor: .black,
                          action: {}) { SocialBrandLogo(provider: .snapchat) }
    }
    .padding()
}
