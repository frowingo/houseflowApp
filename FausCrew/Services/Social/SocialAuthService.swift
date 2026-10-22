import Foundation
import FausCrewCore

@MainActor
protocol SocialAuthServicing: AnyObject {
    func signIn(provider: SocialProvider, credential: SocialCredential) async throws -> SocialSignInOutcome
    func requestEmailCode(pendingToken: String, email: String) async throws
    func complete(_ request: SocialCompleteRequest) async throws -> (token: String, isNewUser: Bool)
    func link(provider: SocialProvider, credential: SocialCredential) async throws -> [SocialProvider]
    func unlink(provider: SocialProvider) async throws -> [SocialProvider]
    func deleteAccount() async throws
    /// `true` / `false` when the backend answered 2xx / 401, nil when it could not be told.
    func isSessionValid() async -> Bool?
}

/// Talks to `/auth/social/*` and `DELETE /user/me`. Provider tokens, the pending token and the
/// JWT only travel in request bodies/headers; nothing here logs them.
@MainActor
final class SocialAuthService: SocialAuthServicing {
    private let http: any HTTPClient
    private let keychain: any KeychainStoring
    private let language: @MainActor () -> String

    init(
        http: any HTTPClient,
        keychain: any KeychainStoring,
        language: @escaping @MainActor () -> String = { APILanguage.code }
    ) {
        self.http = http
        self.keychain = keychain
        self.language = language
    }

    func signIn(provider: SocialProvider, credential: SocialCredential) async throws -> SocialSignInOutcome {
        let request = try SocialAuthWireContract.signInRequest(
            provider: provider, credential: credential, language: language()
        )
        let outcome = try SocialAuthWireContract.signInOutcome(from: try await send(request))
        if case let .signedIn(token, _) = outcome { keychain.authToken = token }
        return outcome
    }

    func requestEmailCode(pendingToken: String, email: String) async throws {
        let request = try SocialAuthWireContract.completeCodeRequest(pendingToken: pendingToken, email: email)
        try SocialAuthWireContract.validateAccepted(try await send(request))
    }

    func complete(_ body: SocialCompleteRequest) async throws -> (token: String, isNewUser: Bool) {
        let request = try SocialAuthWireContract.completeRequest(body)
        let result = try SocialAuthWireContract.completedSignIn(from: try await send(request))
        keychain.authToken = result.token
        return result
    }

    func link(provider: SocialProvider, credential: SocialCredential) async throws -> [SocialProvider] {
        let request = try SocialAuthWireContract.linkRequest(
            provider: provider, credential: credential, language: language(), token: try token()
        )
        return try SocialAuthWireContract.linkedProviders(from: try await send(request))
    }

    func unlink(provider: SocialProvider) async throws -> [SocialProvider] {
        let request = try SocialAuthWireContract.unlinkRequest(provider: provider, token: try token())
        return try SocialAuthWireContract.linkedProviders(from: try await send(request))
    }

    func deleteAccount() async throws {
        let request = SocialAuthWireContract.deleteAccountRequest(token: try token())
        try SocialAuthWireContract.validateAccepted(try await send(request))
    }

    func isSessionValid() async -> Bool? {
        guard let token = keychain.authToken,
              let response = try? await send(AuthWireContract.profileRequest(token: token)) else { return nil }
        switch response.statusCode {
        case 200...299: return true
        case 401: return false
        default: return nil
        }
    }

    private func token() throws -> String {
        guard let token = keychain.authToken else { throw SocialAuthError(statusCode: 401, message: nil) }
        return token
    }

    private func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var headers = request.headers
        headers["Accept-Language"] = language()
        return try await http.send(HTTPRequest(
            path: request.path, method: request.method, queryItems: request.queryItems,
            headers: headers, body: request.body
        ))
    }
}
