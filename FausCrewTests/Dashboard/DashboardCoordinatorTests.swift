import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class DashboardCoordinatorTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        let previousLanguage = APILanguage.code
        APILanguage.update(prefix: "en")
        addTeardownBlock {
            await MainActor.run {
                APILanguage.update(prefix: previousLanguage)
            }
        }
    }

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

    func testDashboardShowsNoSampleDataWithoutHouseDetails() async {
        let harness = makeHarness()
        harness.houseStore.applyHouseDetails(
            TestFixture.houseDetails(members: [TestFixture.member()], chores: [TestFixture.houseChore()])
        )

        harness.houseStore.setCurrentHouseDetails(nil)

        XCTAssertTrue(harness.coordinator.members.isEmpty)
        XCTAssertTrue(harness.coordinator.dashboardChores.isEmpty)
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

    func testAnnouncementConnectionErrorShowsUserMessage() async {
        let harness = makeHarness()
        harness.houseStore.applyHouseDetails(TestFixture.houseDetails())
        harness.houseService.createAnnouncementHandler = { _, _, _ in
            throw URLError(.notConnectedToInternet)
        }

        let didCreate = await harness.coordinator.createAnnouncement(title: "Title", description: "Description")

        XCTAssertFalse(didCreate)
        XCTAssertEqual(harness.toastStore.message, "Unable to connect. Please check your internet connection.")
        XCTAssertTrue(harness.toastStore.isError)
    }

    func testAnnouncementCancellationStillShowsToast() async {
        let harness = makeHarness()
        harness.houseStore.applyHouseDetails(TestFixture.houseDetails())
        harness.houseService.createAnnouncementHandler = { _, _, _ in
            throw CancellationError()
        }

        let didCreate = await harness.coordinator.createAnnouncement(title: "Title", description: "Description")

        XCTAssertFalse(didCreate)
        XCTAssertEqual(harness.toastStore.message, "Something went wrong. Please try again.")
        XCTAssertTrue(harness.toastStore.isError)
    }

    func testCreatedAnnouncementIsAddedToHouseAndShowsSuccessToast() async {
        let harness = makeHarness()
        harness.houseStore.applyHouseDetails(TestFixture.houseDetails())
        harness.houseService.createAnnouncementHandler = { title, description, houseId in
            XCTAssertEqual(title, "Bins")
            XCTAssertEqual(description, "Bins go out tonight")
            XCTAssertEqual(houseId, "house-1")
            return HouseAnnouncementDTO(
                id: "announcement-1",
                houseId: houseId,
                title: title,
                message: description,
                createdOn: TestFixture.timestamp
            )
        }

        let didCreate = await harness.coordinator.createAnnouncement(title: "Bins", description: "Bins go out tonight")

        XCTAssertTrue(didCreate)
        XCTAssertEqual(harness.houseStore.currentHouseDetails?.announcements.map(\.id), ["announcement-1"])
        XCTAssertEqual(harness.toastStore.message, "Announcement published.")
        XCTAssertFalse(harness.toastStore.isError)
    }

    func testAnnouncementWithoutActiveHouseShowsErrorWithoutRequest() async {
        let harness = makeHarness()
        var requestCount = 0
        harness.houseService.createAnnouncementHandler = { _, _, _ in
            requestCount += 1
            throw TestError.unimplemented
        }

        let didCreate = await harness.coordinator.createAnnouncement(title: "Bins", description: "Tonight")

        XCTAssertFalse(didCreate)
        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(harness.toastStore.message, "No active house was found.")
        XCTAssertTrue(harness.toastStore.isError)
    }

    func testCreatingChoreSendsRequestAddsItToHouseAndShowsSuccessToast() async throws {
        let harness = makeHarness()
        harness.houseStore.applyHouseDetails(TestFixture.houseDetails(members: [TestFixture.member()]))
        let dueDate = Date(timeIntervalSince1970: 1_800_000_000)
        let created = try Self.choreResponse(id: "chore-new", status: ChoreStatus.draft.rawValue)
        harness.choreService.createChoreHandler = {
            assignedTo, description, apiDueDate, houseId, isRecurring, level, recurringInterval, title in
            XCTAssertEqual(assignedTo, "user-1")
            XCTAssertEqual(description, "Sweep the hall")
            XCTAssertEqual(apiDueDate, FausCrewDateFormatter.apiString(from: dueDate))
            XCTAssertEqual(houseId, "house-1")
            XCTAssertTrue(isRecurring)
            XCTAssertEqual(level, .hard)
            XCTAssertEqual(recurringInterval, 7)
            XCTAssertEqual(title, "Sweep")
            return created
        }

        let didCreate = await harness.coordinator.createChore(
            assignedToId: "user-1",
            description: "Sweep the hall",
            dueDate: dueDate,
            houseId: "house-1",
            isRecurring: true,
            level: .hard,
            recurringInterval: 7,
            title: "Sweep",
            category: .floorsGeneral
        )

        XCTAssertTrue(didCreate)
        XCTAssertEqual(harness.choreService.lastCreatedCategory, .floorsGeneral)
        XCTAssertEqual(harness.houseStore.currentHouseDetails?.chores.map(\.id), ["chore-new"])
        XCTAssertEqual(harness.coordinator.dashboardChores.map(\.choreApiId), ["chore-new"])
        // Without a server copy the localized lookup falls back to the key.
        XCTAssertEqual(harness.toastStore.message, "chore_created_toast")
        XCTAssertFalse(harness.toastStore.isError)
    }

    func testFailedChoreCreationShowsServerMessageAndLeavesHouseUnchanged() async {
        let harness = makeHarness()
        harness.houseStore.applyHouseDetails(TestFixture.houseDetails())
        harness.choreService.createChoreHandler = { _, _, _, _, _, _, _, _ in
            throw NetworkError.serverError("Chore limit reached.")
        }

        let didCreate = await harness.coordinator.createChore(
            assignedToId: "user-1",
            description: "",
            dueDate: Date(timeIntervalSince1970: 1_800_000_000),
            houseId: "house-1",
            isRecurring: false,
            level: .easy,
            recurringInterval: 0,
            title: "Sweep",
            category: .uncategorized
        )

        XCTAssertFalse(didCreate)
        XCTAssertEqual(harness.houseStore.currentHouseDetails?.chores, [])
        XCTAssertEqual(harness.toastStore.message, "Chore limit reached.")
        XCTAssertTrue(harness.toastStore.isError)
    }

    func testApprovingReviewReplacesChoreInHouseAndShowsApprovedToast() async throws {
        let harness = makeHarness()
        harness.houseStore.applyHouseDetails(TestFixture.houseDetails(chores: [TestFixture.houseChore()]))
        let reviewed = try Self.choreResponse(id: "chore-1", status: ChoreStatus.completed.rawValue)
        harness.choreService.reviewChoreHandler = { choreId, isApproved in
            XCTAssertEqual(choreId, "chore-1")
            XCTAssertTrue(isApproved)
            return reviewed
        }

        let didReview = await harness.coordinator.reviewChore(choreApiId: "chore-1", isApproved: true)

        XCTAssertTrue(didReview)
        XCTAssertEqual(harness.houseStore.currentHouseDetails?.chores.map(\.id), ["chore-1"])
        XCTAssertEqual(harness.houseStore.currentHouseDetails?.chores.first?.status, ChoreStatus.completed.rawValue)
        XCTAssertEqual(harness.toastStore.message, "chore_approved_toast")
        XCTAssertFalse(harness.toastStore.isError)
    }

    func testRejectingReviewSendsDecisionAndShowsSentBackToast() async throws {
        let harness = makeHarness()
        harness.houseStore.applyHouseDetails(TestFixture.houseDetails(chores: [TestFixture.houseChore()]))
        let reviewed = try Self.choreResponse(id: "chore-1", status: ChoreStatus.progress.rawValue)
        harness.choreService.reviewChoreHandler = { choreId, isApproved in
            XCTAssertEqual(choreId, "chore-1")
            XCTAssertFalse(isApproved)
            return reviewed
        }

        let didReview = await harness.coordinator.reviewChore(choreApiId: "chore-1", isApproved: false)

        XCTAssertTrue(didReview)
        XCTAssertEqual(harness.toastStore.message, "chore_sent_back_toast")
        XCTAssertFalse(harness.toastStore.isError)
    }

    func testFailedReviewShowsServerMessageAndKeepsChoreStatus() async {
        let harness = makeHarness()
        harness.houseStore.applyHouseDetails(TestFixture.houseDetails(chores: [TestFixture.houseChore()]))
        harness.choreService.reviewChoreHandler = { _, _ in
            throw NetworkError.serverError("Review already submitted.")
        }

        let didReview = await harness.coordinator.reviewChore(choreApiId: "chore-1", isApproved: true)

        XCTAssertFalse(didReview)
        XCTAssertEqual(harness.houseStore.currentHouseDetails?.chores.first?.status, ChoreStatus.draft.rawValue)
        XCTAssertEqual(harness.toastStore.message, "Review already submitted.")
        XCTAssertTrue(harness.toastStore.isError)
    }

    private static func choreResponse(id: String, status: Int) throws -> ChoreResponse {
        let json = """
        {"id":"\(id)","title":"Wash dishes","description":"Kitchen","houseId":"house-1",\
        "houseOwnerId":"user-1","assignedTo":"user-1","dueDate":"2026-01-02T00:00:00Z",\
        "isCompleted":false,"isRecurring":false,"level":10,"recurringInterval":0,"status":\(status),\
        "createdOn":"2026-01-01T00:00:00Z","statusHistories":[],"reviewRound":0,"reviewVotes":[]}
        """
        return try JSONDecoder().decode(ChoreResponse.self, from: Data(json.utf8))
    }

    private func makeHarness() -> DashboardHarness {
        let authStore = AuthSessionStore(
            keychain: FakeKeychainStore(),
            authService: FakeAuthService(),
            userService: FakeUserService()
        )
        let houseService = FakeHouseService()
        let houseStore = HouseSessionStore(houseService: houseService)
        let choreService = FakeChoreService()
        let localization = TestFixture.localizationStore()
        addTeardownBlock {
            try? FileManager.default.removeItem(at: localization.directory)
        }
        let toastStore = ToastStore()
        let coordinator = DashboardCoordinator(
            authStore: authStore,
            houseStore: houseStore,
            dashboardStore: DashboardStore(),
            choreStore: ChoreStore(choreService: choreService),
            localizationStore: localization.store,
            toastStore: toastStore
        )
        return DashboardHarness(
            coordinator: coordinator,
            authStore: authStore,
            houseStore: houseStore,
            houseService: houseService,
            choreService: choreService,
            toastStore: toastStore
        )
    }
}

@MainActor
private struct DashboardHarness {
    let coordinator: DashboardCoordinator
    let authStore: AuthSessionStore
    let houseStore: HouseSessionStore
    let houseService: FakeHouseService
    let choreService: FakeChoreService
    let toastStore: ToastStore
}
