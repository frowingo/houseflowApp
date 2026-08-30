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
    private var detailsTasks: [String: Task<HouseDetailsResponse, Error>] = [:]
    private var lastDetailsFetchAt: [String: Date] = [:]

    convenience init() {
        self.init(houseService: HouseService.shared)
    }

    init(houseService: any HouseServicing) {
        self.houseService = houseService
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
        let house = try await houseService.joinHouse(inviteCode: inviteCode)
        onDetailsLoading(house)
        let details = try await loadHouseDetails(houseId: house.id, forceRefresh: true)
        return (house, details)
    }

    func applyLoadedHouse(_ result: (house: HouseResponse, details: HouseDetailsResponse)) {
        currentHouse = result.house
        applyHouseDetails(result.details, houseNameOverride: result.house.name)
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

    func fetchFirstHouseDetails(for profile: IsAuthUserData) async throws -> HouseDetailsResponse? {
        guard let firstHouseId = profile.houseIds.first else { return nil }
        return try await loadHouseDetails(houseId: firstHouseId)
    }

    func resetHouseSession() {
        cancelDetailsRequests()
        currentHouse = nil
        setCurrentHouseDetails(nil)
        setHouseName("")
        houseError = nil
    }
}
