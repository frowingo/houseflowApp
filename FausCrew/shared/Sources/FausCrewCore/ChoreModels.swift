import Foundation

// MARK: - Raw value enums

public enum ChoreLevel: Int, Codable, Sendable {
    case easy = 10
    case medium = 20
    case hard = 30
}

public enum ChoreStatus: Int, Codable, Sendable {
    case draft = 0
    case progress = 1
    case inTest = 2
    case completed = 3
}

// MARK: - Requests

public struct CreateChoreRequest: Encodable, Equatable, Sendable {
    public let assignedTo: String
    public let description: String
    public let dueDate: String
    public let houseId: String
    public let isRecurring: Bool
    public let level: Int
    public let recurringInterval: Int
    public let title: String

    public init(
        assignedTo: String,
        description: String,
        dueDate: String,
        houseId: String,
        isRecurring: Bool,
        level: Int,
        recurringInterval: Int,
        title: String
    ) {
        self.assignedTo = assignedTo
        self.description = description
        self.dueDate = dueDate
        self.houseId = houseId
        self.isRecurring = isRecurring
        self.level = level
        self.recurringInterval = recurringInterval
        self.title = title
    }
}

public struct UpdateChoreRequest: Encodable, Equatable, Sendable {
    public let assignedTo: String
    public let description: String
    public let dueDate: String
    public let houseId: String
    public let isRecurring: Bool
    public let level: Int
    public let recurringInterval: Int
    public let title: String

    public init(
        assignedTo: String,
        description: String,
        dueDate: String,
        houseId: String,
        isRecurring: Bool,
        level: Int,
        recurringInterval: Int,
        title: String
    ) {
        self.assignedTo = assignedTo
        self.description = description
        self.dueDate = dueDate
        self.houseId = houseId
        self.isRecurring = isRecurring
        self.level = level
        self.recurringInterval = recurringInterval
        self.title = title
    }
}

public struct ChoreStatusUpdateItem: Encodable, Equatable, Sendable {
    public let choreId: String
    public let status: Int

    public init(choreId: String, status: Int) {
        self.choreId = choreId
        self.status = status
    }
}

public struct UpdateChoreStatusRequest: Encodable, Equatable, Sendable {
    public let chores: [ChoreStatusUpdateItem]
    public let houseId: String

    public init(chores: [ChoreStatusUpdateItem], houseId: String) {
        self.chores = chores
        self.houseId = houseId
    }
}

public struct ReviewChoreRequest: Encodable, Equatable, Sendable {
    public let choreId: String
    public let isApproved: Bool

    public init(choreId: String, isApproved: Bool) {
        self.choreId = choreId
        self.isApproved = isApproved
    }
}

// MARK: - Responses

public struct ChoreReviewResponse: Decodable, Identifiable, Equatable, Sendable {
    public let id: String
    public let status: Int
    public let reviewRound: Int
    public let isCompleted: Bool
    public let reviewVotes: [ChoreReviewVote]
}

public struct ChoreResponse: Decodable, Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let description: String
    public let houseId: String
    public let houseOwnerId: String
    public let assignedTo: String
    public let dueDate: String
    public let isCompleted: Bool
    public let isRecurring: Bool
    public let level: Int
    public let recurringInterval: Int
    public let status: Int
    public let createdOn: String
    public let completedAt: String?
    public let completedBy: String?
    public let statusHistories: [ChoreStatusHistoryResponse]
    public let reviewRound: Int
    public let reviewVotes: [ChoreReviewVote]
    /// Review rounds that carry a photo. Object keys are never sent to clients.
    public let reviewPhotoRounds: [Int]

    private enum CodingKeys: String, CodingKey {
        case id, title, description, houseId, houseOwnerId, assignedTo, dueDate
        case isCompleted, isRecurring, level, recurringInterval, status, createdOn
        case completedAt, completedBy, statusHistories, reviewRound, reviewVotes, reviewPhotoRounds
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        houseId = try container.decode(String.self, forKey: .houseId)
        houseOwnerId = try container.decode(String.self, forKey: .houseOwnerId)
        assignedTo = try container.decode(String.self, forKey: .assignedTo)
        dueDate = try container.decode(String.self, forKey: .dueDate)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        isRecurring = try container.decode(Bool.self, forKey: .isRecurring)
        level = try container.decode(Int.self, forKey: .level)
        recurringInterval = try container.decode(Int.self, forKey: .recurringInterval)
        status = try container.decode(Int.self, forKey: .status)
        createdOn = try container.decode(String.self, forKey: .createdOn)
        completedAt = try container.decodeIfPresent(String.self, forKey: .completedAt)
        completedBy = try container.decodeIfPresent(String.self, forKey: .completedBy)
        statusHistories = try container.decode([ChoreStatusHistoryResponse].self, forKey: .statusHistories)
        reviewRound = try container.decode(Int.self, forKey: .reviewRound)
        reviewVotes = try container.decode([ChoreReviewVote].self, forKey: .reviewVotes)
        reviewPhotoRounds = try container.decodeIfPresent([Int].self, forKey: .reviewPhotoRounds) ?? []
    }
}

public struct ChoreStatusHistoryResponse: Decodable, Identifiable, Equatable, Sendable {
    public let id: String
    public let choreId: String
    public let status: Int
    public let updater: String
    public let dateTime: String
}

// MARK: - Domain model

public struct Chore: Identifiable, Codable, Equatable, Sendable {
    public let id: String
    /// Server-assigned chore ID (nil for local/sample chores).
    public let choreApiId: String?
    public let houseId: String?
    /// Server-assigned user ID of the assignee.
    public let assignedToId: String?
    public let title: String
    public let description: String
    public let assignedTo: User
    /// Presentation value supplied by the platform layer.
    public let dueLabel: String
    /// Raw ISO-8601 date string from the API (nil for local/sample chores).
    public let dueDate: String?
    public let isDone: Bool
    /// Raw value of `ChoreStatus`.
    public let status: Int
    /// Raw value of `ChoreLevel`.
    public let level: Int
    public let reviewRound: Int
    public let reviewVotes: [ChoreReviewVote]
    public let reviewPhotoRounds: [Int]

    public init(
        id: String? = nil,
        choreApiId: String? = nil,
        houseId: String? = nil,
        assignedToId: String? = nil,
        title: String,
        description: String = "",
        assignedTo: User,
        dueLabel: String,
        dueDate: String? = nil,
        isDone: Bool = false,
        status: Int = 0,
        level: Int = 10,
        reviewRound: Int = 0,
        reviewVotes: [ChoreReviewVote] = [],
        reviewPhotoRounds: [Int] = []
    ) {
        self.id = choreApiId ?? id ?? UUID().uuidString
        self.choreApiId = choreApiId
        self.houseId = houseId
        self.assignedToId = assignedToId
        self.title = title
        self.description = description
        self.assignedTo = assignedTo
        self.dueLabel = dueLabel
        self.dueDate = dueDate
        self.isDone = isDone
        self.status = status
        self.level = level
        self.reviewRound = reviewRound
        self.reviewVotes = reviewVotes
        self.reviewPhotoRounds = reviewPhotoRounds
    }
}

// MARK: - Review photo

/// Client-side gate for the `PUT chore/status` multipart path. The backend
/// rejects a JSON InTest request with 400 while the house requires a photo.
public enum ChoreReviewPhotoRules: Sendable {
    /// Backend limit: 3 MB.
    public static let maxByteCount = 3 * 1024 * 1024
    public static let supportedMimeTypes = ["image/jpeg", "image/png", "image/webp"]

    /// Only a single Progress → InTest transition carries a photo.
    public static func requiresPhoto(isChoreReviewPhotoRequired: Bool, targetStatus: ChoreStatus) -> Bool {
        isChoreReviewPhotoRequired && targetStatus == .inTest
    }

    /// Detects the format from magic bytes so a renamed file cannot pass.
    public static func mimeType(of data: Data) -> String? {
        let bytes = [UInt8](data.prefix(12))
        if bytes.starts(with: [0xFF, 0xD8, 0xFF]) { return "image/jpeg" }
        if bytes.starts(with: [0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]) { return "image/png" }
        if bytes.count == 12,
           bytes[0..<4].elementsEqual([0x52, 0x49, 0x46, 0x46]),
           bytes[8..<12].elementsEqual([0x57, 0x45, 0x42, 0x50]) {
            return "image/webp"
        }
        return nil
    }
}

public enum ChoreReviewPhotoError: Error, Equatable, Sendable {
    case missing
    case unsupportedFormat
    case tooLarge
}

/// A validated review photo ready for the `file` multipart field.
public struct ChoreReviewPhotoUpload: Equatable, Sendable {
    public let data: Data
    public let mimeType: String

    public init(data: Data) throws(ChoreReviewPhotoError) {
        guard !data.isEmpty else { throw .missing }
        guard let mimeType = ChoreReviewPhotoRules.mimeType(of: data) else { throw .unsupportedFormat }
        guard data.count <= ChoreReviewPhotoRules.maxByteCount else { throw .tooLarge }
        self.data = data
        self.mimeType = mimeType
    }

    public var fileName: String {
        switch mimeType {
        case "image/png": return "review-photo.png"
        case "image/webp": return "review-photo.webp"
        default: return "review-photo.jpg"
        }
    }
}

/// `GET chore/{choreId}/review-photo/{round}`. The URL is short-lived and must
/// never be persisted, logged or used as a disk cache key.
public struct ChoreReviewPhotoURLResponse: Decodable, Equatable, Sendable {
    public let url: String
    public let expiresAt: String

    public init(url: String, expiresAt: String) {
        self.url = url
        self.expiresAt = expiresAt
    }

    public var expiresAtDate: Date? {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: expiresAt) { return date }
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: expiresAt)
    }

    /// An unparseable expiry is left to the storage host's 403.
    public func isExpired(at now: Date, leeway: TimeInterval = 5) -> Bool {
        guard let expiresAtDate else { return false }
        return now.addingTimeInterval(leeway) >= expiresAtDate
    }
}
