import SwiftUI

/// Shown when a provider (Snapchat, Facebook without email permission) gave no email: the user
/// enters one, receives a code, and the account is only created once the code is verified.
/// The pending token lives in `AuthSessionStore` memory only and is never persisted.
struct SocialEmailCompletionView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var appViewModel: AppViewModel
    @FocusState private var focusedField: AuthField?

    private enum Step { case email, code }

    @State private var step: Step = .email
    @State private var email = ""
    @State private var code = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var isWorking = false
    @State private var errorMessage: String?
    @State private var didSeedNames = false

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            ScrollView {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.xl) {
                    header
                    if step == .email { emailStep } else { codeStep }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(AppDesign.Typography.subheadline)
                            .foregroundColor(AppDesign.Colors.error)
                            .accessibilityIdentifier("socialEmailError")
                    }
                    primaryButton
                    secondaryButtons
                }
                .padding(AppDesign.Spacing.xxl)
            }
        }
        .dismissKeyboardOnTap()
        .onAppear(perform: seedNames)
    }

    // MARK: - Sections

    private var header: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            Text(appViewModel.social("social_email_title", tr: "Emailini doğrula", en: "Verify your email"))
                .font(AppDesign.Typography.title2)
            Text(step == .email
                 ? appViewModel.social("social_email_subtitle",
                                       tr: "Hesabını açmak için bir email adresine ihtiyacımız var. Sana bir kod göndereceğiz.",
                                       en: "We need an email address to create your account. We'll send you a code.")
                 : appViewModel.social("social_code_subtitle",
                                       tr: "\(email) adresine gönderilen 6 karakterlik kodu gir.",
                                       en: "Enter the 6-character code sent to \(email)."))
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.textSecondary)
        }
    }

    private var emailStep: some View {
        ModernTextField(
            title: appViewModel.localized("auth_email_label"),
            text: $email,
            placeholder: appViewModel.localized("auth_email_placeholder"),
            icon: "envelope.fill",
            keyboardType: .emailAddress,
            focusedField: $focusedField,
            fieldType: .email
        )
    }

    private var codeStep: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            OTPInputView(code: $code, automaticallyFocus: true, onSubmit: { Task { await submit() } })
            HStack(spacing: AppDesign.Spacing.md) {
                ModernTextField(
                    title: appViewModel.localized("auth_first_name_label"),
                    text: $firstName,
                    placeholder: appViewModel.localized("auth_first_name_placeholder"),
                    icon: "person.fill",
                    keyboardType: .default,
                    focusedField: $focusedField,
                    fieldType: .firstName
                )
                ModernTextField(
                    title: appViewModel.localized("auth_last_name_label"),
                    text: $lastName,
                    placeholder: appViewModel.localized("auth_last_name_placeholder"),
                    icon: "person.fill",
                    keyboardType: .default,
                    focusedField: $focusedField,
                    fieldType: .lastName
                )
            }
        }
    }

    private var primaryButton: some View {
        Button { Task { await submit() } } label: {
            ZStack {
                if isWorking {
                    ProgressView().progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    Text(step == .email
                         ? appViewModel.social("social_email_send", tr: "Kod gönder", en: "Send code")
                         : appViewModel.social("social_code_confirm", tr: "Hesabı oluştur", en: "Create account"))
                        .font(.system(size: 17, weight: .bold))
                        .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(canSubmit ? AnyShapeStyle(FausBrand.buttonGradient) : AnyShapeStyle(Color(.systemGray4)))
            .cornerRadius(AppDesign.CornerRadius.xl)
        }
        .disabled(!canSubmit || isWorking)
    }

    private var secondaryButtons: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            if step == .code {
                Button(appViewModel.social("social_code_resend", tr: "Tekrar gönder", en: "Resend code")) {
                    Task { await sendCode(advance: false) }
                }
                .disabled(isWorking)
            }
            Button(appViewModel.localized("common_cancel")) {
                appViewModel.socialAuthStore.cancelSocialPending()
                dismiss()
            }
            .foregroundColor(AppDesign.Colors.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Actions

    private var canSubmit: Bool {
        switch step {
        case .email: return email.contains("@") && !email.trimmingCharacters(in: .whitespaces).isEmpty
        case .code: return code.count == 6
        }
    }

    private func seedNames() {
        guard !didSeedNames, let pending = appViewModel.socialAuthStore.socialPending else { return }
        didSeedNames = true
        firstName = pending.firstName
        lastName = pending.lastName
    }

    private func submit() async {
        guard canSubmit, !isWorking else { return }
        focusedField = nil
        if step == .email {
            await sendCode(advance: true)
        } else {
            await complete()
        }
    }

    private func sendCode(advance: Bool) async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await appViewModel.socialAuthStore.requestSocialEmailCode(email: email)
            if advance { step = .code }
        } catch {
            handle(error)
        }
    }

    private func complete() async {
        isWorking = true
        errorMessage = nil
        defer { isWorking = false }
        do {
            try await appViewModel.completeSocialSignUp(
                email: email, code: code, firstName: firstName, lastName: lastName
            )
            dismiss()
        } catch {
            handle(error)
        }
    }

    /// 401: the pending token expired, so the provider sign-in has to start again.
    /// 409: the email is taken, so ask for another one. 400 and the rest: show the message.
    private func handle(_ error: SocialStepError) {
        errorMessage = error.message
        switch error.statusCode {
        case 401:
            appViewModel.socialAuthStore.authError = error.message
            appViewModel.socialAuthStore.cancelSocialPending()
            dismiss()
        case 409:
            step = .email
            code = ""
        default:
            break
        }
    }
}
