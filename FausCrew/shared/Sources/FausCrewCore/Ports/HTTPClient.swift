import Foundation

public struct HTTPQueryItem: Equatable, Sendable {
    public let name: String
    public let value: String?

    public init(name: String, value: String?) {
        self.name = name
        self.value = value
    }
}

public struct HTTPRequest: Sendable {
    public let path: String
    public let method: String
    public let queryItems: [HTTPQueryItem]
    public let headers: [String: String]
    public let body: Data?

    public init(
        path: String,
        method: String,
        queryItems: [HTTPQueryItem] = [],
        headers: [String: String] = [:],
        body: Data? = nil
    ) {
        self.path = path
        self.method = method
        self.queryItems = queryItems
        self.headers = headers
        self.body = body
    }
}

public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let body: Data

    public init(statusCode: Int, headers: [String: String], body: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.body = body
    }
}

/// The current iOS service graph calls this port from the main actor. The
/// adapter performs network I/O asynchronously; the port does not own a session.
@MainActor
public protocol HTTPClient: AnyObject {
    func send(_ request: HTTPRequest) async throws -> HTTPResponse
}

public enum HTTPClientError: Error, Equatable, Sendable {
    case invalidURL
    case invalidResponse
}

/// Preserves the server's existing `message` / `error` envelope and raw-text
/// fallback. It never stores a request or its Authorization header.
public struct HTTPStatusFailure: Error, Equatable, Sendable {
    public let statusCode: Int
    public let message: String?

    public init(response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) {
        statusCode = response.statusCode

        if let envelope = try? decoder.decode(ErrorEnvelope.self, from: response.body) {
            message = envelope.message ?? envelope.error ?? "Request failed."
        } else if let text = String(data: response.body, encoding: .utf8)?
            .trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            message = text
        } else {
            message = nil
        }
    }

    private struct ErrorEnvelope: Decodable {
        let message: String?
        let error: String?
    }
}
