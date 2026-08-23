import SwiftUI

// MARK: - Avatar Option Model

struct AvatarOption: Identifiable {
    let id: Int
    let colors: [Color]
    let label: String
}

private let avatarOptions: [AvatarOption] = [
    AvatarOption(id: 0, colors: [Color(red: 0.95, green: 0.50, blue: 0.08), Color(red: 0.78, green: 0.32, blue: 0.03)], label: "Amber"),
    AvatarOption(id: 1, colors: [Color(red: 0.13, green: 0.42, blue: 0.95), Color(red: 0.08, green: 0.22, blue: 0.62)], label: "Ocean"),
    AvatarOption(id: 2, colors: [Color(red: 0.2, green: 0.75, blue: 0.45), Color(red: 0.1, green: 0.52, blue: 0.30)], label: "Mint"),
    AvatarOption(id: 3, colors: [Color(red: 0.55, green: 0.35, blue: 0.95), Color(red: 0.35, green: 0.18, blue: 0.75)], label: "Violet"),
    AvatarOption(id: 4, colors: [Color(red: 0.95, green: 0.25, blue: 0.35), Color(red: 0.75, green: 0.10, blue: 0.22)], label: "Rose"),
    AvatarOption(id: 5, colors: [Color(red: 0.15, green: 0.72, blue: 0.88), Color(red: 0.05, green: 0.50, blue: 0.70)], label: "Sky"),
    AvatarOption(id: 6, colors: [Color(red: 0.95, green: 0.75, blue: 0.10), Color(red: 0.80, green: 0.55, blue: 0.02)], label: "Gold"),
    AvatarOption(id: 7, colors: [Color(red: 0.30, green: 0.30, blue: 0.38), Color(red: 0.15, green: 0.15, blue: 0.22)], label: "Slate"),
]

// MARK: - ProfileView

struct ProfileView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var showEditSheet = false
    @State private var showAvatarPicker = false
    @State private var showLanguageSettings = false
    @State private var showAbout = false
    @State private var showPhoneManagement = false
    @State private var showLogoutConfirmation = false
    @State private var avatarPulse = false
    @State private var selectedAvatarId: Int = 0
    @State private var appeared = false

    // Brand colour — matches accentOrange in ChoreDetailPopup
    private let brandOrange   = Color(red: 1.0, green: 0.48, blue: 0.15)
    private var brandOrangeDk: Color { brandOrange.opacity(0.7) }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppDesign.Spacing.xl) {
                    heroSection

                    VStack(spacing: AppDesign.Spacing.lg) {
                        personalInfoCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 24)
                            .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.12), value: appeared)
                        accountInformationCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 24)
                            .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.22), value: appeared)
                        settingsCard
                            .opacity(appeared ? 1 : 0)
                            .offset(y: appeared ? 0 : 24)
                            .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.32), value: appeared)
                    }
                    .padding(.horizontal, AppDesign.Spacing.lg)
                    .padding(.bottom, 100)
                }
                .padding(.top, AppDesign.Spacing.xl)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())

            if showAvatarPicker {
                AvatarPickerPopup(
                    initials: initials,
                    onDismiss: {
                        dismissAvatarPicker()
                    }
                )
                .environmentObject(appViewModel)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(10)
            }

            if showEditSheet {
                EditProfilePopup(
                    onDismiss: {
                        dismissEditSheet()
                    }
                )
                .environmentObject(appViewModel)
                .zIndex(11)
            }

            if showAbout {
                AboutPopup {
                    dismissAbout()
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(12)
            }

            if showLanguageSettings {
                LanguageSettingsPopup {
                    dismissLanguageSettings()
                }
                .environmentObject(appViewModel)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(13)
            }

            if showPhoneManagement {
                PhoneManagementPopup(
                    currentPhoneNumber: appViewModel.currentUserProfile?.phoneNumber ?? "",
                    isVerified: appViewModel.currentUserProfile?.isVerifyPhone == true,
                    onDismiss: {
                        dismissPhoneManagement()
                    }
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
                    onCancel: {
                        dismissLogoutConfirmation()
                    }
                )
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(15)
            }
        }
        .animation(AppDesign.Animation.standard, value: showAvatarPicker)
        .animation(AppDesign.Animation.standard, value: showEditSheet)
        .animation(AppDesign.Animation.standard, value: showLanguageSettings)
        .animation(AppDesign.Animation.standard, value: showAbout)
        .animation(AppDesign.Animation.standard, value: showPhoneManagement)
        .animation(AppDesign.Animation.standard, value: showLogoutConfirmation)
        .onChange(of: showAvatarPicker) { _, _ in
            syncOverlayPresentation()
        }
        .onChange(of: showEditSheet) { _, _ in
            syncOverlayPresentation()
        }
        .onChange(of: showLanguageSettings) { _, _ in
            syncOverlayPresentation()
        }
        .onChange(of: showAbout) { _, _ in
            syncOverlayPresentation()
        }
        .onChange(of: showPhoneManagement) { _, _ in
            syncOverlayPresentation()
        }
        .onChange(of: showLogoutConfirmation) { _, _ in
            syncOverlayPresentation()
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

    private func dismissEditSheet() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showEditSheet = false
            }
        }
    }

    private func dismissAvatarPicker() {
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showAvatarPicker = false
            }
        }
    }

    private func dismissLanguageSettings() {
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showLanguageSettings = false
            }
        }
    }

    private func dismissAbout() {
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showAbout = false
            }
        }
    }

    private func dismissLogoutConfirmation() {
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showLogoutConfirmation = false
            }
        }
    }

    private func dismissPhoneManagement() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showPhoneManagement = false
            }
        }
    }

    private func syncOverlayPresentation() {
        appViewModel.isOverlayPresented = showAvatarPicker
            || showEditSheet
            || showLanguageSettings
            || showAbout
            || showPhoneManagement
            || showLogoutConfirmation
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottomLeading) {
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.08, saturation: 0.85, brightness: 0.95),
                            Color(hue: 0.05, saturation: 0.75, brightness: 0.80),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 190)

            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 160, height: 160)
                .offset(x: 140, y: -46)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 110, height: 110)
                .offset(x: 250, y: 52)

            Image(systemName: "person.crop.circle.fill")
                .font(.system(size: 58, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.15))
                .offset(x: 230, y: -50)

            HStack(alignment: .bottom, spacing: AppDesign.Spacing.lg) {
                Button {
                    withAnimation(AppDesign.Animation.standard) {
                        showAvatarPicker = true
                    }
                } label: {
                    ZStack {
                        // Animated ring
                        Circle()
                            .strokeBorder(
                                AngularGradient(
                                    colors: [
                                        Color(red: 1.0, green: 0.78, blue: 0.40),
                                        brandOrange,
                                        Color(red: 0.65, green: 0.20, blue: 0.05),
                                        Color(red: 1.0, green: 0.78, blue: 0.40)
                                    ],
                                    center: .center
                                ),
                                lineWidth: 3
                            )
                            .frame(width: 108, height: 108)
                            .opacity(avatarPulse ? 1 : 0.55)
                            .animation(
                                Animation.easeInOut(duration: 2).repeatForever(autoreverses: true),
                                value: avatarPulse
                            )

                        // White background circle
                        Circle()
                            .fill(Color.white)
                            .frame(width: 96, height: 96)

                        // Avatar fill
                        Group {
                            if let imageUrl = appViewModel.currentUserProfile?.imageUrl,
                               !imageUrl.isEmpty,
                               let url = URL(string: imageUrl) {
                                CachedRemoteImage(url: url) { image in
                                    image.resizable().scaledToFill()
                                } placeholder: {
                                    defaultAvatarFill
                                } failure: {
                                    defaultAvatarFill
                                }
                            } else {
                                defaultAvatarFill
                            }
                        }
                        .frame(width: 96, height: 96)
                        .clipShape(Circle())

                        // Initials (only shown when no imageUrl)
                        if (appViewModel.currentUserProfile?.imageUrl ?? "").isEmpty {
                            Text(initials)
                                .font(.system(size: 38, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                        }
                    }
                    .shadow(color: Color.black.opacity(0.24), radius: 14, x: 0, y: 7)
                }
                .buttonStyle(.plain)
                .onAppear { avatarPulse = true }

                VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                    Text(fullName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(appViewModel.currentUserProfile?.email ?? "—")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
            .padding(.bottom, AppDesign.Spacing.xl)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
        .shadow(color: Color.orange.opacity(0.35), radius: 16, x: 0, y: 6)
        .padding(.horizontal, AppDesign.Spacing.lg)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var defaultAvatarFill: some View {
        Circle()
            .fill(
                LinearGradient(
                    colors: avatarOptions[selectedAvatarId].colors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
    }

    // MARK: - Personal Info Card (with edit button)

    private var personalInfoCard: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: AppDesign.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(brandOrange.opacity(0.14))
                        .frame(width: 28, height: 28)
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(brandOrange)
                }
                Text(appViewModel.localized("profile_personal_info_title"))
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppDesign.Colors.textTertiary)
                    .kerning(0.9)
                Spacer()
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.top, AppDesign.Spacing.md)
            .padding(.bottom, AppDesign.Spacing.sm)

            Divider().padding(.horizontal, AppDesign.Spacing.lg)

            infoRow(icon: "person.fill",        tint: brandOrange,                              label: appViewModel.localized("profile_first_name_label"), value: appViewModel.currentUserProfile?.firstName ?? appViewModel.localized("common_empty_value"))
            cardDivider
            infoRow(icon: "person.fill",        tint: brandOrange,                              label: appViewModel.localized("profile_last_name_label"),  value: appViewModel.currentUserProfile?.lastName ?? appViewModel.localized("common_empty_value"))
            cardDivider
            infoRow(icon: "birthday.cake.fill", tint: Color(red: 0.9, green: 0.45, blue: 0.1),  label: appViewModel.localized("profile_birthdate_label"),  value: birthDateDisplay)

            // Edit Profile button inside card
            Divider().padding(.horizontal, AppDesign.Spacing.lg)

            Button {
                showEditSheet = true
            } label: {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 14, weight: .semibold))
                    Text(appViewModel.localized("profile_edit_button"))
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [brandOrange, brandOrangeDk],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
                .shadow(color: brandOrange.opacity(0.4), radius: 10, x: 0, y: 4)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                        .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
                )
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.vertical, AppDesign.Spacing.md)
        }
        .background(
            ZStack {
                AppDesign.Colors.cardBackground
                LinearGradient(
                    colors: [brandOrange.opacity(0.06), Color.clear, Color(red: 0.65, green: 0.20, blue: 0.05).opacity(0.03)],
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
                        colors: [brandOrange.opacity(0.3), AppDesign.Colors.textTertiary.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Account Information Card

    private var accountInformationCard: some View {
        modernCard(
            headerIcon: "person.text.rectangle.fill",
            headerTint: Color(red: 0.15, green: 0.55, blue: 0.85),
            title: appViewModel.localized("profile_account_information_title", fallback: "Account Information"),
            gradientColors: [Color(red: 0.15, green: 0.55, blue: 0.85).opacity(0.06), Color.clear]
        ) {
            communicationRow(
                icon: "envelope.fill",
                tint: Color(red: 0.15, green: 0.55, blue: 0.85),
                label: appViewModel.localized("profile_email_label", fallback: "Email"),
                value: emailDisplay,
                isVerified: appViewModel.currentUserProfile?.isVerifyEmail == true
            )
            cardDivider
            communicationRow(
                icon: "phone.fill",
                tint: Color(red: 0.2, green: 0.7, blue: 0.4),
                label: appViewModel.localized("profile_phone_label"),
                value: phoneDisplay,
                isVerified: appViewModel.currentUserProfile?.isVerifyPhone == true,
                verificationAction: {
                    withAnimation(AppDesign.Animation.standard) {
                        showPhoneManagement = true
                    }
                }
            )
            cardDivider
            infoRow(icon: "calendar",              tint: Color(red: 0.55, green: 0.35, blue: 0.9),  label: appViewModel.localized("profile_member_since_label"), value: formattedDate(appViewModel.currentUserProfile?.createdOn))
        }
    }

    // MARK: - Settings Card

    private var settingsCard: some View {
        modernCard(
            headerIcon: "gearshape.fill",
            headerTint: AppDesign.Colors.textTertiary,
            title: appViewModel.localized("profile_settings_title"),
            gradientColors: [Color.gray.opacity(0.04), Color.clear]
        ) {
            settingsRow(icon: "bell.badge.fill",       tint: Color(red: 0.95, green: 0.45, blue: 0.1), label: appViewModel.localized("profile_notifications_label"))
            cardDivider
            settingsRow(icon: "lock.shield.fill",      tint: Color(red: 0.35, green: 0.55, blue: 0.88), label: appViewModel.localized("profile_privacy_security_label"))
            cardDivider
            settingsRow(icon: "questionmark.circle.fill", tint: Color(red: 0.55, green: 0.35, blue: 0.9), label: appViewModel.localized("profile_help_support_label"))
            cardDivider
            settingsRow(icon: "globe.europe.africa.fill", tint: Color(red: 0.15, green: 0.55, blue: 0.85), label: appViewModel.localized("profile_language_settings_label")) {
                withAnimation(AppDesign.Animation.standard) { showLanguageSettings = true }
            }
            cardDivider
            settingsRow(icon: "info.circle.fill",      tint: AppDesign.Colors.textTertiary,             label: appViewModel.localized("profile_about_label")) {
                withAnimation(AppDesign.Animation.standard) { showAbout = true }
            }
            cardDivider
            settingsRow(
                icon: "rectangle.portrait.and.arrow.right",
                tint: AppDesign.Colors.error,
                label: appViewModel.localized("profile_logout_label", fallback: "Log out")
            ) {
                withAnimation(AppDesign.Animation.standard) {
                    showLogoutConfirmation = true
                }
            }
        }
    }

    // MARK: - Card Builder

    @ViewBuilder
    private func modernCard<Content: View>(
        headerIcon: String,
        headerTint: Color,
        title: String,
        gradientColors: [Color],
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            // Section header row
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

            Divider()
                .padding(.horizontal, AppDesign.Spacing.lg)

            content()
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
                        colors: [
                            headerTint.opacity(0.3),
                            AppDesign.Colors.textTertiary.opacity(0.1)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Row Components

    private func infoRow(
        icon: String,
        tint: Color,
        label: String,
        value: String,
        valueColor: Color = AppDesign.Colors.textSecondary
    ) -> some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(0.13))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tint)
            }

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

    private func communicationRow(
        icon: String,
        tint: Color,
        label: String,
        value: String,
        isVerified: Bool,
        verificationAction: (() -> Void)? = nil
    ) -> some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(0.13))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tint)
            }

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

            verificationControl(isVerified: isVerified, action: verificationAction)
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, 14)
    }

    @ViewBuilder
    private func verificationControl(isVerified: Bool, action: (() -> Void)?) -> some View {
        let label = appViewModel.localized(
            isVerified ? "common_verified" : "common_not_verified",
            fallback: isVerified ? "Verified" : "Not verified"
        )

        if let action {
            Button(action: action) {
                verificationIcon(isVerified: isVerified)
                    .frame(width: 34, height: 34)
                    .contentShape(Circle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(label)
            .accessibilityHint(
                appViewModel.localized(
                    "profile_phone_manage_accessibility_hint",
                    fallback: "Opens phone update and verification options."
                )
            )
        } else {
            verificationIcon(isVerified: isVerified)
                .accessibilityLabel(label)
        }
    }

    private func verificationIcon(isVerified: Bool) -> some View {
        Image(systemName: isVerified ? "checkmark.circle.fill" : "xmark.circle.fill")
            .font(.system(size: 19, weight: .semibold))
            .foregroundStyle(isVerified ? Color(red: 0.2, green: 0.75, blue: 0.45) : AppDesign.Colors.error)
    }

    private func settingsRow(icon: String, tint: Color, label: String, action: (() -> Void)? = nil) -> some View {
        Button {
            action?()
        } label: {
            HStack(spacing: AppDesign.Spacing.md) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(tint.opacity(0.13))
                        .frame(width: 34, height: 34)
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(tint)
                }

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

    private var cardDivider: some View {
        Divider()
            .padding(.leading, 66)
    }

    // MARK: - Helpers

    private var initials: String {
        let f = appViewModel.currentUserProfile?.firstName.prefix(1) ?? "?"
        let l = appViewModel.currentUserProfile?.lastName.prefix(1) ?? ""
        return "\(f)\(l)".uppercased()
    }

    private var fullName: String {
        guard let p = appViewModel.currentUserProfile else { return appViewModel.localized("common_empty_value") }
        return "\(p.firstName) \(p.lastName)"
    }

    private var phoneDisplay: String {
        guard let p = appViewModel.currentUserProfile, !p.phoneNumber.isEmpty else { return appViewModel.localized("common_empty_value") }
        return p.phoneNumber
    }

    private var emailDisplay: String {
        guard let p = appViewModel.currentUserProfile, !p.email.isEmpty else { return appViewModel.localized("common_empty_value") }
        return p.email
    }

    private var birthDateDisplay: String {
        guard let p = appViewModel.currentUserProfile, let bd = p.birthDate, !bd.isEmpty else { return appViewModel.localized("common_empty_value") }
        let formatted = HouseFlowDateFormatter.displayDate(from: bd)
        return formatted == "—" ? appViewModel.localized("common_empty_value") : formatted
    }

    private func formattedDate(_ iso: String?) -> String {
        let formatted = HouseFlowDateFormatter.displayDate(from: iso)
        return formatted == "—" ? appViewModel.localized("common_empty_value") : formatted
    }
}

// MARK: - Avatar Picker Popup

struct AvatarPickerPopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let initials: String
    let onDismiss: () -> Void

    @State private var images: [UserImageData] = []
    @State private var isLoading = false
    @State private var selectedImage: UserImageData? = nil
    @State private var isSaving = false
    @State private var saveError: String? = nil

    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { if !isSaving { requestDismiss() } }

            VStack(spacing: 0) {
                // Top bar
                ZStack {
                    LinearGradient(
                        colors: [accentOrange, accentOrange.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white.opacity(0.12))

                    HStack(spacing: AppDesign.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appViewModel.localized("profile_avatar_choose_title"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text(appViewModel.localized("profile_avatar_choose_subtitle"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        Spacer()
                        Button { if !isSaving { requestDismiss() } } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 26, height: 26)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, 12)
                }
                .frame(height: 64)

                // Grid body
                ScrollView(showsIndicators: false) {
                    if isLoading {
                        ProgressView()
                            .tint(accentOrange)
                            .scaleEffect(1.2)
                            .frame(maxWidth: .infinity, minHeight: 180)
                    } else if images.isEmpty {
                        VStack(spacing: AppDesign.Spacing.sm) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.system(size: 36))
                                .foregroundStyle(AppDesign.Colors.textTertiary)
                            Text(appViewModel.localized("profile_avatar_empty_message"))
                                .font(AppDesign.Typography.subheadline)
                                .foregroundStyle(AppDesign.Colors.textTertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 180)
                    } else {
                        LazyVGrid(columns: columns, spacing: AppDesign.Spacing.md) {
                            ForEach(images, id: \.publicId) { image in
                                imageCell(image: image)
                            }
                        }
                        .padding(.horizontal, AppDesign.Spacing.xl)
                        .padding(.vertical, AppDesign.Spacing.xl)
                    }
                }
                .frame(maxHeight: 340)

                // Error
                if let error = saveError {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                            .font(AppDesign.Typography.caption)
                        Spacer()
                    }
                    .foregroundStyle(AppDesign.Colors.error)
                    .padding(AppDesign.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                            .fill(AppDesign.Colors.error.opacity(0.1))
                    )
                    .padding(.horizontal, AppDesign.Spacing.xl)
                }

                // Footer
                VStack(spacing: AppDesign.Spacing.sm) {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack(spacing: AppDesign.Spacing.sm) {
                            if isSaving {
                                ProgressView().scaleEffect(0.85).tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text(appViewModel.localized(isSaving ? "common_saving" : "common_save_changes"))
                                .font(AppDesign.Typography.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeightSmall)
                        .background(
                            selectedImage == nil || isSaving
                                ? LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [accentOrange, accentOrange.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(AppDesign.CornerRadius.md)
                    }
                    .disabled(selectedImage == nil || isSaving)

                    Button { if !isSaving { requestDismiss() } } label: {
                        Text(appViewModel.localized("common_cancel"))
                            .font(AppDesign.Typography.headline)
                            .foregroundColor(AppDesign.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppDesign.Size.buttonHeightSmall)
                            .background(AppDesign.Colors.secondaryBackground)
                            .cornerRadius(AppDesign.CornerRadius.md)
                    }
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.lg)
                .background(AppDesign.Colors.background.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -4))
            }
            .background(
                ZStack {
                    AppDesign.Colors.background
                    LinearGradient(
                        colors: [accentOrange.opacity(0.04), Color.clear],
                        startPoint: .top, endPoint: .center
                    )
                }
            )
            .cornerRadius(AppDesign.CornerRadius.xl)
            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .animation(AppDesign.Animation.standard, value: isSaving)
        .task { await fetchImages() }
    }

    // MARK: - Image Cell

    @ViewBuilder
    private func imageCell(image: UserImageData) -> some View {
        let isSelected = selectedImage?.publicId == image.publicId
        Button {
            withAnimation(AppDesign.Animation.spring) {
                selectedImage = image
            }
        } label: {
            ZStack(alignment: .bottomTrailing) {
                CachedRemoteImage(url: URL(string: image.fileURL)) { remoteImage in
                    remoteImage.resizable().scaledToFill()
                } placeholder: {
                    ZStack {
                        Color(AppDesign.Colors.secondaryBackground)
                        ProgressView().tint(accentOrange)
                    }
                } failure: {
                    ZStack {
                        Color(AppDesign.Colors.secondaryBackground)
                        Image(systemName: "photo")
                            .foregroundStyle(AppDesign.Colors.textTertiary)
                    }
                }
                .frame(width: 90, height: 90)
                .clipShape(RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .strokeBorder(
                            isSelected ? accentOrange : Color.clear,
                            lineWidth: 3
                        )
                )
                .scaleEffect(isSelected ? 1.04 : 1.0)

                if isSelected {
                    ZStack {
                        Circle()
                            .fill(accentOrange)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4, y: 4)
                }
            }
            .shadow(
                color: (isSelected ? accentOrange : Color.black).opacity(isSelected ? 0.35 : 0.1),
                radius: isSelected ? 8 : 4,
                x: 0, y: 3
            )
        }
        .buttonStyle(.plain)
        .animation(AppDesign.Animation.spring, value: isSelected)
    }

    // MARK: - Fetch

    private func fetchImages() async {
        isLoading = true
        saveError = nil
        do {
            let response = try await UserService.shared.getImages(category: "profile/superhero")
            await MainActor.run {
                images = response.data
                // Pre-select current imageUrl if it matches one of the fetched images
                if let currentUrl = appViewModel.currentUserProfile?.imageUrl,
                   let match = response.data.first(where: { $0.fileURL == currentUrl }) {
                    selectedImage = match
                }
                isLoading = false
            }
        } catch {
            await MainActor.run {
                saveError = error.localizedDescription
                isLoading = false
            }
        }
    }

    // MARK: - Save

    @MainActor
    private func save() async {
        guard !isSaving else { return }
        guard let image = selectedImage else { return }
        isSaving = true
        saveError = nil
        let request = UpdateProfileRequest(
            imageUrl: image.fileURL,
            birthDay: nil,
            firstName: nil,
            lastName: nil,
            phoneNumber: nil
        )
        do {
            try await appViewModel.updateProfile(request)
            isSaving = false
            requestDismiss()
        } catch {
            isSaving = false
            saveError = error.localizedDescription
        }
    }

    private func requestDismiss() {
        DispatchQueue.main.async {
            onDismiss()
        }
    }
}

// MARK: - Edit Profile Popup

struct EditProfilePopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let onDismiss: () -> Void

    private enum EditField: Hashable {
        case firstName
        case lastName
    }

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var initialFirstName: String = ""
    @State private var initialLastName: String = ""
    @State private var initialBirthDate: Date?
    @State private var maximumBirthDate = Date()
    @State private var isSaving = false
    @State private var saveError: String?
    @FocusState private var focusedField: EditField?

    private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)

    var body: some View {
        ZStack {
            // Dim backdrop
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { if !isSaving { requestDismiss() } }

            VStack(spacing: 0) {
                // ── Top bar (ChoreDetailPopup style)
                ZStack {
                    LinearGradient(
                        colors: [accentOrange, accentOrange.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white.opacity(0.12))

                    HStack(spacing: AppDesign.Spacing.sm) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.22))
                                .frame(width: 34, height: 34)
                            Text(previewInitials)
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundColor(.white)
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(appViewModel.localized("profile_edit_button"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text(appViewModel.currentUserProfile?.email ?? "")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.72))
                                .lineLimit(1)
                        }

                        Spacer()

                        Button { if !isSaving { requestDismiss() } } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 26, height: 26)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, 12)
                }
                .frame(height: 60)

                // ── Scrollable fields
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppDesign.Spacing.md) {
                        HStack(alignment: .top, spacing: AppDesign.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(accentOrange)

                            Text(
                                appViewModel.localized(
                                    "profile_edit_twenty_day_warning",
                                    fallback: "You can update your first name, last name, and birthdate once every 20 days."
                                )
                            )
                            .font(AppDesign.Typography.caption)
                            .foregroundStyle(AppDesign.Colors.textSecondary)
                            .fixedSize(horizontal: false, vertical: true)

                            Spacer(minLength: 0)
                        }
                        .padding(AppDesign.Spacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                .fill(accentOrange.opacity(0.1))
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                        .stroke(accentOrange.opacity(0.25), lineWidth: 1)
                                )
                        )

                        fieldSection(icon: "person.fill", tint: accentOrange, title: appViewModel.localized("profile_edit_name_section")) {
                            editField(icon: "person.fill", tint: accentOrange,
                                      placeholder: appViewModel.localized("profile_first_name_label"), text: $firstName, field: .firstName)
                            Divider().padding(.leading, 66)
                            editField(icon: "person.fill", tint: accentOrange,
                                      placeholder: appViewModel.localized("profile_last_name_label"),  text: $lastName, field: .lastName)
                        }

                        fieldSection(icon: "info.circle.fill",
                                     tint: Color(red: 0.2, green: 0.7, blue: 0.4),
                                     title: appViewModel.localized("profile_edit_details_section")) {
                            HStack(spacing: AppDesign.Spacing.md) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.9, green: 0.45, blue: 0.1).opacity(0.13))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "birthday.cake.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color(red: 0.9, green: 0.45, blue: 0.1))
                                }
                                Text(appViewModel.localized("profile_birthdate_label"))
                                    .font(AppDesign.Typography.subheadline)
                                    .foregroundStyle(AppDesign.Colors.textSecondary)
                                Spacer()
                                DatePicker("", selection: $birthDate, in: ...maximumBirthDate, displayedComponents: .date)
                                    .labelsHidden()
                                    .tint(Color(red: 0.9, green: 0.45, blue: 0.1))
                            }
                            .padding(.horizontal, AppDesign.Spacing.lg)
                            .padding(.vertical, 14)
                        }

                        if let error = saveError {
                            HStack(spacing: AppDesign.Spacing.sm) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                Text(error)
                                    .font(AppDesign.Typography.caption)
                                Spacer()
                            }
                            .foregroundStyle(AppDesign.Colors.error)
                            .padding(AppDesign.Spacing.md)
                            .background(
                                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                    .fill(AppDesign.Colors.error.opacity(0.1))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                            .stroke(AppDesign.Colors.error.opacity(0.3), lineWidth: 1)
                                    )
                            )
                        }
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, AppDesign.Spacing.xl)
                }
                .frame(maxHeight: 420)

                // ── Footer: Save + Cancel
                VStack(spacing: AppDesign.Spacing.sm) {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack(spacing: AppDesign.Spacing.sm) {
                            if isSaving {
                                ProgressView().scaleEffect(0.85).tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text(appViewModel.localized(isSaving ? "common_saving" : "common_save_changes"))
                                .font(AppDesign.Typography.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeightSmall)
                        .background(
                            isSaving || !hasChanges
                                ? LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [accentOrange, accentOrange.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(AppDesign.CornerRadius.md)
                    }
                    .disabled(isSaving || !hasChanges)
                    .animation(AppDesign.Animation.quick, value: hasChanges)
                    .animation(AppDesign.Animation.quick, value: isSaving)

                    Button { if !isSaving { requestDismiss() } } label: {
                        Text(appViewModel.localized("common_cancel"))
                            .font(AppDesign.Typography.headline)
                            .foregroundColor(AppDesign.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppDesign.Size.buttonHeightSmall)
                            .background(AppDesign.Colors.secondaryBackground)
                            .cornerRadius(AppDesign.CornerRadius.md)
                    }
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.lg)
                .background(
                    AppDesign.Colors.background
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -4)
                )
            }
            .background(
                ZStack {
                    AppDesign.Colors.background
                    LinearGradient(
                        colors: [accentOrange.opacity(0.04), Color.clear],
                        startPoint: .top, endPoint: .center
                    )
                }
            )
            .cornerRadius(AppDesign.CornerRadius.xl)
            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .animation(AppDesign.Animation.standard, value: isSaving)
        .onAppear(perform: populate)
    }

    // MARK: - Field Section

    @ViewBuilder
    private func fieldSection<Content: View>(
        icon: String,
        tint: Color,
        title: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: AppDesign.Spacing.sm) {
                ZStack {
                    RoundedRectangle(cornerRadius: 7)
                        .fill(tint.opacity(0.14))
                        .frame(width: 28, height: 28)
                    Image(systemName: icon)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(tint)
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

            content()
        }
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(AppDesign.Colors.secondaryBackground)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                        .stroke(tint.opacity(0.2), lineWidth: 1)
                )
        )
    }

    private func editField(
        icon: String,
        tint: Color,
        placeholder: String,
        text: Binding<String>,
        field: EditField,
        keyboard: UIKeyboardType = .default
    ) -> some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                RoundedRectangle(cornerRadius: 8)
                    .fill(tint.opacity(0.13))
                    .frame(width: 34, height: 34)
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(tint)
            }
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .font(AppDesign.Typography.subheadline)
                .focused($focusedField, equals: field)
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

    private var normalizedFirstName: String {
        firstName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var normalizedLastName: String {
        lastName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasFirstNameChanged: Bool {
        normalizedFirstName != initialFirstName
    }

    private var hasLastNameChanged: Bool {
        normalizedLastName != initialLastName
    }

    private var hasBirthDateChanged: Bool {
        guard let initialBirthDate else { return false }
        return !Calendar.current.isDate(birthDate, inSameDayAs: initialBirthDate)
    }

    private var hasChanges: Bool {
        hasFirstNameChanged || hasLastNameChanged || hasBirthDateChanged
    }

    private var previewInitials: String {
        let f = firstName.prefix(1)
        let l = lastName.prefix(1)
        if f.isEmpty && l.isEmpty {
            return appViewModel.currentUserProfile.map {
                "\($0.firstName.prefix(1))\($0.lastName.prefix(1))"
            }?.uppercased() ?? "?"
        }
        return "\(f)\(l)".uppercased()
    }

    private func populate() {
        guard let p = appViewModel.currentUserProfile else { return }
        firstName   = p.firstName
        lastName    = p.lastName
        initialFirstName = p.firstName.trimmingCharacters(in: .whitespacesAndNewlines)
        initialLastName = p.lastName.trimmingCharacters(in: .whitespacesAndNewlines)
        if let bd = p.birthDate, !bd.isEmpty {
            if let parsed = HouseFlowDateFormatter.parseAPIDate(bd) {
                birthDate = parsed
                initialBirthDate = parsed
                return
            }
        }
        initialBirthDate = birthDate
    }

    private func requestDismiss() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.async {
            onDismiss()
        }
    }

    // MARK: - Save (PUT user/profile)

    @MainActor
    private func save() async {
        guard !isSaving, hasChanges else { return }
        isSaving  = true
        saveError = nil
        let request = UpdateProfileRequest(
            imageUrl:      nil,
            birthDay:      hasBirthDateChanged ? HouseFlowDateFormatter.apiString(from: birthDate) : nil,
            firstName:     hasFirstNameChanged ? normalizedFirstName : nil,
            lastName:      hasLastNameChanged ? normalizedLastName : nil,
            phoneNumber:   nil
        )
        do {
            try await appViewModel.updateProfile(request)
            isSaving = false
            requestDismiss()
        } catch {
            isSaving  = false
            saveError = error.localizedDescription
        }
    }
}

// MARK: - Phone Management Popup

struct PhoneManagementPopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let currentPhoneNumber: String
    let isVerified: Bool
    let onDismiss: () -> Void

    private enum Mode: String, CaseIterable, Identifiable {
        case update
        case verify

        var id: String { rawValue }
    }

    private enum Field: Hashable {
        case phoneNumber
        case verificationCode
    }

    @State private var selectedMode: Mode = .update
    @State private var phoneNumber: String
    @State private var verificationCode = ""
    @State private var hasRequestedCode = false
    @FocusState private var focusedField: Field?

    private let accentBlue = Color(red: 0.15, green: 0.55, blue: 0.85)
    private let verifiedGreen = Color(red: 0.2, green: 0.75, blue: 0.45)

    init(
        currentPhoneNumber: String,
        isVerified: Bool,
        onDismiss: @escaping () -> Void
    ) {
        self.currentPhoneNumber = currentPhoneNumber
        self.isVerified = isVerified
        self.onDismiss = onDismiss
        _phoneNumber = State(initialValue: currentPhoneNumber)
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture(perform: requestDismiss)

            VStack(spacing: 0) {
                topBar

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppDesign.Spacing.lg) {
                        currentStatus
                        integrationNotice
                        modePicker

                        Group {
                            switch selectedMode {
                            case .update:
                                updateSection
                            case .verify:
                                verificationSection
                            }
                        }
                        .transition(.opacity.combined(with: .move(edge: .trailing)))
                    }
                    .padding(AppDesign.Spacing.xl)
                }
                .frame(maxHeight: 430)

                Button(action: requestDismiss) {
                    Text(appViewModel.localized("common_close", fallback: "Close"))
                        .font(AppDesign.Typography.headline)
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeightSmall)
                        .background(AppDesign.Colors.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.lg)
                .background(AppDesign.Colors.background)
            }
            .background(AppDesign.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .animation(AppDesign.Animation.standard, value: selectedMode)
        .animation(AppDesign.Animation.quick, value: hasRequestedCode)
    }

    private var topBar: some View {
        ZStack {
            LinearGradient(
                colors: [accentBlue, accentBlue.opacity(0.72)],
                startPoint: .leading,
                endPoint: .trailing
            )

            Image(systemName: "phone.badge.checkmark.fill")
                .font(.system(size: 58, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.12))
                .offset(x: 85)

            HStack(spacing: AppDesign.Spacing.md) {
                Image(systemName: "phone.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())

                Text(appViewModel.localized("profile_phone_management_title", fallback: "Phone settings"))
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(.white)

                Spacer()

                Button(action: requestDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 30, height: 30)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .frame(height: 62)
    }

    private var currentStatus: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            Image(systemName: isVerified ? "checkmark.shield.fill" : "exclamationmark.shield.fill")
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(isVerified ? verifiedGreen : AppDesign.Colors.error)
                .frame(width: 40, height: 40)
                .background((isVerified ? verifiedGreen : AppDesign.Colors.error).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(currentPhoneNumber.isEmpty ? appViewModel.localized("common_empty_value") : currentPhoneNumber)
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(AppDesign.Colors.textPrimary)
                Text(
                    appViewModel.localized(
                        isVerified ? "common_verified" : "common_not_verified",
                        fallback: isVerified ? "Verified" : "Not verified"
                    )
                )
                .font(AppDesign.Typography.caption)
                .foregroundStyle(isVerified ? verifiedGreen : AppDesign.Colors.error)
            }

            Spacer()
        }
        .padding(AppDesign.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .fill(AppDesign.Colors.secondaryBackground)
        )
    }

    private var integrationNotice: some View {
        HStack(alignment: .top, spacing: AppDesign.Spacing.sm) {
            Image(systemName: "info.circle.fill")
                .foregroundStyle(accentBlue)
            Text(
                appViewModel.localized(
                    "profile_phone_backend_pending_notice",
                    fallback: "Phone update and verification screens are ready. Backend integration will be connected later."
                )
            )
            .font(AppDesign.Typography.caption)
            .foregroundStyle(AppDesign.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .padding(AppDesign.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                .fill(accentBlue.opacity(0.09))
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                        .stroke(accentBlue.opacity(0.22), lineWidth: 1)
                )
        )
    }

    private var modePicker: some View {
        Picker("", selection: $selectedMode) {
            Text(appViewModel.localized("profile_phone_update_tab", fallback: "Update number"))
                .tag(Mode.update)
            Text(appViewModel.localized("profile_phone_verify_tab", fallback: "Verify"))
                .tag(Mode.verify)
        }
        .pickerStyle(.segmented)
        .onChange(of: selectedMode) { _, mode in
            focusedField = mode == .update ? .phoneNumber : nil
        }
    }

    private var updateSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Text(appViewModel.localized("profile_phone_new_number_label", fallback: "New phone number"))
                .font(AppDesign.Typography.subheadline.weight(.semibold))
                .foregroundStyle(AppDesign.Colors.textPrimary)

            HStack(spacing: AppDesign.Spacing.sm) {
                Image(systemName: "phone.fill")
                    .foregroundStyle(accentBlue)
                TextField(
                    appViewModel.localized("profile_edit_phone_placeholder", fallback: "Phone number"),
                    text: $phoneNumber
                )
                .keyboardType(.phonePad)
                .textContentType(.telephoneNumber)
                .focused($focusedField, equals: .phoneNumber)
            }
            .padding(AppDesign.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .fill(AppDesign.Colors.secondaryBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                            .stroke(accentBlue.opacity(focusedField == .phoneNumber ? 0.55 : 0.14), lineWidth: 1.5)
                    )
            )

            primaryButton(
                title: appViewModel.localized("profile_phone_update_button", fallback: "Update phone number"),
                icon: "arrow.triangle.2.circlepath",
                isEnabled: canSubmitPhoneUpdate,
                action: submitPhoneUpdate
            )
        }
    }

    private var verificationSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Text(
                appViewModel.localized(
                    "profile_phone_verification_instruction",
                    fallback: "Request a verification code for your current phone number, then enter the six-digit code."
                )
            )
            .font(AppDesign.Typography.subheadline)
            .foregroundStyle(AppDesign.Colors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            if hasRequestedCode {
                TextField(
                    appViewModel.localized("profile_phone_code_placeholder", fallback: "Verification code"),
                    text: $verificationCode
                )
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($focusedField, equals: .verificationCode)
                .multilineTextAlignment(.center)
                .font(.system(size: 22, weight: .semibold, design: .monospaced))
                .padding(AppDesign.Spacing.md)
                .background(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                        .fill(AppDesign.Colors.secondaryBackground)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                .stroke(accentBlue.opacity(focusedField == .verificationCode ? 0.55 : 0.14), lineWidth: 1.5)
                        )
                )
                .onChange(of: verificationCode) { _, value in
                    verificationCode = String(value.filter(\.isNumber).prefix(6))
                }

                primaryButton(
                    title: appViewModel.localized("profile_phone_verify_button", fallback: "Verify phone number"),
                    icon: "checkmark.shield.fill",
                    isEnabled: verificationCode.count == 6,
                    action: submitVerificationCode
                )
            } else {
                primaryButton(
                    title: appViewModel.localized("profile_phone_send_code_button", fallback: "Send verification code"),
                    icon: "paperplane.fill",
                    isEnabled: !currentPhoneNumber.isEmpty,
                    action: requestVerificationCode
                )
            }
        }
    }

    private func primaryButton(
        title: String,
        icon: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: AppDesign.Spacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                Text(title)
                    .font(AppDesign.Typography.headline)
            }
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: AppDesign.Size.buttonHeightSmall)
            .background(isEnabled ? accentBlue : Color(.systemGray3))
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
        }
        .disabled(!isEnabled)
    }

    private var normalizedPhoneNumber: String {
        phoneNumber.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var canSubmitPhoneUpdate: Bool {
        !normalizedPhoneNumber.isEmpty && normalizedPhoneNumber != currentPhoneNumber
    }

    private func submitPhoneUpdate() {
        showPendingIntegrationMessage()
    }

    private func requestVerificationCode() {
        hasRequestedCode = true
        focusedField = .verificationCode
        showPendingIntegrationMessage()
    }

    private func submitVerificationCode() {
        showPendingIntegrationMessage()
    }

    private func showPendingIntegrationMessage() {
        appViewModel.showToast(
            message: appViewModel.localized(
                "profile_phone_backend_pending_toast",
                fallback: "Phone backend integration is pending."
            ),
            isError: false
        )
    }

    private func requestDismiss() {
        focusedField = nil
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        onDismiss()
    }
}

// MARK: - Language Settings Popup

struct LanguageSettingsPopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let onDismiss: () -> Void

    @State private var selectedPrefix: String?
    @State private var isSaving = false
    @State private var saveError: String?

    private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)
    private let columns = [
        GridItem(.flexible()),
        GridItem(.flexible()),
        GridItem(.flexible())
    ]

    var body: some View {
        ZStack {
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { if !isSaving { requestDismiss() } }

            VStack(spacing: 0) {
                ZStack {
                    LinearGradient(
                        colors: [accentOrange, accentOrange.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    Image(systemName: "globe.europe.africa.fill")
                        .font(.system(size: 58, weight: .bold))
                        .foregroundColor(.white.opacity(0.12))

                    HStack(spacing: AppDesign.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appViewModel.localized("language_settings_title"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text(appViewModel.localized("language_settings_subtitle"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }

                        Spacer()

                        Button { if !isSaving { requestDismiss() } } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 26, height: 26)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, 12)
                }
                .frame(height: 64)

                ScrollView(showsIndicators: false) {
                    if appViewModel.isLoadingLocalizationLanguages && appViewModel.localizationLanguages.isEmpty {
                        ProgressView()
                            .tint(accentOrange)
                            .scaleEffect(1.2)
                            .frame(maxWidth: .infinity, minHeight: 190)
                    } else if appViewModel.localizationLanguages.isEmpty {
                        VStack(spacing: AppDesign.Spacing.sm) {
                            Image(systemName: "globe.badge.chevron.backward")
                                .font(.system(size: 36))
                                .foregroundStyle(AppDesign.Colors.textTertiary)
                            Text(appViewModel.localized("language_settings_empty_message"))
                                .font(AppDesign.Typography.subheadline)
                                .foregroundStyle(AppDesign.Colors.textTertiary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 190)
                    } else {
                        LazyVGrid(columns: columns, spacing: AppDesign.Spacing.md) {
                            ForEach(appViewModel.localizationLanguages) { language in
                                languageCell(language)
                            }
                        }
                        .padding(.horizontal, AppDesign.Spacing.xl)
                        .padding(.vertical, AppDesign.Spacing.xl)
                    }
                }
                .frame(maxHeight: 360)

                if let error = saveError {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(error)
                            .font(AppDesign.Typography.caption)
                        Spacer()
                    }
                    .foregroundStyle(AppDesign.Colors.error)
                    .padding(AppDesign.Spacing.md)
                    .background(
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                            .fill(AppDesign.Colors.error.opacity(0.1))
                    )
                    .padding(.horizontal, AppDesign.Spacing.xl)
                }

                VStack(spacing: AppDesign.Spacing.sm) {
                    Button {
                        Task { await save() }
                    } label: {
                        HStack(spacing: AppDesign.Spacing.sm) {
                            if isSaving {
                                ProgressView().scaleEffect(0.85).tint(.white)
                            } else {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            Text(appViewModel.localized(isSaving ? "common_saving" : "common_save_changes"))
                                .font(AppDesign.Typography.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeightSmall)
                        .background(
                            canSave
                                ? LinearGradient(colors: [accentOrange, accentOrange.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(AppDesign.CornerRadius.md)
                    }
                    .disabled(!canSave)

                    Button { if !isSaving { requestDismiss() } } label: {
                        Text(appViewModel.localized("common_cancel"))
                            .font(AppDesign.Typography.headline)
                            .foregroundColor(AppDesign.Colors.textSecondary)
                            .frame(maxWidth: .infinity)
                            .frame(height: AppDesign.Size.buttonHeightSmall)
                            .background(AppDesign.Colors.secondaryBackground)
                            .cornerRadius(AppDesign.CornerRadius.md)
                    }
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.lg)
                .background(AppDesign.Colors.background.shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -4))
            }
            .background(
                ZStack {
                    AppDesign.Colors.background
                    LinearGradient(
                        colors: [accentOrange.opacity(0.04), Color.clear],
                        startPoint: .top,
                        endPoint: .center
                    )
                }
            )
            .cornerRadius(AppDesign.CornerRadius.xl)
            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .animation(AppDesign.Animation.standard, value: isSaving)
        .animation(AppDesign.Animation.spring, value: selectedPrefix)
        .task { await loadLanguages() }
        .onAppear {
            selectedPrefix = normalized(appViewModel.currentLanguagePrefix)
        }
    }

    @ViewBuilder
    private func languageCell(_ language: LocalizationLanguage) -> some View {
        let isSelected = selectedPrefix == normalized(language.prefix)

        Button {
            guard language.isActive, !isSaving else { return }
            withAnimation(AppDesign.Animation.spring) {
                selectedPrefix = normalized(language.prefix)
            }
        } label: {
            VStack(spacing: AppDesign.Spacing.sm) {
                ZStack {
                    CachedRemoteImage(url: URL(string: language.image)) { remoteImage in
                        remoteImage.resizable().scaledToFill()
                    } placeholder: {
                        ZStack {
                            AppDesign.Colors.secondaryBackground
                            ProgressView().tint(accentOrange)
                        }
                    } failure: {
                        ZStack {
                            AppDesign.Colors.secondaryBackground
                            Image(systemName: "globe")
                                .font(.system(size: 26, weight: .semibold))
                                .foregroundStyle(AppDesign.Colors.textTertiary)
                        }
                    }
                    .frame(width: 86, height: 86)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .opacity(language.isActive ? 1 : 0.38)
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .strokeBorder(isSelected ? accentOrange : Color.clear, lineWidth: 3)
                    )
                    .scaleEffect(isSelected ? 1.04 : 1.0)

                    if !language.isActive {
                        Text(appViewModel.localized("language_settings_coming_soon_badge"))
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            .background(Capsule().fill(Color.black.opacity(0.58)))
                    }

                    if isSelected {
                        VStack {
                            HStack {
                                Spacer()
                                ZStack {
                                    Circle()
                                        .fill(accentOrange)
                                        .frame(width: 22, height: 22)
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 11, weight: .bold))
                                        .foregroundStyle(.white)
                                }
                            }
                            Spacer()
                        }
                        .frame(width: 86, height: 86)
                        .offset(x: 7, y: -7)
                    }
                }

                Text(language.nativeName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(language.isActive ? AppDesign.Colors.textPrimary : AppDesign.Colors.textTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppDesign.Spacing.sm)
        }
        .buttonStyle(.plain)
        .disabled(!language.isActive || isSaving)
        .shadow(
            color: (isSelected ? accentOrange : Color.black).opacity(isSelected ? 0.32 : 0.08),
            radius: isSelected ? 8 : 4,
            x: 0,
            y: 3
        )
    }

    private var canSave: Bool {
        guard !isSaving else { return false }
        guard let selected = selectedPrefix, !selected.isEmpty else { return false }
        guard selected != normalized(appViewModel.currentLanguagePrefix) else { return false }
        return appViewModel.localizationLanguages.first { normalized($0.prefix) == selected }?.isActive == true
    }

    private func loadLanguages() async {
        saveError = nil
        do {
            try await appViewModel.loadLocalizationLanguages()
            await MainActor.run {
                if selectedPrefix == nil {
                    selectedPrefix = normalized(appViewModel.currentLanguagePrefix)
                }
                if selectedPrefix == nil {
                    selectedPrefix = appViewModel.localizationLanguages.first(where: { $0.isDefault })?.prefix
                }
            }
        } catch {
            await MainActor.run {
                saveError = error.localizedDescription
            }
        }
    }

    @MainActor
    private func save() async {
        guard canSave, let selectedPrefix else { return }
        isSaving = true
        saveError = nil
        do {
            try await appViewModel.saveLanguagePreferenceAndRequireLogin(prefix: selectedPrefix)
            isSaving = false
            requestDismiss()
        } catch {
            isSaving = false
            saveError = error.localizedDescription
        }
    }

    private func normalized(_ prefix: String?) -> String? {
        guard let prefix else { return nil }
        let normalizedPrefix = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        return normalizedPrefix.isEmpty ? nil : normalizedPrefix
    }

    private func requestDismiss() {
        DispatchQueue.main.async {
            onDismiss()
        }
    }
}

// MARK: - About HouseFlow Popup

struct AboutPopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let onDismiss: () -> Void

    private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)

    var body: some View {
        ZStack {
            // Dim backdrop
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { requestDismiss() }

            VStack(spacing: 0) {
                // ── Top bar (identical pattern to EditProfilePopup / AvatarPickerPopup)
                ZStack {
                    LinearGradient(
                        colors: [accentOrange, accentOrange.opacity(0.7)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    Image(systemName: "house.fill")
                        .font(.system(size: 56, weight: .bold))
                        .foregroundColor(.white.opacity(0.12))

                    HStack(spacing: AppDesign.Spacing.sm) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(appViewModel.localized("profile_about_label"))
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text(appViewModel.localized("profile_about_version"))
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        Spacer()
                        Button(action: requestDismiss) {
                            Image(systemName: "xmark")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white.opacity(0.9))
                                .frame(width: 26, height: 26)
                                .background(Color.white.opacity(0.2))
                                .clipShape(Circle())
                        }
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.vertical, 12)
                }
                .frame(height: 64)

                // ── Body
                VStack(spacing: AppDesign.Spacing.lg) {
                    // Quote card
                    ZStack {
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                            .fill(accentOrange.opacity(0.06))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                                    .strokeBorder(accentOrange.opacity(0.2), lineWidth: 1)
                            )

                        VStack(spacing: 14) {
                            Image(systemName: "quote.opening")
                                .font(.system(size: 26, weight: .black))
                                .foregroundStyle(accentOrange.opacity(0.6))
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Text(appViewModel.localized("profile_about_quote"))
                                .font(.system(size: 19, weight: .bold, design: .rounded))
                                .foregroundStyle(accentOrange)
                                .multilineTextAlignment(.center)
                                .lineSpacing(5)
                                .frame(maxWidth: .infinity)

                            Image(systemName: "quote.closing")
                                .font(.system(size: 20, weight: .black))
                                .foregroundStyle(accentOrange.opacity(0.4))
                                .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                        .padding(20)
                    }

                    // Made with love
                    HStack(spacing: 6) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 11))
                            .foregroundStyle(accentOrange)
                        Text(appViewModel.localized("profile_about_made_with_love"))
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppDesign.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.xl)

                // ── Footer (same as AvatarPickerPopup)
                Button(action: requestDismiss) {
                    Text(appViewModel.localized("profile_about_close_button"))
                        .font(AppDesign.Typography.headline)
                        .foregroundColor(AppDesign.Colors.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeightSmall)
                        .background(AppDesign.Colors.secondaryBackground)
                        .cornerRadius(AppDesign.CornerRadius.md)
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.lg)
                .background(
                    AppDesign.Colors.background
                        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: -4)
                )
            }
            .background(
                ZStack {
                    AppDesign.Colors.background
                    LinearGradient(
                        colors: [accentOrange.opacity(0.04), Color.clear],
                        startPoint: .top, endPoint: .center
                    )
                }
            )
            .cornerRadius(AppDesign.CornerRadius.xl)
            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
    }

    private func requestDismiss() {
        DispatchQueue.main.async {
            onDismiss()
        }
    }
}
