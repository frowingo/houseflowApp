import SwiftUI

struct ProfileModernCard<Content: View>: View {
    let headerIcon: String
    let headerTint: Color
    let title: String
    let gradientColors: [Color]
    let content: Content

    init(
        headerIcon: String,
        headerTint: Color,
        title: String,
        gradientColors: [Color],
        @ViewBuilder content: () -> Content
    ) {
        self.headerIcon = headerIcon
        self.headerTint = headerTint
        self.title = title
        self.gradientColors = gradientColors
        self.content = content()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppDesign.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(headerTint.opacity(0.14))
                        .frame(width: 28, height: 28)
                    Image(systemName: headerIcon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(headerTint)
                }

                Text(title.uppercased())
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppDesign.Colors.textTertiary)
                    .kerning(0.9)

                Spacer()
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.top, AppDesign.Spacing.md)
            .padding(.bottom, AppDesign.Spacing.sm)

            Divider().padding(.horizontal, AppDesign.Spacing.lg)
            content
        }
        .background(
            ZStack {
                AppDesign.Colors.cardBackground
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
        .shadow(
            color: AppDesign.Shadow.medium.color,
            radius: AppDesign.Shadow.medium.radius,
            x: AppDesign.Shadow.medium.x,
            y: AppDesign.Shadow.medium.y
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .strokeBorder(
                    LinearGradient(
                        colors: [headerTint.opacity(0.3), AppDesign.Colors.textTertiary.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct ProfileInfoRow: View {
    let icon: String
    let tint: Color
    let label: String
    let value: String
    var valueColor: Color = AppDesign.Colors.textSecondary

    var body: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ProfileRowIcon(icon: icon, tint: tint)

            Text(label)
                .font(AppDesign.Typography.subheadline)
                .foregroundStyle(AppDesign.Colors.textPrimary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(valueColor)
                .lineLimit(1)
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, 14)
    }
}

struct ProfileCommunicationRow: View {
    let icon: String
    let tint: Color
    let label: String
    let value: String
    let isVerified: Bool
    let verificationLabel: String
    var verificationHint: String?
    var verificationAction: (() -> Void)?

    var body: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ProfileRowIcon(icon: icon, tint: tint)

            VStack(alignment: .leading, spacing: 3) {
                Text(label)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(AppDesign.Colors.textTertiary)
                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(AppDesign.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }

            Spacer(minLength: AppDesign.Spacing.sm)
            verificationControl
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private var verificationControl: some View {
        if let verificationAction {
            Button(action: verificationAction) {
                verificationIcon
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(verificationLabel)
            .accessibilityHint(verificationHint ?? "")
        } else {
            verificationIcon
                .accessibilityLabel(verificationLabel)
        }
    }

    private var verificationIcon: some View {
        Image(systemName: isVerified ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(
                isVerified
                    ? Color(red: 0.2, green: 0.75, blue: 0.45)
                    : AppDesign.Colors.error
            )
    }
}

struct ProfileSettingsRow: View {
    let icon: String
    let tint: Color
    let label: String
    var action: (() -> Void)?

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: AppDesign.Spacing.md) {
                ProfileRowIcon(icon: icon, tint: tint)

                Text(label)
                    .font(AppDesign.Typography.subheadline)
                    .foregroundStyle(AppDesign.Colors.textPrimary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(AppDesign.Colors.textTertiary)
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.vertical, 14)
        }
        .buttonStyle(.plain)
    }
}

struct ProfileRowIcon: View {
    let icon: String
    let tint: Color

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(tint.opacity(0.13))
                .frame(width: 34, height: 34)
            Image(systemName: icon)
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(tint)
        }
    }
}

struct ProfileCardDivider: View {
    var body: some View {
        Divider().padding(.leading, 66)
    }
}
