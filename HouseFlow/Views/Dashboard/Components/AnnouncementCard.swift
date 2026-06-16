import SwiftUI

/// Duyuru kartı component'i - dashboard'da önemli mesajları gösterir
struct AnnouncementCard: View {
    @State private var isDismissed = false
    @State private var offsetX: CGFloat = 0
    @State private var opacity: Double = 1

    var body: some View {
        if !isDismissed {
            cardContent
                .offset(x: offsetX)
                .opacity(opacity)
                .transition(.asymmetric(
                    insertion: .move(edge: .top).combined(with: .opacity),
                    removal: .move(edge: .trailing).combined(with: .opacity)
                ))
        }
    }

    private var cardContent: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppDesign.Colors.tertiary)

                Text("Announcements")
                    .font(AppDesign.Typography.headline)
                    .foregroundColor(AppDesign.Colors.textPrimary)

                Spacer()

                // Mark as read button
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 13, weight: .semibold))
                        Text("Mark as read")
                            .font(AppDesign.Typography.caption)
                    }
                    .foregroundColor(AppDesign.Colors.primary)
                    .padding(.horizontal, AppDesign.Spacing.sm)
                    .padding(.vertical, 4)
                    .background(AppDesign.Colors.primary.opacity(0.10))
                    .clipShape(Capsule())
                }
            }

            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                Text("🎉 Welcome to HouseFlow!")
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundColor(AppDesign.Colors.textPrimary)

                Text("Keep your shared space organized by completing your assigned chores. Track progress and earn points!")
                    .font(AppDesign.Typography.subheadline)
                    .foregroundColor(AppDesign.Colors.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack {
                Spacer()
                Text("2 hours ago")
                    .font(AppDesign.Typography.caption)
                    .foregroundColor(AppDesign.Colors.textSecondary)
            }
        }
        .padding(AppDesign.Spacing.xl)
        .background(
            LinearGradient(
                colors: [
                    AppDesign.Colors.tertiary.opacity(0.1),
                    Color.yellow.opacity(0.05)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .cornerRadius(AppDesign.CornerRadius.lg)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .stroke(AppDesign.Colors.tertiary.opacity(0.2), lineWidth: 1)
        )
        .gesture(
            DragGesture()
                .onChanged { value in
                    if value.translation.width > 0 {
                        offsetX = value.translation.width
                        opacity = Double(max(0, 1 - value.translation.width / 180))
                    }
                }
                .onEnded { value in
                    if value.translation.width > 100 {
                        dismiss()
                    } else {
                        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                            offsetX = 0
                            opacity = 1
                        }
                    }
                }
        )
    }

    private func dismiss() {
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            isDismissed = true
        }
    }
}

#Preview {
    AnnouncementCard()
        .padding()
}
