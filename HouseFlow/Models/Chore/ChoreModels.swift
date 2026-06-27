import Foundation

// MARK: - Enums

enum ChoreLevel: Int, Codable {
    case easy   = 10
    case medium = 20
    case hard   = 30
}

enum ChoreStatus: Int, Codable {
    case draft     = 0
    case progress  = 1
    case inTest    = 2
    case completed = 3
}

// MARK: - Create Chore

struct CreateChoreRequest: Encodable {
    let assignedTo: String
    let description: String
    let dueDate: String          // "2026-07-12 00:00:00"
    let houseId: String
    let isRecurring: Bool
    let level: Int               // ChoreLevel raw value
    let recurringInterval: Int
    let title: String
}

// MARK: - Update Chore

struct UpdateChoreRequest: Encodable {
    let assignedTo: String
    let description: String
    let dueDate: String
    let houseId: String
    let isRecurring: Bool
    let level: Int
    let recurringInterval: Int
    let title: String
}

// MARK: - Update Chore Status

struct ChoreStatusUpdateItem: Encodable {
    let choreId: String
    let status: Int              // ChoreStatus raw value
}

struct UpdateChoreStatusRequest: Encodable {
    let chores: [ChoreStatusUpdateItem]
    let houseId: String
}

// MARK: - Review Chore

struct ReviewChoreRequest: Encodable {
    let choreId: String
    let isApproved: Bool
}

struct ChoreReviewVote: Codable, Identifiable {
    let id: String
    let choreId: String
    let houseId: String
    let reviewRound: Int
    let reviewerId: String
    let isApproved: Bool
    let createdOn: String
}

struct ChoreReviewResponse: Decodable, Identifiable {
    let id: String
    let status: Int
    let reviewRound: Int
    let isCompleted: Bool
    let reviewVotes: [ChoreReviewVote]
}

// MARK: - Chore Response

struct ChoreResponse: Decodable, Identifiable {
    let id: String
    let title: String
    let description: String
    let houseId: String
    let houseOwnerId: String
    let assignedTo: String
    let dueDate: String
    let isCompleted: Bool
    let isRecurring: Bool
    let level: Int
    let recurringInterval: Int
    let status: Int
    let createdOn: String
    let completedAt: String?
    let completedBy: String?
    let statusHistories: [ChoreStatusHistoryResponse]
    let reviewRound: Int
    let reviewVotes: [ChoreReviewVote]
}

struct ChoreStatusHistoryResponse: Decodable, Identifiable {
    let id: String
    let choreId: String
    let status: Int
    let updater: String
    let dateTime: String
}
