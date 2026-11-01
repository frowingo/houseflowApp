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

    public static func signupRequest(email: String, password: String, firstName: String, lastName: String) throws -> HTTPRequest {
        try jsonRequest("auth/signup", "POST", SignupRequest(email: email, password: password, firstName: firstName, lastName: lastName))
    }

    public static func forgotPasswordRequest(email: String) throws -> HTTPRequest {
        try jsonRequest("auth/forget", "POST", ForgotPasswordRequest(email: email))
    }

    public static func resetPasswordRequest(email: String, code: String, newPassword: String) throws -> HTTPRequest {
        try jsonRequest("auth/reset", "POST", ResetPasswordRequest(email: email, code: code, newPassword: newPassword))
    }

    public static func sendVerificationRequest(token: String) -> HTTPRequest {
        HTTPRequest(path: "auth/validate-email", method: "GET", headers: ["Authorization": "Bearer \(token)"])
    }

    public static func verifyEmailRequest(token: String, code: String) throws -> HTTPRequest {
        try jsonRequest("auth/validate-email", "POST", ValidateEmailRequest(code: code), token: token)
    }

    public static func birthdayRequest(token: String, userId: String, birthDay: String) throws -> HTTPRequest {
        let body = try JSONEncoder().encode(UpdateProfileRequest(
            imageUrl: nil, birthDay: birthDay, firstName: nil, lastName: nil, phoneNumber: nil
        ))
        return HTTPRequest(path: "user/profile/\(userId)", method: "PUT",
            queryItems: [HTTPQueryItem(name: "userId", value: userId)],
            headers: ["Content-Type": "application/json", "Authorization": "Bearer \(token)"], body: body)
    }

    public static func forgotPasswordAccepted(from response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) throws -> Bool {
        try validateStatus(response, decoder: decoder)
        return try decoder.decode(ForgotPasswordResponse.self, from: response.body).success
    }

    public static func verificationAccepted(from response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) throws -> Bool {
        try validateStatus(response, decoder: decoder)
        return try decoder.decode(ValidateEmailResponse.self, from: response.body).success
    }

    public static func resetMessage(from response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) throws -> String {
        try validateStatus(response, decoder: decoder)
        return try decoder.decode(MessageResponse.self, from: response.body).message
    }

    public static func birthdayAccepted(from response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) throws -> Bool {
        try validateStatus(response, decoder: decoder)
        let result = try decoder.decode(UpdateProfileResponse.self, from: response.body)
        return result.success && result.data != nil
    }

    public static func profileUpdateBody(
        imageUrl: String? = nil, birthDay: String? = nil, firstName: String? = nil,
        lastName: String? = nil, phoneNumber: String? = nil, language: String? = nil
    ) throws -> Data {
        try JSONEncoder().encode(UpdateProfileRequest(
            imageUrl: imageUrl, birthDay: birthDay, firstName: firstName,
            lastName: lastName, phoneNumber: phoneNumber, language: language
        ))
    }

    public static func updatedProfile(from response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) throws -> UserResultModel {
        try validateStatus(response, decoder: decoder)
        let result = try decoder.decode(UpdateProfileResponse.self, from: response.body)
        guard result.success, let profile = result.data else { throw ProfileWireError.rejected(result.error) }
        return profile
    }

    public static func profileImages(from response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) throws -> [UserImageData] {
        try validateStatus(response, decoder: decoder)
        let result = try decoder.decode(GetImagesResponse.self, from: response.body)
        guard result.success else { throw SessionRestoreError.invalidProfile }
        return result.data
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

    private static func jsonRequest<T: Encodable>(_ path: String, _ method: String, _ body: T, token: String? = nil) throws -> HTTPRequest {
        var headers = ["Content-Type": "application/json"]
        if let token { headers["Authorization"] = "Bearer \(token)" }
        return HTTPRequest(path: path, method: method, headers: headers, body: try JSONEncoder().encode(body))
    }
}

public enum ProfileWireError: Error, Equatable {
    case rejected(String?)
}

public enum AuthDestination: String, Equatable, Sendable {
    case emailVerification
    case birthdaySetup
    case houseSelection
    case dashboard
}
