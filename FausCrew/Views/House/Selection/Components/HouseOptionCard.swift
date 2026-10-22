import SwiftUI

/// Card component for house selection options (Create/Join)
/// Design: brand icon disc on the left, title and subtitle, chevron on the right.
struct HouseOptionCard: View {
    enum Kind {
        case create
        case join
    }

    let title: String
    let subtitle: String
    let kind: Kind

    var body: some View {
        HStack(spacing: AppDesign.Spacing.lg) {
            iconSection
            contentSection
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(HouseJourneyTheme.accentOrangeInk)
        }
        .padding(AppDesign.Spacing.xl)
        .frame(maxWidth: .infinity)
        .background(HouseJourneyTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xxl, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xxl, style: .continuous)
                .stroke(FausBrand.orange.opacity(0.18), lineWidth: 1)
        )
        .shadow(color: FausBrand.deepBerry.opacity(0.08), radius: 18, x: 0, y: 8)
    }

    // MARK: - Subviews

    @ViewBuilder
    private var iconSection: some View {
        switch kind {
        case .create:
            Circle()
                .fill(FausBrand.iconGradient)
                .frame(width: 64, height: 64)
                .overlay(FausHouseIcon(size: 34, fill: .color(.white)))
                .shadow(color: FausBrand.deepBerry.opacity(0.25), radius: 6, x: 0, y: 6)
                .overlay(alignment: .bottomTrailing) {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(FausBrand.orange)
                        .frame(width: 22, height: 22)
                        .background(
                            Circle()
                                .fill(Color.white)
                                .shadow(color: Color.black.opacity(0.12), radius: 2, x: 0, y: 2)
                        )
                        .offset(x: 2, y: 2)
                }
                .accessibilityHidden(true)
        case .join:
            Circle()
                .fill(FausBrand.deepBerry.opacity(0.09))
                .overlay(Circle().stroke(FausBrand.deepBerry.opacity(0.16), lineWidth: 1.5))
                .frame(width: 64, height: 64)
                .overlay(
                    Image(systemName: "person.2.fill")
                        .font(.system(size: 24, weight: .semibold))
                        .fausGradientForeground()
                )
                .accessibilityHidden(true)
        }
    }

    private var contentSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
            Text(title)
                .font(AppDesign.Typography.headline)
                .foregroundColor(AppDesign.Colors.text)
                .multilineTextAlignment(.leading)

            Text(subtitle)
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.leading)
                .lineLimit(3)
        }
    }
}

// MARK: - Previews

#Preview("Options") {
    VStack(spacing: 20) {
        HouseOptionCard(
            title: "Create New House",
            subtitle: "Start fresh with your roommates",
            kind: .create
        )
        HouseOptionCard(
            title: "Join Existing House",
            subtitle: "Enter an invite code to join",
            kind: .join
        )
    }
    .padding()
}

#Preview("Dark Mode") {
    VStack(spacing: 20) {
        HouseOptionCard(
            title: "Create New House",
            subtitle: "Start fresh with your roommates",
            kind: .create
        )
        HouseOptionCard(
            title: "Join Existing House",
            subtitle: "Enter an invite code to join",
            kind: .join
        )
    }
    .padding()
    .preferredColorScheme(.dark)
}
