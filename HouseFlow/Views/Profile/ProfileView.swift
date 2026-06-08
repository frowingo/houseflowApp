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
    @State private var showAbout = false
    @State private var avatarPulse = false
    @State private var selectedAvatarId: Int = 0

    // Brand colour — matches accentOrange in ChoreDetailPopup
    private let brandOrange   = Color(red: 1.0, green: 0.48, blue: 0.15)
    private var brandOrangeDk: Color { brandOrange.opacity(0.7) }

    var body: some View {
        ZStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 0) {
                    heroSection

                    VStack(spacing: AppDesign.Spacing.lg) {
                        statsStrip
                        personalInfoCard
                        accountCard
                        settingsCard
                    }
                    .padding(.horizontal, AppDesign.Spacing.lg)
                    .padding(.top, AppDesign.Spacing.xl)
                    .padding(.bottom, 100)
                }
            }
            .ignoresSafeArea(edges: .top)
            .background(Color(.systemGroupedBackground).ignoresSafeArea())

            if showAvatarPicker {
                AvatarPickerPopup(
                    initials: initials,
                    onDismiss: {
                        withAnimation(AppDesign.Animation.standard) {
                            showAvatarPicker = false
                        }
                    }
                )
                .environmentObject(appViewModel)
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(10)
            }

            if showEditSheet {
                EditProfilePopup(
                    onDismiss: {
                        withAnimation(AppDesign.Animation.standard) {
                            showEditSheet = false
                            appViewModel.isOverlayPresented = false
                        }
                    }
                )
                .environmentObject(appViewModel)
                .zIndex(11)
            }

            if showAbout {
                AboutPopup {
                    withAnimation(AppDesign.Animation.standard) { showAbout = false }
                }
                .transition(.opacity.combined(with: .scale(scale: 0.96)))
                .zIndex(12)
            }
        }
        .animation(AppDesign.Animation.standard, value: showAvatarPicker)
        .animation(AppDesign.Animation.standard, value: showEditSheet)
        .animation(AppDesign.Animation.standard, value: showAbout)
        .onChange(of: showEditSheet) { _, v in
            withAnimation(AppDesign.Animation.standard) {
                appViewModel.isOverlayPresented = v
            }
        }
    }

    // MARK: - Hero

    private var heroSection: some View {
        ZStack(alignment: .bottom) {
            // Background gradient
            LinearGradient(
                colors: [brandOrange, brandOrangeDk],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .frame(height: 310)

            // Decorative blobs
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 230, height: 230)
                .blur(radius: 12)
                .offset(x: 110, y: -90)

            Circle()
                .fill(Color.white.opacity(0.05))
                .frame(width: 170, height: 170)
                .blur(radius: 8)
                .offset(x: -100, y: 40)

            Circle()
                .fill(Color(red: 0.65, green: 0.20, blue: 0.05).opacity(0.22))
                .frame(width: 100, height: 100)
                .blur(radius: 6)
                .offset(x: 50, y: 55)

            // Content
            VStack(spacing: AppDesign.Spacing.md) {
                // Tappable avatar
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
                                AsyncImage(url: url) { phase in
                                    switch phase {
                                    case .success(let img):
                                        img.resizable().scaledToFill()
                                    default:
                                        Circle()
                                            .fill(
                                                LinearGradient(
                                                    colors: avatarOptions[selectedAvatarId].colors,
                                                    startPoint: .topLeading,
                                                    endPoint: .bottomTrailing
                                                )
                                            )
                                    }
                                }
                            } else {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: avatarOptions[selectedAvatarId].colors,
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
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

                        // Camera badge (bottom-right)
                        ZStack {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 28, height: 28)
                            Image(systemName: "camera.fill")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(brandOrangeDk)
                        }
                        .offset(x: 36, y: 36)

                        // Completeness badge (bottom-left)
                        ZStack {
                            Circle()
                                .fill(brandOrangeDk)
                                .frame(width: 26, height: 26)
                            Circle()
                                .strokeBorder(Color.white, lineWidth: 2)
                                .frame(width: 26, height: 26)
                            Text("\(Int(profileCompleteness * 100))%")
                                .font(.system(size: 7.5, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .offset(x: -36, y: 36)
                    }
                    .shadow(color: Color.black.opacity(0.28), radius: 16, x: 0, y: 8)
                }
                .buttonStyle(.plain)
                .onAppear { avatarPulse = true }

                // Name & email
                VStack(spacing: 5) {
                    Text(fullName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)

                    Text(appViewModel.currentUserProfile?.email ?? "—")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.72))
                }

                // Verification pills
                HStack(spacing: AppDesign.Spacing.sm) {
                    verificationPill(
                        icon: "envelope.fill",
                        label: "Email",
                        verified: appViewModel.currentUserProfile?.isVerifyEmail == true
                    )
                    verificationPill(
                        icon: "phone.fill",
                        label: "Phone",
                        verified: appViewModel.currentUserProfile?.isVerifyPhone == true
                    )
                }
                .padding(.bottom, AppDesign.Spacing.xl)
            }
        }
    }

    private func verificationPill(icon: String, label: String, verified: Bool) -> some View {
        let green = Color(red: 0.2, green: 0.85, blue: 0.5)
        return HStack(spacing: 5) {
            Image(systemName: verified ? "checkmark.circle.fill" : "xmark.circle.fill")
                .font(.system(size: 12, weight: .semibold))
            Text(label)
                .font(.system(size: 12, weight: .semibold))
        }
        .foregroundStyle(verified ? green : Color.white.opacity(0.5))
        .padding(.horizontal, 13)
        .padding(.vertical, 7)
        .background(
            Capsule()
                .fill(verified ? green.opacity(0.18) : Color.white.opacity(0.1))
        )
        .overlay(
            Capsule()
                .strokeBorder(
                    verified ? green.opacity(0.45) : Color.white.opacity(0.18),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Stats Strip

    private var statsStrip: some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            statChip(
                icon: "house.fill",
                tint: brandOrange,
                title: "House",
                value: appViewModel.currentHouseDetails?.name ?? (appViewModel.houseName.isEmpty ? "—" : appViewModel.houseName)
            )
            statChip(
                icon: "checkmark.shield.fill",
                tint: Color(red: 0.2, green: 0.75, blue: 0.45),
                title: "Status",
                value: appViewModel.currentUserProfile?.isActive == true ? "Active" : "Inactive",
                valueColor: appViewModel.currentUserProfile?.isActive == true
                    ? Color(red: 0.2, green: 0.75, blue: 0.45)
                    : AppDesign.Colors.error
            )
            statChip(
                icon: "calendar",
                tint: Color(red: 0.55, green: 0.35, blue: 0.9),
                title: "Joined",
                value: memberSince
            )
        }
    }

    private func statChip(
        icon: String,
        tint: Color,
        title: String,
        value: String,
        valueColor: Color = AppDesign.Colors.textPrimary
    ) -> some View {
        VStack(spacing: 6) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(tint.opacity(0.14))
                    .frame(width: 38, height: 38)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tint)
            }

            Text(value)
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(valueColor)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(AppDesign.Colors.textTertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.Spacing.md)
        .background(
            ZStack {
                AppDesign.Colors.cardBackground
                LinearGradient(
                    colors: [tint.opacity(0.05), Color.clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
        .shadow(color: Color.black.opacity(0.05), radius: 8, x: 0, y: 3)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg)
                .strokeBorder(tint.opacity(0.2), lineWidth: 1)
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
                Text("PERSONAL INFORMATION")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(AppDesign.Colors.textTertiary)
                    .kerning(0.9)
                Spacer()
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.top, AppDesign.Spacing.md)
            .padding(.bottom, AppDesign.Spacing.sm)

            Divider().padding(.horizontal, AppDesign.Spacing.lg)

            infoRow(icon: "person.fill",        tint: brandOrange,                              label: "First Name", value: appViewModel.currentUserProfile?.firstName ?? "—")
            cardDivider
            infoRow(icon: "person.fill",        tint: brandOrange,                              label: "Last Name",  value: appViewModel.currentUserProfile?.lastName ?? "—")
            cardDivider
            infoRow(icon: "phone.fill",         tint: Color(red: 0.2, green: 0.7, blue: 0.4),   label: "Phone",      value: phoneDisplay)
            cardDivider
            infoRow(icon: "birthday.cake.fill", tint: Color(red: 0.9, green: 0.45, blue: 0.1),  label: "Birthdate",  value: birthDateDisplay)

            // Edit Profile button inside card
            Divider().padding(.horizontal, AppDesign.Spacing.lg)

            Button {
                showEditSheet = true
            } label: {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Image(systemName: "pencil.and.outline")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Edit Profile")
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

    // MARK: - Account Card

    private var accountCard: some View {
        modernCard(
            headerIcon: "shield.lefthalf.filled",
            headerTint: Color(red: 0.55, green: 0.35, blue: 0.9),
            title: "Account",
            gradientColors: [Color(red: 0.55, green: 0.35, blue: 0.9).opacity(0.06), Color.clear, Color(red: 0.95, green: 0.6, blue: 0.1).opacity(0.04)]
        ) {
            infoRow(icon: "calendar",              tint: Color(red: 0.55, green: 0.35, blue: 0.9),  label: "Member Since", value: formattedDate(appViewModel.currentUserProfile?.createdOn))
            cardDivider
            infoRow(icon: "clock.fill",            tint: Color(red: 0.95, green: 0.6, blue: 0.1),   label: "Last Login",   value: formattedDate(appViewModel.currentUserProfile?.lastLogin))
            cardDivider
            infoRow(icon: "checkmark.shield.fill", tint: Color(red: 0.2, green: 0.75, blue: 0.45),  label: "Status",       value: appViewModel.currentUserProfile?.isActive == true ? "Active" : "Inactive",
                    valueColor: appViewModel.currentUserProfile?.isActive == true
                        ? Color(red: 0.2, green: 0.75, blue: 0.45)
                        : AppDesign.Colors.error)
        }
    }

    // MARK: - Settings Card

    private var settingsCard: some View {
        modernCard(
            headerIcon: "gearshape.fill",
            headerTint: AppDesign.Colors.textTertiary,
            title: "Settings",
            gradientColors: [Color.gray.opacity(0.04), Color.clear]
        ) {
            settingsRow(icon: "bell.badge.fill",       tint: Color(red: 0.95, green: 0.45, blue: 0.1), label: "Notifications")
            cardDivider
            settingsRow(icon: "lock.shield.fill",      tint: Color(red: 0.35, green: 0.55, blue: 0.88), label: "Privacy & Security")
            cardDivider
            settingsRow(icon: "questionmark.circle.fill", tint: Color(red: 0.55, green: 0.35, blue: 0.9), label: "Help & Support")
            cardDivider
            settingsRow(icon: "info.circle.fill",      tint: AppDesign.Colors.textTertiary,             label: "About HouseFlow") {
                withAnimation(AppDesign.Animation.standard) { showAbout = true }
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
        guard let p = appViewModel.currentUserProfile else { return "—" }
        return "\(p.firstName) \(p.lastName)"
    }

    private var phoneDisplay: String {
        guard let p = appViewModel.currentUserProfile, !p.phoneNumber.isEmpty else { return "—" }
        return p.phoneNumber
    }

    private var birthDateDisplay: String {
        guard let p = appViewModel.currentUserProfile, let bd = p.birthDate, !bd.isEmpty else { return "—" }
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let date = isoFormatter.date(from: bd) ?? {
            isoFormatter.formatOptions = [.withInternetDateTime]
            return isoFormatter.date(from: bd)
        }()
        guard let birth = date else { return "—" }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: birth)
    }

    private var memberSince: String {
        guard let iso = appViewModel.currentUserProfile?.createdOn, !iso.isEmpty else { return "—" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else { return "—" }
        let cal = Calendar.current
        let months = cal.dateComponents([.month], from: date, to: Date()).month ?? 0
        if months < 1 { return "New" }
        if months < 12 { return "\(months)mo" }
        let years = months / 12
        return "\(years)yr"
    }

    private var profileCompleteness: Double {
        guard let p = appViewModel.currentUserProfile else { return 0 }
        var score = 0.0
        if !p.firstName.isEmpty    { score += 0.2 }
        if !p.lastName.isEmpty     { score += 0.2 }
        if !p.phoneNumber.isEmpty  { score += 0.2 }
        if p.birthDate != nil       { score += 0.2 }
        if p.isVerifyEmail == true { score += 0.2 }
        return score
    }

    private func formattedDate(_ iso: String?) -> String {
        guard let iso, !iso.isEmpty else { return "—" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        guard let date = formatter.date(from: iso) else { return "—" }
        let display = DateFormatter()
        display.dateStyle = .medium
        display.timeStyle = .none
        return display.string(from: date)
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
                .onTapGesture { if !isSaving { onDismiss() } }

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
                            Text("Choose Avatar")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text("Select an image to apply")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        Spacer()
                        Button { if !isSaving { onDismiss() } } label: {
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
                            Text("No images found")
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
                            Text(isSaving ? "Saving…" : "Save Changes")
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

                    Button { if !isSaving { onDismiss() } } label: {
                        Text("Cancel")
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
                AsyncImage(url: URL(string: image.fileURL)) { phase in
                    switch phase {
                    case .success(let img):
                        img.resizable().scaledToFill()
                    case .failure:
                        ZStack {
                            Color(AppDesign.Colors.secondaryBackground)
                            Image(systemName: "photo")
                                .foregroundStyle(AppDesign.Colors.textTertiary)
                        }
                    default:
                        ZStack {
                            Color(AppDesign.Colors.secondaryBackground)
                            ProgressView().tint(accentOrange)
                        }
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

    private func save() async {
        guard let image = selectedImage else { return }
        isSaving = true
        saveError = nil
        let request = UpdateProfileRequest(
            imageUrl: image.fileURL,
            birthDay: nil,
            firstName: nil,
            isVerifyEmail: nil,
            isVerifyPhone: nil,
            lastName: nil,
            phoneNumber: nil
        )
        do {
            try await appViewModel.updateProfile(request)
            await MainActor.run {
                isSaving = false
                onDismiss()
            }
        } catch {
            await MainActor.run {
                isSaving = false
                saveError = error.localizedDescription
            }
        }
    }
}

// MARK: - Edit Profile Popup

struct EditProfilePopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let onDismiss: () -> Void

    @State private var firstName: String = ""
    @State private var lastName: String = ""
    @State private var phoneNumber: String = ""
    @State private var birthDate: Date = Calendar.current.date(byAdding: .year, value: -25, to: Date()) ?? Date()
    @State private var isSaving = false
    @State private var saveError: String?

    private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)

    var body: some View {
        ZStack {
            // Dim backdrop
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { if !isSaving { onDismiss() } }

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
                            Text("Edit Profile")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text(appViewModel.currentUserProfile?.email ?? "")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundColor(.white.opacity(0.72))
                                .lineLimit(1)
                        }

                        Spacer()

                        Button { if !isSaving { onDismiss() } } label: {
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
                        fieldSection(icon: "person.fill", tint: accentOrange, title: "Name") {
                            editField(icon: "person.fill", tint: accentOrange,
                                      placeholder: "First Name", text: $firstName)
                            Divider().padding(.leading, 66)
                            editField(icon: "person.fill", tint: accentOrange,
                                      placeholder: "Last Name",  text: $lastName)
                        }

                        fieldSection(icon: "info.circle.fill",
                                     tint: Color(red: 0.2, green: 0.7, blue: 0.4),
                                     title: "Details") {
                            editField(icon: "phone.fill",
                                      tint: Color(red: 0.2, green: 0.7, blue: 0.4),
                                      placeholder: "Phone Number", text: $phoneNumber,
                                      keyboard: .phonePad)
                            Divider().padding(.leading, 66)
                            HStack(spacing: AppDesign.Spacing.md) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color(red: 0.9, green: 0.45, blue: 0.1).opacity(0.13))
                                        .frame(width: 34, height: 34)
                                    Image(systemName: "birthday.cake.fill")
                                        .font(.system(size: 14, weight: .medium))
                                        .foregroundStyle(Color(red: 0.9, green: 0.45, blue: 0.1))
                                }
                                Text("Birthdate")
                                    .font(AppDesign.Typography.subheadline)
                                    .foregroundStyle(AppDesign.Colors.textSecondary)
                                Spacer()
                                DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
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
                            Text(isSaving ? "Saving…" : "Save Changes")
                                .font(AppDesign.Typography.headline)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeightSmall)
                        .background(
                            isSaving
                                ? LinearGradient(colors: [Color.gray.opacity(0.5), Color.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                                : LinearGradient(colors: [accentOrange, accentOrange.opacity(0.75)], startPoint: .leading, endPoint: .trailing)
                        )
                        .cornerRadius(AppDesign.CornerRadius.md)
                    }
                    .disabled(isSaving)
                    .animation(AppDesign.Animation.quick, value: isSaving)

                    Button { if !isSaving { onDismiss() } } label: {
                        Text("Cancel")
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
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, 14)
    }

    // MARK: - Helpers

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
        phoneNumber = p.phoneNumber
        if let bd = p.birthDate, !bd.isEmpty {
            let isoFormatter = ISO8601DateFormatter()
            isoFormatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let parsed = isoFormatter.date(from: bd) {
                birthDate = parsed
            } else {
                isoFormatter.formatOptions = [.withInternetDateTime]
                if let parsed = isoFormatter.date(from: bd) { birthDate = parsed }
            }
        }
    }

    // MARK: - Save (PUT user/profile)

    private func save() async {
        isSaving  = true
        saveError = nil
        let isoFormatter = ISO8601DateFormatter()
        isoFormatter.formatOptions = [.withInternetDateTime]
        let birthDateString = isoFormatter.string(from: birthDate)
        let request = UpdateProfileRequest(
            imageUrl:      nil,
            birthDay:      birthDateString,
            firstName:     firstName.isEmpty   ? nil : firstName,
            isVerifyEmail: nil,
            isVerifyPhone: nil,
            lastName:      lastName.isEmpty    ? nil : lastName,
            phoneNumber:   phoneNumber.isEmpty ? nil : phoneNumber
        )
        do {
            try await appViewModel.updateProfile(request)
            isSaving = false
            onDismiss()
        } catch {
            isSaving  = false
            saveError = error.localizedDescription
        }
    }
}

// MARK: - About HouseFlow Popup

struct AboutPopup: View {
    let onDismiss: () -> Void

    private let accentOrange = Color(red: 1.0, green: 0.48, blue: 0.15)

    var body: some View {
        ZStack {
            // Dim backdrop
            Color.black.opacity(0.55)
                .ignoresSafeArea()
                .onTapGesture { onDismiss() }

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
                            Text("About HouseFlow")
                                .font(.system(size: 15, weight: .bold))
                                .foregroundColor(.white)
                            Text("v1.0.0")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundColor(.white.opacity(0.75))
                        }
                        Spacer()
                        Button(action: onDismiss) {
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

                            Text("Bu uygulamayı yapan tosun,\nokuyana kosun")
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
                        Text("Made with love in Turkey")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(AppDesign.Colors.textTertiary)
                    }
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.xl)

                // ── Footer (same as AvatarPickerPopup)
                Button(action: onDismiss) {
                    Text("Kapat")
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
}
