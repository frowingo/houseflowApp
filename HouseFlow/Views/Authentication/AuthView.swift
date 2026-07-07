import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @FocusState private var focusedField: AuthField?

    @State private var isSignUp = false
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""
    @State private var showForgotPassword = false

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .bottom) {
            heroGradient.ignoresSafeArea()

            VStack(spacing: 0) {
                heroSection

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppDesign.Spacing.xxl) {
                        modeSwitcher
                        formFields
                        if let error = appViewModel.authError {
                            errorBanner(message: error)
                        }
                        primaryButton
                        dividerRow
                        socialRow
                    }
                    .padding(.horizontal, AppDesign.Spacing.xxl)
                    .padding(.top, AppDesign.Spacing.xxxl)
                    .padding(.bottom, 48)
                }
                .frame(maxHeight: .infinity)
                .background(Color(.systemBackground))
                .clipShape(UnevenRoundedRectangle(topLeadingRadius: 32, topTrailingRadius: 32))
            }
            .ignoresSafeArea(.container, edges: .bottom)

            // Toast
            if let msg = appViewModel.successToast {
                toastBanner(message: msg)
                    .padding(.horizontal, AppDesign.Spacing.xxl)
                    .padding(.bottom, 36)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(10)
            }
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: appViewModel.successToast)
        .dismissKeyboardOnTap()
        .fullScreenCover(isPresented: $showForgotPassword) {
            ForgotPasswordView()
        }
        .onChange(of: isSignUp) { _ in
            appViewModel.authError = nil
            firstName = ""; lastName = ""; email = ""; password = ""
        }
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
        VStack(spacing: AppDesign.Spacing.lg) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.18))
                    .frame(width: 84, height: 84)
                Circle()
                    .fill(Color.white.opacity(0.10))
                    .frame(width: 104, height: 104)
                Image(systemName: "house.fill")
                    .font(.system(size: 36, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(spacing: AppDesign.Spacing.xs) {
                Text(appViewModel.localized("app_name"))
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                Text(appViewModel.localized("auth_tagline"))
                    .font(.system(size: 15))
                    .foregroundColor(.white.opacity(0.72))
            }
        }
        .padding(.top, AppDesign.Spacing.xxxl)
        .padding(.bottom, AppDesign.Spacing.huge)
    }

    // MARK: - Mode Switcher

    private var modeSwitcher: some View {
        HStack(spacing: 4) {
            modeTab(title: appViewModel.localized("auth_sign_in_tab"), selected: !isSignUp) { isSignUp = false }
            modeTab(title: appViewModel.localized("auth_sign_up_tab"), selected: isSignUp)  { isSignUp = true  }
        }
        .padding(4)
        .background(Color(.systemGray6))
        .cornerRadius(AppDesign.CornerRadius.lg)
    }

    private func modeTab(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: { withAnimation(AppDesign.Animation.standard) { action() } }) {
            Text(title)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(selected ? AppDesign.Colors.primary : AppDesign.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 36)
                .background(
                    Group {
                        if selected {
                            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                .fill(Color(.systemBackground))
                                .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
                        }
                    }
                )
        }
    }

    // MARK: - Form Fields

    @ViewBuilder
    private var formFields: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            if isSignUp {
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
                .transition(.asymmetric(
                    insertion: .push(from: .top).combined(with: .opacity),
                    removal: .push(from: .bottom).combined(with: .opacity)
                ))
            }

            ModernTextField(
                title: appViewModel.localized("auth_email_label"),
                text: $email,
                placeholder: appViewModel.localized("auth_email_placeholder"),
                icon: "envelope.fill",
                keyboardType: .emailAddress,
                focusedField: $focusedField,
                fieldType: .email
            )

            ModernSecureField(
                title: appViewModel.localized("auth_password_label"),
                text: $password,
                placeholder: appViewModel.localized("auth_password_placeholder"),
                icon: "lock.fill",
                focusedField: $focusedField,
                fieldType: .password
            )

            if !isSignUp {
                HStack {
                    Spacer()
                    Button {
                        showForgotPassword = true
                    } label: {
                        Text(appViewModel.localized("auth_forgot_password_button"))
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(AppDesign.Colors.primary)
                }
                .transition(.opacity)
            }
        }
        .animation(AppDesign.Animation.standard, value: isSignUp)
    }

    // MARK: - Primary Button

    private var primaryButton: some View {
        Button(action: handlePrimaryAction) {
            ZStack {
                if appViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                } else {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: isSignUp ? "person.badge.plus.fill" : "arrow.right.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                        Text(appViewModel.localized(isSignUp ? "auth_create_account_button" : "auth_sign_in_button"))
                            .font(.system(size: 17, weight: .bold))
                    }
                    .foregroundColor(.white)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(
                Group {
                    if isFormValid && !appViewModel.isLoading {
                        heroGradient
                    } else {
                        LinearGradient(colors: [Color(.systemGray4)], startPoint: .leading, endPoint: .trailing)
                    }
                }
            )
            .cornerRadius(AppDesign.CornerRadius.xl)
            .shadow(
                color: isFormValid ? AppDesign.Colors.primary.opacity(0.38) : .clear,
                radius: 12, x: 0, y: 6
            )
        }
        .disabled(!isFormValid || appViewModel.isLoading)
        .animation(AppDesign.Animation.quick, value: isFormValid)
    }

    // MARK: - Divider

    private var dividerRow: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            Rectangle().frame(height: 1).foregroundColor(Color(.systemGray5))
            Text(appViewModel.localized("auth_divider_or"))
                .font(AppDesign.Typography.caption)
                .foregroundColor(AppDesign.Colors.textSecondary)
            Rectangle().frame(height: 1).foregroundColor(Color(.systemGray5))
        }
    }

    // MARK: - Social Login

    private var socialRow: some View {
        HStack(spacing: AppDesign.Spacing.lg) {
            SocialLoginButton(
                name: appViewModel.localized("auth_google_button"),
                backgroundColor: .white,
                foregroundColor: .black,
                borderColor: Color(.systemGray4),
                action: { authenticateWithSocial("Google") }
            ) {
                GoogleLogoView(size: 22)
            }

            SocialLoginButton(
                name: appViewModel.localized("auth_apple_button"),
                backgroundColor: .black,
                foregroundColor: .white,
                action: { authenticateWithSocial("Apple") }
            ) {
                Image(systemName: "applelogo")
                    .font(.system(size: 20))
                    .foregroundColor(.white)
            }

            SocialLoginButton(
                name: appViewModel.localized("auth_snapchat_button"),
                backgroundColor: Color.yellow,
                foregroundColor: .black,
                action: { authenticateWithSocial("Snapchat") }
            ) {
                SnapchatGhostView(size: 20, color: .black)
            }
        }
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(AppDesign.Colors.error)
            Text(message)
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.error)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(AppDesign.Spacing.md)
        .background(AppDesign.Colors.error.opacity(0.08))
        .cornerRadius(AppDesign.CornerRadius.md)
    }

    // MARK: - Toast

    private func toastBanner(message: String) -> some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.white.opacity(0.25))
                    .frame(width: 36, height: 36)
                Image(systemName: "checkmark")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
            }
            Text(message)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
            Spacer()
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, AppDesign.Spacing.md)
        .background(
            LinearGradient(
                colors: [Color(red: 0.12, green: 0.72, blue: 0.46), Color(red: 0.08, green: 0.58, blue: 0.52)],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .cornerRadius(AppDesign.CornerRadius.xl)
        .shadow(color: Color.black.opacity(0.18), radius: 14, x: 0, y: 6)
    }

    // MARK: - Actions

    private func handlePrimaryAction() {
        focusedField = nil
        Task {
            if isSignUp {
                await appViewModel.signup(
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName
                )
            } else {
                await appViewModel.login(email: email, password: password)
            }
        }
    }

    private func authenticateWithSocial(_ platform: String) {
        focusedField = nil
        // Social auth — to be implemented
    }

    private var isFormValid: Bool {
        if isSignUp {
            return !firstName.isEmpty && !lastName.isEmpty && !email.isEmpty && !password.isEmpty
        }
        return !email.isEmpty && !password.isEmpty
    }
}

#Preview {
    AuthView()
        .environmentObject(AppViewModel())
}
