import Foundation
import Combine
import HouseFlowCore

@MainActor
final class AppSessionCoordinator: ObservableObject {
    @Published private(set) var signupSuccessMessage: String?

    private let keychain: any KeychainStoring
    private let authStore: AuthSessionStore
    private let houseStore: HouseSessionStore
    private let localizationStore: LocalizationStore
    private let toastStore: ToastStore
    private let router: AppRouter

    private var authenticationFlowID = UUID()
    private var backgroundedAt: Date?
    private let backgroundRefreshThreshold: TimeInterval
    private let authenticationSettleDelay: Duration

    init(
        keychain: any KeychainStoring,
        authStore: AuthSessionStore,
        houseStore: HouseSessionStore,
        localizationStore: LocalizationStore,
        toastStore: ToastStore,
        router: AppRouter,
        backgroundRefreshThreshold: TimeInterval = 15 * 60,
        authenticationSettleDelay: Duration = .milliseconds(600)
    ) {
        self.keychain = keychain
        self.authStore = authStore
        self.houseStore = houseStore
        self.localizationStore = localizationStore
        self.toastStore = toastStore
        self.router = router
        self.backgroundRefreshThreshold = backgroundRefreshThreshold
        self.authenticationSettleDelay = authenticationSettleDelay
    }

    func completeOnboarding() {
        let profileNeedsBirthday = authStore.currentUserProfile.map {
            !authStore.isAuthenticated && needsBirthdaySetup($0)
        } ?? false
        router.completeOnboarding(needsBirthdaySetup: profileNeedsBirthday)
    }

    func handleBackground() {
        backgroundedAt = Date()
    }

    func handleForeground() async {
        localizationStore.refreshIfNeeded()

        guard let backgroundedAt else {
            return
        }
        let elapsed = Date().timeIntervalSince(backgroundedAt)
        self.backgroundedAt = nil
        if elapsed >= backgroundRefreshThreshold {
            await performAutoLogin()
        }
    }

    func performAutoLogin() async {
        guard keychain.authToken != nil else {
            invalidateAuthenticationFlows()
            authStore.isAuthenticated = false
            router.showUnauthenticatedEntry()
            return
        }
        if let email = authStore.pendingEmailVerification {
            invalidateAuthenticationFlows()
            router.navigate(to: .emailVerification(email: email))
            return
        }
        guard !authStore.isAuthenticated else {
            return
        }

        let flowID = beginAuthenticationFlow()
        router.navigationDirection = .forward
        router.navigate(to: .houseLoading(.checkingAuth), respectingOnboarding: false)

        do {
            router.navigate(to: .houseLoading(.loadingUser), respectingOnboarding: false)
            let profile = try await authStore.restoreAuthenticatedUser(
                invalidMessage: "Oturumunuz sona ermiş. Lütfen tekrar giriş yapın."
            )
            guard isCurrentAuthenticationFlow(flowID) else { return }
            try await finishAuthentication(with: profile, flowID: flowID)
        } catch {
            handleAuthenticationError(error, flowID: flowID)
        }
    }

    func login(email: String, password: String) async {
        if await authStore.login(email: email, password: password) {
            await didAuthenticate()
        }
    }

    @discardableResult
    func socialSignIn(_ provider: SocialProvider) async -> SocialSignInResult {
        let result = await authStore.socialSignIn(provider)
        if case .signedIn = result { await didAuthenticate() }
        return result
    }

    func completeSocialSignUp(email: String, code: String, firstName: String, lastName: String) async throws(SocialStepError) {
        try await authStore.completeSocialSignUp(email: email, code: code, firstName: firstName, lastName: lastName)
        await didAuthenticate()
    }

    @discardableResult
    func signup(email: String, password: String, firstName: String, lastName: String) async -> Bool {
        router.navigationDirection = .forward
        signupSuccessMessage = nil
        let didSignup = await authStore.signup(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName
        )
        if didSignup {
            signupSuccessMessage = localizationStore.value(
                for: "signup_success_message",
                fallback: "Your account was created successfully. Verify your email to continue."
            )
            let verificationEmail = authStore.pendingEmailVerification
                ?? email.trimmingCharacters(in: .whitespacesAndNewlines)
            router.navigate(to: .emailVerification(email: verificationEmail))
        }
        return didSignup
    }

    func clearSignupSuccessMessage() {
        signupSuccessMessage = nil
    }

    func requestPasswordReset(email: String) async throws {
        try await authStore.requestPasswordReset(email: email)
    }

    func resetPasswordOrThrow(email: String, code: String, newPassword: String) async throws {
        try await authStore.resetPasswordOrThrow(email: email, code: code, newPassword: newPassword)
    }

    func sendEmailVerificationCode() async throws {
        try await authStore.sendEmailVerificationCode()
    }

    func validateEmail(code: String) async throws {
        let flowID = beginAuthenticationFlow()

        do {
            try await authStore.validateEmail(code: code)
            guard isCurrentAuthenticationFlow(flowID) else { return }

            let profile = try await authStore.fetchAuthenticatedUser()
            guard isCurrentAuthenticationFlow(flowID) else { return }
            guard profile.isVerifyEmail else {
                throw NetworkError.serverError("The email address could not be verified.")
            }

            authStore.applyAuthenticatedUser(profile)
            router.navigationDirection = .forward
            authStore.isAuthenticated = false
            authStore.clearPendingEmailVerification()
            router.navigate(to: .birthdaySetup)
        } catch {
            guard isCurrentAuthenticationFlow(flowID) else { return }
            throw error
        }
    }

    func completeBirthdaySetup(with birthDate: Date) async throws {
        let flowID = beginAuthenticationFlow()
        let request = UpdateProfileRequest(
            imageUrl: nil,
            birthDay: HouseFlowDateFormatter.apiString(from: birthDate),
            firstName: nil,
            lastName: nil,
            phoneNumber: nil
        )
        let profile = try await authStore.updateProfile(request)
        guard isCurrentAuthenticationFlow(flowID) else { return }
        authStore.applyAuthenticatedUser(profile)
        await didAuthenticate()
    }

    func logout(clearDomainState: () -> Void) {
        invalidateAuthenticationFlows()
        authStore.logout()
        clearDomainState()
        signupSuccessMessage = nil
        router.navigationDirection = .backward
        toastStore.clear()
        router.showUnauthenticatedEntry()
    }

    /// A forced HTTP refresh requested by the `/api/v1/events` channel. It bypasses the
    /// house details cache and never applies a response for a house that is no longer
    /// selected. A user removed from the selected house loses that selection.
    func refreshForAppEvent(profile refreshProfile: Bool, houseID: String?) async {
        guard authStore.isAuthenticated else { return }
        if refreshProfile {
            let flowID = authenticationFlowID
            guard let profile = try? await authStore.fetchAuthenticatedUser(),
                  authStore.isAuthenticated, isCurrentAuthenticationFlow(flowID) else { return }
            authStore.applyAuthenticatedUser(profile)
            if let selected = houseStore.currentHouseDetails?.id,
               !profile.houseList.contains(where: { $0.houseId == selected }) {
                await leaveRemovedHouse(profile: profile, flowID: flowID)
                return
            }
        }
        guard let houseID, houseStore.currentHouseDetails?.id == houseID,
              let details = try? await houseStore.loadHouseDetails(houseId: houseID, forceRefresh: true),
              authStore.isAuthenticated, houseStore.currentHouseDetails?.id == houseID else { return }
        houseStore.applyHouseDetails(details)
    }

    private func leaveRemovedHouse(profile: IsAuthUserData, flowID: UUID) async {
        houseStore.resetHouseSession()
        houseStore.clearChosenHouseSelection()
        guard !profile.houseList.isEmpty else {
            router.navigate(to: .houseSelection)
            return
        }
        router.navigationDirection = .forward
        router.navigate(to: .houseLoading(.loadingHouse), respectingOnboarding: false)
        do {
            guard let result = try await houseStore.loadPreferredHouseDetails(for: profile),
                  isCurrentAuthenticationFlow(flowID), authStore.isAuthenticated else {
                router.navigate(to: .houseSelection)
                return
            }
            houseStore.applySelectedHouseDetails(result.details, houseNameOverride: result.house.houseName)
            router.navigate(to: .dashboard)
        } catch {
            handleAuthenticationError(error, flowID: flowID)
        }
    }

    func invalidateAuthenticationFlows() {
        authenticationFlowID = UUID()
    }

    private func didAuthenticate() async {
        let flowID = beginAuthenticationFlow()
        router.navigationDirection = .forward
        router.navigate(to: .houseLoading(.loadingUser), respectingOnboarding: false)

        do {
            houseStore.setCurrentHouseDetails(nil)
            let profile = try await authStore.fetchAuthenticatedUser()
            guard isCurrentAuthenticationFlow(flowID) else { return }
            try await finishAuthentication(with: profile, flowID: flowID)
        } catch {
            handleAuthenticationError(error, flowID: flowID)
        }
    }

    private func finishAuthentication(with profile: IsAuthUserData, flowID: UUID) async throws {
        guard isCurrentAuthenticationFlow(flowID) else { return }
        authStore.applyAuthenticatedUser(profile)

        guard profile.isVerifyEmail else {
            authStore.requireEmailVerification(for: profile.email)
            authStore.isAuthenticated = false
            router.navigate(to: .emailVerification(email: profile.email))
            return
        }
        if needsBirthdaySetup(profile) {
            authStore.isAuthenticated = false
            router.navigate(to: .birthdaySetup)
            return
        }
        if let language = profile.language {
            localizationStore.applyPreferredLanguage(language)
        } else {
            localizationStore.loadLanguagesAndApplyDefault(
                force: localizationStore.availableLanguages.isEmpty
            )
        }
        authStore.isAuthenticated = true

        guard !profile.houseList.isEmpty else {
            router.navigate(to: .houseSelection)
            return
        }

        router.navigate(to: .houseLoading(.loadingHouse), respectingOnboarding: false)
        guard let result = try await houseStore.loadPreferredHouseDetails(for: profile) else {
            guard isCurrentAuthenticationFlow(flowID), authStore.isAuthenticated else { return }
            router.navigate(to: .houseSelection)
            return
        }
        guard isCurrentAuthenticationFlow(flowID), authStore.isAuthenticated else { return }
        houseStore.applySelectedHouseDetails(
            result.details,
            houseNameOverride: result.house.houseName
        )
        try? await Task.sleep(for: authenticationSettleDelay)
        guard isCurrentAuthenticationFlow(flowID), authStore.isAuthenticated else { return }
        router.navigate(to: .dashboard)
    }

    private func beginAuthenticationFlow() -> UUID {
        let flowID = UUID()
        authenticationFlowID = flowID
        return flowID
    }

    private func isCurrentAuthenticationFlow(_ flowID: UUID) -> Bool {
        authenticationFlowID == flowID
    }

    private func needsBirthdaySetup(_ profile: IsAuthUserData) -> Bool {
        guard let birthDate = profile.birthDate else { return true }
        return birthDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func handleAuthenticationError(_ error: Error, flowID: UUID) {
        guard isCurrentAuthenticationFlow(flowID) else { return }
        authStore.isAuthenticated = false
        toastStore.show(message: errorMessage(from: error), isError: true)
        router.navigate(to: .houseError, respectingOnboarding: false)
    }

    private func errorMessage(from error: Error) -> String {
        if case NetworkError.serverError(let message) = error {
            return message
        }
        return error.localizedDescription
    }
}
