import Foundation

/// `GET` / `PUT chore/catalog` rules shared by the two clients. iOS calls it directly; Android
/// crosses the bridge once per request and once per response.
public enum ChoreCatalogWireContract {
    public static let path = "chore/catalog"

    /// The PUT body: records trimmed and checked against the server's rules first, so a request
    /// the server would reject with 400 is never sent.
    public static func upsertBody(_ records: [ChoreCatalogRecord]) throws(ChoreCatalogViolation) -> Data {
        let prepared = records.map(ChoreCatalogRules.prepared)
        if let violation = ChoreCatalogRules.firstViolation(in: prepared) { throw violation }
        do {
            return try JSONEncoder().encode(prepared)
        } catch {
            // Encoding plain strings, ints and bools does not fail.
            preconditionFailure("ChoreCatalogRecord encoding failed: \(error)")
        }
    }

    /// The records actually sent for `records`, to patch the local list with the response.
    public static func sentRecords(_ records: [ChoreCatalogRecord]) -> [ChoreCatalogRecord] {
        records.map(ChoreCatalogRules.prepared)
    }

    /// `GET chore/catalog`: the visible list (deleted records never come, but are dropped anyway).
    public static func list(response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) throws(ChoreCatalogFailure) -> [ChoreCatalogRecord] {
        let records: [ChoreCatalogRecord] = try decode(response, decoder: decoder)
        return records.filter { !$0.isDeleted }
    }

    /// `PUT chore/catalog`: the local list patched with the response, which is in request order.
    public static func upsert(
        response: HTTPResponse,
        sent: [ChoreCatalogRecord],
        local: [ChoreCatalogRecord],
        decoder: JSONDecoder = JSONDecoder()
    ) throws(ChoreCatalogFailure) -> [ChoreCatalogRecord] {
        let records: [ChoreCatalogRecord] = try decode(response, decoder: decoder)
        do {
            return try ChoreCatalogPatch.apply(response: records, sent: sent, to: local)
        } catch {
            throw ChoreCatalogFailure(kind: .invalidResponse, message: nil)
        }
    }

    private static func decode(_ response: HTTPResponse, decoder: JSONDecoder) throws(ChoreCatalogFailure) -> [ChoreCatalogRecord] {
        guard (200...299).contains(response.statusCode) else {
            throw ChoreCatalogFailure(status: HTTPStatusFailure(response: response, decoder: decoder))
        }
        do {
            return try decoder.decode([ChoreCatalogRecord].self, from: response.body)
        } catch {
            throw ChoreCatalogFailure(kind: .invalidResponse, message: nil)
        }
    }
}

/// A failed catalog request, with the server's localized message when it sent one.
public struct ChoreCatalogFailure: Error, Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        /// 400: the body broke a rule. Client validation normally prevents it.
        case validation
        /// 401: the session flow takes over.
        case unauthorized
        /// 403: a system record was touched. The UI normally prevents it.
        case forbidden
        /// 404: the record is gone or belongs to someone else; the list must be fetched again.
        case notFound
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
        case 400: .validation
        case 401: .unauthorized
        case 403: .forbidden
        case 404: .notFound
        default: .server
        }
        self.init(kind: kind, message: status.message)
    }

    /// After a 404 the local list is stale: fetch it again.
    public var refreshesList: Bool { kind == .notFound }
}
