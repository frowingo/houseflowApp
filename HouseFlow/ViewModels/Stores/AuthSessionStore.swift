import Foundation
import Combine
import HouseFlowCore

@MainActor
final class AuthSessionStore: ObservableObject {
    @Published var isAuthenticated = false
    @Published var currentUser: User?
    @Published var isLoading = false
    @Published var authError: String?
    /// Neutral notice, e.g. a sign-in method that is not set up in this build.
    @Published var authInfo: String?
    /// Set while a provider that gave no email waits for the user to verify one. Memory only.
    @Published var socialPending: SocialPendingRegistration?
    @Published private(set) var successToast: String?
    @Published private(set) var pendingEmailVerification: String?
    @Published private(set) var currentUserId: String?
    @Published internal(set) var currentUserProfile: IsAuthUserData?

    private let keychain: any KeychainStoring
    private let authService: any AuthServicing
    private let userService: any UserServicing
    private let sessionRestorer: (any SessionRestoring)?
    let socialAuthService: (any SocialAuthServicing)?
    let socialCredentials: (any SocialCredentialProviding)?
    let socialConfig: SocialAuthConfig

    init(
        keychain: any KeychainStoring,
        authService: any AuthServicing,
        userService: any UserServicing,
        sessionRestorer: (any SessionRestoring)? = nil,
        socialAuthService: (any SocialAuthServicing)? = nil,
        socialCredentials: (any SocialCredentialProviding)? = nil,
        socialConfig: SocialAuthConfig = SocialAuthConfig(enabledProviders: [])
    ) {
        self.socialAuthService = socialAuthService
        self.socialCredentials = socialCredentials
        self.socialConfig = socialConfig
        self.keychain = keychain
        self.authService = authService
        self.userService = userService
        self.sessionRestorer = sessionRestorer
        pendingEmailVerification = keychain.pendingEmailVerification
    }

    func login(email: String, password: String) async -> Bool {
        isLoading = true
        authError = nil
        authInfo = nil
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
        authInfo = nil
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

    func restoreAuthenticatedUser(invalidMessage: String) async throws -> IsAuthUserData {
        if let sessionRestorer {
            return try await sessionRestorer.restoreProfile(invalidMessage: invalidMessage)
        }
        return try await fetchAuthenticatedUser(invalidMessage: invalidMessage)
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
            houseList: currentUserProfile?.houseList ?? [],
            id: data.id,
            imageUrl: data.imageUrl,
            isActive: data.isActive,
            isVerifyEmail: data.isVerifyEmail,
            isVerifyPhone: data.isVerifyPhone,
            language: data.language,
            lastLogin: data.lastLogin,
            lastName: data.lastName,
            phoneNumber: data.phoneNumber,
            updatedOn: data.updatedOn,
            signUpProvider: currentUserProfile?.signUpProvider,
            linkedProviders: currentUserProfile?.linkedProviders,
            hasPassword: currentUserProfile?.hasPassword
        )
    }

    func addOrUpdateHouse(_ house: HouseResponse) {
        guard var profile = currentUserProfile else { return }

        let summary = AuthHouseSummary(
            houseId: house.id,
            houseName: house.name,
            houseProfile: house.profileImage
        )
        if let index = profile.houseList.firstIndex(where: { $0.houseId == house.id }) {
            profile.houseList[index] = summary
        } else {
            profile.houseList.append(summary)
        }
        currentUserProfile = profile
    }

    func updateHouseSummary(houseId: String, name: String, profileImage: String) {
        guard var profile = currentUserProfile,
              let index = profile.houseList.firstIndex(where: { $0.houseId == houseId }) else {
            return
        }
        profile.houseList[index] = AuthHouseSummary(
            houseId: houseId,
            houseName: name,
            houseProfile: profileImage
        )
        currentUserProfile = profile
    }

    func removeHouseSummary(houseId: String) {
        guard var profile = currentUserProfile else { return }
        profile.houseList.removeAll { $0.houseId == houseId }
        currentUserProfile = profile
    }

    func fetchProfileImages(category: String) async throws -> GetImagesResponse {
        try await userService.getImages(category: category)
    }

    func logout() {
        socialCredentials?.signOutAll()
        socialPending = nil
        authService.logout()
        clearPendingEmailVerification()
        isAuthenticated = false
        isLoading = false
        authError = nil
        authInfo = nil
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

    func clearFeedback() {
        authError = nil
        authInfo = nil
        successToast = nil
    }
}
