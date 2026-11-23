import Foundation

/// Device registration, the house notification list and chore reminders. Paths are relative to
/// `/api/v1`. Both platforms' HTTP adapters add `Accept-Language`, so it is not set here.
public enum NotificationWireContract {
    public static let devicesPath = "notification/devices"
    public static let listPath = "notification"
    public static let maximumTokenLength = 4096
    public static let defaultPageSize = 20
    public static let maximumPageSize = 50

    /// `POST notification/devices`. A blank or oversized token is refused here instead of sending
    /// a request the server would answer with 400.
    public static func registerDeviceRequest(
        token: String, platform: PushPlatform, jwt: String
    ) throws(NotificationFailure) -> HTTPRequest {
        try deviceRequest(method: "POST", body: DeviceBody(token: try prepared(token), platform: platform.rawValue), jwt: jwt)
    }

    /// `DELETE notification/devices`.
    public static func unregisterDeviceRequest(token: String, jwt: String) throws(NotificationFailure) -> HTTPRequest {
        try deviceRequest(method: "DELETE", body: DeviceBody(token: try prepared(token), platform: nil), jwt: jwt)
    }

    /// `GET notification`. `limit` is sent only when given, clamped to what the server accepts.
    public static func listRequest(houseID: String, before: String?, limit: Int?, jwt: String) -> HTTPRequest {
        var query = [HTTPQueryItem(name: "houseId", value: houseID)]
        if let before, !before.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            query.append(HTTPQueryItem(name: "before", value: before))
        }
        if let limit {
            query.append(HTTPQueryItem(name: "limit", value: String(min(maximumPageSize, max(1, limit)))))
        }
        return HTTPRequest(path: listPath, method: "GET", queryItems: query, headers: authorization(jwt))
    }

    /// `POST chore/{id}/remind`, without a body.
    public static func remindRequest(choreID: String, jwt: String) -> HTTPRequest {
        HTTPRequest(path: "chore/\(choreID)/remind", method: "POST", headers: authorization(jwt))
    }

    /// 2xx, unless the body says `success: false`.
    public static func deviceAccepted(_ response: HTTPResponse) throws(NotificationFailure) {
        try requireSuccess(response)
        let acknowledgement = try? JSONDecoder().decode(Acknowledgement.self, from: response.body)
        if acknowledgement?.success == false { throw NotificationFailure(kind: .invalidResponse, message: nil) }
    }

    public static func page(
        _ response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()
    ) throws(NotificationFailure) -> NotificationPage {
        try requireSuccess(response, decoder: decoder)
        guard let envelope = try? decoder.decode(PageEnvelope.self, from: response.body),
              envelope.success != false, let data = envelope.data else {
            throw NotificationFailure(kind: .invalidResponse, message: nil)
        }
        let cursor = data.nextCursor.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        return NotificationPage(items: data.items, nextCursor: cursor)
    }

    /// Any 2xx; the body is not inspected.
    public static func reminded(_ response: HTTPResponse) throws(NotificationFailure) {
        try requireSuccess(response)
    }

    private static func prepared(_ token: String) throws(NotificationFailure) -> String {
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, trimmed.count <= maximumTokenLength else {
            throw NotificationFailure(kind: .invalidRequest, message: nil)
        }
        return trimmed
    }

    private static func deviceRequest(method: String, body: DeviceBody, jwt: String) throws(NotificationFailure) -> HTTPRequest {
        let data: Data
        do {
            data = try JSONEncoder().encode(body)
        } catch {
            // Encoding plain strings does not fail.
            preconditionFailure("DeviceBody encoding failed: \(error)")
        }
        var headers = authorization(jwt)
        headers["Content-Type"] = "application/json"
        return HTTPRequest(path: devicesPath, method: method, headers: headers, body: data)
    }

    private static func authorization(_ jwt: String) -> [String: String] {
        ["Authorization": "Bearer \(jwt)"]
    }

    private static func requireSuccess(_ response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) throws(NotificationFailure) {
        guard (200...299).contains(response.statusCode) else {
            throw NotificationFailure(status: HTTPStatusFailure(response: response, decoder: decoder))
        }
    }

    private struct DeviceBody: Encodable {
        let token: String
        let platform: String?
    }

    private struct Acknowledgement: Decodable {
        let success: Bool?
    }

    private struct PageEnvelope: Decodable {
        struct Payload: Decodable {
            let items: [HouseNotification]
            let nextCursor: String?

            /// One malformed item is dropped instead of failing the page.
            init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                var list = try values.nestedUnkeyedContainer(forKey: .items)
                var items: [HouseNotification] = []
                while !list.isAtEnd {
                    if let item = try? list.decode(HouseNotification.self) {
                        items.append(item)
                    } else {
                        _ = try? list.decode(Skipped.self)
                    }
                }
                self.items = items
                nextCursor = try values.decodeIfPresent(String.self, forKey: .nextCursor)
            }

            private enum CodingKeys: String, CodingKey { case items, nextCursor }
            private struct Skipped: Decodable {}
        }

        let success: Bool?
        let data: Payload?
    }
}

/// A failed notification request, with the server's localized message when it sent one.
public struct NotificationFailure: Error, Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        /// 400: a rule was broken (the message says which). Also a blank or oversized token before sending.
        case invalidRequest
        /// 401: the session flow takes over.
        case unauthorized
        /// 403: not a member of the house.
        case notMember
        /// 404: the house or chore is gone.
        case notFound
        /// 409: this sender already reminded this chore (permanent).
        case alreadyReminded
        /// Any other status.
        case server
        /// A 2xx body that does not match the contract.
        case invalidResponse
    }

    public let kind: Kind
    /// Shown to the user as is (the server localizes it). `nil` when the server sent none.
    public let message: String?

    public init(kind: Kind, message: String?) {
        self.kind = kind
        self.message = message.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }

    public init(status: HTTPStatusFailure) {
        let kind: Kind = switch status.statusCode {
        case 400: .invalidRequest
        case 401: .unauthorized
        case 403: .notMember
        case 404: .notFound
        case 409: .alreadyReminded
        default: .server
        }
        self.init(kind: kind, message: status.message)
    }
}
