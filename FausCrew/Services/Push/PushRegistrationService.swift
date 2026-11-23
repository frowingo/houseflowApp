import Foundation
import FausCrewCore
import os

/// Hosts FausCrewCore's `PushRegistrationChannel`: feeds it the session and the FCM token and
/// performs its effects over HTTP. Failures are only logged; Core decides what is retried.
@MainActor
final class PushRegistrationService {
    private let http: any HTTPClient
    private let keychain: any KeychainStoring
    private let tokens: any PushTokenProviding
    private let channel = PushRegistrationChannel()
    private var started = false
    /// Sign-outs that ran cleanup; a token fetched before one may be the deleted token.
    private var signOuts = 0

    private static let log = Logger(subsystem: "com.fauscrew", category: "Push")

    init(http: any HTTPClient, keychain: any KeychainStoring, tokens: any PushTokenProviding) {
        self.http = http
        self.keychain = keychain
        self.tokens = tokens
    }

    func start() {
        guard !started else { return }
        started = true
        PushNotificationCenter.shared.onTokenChange = { [weak self] in self?.setToken($0) }
        let before = signOuts
        Task {
            if let token = await tokens.currentToken(), signOuts == before { setToken(token) }
        }
    }

    /// The fully signed-in user, or nil.
    func setSession(userID: String?) {
        channel.setSession(userID: userID)
        perform()
    }

    /// Call before the stored JWT is cleared: a user-initiated sign-out still needs it.
    func signOut(reason: PushSignOutReason) {
        channel.signOut(reason: reason)
        perform()
    }

    private func setToken(_ token: String?) {
        channel.setToken(token)
        perform()
    }

    private func perform() {
        var unregister: (token: String, request: HTTPRequest?)?
        var deletesLocalToken = false
        for effect in channel.drainEffects() {
            switch effect {
            case .register(let token):
                register(token)
            case .unregister(let token):
                // The JWT is read now; the session is cleared right after this call.
                let request = keychain.authToken.flatMap {
                    try? NotificationWireContract.unregisterDeviceRequest(token: token, jwt: $0)
                }
                unregister = (token, request)
            case .deleteLocalToken:
                deletesLocalToken = true
            }
        }
        guard unregister != nil || deletesLocalToken else { return }
        signOuts += 1
        // One job, in order, so the fresh token is fetched only after the old one is gone.
        Task {
            if let unregister {
                if let request = unregister.request { await send(request, token: unregister.token) }
                channel.unregisterFinished()
            }
            if deletesLocalToken {
                await tokens.deleteToken()
                channel.localTokenDeleted()
                if let fresh = await tokens.currentToken() { setToken(fresh) }
            }
        }
    }

    private func register(_ token: String) {
        guard let jwt = keychain.authToken,
              let request = try? NotificationWireContract.registerDeviceRequest(token: token, platform: .ios, jwt: jwt)
        else { return }
        Task { await send(request, token: token) }
    }

    private func send(_ request: HTTPRequest, token: String) async {
        let label = "\(request.method) \(request.path) ios \(PushTokenLog.redacted(token))"
        do {
            let response = try await http.send(request)
            Self.log.debug("\(label, privacy: .public) -> \(response.statusCode, privacy: .public)")
        } catch {
            Self.log.error("\(label, privacy: .public) failed: \((error as NSError).code, privacy: .public)")
        }
    }
}
