import Foundation

// MARK: - Create House

struct CreateHouseRequest: Encodable {
    let name: String
    let maxMemberCount: Int
    let type: Int
}

// MARK: - Join House

struct JoinHouseRequest: Encodable {
    let inviteCode: String
}

// MARK: - House Response (create & join share the same shape)

struct HouseResponse: Decodable, Identifiable {
    let id: String
    let name: String
    let inviteCode: String
    let maxMemberCount: Int
    let memberIds: [String]
    let ownerId: String
    let profileImage: String
    let type: Int
    let createdOn: String
    let updatedOn: String
}

// MARK: - House Details Response

struct HouseDetailsResponse: Decodable, Equatable {
    let id: String
    let name: String
    let inviteCode: String
    let maxMemberCount: Int
    let ownerId: String
    let profileImage: String
    let type: Int
    let createdOn: String
    let updatedOn: String
    let members: [HouseMemberDTO]
    let chores: [HouseChoreDTO]
}

// MARK: - Member DTO

struct HouseMemberDTO: Decodable, Identifiable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let imageUrl: String
    let isActive: Bool
    let isVerifyEmail: Bool
    let isVerifyPhone: Bool
    let phoneNumber: String
    let birthDate: String?
    let houseIds: [String]
    let createdOn: String
    let updatedOn: String
    let lastLogin: String

    var fullName: String { "\(firstName) \(lastName)" }
}

// MARK: - Chore DTO

struct HouseChoreDTO: Decodable, Identifiable, Equatable {
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
    let statusHistories: [ChoreStatusHistory]
    let reviewRound: Int
    let reviewVotes: [ChoreReviewVote]
}

struct ChoreStatusHistory: Decodable, Identifiable, Equatable {
    let id: String
    let choreId: String
    let status: Int
    let updater: String
    let dateTime: String
}

// MARK: - HouseChoreDTO helpers

extension HouseChoreDTO {
    /// Converts `dueDate` (ISO-8601) into a human-readable due label.
    var dueLabelString: String {
        HouseFlowDateFormatter.dueLabel(from: dueDate)
    }
}
