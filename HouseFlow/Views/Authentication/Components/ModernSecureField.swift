import SwiftUI

/// Modern styled secure field component with password visibility toggle
/// Features: Icon, focus state, show/hide password, validation border
struct ModernSecureField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    @FocusState.Binding var focusedField: AuthField?
    let fieldType: AuthField
    @State private var isSecure = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            titleLabel
            inputField
        }
    }
    
    // MARK: - Subviews
    
    private var titleLabel: some View {
        Text(title)
            .font(AppDesign.Typography.subheadline)
            .foregroundColor(AppDesign.Colors.text)
    }
    
    private var inputField: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            iconView
            passwordField
            visibilityToggle
        }
        .padding(.horizontal, AppDesign.Spacing.md)
        .padding(.vertical, AppDesign.Spacing.md)
        .background(fieldBackground)
        .animation(AppDesign.Animation.quick, value: isFocused)
    }
    
    private var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: 16))
            .foregroundColor(isFocused ? AppDesign.Colors.primary : AppDesign.Colors.textSecondary)
            .frame(width: 20)
    }
    
    @ViewBuilder
    private var passwordField: some View {
        if isSecure {
            SecureField(placeholder, text: $text)
                .font(.system(size: 16))
                .focused($focusedField, equals: fieldType)
        } else {
            TextField(placeholder, text: $text)
                .font(.system(size: 16))
                .focused($focusedField, equals: fieldType)
                .autocorrectionDisabled()
        }
    }
    
    private var visibilityToggle: some View {
        Button(action: {
            isSecure.toggle()
        }) {
            Image(systemName: isSecure ? "eye" : "eye.slash")
                .font(.system(size: 16))
                .foregroundColor(AppDesign.Colors.textSecondary)
        }
    }
    
    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
            .fill(AppDesign.Colors.cardBackground)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .stroke(
                        isFocused ? AppDesign.Colors.primary : Color.clear,
                        lineWidth: 2
                    )
            )
    }
    
    private var isFocused: Bool {
        focusedField == fieldType
    }
}

// MARK: - Previews

#Preview("Default") {
    @Previewable @FocusState var focusedField: AuthField?
    @Previewable @State var password = ""
    
    return ModernSecureField(
        title: "Password",
        text: $password,
        placeholder: "Enter your password",
        icon: "lock.fill",
        focusedField: $focusedField,
        fieldType: .password
    )
    .padding()
}

#Preview("With Password") {
    @Previewable @FocusState var focusedField: AuthField?
    @Previewable @State var password = "SecurePass123"
    
    return ModernSecureField(
        title: "Password",
        text: $password,
        placeholder: "Enter your password",
        icon: "lock.fill",
        focusedField: $focusedField,
        fieldType: .password
    )
    .padding()
}

#Preview("Focused State") {
    @Previewable @FocusState var focusedField: AuthField?
    @Previewable @State var password = ""
    
    return ModernSecureField(
        title: "Password",
        text: $password,
        placeholder: "Enter your password",
        icon: "lock.fill",
        focusedField: $focusedField,
        fieldType: .password
    )
    .padding()
    .onAppear {
        focusedField = .password
    }
}

#Preview("Dark Mode") {
    @Previewable @FocusState var focusedField: AuthField?
    @Previewable @State var password = "MyPassword"
    
    return ModernSecureField(
        title: "Password",
        text: $password,
        placeholder: "Enter your password",
        icon: "lock.fill",
        focusedField: $focusedField,
        fieldType: .password
    )
    .padding()
    .preferredColorScheme(.dark)
}
