import Foundation
import FausCrewCore

struct SocialPendingRegistration: Equatable {
    let pendingToken: String
    let provider: SocialProvider
    var firstName: String
    var lastName: String
}

enum SocialSignInResult: Equatable {
    case signedIn(isNewUser: Bool)
    /// Shown in this build but not set up yet; `authInfo` explains it.
    case notConfigured
    case needsEmail
    case cancelled
    case failed
}

/// A failure the UI branches on by `statusCode` (nil for local/offline errors); `message` is display text.
struct SocialStepError: Error, Equatable {
    let statusCode: Int?
    let message: String
    /// An explanation rather than a failure (e.g. a method not set up in this build).
    var isInfo = false
}

/// Locally produced strings. Server errors arrive localised through `Accept-Language`.
enum SocialAuthMessages {
    @MainActor static var unavailable: String {
        APILanguage.code == "tr"
            ? "Bu giriş yöntemi şu anda kullanılamıyor."
            : "This sign-in method is not available right now."
    }

    @MainActor static func notConfigured(_ provider: SocialProvider) -> String {
        let name = provider.displayName
        return APILanguage.code == "tr"
            ? "\(name) ile giriş henüz yapılandırılmadı. Şimdilik başka bir yöntemle devam edebilirsin."
            : "Sign in with \(name) isn't set up yet. Please use another method for now."
    }

    @MainActor static var generic: String {
        APILanguage.code == "tr"
            ? "İşlem tamamlanamadı. Lütfen tekrar deneyin."
            : "Something went wrong. Please try again."
    }
}

extension AuthSessionStore {
    var shownSocialProviders: [SocialProvider] { socialConfig.shownProviders }

    // MARK: - Sign in / sign up

    func socialSignIn(_ provider: SocialProvider) async -> SocialSignInResult {
        guard let socialAuthService, let socialCredentials, socialConfig.isShown(provider) else {
            authError = SocialAuthMessages.unavailable
            return .failed
        }
        authError = nil
        guard socialConfig.isConfigured(provider) else {
            authInfo = SocialAuthMessages.notConfigured(provider)
            return .notConfigured
        }
        authInfo = nil
        isLoading = true
        defer { isLoading = false }

        let credential: SocialCredential
        do {
            credential = try await socialCredentials.credential(for: provider)
        } catch SocialSignInError.cancelled {
            return .cancelled
        } catch {
            authError = Self.describe(error).message
            return .failed
        }

        do {
            switch try await socialAuthService.signIn(provider: provider, credential: credential) {
            case let .signedIn(_, isNewUser):
                socialCredentials.didAuthenticate(provider: provider)
                clearPendingEmailVerification()
                return .signedIn(isNewUser: isNewUser)
            case let .needsEmail(pendingToken):
                socialPending = SocialPendingRegistration(
                    pendingToken: pendingToken,
                    provider: provider,
                    firstName: credential.firstName ?? "",
                    lastName: credential.lastName ?? ""
                )
                return .needsEmail
            }
        } catch {
            let step = Self.describe(error)
            authError = step.message
            // 401: the provider token was rejected; drop the SDK session so the retry starts clean.
            if step.statusCode == 401 { socialCredentials.signOutAll() }
            return .failed
        }
    }

    // MARK: - Email completion (needsEmail)

    func requestSocialEmailCode(email: String) async throws(SocialStepError) {
        guard let service = socialAuthService, let pending = socialPending else {
            throw SocialStepError(statusCode: 401, message: SocialAuthMessages.generic)
        }
        do {
            try await service.requestEmailCode(
                pendingToken: pending.pendingToken,
                email: email.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        } catch {
            throw Self.describe(error)
        }
    }

    func completeSocialSignUp(email: String, code: String, firstName: String, lastName: String) async throws(SocialStepError) {
        guard let service = socialAuthService, let pending = socialPending else {
            throw SocialStepError(statusCode: 401, message: SocialAuthMessages.generic)
        }
        do {
            _ = try await service.complete(SocialCompleteRequest(
                pendingToken: pending.pendingToken,
                email: email.trimmingCharacters(in: .whitespacesAndNewlines),
                code: code.trimmingCharacters(in: .whitespacesAndNewlines),
                firstName: firstName,
                lastName: lastName,
                language: APILanguage.code
            ))
            socialCredentials?.didAuthenticate(provider: pending.provider)
            socialPending = nil
            clearPendingEmailVerification()
        } catch {
            throw Self.describe(error)
        }
    }

    func cancelSocialPending() {
        socialPending = nil
        socialCredentials?.signOutAll()
    }

    // MARK: - Linked sign-in methods

    /// Returns false when the session itself turned out to be invalid (caller signs the user out).
    func linkSocialProvider(_ provider: SocialProvider) async throws(SocialStepError) -> Bool {
        guard let service = socialAuthService, let socialCredentials, socialConfig.isShown(provider) else {
            throw SocialStepError(statusCode: nil, message: SocialAuthMessages.unavailable)
        }
        guard socialConfig.isConfigured(provider) else {
            throw SocialStepError(statusCode: nil, message: SocialAuthMessages.notConfigured(provider), isInfo: true)
        }
        let credential: SocialCredential
        do {
            credential = try await socialCredentials.credential(for: provider)
        } catch SocialSignInError.cancelled {
            return true
        } catch {
            throw Self.describe(error)
        }
        do {
            let linked = try await service.link(provider: provider, credential: credential)
            socialCredentials.didAuthenticate(provider: provider)
            applyLinkedProviders(linked)
            return true
        } catch {
            let step = Self.describe(error)
            // 401 is ambiguous (bad session or bad provider token): ask /auth/isAuth before signing out.
            if step.statusCode == 401, await service.isSessionValid() == false { return false }
            throw step
        }
    }

    func unlinkSocialProvider(_ provider: SocialProvider) async throws(SocialStepError) -> Bool {
        guard let service = socialAuthService else {
            throw SocialStepError(statusCode: nil, message: SocialAuthMessages.unavailable)
        }
        do {
            applyLinkedProviders(try await service.unlink(provider: provider))
            return true
        } catch {
            let step = Self.describe(error)
            if step.statusCode == 401 { return false }
            if step.statusCode == 404 { await refreshAccountMethods() }
            throw step
        }
    }

    func refreshAccountMethods() async {
        guard let profile = try? await fetchAuthenticatedUser() else { return }
        applyAuthenticatedUser(profile)
    }

    // MARK: - Account deletion

    /// On success the provider SDK sessions are closed and the local session is wiped.
    func deleteAccount() async throws(SocialStepError) {
        guard let service = socialAuthService else {
            throw SocialStepError(statusCode: nil, message: SocialAuthMessages.unavailable)
        }
        do {
            try await service.deleteAccount()
        } catch {
            throw Self.describe(error)
        }
        logout()
    }

    // MARK: - Helpers

    private func applyLinkedProviders(_ providers: [SocialProvider]) {
        guard var profile = currentUserProfile else { return }
        profile.linkedProviders = providers.map(\.rawValue)
        currentUserProfile = profile
    }

    static func describe(_ error: Error) -> SocialStepError {
        switch error {
        case let error as SocialAuthError:
            return SocialStepError(statusCode: error.statusCode, message: error.message ?? SocialAuthMessages.generic)
        case SocialSignInError.unavailable:
            return SocialStepError(statusCode: nil, message: SocialAuthMessages.unavailable)
        case let SocialSignInError.provider(message):
            return SocialStepError(statusCode: nil, message: message)
        case is SocialSignInError, is SocialAuthContractError:
            return SocialStepError(statusCode: nil, message: SocialAuthMessages.generic)
        default:
            // Offline, timeouts and the like: the system text is already localised.
            return SocialStepError(statusCode: nil, message: error.localizedDescription)
        }
    }
}

extension SocialProvider {
    var displayName: String {
        switch self {
        case .email: return "Email"
        case .google: return "Google"
        case .apple: return "Apple"
        case .facebook: return "Facebook"
        case .snapchat: return "Snapchat"
        }
    }
}
