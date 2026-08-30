import SwiftUI

struct ProfileView: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    @State private var showEditSheet = false
    @State private var showAvatarPicker = false
    @State private var showLanguageSettings = false
    @State private var showAbout = false
    @State private var showPhoneManagement = false
    @State private var showLogoutConfirmation = false
    @State private var appeared = false

    var body: some View {
        ZStack {
            profileContent
            overlays
        }
        .animation(AppDesign.Animation.standard, value: showAvatarPicker)
        .animation(AppDesign.Animation.standard, value: showEditSheet)
        .animation(AppDesign.Animation.standard, value: showLanguageSettings)
        .animation(AppDesign.Animation.standard, value: showAbout)
        .animation(AppDesign.Animation.standard, value: showPhoneManagement)
        .animation(AppDesign.Animation.standard, value: showLogoutConfirmation)
        .onChange(of: showAvatarPicker) { _, _ in syncOverlayPresentation() }
        .onChange(of: showEditSheet) { _, _ in syncOverlayPresentation() }
        .onChange(of: showLanguageSettings) { _, _ in syncOverlayPresentation() }
        .onChange(of: showAbout) { _, _ in syncOverlayPresentation() }
        .onChange(of: showPhoneManagement) { _, _ in syncOverlayPresentation() }
        .onChange(of: showLogoutConfirmation) { _, _ in syncOverlayPresentation() }
        .onDisappear {
            appViewModel.isOverlayPresented = false
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.05)) {
                appeared = true
            }
        }
    }

    private var profileContent: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: AppDesign.Spacing.xl) {
                ProfileHeroSection(
                    imageURLString: appViewModel.currentUserProfile?.imageUrl ?? "",
                    initials: initials,
                    fullName: fullName,
                    email: appViewModel.currentUserProfile?.email ?? "—",
                    isVisible: appeared,
                    onAvatarTap: {
                        showAvatarPicker = true
                    }
                )

                VStack(spacing: AppDesign.Spacing.lg) {
                    personalInfoCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.78).delay(0.12),
                            value: appeared
                        )

                    accountInformationCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.78).delay(0.22),
                            value: appeared
                        )

                    settingsCard
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 24)
                        .animation(
                            .spring(response: 0.6, dampingFraction: 0.78).delay(0.32),
                            value: appeared
                        )
                }
                .padding(.horizontal, AppDesign.Spacing.lg)
                .padding(.bottom, 100)
            }
            .padding(.top, AppDesign.Spacing.xl)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
    }

    private var personalInfoCard: some View {
        ProfilePersonalInfoCard(
            title: appViewModel.localized("profile_personal_info_title"),
            firstNameLabel: appViewModel.localized("profile_first_name_label"),
            firstName: appViewModel.currentUserProfile?.firstName ?? emptyValue,
            lastNameLabel: appViewModel.localized("profile_last_name_label"),
            lastName: appViewModel.currentUserProfile?.lastName ?? emptyValue,
            birthDateLabel: appViewModel.localized("profile_birthdate_label"),
            birthDate: birthDateDisplay,
            editButtonTitle: appViewModel.localized("profile_edit_button"),
            onEdit: {
                showEditSheet = true
            }
        )
    }

    private var accountInformationCard: some View {
        ProfileAccountInformationCard(
            title: appViewModel.localized(
                "profile_account_information_title",
                fallback: "Account Information"
            ),
            emailLabel: appViewModel.localized("profile_email_label", fallback: "Email"),
            email: emailDisplay,
            isEmailVerified: appViewModel.currentUserProfile?.isVerifyEmail == true,
            phoneLabel: appViewModel.localized("profile_phone_label"),
            phone: phoneDisplay,
            isPhoneVerified: appViewModel.currentUserProfile?.isVerifyPhone == true,
            memberSinceLabel: appViewModel.localized("profile_member_since_label"),
            memberSince: formattedDate(appViewModel.currentUserProfile?.createdOn),
            verifiedLabel: appViewModel.localized("common_verified", fallback: "Verified"),
            notVerifiedLabel: appViewModel.localized("common_not_verified", fallback: "Not verified"),
            phoneManagementHint: appViewModel.localized(
                "profile_phone_manage_accessibility_hint",
                fallback: "Opens phone update and verification options."
            ),
            onManagePhone: {
                withAnimation(AppDesign.Animation.standard) {
                    showPhoneManagement = true
                }
            }
        )
    }

    private var settingsCard: some View {
        ProfileSettingsCard(
            title: appViewModel.localized("profile_settings_title"),
            notificationsLabel: appViewModel.localized("profile_notifications_label"),
            privacySecurityLabel: appViewModel.localized("profile_privacy_security_label"),
            helpSupportLabel: appViewModel.localized("profile_help_support_label"),
            languageSettingsLabel: appViewModel.localized("profile_language_settings_label"),
            aboutLabel: appViewModel.localized("profile_about_label"),
            logoutLabel: appViewModel.localized("profile_logout_label", fallback: "Log out"),
            onOpenLanguageSettings: {
                withAnimation(AppDesign.Animation.standard) {
                    showLanguageSettings = true
                }
            },
            onOpenAbout: {
                withAnimation(AppDesign.Animation.standard) {
                    showAbout = true
                }
            },
            onLogout: {
                withAnimation(AppDesign.Animation.standard) {
                    showLogoutConfirmation = true
                }
            }
        )
    }

    @ViewBuilder
    private var overlays: some View {
        if showAvatarPicker {
            AvatarPickerPopup(
                initials: initials,
                onDismiss: dismissAvatarPicker
            )
            .environmentObject(appViewModel)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .zIndex(10)
        }

        if showEditSheet {
            EditProfilePopup(onDismiss: dismissEditSheet)
                .environmentObject(appViewModel)
                .zIndex(11)
        }

        if showAbout {
            AboutPopup(onDismiss: dismissAbout)
                .environmentObject(appViewModel)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(12)
        }

        if showLanguageSettings {
            LanguageSettingsPopup(onDismiss: dismissLanguageSettings)
                .environmentObject(appViewModel)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(13)
        }

        if showPhoneManagement {
            PhoneManagementPopup(
                currentPhoneNumber: appViewModel.currentUserProfile?.phoneNumber ?? "",
                isVerified: appViewModel.currentUserProfile?.isVerifyPhone == true,
                onDismiss: dismissPhoneManagement
            )
            .environmentObject(appViewModel)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .zIndex(14)
        }

        if showLogoutConfirmation {
            LogoutConfirmationPopup(
                onConfirm: {
                    showLogoutConfirmation = false
                    withAnimation(AppDesign.Animation.standard) {
                        appViewModel.logout()
                    }
                },
                onCancel: dismissLogoutConfirmation
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .zIndex(15)
        }
    }

    private func dismissEditSheet() {
        hideKeyboard()
        dismissWithoutAnimation {
            showEditSheet = false
        }
    }

    private func dismissAvatarPicker() {
        dismissWithoutAnimation {
            showAvatarPicker = false
        }
    }

    private func dismissLanguageSettings() {
        dismissWithoutAnimation {
            showLanguageSettings = false
        }
    }

    private func dismissAbout() {
        dismissWithoutAnimation {
            showAbout = false
        }
    }

    private func dismissLogoutConfirmation() {
        dismissWithoutAnimation {
            showLogoutConfirmation = false
        }
    }

    private func dismissPhoneManagement() {
        hideKeyboard()
        dismissWithoutAnimation {
            showPhoneManagement = false
        }
    }

    private func dismissWithoutAnimation(_ action: @escaping () -> Void) {
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction, action)
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil,
            from: nil,
            for: nil
        )
    }

    private func syncOverlayPresentation() {
        appViewModel.isOverlayPresented = showAvatarPicker
            || showEditSheet
            || showLanguageSettings
            || showAbout
            || showPhoneManagement
            || showLogoutConfirmation
    }

    private var emptyValue: String {
        appViewModel.localized("common_empty_value")
    }

    private var initials: String {
        let firstInitial = appViewModel.currentUserProfile?.firstName.prefix(1) ?? "?"
        let lastInitial = appViewModel.currentUserProfile?.lastName.prefix(1) ?? ""
        return "\(firstInitial)\(lastInitial)".uppercased()
    }

    private var fullName: String {
        guard let profile = appViewModel.currentUserProfile else { return emptyValue }
        return "\(profile.firstName) \(profile.lastName)"
    }

    private var phoneDisplay: String {
        guard let profile = appViewModel.currentUserProfile, !profile.phoneNumber.isEmpty else {
            return emptyValue
        }
        return profile.phoneNumber
    }

    private var emailDisplay: String {
        guard let profile = appViewModel.currentUserProfile, !profile.email.isEmpty else {
            return emptyValue
        }
        return profile.email
    }

    private var birthDateDisplay: String {
        guard let birthDate = appViewModel.currentUserProfile?.birthDate, !birthDate.isEmpty else {
            return emptyValue
        }
        return displayDate(birthDate)
    }

    private func formattedDate(_ isoDate: String?) -> String {
        displayDate(isoDate)
    }

    private func displayDate(_ isoDate: String?) -> String {
        let formatted = HouseFlowDateFormatter.displayDate(from: isoDate)
        return formatted == "—" ? emptyValue : formatted
    }
}
