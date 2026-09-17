import SwiftUI

struct JoinHousePopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let onDismiss: () -> Void

    @State private var inviteCode = ""
    @State private var isJoining = false
    @State private var errorMessage: String?
    @AccessibilityFocusState private var headerAccessibilityFocused: Bool

    private let tint = Color(red: 0.12, green: 0.55, blue: 0.54)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                Color.black.opacity(0.55)
                    .ignoresSafeArea()
                    .onTapGesture {
                        guard !isJoining else { return }
                        requestDismiss()
                    }

                popupContent
                    .frame(maxWidth: 480)
                    .frame(
                        height: max(
                            0,
                            min(
                                proxy.size.height - 40,
                                dynamicTypeSize.isAccessibilitySize ? 430 : 350
                            )
                        )
                    )
                    .padding(.horizontal, AppDesign.Spacing.lg)
            }
        }
        .task {
            headerAccessibilityFocused = true
        }
    }

    private var popupContent: some View {
        VStack(spacing: 0) {
            header

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.xl) {
                    VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                        Text(
                            appViewModel.localized(
                                "profile_house_join_prompt",
                                fallback: "Enter the 8-character invite code shared with you."
                            )
                        )
                        .font(AppDesign.Typography.subheadline)
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)

                        OTPInputView(
                            code: $inviteCode,
                            characterCount: InviteCodeRules.requiredLength,
                            digitsOnly: false,
                            isError: errorMessage != nil,
                            automaticallyFocus: true,
                            accessibilityLabel: appViewModel.localized(
                                "profile_house_join_code_accessibility_label",
                                fallback: "House invite code"
                            ),
                            onSubmit: submit
                        )
                        .onChange(of: inviteCode) { _, _ in
                            errorMessage = nil
                        }

                        HStack {
                            Text(
                                appViewModel.localized(
                                    "profile_house_join_code_hint",
                                    fallback: "Letters and numbers only"
                                )
                            )
                            Spacer()
                            Text("\(inviteCode.count)/\(InviteCodeRules.requiredLength)")
                                .monospacedDigit()
                        }
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(
                            InviteCodeRules.isValid(inviteCode)
                                ? AppDesign.Colors.textPrimary
                                : AppDesign.Colors.textSecondary
                        )
                    }

                    if let errorMessage {
                        HStack(alignment: .top, spacing: AppDesign.Spacing.sm) {
                            Image(systemName: "exclamationmark.triangle.fill")
                            Text(errorMessage)
                                .fixedSize(horizontal: false, vertical: true)
                            Spacer(minLength: 0)
                        }
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(AppDesign.Colors.error)
                        .padding(AppDesign.Spacing.md)
                        .background(AppDesign.Colors.error.opacity(0.09))
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
                    }
                }
                .padding(AppDesign.Spacing.lg)
            }
            .scrollDismissesKeyboard(.interactively)

            footer
        }
        .background(MainScreenBackground())
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
        .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
        .accessibilityAddTraits(.isModal)
    }

    private var header: some View {
        ZStack {
            BrandPopupHeaderBackground()

            Image(systemName: "house.and.flag.fill")
                .font(.system(size: 56, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.12))
                .offset(x: 85)

            HStack(spacing: AppDesign.Spacing.sm) {
                Image(systemName: "person.2.badge.plus")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 34, height: 34)
                    .background(Color.white.opacity(0.18))
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(
                        appViewModel.localized(
                            "profile_house_join_title",
                            fallback: "Join a house"
                        )
                    )
                    .font(AppDesign.Typography.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .accessibilityFocused($headerAccessibilityFocused)

                    Text(
                        appViewModel.localized(
                            "profile_house_join_subtitle",
                            fallback: "Use an invitation code"
                        )
                    )
                    .font(AppDesign.Typography.caption2)
                    .foregroundStyle(Color.white.opacity(0.76))
                }

                Spacer(minLength: AppDesign.Spacing.sm)

                Button(action: requestDismiss) {
                    Image(systemName: "xmark")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 28, height: 28)
                        .background(Color.white.opacity(0.18))
                        .clipShape(Circle())
                        .frame(width: 44, height: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(isJoining)
                .accessibilityLabel(appViewModel.localized("common_close", fallback: "Close"))
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .frame(height: 64)
        .zIndex(1)
    }

    private var footer: some View {
        Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(spacing: AppDesign.Spacing.sm) {
                    joinButton
                    cancelButton
                }
            } else {
                HStack(spacing: AppDesign.Spacing.md) {
                    cancelButton
                    joinButton
                }
            }
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, AppDesign.Spacing.md)
        .background(AppDesign.Colors.background)
        .overlay(alignment: .top) {
            Divider()
        }
    }

    private var cancelButton: some View {
        Button(action: requestDismiss) {
            Text(appViewModel.localized("common_cancel", fallback: "Cancel"))
                .font(AppDesign.Typography.headline)
                .foregroundStyle(AppDesign.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(minHeight: AppDesign.Size.buttonHeightSmall)
                .padding(.vertical, AppDesign.Spacing.xs)
                .background(AppDesign.Colors.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
        }
        .buttonStyle(.plain)
        .disabled(isJoining)
    }

    private var joinButton: some View {
        Button(action: submit) {
            HStack(spacing: AppDesign.Spacing.sm) {
                if isJoining {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: "arrow.right.circle.fill")
                }
                Text(
                    appViewModel.localized(
                        isJoining ? "common_joining" : "profile_house_join_button",
                        fallback: isJoining ? "Joining…" : "Join house"
                    )
                )
                .fixedSize(horizontal: false, vertical: true)
            }
            .font(AppDesign.Typography.headline)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(minHeight: AppDesign.Size.buttonHeightSmall)
            .padding(.vertical, AppDesign.Spacing.xs)
            .background(joinButtonBackground)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
        }
        .buttonStyle(.plain)
        .disabled(!canJoin)
    }

    private var canJoin: Bool {
        InviteCodeRules.isValid(inviteCode) && !isJoining
    }

    private var joinButtonBackground: some View {
        Group {
            if canJoin {
                HouseJourneyTheme.joinButtonGradient
            } else {
                LinearGradient(
                    colors: [Color.gray.opacity(0.42), Color.gray.opacity(0.32)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            }
        }
    }

    private func submit() {
        guard canJoin else { return }
        hideKeyboard()
        Task { await joinHouse() }
    }

    @MainActor
    private func joinHouse() async {
        isJoining = true
        errorMessage = nil
        do {
            _ = try await appViewModel.joinHouseFromProfile(inviteCode: inviteCode)
            isJoining = false
            appViewModel.showToast(
                message: appViewModel.localized(
                    "profile_house_join_success",
                    fallback: "House joined successfully."
                ),
                isError: false
            )
            requestDismiss()
        } catch {
            errorMessage = error.localizedDescription
            isJoining = false
        }
    }

    private func requestDismiss() {
        guard !isJoining else { return }
        hideKeyboard()
        DispatchQueue.main.async {
            onDismiss()
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
}
