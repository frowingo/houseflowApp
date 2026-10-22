import AuthenticationServices
import CryptoKit
import Foundation
import FausCrewCore
import UIKit

/// Sign in with Apple. The nonce is random per attempt: Apple receives its SHA-256 (lowercase
/// hex), the backend receives the raw value. Apple shares the name only on first authorisation,
/// so it is kept locally until the backend accepted a request, and re-sent on retries.
@MainActor
final class AppleCredentialProvider: NSObject, SocialCredentialProviding {
    private let pendingNameStore: any PreferencesStore
    private var continuation: CheckedContinuation<ASAuthorizationAppleIDCredential, Error>?
    private var controller: ASAuthorizationController?

    private static let givenNameKey = "social.apple.pendingGivenName"
    private static let familyNameKey = "social.apple.pendingFamilyName"

    init(pendingNameStore: any PreferencesStore = UserDefaults.standard) {
        self.pendingNameStore = pendingNameStore
    }

    func credential(for provider: SocialProvider) async throws -> SocialCredential {
        guard provider == .apple else { throw SocialSignInError.unavailable(provider) }
        let rawNonce = try Self.randomNonce()

        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]
        request.nonce = Self.sha256Hex(rawNonce)

        let apple = try await authorize(request)
        guard let tokenData = apple.identityToken, let idToken = String(data: tokenData, encoding: .utf8),
              let codeData = apple.authorizationCode, let code = String(data: codeData, encoding: .utf8)
        else { throw SocialSignInError.missingCredential }

        if let name = apple.fullName {
            if let given = name.givenName { pendingNameStore.set(given, forKey: Self.givenNameKey) }
            if let family = name.familyName { pendingNameStore.set(family, forKey: Self.familyNameKey) }
        }
        return SocialCredential(
            idToken: idToken,
            nonce: rawNonce,
            authorizationCode: code,
            firstName: pendingNameStore.string(forKey: Self.givenNameKey),
            lastName: pendingNameStore.string(forKey: Self.familyNameKey)
        )
    }

    /// Call once the backend accepted the request; the name is then stored server-side.
    func clearPendingName() {
        pendingNameStore.removeObject(forKey: Self.givenNameKey)
        pendingNameStore.removeObject(forKey: Self.familyNameKey)
    }

    func signOutAll() {}

    func didAuthenticate(provider: SocialProvider) { clearPendingName() }

    // MARK: - Authorization

    private func authorize(_ request: ASAuthorizationAppleIDRequest) async throws -> ASAuthorizationAppleIDCredential {
        try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            let controller = ASAuthorizationController(authorizationRequests: [request])
            controller.delegate = self
            controller.presentationContextProvider = self
            self.controller = controller
            controller.performRequests()
        }
    }

    private func finish(_ result: Result<ASAuthorizationAppleIDCredential, Error>) {
        let pending = continuation
        continuation = nil
        controller = nil
        pending?.resume(with: result)
    }

    // MARK: - Nonce

    static func randomNonce(length: Int = 32) throws -> String {
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        while result.count < length {
            var bytes = [UInt8](repeating: 0, count: 16)
            guard SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes) == errSecSuccess else {
                throw SocialSignInError.provider("Secure random generation failed.")
            }
            // 64 symbols divide 256 evenly, so the modulo adds no bias.
            for byte in bytes where result.count < length {
                result.append(charset[Int(byte) % charset.count])
            }
        }
        return result
    }

    static func sha256Hex(_ input: String) -> String {
        SHA256.hash(data: Data(input.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}

extension AppleCredentialProvider: ASAuthorizationControllerDelegate {
    nonisolated func authorizationController(
        controller: ASAuthorizationController,
        didCompleteWithAuthorization authorization: ASAuthorization
    ) {
        let credential = authorization.credential as? ASAuthorizationAppleIDCredential
        Task { @MainActor in
            if let credential {
                finish(.success(credential))
            } else {
                finish(.failure(SocialSignInError.missingCredential))
            }
        }
    }

    nonisolated func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        let cancelled = (error as? ASAuthorizationError)?.code == .canceled
        let message = error.localizedDescription
        Task { @MainActor in
            finish(.failure(cancelled ? SocialSignInError.cancelled : SocialSignInError.provider(message)))
        }
    }
}

extension AppleCredentialProvider: ASAuthorizationControllerPresentationContextProviding {
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first ?? ASPresentationAnchor()
    }
}
