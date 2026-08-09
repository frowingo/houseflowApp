import Foundation

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

final class NetworkService {
    static let shared = NetworkService()

    private let session: URLSession
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    private init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        self.session = URLSession(configuration: config)
        self.encoder = JSONEncoder()
        self.decoder = JSONDecoder()
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
        let request = try makeRequest(
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
        let request = try makeRequest(
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
        let request = try makeRequest(
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
        let request = try makeRequest(
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
        let request = try makeRequest(
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
    ) throws -> URLRequest {
        guard var components = URLComponents(
            url: AppEnvironment.current.baseURL.appendingPathComponent(path),
            resolvingAgainstBaseURL: true
        ) else { throw NetworkError.invalidURL }

        if !queryItems.isEmpty {
            components.queryItems = queryItems
        }

        guard let url = components.url else { throw NetworkError.invalidURL }

        var request = URLRequest(url: url)
        request.httpMethod = method

        if let body {
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            request.httpBody = body
        }

        if let token {
            request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }

        return request
    }

    private func send<Success: Decodable>(
        _ request: URLRequest,
        successType: Success.Type
    ) async throws -> Success {
        let (data, response) = try await session.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw NetworkError.unknown(-1)
        }

        if (200...399).contains(http.statusCode) {
            do {
                return try decoder.decode(Success.self, from: data)
            } catch {
                throw NetworkError.decodingError(error)
            }
        } else {
            if let errorBody = try? decoder.decode(APIErrorResponse.self, from: data) {
                throw NetworkError.serverError(errorBody.message ?? errorBody.error ?? "Request failed.")
            }
            if let errorMessage = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
               !errorMessage.isEmpty {
                throw NetworkError.serverError(errorMessage)
            }
            throw NetworkError.unknown(http.statusCode)
        }
    }
}

// MARK: - Shared error response shape

struct APIErrorResponse: Decodable {
    let error: String?
    let message: String?
}
