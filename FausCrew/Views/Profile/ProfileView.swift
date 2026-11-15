import SwiftUI
import FausCrewCore

struct ProfileView: View {
    /// The popups drawn over the profile. Only one is visible at a time.
    private enum Overlay: Equatable {
        case editProfile
        case avatarPicker
        case languageSettings
        case themeSettings
        case about
        case phoneManagement
        case logoutConfirmation
        case joinHouse
        case createHouse
        case houseInfo(AuthHouseSummary)
    }

    @EnvironmentObject private var appViewModel: AppViewModel
    @EnvironmentObject private var themeStore: ThemeStore

    @State private var activeOverlay: Overlay?
    @State private var showLoginMethods = false
    @State private var showDeleteAccount = false
    @State private var appeared = false
    @AccessibilityFocusState private var houseInformationAccessibilityFocused: Bool

    var body: some View {
        ZStack {
            profileContent
                .accessibilityHidden(activeOverlay != nil)
            overlays
        }
        .animation(AppDesign.Animation.standard, value: activeOverlay)
        .onChange(of: activeOverlay) { _, _ in syncOverlayPresentation() }
        .sheet(isPresented: $showLoginMethods) {
            LoginMethodsView().environmentObject(appViewModel)
        }
        .sheet(isPresented: $showDeleteAccount) {
            DeleteAccountView().environmentObject(appViewModel)
        }
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
        ZStack {
            MainScreenBackground()

            ScrollView(showsIndicators: false) {
                VStack(spacing: AppDesign.Spacing.xl) {
                    ProfileHeroSection(
                        imageURLString: appViewModel.currentUserProfile?.imageUrl ?? "",
                        initials: initials,
                        fullName: fullName,
                        isVisible: appeared,
                        onAvatarTap: {
                            present(.avatarPicker)
                        }
                    )

                    VStack(spacing: AppDesign.Spacing.lg) {
                        accountInformationCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 24)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.78).delay(0.12),
                                value: appeared
                            )

                        houseInformationCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 24)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.78).delay(0.20),
                                value: appeared
                            )

                        personalInfoCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 24)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.78).delay(0.28),
                                value: appeared
                            )

                        settingsCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 24)
                            .animation(
                                .spring(response: 0.6, dampingFraction: 0.78).delay(0.36),
                                value: appeared
                            )
                    }
                    .padding(.horizontal, AppDesign.Spacing.lg)
                    .padding(.bottom, 100)
                }
                .padding(.top, AppDesign.Spacing.xl)
            }
        }
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
                present(.editProfile)
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
            onManagePhone: { present(.phoneManagement) }
        )
    }

    private var houseInformationCard: some View {
        ProfileHouseInformationCard(
            title: appViewModel.localized(
                "profile_house_information_title",
                fallback: "House Informations"
            ),
            houses: appViewModel.availableHouses,
            emptyMessage: appViewModel.localized(
                "profile_house_information_empty",
                fallback: "No houses are connected to this account."
            ),
            detailsButtonTitle: appViewModel.localized(
                "profile_house_information_view_button",
                fallback: "View"
            ),
            joinButtonTitle: appViewModel.localized(
                "profile_house_join_title",
                fallback: "Join a house"
            ),
            joinButtonSubtitle: appViewModel.localized(
                "profile_house_join_row_subtitle",
                fallback: "Enter an 8-character invite code"
            ),
            createButtonTitle: appViewModel.localized(
                "profile_house_create_title",
                fallback: "Create a house"
            ),
            createButtonSubtitle: appViewModel.localized(
                "profile_house_create_subtitle",
                fallback: "Set up a new home for your crew"
            ),
            showsAddHouseOptions: appViewModel.canAddHouse,
            onSelect: { present(.houseInfo($0)) },
            onJoin: { present(.joinHouse) },
            onCreate: { present(.createHouse) }
        )
        .accessibilityFocused($houseInformationAccessibilityFocused)
    }

    private var settingsCard: some View {
        ProfileSettingsCard(
            title: appViewModel.localized("profile_settings_title"),
            notificationsLabel: appViewModel.localized("profile_notifications_label"),
            privacySecurityLabel: appViewModel.localized("profile_privacy_security_label"),
            helpSupportLabel: appViewModel.localized("profile_help_support_label"),
            languageSettingsLabel: appViewModel.localized("profile_language_settings_label"),
            themeLabel: appViewModel.localized("profile_theme_label", fallback: "Theme"),
            themeValue: themeStore.theme.displayName,
            aboutLabel: appViewModel.localized("profile_about_label"),
            logoutLabel: appViewModel.localized("profile_logout_label", fallback: "Log out"),
            loginMethodsLabel: appViewModel.localized("profile_login_methods_label", tr: "Giriş yöntemleri", en: "Sign-in methods"),
            deleteAccountLabel: appViewModel.localized("profile_delete_account_label", tr: "Hesabı sil", en: "Delete account"),
            onOpenLanguageSettings: { present(.languageSettings) },
            onOpenThemeSettings: { present(.themeSettings) },
            onOpenAbout: { present(.about) },
            onOpenLoginMethods: { showLoginMethods = true },
            onDeleteAccount: { showDeleteAccount = true },
            onLogout: { present(.logoutConfirmation) }
        )
    }

    @ViewBuilder
    private var overlays: some View {
        switch activeOverlay {
        case .joinHouse:
            JoinHousePopup(onDismiss: dismissHouseOverlay)
                .environmentObject(appViewModel)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(17)

        case .createHouse:
            CreateHousePopup(onDismiss: dismissHouseOverlay)
                .environmentObject(appViewModel)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(17)

        case .houseInfo(let house):
            HouseInfoPopup(
                house: house,
                onDismiss: dismissHouseOverlay
            )
            .environmentObject(appViewModel)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .zIndex(16)

        case .avatarPicker:
            AvatarPickerPopup(
                initials: initials,
                onDismiss: dismissOverlay
            )
            .environmentObject(appViewModel)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .zIndex(10)

        case .editProfile:
            EditProfilePopup(onDismiss: dismissFormOverlay)
                .environmentObject(appViewModel)
                .zIndex(11)

        case .about:
            AboutPopup(onDismiss: dismissOverlay)
                .environmentObject(appViewModel)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(12)

        case .languageSettings:
            LanguageSettingsPopup(onDismiss: dismissOverlay)
                .environmentObject(appViewModel)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(13)

        case .themeSettings:
            ThemeSettingsPopup(onDismiss: dismissOverlay)
                .environmentObject(appViewModel)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(13)

        case .phoneManagement:
            PhoneManagementPopup(
                currentPhoneNumber: appViewModel.currentUserProfile?.phoneNumber ?? "",
                isVerified: appViewModel.currentUserProfile?.isVerifyPhone == true,
                onDismiss: dismissFormOverlay
            )
            .environmentObject(appViewModel)
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .zIndex(14)

        case .logoutConfirmation:
            LogoutConfirmationPopup(
                onConfirm: {
                    activeOverlay = nil
                    withAnimation(AppDesign.Animation.standard) {
                        appViewModel.logout()
                    }
                },
                onCancel: dismissOverlay
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .zIndex(15)

        case nil:
            EmptyView()
        }
    }

    private func present(_ overlay: Overlay) {
        withAnimation(AppDesign.Animation.standard) {
            activeOverlay = overlay
        }
    }

    private func dismissOverlay() {
        dismissWithoutAnimation {
            activeOverlay = nil
        }
    }

    /// Popups with text fields: drop the keyboard before the popup goes away.
    private func dismissFormOverlay() {
        hideKeyboard()
        dismissOverlay()
    }

    /// House popups hand the accessibility focus back to the house information card.
    private func dismissHouseOverlay() {
        dismissFormOverlay()
        restoreHouseInformationFocus()
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
        appViewModel.isOverlayPresented = activeOverlay != nil
    }

    private func restoreHouseInformationFocus() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            houseInformationAccessibilityFocused = true
        }
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
        let formatted = FausCrewDateFormatter.displayDate(from: isoDate)
        return formatted == "—" ? emptyValue : formatted
    }
}
