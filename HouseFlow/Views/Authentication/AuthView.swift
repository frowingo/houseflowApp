import SwiftUI

/// Authentication screen with social login and email/password options
/// Refactored: Component'lere bölündü, Design System kullanıyor
struct AuthView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @FocusState private var focusedField: AuthField?
    
    var body: some View {
        ScrollView {
            VStack(spacing: AppDesign.Spacing.xxl) {
                headerSection
                formSection
                socialLoginSection
                actionButtonsSection
            }
        }
        .background(AppDesign.Colors.background)
        .navigationBarHidden(true)
        .dismissKeyboardOnTap()
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            appIcon
            titleSection
        }
        .padding(.top, AppDesign.Spacing.xl)
    }
    
    private var appIcon: some View {
        Image(systemName: "house.circle.fill")
            .font(.system(size: 48))
            .foregroundColor(AppDesign.Colors.primary)
    }
    
    private var titleSection: some View {
        VStack(spacing: AppDesign.Spacing.xs) {
            Text("Welcome Back!")
                .font(.system(size: 28, weight: .bold, design: .rounded))
            
            Text("Sign in to your HouseFlow account and manage your shared home effortlessly")
                .font(AppDesign.Typography.subheadline)
                .foregroundColor(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppDesign.Spacing.xxl)
        }
    }
    
    // MARK: - Form Section
    
    private var formSection: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            ModernTextField(
                title: "Name",
                text: $name,
                placeholder: "How to call you?",
                icon: "person.circle.fill",
                keyboardType: .default,
                focusedField: $focusedField,
                fieldType: .name
            )
            
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
            ) {
                authenticateWithSocial("Google")
            }
            
            SocialLoginButton(
                icon: "applelogo",
                name: "Apple",
                backgroundColor: .black,
                foregroundColor: .white
            ) {
                authenticateWithSocial("Apple")
            }
            
            SocialLoginButton(
                icon: "camera.fill",
                name: "Snapchat",
                backgroundColor: Color.yellow,
                foregroundColor: .black
            ) {
                authenticateWithSocial("Snapchat")
            }
        }
    }
    
    // MARK: - Action Buttons Section
    
    private var actionButtonsSection: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            signInButton
            demoModeButton
        }
        .padding(.horizontal, AppDesign.Spacing.xxl)
        .padding(.bottom, AppDesign.Spacing.xxl)
    }
    
    private var signInButton: some View {
        Button(action: handleSignIn) {
            HStack(spacing: AppDesign.Spacing.md) {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 20))
                Text("Sign In")
                    .font(AppDesign.Typography.headline)
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
            .shadow(
                color: AppDesign.Colors.primary.opacity(0.3),
                radius: 8,
                x: 0,
                y: 4
            )
        }
        .disabled(!isFormValid)
        .opacity(isFormValid ? 1.0 : 0.6)
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
    }
    
    // MARK: - Actions
    
    private func handleSignIn() {
        focusedField = nil
        withAnimation(AppDesign.Animation.standard) {
            appViewModel.authenticate()
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
        print("Authenticating with \(platform)")
        withAnimation(AppDesign.Animation.standard) {
            appViewModel.authenticate()
        }
    }
    
    private var isFormValid: Bool {
        !name.isEmpty && !email.isEmpty && !password.isEmpty
    }
}

#Preview {
    AuthView()
        .environmentObject(AppViewModel())
}
