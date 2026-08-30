import XCTest
@testable import HouseFlow

@MainActor
final class DashboardCoordinatorTests: XCTestCase {
    func testHouseDetailsAreMappedIntoDashboardState() async {
        let harness = makeHarness()
        harness.authStore.applyAuthenticatedUser(
            TestFixture.profile(houseIds: ["house-1"])
        )

        harness.houseStore.applyHouseDetails(
            TestFixture.houseDetails(
                members: [TestFixture.member()],
                chores: [TestFixture.houseChore()]
            )
        )

        XCTAssertEqual(harness.coordinator.members.count, 1)
        XCTAssertEqual(harness.coordinator.members.first?.apiId, "user-1")
        XCTAssertEqual(harness.coordinator.dashboardChores.count, 1)
        XCTAssertEqual(harness.coordinator.dashboardChores.first?.choreApiId, "chore-1")
        XCTAssertEqual(harness.coordinator.dashboardChores.first?.assignedTo.apiId, "user-1")
    }

    func testClearSessionRemovesLocalChores() async {
        let harness = makeHarness()
        harness.coordinator.chores = [
            Chore(
                title: "Local chore",
                assignedTo: User(firstName: "Ada", lastName: "Lovelace"),
                dueLabel: "Today"
            )
        ]

        harness.coordinator.clearSession()

        XCTAssertTrue(harness.coordinator.chores.isEmpty)
        XCTAssertTrue(harness.coordinator.dashboardChores.isEmpty)
    }

    private func makeHarness() -> DashboardHarness {
        let authStore = AuthSessionStore(
            keychain: FakeKeychainStore(),
            authService: FakeAuthService(),
            userService: FakeUserService()
        )
        let houseStore = HouseSessionStore(houseService: FakeHouseService())
        let localization = TestFixture.localizationStore()
        addTeardownBlock {
            try? FileManager.default.removeItem(at: localization.directory)
        }
        let coordinator = DashboardCoordinator(
            authStore: authStore,
            houseStore: houseStore,
            dashboardStore: DashboardStore(),
            choreStore: ChoreStore(choreService: FakeChoreService()),
            localizationStore: localization.store,
            toastStore: ToastStore()
        )
        return DashboardHarness(
            coordinator: coordinator,
            authStore: authStore,
            houseStore: houseStore
        )
    }
}

@MainActor
private struct DashboardHarness {
    let coordinator: DashboardCoordinator
    let authStore: AuthSessionStore
    let houseStore: HouseSessionStore
}
