import SwiftUI

struct EmailVerificationView: View {
    let email: String
    let signupSuccessMessage: String?
    let onCancel: () -> Void
    let onSendCode: () async throws -> Void
    let onDismissSignupSuccess: () -> Void

    @State private var hasSentCode = false
    @State private var isSending = false
    @State private var isVerifying = false
    @State private var otpCode = ""
    @State private var secondsRemaining = 0
    @State private var countdownDeadline: Date?
    @State private var countdownID = 0
    @State private var toastMessage: String?
    @State private var isShowingSignupSuccess = false

    init(
        email: String,
        signupSuccessMessage: String? = nil,
        onCancel: @escaping () -> Void = {},
        onSendCode: @escaping () async throws -> Void = {},
        onDismissSignupSuccess: @escaping () -> Void = {}
    ) {
        self.email = email
        self.signupSuccessMessage = signupSuccessMessage
        self.onCancel = onCancel
        self.onSendCode = onSendCode
        self.onDismissSignupSuccess = onDismissSignupSuccess
    }

    var body: some View {
        ZStack(alignment: .top) {
            Color(.systemBackground).ignoresSafeArea()

            VStack(spacing: 0) {
                heroSection

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppDesign.Spacing.xxl) {
                        emailSection

                        if hasSentCode {
                            codeEntrySection
                                .transition(.push(from: .bottom).combined(with: .opacity))
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

            if let toastMessage {
                ToastView(message: toastMessage, isError: true)
                    .padding(.top, 60)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .zIndex(10)
            }

            if isShowingSignupSuccess, let signupSuccessMessage {
                signupSuccessPopup(message: signupSuccessMessage)
                    .transition(.opacity.combined(with: .scale(scale: 0.94)))
                    .zIndex(20)
            }
        }
        .animation(.spring(response: 0.48, dampingFraction: 0.78), value: hasSentCode)
        .animation(AppDesign.Animation.standard, value: toastMessage)
        .dismissKeyboardOnTap()
        .task(id: countdownID) {
            await runCountdown()
        }
        .onAppear {
            presentSignupSuccessIfNeeded(signupSuccessMessage)
        }
        .onChange(of: signupSuccessMessage) { _, newMessage in
            presentSignupSuccessIfNeeded(newMessage)
        }
    }

    private var heroGradient: LinearGradient {
        LinearGradient(
            colors: [Color.orange, Color.orange.opacity(0.72)],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func signupSuccessPopup(message: String) -> some View {
        ZStack {
            Color.black.opacity(0.42)
                .ignoresSafeArea()

            VStack(spacing: AppDesign.Spacing.xl) {
                ZStack {
                    Circle()
                        .fill(AppDesign.Colors.success.opacity(0.12))
                        .frame(width: 88, height: 88)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 52, weight: .semibold))
                        .foregroundStyle(AppDesign.Colors.success)
                }

                VStack(spacing: AppDesign.Spacing.sm) {
                    Text(appViewModel.localized(
                        "signup_success_title",
                        fallback: "Registration complete"
                    ))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(AppDesign.Colors.textPrimary)

                    Text(message)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                }

                Button(action: dismissSignupSuccess) {
                    Text(appViewModel.localized(
                        "common_continue",
                        fallback: "Continue"
                    ))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(heroGradient)
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
                }
            }
            .padding(AppDesign.Spacing.xxl)
            .background(AppDesign.Colors.background)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xxl))
            .shadow(color: Color.black.opacity(0.20), radius: 24, x: 0, y: 12)
            .padding(.horizontal, AppDesign.Spacing.xxxl)
        }
    }

    private var heroSection: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 70, height: 70)
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 88, height: 88)
                Image(systemName: "envelope.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: AppDesign.Spacing.xs) {
                Text(appViewModel.localized("email_verification_title", fallback: "Verify your email"))
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(appViewModel.localized(
                    "email_verification_subtitle",
                    fallback: "We’ll send a 6-character code to your inbox"
                ))
                    .font(.system(size: 14))
                    .foregroundColor(.white.opacity(0.72))
            }
        }
        .padding(.top, AppDesign.Spacing.xl)
        .padding(.bottom, AppDesign.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(
            heroGradient
                .padding(.bottom, -32)
                .ignoresSafeArea(.container, edges: .top)
        )
    }

    @EnvironmentObject private var appViewModel: AppViewModel

    private var backButton: some View {
        VStack {
            HStack {
                Button(action: onCancel) {
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

    private var emailSection: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            emailField
            sendButton

            if secondsRemaining > 0 {
                HStack(spacing: AppDesign.Spacing.xs) {
                    Image(systemName: "clock")
                    Text(appViewModel.localized(
                        "email_verification_resend_countdown",
                        fallback: "You can resend the email in"
                    ))
                    Text(formattedCountdown)
                        .monospacedDigit()
                        .fontWeight(.semibold)
                }
                .font(.system(size: 12))
                .foregroundColor(AppDesign.Colors.textSecondary)
                .transition(.opacity)
            }
        }
    }

    private var emailField: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
            Text(appViewModel.localized("auth_email_label"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(AppDesign.Colors.text)
                .opacity(0.45)

            HStack(spacing: AppDesign.Spacing.md) {
                Image(systemName: "envelope.fill")
                    .font(.system(size: 16))
                    .foregroundColor(AppDesign.Colors.textSecondary)
                    .frame(width: 20)

                TextField(
                    appViewModel.localized("auth_email_placeholder"),
                    text: .constant(email)
                )
                    .font(.system(size: 16))
                    .foregroundColor(AppDesign.Colors.text)
                    .keyboardType(.emailAddress)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .disabled(true)

                Spacer()
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.vertical, AppDesign.Spacing.lg)
            .background(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .fill(Color(.systemGray5))
            )
            .opacity(0.6)
        }
    }

    private var sendButton: some View {
        let isDisabled = isSending || secondsRemaining > 0

        return Button(action: handleSend) {
            ZStack {
                if isSending {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "paperplane.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(appViewModel.localized(
                            hasSentCode ? "email_verification_resend_button" : "email_verification_send_button",
                            fallback: hasSentCode ? "Resend email" : "Send verification email"
                        ))
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
                radius: 12,
                x: 0,
                y: 6
            )
        }
        .disabled(isDisabled)
        .animation(AppDesign.Animation.quick, value: isDisabled)
    }

    private var codeEntrySection: some View {
        VStack(spacing: AppDesign.Spacing.xl) {
            VStack(spacing: AppDesign.Spacing.xs) {
                Text(appViewModel.localized("email_verification_code_title", fallback: "Enter verification code"))
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(AppDesign.Colors.text)
                Text(appViewModel.localized(
                    "email_verification_code_instruction",
                    fallback: "Enter the 6-character code sent to your email address."
                ))
                    .font(.system(size: 14))
                    .foregroundColor(AppDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
            }

            OTPInputView(code: $otpCode, digitsOnly: false)

            verifyButton
        }
    }

    private var verifyButton: some View {
        let isDisabled = otpCode.count != 6 || isVerifying

        return Button(action: handleVerify) {
            ZStack {
                if isVerifying {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "checkmark.shield.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(appViewModel.localized("email_verification_confirm_button", fallback: "Verify email"))
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
                radius: 12,
                x: 0,
                y: 6
            )
        }
        .disabled(isDisabled)
        .animation(AppDesign.Animation.quick, value: isDisabled)
    }

    private var formattedCountdown: String {
        String(format: "%02d:%02d", secondsRemaining / 60, secondsRemaining % 60)
    }

    private func handleSend() {
        let hadAlreadySentCode = hasSentCode
        isSending = true
        otpCode = ""
        hasSentCode = true
        countdownDeadline = Date().addingTimeInterval(180)
        secondsRemaining = 180
        countdownID += 1

        Task {
            do {
                try await onSendCode()
            } catch {
                countdownDeadline = nil
                secondsRemaining = 0
                hasSentCode = hadAlreadySentCode
                showError(error.localizedDescription)
            }
            isSending = false
        }
    }

    private func handleVerify() {
        let code = otpCode
        guard code.count == 6 else { return }

        isVerifying = true

        Task { @MainActor in
            do {
                try await appViewModel.validateEmail(code: code)
                // A successful verification changes the root navigation state and
                // removes this view. Do not access its @State storage afterwards.
                return
            } catch {
                isVerifying = false
                showError(error.localizedDescription)
            }
        }
    }

    private func runCountdown() async {
        guard countdownID > 0 else { return }

        while !Task.isCancelled, let countdownDeadline {
            let remaining = max(0, Int(ceil(countdownDeadline.timeIntervalSinceNow)))
            secondsRemaining = remaining
            guard remaining > 0 else {
                self.countdownDeadline = nil
                return
            }

            try? await Task.sleep(for: .seconds(1))
        }
    }

    private func presentSignupSuccessIfNeeded(_ message: String?) {
        guard message != nil else {
            isShowingSignupSuccess = false
            return
        }

        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            isShowingSignupSuccess = true
        }
    }

    private func dismissSignupSuccess() {
        withAnimation(.spring(response: 0.36, dampingFraction: 0.86)) {
            isShowingSignupSuccess = false
        }
        onDismissSignupSuccess()
    }

    private func showError(_ message: String) {
        withAnimation(AppDesign.Animation.standard) {
            toastMessage = message
        }
        Task {
            try? await Task.sleep(for: .seconds(3))
            withAnimation(AppDesign.Animation.standard) {
                toastMessage = nil
            }
        }
    }
}

#Preview {
    EmailVerificationView(email: "test@gmail.com")
        .environmentObject(AppViewModel())
}
