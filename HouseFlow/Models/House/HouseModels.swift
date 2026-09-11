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

// MARK: - Announcement Request

struct CreateAnnouncementRequest: Encodable {
    let description: String
    let houseId: String
    let title: String
}

// MARK: - House API Envelope

struct HouseAPIResponse<Data: Decodable>: Decodable {
    let data: Data?
    let success: Bool
    let error: String?
}

// MARK: - API Time

/// The house API may return dates either as ISO-8601 strings or as
/// `{ "time.Time": "..." }`. Keeping the normalized value as a string lets
/// the rest of the app continue using `HouseFlowDateFormatter`.
struct APITimeValue: Decodable {
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

extension KeyedDecodingContainer {
    func decodeAPITime(forKey key: Key) throws -> String {
        try decode(APITimeValue.self, forKey: key).rawValue
    }

    func decodeAPITimeIfPresent(forKey key: Key) throws -> String? {
        guard contains(key), try !decodeNil(forKey: key) else { return nil }
        return try decode(APITimeValue.self, forKey: key).rawValue
    }
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

    private enum CodingKeys: String, CodingKey {
        case id, name, inviteCode, maxMemberCount, memberIds, ownerId
        case profileImage, type, createdOn, updatedOn
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        inviteCode = try container.decode(String.self, forKey: .inviteCode)
        maxMemberCount = try container.decode(Int.self, forKey: .maxMemberCount)
        memberIds = try container.decode([String].self, forKey: .memberIds)
        ownerId = try container.decode(String.self, forKey: .ownerId)
        profileImage = try container.decode(String.self, forKey: .profileImage)
        type = try container.decode(Int.self, forKey: .type)
        createdOn = try container.decodeAPITime(forKey: .createdOn)
        updatedOn = try container.decodeAPITime(forKey: .updatedOn)
    }
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
    var announcements: [HouseAnnouncementDTO] = []
}

extension HouseDetailsResponse {
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case inviteCode
        case maxMemberCount
        case ownerId
        case profileImage
        case type
        case createdOn
        case updatedOn
        case members
        case chores
        case announcements
        case activeAnnouncements
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        inviteCode = try container.decode(String.self, forKey: .inviteCode)
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

struct HouseAnnouncementDTO: Decodable, Identifiable, Equatable {
    let id: String
    let houseId: String?
    let title: String
    let message: String
    let createdOn: String
    let updatedOn: String?
    let isActive: Bool
    let publisherId: String?
    let publisherName: String?

    init(
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
        case id
        case announcementId
        case houseId
        case announcedBy
        case title
        case message
        case content
        case description
        case body
        case createdOn
        case createdAt
        case updatedOn
        case updatedAt
        case isActive
        case createdBy
        case createdById
        case createdByUserId
        case creatorId
        case publisherId
        case userId
        case memberId
        case publisherName
        case createdByName
        case authorName
        case createdByFirstName
        case createdByLastName
        case createdByUser
        case creator
        case publisher
        case author
    }

    init(from decoder: Decoder) throws {
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
            keys: [.announcedBy, .createdById, .createdByUserId, .creatorId, .publisherId, .userId, .memberId, .createdBy]
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
        case id
        case userId
        case memberId
        case firstName
        case lastName
        case name
        case fullName
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

struct HouseMemberDTO: Decodable, Identifiable, Equatable {
    let id: String
    let firstName: String
    let lastName: String
    let email: String
    let imageUrl: String
    let isActive: Bool
    let isVerifyEmail: Bool
    let isVerifyPhone: Bool
    let language: String?
    let phoneNumber: String
    let birthDate: String?
    let houseIds: [String]
    let createdOn: String
    let updatedOn: String
    let lastLogin: String

    var fullName: String { "\(firstName) \(lastName)" }

    private enum CodingKeys: String, CodingKey {
        case id, firstName, lastName, email, imageUrl, isActive
        case isVerifyEmail, isVerifyPhone, language, phoneNumber, houseIds
        case createdOn, updatedOn, lastLogin
        case birthDate = "birthDay"
    }

    init(
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

    init(from decoder: Decoder) throws {
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

    private enum CodingKeys: String, CodingKey {
        case id, title, description, houseId, houseOwnerId, assignedTo
        case dueDate, isCompleted, isRecurring, level, recurringInterval
        case status, createdOn, completedAt, completedBy, statusHistories
        case reviewRound, reviewVotes
    }

    init(
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

    init(from decoder: Decoder) throws {
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

struct ChoreStatusHistory: Decodable, Identifiable, Equatable {
    let id: String
    let choreId: String
    let status: Int
    let updater: String
    let dateTime: String

    private enum CodingKeys: String, CodingKey {
        case id, choreId, status, updater, dateTime
    }

    init(id: String, choreId: String, status: Int, updater: String, dateTime: String) {
        self.id = id
        self.choreId = choreId
        self.status = status
        self.updater = updater
        self.dateTime = dateTime
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(String.self, forKey: .id)
        choreId = try container.decode(String.self, forKey: .choreId)
        status = try container.decode(Int.self, forKey: .status)
        updater = try container.decode(String.self, forKey: .updater)
        dateTime = try container.decodeAPITime(forKey: .dateTime)
    }
}

// MARK: - HouseChoreDTO helpers

extension HouseChoreDTO {
    /// Converts `dueDate` (ISO-8601) into a human-readable due label.
    var dueLabelString: String {
        HouseFlowDateFormatter.dueLabel(from: dueDate)
    }
}
