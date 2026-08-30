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
