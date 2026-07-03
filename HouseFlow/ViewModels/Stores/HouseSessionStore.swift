import Foundation
import Combine

@MainActor
final class HouseSessionStore: ObservableObject {
    @Published var hasSelectedHouse = false
    @Published var showCreateHouse = false
    @Published var showJoinHouse = false
    @Published var currentHouse: HouseResponse?
    @Published private(set) var currentHouseDetails: HouseDetailsResponse?
    @Published private(set) var houseName = ""
    @Published var houseIsLoading = false
    @Published var houseError: String?
    @Published var isInitializing: Bool
    @Published var showHouseLoading = false
    @Published var houseLoadingPhase: HouseLoadingPhase = .checkingAuth
    @Published var showHouseError = false

    private let refreshCooldown: TimeInterval = 30
    private let houseService = HouseService.shared
    private var detailsTasks: [String: Task<HouseDetailsResponse, Error>] = [:]
    private var lastDetailsFetchAt: [String: Date] = [:]

    init(isInitializing: Bool) {
        self.isInitializing = isInitializing
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

    func beginCreateHouseFlow(name: String, type: Int, maxMemberCount: Int) async throws {
        houseLoadingPhase = .creating
        showCreateHouse = false
        showHouseLoading = true
        houseError = nil

        do {
            let house = try await houseService.createHouse(name: name, type: type, maxMemberCount: maxMemberCount)
            currentHouse = house
            houseLoadingPhase = .loadingDetails

            let details = try await loadHouseDetails(houseId: house.id, forceRefresh: true)
            applyHouseDetails(details, houseNameOverride: house.name)

            try? await Task.sleep(for: .milliseconds(700))
            hasSelectedHouse = true
            showHouseLoading = false
            showHouseError = false
        } catch {
            showHouseLoading = false
            showCreateHouse = true
            houseError = error.localizedDescription
            throw error
        }
    }

    func beginJoinHouseFlow(inviteCode: String) async throws {
        houseLoadingPhase = .joining
        showJoinHouse = false
        showHouseLoading = true
        houseError = nil

        do {
            let house = try await houseService.joinHouse(inviteCode: inviteCode)
            currentHouse = house
            houseLoadingPhase = .loadingDetails

            let details = try await loadHouseDetails(houseId: house.id, forceRefresh: true)
            applyHouseDetails(details, houseNameOverride: house.name)

            try? await Task.sleep(for: .milliseconds(700))
            hasSelectedHouse = true
            showHouseLoading = false
            showHouseError = false
        } catch {
            showHouseLoading = false
            showJoinHouse = true
            houseError = error.localizedDescription
            throw error
        }
    }

    func loadFirstHouseIfPresent(for profile: IsAuthUserData, settleDelay: Duration = .milliseconds(600)) async throws -> Bool {
        guard let firstHouseId = profile.houseIds.first else {
            showHouseLoading = false
            return false
        }

        houseLoadingPhase = .loadingHouse
        let details = try await loadHouseDetails(houseId: firstHouseId)
        applyHouseDetails(details)
        try? await Task.sleep(for: settleDelay)
        showHouseLoading = false
        hasSelectedHouse = true
        showHouseError = false
        return true
    }

    func resetHouseSession() {
        cancelDetailsRequests()
        hasSelectedHouse = false
        showCreateHouse = false
        showJoinHouse = false
        showHouseLoading = false
        showHouseError = false
        isInitializing = false
        currentHouse = nil
        setCurrentHouseDetails(nil)
        setHouseName("")
    }
}
