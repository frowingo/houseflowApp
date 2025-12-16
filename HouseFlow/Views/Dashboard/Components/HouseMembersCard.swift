import SwiftUI

/// Ev üyelerini gösteren kart component'i
struct HouseMembersCard: View {
    let members: [User]
    
    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
            Text("House Members")
                .font(AppDesign.Typography.headline)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppDesign.Spacing.lg) {
                    ForEach(members) { member in
                        VStack(spacing: AppDesign.Spacing.sm) {
                            UserAvatar(user: member, size: AppDesign.Size.avatarLarge)
                            
                            Text(member.name)
                                .font(AppDesign.Typography.caption)
                                .fontWeight(.medium)
                        }
                    }
                }
                .padding(.horizontal, 4)
            }
        }
        .padding(AppDesign.Spacing.xl)
        .background(AppDesign.Colors.cardBackground)
        .cornerRadius(AppDesign.CornerRadius.lg)
        .shadow(
            color: AppDesign.Shadow.light.color,
            radius: AppDesign.Shadow.light.radius,
            x: AppDesign.Shadow.light.x,
            y: AppDesign.Shadow.light.y
        )
    }
}

#Preview {
    HouseMembersCard(members: [
        User(name: "Mahmut", points: 12),
        User(name: "Jane", points: 8),
        User(name: "Abdüllatif", points: 10),
        User(name: "Katya", points: 6)
    ])
    .padding()
}

#Preview("Dark Mode") {
    HouseMembersCard(members: [
        User(name: "Mahmut", points: 12),
        User(name: "Jane", points: 8),
        User(name: "Abdüllatif", points: 10)
    ])
    .padding()
    .preferredColorScheme(.dark)
}
