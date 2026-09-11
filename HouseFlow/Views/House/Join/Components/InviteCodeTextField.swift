import SwiftUI

/// Custom text field style for invite code input
/// Features: Monospaced font, centered text, error state, validation border
struct InviteCodeTextField: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @Binding var text: String
    let isError: Bool
    @FocusState.Binding var isFocused: Bool
    let onSubmit: () -> Void
    
    var body: some View {
        TextField(appViewModel.localized("join_house_invite_placeholder"), text: $text)
            .font(.system(size: 18, weight: .medium, design: .monospaced))
            .multilineTextAlignment(.center)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .focused($isFocused)
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.vertical, AppDesign.Spacing.lg)
            .foregroundStyle(AppDesign.Colors.textPrimary)
            .background(fieldBackground)
            .onSubmit(onSubmit)
    }
    
    // MARK: - Background
    
    private var fieldBackground: some View {
        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
            .fill(HouseJourneyTheme.surface)
            .overlay(borderOverlay)
            .shadow(
                color: isFocused ? HouseJourneyTheme.accentOrange.opacity(0.12) : Color.black.opacity(0.035),
                radius: isFocused ? 10 : 5,
                x: 0,
                y: 3
            )
    }
    
    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
            .stroke(
                isError
                    ? AppDesign.Colors.error
                    : (isFocused ? HouseJourneyTheme.accentOrange : HouseJourneyTheme.indigo.opacity(0.12)),
                lineWidth: isFocused || isError ? 2 : 1
            )
            .animation(AppDesign.Animation.quick, value: isError)
            .animation(AppDesign.Animation.quick, value: isFocused)
    }
}

// MARK: - Previews

#Preview("Empty") {
    @Previewable @FocusState var focused: Bool
    @Previewable @State var code = ""
    
    return InviteCodeTextField(
        text: $code,
        isError: false,
        isFocused: $focused,
        onSubmit: {}
    )
    .padding()
}

#Preview("With Code") {
    @Previewable @FocusState var focused: Bool
    @Previewable @State var code = "HOUSE123"
    
    return InviteCodeTextField(
        text: $code,
        isError: false,
        isFocused: $focused,
        onSubmit: {}
    )
    .padding()
}

#Preview("Error State") {
    @Previewable @FocusState var focused: Bool
    @Previewable @State var code = "INVALID"
    
    return InviteCodeTextField(
        text: $code,
        isError: true,
        isFocused: $focused,
        onSubmit: {}
    )
    .padding()
}

#Preview("Dark Mode") {
    @Previewable @FocusState var focused: Bool
    @Previewable @State var code = "DEMO456"
    
    return InviteCodeTextField(
        text: $code,
        isError: false,
        isFocused: $focused,
        onSubmit: {}
    )
    .padding()
    .preferredColorScheme(.dark)
}
