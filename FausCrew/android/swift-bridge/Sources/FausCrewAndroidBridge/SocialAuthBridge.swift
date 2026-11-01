import Foundation
import FausCrewCore

// Social sign-in facade. Request bodies and response interpretation come from Core's
// SocialAuthWireContract; Kotlin owns HTTP, secure storage and provider SDKs.
// Empty strings stand for "absent" so no optional types cross JNI. Results always carry
// `status` because the app branches on the HTTP code, never on the message text.

/// `/auth/social/{provider}` path segment, or "" for email/password and unknown numbers.
public func socialProviderSlug(_ provider: Int32) -> String {
    SocialProvider(rawValue: Int(provider))?.slug ?? ""
}

/// Body for `POST /auth/social/{provider}` and `POST /auth/social/{provider}/link`.
public func socialSignInRequestBody(
    _ idToken: String, _ accessToken: String, _ nonce: String, _ authorizationCode: String,
    _ firstName: String, _ lastName: String, _ language: String
) -> String {
    let credential = SocialCredential(
        idToken: idToken.nilIfEmpty, accessToken: accessToken.nilIfEmpty, nonce: nonce.nilIfEmpty,
        authorizationCode: authorizationCode.nilIfEmpty, firstName: firstName.nilIfEmpty,
        lastName: lastName.nilIfEmpty
    )
    return encode(SocialSignInRequest(credential: credential, language: language.nilIfEmpty))
}

public func socialCompleteCodeRequestBody(_ pendingToken: String, _ email: String) -> String {
    encode(SocialCompleteCodeRequest(pendingToken: pendingToken, email: email))
}

public func socialCompleteRequestBody(
    _ pendingToken: String, _ email: String, _ code: String,
    _ firstName: String, _ lastName: String, _ language: String
) -> String {
    encode(SocialCompleteRequest(
        pendingToken: pendingToken, email: email, code: code,
        firstName: firstName.nilIfEmpty, lastName: lastName.nilIfEmpty, language: language.nilIfEmpty
    ))
}

/// action: signIn (sign-in and completion), accepted (complete/code, DELETE user/me), linked.
public func socialResponse(_ action: String, _ status: Int32, _ body: String) -> String {
    let reply = HTTPResponse(statusCode: Int(status), headers: [:], body: Data(body.utf8))
    do {
        switch action {
        case "signIn":
            switch try SocialAuthWireContract.signInOutcome(from: reply) {
            case let .signedIn(token, isNewUser):
                return socialJSON(["ok": true, "status": Int(status), "token": token, "isNewUser": isNewUser])
            case let .needsEmail(pendingToken):
                return socialJSON(["ok": true, "status": Int(status), "needsEmail": true, "pendingToken": pendingToken])
            }
        case "accepted":
            try SocialAuthWireContract.validateAccepted(reply)
            return socialJSON(["ok": true, "status": Int(status)])
        case "linked":
            let providers = try SocialAuthWireContract.linkedProviders(from: reply)
            return socialJSON(["ok": true, "status": Int(status), "linkedProviders": providers.map(\.rawValue)])
        default:
            return socialJSON(["ok": false, "status": Int(status), "message": ""])
        }
    } catch let error as SocialAuthError {
        return socialJSON(["ok": false, "status": error.statusCode, "message": error.message ?? ""])
    } catch {
        return socialJSON(["ok": false, "status": Int(status), "message": ""])
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private func encode<T: Encodable>(_ value: T) -> String {
    (try? JSONEncoder().encode(value)).flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
}

private func socialJSON(_ object: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
          let string = String(data: data, encoding: .utf8) else { return #"{"ok":false}"# }
    return string
}
