import Foundation
@testable import HouseFlow

enum TestError: LocalizedError {
    case sample
    case unimplemented

    var errorDescription: String? {
        switch self {
        case .sample:
            return "test-error"
        case .unimplemented:
            return "test-double-not-configured"
        }
    }
}

@MainActor
final class FakeKeychainStore: KeychainStoring {
    var authToken: String?
    var userEmail: String?
    var userFirstName: String?
    var userLastName: String?
    var pendingEmailVerification: String?
}

@MainActor
final class FakeAuthService: AuthServicing {
    var signupHandler: (String, String, String, String) async throws -> AuthTokenResponse = { _, _, _, _ in
        throw TestError.unimplemented
    }
    var loginHandler: (String, String) async throws -> AuthTokenResponse = { _, _ in
        throw TestError.unimplemented
    }
    var forgotPasswordHandler: (String) async throws -> ForgotPasswordResponse = { _ in
        throw TestError.unimplemented
    }
    var resetPasswordHandler: (String, String, String) async throws -> MessageResponse = { _, _, _ in
        throw TestError.unimplemented
    }
    var sendEmailVerificationCodeHandler: () async throws -> ValidateEmailResponse = {
        throw TestError.unimplemented
    }
    var validateEmailHandler: (String) async throws -> ValidateEmailResponse = { _ in
        throw TestError.unimplemented
    }
    var isAuthHandler: () async throws -> IsAuthResponse = {
        throw TestError.unimplemented
    }
    private(set) var logoutCallCount = 0

    func signup(
        email: String,
        password: String,
        firstName: String,
        lastName: String
    ) async throws -> AuthTokenResponse {
        try await signupHandler(email, password, firstName, lastName)
    }

    func login(email: String, password: String) async throws -> AuthTokenResponse {
        try await loginHandler(email, password)
    }

    func forgotPassword(email: String) async throws -> ForgotPasswordResponse {
        try await forgotPasswordHandler(email)
    }

    func resetPassword(email: String, code: String, newPassword: String) async throws -> MessageResponse {
        try await resetPasswordHandler(email, code, newPassword)
    }

    func sendEmailVerificationCode() async throws -> ValidateEmailResponse {
        try await sendEmailVerificationCodeHandler()
    }

    func validateEmail(code: String) async throws -> ValidateEmailResponse {
        try await validateEmailHandler(code)
    }

    func isAuth() async throws -> IsAuthResponse {
        try await isAuthHandler()
    }

    func logout() {
        logoutCallCount += 1
    }
}

@MainActor
final class FakeUserService: UserServicing {
    var getImagesHandler: (String) async throws -> GetImagesResponse = { _ in
        throw TestError.unimplemented
    }
    var updateProfileHandler: (String, UpdateProfileRequest) async throws -> UpdateProfileResponse = { _, _ in
        throw TestError.unimplemented
    }
    private(set) var lastUpdatedUserId: String?
    private(set) var lastUpdateRequest: UpdateProfileRequest?

    func getImages(category: String) async throws -> GetImagesResponse {
        try await getImagesHandler(category)
    }

    func updateProfile(
        userId: String,
        request: UpdateProfileRequest
    ) async throws -> UpdateProfileResponse {
        lastUpdatedUserId = userId
        lastUpdateRequest = request
        return try await updateProfileHandler(userId, request)
    }
}

@MainActor
final class FakeHouseService: HouseServicing {
    var createHouseHandler: (String, Int, Int) async throws -> HouseResponse = { _, _, _ in
        throw TestError.unimplemented
    }
    var fetchDetailsHandler: (String) async throws -> HouseDetailsResponse = { _ in
        throw TestError.unimplemented
    }
    var fetchInfoHandler: (String) async throws -> HouseInfoData = { _ in
        throw TestError.unimplemented
    }
    var updateProfileHandler: (String, UpdateHouseProfileRequest) async throws -> HouseInfoData = { _, _ in
        throw TestError.unimplemented
    }
    var createInviteCodeHandler: (String) async throws -> HouseInviteCodeData = { _ in
        throw TestError.unimplemented
    }
    var removeMemberHandler: (String, String) async throws -> Void = { _, _ in
        throw TestError.unimplemented
    }
    var joinHouseHandler: (String) async throws -> HouseResponse = { _ in
        throw TestError.unimplemented
    }
    var createAnnouncementHandler: (String, String, String) async throws -> HouseAnnouncementDTO = { _, _, _ in
        throw TestError.unimplemented
    }

    func createHouse(name: String, type: Int, maxMemberCount: Int) async throws -> HouseResponse {
        try await createHouseHandler(name, type, maxMemberCount)
    }

    func fetchDetails(houseId: String) async throws -> HouseDetailsResponse {
        try await fetchDetailsHandler(houseId)
    }

    func fetchInfo(houseId: String) async throws -> HouseInfoData {
        try await fetchInfoHandler(houseId)
    }

    func updateProfile(
        houseId: String,
        request: UpdateHouseProfileRequest
    ) async throws -> HouseInfoData {
        try await updateProfileHandler(houseId, request)
    }

    func createInviteCode(houseId: String) async throws -> HouseInviteCodeData {
        try await createInviteCodeHandler(houseId)
    }

    func removeMember(houseId: String, userId: String) async throws {
        try await removeMemberHandler(houseId, userId)
    }

    func joinHouse(inviteCode: String) async throws -> HouseResponse {
        try await joinHouseHandler(inviteCode)
    }

    func createAnnouncement(
        title: String,
        description: String,
        houseId: String
    ) async throws -> HouseAnnouncementDTO {
        try await createAnnouncementHandler(title, description, houseId)
    }
}

@MainActor
final class FakeChoreService: ChoreServicing {
    var createChoreHandler: (
        String,
        String,
        String,
        String,
        Bool,
        ChoreLevel,
        Int,
        String
    ) async throws -> ChoreResponse = { _, _, _, _, _, _, _, _ in
        throw TestError.unimplemented
    }
    var updateStatusHandler: (String, [ChoreStatusUpdateItem]) async throws -> [ChoreResponse] = { _, _ in
        throw TestError.unimplemented
    }
    var reviewChoreHandler: (String, Bool) async throws -> ChoreResponse = { _, _ in
        throw TestError.unimplemented
    }

    func createChore(
        assignedTo: String,
        description: String,
        dueDate: String,
        houseId: String,
        isRecurring: Bool,
        level: ChoreLevel,
        recurringInterval: Int,
        title: String
    ) async throws -> ChoreResponse {
        try await createChoreHandler(
            assignedTo,
            description,
            dueDate,
            houseId,
            isRecurring,
            level,
            recurringInterval,
            title
        )
    }

    func updateChoreStatus(
        houseId: String,
        chores: [ChoreStatusUpdateItem]
    ) async throws -> [ChoreResponse] {
        try await updateStatusHandler(houseId, chores)
    }

    func reviewChore(choreId: String, isApproved: Bool) async throws -> ChoreResponse {
        try await reviewChoreHandler(choreId, isApproved)
    }
}

@MainActor
final class FakeLocalizationService: LocalizationServicing {
    var fetchLanguagesHandler: () async throws -> [LocalizationLanguage] = { [] }
    var fetchPlaintextsHandler: (String) async throws -> [LocalizationPlaintextItem] = { _ in [] }

    func fetchLanguages() async throws -> [LocalizationLanguage] {
        try await fetchLanguagesHandler()
    }

    func fetchPlaintexts(languagePrefix: String) async throws -> [LocalizationPlaintextItem] {
        try await fetchPlaintextsHandler(languagePrefix)
    }
}

@MainActor
final class NetworkRequestStub {
    var responseData = Data()
    var statusCode = 200
    var responseHeaders: [String: String] = [:]
    var error: Error?
    private(set) var requests: [URLRequest] = []

    func execute(_ request: URLRequest) async throws -> (Data, URLResponse) {
        requests.append(request)
        if let error {
            throw error
        }

        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: "HTTP/1.1",
            headerFields: responseHeaders
        )!
        return (responseData, response)
    }
}

@MainActor
enum TestFixture {
    static let timestamp = "2026-01-01T00:00:00Z"

    static func profile(
        id: String = "user-1",
        isVerified: Bool = true,
        birthDate: String? = "1990-01-01T00:00:00Z",
        houseIds: [String] = [],
        language: String? = "en"
    ) -> IsAuthUserData {
        IsAuthUserData(
            birthDate: birthDate,
            createdOn: timestamp,
            email: "user@example.com",
            firstName: "Ada",
            houseList: houseIds.map {
                AuthHouseSummary(
                    houseId: $0,
                    houseName: "House \($0)",
                    houseProfile: ""
                )
            },
            id: id,
            imageUrl: "",
            isActive: true,
            isVerifyEmail: isVerified,
            isVerifyPhone: false,
            language: language,
            lastLogin: timestamp,
            lastName: "Lovelace",
            phoneNumber: "",
            updatedOn: timestamp
        )
    }

    static func userResult(language: String? = "en") -> UserResultModel {
        UserResultModel(
            id: "user-1",
            firstName: "Ada",
            lastName: "Lovelace",
            email: "user@example.com",
            imageUrl: "",
            birthDate: "1990-01-01T00:00:00Z",
            isActive: true,
            isVerifyEmail: true,
            isVerifyPhone: false,
            language: language,
            phoneNumber: "",
            houseIds: [],
            createdOn: timestamp,
            updatedOn: timestamp,
            lastLogin: timestamp
        )
    }

    static func houseResponse(
        id: String = "house-1",
        name: String = "Test House"
    ) -> HouseResponse {
        let json = """
        {
          "id": "\(id)",
          "name": "\(name)",
          "inviteCode": "JOINME",
          "maxMemberCount": 4,
          "memberIds": ["user-1"],
          "ownerId": "user-1",
          "profileImage": "",
          "type": 1,
          "createdOn": "2026-01-01T00:00:00Z",
          "updatedOn": "2026-01-01T00:00:00Z"
        }
        """
        return try! JSONDecoder().decode(HouseResponse.self, from: Data(json.utf8))
    }

    static func member(id: String = "user-1") -> HouseMemberDTO {
        HouseMemberDTO(
            id: id,
            firstName: "Ada",
            lastName: "Lovelace",
            email: "user@example.com",
            imageUrl: "",
            isActive: true,
            isVerifyEmail: true,
            isVerifyPhone: false,
            phoneNumber: "",
            birthDate: "1990-01-01T00:00:00Z",
            houseIds: ["house-1"],
            createdOn: timestamp,
            updatedOn: timestamp,
            lastLogin: timestamp
        )
    }

    static func houseChore(assignedTo: String = "user-1") -> HouseChoreDTO {
        HouseChoreDTO(
            id: "chore-1",
            title: "Wash dishes",
            description: "Kitchen",
            houseId: "house-1",
            houseOwnerId: "user-1",
            assignedTo: assignedTo,
            dueDate: "2026-01-02T00:00:00Z",
            isCompleted: false,
            isRecurring: false,
            level: ChoreLevel.easy.rawValue,
            recurringInterval: 0,
            status: ChoreStatus.draft.rawValue,
            createdOn: timestamp,
            completedAt: nil,
            completedBy: nil,
            statusHistories: [],
            reviewRound: 0,
            reviewVotes: []
        )
    }

    static func houseDetails(
        id: String = "house-1",
        name: String = "Test House",
        members: [HouseMemberDTO] = [],
        chores: [HouseChoreDTO] = []
    ) -> HouseDetailsResponse {
        HouseDetailsResponse(
            id: id,
            name: name,
            maxMemberCount: 4,
            ownerId: "user-1",
            profileImage: "",
            type: 1,
            createdOn: timestamp,
            updatedOn: timestamp,
            members: members,
            chores: chores,
            announcements: []
        )
    }

    static func houseInfo(
        name: String = "Test House",
        memberCountLimit: Int = 4,
        profileImage: String = "",
        members: [HouseInfoMember] = [
            HouseInfoMember(
                isOwner: true,
                name: "Ada Lovelace",
                profileImage: "",
                userId: "user-1"
            )
        ]
    ) -> HouseInfoData {
        HouseInfoData(
            houseMemberCount: members.count,
            houseMemberCountLimit: memberCountLimit,
            houseMembers: members,
            houseName: name,
            houseProfileImage: profileImage,
            houseType: 1
        )
    }

    static func localizationStore() -> (store: LocalizationStore, directory: URL) {
        localizationStore(service: FakeLocalizationService())
    }

    static func localizationStore(
        service: FakeLocalizationService
    ) -> (store: LocalizationStore, directory: URL) {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("HouseFlowTests-\(UUID().uuidString)", isDirectory: true)
        let store = LocalizationStore(
            service: service,
            cache: LocalizationDiskCache(baseDirectory: directory)
        )
        return (store, directory)
    }
}
