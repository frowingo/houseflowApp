import SwiftUI

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
                    .zIndex(1)

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
                .scrollDismissesKeyboard(.interactively)
                .frame(maxHeight: 430)
                .clipped()

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
            .background(MainScreenBackground())
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
            .shadow(color: Color.black.opacity(0.25), radius: 30, x: 0, y: 16)
            .padding(.horizontal, AppDesign.Spacing.xl)
        }
        .dismissKeyboardOnTap()
        .animation(AppDesign.Animation.standard, value: selectedMode)
        .animation(AppDesign.Animation.quick, value: hasRequestedCode)
    }

    private var topBar: some View {
        ZStack {
            BrandPopupHeaderBackground()

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
