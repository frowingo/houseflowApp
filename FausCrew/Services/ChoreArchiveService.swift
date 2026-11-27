import Foundation
import FausCrewCore

@MainActor
protocol ChoreArchiveServicing: AnyObject {
    /// Page one of the chores closed in `[from, to)`.
    func firstPage(houseID: String, from: Date, to: Date) async throws -> ChoreArchivePage
    /// The page behind a previous page's `nextURL`, which is used as the server gave it.
    func nextPage(nextURL: String) async throws -> ChoreArchivePage
}

/// `GET chore/archive` over the shared HTTP transport. Wire rules and failure kinds live in Core
/// (`ChoreArchiveWireContract`); this adapter only adds the session.
@MainActor
final class ChoreArchiveService: ChoreArchiveServicing {
    private let http: any HTTPClient
    private let keychain: any KeychainStoring
    private let onUnauthorized: (_ rejectedToken: String) -> Void

    /// `onUnauthorized` hands a rejected JWT to the app's session handling, like `NetworkService`.
    init(http: any HTTPClient, keychain: any KeychainStoring, onUnauthorized: @escaping (String) -> Void = { _ in }) {
        self.http = http
        self.keychain = keychain
        self.onUnauthorized = onUnauthorized
    }

    func firstPage(houseID: String, from: Date, to: Date) async throws -> ChoreArchivePage {
        let jwt = try token()
        return try await page(try ChoreArchiveWireContract.firstPageRequest(houseID: houseID, from: from, to: to, jwt: jwt), jwt: jwt)
    }

    func nextPage(nextURL: String) async throws -> ChoreArchivePage {
        let jwt = try token()
        guard let request = ChoreArchiveWireContract.nextPageRequest(nextURL: nextURL, jwt: jwt) else {
            throw ChoreArchiveFailure(kind: .invalidRequest, message: nil)
        }
        return try await page(request, jwt: jwt)
    }

    private func page(_ request: HTTPRequest, jwt: String) async throws -> ChoreArchivePage {
        let response = try await send(request)
        do {
            return try ChoreArchiveWireContract.page(response)
        } catch {
            throw rejected(error, jwt: jwt)
        }
    }

    private func token() throws -> String {
        guard let jwt = keychain.authToken else { throw ChoreArchiveFailure(kind: .unauthorized, message: nil) }
        return jwt
    }

    /// The server localizes its messages from `Accept-Language`, which the raw transport does not add.
    private func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var headers = request.headers
        headers["Accept-Language"] = APILanguage.code
        return try await http.send(HTTPRequest(
            path: request.path,
            method: request.method,
            queryItems: request.queryItems,
            headers: headers,
            body: request.body,
            percentEncodedQuery: request.percentEncodedQuery
        ))
    }

    private func rejected(_ error: any Error, jwt: String) -> any Error {
        if (error as? ChoreArchiveFailure)?.kind == .unauthorized { onUnauthorized(jwt) }
        return error
    }
}
