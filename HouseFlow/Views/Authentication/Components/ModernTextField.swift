import SwiftUI

/// Modern styled text field component for authentication forms
/// Features: Icon, focus state, validation border, keyboard type support
struct ModernTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    let keyboardType: UIKeyboardType
    @FocusState.Binding var focusedField: AuthField?
    let fieldType: AuthField
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
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
            textField
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, AppDesign.Spacing.lg)
        .background(fieldBackground)
        .animation(AppDesign.Animation.quick, value: isFocused)
    }
    
    private var iconView: some View {
        Image(systemName: icon)
            .font(.system(size: 16))
            .foregroundColor(isFocused ? AppDesign.Colors.primary : AppDesign.Colors.textSecondary)
            .frame(width: 20)
    }
    
    private var textField: some View {
        TextField(placeholder, text: $text)
            .font(.system(size: 16))
            .textInputAutocapitalization(fieldType == .email ? .never : .none)
            .keyboardType(keyboardType)
            .focused($focusedField, equals: fieldType)
            .autocorrectionDisabled()
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

#Preview("Email Field") {
    @Previewable @FocusState var focusedField: AuthField?
    @Previewable @State var email = ""
    
    return ModernTextField(
        title: "Email Address",
        text: $email,
        placeholder: "your.email@example.com",
        icon: "envelope.fill",
        keyboardType: .emailAddress,
        focusedField: $focusedField,
        fieldType: .email
    )
    .padding()
}

#Preview("Name Field") {
    @Previewable @FocusState var focusedField: AuthField?
    @Previewable @State var name = ""
    
    return ModernTextField(
        title: "Full Name",
        text: $name,
        placeholder: "John Doe",
        icon: "person.circle.fill",
        keyboardType: .default,
        focusedField: $focusedField,
        fieldType: .name
    )
    .padding()
}

#Preview("Focused State") {
    @Previewable @FocusState var focusedField: AuthField?
    @Previewable @State var email = "test@example.com"
    
    return ModernTextField(
        title: "Email Address",
        text: $email,
        placeholder: "your.email@example.com",
        icon: "envelope.fill",
        keyboardType: .emailAddress,
        focusedField: $focusedField,
        fieldType: .email
    )
    .padding()
    .onAppear {
        focusedField = .email
    }
}

#Preview("Dark Mode") {
    @Previewable @FocusState var focusedField: AuthField?
    @Previewable @State var email = ""
    
    return VStack(spacing: 16) {
        ModernTextField(
            title: "Email Address",
            text: $email,
            placeholder: "your.email@example.com",
            icon: "envelope.fill",
            keyboardType: .emailAddress,
            focusedField: $focusedField,
            fieldType: .email
        )
        
        ModernTextField(
            title: "Phone Number",
            text: $email,
            placeholder: "+1 (555) 123-4567",
            icon: "phone.fill",
            keyboardType: .phonePad,
            focusedField: $focusedField,
            fieldType: .phone
        )
    }
    .padding()
    .preferredColorScheme(.dark)
}
