import Foundation
import FausCrewCore

// `GET` / `PUT chore/catalog` for Android: one call per request body and one per response.
// Records cross as JSON in their full shape (server fields included), so Kotlin keeps the list
// exactly as the server sent it; validation, the request shape and patching stay in Core.

/// The PUT body for `recordsJson` (an array of records as Android holds them).
/// Returns `{"ok":true,"body":"…"}` or `{"ok":false,"kind":"validation","rule":"…","index":n}`.
public func choreCatalogRequestBody(_ recordsJson: String) -> String {
    guard let records = catalogRecords(recordsJson) else {
        return catalogJSON(["ok": false, "kind": ChoreCatalogFailure.Kind.validation.rawValue, "rule": "unreadable"])
    }
    do {
        let body = try ChoreCatalogWireContract.upsertBody(records)
        return catalogJSON(["ok": true, "body": String(data: body, encoding: .utf8) ?? "[]"])
    } catch {
        var object: [String: Any] = ["ok": false, "kind": ChoreCatalogFailure.Kind.validation.rawValue,
                                     "rule": String(describing: error.rule)]
        if let index = error.index { object["index"] = index }
        return catalogJSON(object)
    }
}

/// action: `list` or `upsert`. For `upsert`, `recordsJson` is what went to
/// `choreCatalogRequestBody` and `localJson` the list on screen, which comes back patched.
/// Returns `{"ok":true,"records":[…]}` or `{"ok":false,"kind":"…","message":"…"}`.
public func choreCatalogResponse(
    _ action: String, _ status: Int32, _ body: String, _ recordsJson: String, _ localJson: String
) -> String {
    let response = HTTPResponse(statusCode: Int(status), headers: [:], body: Data(body.utf8))
    do throws(ChoreCatalogFailure) {
        let records: [ChoreCatalogRecord]
        switch action {
        case "list":
            records = try ChoreCatalogWireContract.list(response: response)
        case "upsert":
            guard let sent = catalogRecords(recordsJson), let local = catalogRecords(localJson) else {
                throw ChoreCatalogFailure(kind: .invalidResponse, message: nil)
            }
            records = try ChoreCatalogWireContract.upsert(
                response: response,
                sent: ChoreCatalogWireContract.sentRecords(sent),
                local: local
            )
        default:
            throw ChoreCatalogFailure(kind: .invalidResponse, message: nil)
        }
        return catalogJSON(["ok": true, "records": records.map(catalogObject)])
    } catch {
        var object: [String: Any] = ["ok": false, "kind": error.kind.rawValue]
        if let message = error.message { object["message"] = message }
        return catalogJSON(object)
    }
}

private func catalogRecords(_ json: String) -> [ChoreCatalogRecord]? {
    try? JSONDecoder().decode([ChoreCatalogRecord].self, from: Data(json.utf8))
}

/// Every field, unlike the request encoding, which leaves the server's out.
private func catalogObject(_ record: ChoreCatalogRecord) -> [String: Any] {
    var object: [String: Any] = [
        "title": record.title,
        "description": record.description,
        "recurringInterval": record.recurringInterval,
        "level": record.level,
        "category": record.category,
        "isDeleted": record.isDeleted,
        "isSystem": record.isSystem,
    ]
    if let id = record.id { object["id"] = id }
    if let userId = record.userId { object["userId"] = userId }
    if let createdOn = record.createdOn { object["createdOn"] = createdOn }
    if let updatedOn = record.updatedOn { object["updatedOn"] = updatedOn }
    return object
}

private func catalogJSON(_ object: [String: Any]) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
          let string = String(data: data, encoding: .utf8) else { return "{\"ok\":false}" }
    return string
}
