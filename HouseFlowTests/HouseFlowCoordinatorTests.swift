import XCTest
@testable import HouseFlow

@MainActor
final class HouseFlowCoordinatorTests: XCTestCase {
    func testCreateHouseSuccessAppliesDetailsAndShowsDashboard() async {
        let harness = makeHarness()
        let house = TestFixture.houseResponse()
        let details = TestFixture.houseDetails()
        harness.houseService.createHouseHandler = { _, _, _ in house }
        harness.houseService.fetchDetailsHandler = { _ in details }

        await harness.coordinator.beginCreateHouseFlow(
            name: "Test House",
            type: 1,
            maxMemberCount: 4
        )

        XCTAssertEqual(harness.houseStore.currentHouse?.id, "house-1")
        XCTAssertEqual(harness.houseStore.currentHouseDetails, details)
        XCTAssertEqual(harness.houseStore.houseName, "Test House")
        XCTAssertEqual(harness.router.route, .dashboard)
    }

    func testJoinHouseErrorReturnsToJoinScreenAndShowsToast() async {
        let harness = makeHarness()
        harness.houseService.joinHouseHandler = { _ in
            throw TestError.sample
        }

        await harness.coordinator.beginJoinHouseFlow(inviteCode: "INVALID")

        XCTAssertEqual(harness.router.route, .joinHouse)
        XCTAssertEqual(harness.houseStore.houseError, "test-error")
        XCTAssertEqual(harness.toastStore.message, "test-error")
        XCTAssertTrue(harness.toastStore.isError)
    }

    func testResetSessionPreventsStaleCreateResponseFromShowingDashboard() async {
        let harness = makeHarness()
        let detailsRequestStarted = expectation(description: "Details request started")
        var continuation: CheckedContinuation<HouseDetailsResponse, Error>?
        harness.houseService.createHouseHandler = { _, _, _ in
            TestFixture.houseResponse()
        }
        harness.houseService.fetchDetailsHandler = { _ in
            detailsRequestStarted.fulfill()
            return try await withCheckedThrowingContinuation { pendingContinuation in
                continuation = pendingContinuation
            }
        }

        let createTask = Task {
            await harness.coordinator.beginCreateHouseFlow(
                name: "Test House",
                type: 1,
                maxMemberCount: 4
            )
        }
        await fulfillment(of: [detailsRequestStarted], timeout: 1)

        harness.coordinator.resetSession()
        harness.authStore.isAuthenticated = false
        harness.router.showUnauthenticatedEntry()
        continuation?.resume(returning: TestFixture.houseDetails())
        await createTask.value

        XCTAssertNil(harness.houseStore.currentHouse)
        XCTAssertNil(harness.houseStore.currentHouseDetails)
        XCTAssertEqual(harness.router.route, .authentication)
    }

    private func makeHarness() -> HouseHarness {
        let keychain = FakeKeychainStore()
        keychain.authToken = "token"
        let authStore = AuthSessionStore(
            keychain: keychain,
            authService: FakeAuthService(),
            userService: FakeUserService()
        )
        authStore.isAuthenticated = true
        let houseService = FakeHouseService()
        let houseStore = HouseSessionStore(houseService: houseService)
        let toastStore = ToastStore()
        let defaults = makeDefaults()
        let router = AppRouter(
            hasAuthToken: true,
            pendingEmailVerification: nil,
            userDefaults: defaults,
            isAuthenticated: { authStore.isAuthenticated },
            pendingEmailVerification: { authStore.pendingEmailVerification }
        )
        let coordinator = HouseFlowCoordinator(
            authStore: authStore,
            houseStore: houseStore,
            toastStore: toastStore,
            router: router,
            completionDelay: .zero
        )
        return HouseHarness(
            coordinator: coordinator,
            authStore: authStore,
            houseService: houseService,
            houseStore: houseStore,
            toastStore: toastStore,
            router: router
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "HouseFlowCoordinatorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: "hasSeenOnboarding")
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}

@MainActor
private struct HouseHarness {
    let coordinator: HouseFlowCoordinator
    let authStore: AuthSessionStore
    let houseService: FakeHouseService
    let houseStore: HouseSessionStore
    let toastStore: ToastStore
    let router: AppRouter
}
