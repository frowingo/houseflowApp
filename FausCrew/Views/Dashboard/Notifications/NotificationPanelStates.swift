import SwiftUI

/// A placeholder row in the shape of `NotificationRow` while the first page loads.
struct NotificationSkeletonRow: View {
    @State private var pulse = false

    var body: some View {
        let bar = AppDesign.Colors.textTertiary.opacity(0.16)
        HStack(alignment: .top, spacing: AppDesign.Spacing.md) {
            Circle().fill(bar).frame(width: 36, height: 36)
            VStack(alignment: .leading, spacing: 8) {
                RoundedRectangle(cornerRadius: 4).fill(bar).frame(width: 90, height: 10)
                RoundedRectangle(cornerRadius: 5).fill(bar).frame(height: 14)
                RoundedRectangle(cornerRadius: 4).fill(bar.opacity(0.7)).frame(width: 160, height: 10)
            }
        }
        .padding(AppDesign.Spacing.lg)
        .padding(.leading, 4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg).fill(AppDesign.Colors.secondaryBackground))
        .opacity(pulse ? 0.55 : 1)
        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
        .onAppear { pulse = true }
        .accessibilityHidden(true)
    }
}

/// An icon, a message and, when `action` is set, the whole card as a retry button.
struct NotificationStatusCard: View {
    let icon: String
    let tint: Color
    let text: String
    var action: (() -> Void)? = nil

    var body: some View {
        if let action {
            Button(action: action) { card }
                .buttonStyle(.plain)
        } else {
            card
        }
    }

    private var card: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            Image(systemName: icon)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 60, height: 60)
                .background(tint.opacity(0.12), in: Circle())
            Text(text)
                .font(AppDesign.Typography.subheadline)
                .foregroundStyle(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.Spacing.xxl)
        .padding(.horizontal, AppDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(AppDesign.Colors.secondaryBackground)
        )
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
