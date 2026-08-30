import Foundation

final class AuthService {
    private let network: any NetworkServicing
    private let keychain: any KeychainStoring

    init(network: any NetworkServicing, keychain: any KeychainStoring) {
        self.network = network
        self.keychain = keychain
    }

    // MARK: - Signup

    /// POST auth/signup
    /// Stores the returned token in Keychain on success.
    func signup(
        email: String,
        password: String,
        firstName: String,
        lastName: String
    ) async throws -> AuthTokenResponse {
        let body = SignupRequest(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName
        )
        let response = try await network.request(
            path: "auth/signup",
            method: "POST",
            body: body,
            successType: AuthTokenResponse.self
        )
        keychain.authToken = response.token
        keychain.userEmail = email
        return response
    }

    // MARK: - Login

    /// POST auth/login
    /// Stores the returned token in Keychain on success.
    func login(email: String, password: String) async throws -> AuthTokenResponse {
        let body = LoginRequest(email: email, password: password)
        let response = try await network.request(
            path: "auth/login",
            method: "POST",
            body: body,
            successType: AuthTokenResponse.self
        )
        keychain.authToken = response.token
        keychain.userEmail = email
        return response
    }

    // MARK: - Forgot Password

    /// POST auth/forget
    func forgotPassword(email: String) async throws -> ForgotPasswordResponse {
        let body = ForgotPasswordRequest(email: email)
        return try await network.request(
            path: "auth/forget",
            method: "POST",
            body: body,
            successType: ForgotPasswordResponse.self
        )
    }

    // MARK: - Reset Password

    /// POST auth/reset
    func resetPassword(
        email: String,
        code: String,
        newPassword: String
    ) async throws -> MessageResponse {
        let body = ResetPasswordRequest(email: email, code: code, newPassword: newPassword)
        return try await network.request(
            path: "auth/reset",
            method: "POST",
            body: body,
            successType: MessageResponse.self
        )
    }

    // MARK: - Email Verification

    /// GET auth/validate-email — Bearer token only; sends a verification code.
    func sendEmailVerificationCode() async throws -> ValidateEmailResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("No token stored.")
        }
        return try await network.get(
            path: "auth/validate-email",
            queryItems: [],
            successType: ValidateEmailResponse.self,
            token: token
        )
    }

    /// POST auth/validate-email — Bearer token plus the six-character verification code.
    func validateEmail(code: String) async throws -> ValidateEmailResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("No token stored.")
        }
        return try await network.authenticatedRequest(
            path: "auth/validate-email",
            method: "POST",
            body: ValidateEmailRequest(code: code),
            successType: ValidateEmailResponse.self,
            token: token
        )
    }

    // MARK: - Is Authenticated

    /// GET auth/isAuth — Bearer token only, returns { "success": bool, "data": { ...user } }
    func isAuth() async throws -> IsAuthResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("No token stored.")
        }
        return try await network.get(
            path: "auth/isAuth",
            queryItems: [],
            successType: IsAuthResponse.self,
            token: token
        )
    }

    // MARK: - Helpers

    var isLoggedIn: Bool {
        keychain.authToken != nil
    }

    func logout() {
        keychain.authToken = nil
        keychain.userEmail = nil
    }
}
