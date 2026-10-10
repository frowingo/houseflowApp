import Foundation
import HouseFlowCore

@MainActor
final class URLSessionHTTPClient: HTTPClient {
    typealias RequestExecutor = @MainActor (URLRequest) async throws -> (Data, URLResponse)

    private let baseURL: URL
    private let requestExecutor: RequestExecutor

    init(baseURL: URL, session: URLSession? = nil, requestExecutor: RequestExecutor? = nil) {
        self.baseURL = baseURL
        if let requestExecutor {
            self.requestExecutor = requestExecutor
        } else {
            let resolvedSession = session ?? Self.makeDefaultSession()
            self.requestExecutor = { request in
                try await resolvedSession.data(for: request)
            }
        }
    }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        let urlRequest = try makeURLRequest(from: request)
        let (data, response) = try await executeRaw(urlRequest)
        guard let http = response as? HTTPURLResponse else {
            throw HTTPClientError.invalidResponse
        }

        let headers = http.allHeaderFields.reduce(into: [String: String]()) { result, header in
            result[String(describing: header.key).lowercased()] = String(describing: header.value)
        }
        return HTTPResponse(statusCode: http.statusCode, headers: headers, body: data)
    }

    /// Existing realtime admission calls this with a complete URLRequest.
    func executeRaw(_ request: URLRequest) async throws -> (Data, URLResponse) {
        try Task.checkCancellation()
        do {
            let response = try await requestExecutor(request)
            try Task.checkCancellation()
            return response
        } catch {
            try Task.checkCancellation()
            throw error
        }
    }

    private func makeURLRequest(from request: HTTPRequest) throws -> URLRequest {
        guard var components = URLComponents(
            url: baseURL.appendingPathComponent(request.path),
            resolvingAgainstBaseURL: true
        ) else { throw HTTPClientError.invalidURL }

        if !request.queryItems.isEmpty {
            components.queryItems = request.queryItems.map {
                URLQueryItem(name: $0.name, value: $0.value)
            }
        }

        guard let url = components.url else { throw HTTPClientError.invalidURL }

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = request.method
        urlRequest.httpBody = request.body
        for (name, value) in request.headers {
            urlRequest.setValue(value, forHTTPHeaderField: name)
        }
        return urlRequest
    }

    private static func makeDefaultSession() -> URLSession {
        let configuration = URLSessionConfiguration.default
        configuration.timeoutIntervalForRequest = 30
        return URLSession(configuration: configuration)
    }
}
