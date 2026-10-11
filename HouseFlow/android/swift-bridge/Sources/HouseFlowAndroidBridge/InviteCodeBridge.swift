import Foundation
import HouseFlowCore

/// Narrow, versioned JNI boundary. HTTP execution and secure storage stay on Android.
public func bridgeVersion() -> Int32 { 2 }

public func normalizeInviteCode(_ input: String) -> String {
    InviteCodeRules.normalized(input)
}

public func loginRequestBody(_ email: String, _ password: String) -> String {
    guard let request = try? AuthWireContract.loginRequest(email: email, password: password),
          let body = request.body, let json = String(data: body, encoding: .utf8) else {
        return "{}"
    }
    return json
}

/// A compact JSON result keeps Swift value types out of generated Java bindings.
public func loginResponse(_ status: Int32, _ body: String) -> String {
    do {
        let token = try AuthWireContract.loginToken(from: response(status, body))
        return json(["ok": true, "token": token])
    } catch {
        return failure(error)
    }
}

public func profileResponse(_ status: Int32, _ body: String) -> String {
    do {
        let profile = try AuthWireContract.profile(from: response(status, body))
        return json([
            "ok": true,
            "destination": AuthWireContract.destination(for: profile).rawValue,
            "email": profile.email,
            "firstName": profile.firstName,
            "lastName": profile.lastName,
            "language": profile.language ?? ""
        ])
    } catch {
        return failure(error)
    }
}

private func response(_ status: Int32, _ body: String) -> HTTPResponse {
    HTTPResponse(statusCode: Int(status), headers: [:], body: Data(body.utf8))
}

private func failure(_ error: Error) -> String {
    let message = (error as? HTTPStatusFailure)?.message ?? ""
    return json(["ok": false, "message": message])
}

private func json(_ object: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
          let string = String(data: data, encoding: .utf8) else { return "{\"ok\":false}" }
    return string
}
