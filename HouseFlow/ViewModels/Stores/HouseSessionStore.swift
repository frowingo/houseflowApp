import Foundation
import Combine

@MainActor
final class HouseSessionStore: ObservableObject {
    @Published var currentHouse: HouseResponse?
    @Published private(set) var currentHouseDetails: HouseDetailsResponse?
    @Published private(set) var houseName = ""
    @Published var houseIsLoading = false
    @Published var houseError: String?

    private let refreshCooldown: TimeInterval = 30
    private let houseService: any HouseServicing
    private let userDefaults: UserDefaults
    private var detailsTasks: [String: Task<HouseDetailsResponse, Error>] = [:]
    private var lastDetailsFetchAt: [String: Date] = [:]

    private static let chosenHouseKey = "chosenHouse"

    init(houseService: any HouseServicing, userDefaults: UserDefaults = .standard) {
        self.houseService = houseService
        self.userDefaults = userDefaults
    }

    func setHouseName(_ name: String) {
        guard houseName != name else { return }
        houseName = name
    }

    func setCurrentHouseDetails(_ details: HouseDetailsResponse?) {
        guard currentHouseDetails != details else { return }
        currentHouseDetails = details
    }

    func applyHouseDetails(_ details: HouseDetailsResponse, houseNameOverride: String? = nil) {
        setCurrentHouseDetails(details)
        setHouseName(houseNameOverride ?? details.name)
    }

    func applySelectedHouseDetails(
        _ details: HouseDetailsResponse,
        houseNameOverride: String? = nil
    ) {
        applyHouseDetails(details, houseNameOverride: houseNameOverride)
        userDefaults.set(details.id, forKey: Self.chosenHouseKey)
    }

    func loadHouseDetails(houseId: String, forceRefresh: Bool = false) async throws -> HouseDetailsResponse {
        if !forceRefresh,
           currentHouseDetails?.id == houseId,
           let fetchedAt = lastDetailsFetchAt[houseId],
           Date().timeIntervalSince(fetchedAt) < refreshCooldown,
           let details = currentHouseDetails {
            return details
        }

        if let task = detailsTasks[houseId] {
            return try await task.value
        }

        let task = Task<HouseDetailsResponse, Error> {
            try await houseService.fetchDetails(houseId: houseId)
        }
        detailsTasks[houseId] = task

        do {
            let details = try await task.value
            detailsTasks[houseId] = nil
            lastDetailsFetchAt[houseId] = Date()
            return details
        } catch {
            detailsTasks[houseId] = nil
            throw error
        }
    }

    func loadHouseInfo(houseId: String) async throws -> HouseInfoData {
        try await houseService.fetchInfo(houseId: houseId)
    }

    func createInviteCode(houseId: String) async throws -> HouseInviteCodeData {
        try await houseService.createInviteCode(houseId: houseId)
    }

    func updateHouseProfile(
        houseId: String,
        request: UpdateHouseProfileRequest
    ) async throws -> HouseInfoData {
        let info = try await houseService.updateProfile(houseId: houseId, request: request)
        applyHouseProfile(info, houseId: houseId)
        return info
    }

    func removeHouseMember(houseId: String, userId: String) async throws {
        try await houseService.removeMember(houseId: houseId, userId: userId)
        guard currentHouseDetails?.id == houseId else { return }

        do {
            let refreshedDetails = try await loadHouseDetails(
                houseId: houseId,
                forceRefresh: true
            )
            guard currentHouseDetails?.id == houseId else { return }
            applyHouseDetails(refreshedDetails)
        } catch {
            guard let latestDetails = currentHouseDetails,
                  latestDetails.id == houseId else { return }
            setCurrentHouseDetails(latestDetails.removingMember(userId: userId))
        }
    }

    func leaveHouse(houseId: String, userId: String) async throws {
        try await houseService.removeMember(houseId: houseId, userId: userId)
    }

    func joinHouse(inviteCode: String) async throws -> HouseResponse {
        try await houseService.joinHouse(inviteCode: inviteCode)
    }

    func cancelDetailsRequests() {
        detailsTasks.values.forEach { $0.cancel() }
        detailsTasks.removeAll()
        lastDetailsFetchAt.removeAll()
    }

    func createHouseWithDetails(
        name: String,
        type: Int,
        maxMemberCount: Int,
        onDetailsLoading: (HouseResponse) -> Void
    ) async throws -> (house: HouseResponse, details: HouseDetailsResponse) {
        let house = try await houseService.createHouse(name: name, type: type, maxMemberCount: maxMemberCount)
        onDetailsLoading(house)
        let details = try await loadHouseDetails(houseId: house.id, forceRefresh: true)
        return (house, details)
    }

    func joinHouseWithDetails(
        inviteCode: String,
        onDetailsLoading: (HouseResponse) -> Void
    ) async throws -> (house: HouseResponse, details: HouseDetailsResponse) {
        let house = try await joinHouse(inviteCode: inviteCode)
        onDetailsLoading(house)
        let details = try await loadHouseDetails(houseId: house.id, forceRefresh: true)
        return (house, details)
    }

    func applyLoadedHouse(_ result: (house: HouseResponse, details: HouseDetailsResponse)) {
        currentHouse = result.house
        applySelectedHouseDetails(result.details, houseNameOverride: result.house.name)
    }

    func createAnnouncement(title: String, description: String) async throws -> HouseAnnouncementDTO {
        guard let activeDetails = currentHouseDetails, !activeDetails.id.isEmpty else {
            throw NetworkError.serverError("No active house was found.")
        }

        let announcement = try await houseService.createAnnouncement(
            title: title,
            description: description,
            houseId: activeDetails.id
        )

        // Do not merge into another house if the active selection changed while
        // the request was in flight.
        guard var latestDetails = currentHouseDetails,
              latestDetails.id == activeDetails.id else {
            return announcement
        }

        if let index = latestDetails.announcements.firstIndex(where: { $0.id == announcement.id }) {
            latestDetails.announcements[index] = announcement
        } else {
            latestDetails.announcements.insert(announcement, at: 0)
        }
        setCurrentHouseDetails(latestDetails)
        return announcement
    }

    func loadPreferredHouseDetails(
        for profile: IsAuthUserData
    ) async throws -> (house: AuthHouseSummary, details: HouseDetailsResponse)? {
        guard let preferredHouse = preferredHouse(in: profile.houseList) else { return nil }
        let details = try await loadHouseDetails(houseId: preferredHouse.houseId)
        return (preferredHouse, details)
    }

    func resetHouseSession() {
        cancelDetailsRequests()
        currentHouse = nil
        setCurrentHouseDetails(nil)
        setHouseName("")
        houseError = nil
    }

    func clearChosenHouseSelection() {
        userDefaults.removeObject(forKey: Self.chosenHouseKey)
    }

    private func preferredHouse(in houses: [AuthHouseSummary]) -> AuthHouseSummary? {
        if let chosenHouseId = userDefaults.string(forKey: Self.chosenHouseKey),
           let chosenHouse = houses.first(where: { $0.houseId == chosenHouseId }) {
            return chosenHouse
        }
        return houses.first
    }

    private func applyHouseProfile(_ info: HouseInfoData, houseId: String) {
        guard let details = currentHouseDetails, details.id == houseId else { return }

        let updatedDetails = HouseDetailsResponse(
            id: details.id,
            name: info.houseName,
            maxMemberCount: info.houseMemberCountLimit,
            ownerId: details.ownerId,
            profileImage: info.houseProfileImage,
            type: info.houseType,
            createdOn: details.createdOn,
            updatedOn: details.updatedOn,
            members: details.members,
            chores: details.chores,
            announcements: details.announcements
        )
        applyHouseDetails(updatedDetails)
    }
}

private extension HouseDetailsResponse {
    func removingMember(userId: String) -> HouseDetailsResponse {
        HouseDetailsResponse(
            id: id,
            name: name,
            maxMemberCount: maxMemberCount,
            ownerId: ownerId,
            profileImage: profileImage,
            type: type,
            createdOn: createdOn,
            updatedOn: updatedOn,
            members: members.filter { $0.id != userId },
            chores: chores,
            announcements: announcements
        )
    }
}
