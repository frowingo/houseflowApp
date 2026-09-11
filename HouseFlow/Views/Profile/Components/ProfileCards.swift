import SwiftUI

struct ProfilePersonalInfoCard: View {
    let title: String
    let firstNameLabel: String
    let firstName: String
    let lastNameLabel: String
    let lastName: String
    let birthDateLabel: String
    let birthDate: String
    let editButtonTitle: String
    let onEdit: () -> Void

    private let personalTeal = Color(red: 0.20, green: 0.50, blue: 0.52)
    private let personalSage = Color(red: 0.37, green: 0.62, blue: 0.50)
    private let personalSlate = Color(red: 0.36, green: 0.48, blue: 0.61)

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppDesign.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(personalTeal.opacity(0.14))
                        .frame(width: 28, height: 28)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(personalTeal)
                }
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppDesign.Colors.textTertiary)
                    .kerning(0.9)
                Spacer()

                Button(action: onEdit) {
                    Image(systemName: "pencil")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(personalTeal)
                        .frame(width: 30, height: 30)
                        .background(personalTeal.opacity(0.12))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(editButtonTitle)
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.top, AppDesign.Spacing.md)
            .padding(.bottom, AppDesign.Spacing.sm)

            Divider().padding(.horizontal, AppDesign.Spacing.lg)

            ProfileInfoRow(
                icon: "person.fill",
                tint: personalTeal,
                label: firstNameLabel,
                value: firstName
            )
            ProfileCardDivider()
            ProfileInfoRow(
                icon: "person.fill",
                tint: personalSage,
                label: lastNameLabel,
                value: lastName
            )
            ProfileCardDivider()
            ProfileInfoRow(
                icon: "birthday.cake.fill",
                tint: personalSlate,
                label: birthDateLabel,
                value: birthDate
            )
        }
        .background(
            ZStack {
                AppDesign.Colors.cardBackground
                LinearGradient(
                    colors: [
                        personalTeal.opacity(0.065),
                        Color.clear,
                        personalSage.opacity(0.04)
                    ],
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
                        colors: [personalTeal.opacity(0.3), personalSage.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }
}

struct ProfileAccountInformationCard: View {
    let title: String
    let emailLabel: String
    let email: String
    let isEmailVerified: Bool
    let phoneLabel: String
    let phone: String
    let isPhoneVerified: Bool
    let memberSinceLabel: String
    let memberSince: String
    let verifiedLabel: String
    let notVerifiedLabel: String
    let phoneManagementHint: String
    let onManagePhone: () -> Void

    var body: some View {
        ProfileModernCard(
            headerIcon: "person.text.rectangle.fill",
            headerTint: Color(red: 0.15, green: 0.55, blue: 0.85),
            title: title,
            gradientColors: [Color(red: 0.15, green: 0.55, blue: 0.85).opacity(0.06), Color.clear]
        ) {
            ProfileCommunicationRow(
                icon: "envelope.fill",
                tint: Color(red: 0.15, green: 0.55, blue: 0.85),
                label: emailLabel,
                value: email,
                isVerified: isEmailVerified,
                verificationLabel: isEmailVerified ? verifiedLabel : notVerifiedLabel
            )
            ProfileCardDivider()
            ProfileCommunicationRow(
                icon: "phone.fill",
                tint: Color(red: 0.2, green: 0.7, blue: 0.4),
                label: phoneLabel,
                value: phone,
                isVerified: isPhoneVerified,
                verificationLabel: isPhoneVerified ? verifiedLabel : notVerifiedLabel,
                verificationHint: phoneManagementHint,
                verificationAction: onManagePhone
            )
            ProfileCardDivider()
            ProfileInfoRow(
                icon: "calendar",
                tint: Color(red: 0.55, green: 0.35, blue: 0.9),
                label: memberSinceLabel,
                value: memberSince
            )
        }
    }
}

struct ProfileSettingsCard: View {
    let title: String
    let notificationsLabel: String
    let privacySecurityLabel: String
    let helpSupportLabel: String
    let languageSettingsLabel: String
    let aboutLabel: String
    let logoutLabel: String
    let onOpenLanguageSettings: () -> Void
    let onOpenAbout: () -> Void
    let onLogout: () -> Void

    var body: some View {
        ProfileModernCard(
            headerIcon: "gearshape.fill",
            headerTint: AppDesign.Colors.textTertiary,
            title: title,
            gradientColors: [Color.gray.opacity(0.04), Color.clear]
        ) {
            ProfileSettingsRow(
                icon: "bell.badge.fill",
                tint: Color(red: 0.95, green: 0.45, blue: 0.1),
                label: notificationsLabel
            )
            ProfileCardDivider()
            ProfileSettingsRow(
                icon: "lock.shield.fill",
                tint: Color(red: 0.35, green: 0.55, blue: 0.88),
                label: privacySecurityLabel
            )
            ProfileCardDivider()
            ProfileSettingsRow(
                icon: "questionmark.circle.fill",
                tint: Color(red: 0.55, green: 0.35, blue: 0.9),
                label: helpSupportLabel
            )
            ProfileCardDivider()
            ProfileSettingsRow(
                icon: "globe.europe.africa.fill",
                tint: Color(red: 0.15, green: 0.55, blue: 0.85),
                label: languageSettingsLabel,
                action: onOpenLanguageSettings
            )
            ProfileCardDivider()
            ProfileSettingsRow(
                icon: "info.circle.fill",
                tint: AppDesign.Colors.textTertiary,
                label: aboutLabel,
                action: onOpenAbout
            )
            ProfileCardDivider()
            ProfileSettingsRow(
                icon: "rectangle.portrait.and.arrow.right",
                tint: AppDesign.Colors.error,
                label: logoutLabel,
                action: onLogout
            )
        }
    }
}
