import SwiftUI

/// Info row component for step-by-step instructions
/// Features: Numbered badge, description text
struct InfoRow: View {
    let number: String
    let text: String
    
    var body: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            numberBadge
            descriptionText
            Spacer()
        }
    }
    
    // MARK: - Subviews
    
    private var numberBadge: some View {
        Text(number)
            .font(AppDesign.Typography.caption)
            .foregroundColor(.white)
            .frame(width: 20, height: 20)
            .background(AppDesign.Colors.primary)
            .clipShape(Circle())
    }
    
    private var descriptionText: some View {
        Text(text)
            .font(AppDesign.Typography.caption)
            .foregroundColor(AppDesign.Colors.textSecondary)
    }
}

// MARK: - Previews

#Preview("Single Row") {
    InfoRow(number: "1", text: "Ask the home owner for the invite code")
        .padding()
}

#Preview("Multiple Rows") {
    VStack(spacing: 8) {
        InfoRow(number: "1", text: "Ask the home owner for the invite code")
        InfoRow(number: "2", text: "Enter the 6–8 character code above")
        InfoRow(number: "3", text: "Tap \"Join House\" button")
    }
    .padding()
}

#Preview("Dark Mode") {
    VStack(spacing: 8) {
        InfoRow(number: "1", text: "Step one description")
        InfoRow(number: "2", text: "Step two description")
        InfoRow(number: "3", text: "Step three description")
    }
    .padding()
    .preferredColorScheme(.dark)
}
