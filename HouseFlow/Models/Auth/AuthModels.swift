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

struct IsAuthResponse: Decodable {
    let success: Bool
}

// MARK: - User Profile

struct UserProfileResponse: Decodable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let imageUrl: String
    let age: Int
    let role: Int
    let isActive: Bool
    let isVerifyEmail: Bool
    let isVerifyPhone: Bool
    let phoneNumber: String
    let houseIds: [String]
    let failedLoginAttempts: Int
    let createdOn: String
    let updatedOn: String
    let lastLogin: String

    var fullName: String { "\(firstName) \(lastName)" }
}
