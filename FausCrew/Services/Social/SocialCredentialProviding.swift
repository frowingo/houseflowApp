import Foundation
import FausCrewCore

enum SocialSignInError: Error, Equatable {
    /// The user closed the provider's sheet.
    case cancelled
    /// No SDK/config for this provider in this build.
    case unavailable(SocialProvider)
    /// Provider answered but gave nothing usable (e.g. no identity token).
    case missingCredential
    case provider(String)
}

/// Gets a *fresh* provider credential per call and signs the provider SDK out afterwards.
@MainActor
protocol SocialCredentialProviding: AnyObject {
    func credential(for provider: SocialProvider) async throws -> SocialCredential
    /// Clears every provider SDK session (logout, account deletion, a 401 from the backend).
    func signOutAll()
    /// The backend accepted this provider's credential (sign-in, completion or link).
    func didAuthenticate(provider: SocialProvider)
}

extension SocialCredentialProviding {
    func didAuthenticate(provider: SocialProvider) {}
}

/// Which provider buttons the build shows, and which of them can actually start a sign-in.
/// Every provider in `FausCrewSocialProviders` gets a button. One whose client ID is still a
/// `YOUR_…` placeholder (or, for Apple, whose capability is off in this build) is shown but not
/// configured: tapping it explains that instead of opening the SDK.
struct SocialAuthConfig: Equatable {
    let shownProviders: [SocialProvider]
    let configuredProviders: Set<SocialProvider>

    init(shownProviders: [SocialProvider], configuredProviders: Set<SocialProvider>) {
        self.shownProviders = shownProviders
        self.configuredProviders = configuredProviders.intersection(shownProviders)
    }

    /// Shown and configured alike.
    init(enabledProviders: [SocialProvider]) {
        self.init(shownProviders: enabledProviders, configuredProviders: Set(enabledProviders))
    }

    func isShown(_ provider: SocialProvider) -> Bool { shownProviders.contains(provider) }
    func isConfigured(_ provider: SocialProvider) -> Bool { configuredProviders.contains(provider) }

    private static let requiredKey: [SocialProvider: String] = [
        .google: "GIDClientID", .facebook: "FacebookAppID", .snapchat: "SCSDKClientId",
    ]

    static func load(from bundle: Bundle = .main) -> SocialAuthConfig {
        let names = (bundle.object(forInfoDictionaryKey: "FausCrewSocialProviders") as? [String]) ?? []
        let shown = SocialProvider.signInProviders.filter { names.contains($0.slug ?? "") }
        let configured = shown.filter { provider in
            if provider == .apple {
                // Needs the Sign in with Apple capability, which only Release carries.
                return bundle.object(forInfoDictionaryKey: "FausCrewAppleSignInEnabled") as? Bool == true
            }
            guard let key = requiredKey[provider] else { return true }
            guard let value = bundle.object(forInfoDictionaryKey: key) as? String else { return false }
            return !value.isEmpty && !value.contains("YOUR_")
        }
        return SocialAuthConfig(shownProviders: shown, configuredProviders: Set(configured))
    }
}

/// Routes to one platform adapter per provider.
@MainActor
final class SocialCredentialRouter: SocialCredentialProviding {
    private let adapters: [SocialProvider: any SocialCredentialProviding]

    init(adapters: [SocialProvider: any SocialCredentialProviding]) {
        self.adapters = adapters
    }

    func credential(for provider: SocialProvider) async throws -> SocialCredential {
        guard let adapter = adapters[provider] else { throw SocialSignInError.unavailable(provider) }
        return try await adapter.credential(for: provider)
    }

    func signOutAll() {
        adapters.values.forEach { $0.signOutAll() }
    }

    func didAuthenticate(provider: SocialProvider) {
        adapters[provider]?.didAuthenticate(provider: provider)
    }
}
