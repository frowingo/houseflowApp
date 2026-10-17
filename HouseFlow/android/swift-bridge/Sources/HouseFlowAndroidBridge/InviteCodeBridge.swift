import Foundation
import HouseFlowCore

/// Narrow, versioned JNI boundary. HTTP execution and secure storage stay on Android.
public func bridgeVersion() -> Int32 { 9 }

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

public func signupRequestBody(_ email: String, _ password: String, _ firstName: String, _ lastName: String) -> String {
    requestBody(try? AuthWireContract.signupRequest(email: email, password: password, firstName: firstName, lastName: lastName))
}

public func forgotPasswordRequestBody(_ email: String) -> String {
    requestBody(try? AuthWireContract.forgotPasswordRequest(email: email))
}

public func resetPasswordRequestBody(_ email: String, _ code: String, _ newPassword: String) -> String {
    requestBody(try? AuthWireContract.resetPasswordRequest(email: email, code: code, newPassword: newPassword))
}

public func verifyEmailRequestBody(_ code: String) -> String {
    requestBody(try? AuthWireContract.verifyEmailRequest(token: "", code: code))
}

public func birthdayRequestBody(_ birthDay: String) -> String {
    requestBody(try? AuthWireContract.birthdayRequest(token: "", userId: "", birthDay: birthDay))
}

/// action: forgot, sendVerification, verifyEmail, reset, birthday.
public func authActionResponse(_ action: String, _ status: Int32, _ body: String) -> String {
    do {
        let reply = response(status, body)
        switch action {
        case "forgot":
            // iOS accepts a decoded response even if its success field is false.
            _ = try AuthWireContract.forgotPasswordAccepted(from: reply)
            return json(["ok": true])
        case "sendVerification", "verifyEmail":
            let accepted = try AuthWireContract.verificationAccepted(from: reply)
            return json(["ok": accepted, "message": accepted ? "" :
                (action == "sendVerification" ? "Verification email could not be sent." : "The verification code is invalid.")])
        case "reset":
            return json(["ok": true, "message": try AuthWireContract.resetMessage(from: reply)])
        case "birthday":
            return json(["ok": try AuthWireContract.birthdayAccepted(from: reply)])
        default:
            return json(["ok": false, "message": "Unsupported auth action"])
        }
    } catch {
        return failure(error)
    }
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
            "userId": profile.id,
            "email": profile.email,
            "firstName": profile.firstName,
            "lastName": profile.lastName,
            "language": profile.language ?? "",
            "imageUrl": profile.imageUrl,
            "birthDay": profile.birthDate ?? "",
            "createdOn": profile.createdOn,
            "phoneNumber": profile.phoneNumber,
            "isVerifyEmail": profile.isVerifyEmail,
            "isVerifyPhone": profile.isVerifyPhone,
            "houseList": profile.houseList.map { [
                "houseId": $0.houseId,
                "houseName": $0.houseName,
                "houseProfile": $0.houseProfile
            ] }
        ])
    } catch {
        return failure(error)
    }
}

public func profileUpdateRequestBody(
    _ imageUrl: String, _ birthDay: String, _ firstName: String,
    _ lastName: String, _ phoneNumber: String, _ language: String
) -> String {
    let body = try? AuthWireContract.profileUpdateBody(
        imageUrl: imageUrl.isEmpty ? nil : imageUrl,
        birthDay: birthDay.isEmpty ? nil : birthDay,
        firstName: firstName.isEmpty ? nil : firstName,
        lastName: lastName.isEmpty ? nil : lastName,
        phoneNumber: phoneNumber.isEmpty ? nil : phoneNumber,
        language: language.isEmpty ? nil : language
    )
    return body.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
}

public func profileUpdateResponse(_ status: Int32, _ body: String) -> String {
    do {
        let profile = try AuthWireContract.updatedProfile(from: response(status, body))
        return json(["ok": true, "firstName": profile.firstName, "lastName": profile.lastName,
            "imageUrl": profile.imageUrl, "birthDay": profile.birthDate ?? "",
            "phoneNumber": profile.phoneNumber, "language": profile.language ?? ""])
    } catch {
        if case ProfileWireError.rejected(let message) = error {
            return json(["ok": false, "message": message ?? ""])
        }
        return failure(error)
    }
}

public func profileImagesResponse(_ status: Int32, _ body: String) -> String {
    do {
        let images = try AuthWireContract.profileImages(from: response(status, body))
        return json(["ok": true, "images": images.map { ["url": $0.fileURL, "publicId": $0.publicId] }])
    } catch { return failure(error) }
}

/// One JNI call per house operation, never per dashboard item. The validated
/// server envelope is passed through for Android's screen-state projection.
public func houseResponse(_ action: String, _ status: Int32, _ body: String) -> String {
    do {
        try HouseWireContract.validate(action: action, response: response(status, body))
        return body
    } catch {
        let message: String
        if case HouseWireError.rejected(let serverMessage) = error {
            message = serverMessage ?? ""
        } else {
            message = (error as? HTTPStatusFailure)?.message ?? ""
        }
        return json(["success": false, "error": message])
    }
}

/// action: create, join, invite, exit, profile.
public func houseRequestBody(
    _ action: String, _ houseId: String, _ userId: String, _ name: String,
    _ inviteCode: String, _ type: Int32, _ maxMemberCount: Int32, _ profileImage: String
) -> String {
    let data: Data?
    switch action {
    case "create":
        data = try? HouseWireContract.createBody(name: name, type: Int(type), maxMemberCount: Int(maxMemberCount))
    case "join":
        data = try? HouseWireContract.joinBody(inviteCode: inviteCode)
    case "invite":
        data = try? HouseWireContract.inviteBody(houseId: houseId)
    case "exit":
        data = try? HouseWireContract.exitBody(houseId: houseId, userId: userId)
    case "profile":
        data = try? HouseWireContract.profileBody(
            name: name, type: Int(type), maxMemberCount: Int(maxMemberCount), profileImage: profileImage
        )
    default:
        data = nil
    }
    return data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
}

/// action: create, update, status, review, announcement.
public func dashboardRequestBody(
    _ action: String, _ houseId: String, _ choreId: String, _ assignedTo: String,
    _ title: String, _ description: String, _ dueDate: String, _ isRecurring: Bool,
    _ level: Int32, _ recurringInterval: Int32, _ status: Int32, _ isApproved: Bool
) -> String {
    let data: Data?
    switch action {
    case "create":
        data = try? DashboardWireContract.choreBody(
            assignedTo: assignedTo, description: description, dueDate: dueDate,
            houseId: houseId, isRecurring: isRecurring, level: Int(level),
            recurringInterval: Int(recurringInterval), title: title
        )
    case "update":
        data = try? DashboardWireContract.updateChoreBody(
            assignedTo: assignedTo, description: description, dueDate: dueDate,
            houseId: houseId, isRecurring: isRecurring, level: Int(level),
            recurringInterval: Int(recurringInterval), title: title
        )
    case "status":
        data = try? DashboardWireContract.statusBody(choreId: choreId, houseId: houseId, status: Int(status))
    case "review":
        data = try? DashboardWireContract.reviewBody(choreId: choreId, isApproved: isApproved)
    case "announcement":
        data = try? DashboardWireContract.announcementBody(title: title, description: description, houseId: houseId)
    default:
        data = nil
    }
    return data.flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
}

public func dashboardResponse(_ action: String, _ status: Int32, _ body: String) -> String {
    do {
        try DashboardWireContract.validate(action: action, response: response(status, body))
        return json(["ok": true, "data": body])
    } catch {
        let message: String
        if case DashboardWireError.rejected(let serverMessage) = error {
            message = serverMessage ?? ""
        } else {
            message = (error as? HTTPStatusFailure)?.message ?? ""
        }
        return json(["ok": false, "message": message])
    }
}

private func requestBody(_ request: HTTPRequest?) -> String {
    guard let body = request?.body, let json = String(data: body, encoding: .utf8) else { return "{}" }
    return json
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
