import Foundation
import GoogleSignIn
import HouseFlowCore
import UIKit

/// Google Sign-In: the ID token goes to the backend as `idToken`. A nonce is passed to the SDK
/// and the *same* raw value is sent as `nonce`, since the token then carries it.
@MainActor
final class GoogleCredentialProvider: SocialCredentialProviding {
    func credential(for provider: SocialProvider) async throws -> SocialCredential {
        guard provider == .google, SocialPresentation.configuredValue("GIDClientID") != nil else {
            throw SocialSignInError.unavailable(provider)
        }
        guard let presenter = SocialPresentation.topViewController() else { throw SocialSignInError.missingCredential }
        let nonce = try AppleCredentialProvider.randomNonce()

        let result: GIDSignInResult = try await withCheckedThrowingContinuation { continuation in
            GIDSignIn.sharedInstance.signIn(
                withPresenting: presenter, hint: nil, additionalScopes: nil, nonce: nonce
            ) { result, error in
                if let result {
                    continuation.resume(returning: result)
                } else if let error = error as? GIDSignInError, error.code == .canceled {
                    continuation.resume(throwing: SocialSignInError.cancelled)
                } else {
                    continuation.resume(throwing: SocialSignInError.provider(
                        error?.localizedDescription ?? "Google sign-in failed."
                    ))
                }
            }
        }
        guard let idToken = result.user.idToken?.tokenString else { throw SocialSignInError.missingCredential }
        return SocialCredential(
            idToken: idToken,
            nonce: nonce,
            firstName: result.user.profile?.givenName,
            lastName: result.user.profile?.familyName
        )
    }

    /// Also makes the next sign-in show the account picker again.
    func signOutAll() {
        GIDSignIn.sharedInstance.signOut()
    }
}
