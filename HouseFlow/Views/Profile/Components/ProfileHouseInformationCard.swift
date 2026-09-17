import SwiftUI

struct ProfileHouseInformationCard: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    let houses: [AuthHouseSummary]
    let emptyMessage: String
    let detailsButtonTitle: String
    let joinButtonTitle: String
    let joinButtonSubtitle: String
    let onSelect: (AuthHouseSummary) -> Void
    let onJoin: () -> Void

    private let houseTint = Color(red: 0.42, green: 0.27, blue: 0.67)
    private let joinTint = Color(red: 0.12, green: 0.55, blue: 0.54)

    var body: some View {
        ProfileModernCard(
            headerIcon: "house.fill",
            headerTint: houseTint,
            title: title,
            gradientColors: [houseTint.opacity(0.07), Color.clear]
        ) {
            VStack(spacing: 0) {
                if houses.isEmpty {
                    HStack(spacing: AppDesign.Spacing.md) {
                        ProfileRowIcon(icon: "house", tint: houseTint)
                        Text(emptyMessage)
                            .font(AppDesign.Typography.subheadline)
                            .foregroundStyle(AppDesign.Colors.textSecondary)
                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, AppDesign.Spacing.lg)
                    .padding(.vertical, AppDesign.Spacing.lg)
                } else {
                    ForEach(houses) { house in
                        Button {
                            onSelect(house)
                        } label: {
                            HStack(spacing: AppDesign.Spacing.md) {
                                HouseProfileThumbnail(
                                    imageURLString: house.houseProfile,
                                    size: 44,
                                    cornerRadius: 13
                                )

                                Text(house.houseName)
                                    .font(AppDesign.Typography.subheadline.weight(.semibold))
                                    .foregroundStyle(AppDesign.Colors.textPrimary)
                                    .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)

                                Spacer(minLength: AppDesign.Spacing.sm)

                                Group {
                                    if dynamicTypeSize.isAccessibilitySize {
                                        Image(systemName: "chevron.right")
                                            .font(AppDesign.Typography.caption.weight(.bold))
                                    } else {
                                        HStack(spacing: 5) {
                                            Text(detailsButtonTitle)
                                                .font(AppDesign.Typography.caption.weight(.semibold))
                                            Image(systemName: "chevron.right")
                                                .font(AppDesign.Typography.caption2.weight(.bold))
                                        }
                                    }
                                }
                                .foregroundStyle(AppDesign.Colors.textPrimary)
                                .padding(.horizontal, 10)
                                .frame(minHeight: 30)
                                .padding(.vertical, 2)
                                .background(houseTint.opacity(0.11))
                                .clipShape(Capsule())
                            }
                            .padding(.horizontal, AppDesign.Spacing.lg)
                            .padding(.vertical, 11)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint(detailsButtonTitle)

                        if house.id != houses.last?.id {
                            ProfileCardDivider()
                        }
                    }
                }

                ProfileCardDivider()

                Button(action: onJoin) {
                    HStack(spacing: AppDesign.Spacing.md) {
                        ProfileRowIcon(icon: "person.2.badge.plus", tint: joinTint)

                        VStack(alignment: .leading, spacing: 2) {
                            Text(joinButtonTitle)
                                .font(AppDesign.Typography.subheadline.weight(.semibold))
                                .foregroundStyle(AppDesign.Colors.textPrimary)
                            Text(joinButtonSubtitle)
                                .font(AppDesign.Typography.caption)
                                .foregroundStyle(AppDesign.Colors.textSecondary)
                                .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)
                        }

                        Spacer(minLength: AppDesign.Spacing.sm)

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(joinTint)
                            .frame(width: 32, height: 32)
                            .background(joinTint.opacity(0.11))
                            .clipShape(Circle())
                    }
                    .padding(.horizontal, AppDesign.Spacing.lg)
                    .padding(.vertical, 12)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        }
    }
}

struct HouseProfileThumbnail: View {
    let imageURLString: String
    let size: CGFloat
    let cornerRadius: CGFloat

    var body: some View {
        Group {
            if let imageURL {
                CachedRemoteImage(url: imageURL) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    placeholder
                } failure: {
                    placeholder
                }
            } else {
                placeholder
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
    }

    private var imageURL: URL? {
        let value = imageURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : URL(string: value)
    }

    private var placeholder: some View {
        ZStack {
            HouseJourneyTheme.indigo.opacity(0.11)
            Image(systemName: "house.fill")
                .font(.system(size: size * 0.4, weight: .semibold))
                .foregroundStyle(HouseJourneyTheme.indigo)
        }
    }
}
