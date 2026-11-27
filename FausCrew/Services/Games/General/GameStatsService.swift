import Foundation
import FausCrewCore

@MainActor
protocol GameStatsServicing: AnyObject {
    /// The house's per-game standings, in the backend's order.
    func stats(houseID: String) async throws -> [HouseGameStats]
}

/// `GET game/stats` over the shared HTTP transport. Wire rules and failure kinds live in Core
/// (`GameStatsWireContract`); this adapter only adds the session and the language.
@MainActor
final class GameStatsService: GameStatsServicing {
    private let http: any HTTPClient
    private let keychain: any KeychainStoring
    private let onUnauthorized: (_ rejectedToken: String) -> Void

    /// `onUnauthorized` hands a rejected JWT to the app's session handling, like `NetworkService`.
    init(http: any HTTPClient, keychain: any KeychainStoring, onUnauthorized: @escaping (String) -> Void = { _ in }) {
        self.http = http
        self.keychain = keychain
        self.onUnauthorized = onUnauthorized
    }

    func stats(houseID: String) async throws -> [HouseGameStats] {
        guard let jwt = keychain.authToken else { throw GameStatsFailure(kind: .unauthorized, message: nil) }
        let request = try GameStatsWireContract.request(houseID: houseID, jwt: jwt)
        var headers = request.headers
        // The server localizes its messages from `Accept-Language`, which the raw transport does not add.
        headers["Accept-Language"] = APILanguage.code
        let response = try await http.send(HTTPRequest(
            path: request.path,
            method: request.method,
            queryItems: request.queryItems,
            headers: headers,
            body: request.body,
            percentEncodedQuery: request.percentEncodedQuery
        ))
        do {
            return try GameStatsWireContract.decode(response)
        } catch {
            if error.kind == .unauthorized { onUnauthorized(jwt) }
            throw error
        }
    }
}
