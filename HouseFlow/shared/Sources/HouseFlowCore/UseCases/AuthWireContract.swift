import Foundation

/// The auth wire and post-profile decisions shared by the iOS host and the
/// Android JNI facade. HTTP execution, secure storage, and navigation stay on
/// their respective platforms.
public enum AuthWireContract {
    public static func loginRequest(email: String, password: String) throws -> HTTPRequest {
        HTTPRequest(
            path: "auth/login",
            method: "POST",
            headers: ["Content-Type": "application/json"],
            body: try JSONEncoder().encode(LoginRequest(email: email, password: password))
        )
    }

    public static func loginToken(
        from response: HTTPResponse,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> String {
        try validateStatus(response, decoder: decoder)
        return try decoder.decode(AuthTokenResponse.self, from: response.body).token
    }

    public static func profileRequest(token: String) -> HTTPRequest {
        HTTPRequest(
            path: "auth/isAuth",
            method: "GET",
            headers: ["Authorization": "Bearer \(token)"]
        )
    }

    public static func profile(
        from response: HTTPResponse,
        decoder: JSONDecoder = JSONDecoder()
    ) throws -> IsAuthUserData {
        try validateStatus(response, decoder: decoder)
        let payload = try decoder.decode(IsAuthResponse.self, from: response.body)
        guard payload.success, let profile = payload.data else {
            throw SessionRestoreError.invalidProfile
        }
        return profile
    }

    public static func destination(for profile: IsAuthUserData) -> AuthDestination {
        if !profile.isVerifyEmail { return .emailVerification }
        if profile.birthDate?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false {
            return .birthdaySetup
        }
        return profile.houseList.isEmpty ? .houseSelection : .dashboard
    }

    private static func validateStatus(_ response: HTTPResponse, decoder: JSONDecoder) throws {
        guard (200...399).contains(response.statusCode) else {
            throw HTTPStatusFailure(response: response, decoder: decoder)
        }
    }
}

public enum AuthDestination: String, Equatable, Sendable {
    case emailVerification
    case birthdaySetup
    case houseSelection
    case dashboard
}
