import Foundation

@MainActor
final class HouseFlowCoordinator {
    private let authStore: AuthSessionStore
    private let houseStore: HouseSessionStore
    private let toastStore: ToastStore
    private let router: AppRouter
    private let completionDelay: Duration
    private var flowID = UUID()

    init(
        authStore: AuthSessionStore,
        houseStore: HouseSessionStore,
        toastStore: ToastStore,
        router: AppRouter,
        completionDelay: Duration = .milliseconds(700)
    ) {
        self.authStore = authStore
        self.houseStore = houseStore
        self.toastStore = toastStore
        self.router = router
        self.completionDelay = completionDelay
    }

    func showCreateHouseScreen() {
        router.navigationDirection = .forward
        router.navigate(to: .createHouse)
    }

    func backToHouseSelection() {
        router.navigationDirection = .backward
        router.navigate(to: .houseSelection)
    }

    func showJoinHouseScreen() {
        router.navigationDirection = .forward
        router.navigate(to: .joinHouse)
    }

    func beginCreateHouseFlow(name: String, type: Int, maxMemberCount: Int) async {
        guard authStore.isAuthenticated else {
            router.showUnauthenticatedEntry()
            return
        }

        let activeFlowID = beginFlow()
        houseStore.houseError = nil
        router.navigationDirection = .forward
        router.navigate(to: .houseLoading(.creating), respectingOnboarding: false)

        do {
            let result = try await houseStore.createHouseWithDetails(
                name: name,
                type: type,
                maxMemberCount: maxMemberCount,
                onDetailsLoading: { [weak self] house in
                    guard let self,
                          self.isCurrent(activeFlowID),
                          self.authStore.isAuthenticated else { return }
                    self.houseStore.currentHouse = house
                    self.router.navigate(to: .houseLoading(.loadingDetails), respectingOnboarding: false)
                }
            )
            guard isCurrent(activeFlowID), authStore.isAuthenticated else { return }
            houseStore.applyLoadedHouse(result)
            authStore.addOrUpdateHouse(result.house)
            try? await Task.sleep(for: completionDelay)
            guard isCurrent(activeFlowID), authStore.isAuthenticated else { return }
            router.navigationDirection = .forward
            router.navigate(to: .dashboard)
        } catch {
            guard isCurrent(activeFlowID) else { return }
            houseStore.houseError = error.localizedDescription
            router.navigationDirection = .backward
            router.navigate(to: .createHouse)
            toastStore.show(message: error.localizedDescription, isError: true)
        }
    }

    func beginJoinHouseFlow(inviteCode: String) async {
        guard authStore.isAuthenticated else {
            router.showUnauthenticatedEntry()
            return
        }

        let activeFlowID = beginFlow()
        houseStore.houseError = nil
        router.navigationDirection = .forward
        router.navigate(to: .houseLoading(.joining), respectingOnboarding: false)

        do {
            let result = try await houseStore.joinHouseWithDetails(
                inviteCode: inviteCode,
                onDetailsLoading: { [weak self] house in
                    guard let self,
                          self.isCurrent(activeFlowID),
                          self.authStore.isAuthenticated else { return }
                    self.houseStore.currentHouse = house
                    self.router.navigate(to: .houseLoading(.loadingDetails), respectingOnboarding: false)
                }
            )
            guard isCurrent(activeFlowID), authStore.isAuthenticated else { return }
            houseStore.applyLoadedHouse(result)
            authStore.addOrUpdateHouse(result.house)
            try? await Task.sleep(for: completionDelay)
            guard isCurrent(activeFlowID), authStore.isAuthenticated else { return }
            router.navigationDirection = .forward
            router.navigate(to: .dashboard)
        } catch {
            guard isCurrent(activeFlowID) else { return }
            houseStore.houseError = error.localizedDescription
            router.navigationDirection = .backward
            router.navigate(to: .joinHouse)
            toastStore.show(message: error.localizedDescription, isError: true)
        }
    }

    func switchHouse(to house: AuthHouseSummary) async {
        guard authStore.isAuthenticated else {
            router.showUnauthenticatedEntry()
            return
        }
        guard authStore.currentUserProfile?.houseList.contains(where: {
            $0.houseId == house.houseId
        }) == true else {
            return
        }
        guard houseStore.currentHouseDetails?.id != house.houseId else { return }

        let activeFlowID = beginFlow()
        houseStore.houseError = nil
        router.navigationDirection = .forward
        router.navigate(to: .houseLoading(.loadingHouse), respectingOnboarding: false)

        do {
            let details = try await houseStore.loadHouseDetails(
                houseId: house.houseId,
                forceRefresh: true
            )
            guard isCurrent(activeFlowID), authStore.isAuthenticated else { return }
            houseStore.applySelectedHouseDetails(
                details,
                houseNameOverride: house.houseName
            )
            router.navigate(to: .dashboard)
        } catch {
            guard isCurrent(activeFlowID), authStore.isAuthenticated else { return }
            houseStore.houseError = error.localizedDescription
            router.navigationDirection = .backward
            router.navigate(to: .dashboard)
            toastStore.show(message: error.localizedDescription, isError: true)
        }
    }

    func leaveHouse(houseId: String) async throws {
        guard authStore.isAuthenticated, let userId = authStore.currentUserId else {
            throw NetworkError.serverError("User not authenticated.")
        }
        guard let profile = authStore.currentUserProfile,
              profile.houseList.contains(where: { $0.houseId == houseId }) else {
            return
        }

        let isLeavingActiveHouse = houseStore.currentHouseDetails?.id == houseId
        try await houseStore.leaveHouse(houseId: houseId, userId: userId)
        authStore.removeHouseSummary(houseId: houseId)

        guard isLeavingActiveHouse else { return }

        houseStore.resetHouseSession()
        houseStore.clearChosenHouseSelection()

        guard authStore.currentUserProfile?.houseList.isEmpty == false else {
            router.navigationDirection = .backward
            router.navigate(to: .houseSelection)
            return
        }

        await reloadPreferredHouse()
    }

    func reloadPreferredHouse() async {
        guard authStore.isAuthenticated, let profile = authStore.currentUserProfile else {
            router.showUnauthenticatedEntry()
            return
        }

        guard !profile.houseList.isEmpty else {
            houseStore.resetHouseSession()
            houseStore.clearChosenHouseSelection()
            router.navigationDirection = .backward
            router.navigate(to: .houseSelection)
            return
        }

        let activeFlowID = beginFlow()
        houseStore.houseError = nil
        router.navigationDirection = .forward
        router.navigate(to: .houseLoading(.loadingHouse), respectingOnboarding: false)

        do {
            guard let result = try await houseStore.loadPreferredHouseDetails(for: profile) else {
                return
            }
            guard isCurrent(activeFlowID), authStore.isAuthenticated else { return }
            houseStore.applySelectedHouseDetails(
                result.details,
                houseNameOverride: result.house.houseName
            )
            router.navigate(to: .dashboard)
        } catch {
            guard isCurrent(activeFlowID), authStore.isAuthenticated else { return }
            houseStore.resetHouseSession()
            houseStore.houseError = error.localizedDescription
            router.navigationDirection = .backward
            router.navigate(to: .houseError, respectingOnboarding: false)
            toastStore.show(message: error.localizedDescription, isError: true)
        }
    }

    func resetSession() {
        flowID = UUID()
        houseStore.resetHouseSession()
    }

    private func beginFlow() -> UUID {
        let newFlowID = UUID()
        flowID = newFlowID
        return newFlowID
    }

    private func isCurrent(_ candidate: UUID) -> Bool {
        flowID == candidate
    }
}
