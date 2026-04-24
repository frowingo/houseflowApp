import Foundation

// MARK: - Signup

struct SignupRequest: Encodable {
    let email: String
    let password: String
    let firstName: String
    let lastName: String
}

// MARK: - Login

struct LoginRequest: Encodable {
    let email: String
    let password: String
}

// MARK: - Forgot Password

struct ForgotPasswordRequest: Encodable {
    let email: String
}

// MARK: - Reset Password

struct ResetPasswordRequest: Encodable {
    let email: String
    let code: String
    let newPassword: String
}

// MARK: - Success Responses

struct AuthTokenResponse: Decodable {
    let token: String
}

struct MessageResponse: Decodable {
    let message: String
}
