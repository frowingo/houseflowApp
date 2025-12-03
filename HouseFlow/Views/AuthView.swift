import SwiftUI

struct AuthView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var email = ""
    @State private var password = ""
    @State private var phoneNumber = ""
    @FocusState private var focusedField: AuthField?
    
    enum AuthField {
        case email, password, phone, name
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                VStack(spacing: 12) {
                    Image(systemName: "house.circle.fill")
                        .font(.system(size: 48))
                        .foregroundColor(.blue)
                    
                    VStack(spacing: 6) {
                        Text("Welcome Back!")
                            .font(.system(size: 28, weight: .bold, design: .rounded))
                        
                        Text("Sign in to your HouseFlow account and manage your shared home effortlessly")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
                .padding(.top, 20)
                
                // Form
                VStack(spacing: 15) {
                    // Name Field
                    ModernTextField(
                        title: "Name",
                        text: $email,
                        placeholder: "How to call you?",
                        icon: "person.circle.fill",
                        keyboardType: .emailAddress,
                        focusedField: $focusedField,
                        fieldType: .name
                    )
                    // Email Field
                    ModernTextField(
                        title: "Email Address",
                        text: $email,
                        placeholder: "your.email@example.com",
                        icon: "envelope.fill",
                        keyboardType: .emailAddress,
                        focusedField: $focusedField,
                        fieldType: .email
                    )
                    
                    // Password Field
                    ModernSecureField(
                        title: "Password",
                        text: $password,
                        placeholder: "Enter your password",
                        icon: "lock.fill",
                        focusedField: $focusedField,
                        fieldType: .password
                    )
                }
                .padding(.horizontal, 20)
                
                // Social Login Section
                VStack(spacing: 12) {
                    HStack {
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.secondary.opacity(0.3))
                        
                        Text("or continue with")
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 16)
                        
                        Rectangle()
                            .frame(height: 1)
                            .foregroundColor(.secondary.opacity(0.3))
                    }
                    
                    // Social Login Buttons
                    HStack(spacing: 16) {
                        SocialLoginButton(
                            icon: "globe",
                            name: "Google",
                            backgroundColor: .white,
                            foregroundColor: .black,
                            borderColor: .gray.opacity(0.3)
                        ) {
                            // Google login action
                            authenticateWithSocial("Google")
                        }
                        
                        SocialLoginButton(
                            icon: "applelogo",
                            name: "Apple",
                            backgroundColor: .black,
                            foregroundColor: .white
                        ) {
                            // Apple login action
                            authenticateWithSocial("Apple")
                        }
                        
                        SocialLoginButton(
                            icon: "camera.fill",
                            name: "Snapchat",
                            backgroundColor: Color.yellow,
                            foregroundColor: .black
                        ) {
                            // Snapchat login action
                            authenticateWithSocial("Snapchat")
                        }
                    }
                }
                .padding(.horizontal, 24)
            
                
                // Main Login Buttons
                VStack(spacing: 12) {
                    Button(action: {
                        focusedField = nil
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appViewModel.authenticate()
                        }
                    }) {
                        HStack(spacing: 12) {
                            Image(systemName: "person.circle.fill")
                                .font(.system(size: 20))
                            Text("Sign In")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(
                            LinearGradient(
                                colors: [Color.blue, Color.blue.opacity(0.8)],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .cornerRadius(16)
                        .shadow(color: Color.blue.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(email.isEmpty || password.isEmpty || phoneNumber.isEmpty)
                    .opacity((email.isEmpty || password.isEmpty || phoneNumber.isEmpty) ? 0.6 : 1.0)
                    
                    Button(action: {
                        focusedField = nil
                        withAnimation(.easeInOut(duration: 0.3)) {
                            appViewModel.authenticate()
                        }
                    }) {
                        HStack(spacing: 10) {
                            Image(systemName: "play.circle.fill")
                                .font(.system(size: 19))
                            Text("Demo Mode")
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 30)
            }
        }
        .background(Color(.systemBackground))
        .navigationBarHidden(true)
        .dismissKeyboardOnTap()
    }
    
    private func authenticateWithSocial(_ platform: String) {
        focusedField = nil
        // Demo: Show which platform was selected
        print("Authenticating with \(platform)")
        withAnimation(.easeInOut(duration: 0.3)) {
            appViewModel.authenticate()
        }
    }
}

struct ModernTextField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    let keyboardType: UIKeyboardType
    @FocusState.Binding var focusedField: AuthView.AuthField?
    let fieldType: AuthView.AuthField
    
    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(focusedField == fieldType ? .blue : .secondary)
                    .frame(width: 20)
                
                TextField(placeholder, text: $text)
                    .font(.system(size: 16))
                    .textInputAutocapitalization(fieldType == .email ? .never : .none)
                    .keyboardType(keyboardType)
                    .focused($focusedField, equals: fieldType)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                focusedField == fieldType ? Color.blue : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: focusedField == fieldType)
        }
    }
}

struct ModernSecureField: View {
    let title: String
    @Binding var text: String
    let placeholder: String
    let icon: String
    @FocusState.Binding var focusedField: AuthView.AuthField?
    let fieldType: AuthView.AuthField
    @State private var isSecure = true
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(focusedField == fieldType ? .blue : .secondary)
                    .frame(width: 20)
                
                if isSecure {
                    SecureField(placeholder, text: $text)
                        .font(.system(size: 16))
                        .focused($focusedField, equals: fieldType)
                } else {
                    TextField(placeholder, text: $text)
                        .font(.system(size: 16))
                        .focused($focusedField, equals: fieldType)
                        .autocorrectionDisabled()
                }
                
                Button(action: {
                    isSecure.toggle()
                }) {
                    Image(systemName: isSecure ? "eye" : "eye.slash")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                focusedField == fieldType ? Color.blue : Color.clear,
                                lineWidth: 2
                            )
                    )
            )
            .animation(.easeInOut(duration: 0.2), value: focusedField == fieldType)
        }
    }
}

struct SocialLoginButton: View {
    let icon: String
    let name: String
    let backgroundColor: Color
    let foregroundColor: Color
    let borderColor: Color?
    let action: () -> Void
    
    init(
        icon: String,
        name: String,
        backgroundColor: Color,
        foregroundColor: Color,
        borderColor: Color? = nil,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.name = name
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.borderColor = borderColor
        self.action = action
    }
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(foregroundColor)
                
                Text(name)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(foregroundColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(borderColor ?? Color.clear, lineWidth: 1)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    AuthView()
        .environmentObject(AppViewModel())
}
