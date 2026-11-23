import Foundation
import FausCrewCore

@MainActor
protocol NotificationServicing: AnyObject {
    /// One page of the house's notification list; `before` is the previous page's `nextCursor`.
    func list(houseID: String, before: String?) async throws -> NotificationPage
    /// `POST chore/{id}/remind`.
    func remind(choreID: String) async throws
}

/// `GET notification` and `POST chore/{id}/remind` over the shared HTTP transport. Wire rules and
/// failure kinds live in Core (`NotificationWireContract`); this adapter only adds the session.
@MainActor
final class NotificationService: NotificationServicing {
    static let pageSize = NotificationWireContract.defaultPageSize

    private let http: any HTTPClient
    private let keychain: any KeychainStoring
    private let onUnauthorized: (_ rejectedToken: String) -> Void

    /// `onUnauthorized` hands a rejected JWT to the app's session handling, like `NetworkService`.
    init(http: any HTTPClient, keychain: any KeychainStoring, onUnauthorized: @escaping (String) -> Void = { _ in }) {
        self.http = http
        self.keychain = keychain
        self.onUnauthorized = onUnauthorized
    }

    func list(houseID: String, before: String?) async throws -> NotificationPage {
        let jwt = try token()
        let response = try await send(
            NotificationWireContract.listRequest(houseID: houseID, before: before, limit: Self.pageSize, jwt: jwt)
        )
        do {
            return try NotificationWireContract.page(response)
        } catch {
            throw rejected(error, jwt: jwt)
        }
    }

    func remind(choreID: String) async throws {
        let jwt = try token()
        let response = try await send(NotificationWireContract.remindRequest(choreID: choreID, jwt: jwt))
        do {
            try NotificationWireContract.reminded(response)
        } catch {
            throw rejected(error, jwt: jwt)
        }
    }

    private func token() throws -> String {
        guard let jwt = keychain.authToken else { throw NotificationFailure(kind: .unauthorized, message: nil) }
        return jwt
    }

    /// The server localizes its messages from `Accept-Language`, which the raw transport does not add.
    private func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        var headers = request.headers
        headers["Accept-Language"] = APILanguage.code
        return try await http.send(HTTPRequest(
            path: request.path, method: request.method, queryItems: request.queryItems, headers: headers, body: request.body
        ))
    }

    private func rejected(_ error: any Error, jwt: String) -> any Error {
        if (error as? NotificationFailure)?.kind == .unauthorized { onUnauthorized(jwt) }
        return error
    }
}
