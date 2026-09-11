import SwiftUI

/// House member carousel using the cool-toned Create House palette.
struct HouseMembersCard: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let members: [User]

    private let memberTints: [Color] = [
        HouseJourneyTheme.indigo,
        HouseJourneyTheme.teal,
        HouseJourneyTheme.purple,
        HouseJourneyTheme.blue
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
            header

            if members.isEmpty {
                emptyState
            } else {
                membersCarousel
            }
        }
        .padding(AppDesign.Spacing.xl)
        .background(
            ZStack {
                HouseJourneyTheme.surface

                LinearGradient(
                    colors: [
                        HouseJourneyTheme.indigo.opacity(0.075),
                        HouseJourneyTheme.teal.opacity(0.035),
                        Color.clear
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(HouseJourneyTheme.purple.opacity(0.055))
                    .frame(width: 150, height: 150)
                    .offset(x: 150, y: -70)
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            HouseJourneyTheme.indigo.opacity(0.24),
                            HouseJourneyTheme.teal.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(
            color: HouseJourneyTheme.deepIndigo.opacity(0.09),
            radius: 14,
            x: 0,
            y: 6
        )
    }

    private var header: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 11)
                    .fill(
                        LinearGradient(
                            colors: [HouseJourneyTheme.teal, HouseJourneyTheme.indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 42, height: 42)

                Image(systemName: "person.3.fill")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)

                Circle()
                    .fill(HouseJourneyTheme.accentOrange)
                    .frame(width: 7, height: 7)
                    .overlay(Circle().stroke(HouseJourneyTheme.surface, lineWidth: 1.5))
                    .offset(x: 15, y: 15)
            }

            LocalizedText("house_members_title")
                .font(AppDesign.Typography.headline)
                .foregroundStyle(AppDesign.Colors.textPrimary)

            Spacer()

            HStack(spacing: 5) {
                Circle()
                    .fill(HouseJourneyTheme.accentOrange)
                    .frame(width: 5, height: 5)
                Text("\(members.count)")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
            }
            .foregroundStyle(HouseJourneyTheme.deepIndigo)
            .padding(.horizontal, AppDesign.Spacing.sm)
            .frame(minHeight: 26)
            .background(HouseJourneyTheme.indigo.opacity(0.10))
            .clipShape(Capsule())
        }
    }

    private var membersCarousel: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            LazyHStack(spacing: AppDesign.Spacing.md) {
                ForEach(Array(members.enumerated()), id: \.element.id) { index, member in
                    memberTile(member, tint: memberTints[index % memberTints.count])
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 4)
        }
        .scrollClipDisabled()
    }

    private func memberTile(_ member: User, tint: Color) -> some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .strokeBorder(
                        AngularGradient(
                            colors: [
                                tint.opacity(0.35),
                                tint,
                                HouseJourneyTheme.accentOrange.opacity(0.65),
                                tint.opacity(0.35)
                            ],
                            center: .center
                        ),
                        lineWidth: 2.5
                    )
                    .frame(width: 62, height: 62)

                UserAvatar(user: member, size: 52)
                    .padding(5)

                ZStack {
                    Circle()
                        .fill(HouseJourneyTheme.surface)
                        .frame(width: 21, height: 21)
                    Circle()
                        .fill(tint)
                        .frame(width: 15, height: 15)
                    Image(systemName: "house.fill")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.white)
                }
                .offset(x: 1, y: 1)
            }

            Text(member.name)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(AppDesign.Colors.textPrimary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, minHeight: 30, alignment: .top)
        }
        .padding(.horizontal, AppDesign.Spacing.sm)
        .padding(.vertical, AppDesign.Spacing.md)
        .frame(width: 108, height: 124)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(tint.opacity(0.075))
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .strokeBorder(tint.opacity(0.15), lineWidth: 1)
        )
        .shadow(color: tint.opacity(0.08), radius: 7, x: 0, y: 3)
    }

    private var emptyState: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            Image(systemName: "person.3")
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(HouseJourneyTheme.indigo.opacity(0.55))

            Text(appViewModel.localized(
                "house_members_empty_message",
                fallback: "No house members to show yet."
            ))
                .font(AppDesign.Typography.subheadline)
                .foregroundStyle(AppDesign.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.Spacing.xl)
    }
}

#Preview {
    HouseMembersCard(members: [
        User(name: "Mahmut", points: 12),
        User(name: "Jane", points: 8),
        User(name: "Abdüllatif", points: 10),
        User(name: "Katya", points: 6)
    ])
    .environmentObject(AppViewModel())
    .padding()
}
