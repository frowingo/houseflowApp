import Foundation
import FausCrewCore

enum NetworkError: LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(String)    // 400 / 404 / 500 with { "error": "..." }
    case decodingError(Error)
    case unknown(Int)

    nonisolated static let genericMessage = "Something went wrong. Please try again."
    nonisolated static let sessionExpiredMessage = "Your session has expired. Please sign in again."

    var errorDescription: String? {
        switch self {
        case .invalidURL:           return Self.genericMessage
        case .unauthorized:         return Self.sessionExpiredMessage
        case .serverError(let msg): return msg
        case .decodingError:        return Self.genericMessage
        case .unknown:              return Self.genericMessage
        }
    }
}

@MainActor
final class NetworkService: NetworkServicing, HTTPRequestExecuting, HTTPClient {
    typealias RequestExecutor = URLSessionHTTPClient.RequestExecutor

    var onUnauthorized: ((_ rejectedToken: String) -> Void)?

    private let encoder: JSONEncoder
    private let decoder: JSONDecoder
    private let client: any HTTPClient
    private let rawClient: URLSessionHTTPClient

    convenience init() {
        self.init(baseURL: AppEnvironment.baseURL)
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
    func request<Body: Encodable, Success: Decodable & Sendable>(
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

    func authenticatedRequest<Body: Encodable, Success: Decodable & Sendable>(
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

    func authenticatedRequest<Body: Encodable, Success: Decodable & Sendable>(
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

    // MARK: - Authenticated multipart request

    /// The boundary comes from `form`, so Content-Type always carries it.
    func authenticatedMultipartRequest<Success: Decodable & Sendable>(
        path: String,
        method: String,
        form: MultipartFormData,
        successType: Success.Type,
        token: String
    ) async throws -> Success {
        let request = makeRequest(
            path: path,
            method: method,
            body: form.encoded(),
            contentType: form.contentType,
            token: token
        )
        return try await send(request, successType: successType)
    }

    // MARK: - Authenticated GET with query parameters

    func get<Success: Decodable & Sendable>(
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

    func get<Success: Decodable & Sendable>(
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
        contentType: String = "application/json",
        token: String? = nil
    ) -> HTTPRequest {
        var headers: [String: String] = ["Accept-Language": APILanguage.code]
        if body != nil { headers["Content-Type"] = contentType }
        if let token { headers["Authorization"] = "Bearer \(token)" }

        return HTTPRequest(
            path: path,
            method: method,
            queryItems: queryItems.map { HTTPQueryItem(name: $0.name, value: $0.value) },
            headers: headers,
            body: body
        )
    }

    private func send<Success: Decodable & Sendable>(
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
                return try await Self.decode(successType, from: response.body, decoder: decoder)
            } catch {
                throw NetworkError.decodingError(error)
            }
        } else {
            if response.statusCode == 401, let authorization = request.headers["Authorization"] {
                let token = String(authorization.dropFirst("Bearer ".count))
                onUnauthorized?(token)
                throw NetworkError.unauthorized
            }
            let failure = HTTPStatusFailure(response: response, decoder: decoder)
            if let message = failure.message { throw NetworkError.serverError(message) }
            throw NetworkError.unknown(failure.statusCode)
        }
    }

    @concurrent nonisolated
    private static func decode<Success: Decodable & Sendable>(
        _ type: Success.Type,
        from data: Data,
        decoder: JSONDecoder
    ) async throws -> Success {
        try decoder.decode(type, from: data)
    }

    /// Lets Core use cases share the existing iOS HTTP transport/session.
    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        try await client.send(request)
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
