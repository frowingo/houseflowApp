import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class HouseSessionStoreTests: XCTestCase {
    func testLoadWithinCooldownServesAppliedDetailsWithoutFetching() async throws {
        let harness = HouseStoreHarness()
        let loaded = try await harness.store.loadHouseDetails(houseId: "house-1")
        harness.store.applyHouseDetails(loaded)
        harness.advanceClock(by: 29)

        let cached = try await harness.store.loadHouseDetails(houseId: "house-1")

        XCTAssertEqual(cached, loaded)
        XCTAssertEqual(harness.fetchedHouseIds, ["house-1"])
    }

    func testLoadFetchesAgainOnceCooldownHasElapsed() async throws {
        let harness = HouseStoreHarness()
        let first = try await harness.store.loadHouseDetails(houseId: "house-1")
        harness.store.applyHouseDetails(first)
        harness.advanceClock(by: 30)
        harness.houseName = "Renamed House"

        let refreshed = try await harness.store.loadHouseDetails(houseId: "house-1")

        XCTAssertEqual(refreshed.name, "Renamed House")
        XCTAssertEqual(harness.fetchedHouseIds, ["house-1", "house-1"])
    }

    func testForceRefreshBypassesCooldown() async throws {
        let harness = HouseStoreHarness()
        let first = try await harness.store.loadHouseDetails(houseId: "house-1")
        harness.store.applyHouseDetails(first)

        _ = try await harness.store.loadHouseDetails(houseId: "house-1", forceRefresh: true)

        XCTAssertEqual(harness.fetchedHouseIds, ["house-1", "house-1"])
    }

    func testLoadFetchesWhenFreshDetailsWereNeverApplied() async throws {
        let harness = HouseStoreHarness()
        _ = try await harness.store.loadHouseDetails(houseId: "house-1")

        _ = try await harness.store.loadHouseDetails(houseId: "house-1")

        XCTAssertEqual(harness.fetchedHouseIds, ["house-1", "house-1"])
        XCTAssertNil(harness.store.currentHouseDetails)
    }

    func testCooldownIsNotUsedForAnotherHouse() async throws {
        let harness = HouseStoreHarness()
        let first = try await harness.store.loadHouseDetails(houseId: "house-1")
        harness.store.applyHouseDetails(first)

        let other = try await harness.store.loadHouseDetails(houseId: "house-2")

        XCTAssertEqual(other.id, "house-2")
        XCTAssertEqual(harness.fetchedHouseIds, ["house-1", "house-2"])
    }

    func testCancellingDetailsRequestsDropsTheCooldown() async throws {
        let harness = HouseStoreHarness()
        let first = try await harness.store.loadHouseDetails(houseId: "house-1")
        harness.store.applyHouseDetails(first)

        harness.store.cancelDetailsRequests()
        _ = try await harness.store.loadHouseDetails(houseId: "house-1")

        XCTAssertEqual(harness.fetchedHouseIds, ["house-1", "house-1"])
    }

    func testConcurrentLoadsForOneHouseShareASingleFetch() async throws {
        let harness = HouseStoreHarness()
        let requestStarted = expectation(description: "Details request started")
        var continuation: CheckedContinuation<HouseDetailsResponse, Error>?
        harness.houseService.fetchDetailsHandler = { houseId in
            harness.fetchedHouseIds.append(houseId)
            requestStarted.fulfill()
            return try await withCheckedThrowingContinuation { pendingContinuation in
                continuation = pendingContinuation
            }
        }

        let first = Task { try await harness.store.loadHouseDetails(houseId: "house-1") }
        await fulfillment(of: [requestStarted], timeout: 1)
        let second = Task { try await harness.store.loadHouseDetails(houseId: "house-1") }
        // Relies on FIFO MainActor scheduling: the second Task is enqueued before these yields, so it
        // reaches `await task.value` on the shared in-flight task before the continuation is resumed.
        await Task.yield()
        await Task.yield()
        continuation?.resume(returning: TestFixture.houseDetails(id: "house-1", name: "Shared"))

        let firstResult = try await first.value
        let secondResult = try await second.value

        XCTAssertEqual(firstResult.name, "Shared")
        XCTAssertEqual(secondResult, firstResult)
        XCTAssertEqual(harness.fetchedHouseIds, ["house-1"])
    }

    func testFailedLoadDoesNotBlockTheNextLoad() async throws {
        let harness = HouseStoreHarness()
        harness.houseService.fetchDetailsHandler = { houseId in
            harness.fetchedHouseIds.append(houseId)
            if harness.fetchedHouseIds.count == 1 {
                throw TestError.sample
            }
            return TestFixture.houseDetails(id: houseId)
        }

        do {
            _ = try await harness.store.loadHouseDetails(houseId: "house-1")
            XCTFail("Expected the first load to fail")
        } catch {
            XCTAssertEqual(error as? TestError, .sample)
        }
        let details = try await harness.store.loadHouseDetails(houseId: "house-1")

        XCTAssertEqual(details.id, "house-1")
        XCTAssertEqual(harness.fetchedHouseIds, ["house-1", "house-1"])
    }

    func testRemovingMemberFallsBackToLocalRemovalWhenRefreshFails() async throws {
        let harness = HouseStoreHarness()
        harness.store.applyHouseDetails(TestFixture.houseDetails(
            members: [TestFixture.member(id: "user-1"), TestFixture.member(id: "user-2")]
        ))
        harness.houseService.removeMemberHandler = { _, _ in }
        harness.houseService.fetchDetailsHandler = { _ in throw TestError.sample }

        try await harness.store.removeHouseMember(houseId: "house-1", userId: "user-2")

        XCTAssertEqual(harness.store.currentHouseDetails?.members.map(\.id), ["user-1"])
    }

    func testCreatedAnnouncementIsInsertedFirstAndReplacedById() async throws {
        let harness = HouseStoreHarness()
        harness.store.applyHouseDetails(TestFixture.houseDetails())
        var response = Self.announcement(id: "announcement-1", title: "First")
        harness.houseService.createAnnouncementHandler = { _, _, _ in response }

        _ = try await harness.store.createAnnouncement(title: "First", description: "Body")
        response = Self.announcement(id: "announcement-2", title: "Second")
        _ = try await harness.store.createAnnouncement(title: "Second", description: "Body")
        response = Self.announcement(id: "announcement-2", title: "Second edited")
        _ = try await harness.store.createAnnouncement(title: "Second edited", description: "Body")

        XCTAssertEqual(
            harness.store.currentHouseDetails?.announcements.map(\.title),
            ["Second edited", "First"]
        )
    }

    private static func announcement(id: String, title: String) -> HouseAnnouncementDTO {
        HouseAnnouncementDTO(id: id, houseId: "house-1", title: title, message: "Body", createdOn: TestFixture.timestamp)
    }
}

@MainActor
private final class HouseStoreHarness {
    let houseService = FakeHouseService()
    private(set) var store: HouseSessionStore!
    private var clock = Date(timeIntervalSince1970: 1_000)
    var houseName = "Test House"
    var fetchedHouseIds: [String] = []

    init() {
        houseService.fetchDetailsHandler = { [unowned self] houseId in
            self.fetchedHouseIds.append(houseId)
            return TestFixture.houseDetails(id: houseId, name: self.houseName)
        }
        store = HouseSessionStore(houseService: houseService, now: { [unowned self] in self.clock })
    }

    func advanceClock(by seconds: TimeInterval) {
        clock = clock.addingTimeInterval(seconds)
    }
}
