import Foundation
import FausCrewCore

/// `GET` / `PUT chore/catalog` over the shared HTTP transport. Wire rules, validation and
/// patching live in Core (`ChoreCatalogWireContract`); this adapter only adds the session.
@MainActor
final class ChoreCatalogService: ChoreCatalogServicing {
    private let http: any HTTPClient
    private let keychain: any KeychainStoring

    init(http: any HTTPClient, keychain: any KeychainStoring) {
        self.http = http
        self.keychain = keychain
    }

    func fetchCatalog() async throws -> [ChoreCatalogRecord] {
        let response = try await send(method: "GET", body: nil)
        return try ChoreCatalogWireContract.list(response: response)
    }

    func upsertCatalog(_ records: [ChoreCatalogRecord], local: [ChoreCatalogRecord]) async throws -> [ChoreCatalogRecord] {
        let body: Data
        do {
            body = try ChoreCatalogWireContract.upsertBody(records)
        } catch {
            // The UI applies the same rules first, so this is a programming error, not user input.
            throw ChoreCatalogFailure(kind: .validation, message: nil)
        }
        let response = try await send(method: "PUT", body: body)
        return try ChoreCatalogWireContract.upsert(
            response: response,
            sent: ChoreCatalogWireContract.sentRecords(records),
            local: local
        )
    }

    private func send(method: String, body: Data?) async throws -> HTTPResponse {
        guard let token = keychain.authToken else {
            throw ChoreCatalogFailure(kind: .unauthorized, message: nil)
        }
        var headers = ["Accept-Language": APILanguage.code, "Authorization": "Bearer \(token)"]
        if body != nil { headers["Content-Type"] = "application/json" }
        do {
            return try await http.send(HTTPRequest(
                path: ChoreCatalogWireContract.path,
                method: method,
                headers: headers,
                body: body
            ))
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            // No response at all (offline, timeout): the UI shows its own connection message.
            throw ChoreCatalogFailure(kind: .server, message: nil)
        }
    }
}
