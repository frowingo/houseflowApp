import Foundation
import FausCrewCore

// Push notification rules for Android: device registration and notification list requests,
// response validation, the unread badge, push targets and the reminder rule. JSON in, JSON out;
// the JWT never crosses (Kotlin adds the Authorization header) and Core stays the only place
// that knows the paths, bodies and limits.

/// action: `register` {token, platform}, `unregister` {token}, `list` {houseId, before?, limit?} or
/// `remind` {choreId}. Returns `{"ok":true,"path":"…","method":"…","query":[{"name","value"}],"body":"…"}`
/// (`body` only when there is one) or `{"ok":false,"kind":"invalidRequest"}`.
public func notificationRequest(_ action: String, _ fieldsJson: String) -> String {
    let fields = (try? JSONSerialization.jsonObject(with: Data(fieldsJson.utf8))) as? [String: Any] ?? [:]
    func text(_ key: String) -> String { fields[key] as? String ?? "" }
    // The Authorization header is Kotlin's; only the path, query and body are used from Core's request.
    let jwt = ""
    do throws(NotificationFailure) {
        let request: HTTPRequest
        switch action {
        case "register":
            guard let platform = PushPlatform(rawValue: text("platform")) else {
                throw NotificationFailure(kind: .invalidRequest, message: nil)
            }
            request = try NotificationWireContract.registerDeviceRequest(token: text("token"), platform: platform, jwt: jwt)
        case "unregister":
            request = try NotificationWireContract.unregisterDeviceRequest(token: text("token"), jwt: jwt)
        case "list":
            request = NotificationWireContract.listRequest(
                houseID: text("houseId"), before: fields["before"] as? String, limit: fields["limit"] as? Int, jwt: jwt)
        case "remind":
            request = NotificationWireContract.remindRequest(choreID: text("choreId"), jwt: jwt)
        default:
            throw NotificationFailure(kind: .invalidRequest, message: nil)
        }
        var object: [String: Any] = [
            "ok": true,
            "path": request.path,
            "method": request.method,
            "query": request.queryItems.map { ["name": $0.name, "value": $0.value ?? ""] },
        ]
        if let body = request.body { object["body"] = String(decoding: body, as: UTF8.self) }
        return bridgeJSON(object)
    } catch {
        return failureJSON(error)
    }
}

/// action: `register`, `unregister`, `list` or `remind`. Returns `{"ok":true}`, for `list`
/// `{"ok":true,"items":[…],"nextCursor"?:"…"}`, or `{"ok":false,"kind":"…","message"?:"…"}`.
public func notificationResponse(_ action: String, _ status: Int32, _ body: String) -> String {
    let response = HTTPResponse(statusCode: Int(status), headers: [:], body: Data(body.utf8))
    do throws(NotificationFailure) {
        switch action {
        case "register", "unregister":
            try NotificationWireContract.deviceAccepted(response)
        case "remind":
            try NotificationWireContract.reminded(response)
        case "list":
            let page = try NotificationWireContract.page(response)
            var object: [String: Any] = ["ok": true, "items": page.items.map(notificationObject)]
            if let cursor = page.nextCursor { object["nextCursor"] = cursor }
            return bridgeJSON(object)
        default:
            throw NotificationFailure(kind: .invalidResponse, message: nil)
        }
        return bridgeJSON(["ok": true])
    } catch {
        return failureJSON(error)
    }
}

/// Items as `notificationResponse` returns them; `markerJson` is a saved marker or `""`.
public func notificationUnreadCount(_ itemsJson: String, _ markerJson: String) -> Int32 {
    let items = notificationItems(itemsJson)
    let marker = try? JSONDecoder().decode(NotificationSeenMarker.self, from: Data(markerJson.utf8))
    return Int32(NotificationSeen.unreadCount(items: items, seen: marker))
}

/// The marker to save when the panel opens, as JSON, or `""` when there are no items.
public func notificationSeenMarker(_ itemsJson: String) -> String {
    guard let marker = NotificationSeen.marker(newestOf: notificationItems(itemsJson)) else { return "" }
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    return (try? encoder.encode(marker)).map { String(decoding: $0, as: UTF8.self) } ?? ""
}

/// `dataJson` holds the push data / intent extras. Returns `{"ok":true,"houseId":"…","choreId"?,
/// "notificationId"?,"type"?}` or `{"ok":false}`.
public func notificationPushTarget(_ dataJson: String) -> String {
    let values = (try? JSONSerialization.jsonObject(with: Data(dataJson.utf8))) as? [String: Any] ?? [:]
    guard let target = PushTarget(data: values.compactMapValues { $0 as? String }) else {
        return bridgeJSON(["ok": false])
    }
    var object: [String: Any] = ["ok": true, "houseId": target.houseID]
    if let choreID = target.choreID { object["choreId"] = choreID }
    if let notificationID = target.notificationID { object["notificationId"] = notificationID }
    if let kind = target.kind { object["type"] = kind.wire }
    return bridgeJSON(object)
}

public func choreCanRemind(
    _ assignedToId: String, _ currentUserId: String, _ status: Int32, _ dueDate: String, _ nowEpochSeconds: Double
) -> Bool {
    ChoreReminderRules.canRemind(
        assignedToID: assignedToId, currentUserID: currentUserId, status: Int(status), dueDate: dueDate,
        now: Date(timeIntervalSince1970: nowEpochSeconds))
}

public func pushTokenRedacted(_ token: String) -> String { PushTokenLog.redacted(token) }

private func notificationItems(_ json: String) -> [HouseNotification] {
    (try? JSONDecoder().decode([HouseNotification].self, from: Data(json.utf8))) ?? []
}

/// The wire shape, so the list can be handed back to the functions above unchanged.
private func notificationObject(_ item: HouseNotification) -> [String: Any] {
    var object: [String: Any] = [
        "id": item.id,
        "type": item.kind.wire,
        "houseId": item.houseID,
        "senderUserId": item.senderUserID,
        "title": item.title,
        "message": item.message,
        "createdAt": item.createdAt,
    ]
    if let choreID = item.choreID { object["choreId"] = choreID }
    return object
}

private func failureJSON(_ failure: NotificationFailure) -> String {
    var object: [String: Any] = ["ok": false, "kind": failure.kind.rawValue]
    if let message = failure.message { object["message"] = message }
    return bridgeJSON(object)
}

/// `targetJson` is `notificationPushTarget`'s object; `contextJson` uses `PushRouteContext`'s property
/// names with `houseIDs` / `loadedChoreIDs` null while loading. Returns `{"step":"…","id"?:"…"}`
/// (`id` for `switchHouse` and `openChore`); an unreadable target is `drop`.
public func notificationPushRoute(_ targetJson: String, _ contextJson: String) -> String {
    func object(_ json: String) -> [String: Any] {
        (try? JSONSerialization.jsonObject(with: Data(json.utf8))) as? [String: Any] ?? [:]
    }
    let targetFields = object(targetJson)
    guard let houseID = targetFields["houseId"] as? String else { return bridgeJSON(["step": "drop"]) }
    var data = ["houseId": houseID]
    if let choreID = targetFields["choreId"] as? String { data["choreId"] = choreID }
    guard let target = PushTarget(data: data) else { return bridgeJSON(["step": "drop"]) }
    let fields = object(contextJson)
    let context = PushRouteContext(
        isSignedIn: fields["isSignedIn"] as? Bool ?? false,
        houseIDs: fields["houseIDs"] as? [String],
        selectedHouseID: fields["selectedHouseID"] as? String,
        isSwitchingHouse: fields["isSwitchingHouse"] as? Bool ?? false,
        isGameOpen: fields["isGameOpen"] as? Bool ?? false,
        isDashboardShown: fields["isDashboardShown"] as? Bool ?? false,
        loadedChoreIDs: (fields["loadedChoreIDs"] as? [String]).map(Set.init))
    switch PushRouting.next(target, in: context) {
    case .wait: return bridgeJSON(["step": "wait"])
    case .drop: return bridgeJSON(["step": "drop"])
    case .switchHouse(let id): return bridgeJSON(["step": "switchHouse", "id": id])
    case .showDashboard: return bridgeJSON(["step": "showDashboard"])
    case .openChore(let id): return bridgeJSON(["step": "openChore", "id": id])
    case .finished: return bridgeJSON(["step": "finished"])
    }
}
