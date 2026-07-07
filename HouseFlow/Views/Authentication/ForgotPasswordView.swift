import SwiftUI

// MARK: - Flow Phase

private enum ForgotFlowPhase {
    case idle
    case loading
    case failed
    case codeEntry
    case resetting
}

// MARK: - OTP Input View

private struct OTPInputView: View {
    @Binding var code: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            ForEach(0..<6, id: \.self) { i in
                digitBox(at: i)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
        .background(
            TextField("", text: $code)
                .keyboardType(.asciiCapable)
                .textContentType(.oneTimeCode)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
                .focused($isFocused)
                .opacity(0.001)
                .onChange(of: code) { newValue in
                    let filtered = String(newValue.filter { $0.isLetter || $0.isNumber }.prefix(6)).uppercased()
                    if filtered != newValue { code = filtered }
                }
        )
    }

    private func digitBox(at index: Int) -> some View {
        let chars = Array(code)
        let char = index < chars.count ? String(chars[index]) : ""
        let isActive = index == min(code.count, 5) && isFocused

        return ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.systemGray6))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            isActive ? AppDesign.Colors.primary :
                            !char.isEmpty ? AppDesign.Colors.primary.opacity(0.45) :
                            Color(.systemGray4),
                            lineWidth: isActive ? 2 : 1
                        )
                )
                .frame(width: 46, height: 58)

            Text(char)
                .font(.system(size: 22, weight: .bold, design: .monospaced))
                .foregroundColor(AppDesign.Colors.text)
        }
        .animation(AppDesign.Animation.quick, value: code)
        .animation(AppDesign.Animation.quick, value: isFocused)
    }
}

// MARK: - Forgot Password View

struct ForgotPasswordView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @FocusState private var emailFocused: Bool
    @FocusState private var newPasswordFocused: Bool

    @State private var email = ""
    @State private var phase: ForgotFlowPhase = .idle
    @State private var sendErrorMessage: String?
    @State private var otpCode = ""
    @State private var newPassword = ""
    @State private var isPasswordVisible = false

    // Toast
    @State private var toastMessage: String?
    @State private var toastIsError = true

    private let authService = AuthService.shared

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            heroGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                heroSection

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppDesign.Spacing.xxl) {
                        emailSection

                        if phase != .idle {
                            statusIconSection
                        }

                        if phase == .codeEntry || phase == .resetting {
                            codeEntrySection
                                .padding(.top, -AppDesign.Spacing.md)
                        }
                    }
                    .padding(.horizontal, AppDesign.Spacing.xxl)
                    .padding(.top, AppDesign.Spacing.xxxl)
                    .padding(.bottom, 60)
                }
                .frame(maxHeight: .infinity)
                .background(Color(.systemBackground))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
            }
            .ignoresSafeArea(.container, edges: .bottom)

            backButton

            if let msg = toastMessage {
                ToastView(message: msg, isError: toastIsError)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: phase)
        .animation(AppDesign.Animation.standard, value: toastMessage)
        .dismissKeyboardOnTap()
    }

    // MARK: - Gradient

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: [Color.orange, Color.orange.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // MARK: - Hero Section

    private var heroSection: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 70, height: 70)
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 88, height: 88)
                Image(systemName: "lock.rotation")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: AppDesign.Spacing.xs) {
                Text(appViewModel.localized("forgot_password_title"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(appViewModel.localized("forgot_password_subtitle"))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.72))
            }
        }
        .padding(.top, AppDesign.Spacing.xl)
        .padding(.bottom, AppDesign.Spacing.xxl)
    }

    // MARK: - Back Button

    private var backButton: some View {
        VStack {
            HStack {
                Button(action: { dismiss() }) {
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.25))
                            .frame(width: 40, height: 40)
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white)
                    }
                }
                .padding(.leading, AppDesign.Spacing.xxl)
                Spacer()
            }
            .padding(.top, 56)
            Spacer()
        }
    }

    // MARK: - Email Section

    private var isEmailDisabled: Bool {
        switch phase {
        case .loading, .codeEntry, .resetting: return true
        default: return false
        }
    }

    private var emailSection: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            emailField
            sendButton
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
            Text(appViewModel.localized("auth_email_label"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppDesign.Colors.text)
                .opacity(isEmailDisabled ? 0.45 : 1)

            HStack(spacing: AppDesign.Spacing.md) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 16))
                    .foregroundColor(
                        emailFocused && !isEmailDisabled
                            ? AppDesign.Colors.primary
                            : AppDesign.Colors.textSecondary
                    )
                    .frame(width: 20)

                TextField(appViewModel.localized("auth_email_placeholder"), text: $email)
                    .font(.system(size: 16))
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($emailFocused)
                    .disabled(isEmailDisabled)
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.vertical, AppDesign.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .fill(isEmailDisabled ? Color(.systemGray5) : AppDesign.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                            .stroke(
                                emailFocused && !isEmailDisabled ? AppDesign.Colors.primary : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .opacity(isEmailDisabled ? 0.6 : 1)
            .animation(AppDesign.Animation.quick, value: emailFocused)
        }
    }

    private var sendButton: some View {
        let isValid = isValidEmail(email)
        let isDisabled: Bool = {
            switch phase {
            case .loading, .codeEntry, .resetting: return true
            default: return !isValid
            }
        }()

        return Button(action: handleSend) {
            ZStack {
                if phase == .loading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(appViewModel.localized("forgot_password_send_button"))
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Group {
                    if !isDisabled {
                        heroGradient
                    } else {
                        LinearGradient(
                            colors: [Color(.systemGray4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(AppDesign.CornerRadius.xl)
            .shadow(
                color: !isDisabled ? Color.orange.opacity(0.4) : .clear,
                radius: 12, x: 0, y: 6
            )
        }
        .disabled(isDisabled)
        .animation(AppDesign.Animation.quick, value: isDisabled)
    }

    // MARK: - Status Icon Section

    @ViewBuilder
    private var statusIconSection: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            switch phase { 
            case .loading:
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: Color.orange))
                    .scaleEffect(1.6)
                    .frame(height: 80)
                    .transition(.scale.combined(with: .opacity))

            case .codeEntry, .resetting:
                statusCircle(icon: "checkmark.circle.fill", color: .green)
                    .scaleEffect(0.78)
                    .transition(.scale(scale: 0.3).combined(with: .opacity))

            case .failed:
                VStack(spacing: AppDesign.Spacing.sm) {
                    statusCircle(icon: "xmark.circle.fill", color: .red)
                        .transition(.scale(scale: 0.3).combined(with: .opacity))

                    if let msg = sendErrorMessage {
                        Text(msg)
                            .font(.system(size: 13))
                            .foregroundColor(AppDesign.Colors.error)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, AppDesign.Spacing.xl)
                            .transition(.opacity)
                    }
                }

            default:
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func statusCircle(icon: String, color: Color) -> some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.1))
                .frame(width: 80, height: 80)
            Circle()
                .strokeBorder(color.opacity(0.28), lineWidth: 2)
                .frame(width: 80, height: 80)
            Image(systemName: icon)
                .font(.system(size: 44))
                .foregroundColor(color)
        }
    }

    // MARK: - Code Entry Section

    private var codeEntrySection: some View {
        VStack(spacing: AppDesign.Spacing.xl) {
            // Info message
            VStack(spacing: AppDesign.Spacing.xs) {
                Text(appViewModel.localized("forgot_password_check_inbox_title"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppDesign.Colors.text)
                Text(appViewModel.localized(
                    "forgot_password_code_instruction_template",
                    replacements: ["email": email]
                ))
                    .font(.system(size: 14))
                    .foregroundColor(AppDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .transition(.push(from: .bottom).combined(with: .opacity))

            // OTP boxes
            OTPInputView(code: $otpCode)
                .transition(.push(from: .bottom).combined(with: .opacity))

            // New password field
            newPasswordField
                .transition(.push(from: .bottom).combined(with: .opacity))

            // Reset button
            resetButton
                .transition(.push(from: .bottom).combined(with: .opacity))
        }
    }

    // MARK: - New Password Field

    private var newPasswordField: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
            Text(appViewModel.localized("forgot_password_new_password_label"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppDesign.Colors.text)

            HStack(spacing: AppDesign.Spacing.md) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 16))
                    .foregroundColor(newPasswordFocused ? AppDesign.Colors.primary : AppDesign.Colors.textSecondary)
                    .frame(width: 20)

                Group {
                    if isPasswordVisible {
                        TextField(appViewModel.localized("forgot_password_new_password_placeholder"), text: $newPassword)
                            .font(.system(size: 16))
                            .focused($newPasswordFocused)
                            .autocorrectionDisabled()
                    } else {
                        SecureField(appViewModel.localized("forgot_password_new_password_placeholder"), text: $newPassword)
                            .font(.system(size: 16))
                            .focused($newPasswordFocused)
                    }
                }

                Button(action: { isPasswordVisible.toggle() }) {
                    Image(systemName: isPasswordVisible ? "eye.slash" : "eye")
                        .font(.system(size: 16))
                        .foregroundColor(AppDesign.Colors.textSecondary)
                }
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.vertical, AppDesign.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .fill(AppDesign.Colors.cardBackground)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                            .stroke(
                                newPasswordFocused ? AppDesign.Colors.primary : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .animation(AppDesign.Animation.quick, value: newPasswordFocused)
        }
    }

    // MARK: - Reset Button

    private var resetButton: some View {
        let isFormComplete = otpCode.count == 6 && !newPassword.isEmpty
        let isDisabled = !isFormComplete || phase == .resetting

        return Button(action: handleReset) {
            ZStack {
                if phase == .resetting {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(appViewModel.localized("forgot_password_reset_button"))
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Group {
                    if !isDisabled {
                        heroGradient
                    } else {
                        LinearGradient(
                            colors: [Color(.systemGray4)],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    }
                }
            )
            .cornerRadius(AppDesign.CornerRadius.xl)
            .shadow(
                color: !isDisabled ? Color.orange.opacity(0.4) : .clear,
                radius: 12, x: 0, y: 6
            )
        }
        .disabled(isDisabled)
        .animation(AppDesign.Animation.quick, value: isDisabled)
    }

    // MARK: - Actions

    private func handleSend() {
        guard isValidEmail(email) else {
            showToast(appViewModel.localized("forgot_password_invalid_email_toast"), isError: true)
            return
        }
        emailFocused = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.75)) {
            phase = .loading
            sendErrorMessage = nil
        }
        Task {
            do {
                _ = try await authService.forgotPassword(email: email)
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    phase = .codeEntry
                }
            } catch {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.7)) {
                    sendErrorMessage = error.localizedDescription
                    phase = .failed
                }
            }
        }
    }

    private func handleReset() {
        newPasswordFocused = false
        let code = otpCode
        let password = newPassword
        withAnimation(AppDesign.Animation.standard) { phase = .resetting }
        Task {
            do {
                _ = try await authService.resetPassword(email: email, code: code, newPassword: password)
                showToast(appViewModel.localized("forgot_password_success_toast"), isError: false)
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                dismiss()
            } catch {
                withAnimation(AppDesign.Animation.standard) { phase = .codeEntry }
                showToast(error.localizedDescription, isError: true)
            }
        }
    }

    private func showToast(_ message: String, isError: Bool) {
        toastIsError = isError
        withAnimation(AppDesign.Animation.standard) { toastMessage = message }
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            withAnimation(AppDesign.Animation.standard) { toastMessage = nil }
        }
    }

    private func isValidEmail(_ value: String) -> Bool {
        let regex = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        return value.range(of: regex, options: .regularExpression) != nil
    }
}

// MARK: - Preview

#Preview {
    ForgotPasswordView()
        .environmentObject(AppViewModel())
}
