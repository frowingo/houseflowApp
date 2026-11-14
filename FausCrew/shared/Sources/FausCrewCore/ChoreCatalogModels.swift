import Foundation

// MARK: - Chore catalog (GET / PUT chore/catalog)
//
// Contract: `Documents/choreCatalogBackendContract.md`. The catalog holds the system's ready-made
// templates (`isSystem`) and the user's own saved chores ("drafts" in the UI). The server is the
// only source of truth; the clients keep the last list in memory and patch it with PUT results.

/// `ChoreCatalogModel`. The same shape travels in requests and responses.
public struct ChoreCatalogRecord: Codable, Hashable, Sendable {
    /// `nil` for a record the server has not created yet.
    public var id: String?
    public var title: String
    public var description: String
    /// Days between repeats, 0–365; `0` does not repeat.
    public var recurringInterval: Int
    /// `ChoreLevel` raw value.
    public var level: Int
    /// `ChoreCategoryKind` raw value, 1–9 (the catalog never takes `0`).
    public var category: Int
    public var isDeleted: Bool
    /// A system template: read-only for normal users.
    public var isSystem: Bool
    /// Filled by the server; never sent.
    public var userId: String?
    public var createdOn: String?
    public var updatedOn: String?

    public init(
        id: String? = nil,
        title: String,
        description: String = "",
        recurringInterval: Int = 0,
        level: Int = ChoreLevel.easy.rawValue,
        category: Int,
        isDeleted: Bool = false,
        isSystem: Bool = false,
        userId: String? = nil,
        createdOn: String? = nil,
        updatedOn: String? = nil
    ) {
        self.id = id.flatMap { $0.isEmpty ? nil : $0 }
        self.title = title
        self.description = description
        self.recurringInterval = recurringInterval
        self.level = level
        self.category = category
        self.isDeleted = isDeleted
        self.isSystem = isSystem
        self.userId = userId
        self.createdOn = createdOn
        self.updatedOn = updatedOn
    }

    public var categoryKind: ChoreCategoryKind { ChoreCategoryKind(apiValue: category) }

    /// A new copy owned by the user: how a system template (or any record) is saved as a draft.
    public var asNewUserRecord: ChoreCatalogRecord {
        ChoreCatalogRecord(title: title, description: description, recurringInterval: recurringInterval,
                           level: level, category: category)
    }

    /// The whole record marked for deletion; deletes must still pass validation.
    public var markedDeleted: ChoreCatalogRecord {
        var record = self
        record.isDeleted = true
        return record
    }

    /// `updatedOn` (or `createdOn`) as a date, for newest-first lists.
    public var updatedDate: Date? { ChoreCatalogDate.parse(updatedOn ?? createdOn) }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, recurringInterval, level, category
        case isDeleted, isSystem, userId, createdOn, updatedOn
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let id = try container.decodeIfPresent(String.self, forKey: .id)
        self.id = id.flatMap { $0.isEmpty ? nil : $0 }
        title = try container.decode(String.self, forKey: .title)
        description = try container.decodeIfPresent(String.self, forKey: .description) ?? ""
        recurringInterval = try container.decodeIfPresent(Int.self, forKey: .recurringInterval) ?? 0
        level = try container.decode(Int.self, forKey: .level)
        category = try container.decodeIfPresent(Int.self, forKey: .category) ?? 0
        isDeleted = try container.decodeIfPresent(Bool.self, forKey: .isDeleted) ?? false
        isSystem = try container.decodeIfPresent(Bool.self, forKey: .isSystem) ?? false
        userId = try container.decodeIfPresent(String.self, forKey: .userId)
        createdOn = try container.decodeIfPresent(String.self, forKey: .createdOn)
        updatedOn = try container.decodeIfPresent(String.self, forKey: .updatedOn)
    }

    /// Request shape: server-filled fields are left out, as is `id` for a new record.
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(description, forKey: .description)
        try container.encode(recurringInterval, forKey: .recurringInterval)
        try container.encode(level, forKey: .level)
        try container.encode(category, forKey: .category)
        try container.encode(isDeleted, forKey: .isDeleted)
        try container.encode(isSystem, forKey: .isSystem)
    }
}

// MARK: - Validation (the server's rules, applied before sending)

public enum ChoreCatalogRule: Equatable, Sendable {
    case emptyBatch
    case tooManyRecords
    case invalidId
    case titleLength
    case descriptionTooLong
    case recurringIntervalOutOfRange
    case invalidLevel
    case invalidCategory
    case deleteWithoutId
    /// Normal users never send `isSystem: true`; system templates are read-only here.
    case systemRecord
}

public struct ChoreCatalogViolation: Error, Equatable, Sendable {
    /// Position in the batch; `nil` for rules about the batch itself.
    public let index: Int?
    public let rule: ChoreCatalogRule

    public init(index: Int?, rule: ChoreCatalogRule) {
        self.index = index
        self.rule = rule
    }
}

public enum ChoreCatalogRules {
    public static let titleLength = 3...200
    public static let descriptionMaxLength = 1000
    public static let recurringInterval = 0...365
    public static let batchSize = 1...100
    public static let idLength = 24
    public static let levels = [ChoreLevel.easy, .medium, .hard].map(\.rawValue)

    /// Text exactly as it is sent: surrounding whitespace removed.
    public static func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public static func isValidTitle(_ title: String) -> Bool {
        titleLength.contains(normalized(title).count)
    }

    public static func isValidDescription(_ description: String) -> Bool {
        normalized(description).count <= descriptionMaxLength
    }

    /// Every rule a single record breaks, in a fixed order.
    public static func violations(of record: ChoreCatalogRecord) -> [ChoreCatalogRule] {
        var rules: [ChoreCatalogRule] = []
        let id = record.id.flatMap { $0.isEmpty ? nil : $0 }
        if let id, id.count != idLength { rules.append(.invalidId) }
        if !isValidTitle(record.title) { rules.append(.titleLength) }
        if !isValidDescription(record.description) { rules.append(.descriptionTooLong) }
        if !recurringInterval.contains(record.recurringInterval) { rules.append(.recurringIntervalOutOfRange) }
        if !levels.contains(record.level) { rules.append(.invalidLevel) }
        if !(ChoreCategoryKind(rawValue: record.category)?.isAssignable ?? false) { rules.append(.invalidCategory) }
        if record.isDeleted && id == nil { rules.append(.deleteWithoutId) }
        if record.isSystem { rules.append(.systemRecord) }
        return rules
    }

    /// The first rule the batch breaks, or `nil` when the server would accept it.
    public static func firstViolation(in records: [ChoreCatalogRecord]) -> ChoreCatalogViolation? {
        if records.isEmpty { return ChoreCatalogViolation(index: nil, rule: .emptyBatch) }
        if records.count > batchSize.upperBound { return ChoreCatalogViolation(index: nil, rule: .tooManyRecords) }
        for (index, record) in records.enumerated() {
            if let rule = violations(of: record).first { return ChoreCatalogViolation(index: index, rule: rule) }
        }
        return nil
    }

    /// The record as it is sent: text trimmed, an empty id dropped (a new record).
    public static func prepared(_ record: ChoreCatalogRecord) -> ChoreCatalogRecord {
        var record = record
        if record.id?.isEmpty == true { record.id = nil }
        record.title = normalized(record.title)
        record.description = normalized(record.description)
        return record
    }
}

// MARK: - Patching the local list with a PUT result

public enum ChoreCatalogPatchError: Error, Equatable, Sendable {
    /// The response does not have one record per request record.
    case countMismatch
    /// A response record without an id.
    case missingId(index: Int)
}

public enum ChoreCatalogPatch {
    /// Applies a PUT result to the local list. The response is in request order, so records are
    /// matched by index: a deleted record leaves the list, an existing one is overwritten in
    /// place, and a new one (sent without an id) is appended with the server's id.
    public static func apply(
        response: [ChoreCatalogRecord],
        sent: [ChoreCatalogRecord],
        to local: [ChoreCatalogRecord]
    ) throws(ChoreCatalogPatchError) -> [ChoreCatalogRecord] {
        guard response.count == sent.count else { throw .countMismatch }
        var result = local
        for (index, record) in response.enumerated() {
            guard let id = record.id else { throw .missingId(index: index) }
            let existing = result.firstIndex { $0.id == id }
            if record.isDeleted {
                if let existing { result.remove(at: existing) }
            } else if let existing {
                result[existing] = record
            } else {
                result.append(record)
            }
        }
        return result
    }
}

// MARK: - Lists for the UI

public extension Array where Element == ChoreCatalogRecord {
    /// System templates in server order (category, then title).
    var systemRecords: [ChoreCatalogRecord] { filter { $0.isSystem && !$0.isDeleted } }

    /// The user's own records, most recently saved first.
    var userRecords: [ChoreCatalogRecord] {
        filter { !$0.isSystem && !$0.isDeleted }
            .enumerated()
            .sorted { lhs, rhs in
                let left = lhs.element.updatedDate ?? .distantPast
                let right = rhs.element.updatedDate ?? .distantPast
                return left == right ? lhs.offset < rhs.offset : left > right
            }
            .map(\.element)
    }
}

enum ChoreCatalogDate {
    static func parse(_ value: String?) -> Date? {
        guard let value else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: value) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: value)
    }
}
