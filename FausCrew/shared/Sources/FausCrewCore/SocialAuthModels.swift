import Foundation

// MARK: - Providers

/// API provider numbers: `0` email/password, `1` Google, `2` Apple, `3` Facebook, `4` Snapchat.
public enum SocialProvider: Int, CaseIterable, Codable, Sendable {
    case email = 0
    case google = 1
    case apple = 2
    case facebook = 3
    case snapchat = 4

    /// Path segment used by `/auth/social/{provider}`; nil for email/password.
    public var slug: String? {
        switch self {
        case .email: return nil
        case .google: return "google"
        case .apple: return "apple"
        case .facebook: return "facebook"
        case .snapchat: return "snapchat"
        }
    }

    /// Providers that offer a sign-in button (everything except email/password).
    public static var signInProviders: [SocialProvider] { allCases.filter { $0.slug != nil } }
}

// MARK: - Requests

/// What a provider SDK produced. Only the fields a provider needs are set; unset fields are
/// omitted from the JSON body. None of these values may be logged or persisted.
public struct SocialCredential: Equatable, Sendable {
    public var idToken: String?
    public var accessToken: String?
    public var nonce: String?
    public var authorizationCode: String?
    public var firstName: String?
    public var lastName: String?

    public init(
        idToken: String? = nil,
        accessToken: String? = nil,
        nonce: String? = nil,
        authorizationCode: String? = nil,
        firstName: String? = nil,
        lastName: String? = nil
    ) {
        self.idToken = idToken
        self.accessToken = accessToken
        self.nonce = nonce
        self.authorizationCode = authorizationCode
        self.firstName = firstName
        self.lastName = lastName
    }
}

public struct SocialSignInRequest: Encodable, Equatable, Sendable {
    public let idToken: String?
    public let accessToken: String?
    public let nonce: String?
    public let authorizationCode: String?
    public let firstName: String?
    public let lastName: String?
    public let language: String?

    public init(credential: SocialCredential, language: String?) {
        idToken = credential.idToken
        accessToken = credential.accessToken
        nonce = credential.nonce
        authorizationCode = credential.authorizationCode
        firstName = credential.firstName?.socialTrimmedName
        lastName = credential.lastName?.socialTrimmedName
        self.language = language
    }
}

public struct SocialCompleteCodeRequest: Encodable, Equatable, Sendable {
    public let pendingToken: String
    public let email: String

    public init(pendingToken: String, email: String) {
        self.pendingToken = pendingToken
        self.email = email
    }
}

public struct SocialCompleteRequest: Encodable, Equatable, Sendable {
    public let pendingToken: String
    public let email: String
    public let code: String
    public let firstName: String?
    public let lastName: String?
    public let language: String?

    public init(
        pendingToken: String,
        email: String,
        code: String,
        firstName: String?,
        lastName: String?,
        language: String?
    ) {
        self.pendingToken = pendingToken
        self.email = email
        self.code = code
        self.firstName = firstName?.socialTrimmedName
        self.lastName = lastName?.socialTrimmedName
        self.language = language
    }
}

// MARK: - Responses

public struct SocialSignInResponse: Decodable, Equatable, Sendable {
    public let token: String?
    public let isNewUser: Bool
    public let needsEmail: Bool?
    public let pendingToken: String?
}

public struct SocialSuccessResponse: Decodable, Sendable {
    public let success: Bool?
}

public struct LinkedProvidersResponse: Decodable, Equatable, Sendable {
    public let linkedProviders: [Int]
}

/// Typed outcome of a sign-in or completion call; the app branches on this, never on message text.
public enum SocialSignInOutcome: Equatable, Sendable {
    case signedIn(token: String, isNewUser: Bool)
    case needsEmail(pendingToken: String)
}

/// A non-2xx answer. Callers branch on `statusCode` only; `message` is localized display text.
public struct SocialAuthError: Error, Equatable, Sendable {
    public let statusCode: Int
    public let message: String?

    public init(statusCode: Int, message: String?) {
        self.statusCode = statusCode
        self.message = message
    }
}

extension String {
    /// Names are capped at 50 characters by the API; blank names are dropped.
    var socialTrimmedName: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : String(trimmed.prefix(50))
    }
}
