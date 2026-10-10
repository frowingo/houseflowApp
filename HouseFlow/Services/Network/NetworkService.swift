import Foundation
import HouseFlowCore

enum NetworkError: LocalizedError {
    case invalidURL
    case serverError(String)    // 400 / 404 / 500 with { "error": "..." }
    case decodingError(Error)
    case unknown(Int)

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return "Invalid URL."
        case .serverError(let msg): return msg
        case .decodingError(let e): return "Response decoding failed: \(e.localizedDescription)"
        case .unknown(let code):    return "Unexpected status code: \(code)."
        }
    }
}

@MainActor
final class NetworkService: NetworkServicing, HTTPRequestExecuting {
    typealias RequestExecutor = URLSessionHTTPClient.RequestExecutor

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let client: any HTTPClient
    private let rawClient: URLSessionHTTPClient

    convenience init() {
        self.init(baseURL: AppEnvironment.current.baseURL)
    }

    init(
        baseURL: URL,
        session: URLSession? = nil,
        encoder: JSONEncoder = JSONEncoder(),
        decoder: JSONDecoder = JSONDecoder(),
        requestExecutor: RequestExecutor? = nil,
        httpClient: (any HTTPClient)? = nil
    ) {
        self.encoder = encoder
        self.decoder = decoder
        let adapter = URLSessionHTTPClient(
            baseURL: baseURL,
            session: session,
            requestExecutor: requestExecutor
        )
        rawClient = adapter
        client = httpClient ?? adapter
    }

    // MARK: - Core request

    /// Sends a request and returns the decoded success response.
    /// - 200...399 → decoded as `Success`
    /// - 400 / 404 / 500 → decoded as `{ "error": "..." }` → throws `NetworkError.serverError`
    func request<Body: Encodable, Success: Decodable>(
        path: String,
        method: String = "POST",
        body: Body,
        successType: Success.Type
    ) async throws -> Success {
        let request = makeRequest(
            path: path,
            method: method,
            body: try encoder.encode(body)
        )
        return try await send(request, successType: successType)
    }

    // MARK: - Authenticated request (adds Bearer token)

    func authenticatedRequest<Body: Encodable, Success: Decodable>(
        path: String,
        method: String = "POST",
        body: Body,
        successType: Success.Type,
        token: String
    ) async throws -> Success {
        let request = makeRequest(
            path: path,
            method: method,
            body: try encoder.encode(body),
            token: token
        )
        return try await send(request, successType: successType)
    }

    // MARK: - Authenticated request with query parameters and body

    func authenticatedRequest<Body: Encodable, Success: Decodable>(
        path: String,
        method: String = "PUT",
        queryItems: [URLQueryItem],
        body: Body,
        successType: Success.Type,
        token: String
    ) async throws -> Success {
        let request = makeRequest(
            path: path,
            method: method,
            queryItems: queryItems,
            body: try encoder.encode(body),
            token: token
        )
        return try await send(request, successType: successType)
    }

    // MARK: - Authenticated GET with query parameters

    func get<Success: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        successType: Success.Type
    ) async throws -> Success {
        let request = makeRequest(
            path: path,
            method: "GET",
            queryItems: queryItems
        )
        return try await send(request, successType: successType)
    }

    func get<Success: Decodable>(
        path: String,
        queryItems: [URLQueryItem] = [],
        successType: Success.Type,
        token: String
    ) async throws -> Success {
        let request = makeRequest(
            path: path,
            method: "GET",
            queryItems: queryItems,
            token: token
        )
        return try await send(request, successType: successType)
    }

    private func makeRequest(
        path: String,
        method: String,
        queryItems: [URLQueryItem] = [],
        body: Data? = nil,
        token: String? = nil
    ) -> HTTPRequest {
        var headers: [String: String] = [:]
        if body != nil { headers["Content-Type"] = "application/json" }
        if let token { headers["Authorization"] = "Bearer \(token)" }

        return HTTPRequest(
            path: path,
            method: method,
            queryItems: queryItems.map { HTTPQueryItem(name: $0.name, value: $0.value) },
            headers: headers,
            body: body
        )
    }

    private func send<Success: Decodable>(
        _ request: HTTPRequest,
        successType: Success.Type
    ) async throws -> Success {
        let response: HTTPResponse
        do {
            response = try await client.send(request)
        } catch HTTPClientError.invalidURL {
            throw NetworkError.invalidURL
        } catch HTTPClientError.invalidResponse {
            throw NetworkError.unknown(-1)
        }

        if (200...399).contains(response.statusCode) {
            do {
                return try decoder.decode(Success.self, from: response.body)
            } catch {
                throw NetworkError.decodingError(error)
            }
        } else {
            let failure = HTTPStatusFailure(response: response, decoder: decoder)
            if let message = failure.message { throw NetworkError.serverError(message) }
            throw NetworkError.unknown(failure.statusCode)
        }
    }

    /// Raw response path for clients that need status and headers (e.g. realtime admission).
    /// Existing decoded request methods keep their established error-message behavior.
    func execute(_ request: URLRequest) async throws -> NetworkHTTPResponse {
        try Task.checkCancellation()
        do {
            let (data, response) = try await rawClient.executeRaw(request)
            try Task.checkCancellation()
            guard let http = response as? HTTPURLResponse else { throw NetworkError.unknown(-1) }
            return NetworkHTTPResponse(data: data, response: http)
        } catch {
            try Task.checkCancellation()
            throw error
        }
    }

}
