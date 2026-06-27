import SwiftUI

/// Duyuru kartı component'i - dashboard'da önemli mesajları gösterir
struct AnnouncementCard: View {
    @State private var isDismissed = false
    @State private var isClosing = false

    var body: some View {
        if !isDismissed {
            cardContent
                .scaleEffect(isClosing ? 0.96 : 1, anchor: .top)
                .opacity(isClosing ? 0 : 1)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .scale(scale: 0.96, anchor: .top).combined(with: .opacity)
                ))
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
            HStack(alignment: .top, spacing: AppDesign.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(AppDesign.Colors.tertiary.opacity(0.15))
                        .frame(width: 40, height: 40)
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(AppDesign.Colors.tertiary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text("Announcements")
                        .font(AppDesign.Typography.headline)
                        .foregroundColor(AppDesign.Colors.textPrimary)

                    Text("2 hours ago")
                        .font(AppDesign.Typography.caption)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                }

                Spacer()

                Button {
                    dismiss()
                } label: {
                    Image(systemName: "checkmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(AppDesign.Colors.tertiary)
                        .frame(width: 30, height: 30)
                        .background(AppDesign.Colors.tertiary.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                Text("Welcome to HouseFlow!")
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundColor(AppDesign.Colors.textPrimary)

                Text("Keep your shared space organized by completing your assigned chores. Track progress and earn points!")
                    .font(AppDesign.Typography.subheadline)
                    .foregroundColor(AppDesign.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppDesign.Spacing.xl)
        .background(
            ZStack {
                AppDesign.Colors.cardBackground
                LinearGradient(
                    colors: [
                        AppDesign.Colors.tertiary.opacity(0.13),
                        Color.yellow.opacity(0.06),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(AppDesign.Colors.tertiary.opacity(0.08))
                    .frame(width: 110, height: 110)
                    .offset(x: 150, y: -56)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .stroke(AppDesign.Colors.tertiary.opacity(0.22), lineWidth: 1)
        )
        .shadow(color: Color.orange.opacity(0.12), radius: 14, x: 0, y: 5)
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
            isClosing = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            withAnimation(.spring(response: 0.38, dampingFraction: 0.82)) {
                isDismissed = true
            }
        }
    }
}

#Preview {
    AnnouncementCard()
        .padding()
}
