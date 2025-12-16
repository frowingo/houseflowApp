import SwiftUI

/// Social login button component (Google, Apple, Snapchat, etc.)
/// Features: Icon, label, custom colors, border support
struct SocialLoginButton: View {
    let icon: String
    let name: String
    let backgroundColor: Color
    let foregroundColor: Color
    let borderColor: Color?
    let action: () -> Void
    
    init(
        icon: String,
        name: String,
        backgroundColor: Color,
        foregroundColor: Color,
        borderColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
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
                labelView
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(backgroundColor)
            .overlay(borderOverlay)
            .cornerRadius(AppDesign.CornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Subviews
    
    private var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: 20))
            .foregroundColor(foregroundColor)
    }
    
    private var labelView: some View {
        Text(name)
            .font(AppDesign.Typography.caption)
            .foregroundColor(foregroundColor)
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
            .stroke(borderColor ?? Color.clear, lineWidth: 1)
    }
}

// MARK: - Previews

#Preview("Google") {
    SocialLoginButton(
        icon: "globe",
        name: "Google",
        backgroundColor: .white,
        foregroundColor: .black,
        borderColor: .gray.opacity(0.3)
    ) {
        print("Google login")
    }
    .frame(width: 100)
    .padding()
}

#Preview("Apple") {
    SocialLoginButton(
        icon: "applelogo",
        name: "Apple",
        backgroundColor: .black,
        foregroundColor: .white
    ) {
        print("Apple login")
    }
    .frame(width: 100)
    .padding()
}

#Preview("Snapchat") {
    SocialLoginButton(
        icon: "camera.fill",
        name: "Snapchat",
        backgroundColor: .yellow,
        foregroundColor: .black
    ) {
        print("Snapchat login")
    }
    .frame(width: 100)
    .padding()
}

#Preview("All Social Buttons") {
    HStack(spacing: 16) {
        SocialLoginButton(
            icon: "globe",
            name: "Google",
            backgroundColor: .white,
            foregroundColor: .black,
            borderColor: .gray.opacity(0.3)
        ) {}
        
        SocialLoginButton(
            icon: "applelogo",
            name: "Apple",
            backgroundColor: .black,
            foregroundColor: .white
        ) {}
        
        SocialLoginButton(
            icon: "camera.fill",
            name: "Snapchat",
            backgroundColor: .yellow,
            foregroundColor: .black
        ) {}
    }
    .padding()
}

#Preview("Dark Mode") {
    HStack(spacing: 16) {
        SocialLoginButton(
            icon: "globe",
            name: "Google",
            backgroundColor: .white,
            foregroundColor: .black,
            borderColor: .gray.opacity(0.3)
        ) {}
        
        SocialLoginButton(
            icon: "applelogo",
            name: "Apple",
            backgroundColor: .black,
            foregroundColor: .white
        ) {}
    }
    .padding()
    .preferredColorScheme(.dark)
    .background(Color(.systemBackground))
}
