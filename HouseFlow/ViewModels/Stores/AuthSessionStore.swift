import Foundation
import Combine

@MainActor
final class AuthSessionStore: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var authError: String?
    @Published var successToast: String?
    @Published private(set) var pendingEmailVerification: String?
    @Published private(set) var currentUserId: String?
    @Published private(set) var currentUserProfile: IsAuthUserData?

    private let keychain: any KeychainStoring
    private let authService: any AuthServicing
    private let userService: any UserServicing

    convenience init() {
        self.init(
            keychain: KeychainService.shared,
            authService: AuthService.shared,
            userService: UserService.shared
        )
    }

    init(
        keychain: any KeychainStoring,
        authService: any AuthServicing,
        userService: any UserServicing
    ) {
        self.keychain = keychain
        self.authService = authService
        self.userService = userService
        pendingEmailVerification = keychain.pendingEmailVerification
    }

    func login(email: String, password: String) async -> Bool {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        do {
            _ = try await authService.login(email: email, password: password)
            clearPendingEmailVerification()
            return true
        } catch {
            authError = error.localizedDescription
            return false
        }
    }

    func signup(email: String, password: String, firstName: String, lastName: String) async -> Bool {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        do {
            _ = try await authService.signup(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            requireEmailVerification(for: email)
            return true
        } catch {
            authError = error.localizedDescription
            return false
        }
    }

    func forgotPassword(email: String) async -> Bool {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        do {
            let response = try await authService.forgotPassword(email: email)
            return response.success
        } catch {
            authError = error.localizedDescription
            return false
        }
    }

    func resetPassword(email: String, code: String, newPassword: String) async -> Bool {
        isLoading = true
        authError = nil
        defer { isLoading = false }

        do {
            _ = try await authService.resetPassword(email: email, code: code, newPassword: newPassword)
            return true
        } catch {
            authError = error.localizedDescription
            return false
        }
    }

    func requestPasswordReset(email: String) async throws {
        _ = try await authService.forgotPassword(email: email)
    }

    func resetPasswordOrThrow(email: String, code: String, newPassword: String) async throws {
        _ = try await authService.resetPassword(email: email, code: code, newPassword: newPassword)
    }

    func sendEmailVerificationCode() async throws {
        let response = try await authService.sendEmailVerificationCode()
        guard response.success else {
            throw NetworkError.serverError("Verification email could not be sent.")
        }
    }

    func validateEmail(code: String) async throws {
        let response = try await authService.validateEmail(code: code)
        guard response.success else {
            throw NetworkError.serverError("The verification code is invalid.")
        }
    }

    func fetchAuthenticatedUser(invalidMessage: String = "Authenticated user could not be resolved.") async throws -> IsAuthUserData {
        let result = try await authService.isAuth()
        guard result.success, let profile = result.data else {
            throw NetworkError.serverError(invalidMessage)
        }
        return profile
    }

    func updateProfile(_ request: UpdateProfileRequest) async throws -> IsAuthUserData {
        guard let userId = currentUserId else {
            throw NetworkError.serverError("User not authenticated.")
        }
        let response = try await userService.updateProfile(userId: userId, request: request)
        guard response.success, let data = response.data else {
            throw NetworkError.serverError(response.error ?? "Update failed.")
        }
        return IsAuthUserData(
            birthDate: data.birthDate,
            createdOn: data.createdOn,
            email: data.email,
            firstName: data.firstName,
            houseIds: data.houseIds,
            id: data.id,
            imageUrl: data.imageUrl,
            isActive: data.isActive,
            isVerifyEmail: data.isVerifyEmail,
            isVerifyPhone: data.isVerifyPhone,
            language: data.language,
            lastLogin: data.lastLogin,
            lastName: data.lastName,
            phoneNumber: data.phoneNumber,
            updatedOn: data.updatedOn
        )
    }

    func fetchProfileImages(category: String) async throws -> GetImagesResponse {
        try await userService.getImages(category: category)
    }

    func logout() {
        authService.logout()
        clearPendingEmailVerification()
        isAuthenticated = false
        isLoading = false
        authError = nil
        successToast = nil
        clearUser()
    }

    func applyAuthenticatedUser(_ profile: IsAuthUserData) {
        keychain.userEmail = profile.email
        keychain.userFirstName = profile.firstName
        keychain.userLastName = profile.lastName
        currentUserId = profile.id
        currentUserProfile = profile
        currentUser = User(
            firstName: profile.firstName,
            lastName: profile.lastName,
            apiId: profile.id,
            points: 0,
            imageUrl: profile.imageUrl.isEmpty ? nil : profile.imageUrl
        )
    }

    func clearUser() {
        currentUser = nil
        currentUserId = nil
        currentUserProfile = nil
    }

    func requireEmailVerification(for email: String) {
        let normalizedEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)
        pendingEmailVerification = normalizedEmail
        keychain.pendingEmailVerification = normalizedEmail
    }

    func clearPendingEmailVerification() {
        pendingEmailVerification = nil
        keychain.pendingEmailVerification = nil
    }
}
