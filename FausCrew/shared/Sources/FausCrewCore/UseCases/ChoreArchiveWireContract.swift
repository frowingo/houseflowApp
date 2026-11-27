import Foundation

/// `GET chore/archive`: closed chores by date range, in pages. Paths are relative to `/api/v1`.
/// Both platforms' HTTP adapters add `Accept-Language`, so it is not set here.
public enum ChoreArchiveWireContract {
    public static let path = "chore/archive"
    /// What the server returns per page. Never sent; the server owns it.
    public static let pageSize = 10

    private static let nextURLPrefix = "/api/v1/"

    /// The first page of `[from, to)`. Dates go out as UTC with a `Z`, so no `+` offset has to
    /// survive URL encoding. An empty or reversed range is refused here instead of sending a
    /// request the server would answer with 400.
    public static func firstPageRequest(
        houseID: String, from: Date, to: Date, jwt: String
    ) throws(ChoreArchiveFailure) -> HTTPRequest {
        let house = houseID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !house.isEmpty, from < to else { throw ChoreArchiveFailure(kind: .invalidRequest, message: nil) }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime]
        formatter.timeZone = TimeZone(identifier: "UTC")
        return HTTPRequest(
            path: path,
            method: "GET",
            queryItems: [
                HTTPQueryItem(name: "houseId", value: house),
                HTTPQueryItem(name: "from", value: formatter.string(from: from)),
                HTTPQueryItem(name: "to", value: formatter.string(from: to)),
            ],
            headers: authorization(jwt)
        )
    }

    /// The next page from the server's `nextUrl`, a host-less path such as
    /// `/api/v1/chore/archive?cursor=...&from=...`. The query is never parsed or re-encoded: the
    /// cursor is base64, so a `+` or `/` in it must reach the server byte for byte. Anything that is
    /// not a plain relative path plus a well-formed query gives `nil`, because
    /// `URLComponents.percentEncodedQuery` traps on invalid input.
    public static func nextPageRequest(nextURL: String, jwt: String) -> HTTPRequest? {
        guard nextURL.hasPrefix(nextURLPrefix) else { return nil }
        let rest = nextURL.dropFirst(nextURLPrefix.count)
        guard let separator = rest.firstIndex(of: "?") else { return nil }
        let path = rest[..<separator]
        let query = rest[rest.index(after: separator)...]
        guard isRelativePath(path), isPercentEncodedQuery(query) else { return nil }
        return HTTPRequest(
            path: String(path),
            method: "GET",
            headers: authorization(jwt),
            percentEncodedQuery: String(query)
        )
    }

    public static func page(
        _ response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()
    ) throws(ChoreArchiveFailure) -> ChoreArchivePage {
        guard (200...299).contains(response.statusCode) else {
            throw ChoreArchiveFailure(status: HTTPStatusFailure(response: response, decoder: decoder))
        }
        guard let envelope = try? decoder.decode(PageEnvelope.self, from: response.body),
              envelope.success != false, let data = envelope.data else {
            throw ChoreArchiveFailure(kind: .invalidResponse, message: nil)
        }
        let next = data.nextUrl.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        return ChoreArchivePage(chores: data.chores, nextURL: next)
    }

    private static func authorization(_ jwt: String) -> [String: String] {
        ["Authorization": "Bearer \(jwt)"]
    }

    private static func isRelativePath(_ path: Substring) -> Bool {
        guard !path.isEmpty else { return false }
        return path.split(separator: "/", omittingEmptySubsequences: false).allSatisfy { segment in
            !segment.isEmpty && segment != "." && segment != ".." && segment.utf8.allSatisfy(isUnreserved)
        }
    }

    private static func isPercentEncodedQuery(_ query: Substring) -> Bool {
        guard !query.isEmpty else { return false }
        let bytes = Array(query.utf8)
        var index = 0
        while index < bytes.count {
            let byte = bytes[index]
            if byte == UInt8(ascii: "%") {
                guard index + 2 < bytes.count, isHex(bytes[index + 1]), isHex(bytes[index + 2]) else { return false }
                index += 3
                continue
            }
            guard isUnreserved(byte) || "!$&()*+,;=:@/?".utf8.contains(byte) else { return false }
            index += 1
        }
        return true
    }

    private static func isUnreserved(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "A")...UInt8(ascii: "Z"), UInt8(ascii: "a")...UInt8(ascii: "z"),
             UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "-"), UInt8(ascii: "."),
             UInt8(ascii: "_"), UInt8(ascii: "~"):
            true
        default:
            false
        }
    }

    private static func isHex(_ byte: UInt8) -> Bool {
        switch byte {
        case UInt8(ascii: "0")...UInt8(ascii: "9"), UInt8(ascii: "A")...UInt8(ascii: "F"),
             UInt8(ascii: "a")...UInt8(ascii: "f"):
            true
        default:
            false
        }
    }

    private struct PageEnvelope: Decodable {
        struct Payload: Decodable {
            let chores: [HouseChoreDTO]
            let nextUrl: String?
        }

        let success: Bool?
        let data: Payload?
    }
}

/// One page of archived chores. `nextURL` is the server's `nextUrl`, `nil` on the last page.
public struct ChoreArchivePage: Equatable, Sendable {
    public let chores: [HouseChoreDTO]
    public let nextURL: String?

    public init(chores: [HouseChoreDTO], nextURL: String?) {
        self.chores = chores
        self.nextURL = nextURL
    }
}

/// A failed archive request, with the server's localized message when it sent one.
public struct ChoreArchiveFailure: Error, Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        /// 400: a rule was broken, such as a tampered cursor. Also a request refused before sending
        /// (blank house, empty or reversed range).
        case invalidRequest
        /// 401: the session flow takes over.
        case unauthorized
        /// 403: not a member of the house.
        case notMember
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
        default: .server
        }
        self.init(kind: kind, message: status.message)
    }
}
