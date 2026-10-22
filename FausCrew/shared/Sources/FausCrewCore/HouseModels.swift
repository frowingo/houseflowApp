import Foundation

// MARK: - Requests

public struct CreateHouseRequest: Encodable, Equatable, Sendable {
    public let name: String
    public let maxMemberCount: Int
    public let type: Int

    public init(name: String, maxMemberCount: Int, type: Int) {
        self.name = name
        self.maxMemberCount = maxMemberCount
        self.type = type
    }
}

public struct JoinHouseRequest: Encodable, Equatable, Sendable {
    public let inviteCode: String

    public init(inviteCode: String) {
        self.inviteCode = inviteCode
    }
}

public struct CreateAnnouncementRequest: Encodable, Equatable, Sendable {
    public let description: String
    public let houseId: String
    public let title: String

    public init(description: String, houseId: String, title: String) {
        self.description = description
        self.houseId = houseId
        self.title = title
    }
}

public struct UpdateHouseProfileRequest: Encodable, Equatable, Sendable {
    public let houseMemberCountLimit: Int
    public let houseName: String
    public let houseProfileImage: String
    public let houseType: Int

    public init(
        houseMemberCountLimit: Int,
        houseName: String,
        houseProfileImage: String,
        houseType: Int
    ) {
        self.houseMemberCountLimit = houseMemberCountLimit
        self.houseName = houseName
        self.houseProfileImage = houseProfileImage
        self.houseType = houseType
    }
}

public struct ExitHouseRequest: Encodable, Equatable, Sendable {
    public let houseId: String
    public let userId: String

    public init(houseId: String, userId: String) {
        self.houseId = houseId
        self.userId = userId
    }
}

public struct CreateHouseInviteCodeRequest: Encodable, Equatable, Sendable {
    public let houseId: String

    public init(houseId: String) {
        self.houseId = houseId
    }
}

// MARK: - Invite code rule

public enum InviteCodeRules: Sendable {
    public static let requiredLength = 8

    private static let allowedCharacters = CharacterSet(
        charactersIn: "ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789"
    )

    public static func normalized(_ value: String) -> String {
        let filtered = value
            .uppercased()
            .unicodeScalars
            .filter { allowedCharacters.contains($0) }
            .map(String.init)
            .joined()
        return String(filtered.prefix(requiredLength))
    }

    public static func isValid(_ value: String) -> Bool {
        normalized(value).count == requiredLength
    }
}

// MARK: - Response envelope and wire time

public struct HouseAPIResponse<Payload: Decodable>: Decodable {
    public let data: Payload?
    public let success: Bool
    public let error: String?
}

/// House endpoints return timestamps as either an ISO-8601 string or a
/// `{ "time.Time": "..." }` object. DTOs retain the normalized wire value.
private struct APITimeValue: Decodable {
    let rawValue: String

    private enum CodingKeys: String, CodingKey {
        case time = "time.Time"
    }

    init(from decoder: Decoder) throws {
        if let container = try? decoder.singleValueContainer(),
           let value = try? container.decode(String.self) {
            rawValue = value
            return
        }

        let container = try decoder.container(keyedBy: CodingKeys.self)
        rawValue = try container.decode(String.self, forKey: .time)
    }
}

private extension KeyedDecodingContainer {
    func decodeAPITime(forKey key: Key) throws -> String {
        try decode(APITimeValue.self, forKey: key).rawValue
    }

    func decodeAPITimeIfPresent(forKey key: Key) throws -> String? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decode(APITimeValue.self, forKey: key).rawValue
    }
}

// MARK: - House response

public struct HouseResponse: Decodable, Identifiable, Sendable {
    public let id: String
    public let name: String
    public let inviteCode: String?
    public let maxMemberCount: Int
    public let memberIds: [String]
    public let ownerId: String
    public let profileImage: String
    public let type: Int
    public let createdOn: String
    public let updatedOn: String

    private enum CodingKeys: String, CodingKey {
        case id, name, inviteCode, maxMemberCount, memberIds, ownerId
        case profileImage, type, createdOn, updatedOn
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        inviteCode = try container.decodeIfPresent(String.self, forKey: .inviteCode)
        maxMemberCount = try container.decode(Int.self, forKey: .maxMemberCount)
        memberIds = try container.decode([String].self, forKey: .memberIds)
        ownerId = try container.decode(String.self, forKey: .ownerId)
        profileImage = try container.decode(String.self, forKey: .profileImage)
        type = try container.decode(Int.self, forKey: .type)
        createdOn = try container.decodeAPITime(forKey: .createdOn)
        updatedOn = try container.decodeAPITime(forKey: .updatedOn)
    }
}

// MARK: - House details

public struct HouseDetailsResponse: Decodable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let maxMemberCount: Int
    public let ownerId: String
    public let profileImage: String
    public let type: Int
    public let createdOn: String
    public let updatedOn: String
    public let members: [HouseMemberDTO]
    public let chores: [HouseChoreDTO]
    public var announcements: [HouseAnnouncementDTO]

    public init(
        id: String,
        name: String,
        maxMemberCount: Int,
        ownerId: String,
        profileImage: String,
        type: Int,
        createdOn: String,
        updatedOn: String,
        members: [HouseMemberDTO],
        chores: [HouseChoreDTO],
        announcements: [HouseAnnouncementDTO] = []
    ) {
        self.id = id
        self.name = name
        self.maxMemberCount = maxMemberCount
        self.ownerId = ownerId
        self.profileImage = profileImage
        self.type = type
        self.createdOn = createdOn
        self.updatedOn = updatedOn
        self.members = members
        self.chores = chores
        self.announcements = announcements
    }

    private enum CodingKeys: String, CodingKey {
        case id, name, maxMemberCount, ownerId, profileImage, type
        case createdOn, updatedOn, members, chores, announcements, activeAnnouncements
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        maxMemberCount = try container.decode(Int.self, forKey: .maxMemberCount)
        ownerId = try container.decode(String.self, forKey: .ownerId)
        profileImage = try container.decode(String.self, forKey: .profileImage)
        type = try container.decode(Int.self, forKey: .type)
        createdOn = try container.decodeAPITime(forKey: .createdOn)
        updatedOn = try container.decodeAPITime(forKey: .updatedOn)
        members = try container.decode([HouseMemberDTO].self, forKey: .members)
        chores = try container.decode([HouseChoreDTO].self, forKey: .chores)
        announcements = try container.decodeIfPresent(
            [HouseAnnouncementDTO].self,
            forKey: .announcements
        ) ?? container.decodeIfPresent(
            [HouseAnnouncementDTO].self,
            forKey: .activeAnnouncements
        ) ?? []
    }
}

// MARK: - Announcement DTO

public struct HouseAnnouncementDTO: Decodable, Identifiable, Equatable, Sendable {
    public let id: String
    public let houseId: String?
    public let title: String
    public let message: String
    public let createdOn: String
    public let updatedOn: String?
    public let isActive: Bool
    public let publisherId: String?
    public let publisherName: String?

    public init(
        id: String,
        houseId: String? = nil,
        title: String,
        message: String,
        createdOn: String,
        updatedOn: String? = nil,
        isActive: Bool = true,
        publisherId: String? = nil,
        publisherName: String? = nil
    ) {
        self.id = id
        self.houseId = houseId
        self.title = title
        self.message = message
        self.createdOn = createdOn
        self.updatedOn = updatedOn
        self.isActive = isActive
        self.publisherId = publisherId
        self.publisherName = publisherName
    }

    private enum CodingKeys: String, CodingKey {
        case id, announcementId, houseId, announcedBy, title, message, content
        case description, body, createdOn, createdAt, updatedOn, updatedAt, isActive
        case createdBy, createdById, createdByUserId, creatorId, publisherId
        case userId, memberId, publisherName, createdByName, authorName
        case createdByFirstName, createdByLastName, createdByUser, creator, publisher, author
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)

        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decode(String.self, forKey: .announcementId)
        houseId = try container.decodeIfPresent(String.self, forKey: .houseId)
        title = try container.decode(String.self, forKey: .title)
        message = try container.decodeIfPresent(String.self, forKey: .message)
            ?? container.decodeIfPresent(String.self, forKey: .content)
            ?? container.decodeIfPresent(String.self, forKey: .description)
            ?? container.decode(String.self, forKey: .body)
        createdOn = try container.decodeAPITimeIfPresent(forKey: .createdOn)
            ?? container.decodeAPITime(forKey: .createdAt)
        updatedOn = try container.decodeAPITimeIfPresent(forKey: .updatedOn)
            ?? container.decodeAPITimeIfPresent(forKey: .updatedAt)
        isActive = try container.decodeIfPresent(Bool.self, forKey: .isActive) ?? true

        let nestedPublisher = Self.decodePublisher(
            from: container,
            keys: [.createdByUser, .creator, .publisher, .author, .createdBy]
        )
        publisherId = Self.decodeString(
            from: container,
            keys: [
                .announcedBy, .createdById, .createdByUserId, .creatorId,
                .publisherId, .userId, .memberId, .createdBy,
            ]
        ) ?? nestedPublisher?.id

        let directName = Self.decodeString(
            from: container,
            keys: [.publisherName, .createdByName, .authorName]
        )
        let firstName = Self.decodeString(from: container, keys: [.createdByFirstName])
        let lastName = Self.decodeString(from: container, keys: [.createdByLastName])
        let composedName = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        publisherName = directName
            ?? (composedName.isEmpty ? nil : composedName)
            ?? nestedPublisher?.displayName
    }

    private static func decodeString(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> String? {
        for key in keys {
            if let value = try? container.decode(String.self, forKey: key) {
                let trimmedValue = value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedValue.isEmpty { return trimmedValue }
            }
        }
        return nil
    }

    private static func decodePublisher(
        from container: KeyedDecodingContainer<CodingKeys>,
        keys: [CodingKeys]
    ) -> AnnouncementPublisherPayload? {
        for key in keys {
            if let publisher = try? container.decode(AnnouncementPublisherPayload.self, forKey: key) {
                return publisher
            }
        }
        return nil
    }
}

private struct AnnouncementPublisherPayload: Decodable {
    let id: String?
    let firstName: String?
    let lastName: String?
    let name: String?
    let fullName: String?

    var displayName: String? {
        if let fullName, !fullName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return fullName
        }
        if let name, !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return name
        }

        let composedName = [firstName, lastName]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        return composedName.isEmpty ? nil : composedName
    }

    private enum CodingKeys: String, CodingKey {
        case id, userId, memberId, firstName, lastName, name, fullName
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decodeIfPresent(String.self, forKey: .id)
            ?? container.decodeIfPresent(String.self, forKey: .userId)
            ?? container.decodeIfPresent(String.self, forKey: .memberId)
        firstName = try container.decodeIfPresent(String.self, forKey: .firstName)
        lastName = try container.decodeIfPresent(String.self, forKey: .lastName)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        fullName = try container.decodeIfPresent(String.self, forKey: .fullName)
    }
}

// MARK: - Member DTO

public struct HouseMemberDTO: Decodable, Identifiable, Equatable, Sendable {
    public let id: String
    public let firstName: String
    public let lastName: String
    public let email: String
    public let imageUrl: String
    public let isActive: Bool
    public let isVerifyEmail: Bool
    public let isVerifyPhone: Bool
    public let language: String?
    public let phoneNumber: String
    public let birthDate: String?
    public let houseIds: [String]
    public let createdOn: String
    public let updatedOn: String
    public let lastLogin: String

    public var fullName: String { "\(firstName) \(lastName)" }

    private enum CodingKeys: String, CodingKey {
        case id, firstName, lastName, email, imageUrl, isActive
        case isVerifyEmail, isVerifyPhone, language, phoneNumber, houseIds
        case createdOn, updatedOn, lastLogin
        case birthDate = "birthDay"
    }

    public init(
        id: String,
        firstName: String,
        lastName: String,
        email: String,
        imageUrl: String,
        isActive: Bool,
        isVerifyEmail: Bool,
        isVerifyPhone: Bool,
        language: String? = nil,
        phoneNumber: String,
        birthDate: String?,
        houseIds: [String],
        createdOn: String,
        updatedOn: String,
        lastLogin: String
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.imageUrl = imageUrl
        self.isActive = isActive
        self.isVerifyEmail = isVerifyEmail
        self.isVerifyPhone = isVerifyPhone
        self.language = language
        self.phoneNumber = phoneNumber
        self.birthDate = birthDate
        self.houseIds = houseIds
        self.createdOn = createdOn
        self.updatedOn = updatedOn
        self.lastLogin = lastLogin
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        firstName = try container.decode(String.self, forKey: .firstName)
        lastName = try container.decode(String.self, forKey: .lastName)
        email = try container.decode(String.self, forKey: .email)
        imageUrl = try container.decode(String.self, forKey: .imageUrl)
        isActive = try container.decode(Bool.self, forKey: .isActive)
        isVerifyEmail = try container.decode(Bool.self, forKey: .isVerifyEmail)
        isVerifyPhone = try container.decode(Bool.self, forKey: .isVerifyPhone)
        language = try container.decodeIfPresent(String.self, forKey: .language)
        phoneNumber = try container.decode(String.self, forKey: .phoneNumber)
        birthDate = try container.decodeAPITimeIfPresent(forKey: .birthDate)
        houseIds = try container.decode([String].self, forKey: .houseIds)
        createdOn = try container.decodeAPITime(forKey: .createdOn)
        updatedOn = try container.decodeAPITime(forKey: .updatedOn)
        lastLogin = try container.decodeAPITime(forKey: .lastLogin)
    }
}

// MARK: - Nested chore DTOs in house details

public struct HouseChoreDTO: Decodable, Identifiable, Equatable, Sendable {
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
    public let statusHistories: [ChoreStatusHistory]
    public let reviewRound: Int
    public let reviewVotes: [ChoreReviewVote]

    public init(
        id: String,
        title: String,
        description: String,
        houseId: String,
        houseOwnerId: String,
        assignedTo: String,
        dueDate: String,
        isCompleted: Bool,
        isRecurring: Bool,
        level: Int,
        recurringInterval: Int,
        status: Int,
        createdOn: String,
        completedAt: String?,
        completedBy: String?,
        statusHistories: [ChoreStatusHistory],
        reviewRound: Int,
        reviewVotes: [ChoreReviewVote]
    ) {
        self.id = id
        self.title = title
        self.description = description
        self.houseId = houseId
        self.houseOwnerId = houseOwnerId
        self.assignedTo = assignedTo
        self.dueDate = dueDate
        self.isCompleted = isCompleted
        self.isRecurring = isRecurring
        self.level = level
        self.recurringInterval = recurringInterval
        self.status = status
        self.createdOn = createdOn
        self.completedAt = completedAt
        self.completedBy = completedBy
        self.statusHistories = statusHistories
        self.reviewRound = reviewRound
        self.reviewVotes = reviewVotes
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, description, houseId, houseOwnerId, assignedTo
        case dueDate, isCompleted, isRecurring, level, recurringInterval
        case status, createdOn, completedAt, completedBy, statusHistories
        case reviewRound, reviewVotes
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        title = try container.decode(String.self, forKey: .title)
        description = try container.decode(String.self, forKey: .description)
        houseId = try container.decode(String.self, forKey: .houseId)
        houseOwnerId = try container.decode(String.self, forKey: .houseOwnerId)
        assignedTo = try container.decode(String.self, forKey: .assignedTo)
        dueDate = try container.decodeAPITime(forKey: .dueDate)
        isCompleted = try container.decode(Bool.self, forKey: .isCompleted)
        isRecurring = try container.decode(Bool.self, forKey: .isRecurring)
        level = try container.decode(Int.self, forKey: .level)
        recurringInterval = try container.decode(Int.self, forKey: .recurringInterval)
        status = try container.decode(Int.self, forKey: .status)
        createdOn = try container.decodeAPITime(forKey: .createdOn)
        completedAt = try container.decodeAPITimeIfPresent(forKey: .completedAt)
        completedBy = try container.decodeIfPresent(String.self, forKey: .completedBy)
        statusHistories = try container.decode([ChoreStatusHistory].self, forKey: .statusHistories)
        reviewRound = try container.decode(Int.self, forKey: .reviewRound)
        reviewVotes = try container.decode([ChoreReviewVote].self, forKey: .reviewVotes)
    }
}

public struct ChoreStatusHistory: Decodable, Identifiable, Equatable, Sendable {
    public let id: String
    public let choreId: String
    public let status: Int
    public let updater: String
    public let dateTime: String

    public init(id: String, choreId: String, status: Int, updater: String, dateTime: String) {
        self.id = id
        self.choreId = choreId
        self.status = status
        self.updater = updater
        self.dateTime = dateTime
    }

    private enum CodingKeys: String, CodingKey {
        case id, choreId, status, updater, dateTime
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        choreId = try container.decode(String.self, forKey: .choreId)
        status = try container.decode(Int.self, forKey: .status)
        updater = try container.decode(String.self, forKey: .updater)
        dateTime = try container.decodeAPITime(forKey: .dateTime)
    }
}

public struct ChoreReviewVote: Codable, Identifiable, Equatable, Sendable {
    public let id: String
    public let choreId: String
    public let houseId: String
    public let reviewRound: Int
    public let reviewerId: String
    public let isApproved: Bool
    public let createdOn: String

    public init(
        id: String,
        choreId: String,
        houseId: String,
        reviewRound: Int,
        reviewerId: String,
        isApproved: Bool,
        createdOn: String
    ) {
        self.id = id
        self.choreId = choreId
        self.houseId = houseId
        self.reviewRound = reviewRound
        self.reviewerId = reviewerId
        self.isApproved = isApproved
        self.createdOn = createdOn
    }

    private enum CodingKeys: String, CodingKey {
        case id, choreId, houseId, reviewRound, reviewerId, isApproved, createdOn
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        choreId = try container.decode(String.self, forKey: .choreId)
        houseId = try container.decode(String.self, forKey: .houseId)
        reviewRound = try container.decode(Int.self, forKey: .reviewRound)
        reviewerId = try container.decode(String.self, forKey: .reviewerId)
        isApproved = try container.decode(Bool.self, forKey: .isApproved)
        createdOn = try container.decodeAPITime(forKey: .createdOn)
    }
}

// MARK: - House information

public struct HouseInfoData: Decodable, Equatable, Sendable {
    public let houseMemberCount: Int
    public let houseMemberCountLimit: Int
    public let houseMembers: [HouseInfoMember]
    public let houseName: String
    public let houseProfileImage: String
    public let houseType: Int

    public init(
        houseMemberCount: Int,
        houseMemberCountLimit: Int,
        houseMembers: [HouseInfoMember],
        houseName: String,
        houseProfileImage: String,
        houseType: Int
    ) {
        self.houseMemberCount = houseMemberCount
        self.houseMemberCountLimit = houseMemberCountLimit
        self.houseMembers = houseMembers
        self.houseName = houseName
        self.houseProfileImage = houseProfileImage
        self.houseType = houseType
    }

    public func isOwner(userId: String?) -> Bool {
        guard let userId else { return false }
        return houseMembers.first(where: { $0.userId == userId })?.isOwner == true
    }

    public func removingMember(userId: String) -> HouseInfoData {
        let remainingMembers = houseMembers.filter { $0.userId != userId }
        return HouseInfoData(
            houseMemberCount: remainingMembers.count,
            houseMemberCountLimit: houseMemberCountLimit,
            houseMembers: remainingMembers,
            houseName: houseName,
            houseProfileImage: houseProfileImage,
            houseType: houseType
        )
    }
}

public struct HouseInfoMember: Decodable, Equatable, Identifiable, Sendable {
    public let isOwner: Bool
    public let name: String
    public let profileImage: String
    public let userId: String

    public var id: String { userId }

    public init(isOwner: Bool, name: String, profileImage: String, userId: String) {
        self.isOwner = isOwner
        self.name = name
        self.profileImage = profileImage
        self.userId = userId
    }
}

public struct HouseInviteCodeData: Decodable, Equatable, Sendable {
    public let expiresInSeconds: Int
    public let inviteCode: String
}

public struct HouseActionResponse: Decodable, Equatable, Sendable {
    public let success: Bool
    public let error: String?
}
