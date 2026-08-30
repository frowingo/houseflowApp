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
    private let houseService = HouseService.shared
    private var detailsTasks: [String: Task<HouseDetailsResponse, Error>] = [:]
    private var lastDetailsFetchAt: [String: Date] = [:]

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

    func beginCreateHouseFlow(
        name: String,
        type: Int,
        maxMemberCount: Int,
        onDetailsLoading: () -> Void
    ) async throws {
        houseError = nil

        do {
            let house = try await houseService.createHouse(name: name, type: type, maxMemberCount: maxMemberCount)
            currentHouse = house
            onDetailsLoading()

            let details = try await loadHouseDetails(houseId: house.id, forceRefresh: true)
            applyHouseDetails(details, houseNameOverride: house.name)

            try? await Task.sleep(for: .milliseconds(700))
        } catch {
            houseError = error.localizedDescription
            throw error
        }
    }

    func beginJoinHouseFlow(
        inviteCode: String,
        onDetailsLoading: () -> Void
    ) async throws {
        houseError = nil

        do {
            let house = try await houseService.joinHouse(inviteCode: inviteCode)
            currentHouse = house
            onDetailsLoading()

            let details = try await loadHouseDetails(houseId: house.id, forceRefresh: true)
            applyHouseDetails(details, houseNameOverride: house.name)

            try? await Task.sleep(for: .milliseconds(700))
        } catch {
            houseError = error.localizedDescription
            throw error
        }
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
