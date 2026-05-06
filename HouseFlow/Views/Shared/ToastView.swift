import SwiftUI

/// Global toast notification that slides in from the top.
/// Driven by `AppViewModel.toastMessage`.
struct ToastView: View {
    let message: String
    let isError: Bool

    var body: some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: isError ? "xmark.circle.fill" : "checkmark.circle.fill")
                .foregroundColor(isError ? AppDesign.Colors.error : AppDesign.Colors.success)
                .font(.system(size: 18, weight: .semibold))

            Text(message)
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.text)
                .multilineTextAlignment(.leading)
                .lineLimit(3)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, AppDesign.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                .fill(AppDesign.Colors.cardBackground)
                .shadow(
                    color: AppDesign.Shadow.medium.color,
                    radius: AppDesign.Shadow.medium.radius,
                    x: AppDesign.Shadow.medium.x,
                    y: AppDesign.Shadow.medium.y
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                .strokeBorder(
                    isError ? AppDesign.Colors.error.opacity(0.35) : AppDesign.Colors.success.opacity(0.35),
                    lineWidth: 1
                )
        )
        .padding(.horizontal, AppDesign.Spacing.xxl)
    }
}

#Preview {
    VStack(spacing: 16) {
        ToastView(message: "Something went wrong. Please try again.", isError: true)
        ToastView(message: "House created successfully!", isError: false)
    }
    .padding()
}
