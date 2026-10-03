import Foundation

@MainActor
final class ProfileCoordinator {
    private let authStore: AuthSessionStore
    private let houseStore: HouseSessionStore
    private let localizationStore: LocalizationStore
    private let toastStore: ToastStore

    init(
        authStore: AuthSessionStore,
        houseStore: HouseSessionStore,
        localizationStore: LocalizationStore,
        toastStore: ToastStore
    ) {
        self.authStore = authStore
        self.houseStore = houseStore
        self.localizationStore = localizationStore
        self.toastStore = toastStore
    }

    var currentLanguagePrefix: String? {
        authStore.currentUserProfile?.language ?? localizationStore.languagePrefix
    }

    func updateProfile(_ request: UpdateProfileRequest) async throws {
        let profile = try await authStore.updateProfile(request)
        authStore.applyAuthenticatedUser(profile)
    }

    func fetchProfileImages(category: String) async throws -> GetImagesResponse {
        try await authStore.fetchProfileImages(category: category)
    }

    func fetchHouseInfo(houseId: String) async throws -> HouseInfoData {
        try await houseStore.loadHouseInfo(houseId: houseId)
    }

    func fetchHouseProfileImages() async throws -> GetImagesResponse {
        try await authStore.fetchProfileImages(category: "house")
    }

    func createHouseInviteCode(houseId: String) async throws -> HouseInviteCodeData {
        try await houseStore.createInviteCode(houseId: houseId)
    }

    func joinHouse(inviteCode: String) async throws -> HouseResponse {
        let normalizedCode = InviteCodeRules.normalized(inviteCode)
        guard InviteCodeRules.isValid(normalizedCode) else {
            throw NetworkError.serverError("Invite code must contain 8 letters or numbers.")
        }

        let house = try await houseStore.joinHouse(inviteCode: normalizedCode)
        authStore.addOrUpdateHouse(house)
        return house
    }

    func updateHouseProfile(
        houseId: String,
        name: String,
        memberCountLimit: Int,
        profileImage: String,
        houseType: Int
    ) async throws -> HouseInfoData {
        let request = UpdateHouseProfileRequest(
            houseMemberCountLimit: memberCountLimit,
            houseName: name,
            houseProfileImage: profileImage,
            houseType: houseType
        )
        let info = try await houseStore.updateHouseProfile(
            houseId: houseId,
            request: request
        )
        authStore.updateHouseSummary(
            houseId: houseId,
            name: info.houseName,
            profileImage: info.houseProfileImage
        )
        return info
    }

    func removeHouseMember(houseId: String, userId: String) async throws {
        try await houseStore.removeHouseMember(houseId: houseId, userId: userId)
    }

    func updateLocalizationLanguage(prefix: String) async throws {
        let request = UpdateProfileRequest(
            imageUrl: nil,
            birthDay: nil,
            firstName: nil,
            lastName: nil,
            phoneNumber: nil,
            language: prefix
        )
        try await updateProfile(request)
        try await localizationStore.refreshLanguagePrefix(prefix)
    }

    func saveLanguagePreferenceAndRequireLogin(
        prefix: String,
        onRequireLogin: () -> Void
    ) async throws {
        try await updateLocalizationLanguage(prefix: prefix)
        onRequireLogin()
        toastStore.show(
            message: localizationStore.value(for: "language_settings_relogin_message"),
            isError: false
        )
    }
}
