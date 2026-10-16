import Foundation
import HouseFlowCore

/// Shares HTTP/keychain dependencies with the app; never creates a network graph.
@MainActor
protocol GameSessionServicing: AnyObject {
    func gameCatalog(houseID: String) async throws -> GameCatalog
    func ensureHouseRocketsSession(houseID: String) async throws -> GameSessionDTO
    func discoverHouseRocketsSession(houseID: String) async throws -> GameSessionDTO
    func houseRocketsResult(sessionID: String) async throws -> HouseRocketsResultDTO
    func realtimeRequest(sessionID: String) throws -> URLRequest
}

/// Turns a Core `GameRoute` into a URLRequest; route names live in HouseFlowCore.
struct GameEndpointBuilder {
    let baseURL: URL

    func request(_ route: GameRoute, token: String, body: Data? = nil) throws -> URLRequest {
        guard !token.isEmpty, token.trimmingCharacters(in: .whitespacesAndNewlines) == token else {
            throw GameRealtimeError.authenticationRequired
        }
        guard let scheme = baseURL.scheme?.lowercased(), ["https", "http"].contains(scheme),
              baseURL.host != nil, baseURL.user == nil, baseURL.password == nil,
              baseURL.query == nil, baseURL.fragment == nil else { throw NetworkError.invalidURL }
        var url = baseURL
        for component in route.pathComponents {
            do { try GameWireContract.validateIdentifier(component) }
            catch { throw GameRealtimeError.invalidIdentifier }
            url.appendPathComponent(component)
        }
        guard var values = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }
        let queryItems = route.queryItems.map { URLQueryItem(name: $0.name, value: $0.value) }
        if !queryItems.isEmpty { values.queryItems = queryItems }
        if route.isRealtime { values.scheme = values.scheme?.lowercased() == "https" ? "wss" : "ws" }
        guard let endpoint = values.url else { throw NetworkError.invalidURL }
        var request = URLRequest(url: endpoint)
        request.httpMethod = route.method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    func realtimeRequest(sessionID: String, token: String) throws -> URLRequest {
        try request(.realtime(sessionId: sessionID), token: token)
    }
}

@MainActor
final class GameSessionService: GameSessionServicing {
    private let network: any HTTPRequestExecuting
    private let keychain: any KeychainStoring
    private let endpoints: GameEndpointBuilder

    init(network: any HTTPRequestExecuting, keychain: any KeychainStoring, baseURL: URL) {
        self.network = network
        self.keychain = keychain
        endpoints = GameEndpointBuilder(baseURL: baseURL)
    }

    func gameCatalog(houseID: String) async throws -> GameCatalog {
        try GameRealtimeCodec.validateIdentifier(houseID)
        let request = try endpoints.request(.catalog(houseId: houseID), token: token())
        try Task.checkCancellation()
        let response = try await network.execute(request)
        try Task.checkCancellation()
        guard (200..<300).contains(response.statusCode) else { throw NetworkHTTPFailure(response: response) }
        return try GameWireContract.decodeCatalog(houseId: houseID, response: HTTPResponse(
            statusCode: response.statusCode, headers: response.headers, body: response.data))
    }

    func ensureHouseRocketsSession(houseID: String) async throws -> GameSessionDTO {
        try GameRealtimeCodec.validateIdentifier(houseID)
        let request = try endpoints.request(.ensureSession(gameKey: GameKey.houseRockets), token: token(),
                                            body: GameWireContract.ensureSessionBody(houseId: houseID))
        let session: GameSessionDTO = try await send(request)
        try validate(session, houseID: houseID)
        return session
    }

    func discoverHouseRocketsSession(houseID: String) async throws -> GameSessionDTO {
        try GameRealtimeCodec.validateIdentifier(houseID)
        let request = try endpoints.request(.discoverSession(gameKey: GameKey.houseRockets, houseId: houseID),
                                            token: token())
        let session: GameSessionDTO = try await send(request)
        try validate(session, houseID: houseID)
        return session
    }

    func houseRocketsResult(sessionID: String) async throws -> HouseRocketsResultDTO {
        try GameRealtimeCodec.validateIdentifier(sessionID)
        let request = try endpoints.request(.result(sessionId: sessionID), token: token())
        let result: HouseRocketsResultDTO = try await send(request)
        try GameRealtimeCodec.validateCompatibility(protocolVersion: result.protocolVersion,
            courseVersion: result.courseVersion, gameKey: result.gameKey)
        guard result.sessionId == sessionID else { throw GameRealtimeError.unexpectedSession }
        return result
    }

    func realtimeRequest(sessionID: String) throws -> URLRequest {
        try endpoints.realtimeRequest(sessionID: sessionID, token: token())
    }

    private func token() throws -> String {
        guard let token = keychain.authToken else { throw GameRealtimeError.authenticationRequired }
        return token
    }

    private func validate(_ session: GameSessionDTO, houseID: String) throws {
        try GameRealtimeCodec.validateCompatibility(protocolVersion: session.protocolVersion, gameKey: session.gameKey)
        guard session.houseId == houseID, !session.sessionId.isEmpty else { throw GameRealtimeError.unexpectedSession }
    }

    private func send<Value: Decodable>(_ request: URLRequest) async throws -> Value {
        try Task.checkCancellation()
        let response = try await network.execute(request)
        try Task.checkCancellation()
        guard (200..<300).contains(response.statusCode) else {
            // A closed game must not look like a retryable conflict; an active
            // session is still returned with 2xx, so only new sessions see this.
            if GameHTTPError(statusCode: response.statusCode, body: response.data).isGameUnavailable {
                throw GameRealtimeError.gameUnavailable
            }
            throw NetworkHTTPFailure(response: response)
        }
        let envelope = try GameRealtimeCodec.makeDecoder().decode(GameHTTPEnvelope<Value>.self, from: response.data)
        guard envelope.success, let value = envelope.data else { throw GameRealtimeError.invalidResponse }
        return value
    }
}
