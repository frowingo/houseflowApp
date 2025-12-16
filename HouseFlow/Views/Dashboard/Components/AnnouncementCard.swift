import SwiftUI

/// Duyuru kartı component'i - dashboard'da önemli mesajları gösterir
struct AnnouncementCard: View {
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack {
                Image(systemName: "megaphone.fill")
                    .font(.system(size: 18))
                    .foregroundColor(AppDesign.Colors.tertiary)
                
                Text("Announcements")
                    .font(AppDesign.Typography.headline)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                Text("🎉 Welcome to HouseFlow!")
                    .font(AppDesign.Typography.bodyBold)
                
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
    }
}

#Preview {
    AnnouncementCard()
        .padding()
}

#Preview("Dark Mode") {
    AnnouncementCard()
        .padding()
        .preferredColorScheme(.dark)
}
