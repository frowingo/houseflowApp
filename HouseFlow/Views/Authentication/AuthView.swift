import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @FocusState private var focusedField: AuthField?

    // MARK: - Mode

    @State private var isSignUp = false

    // MARK: - Form fields

    @State private var firstName = ""
    @State private var lastName = ""
    @State private var email = ""
    @State private var password = ""

    var body: some View {
        ScrollView {
            VStack(spacing: AppDesign.Spacing.xxl) {
                headerSection
                modeSwitcher
                formSection
                if let error = appViewModel.authError {
                    errorBanner(message: error)
                }
                socialLoginSection
                actionButtonsSection
            }
        }
        .background(AppDesign.Colors.background)
        .navigationBarHidden(true)
        .dismissKeyboardOnTap()
        .onChange(of: isSignUp) { _ in
            appViewModel.authError = nil
            firstName = ""
            lastName = ""
            email = ""
            password = ""
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            Image(systemName: "house.circle.fill")
                .font(.system(size: 48))
                .foregroundColor(AppDesign.Colors.primary)

            VStack(spacing: AppDesign.Spacing.xs) {
                Text(isSignUp ? "Create Account" : "Welcome Back!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text(isSignUp
                     ? "Join HouseFlow and start managing your shared home"
                     : "Sign in to your HouseFlow account and manage your shared home effortlessly")
                    .font(AppDesign.Typography.subheadline)
                    .foregroundColor(AppDesign.Colors.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppDesign.Spacing.xxl)
            }
        }
        .padding(.top, AppDesign.Spacing.xl)
    }

    // MARK: - Mode Switcher

    private var modeSwitcher: some View {
        HStack(spacing: 0) {
            modeTab(title: "Sign In", selected: !isSignUp) { isSignUp = false }
            modeTab(title: "Sign Up", selected: isSignUp)  { isSignUp = true  }
        }
        .background(AppDesign.Colors.surface)
        .cornerRadius(AppDesign.CornerRadius.md)
        .padding(.horizontal, AppDesign.Spacing.xxl)
    }

    private func modeTab(title: String, selected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppDesign.Typography.headline)
                .foregroundColor(selected ? .white : AppDesign.Colors.textSecondary)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(selected ? AppDesign.Colors.primary : Color.clear)
                .cornerRadius(AppDesign.CornerRadius.md)
        }
    }

    // MARK: - Form Section

    private var formSection: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            if isSignUp {
                ModernTextField(
                    title: "First Name",
                    text: $firstName,
                    placeholder: "Your first name",
                    icon: "person.circle.fill",
                    keyboardType: .default,
                    focusedField: $focusedField,
                    fieldType: .name
                )

                ModernTextField(
                    title: "Last Name",
                    text: $lastName,
                    placeholder: "Your last name",
                    icon: "person.circle.fill",
                    keyboardType: .default,
                    focusedField: $focusedField,
                    fieldType: .name
                )
            }

            ModernTextField(
                title: "Email Address",
                text: $email,
                placeholder: "your.email@example.com",
                icon: "envelope.fill",
                keyboardType: .emailAddress,
                focusedField: $focusedField,
                fieldType: .email
            )

            ModernSecureField(
                title: "Password",
                text: $password,
                placeholder: "Enter your password",
                icon: "lock.fill",
                focusedField: $focusedField,
                fieldType: .password
            )
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
    }

    // MARK: - Error Banner

    private func errorBanner(message: String) -> some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.red)
            Text(message)
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(.red)
                .multilineTextAlignment(.leading)
            Spacer()
        }
        .padding(AppDesign.Spacing.md)
        .background(Color.red.opacity(0.1))
        .cornerRadius(AppDesign.CornerRadius.md)
        .padding(.horizontal, AppDesign.Spacing.xl)
    }

    // MARK: - Social Login Section

    private var socialLoginSection: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            dividerWithText
            socialButtonsRow
        }
        .padding(.horizontal, AppDesign.Spacing.xxl)
    }

    private var dividerWithText: some View {
        HStack {
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppDesign.Colors.textSecondary.opacity(0.3))
            Text("or continue with")
                .font(AppDesign.Typography.caption)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .padding(.horizontal, AppDesign.Spacing.lg)
            Rectangle()
                .frame(height: 1)
                .foregroundColor(AppDesign.Colors.textSecondary.opacity(0.3))
        }
    }

    private var socialButtonsRow: some View {
        HStack(spacing: AppDesign.Spacing.lg) {
            SocialLoginButton(
                icon: "globe",
                name: "Google",
                backgroundColor: .white,
                foregroundColor: .black,
                borderColor: .gray.opacity(0.3)
            ) { authenticateWithSocial("Google") }

            SocialLoginButton(
                icon: "applelogo",
                name: "Apple",
                backgroundColor: .black,
                foregroundColor: .white
            ) { authenticateWithSocial("Apple") }

            SocialLoginButton(
                icon: "camera.fill",
                name: "Snapchat",
                backgroundColor: Color.yellow,
                foregroundColor: .black
            ) { authenticateWithSocial("Snapchat") }
        }
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            primaryButton
            demoModeButton
        }
        .padding(.horizontal, AppDesign.Spacing.xxl)
        .padding(.bottom, AppDesign.Spacing.xxl)
    }

    private var primaryButton: some View {
        Button(action: handlePrimaryAction) {
            HStack(spacing: AppDesign.Spacing.md) {
                if appViewModel.isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.85)
                } else {
                    Image(systemName: isSignUp ? "person.badge.plus" : "person.circle.fill")
                        .font(.system(size: 20))
                    Text(isSignUp ? "Create Account" : "Sign In")
                        .font(AppDesign.Typography.headline)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(
                LinearGradient(
                    colors: [AppDesign.Colors.primary, AppDesign.Colors.primary.opacity(0.8)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(AppDesign.CornerRadius.lg)
            .shadow(color: AppDesign.Colors.primary.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(!isFormValid || appViewModel.isLoading)
        .opacity(isFormValid && !appViewModel.isLoading ? 1.0 : 0.6)
    }

    private var demoModeButton: some View {
        Button(action: handleDemoMode) {
            HStack(spacing: AppDesign.Spacing.sm) {
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 19))
                Text("Demo Mode")
                    .font(AppDesign.Typography.headline)
            }
            .foregroundColor(AppDesign.Colors.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 48)
            .background(AppDesign.Colors.primary.opacity(0.1))
            .cornerRadius(AppDesign.CornerRadius.md)
        }
        .disabled(appViewModel.isLoading)
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

    private func handleDemoMode() {
        focusedField = nil
        withAnimation(AppDesign.Animation.standard) {
            appViewModel.authenticate()
        }
    }

    private func authenticateWithSocial(_ platform: String) {
        focusedField = nil
        // Social auth — to be implemented
        withAnimation(AppDesign.Animation.standard) {
            appViewModel.authenticate()
        }
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
