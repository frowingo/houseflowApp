import SwiftUI

/// Card component for house selection options (Create/Join)
/// Design: Large icon, title, subtitle with shadow effects
struct HouseOptionCard: View {
    let title: String
    let subtitle: String
    let iconName: String
    let backgroundColor: Color
    
    var body: some View {
        VStack(spacing: AppDesign.Spacing.xxl) {
            iconSection
            contentSection
        }
        .padding(AppDesign.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .frame(height: 220)
        .background(AppDesign.Colors.surface)
        .cornerRadius(AppDesign.CornerRadius.xxl)
        .shadow(
            color: AppDesign.Shadow.medium.color,
            radius: AppDesign.Shadow.medium.radius,
            x: AppDesign.Shadow.medium.x,
            y: AppDesign.Shadow.medium.y
        )
    }
    
    // MARK: - Subviews
    
    private var iconSection: some View {
        Image(systemName: iconName)
            .font(.system(size: AppDesign.Size.iconExtraLarge, weight: .medium))
            .foregroundColor(.white)
            .frame(width: 100, height: 100)
            .background(backgroundColor)
            .clipShape(Circle())
            .shadow(
                color: backgroundColor.opacity(0.3),
                radius: 10,
                x: 0,
                y: 5
            )
    }
    
    private var contentSection: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            Text(title)
                .font(AppDesign.Typography.title3)
                .foregroundColor(AppDesign.Colors.text)
                .multilineTextAlignment(.center)
            
            Text(subtitle)
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(3)
        }
    }
}

// MARK: - Previews

#Preview("Create House Option") {
    HouseOptionCard(
        title: "Create New House",
        subtitle: "Start fresh with your roommates",
        iconName: "plus.circle.fill",
        backgroundColor: .blue
    )
    .padding()
}

#Preview("Join House Option") {
    HouseOptionCard(
        title: "Join Existing House",
        subtitle: "Enter an invite code to join",
        iconName: "person.2.circle.fill",
        backgroundColor: .green
    )
    .padding()
}

#Preview("Dark Mode") {
    VStack(spacing: 20) {
        HouseOptionCard(
            title: "Create New House",
            subtitle: "Start fresh with your roommates",
            iconName: "plus.circle.fill",
            backgroundColor: .blue
        )
        
        HouseOptionCard(
            title: "Join Existing House",
            subtitle: "Enter an invite code to join",
            iconName: "person.2.circle.fill",
            backgroundColor: .green
        )
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Custom Colors") {
    VStack(spacing: 20) {
        HouseOptionCard(
            title: "Premium House",
            subtitle: "Access exclusive features",
            iconName: "star.circle.fill",
            backgroundColor: .purple
        )
        
        HouseOptionCard(
            title: "Enterprise House",
            subtitle: "For large organizations",
            iconName: "building.2.circle.fill",
            backgroundColor: .orange
        )
    }
    .padding()
}
