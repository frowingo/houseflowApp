import Foundation
import FausCrewCore

// Chore archive requests for Android. JSON in, JSON out; the JWT never crosses (Kotlin adds the
// Authorization header) and Core stays the only place that knows the path, the date wire format and
// how a `nextUrl` is validated.

/// action: `first` {houseId, fromEpochSeconds, toEpochSeconds} or `next` {nextUrl}. Returns
/// `{"ok":true,"path":"…","method":"…","query":[{"name","value"}],"percentEncodedQuery"?:"…"}`
/// (`percentEncodedQuery` only when set, and then used as is) or `{"ok":false,"kind":"invalidRequest"}`.
public func choreArchiveRequest(_ action: String, _ fieldsJson: String) -> String {
    let fields = (try? JSONSerialization.jsonObject(with: Data(fieldsJson.utf8))) as? [String: Any] ?? [:]
    func text(_ key: String) -> String { fields[key] as? String ?? "" }
    func date(_ key: String) -> Date { Date(timeIntervalSince1970: (fields[key] as? NSNumber)?.doubleValue ?? 0) }
    // The Authorization header is Kotlin's; only the path and query are used from Core's request.
    let jwt = ""
    do throws(ChoreArchiveFailure) {
        let request: HTTPRequest
        switch action {
        case "first":
            request = try ChoreArchiveWireContract.firstPageRequest(
                houseID: text("houseId"), from: date("fromEpochSeconds"), to: date("toEpochSeconds"), jwt: jwt)
        case "next":
            guard let next = ChoreArchiveWireContract.nextPageRequest(nextURL: text("nextUrl"), jwt: jwt) else {
                throw ChoreArchiveFailure(kind: .invalidRequest, message: nil)
            }
            request = next
        default:
            throw ChoreArchiveFailure(kind: .invalidRequest, message: nil)
        }
        var object: [String: Any] = [
            "ok": true,
            "path": request.path,
            "method": request.method,
            "query": request.queryItems.map { ["name": $0.name, "value": $0.value ?? ""] },
        ]
        if let query = request.percentEncodedQuery { object["percentEncodedQuery"] = query }
        return bridgeJSON(object)
    } catch {
        return failureJSON(error)
    }
}

/// Returns `{"ok":true,"chores":[…],"nextUrl"?:"…"}` (chores as the dashboard projection) or
/// `{"ok":false,"kind":"…","message"?:"…"}`.
public func choreArchiveResponse(_ status: Int32, _ body: String) -> String {
    let response = HTTPResponse(statusCode: Int(status), headers: [:], body: Data(body.utf8))
    do throws(ChoreArchiveFailure) {
        let page = try ChoreArchiveWireContract.page(response)
        var object: [String: Any] = ["ok": true, "chores": page.chores.map(choreObject)]
        if let next = page.nextURL { object["nextUrl"] = next }
        return bridgeJSON(object)
    } catch {
        return failureJSON(error)
    }
}

private func failureJSON(_ failure: ChoreArchiveFailure) -> String {
    var object: [String: Any] = ["ok": false, "kind": failure.kind.rawValue]
    if let message = failure.message { object["message"] = message }
    return bridgeJSON(object)
}
