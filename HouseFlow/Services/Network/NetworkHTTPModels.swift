import Foundation

@MainActor
protocol HTTPRequestExecuting: AnyObject {
    func execute(_ request: URLRequest) async throws -> NetworkHTTPResponse
}

struct NetworkHTTPResponse: Sendable {
    let data: Data
    let statusCode: Int
    /// Lowercase header names so consumers do not depend on server casing.
    let headers: [String: String]

    init(data: Data, response: HTTPURLResponse) {
        self.data = data
        statusCode = response.statusCode
        headers = response.allHeaderFields.reduce(into: [:]) { result, header in
            result[String(describing: header.key).lowercased()] = String(describing: header.value)
        }
    }
}

struct NetworkHTTPFailure: Error, LocalizedError, Sendable {
    let statusCode: Int
    let headers: [String: String]
    let body: Data

    init(response: NetworkHTTPResponse) {
        statusCode = response.statusCode
        headers = response.headers
        body = response.data
    }

    var errorDescription: String? {
        if let error = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] {
            return error["message"] as? String ?? error["error"] as? String ?? "Request failed."
        }
        return "Unexpected status code: \(statusCode)."
    }

    /// Both delta-seconds and HTTP-date are legal. Caller supplies its clock.
    func retryAfterSeconds(at now: Date) -> TimeInterval? {
        guard let value = headers["retry-after"] else { return nil }
        let text = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if let seconds = Double(text), seconds.isFinite, seconds >= 0 { return seconds }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        guard let date = formatter.date(from: text) else { return nil }
        return max(0, date.timeIntervalSince(now))
    }
}
