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
        reviewVotes: [ChoreReviewVote] = []
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
    }
}
