import AppTrackingTransparency
import FacebookCore
import FacebookLogin
import Foundation
import HouseFlowCore
import UIKit

/// Facebook Login. With ATT granted the SDK does a classic login and the backend gets the
/// `accessToken`. Without it (Limited Login) there is no access token: the OIDC
/// `AuthenticationToken` goes as `idToken` together with the raw nonce (Facebook does not hash it).
@MainActor
final class FacebookCredentialProvider: SocialCredentialProviding {
    private let loginManager = LoginManager()

    func credential(for provider: SocialProvider) async throws -> SocialCredential {
        guard provider == .facebook, SocialPresentation.configuredValue("FacebookAppID") != nil else {
            throw SocialSignInError.unavailable(provider)
        }
        let nonce = try AppleCredentialProvider.randomNonce()
        let tracking: LoginTracking = ATTrackingManager.trackingAuthorizationStatus == .authorized ? .enabled : .limited
        guard let configuration = LoginConfiguration(
            permissions: ["public_profile", "email"], tracking: tracking, nonce: nonce
        ) else { throw SocialSignInError.missingCredential }

        // Each attempt starts from a clean SDK session so the token is fresh.
        loginManager.logOut()
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            loginManager.logIn(viewController: SocialPresentation.topViewController(), configuration: configuration) { result in
                switch result {
                case .success: continuation.resume()
                case .cancelled: continuation.resume(throwing: SocialSignInError.cancelled)
                case let .failed(error): continuation.resume(throwing: SocialSignInError.provider(error.localizedDescription))
                }
            }
        }

        let profile = Profile.current
        if let accessToken = AccessToken.current?.tokenString {
            return SocialCredential(accessToken: accessToken, firstName: profile?.firstName, lastName: profile?.lastName)
        }
        if let idToken = AuthenticationToken.current?.tokenString {
            return SocialCredential(idToken: idToken, nonce: nonce, firstName: profile?.firstName, lastName: profile?.lastName)
        }
        throw SocialSignInError.missingCredential
    }

    func signOutAll() {
        loginManager.logOut()
    }
}
