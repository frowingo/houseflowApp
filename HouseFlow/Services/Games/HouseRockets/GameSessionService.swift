import Foundation

/// Shares HTTP/keychain dependencies with the app; never creates a network graph.
@MainActor
protocol GameSessionServicing: AnyObject {
    func ensureHouseRocketsSession(houseID: String) async throws -> GameSessionDTO
    func discoverHouseRocketsSession(houseID: String) async throws -> GameSessionDTO
    func houseRocketsResult(sessionID: String) async throws -> HouseRocketsResultDTO
    func realtimeRequest(sessionID: String) throws -> URLRequest
}

struct GameEndpointBuilder {
    let baseURL: URL

    func request(components: [String], method: String, token: String,
                 queryItems: [URLQueryItem] = [], body: Data? = nil) throws -> URLRequest {
        guard !token.isEmpty, token.trimmingCharacters(in: .whitespacesAndNewlines) == token else {
            throw GameRealtimeError.authenticationRequired
        }
        guard let scheme = baseURL.scheme?.lowercased(), ["https", "http"].contains(scheme),
              baseURL.host != nil, baseURL.user == nil, baseURL.password == nil,
              baseURL.query == nil, baseURL.fragment == nil else { throw NetworkError.invalidURL }
        var url = baseURL
        for component in components {
            try GameRealtimeCodec.validateIdentifier(component)
            guard component != ".", component != "..",
                  !component.contains(where: { "/\\?#".contains($0) }) else {
                throw GameRealtimeError.invalidIdentifier
            }
            url.appendPathComponent(component)
        }
        guard var values = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }
        if !queryItems.isEmpty { values.queryItems = queryItems }
        guard let endpoint = values.url else { throw NetworkError.invalidURL }
        var request = URLRequest(url: endpoint)
        request.httpMethod = method
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        if let body {
            request.httpBody = body
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        }
        return request
    }

    func realtimeRequest(sessionID: String, token: String) throws -> URLRequest {
        var request = try self.request(components: ["game", sessionID, "realtime"], method: "GET",
                                       token: token, queryItems: [.init(name: "protocolVersion", value: "2")])
        guard let url = request.url,
              var values = URLComponents(url: url, resolvingAgainstBaseURL: false) else {
            throw NetworkError.invalidURL
        }
        values.scheme = values.scheme?.lowercased() == "https" ? "wss" : "ws"
        guard let endpoint = values.url else { throw NetworkError.invalidURL }
        request.url = endpoint
        return request
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

    func ensureHouseRocketsSession(houseID: String) async throws -> GameSessionDTO {
        try GameRealtimeCodec.validateIdentifier(houseID)
        let request = try endpoints.request(components: ["game", "houseRockets", "session"],
            method: "PUT", token: token(), body: JSONEncoder().encode(EnsureGameSessionRequest(houseId: houseID)))
        let session: GameSessionDTO = try await send(request)
        try validate(session, houseID: houseID)
        return session
    }

    func discoverHouseRocketsSession(houseID: String) async throws -> GameSessionDTO {
        try GameRealtimeCodec.validateIdentifier(houseID)
        let request = try endpoints.request(components: ["game", "houseRockets", "session"],
            method: "GET", token: token(), queryItems: [.init(name: "houseId", value: houseID)])
        let session: GameSessionDTO = try await send(request)
        try validate(session, houseID: houseID)
        return session
    }

    func houseRocketsResult(sessionID: String) async throws -> HouseRocketsResultDTO {
        let request = try endpoints.request(components: ["game", sessionID, "result"], method: "GET", token: token())
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
        guard (200..<300).contains(response.statusCode) else { throw NetworkHTTPFailure(response: response) }
        let envelope = try GameRealtimeCodec.makeDecoder().decode(GameHTTPEnvelope<Value>.self, from: response.data)
        guard envelope.success, let value = envelope.data else { throw GameRealtimeError.invalidResponse }
        return value
    }
}
