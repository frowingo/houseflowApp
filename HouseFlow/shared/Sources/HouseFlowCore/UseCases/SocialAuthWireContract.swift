import Foundation

/// Wire contract for `/auth/social/*`, `/auth/social/{provider}/link` and `DELETE /user/me`.
/// Status codes drive the caller's branching; response `error` text is display-only.
public enum SocialAuthWireContract {
    public static func signInRequest(
        provider: SocialProvider,
        credential: SocialCredential,
        language: String?
    ) throws -> HTTPRequest {
        guard let slug = provider.slug else { throw SocialAuthContractError.unsupportedProvider }
        return try json("auth/social/\(slug)", "POST", SocialSignInRequest(credential: credential, language: language))
    }

    public static func completeCodeRequest(pendingToken: String, email: String) throws -> HTTPRequest {
        try json("auth/social/complete/code", "POST", SocialCompleteCodeRequest(pendingToken: pendingToken, email: email))
    }

    public static func completeRequest(_ body: SocialCompleteRequest) throws -> HTTPRequest {
        try json("auth/social/complete", "POST", body)
    }

    public static func linkRequest(
        provider: SocialProvider,
        credential: SocialCredential,
        language: String?,
        token: String
    ) throws -> HTTPRequest {
        guard let slug = provider.slug else { throw SocialAuthContractError.unsupportedProvider }
        return try json(
            "auth/social/\(slug)/link", "POST",
            SocialSignInRequest(credential: credential, language: language), token: token
        )
    }

    public static func unlinkRequest(provider: SocialProvider, token: String) throws -> HTTPRequest {
        guard let slug = provider.slug else { throw SocialAuthContractError.unsupportedProvider }
        return HTTPRequest(
            path: "auth/social/\(slug)/link", method: "DELETE",
            headers: ["Authorization": "Bearer \(token)"]
        )
    }

    public static func deleteAccountRequest(token: String) -> HTTPRequest {
        HTTPRequest(path: "user/me", method: "DELETE", headers: ["Authorization": "Bearer \(token)"])
    }

    // MARK: Responses

    public static func signInOutcome(from response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) throws -> SocialSignInOutcome {
        try validate(response, decoder: decoder)
        let payload = try decoder.decode(SocialSignInResponse.self, from: response.body)
        if let token = payload.token, !token.isEmpty {
            return .signedIn(token: token, isNewUser: payload.isNewUser)
        }
        if payload.needsEmail == true, let pending = payload.pendingToken, !pending.isEmpty {
            return .needsEmail(pendingToken: pending)
        }
        throw SocialAuthContractError.malformedResponse
    }

    /// `/auth/social/complete`: 201 creates the account, 200 means it already existed.
    public static func completedSignIn(from response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) throws -> (token: String, isNewUser: Bool) {
        let outcome = try signInOutcome(from: response, decoder: decoder)
        guard case let .signedIn(token, isNew) = outcome else { throw SocialAuthContractError.malformedResponse }
        return (token, isNew)
    }

    public static func validateAccepted(_ response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) throws {
        try validate(response, decoder: decoder)
    }

    public static func linkedProviders(from response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) throws -> [SocialProvider] {
        try validate(response, decoder: decoder)
        let payload = try decoder.decode(LinkedProvidersResponse.self, from: response.body)
        return payload.linkedProviders.compactMap(SocialProvider.init(rawValue:))
    }

    private static func validate(_ response: HTTPResponse, decoder: JSONDecoder) throws {
        guard (200...299).contains(response.statusCode) else {
            let failure = HTTPStatusFailure(response: response, decoder: decoder)
            throw SocialAuthError(statusCode: failure.statusCode, message: failure.message)
        }
    }

    private static func json<T: Encodable>(_ path: String, _ method: String, _ body: T, token: String? = nil) throws -> HTTPRequest {
        var headers = ["Content-Type": "application/json"]
        if let token { headers["Authorization"] = "Bearer \(token)" }
        return HTTPRequest(path: path, method: method, headers: headers, body: try JSONEncoder().encode(body))
    }
}

public enum SocialAuthContractError: Error, Equatable, Sendable {
    case unsupportedProvider
    case malformedResponse
}
