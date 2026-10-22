import Foundation
import HouseFlowCore
import SCSDKLoginKit
import UIKit

/// Snap Login Kit. Scopes (display name, external ID) come from `SCSDKScopes` in Info.plist.
/// The access token goes to the backend as `accessToken`; Snapchat never shares an email, so a
/// new user always continues with the `needsEmail` flow. The display name pre-fills that form.
@MainActor
final class SnapchatCredentialProvider: SocialCredentialProviding {
    func credential(for provider: SocialProvider) async throws -> SocialCredential {
        guard provider == .snapchat, SocialPresentation.configuredValue("SCSDKClientId") != nil else {
            throw SocialSignInError.unavailable(provider)
        }
        // Clearing first forces a fresh authorisation instead of reusing a stored token.
        SCSDKLoginClient.clearToken()
        try await grant()
        let accessToken: String = try await withCheckedThrowingContinuation { continuation in
            SCSDKLoginClient.fetchAccessToken { token, error in
                if let token, !token.isEmpty {
                    continuation.resume(returning: token)
                } else {
                    continuation.resume(throwing: SocialSignInError.provider(
                        error?.localizedDescription ?? "Snapchat did not return an access token."
                    ))
                }
            }
        }
        return SocialCredential(accessToken: accessToken, firstName: await displayName())
    }

    func signOutAll() {
        SCSDKLoginClient.clearToken()
    }

    /// Login Kit never reports a user who leaves Snapchat without approving. If the app becomes
    /// active again and no result follows shortly, the attempt counts as cancelled.
    private func grant() async throws {
        let attempt = GrantAttempt()
        defer { attempt.stopObserving() }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            attempt.continuation = continuation
            attempt.observeReturn()
            SCSDKLoginClient.login(from: SocialPresentation.topViewController()) { success, error in
                Task { @MainActor in
                    if success {
                        attempt.finish(nil)
                    } else if let error {
                        attempt.finish(SocialSignInError.provider(error.localizedDescription))
                    } else {
                        // Login Kit reports a closed sheet as a failure without an error.
                        attempt.finish(SocialSignInError.cancelled)
                    }
                }
            }
        }
    }

    /// Best effort: a missing display name only leaves the name fields empty.
    private func displayName() async -> String? {
        await withCheckedContinuation { continuation in
            let query = SCSDKUserDataQueryBuilder().withDisplayName().build()
            SCSDKLoginClient.fetchUserData(with: query, success: { userData, _ in
                continuation.resume(returning: userData?.displayName)
            }, failure: { _, _ in
                continuation.resume(returning: nil)
            })
        }
    }
}

/// One login attempt: resumes its continuation exactly once.
@MainActor
private final class GrantAttempt {
    var continuation: CheckedContinuation<Void, Error>?
    private var observers: [NSObjectProtocol] = []
    private var leftApp = false
    private static let returnGrace: Duration = .seconds(2)

    func observeReturn() {
        let center = NotificationCenter.default
        observers.append(center.addObserver(forName: UIApplication.willResignActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated { self?.leftApp = true }
        })
        observers.append(center.addObserver(forName: UIApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.leftApp else { return }
                Task { @MainActor [weak self] in
                    try? await Task.sleep(for: Self.returnGrace)
                    self?.finish(SocialSignInError.cancelled)
                }
            }
        })
    }

    func finish(_ error: Error?) {
        guard let continuation else { return }
        self.continuation = nil
        stopObserving()
        if let error { continuation.resume(throwing: error) } else { continuation.resume() }
    }

    func stopObserving() {
        observers.forEach(NotificationCenter.default.removeObserver)
        observers.removeAll()
    }
}
