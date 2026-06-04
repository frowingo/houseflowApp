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

struct ForgotPasswordResponse: Decodable {
    let success: Bool
}

struct MessageResponse: Decodable {
    let message: String
}

struct IsAuthResponse: Decodable {
    let data: IsAuthUserData?
    let success: Bool
}

struct IsAuthUserData: Decodable {
    let age: Int
    let createdOn: String
    let email: String
    let firstName: String
    let houseIds: [String]
    let id: String
    let imageUrl: String
    let isActive: Bool
    let isVerifyEmail: Bool
    let isVerifyPhone: Bool
    let lastLogin: String
    let lastName: String
    let phoneNumber: String
    let updatedOn: String

    var fullName: String { "\(firstName) \(lastName)" }
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

// MARK: - Update User Profile

struct UpdateProfileRequest: Encodable {
    let imageUrl: String?
    let age: Int?
    let firstName: String?
    let isVerifyEmail: Bool?
    let isVerifyPhone: Bool?
    let lastName: String?
    let phoneNumber: String?
}

// PUT user/profile returns the updated user object directly (flat, no wrapper)
typealias UpdateProfileResponse = IsAuthUserData
