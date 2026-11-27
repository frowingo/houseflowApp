import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class ChoreArchiveStoreTests: XCTestCase {
    private var service: FakeChoreArchiveService!

    override func setUp() async throws {
        service = FakeChoreArchiveService()
    }

    // MARK: - Month bounds

    func testOpenLoadsTheCurrentMonthInIstanbul() async throws {
        let store = makeStore(zone: "Europe/Istanbul", now: "2026-11-24T10:00:00Z")
        store.setContext(userID: "u1", houseID: "h1")
        XCTAssertTrue(service.firstCalls.isEmpty, "the archive loads only when opened")

        await store.open()

        let call = try XCTUnwrap(service.firstCalls.first)
        XCTAssertEqual(call.houseID, "h1")
        XCTAssertEqual(utc(call.from), "2026-10-31T21:00:00Z")
        XCTAssertEqual(utc(call.to), "2026-11-30T21:00:00Z")
        XCTAssertEqual(store.phase, .loaded)
    }

    func testBerlinMonthsAcrossDaylightSavingChanges() async throws {
        let march = makeStore(zone: "Europe/Berlin", now: "2026-03-15T10:00:00Z")
        march.setContext(userID: "u1", houseID: "h1")
        await march.open()
        XCTAssertEqual(utc(service.firstCalls[0].from), "2026-02-28T23:00:00Z")
        XCTAssertEqual(utc(service.firstCalls[0].to), "2026-03-31T22:00:00Z")

        let october = makeStore(zone: "Europe/Berlin", now: "2026-10-15T10:00:00Z")
        october.setContext(userID: "u1", houseID: "h1")
        await october.open()
        XCTAssertEqual(utc(service.firstCalls[1].from), "2026-09-30T22:00:00Z")
        XCTAssertEqual(utc(service.firstCalls[1].to), "2026-10-31T23:00:00Z")
    }

    func testStepsAcrossTheYearBoundary() async throws {
        let store = makeStore(zone: "Europe/Istanbul", now: "2027-01-15T10:00:00Z")
        store.setContext(userID: "u1", houseID: "h1")
        await store.open()
        await store.showPreviousMonth()
        XCTAssertEqual(utc(service.firstCalls[1].from), "2026-11-30T21:00:00Z")
        XCTAssertEqual(utc(service.firstCalls[1].to), "2026-12-31T21:00:00Z")

        await store.showNextMonth()
        XCTAssertEqual(utc(service.firstCalls[2].from), "2026-12-31T21:00:00Z")
        XCTAssertEqual(utc(service.firstCalls[2].to), "2027-01-31T21:00:00Z")
    }

    func testNextMonthStopsAtTheCurrentMonth() async {
        let store = makeStore()
        store.setContext(userID: "u1", houseID: "h1")
        await store.open()
        XCTAssertFalse(store.canShowNextMonth)

        await store.showNextMonth()
        XCTAssertEqual(service.firstCalls.count, 1)

        await store.showPreviousMonth()
        XCTAssertTrue(store.canShowNextMonth)
        await store.showNextMonth()
        XCTAssertEqual(service.firstCalls.count, 3)
        XCTAssertFalse(store.canShowNextMonth)
    }

    func testOpenReturnsToTheCurrentMonth() async {
        let store = makeStore()
        store.setContext(userID: "u1", houseID: "h1")
        await store.open()
        let current = store.monthStart
        await store.showPreviousMonth()
        XCTAssertNotEqual(store.monthStart, current)

        await store.open()

        XCTAssertEqual(store.monthStart, current)
        XCTAssertEqual(service.firstCalls.last?.from, current)
    }

    // MARK: - Paging

    func testLoadMoreAppendsWithoutDuplicatesAndStopsWithoutNextURL() async {
        let store = makeStore()
        service.first = page(["c1", "c2"], next: "/api/v1/chore/archive?cursor=a")
        service.next = ["/api/v1/chore/archive?cursor=a": page(["c2", "c3"], next: nil)]
        store.setContext(userID: "u1", houseID: "h1")
        await store.open()
        XCTAssertTrue(store.canLoadMore)

        await store.loadMore()
        await store.loadMore()

        XCTAssertEqual(store.chores.map(\.id), ["c1", "c2", "c3"])
        XCTAssertEqual(service.nextCalls, ["/api/v1/chore/archive?cursor=a"])
        XCTAssertFalse(store.canLoadMore)
    }

    func testLoadMoreFailureKeepsTheListAndFlagsIt() async {
        let store = makeStore()
        service.first = page(["c1"], next: "/api/v1/chore/archive?cursor=a")
        store.setContext(userID: "u1", houseID: "h1")
        await store.open()
        service.failure = ChoreArchiveFailure(kind: .server, message: nil)

        await store.loadMore()

        XCTAssertTrue(store.loadMoreFailed)
        XCTAssertFalse(store.isLoadingMore)
        XCTAssertEqual(store.chores.map(\.id), ["c1"])
        XCTAssertTrue(store.canLoadMore)
    }

    func testFirstPageFailureShowsTheServerMessage() async {
        let store = makeStore()
        service.failure = ChoreArchiveFailure(kind: .server, message: "Server text")
        store.setContext(userID: "u1", houseID: "h1")

        await store.open()

        XCTAssertEqual(store.phase, .failed)
        XCTAssertEqual(store.failureMessage, "Server text")

        service.failure = nil
        service.first = page(["c1"], next: nil)
        await store.refresh()
        XCTAssertEqual(store.phase, .loaded)
        XCTAssertNil(store.failureMessage)
        XCTAssertEqual(store.chores.map(\.id), ["c1"])
    }

    // MARK: - Stale answers

    func testASlowFirstPageAfterAMonthChangeIsDropped() async {
        let store = makeStore()
        store.setContext(userID: "u1", houseID: "h1")
        service.first = page(["slow"], next: "/api/v1/chore/archive?cursor=slow")
        service.gate = true
        let opening = Task { await store.open() }
        await until { self.service.firstCalls.count == 1 }

        service.gate = false
        service.first = page(["fast"], next: nil)
        await store.showPreviousMonth()
        service.releaseGate()
        await opening.value

        XCTAssertEqual(store.chores.map(\.id), ["fast"])
        XCTAssertFalse(store.canLoadMore)
        XCTAssertEqual(store.phase, .loaded)
    }

    func testALoadMoreAnswerAfterAContextChangeIsDropped() async {
        let store = makeStore()
        service.first = page(["c1"], next: "/api/v1/chore/archive?cursor=a")
        service.next = ["/api/v1/chore/archive?cursor=a": page(["late"], next: nil)]
        store.setContext(userID: "u1", houseID: "h1")
        await store.open()
        service.gate = true
        let loading = Task { await store.loadMore() }
        await until { self.service.nextCalls.count == 1 }

        store.setContext(userID: "u1", houseID: "h2")
        service.releaseGate()
        await loading.value

        XCTAssertTrue(store.chores.isEmpty)
        XCTAssertEqual(store.phase, .idle)
        XCTAssertFalse(store.isLoadingMore)
        XCTAssertFalse(store.canLoadMore)
    }

    func testARefreshDuringLoadMoreKeepsTheLateAnswerOut() async {
        let store = makeStore()
        service.first = page(["c1"], next: "/api/v1/chore/archive?cursor=a")
        service.next = ["/api/v1/chore/archive?cursor=a": page(["late"], next: nil)]
        store.setContext(userID: "u1", houseID: "h1")
        await store.open()
        service.gate = true
        let loading = Task { await store.loadMore() }
        await until { self.service.nextCalls.count == 1 }

        service.gate = false
        service.first = page(["fresh"], next: "/api/v1/chore/archive?cursor=b")
        await store.refresh()
        service.releaseGate()
        await loading.value

        XCTAssertEqual(store.chores.map(\.id), ["fresh"])
        XCTAssertFalse(store.isLoadingMore)
        XCTAssertTrue(store.canLoadMore)
    }

    func testFirstPageDropsRepeatedIDs() async {
        let store = makeStore()
        service.first = page(["c1", "c2", "c1"], next: nil)
        store.setContext(userID: "u1", houseID: "h1")

        await store.open()

        XCTAssertEqual(store.chores.map(\.id), ["c1", "c2"])
    }

    func testSigningOutClearsTheList() async {
        let store = makeStore()
        service.first = page(["c1"], next: nil)
        store.setContext(userID: "u1", houseID: "h1")
        await store.open()

        store.setContext(userID: nil, houseID: nil)
        await store.open()

        XCTAssertTrue(store.chores.isEmpty)
        XCTAssertEqual(store.phase, .idle)
        XCTAssertEqual(service.firstCalls.count, 1)
    }

    // MARK: - Access

    func testForbiddenFirstPageAndLoadMoreReportLostAccess() async {
        let store = makeStore()
        var accessLost = 0
        store.onAccessLost = { accessLost += 1 }
        service.first = page(["c1"], next: "/api/v1/chore/archive?cursor=a")
        store.setContext(userID: "u1", houseID: "h1")
        await store.open()

        service.failure = ChoreArchiveFailure(kind: .notMember, message: nil)
        await store.loadMore()
        XCTAssertEqual(accessLost, 1)
        XCTAssertFalse(store.loadMoreFailed)

        await store.showPreviousMonth()
        XCTAssertEqual(accessLost, 2)
        XCTAssertEqual(store.phase, .failed)
    }

    func testUnauthorizedFailsWithoutReportingLostAccess() async {
        let store = makeStore()
        var accessLost = 0
        store.onAccessLost = { accessLost += 1 }
        service.failure = ChoreArchiveFailure(kind: .unauthorized, message: nil)
        store.setContext(userID: "u1", houseID: "h1")

        await store.open()

        XCTAssertEqual(store.phase, .failed)
        XCTAssertEqual(accessLost, 0)
    }

    func testCancelledFirstPageIsNotShownAsFailed() async {
        let store = makeStore()
        store.setContext(userID: "u1", houseID: "h1")
        for error in [CancellationError() as any Error, URLError(.cancelled)] {
            service.failure = error
            await store.open()
            XCTAssertEqual(store.phase, .idle)
            XCTAssertNil(store.failureMessage)
        }
    }

    func testRetryAfterAFailureLoadsTheList() async {
        let store = makeStore()
        service.failure = URLError(.notConnectedToInternet)
        store.setContext(userID: "u1", houseID: "h1")
        await store.open()
        XCTAssertEqual(store.phase, .failed)

        service.failure = nil
        service.first = page(["c1"], next: nil)
        await store.refresh()

        XCTAssertEqual(store.phase, .loaded)
        XCTAssertEqual(store.chores.map(\.id), ["c1"])
    }

    // MARK: - Helpers

    private func makeStore(zone: String = "Europe/Istanbul", now: String = "2026-11-24T10:00:00Z") -> ChoreArchiveStore {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: zone)!
        let instant = ISO8601DateFormatter().date(from: now)!
        return ChoreArchiveStore(service: service, calendar: calendar, now: { instant }) { dto in
            Chore(choreApiId: dto.id, title: dto.title, assignedTo: User(name: "Ada"), dueLabel: "")
        }
    }

    private func utc(_ date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: "UTC")
        return formatter.string(from: date)
    }

    private func page(_ ids: [String], next: String?) -> ChoreArchivePage {
        ChoreArchivePage(
            chores: ids.map {
                HouseChoreDTO(
                    id: $0, title: "Chore \($0)", description: "", houseId: "h1", houseOwnerId: "u1", assignedTo: "u2",
                    dueDate: "2026-11-02T18:00:00Z", isCompleted: true, isRecurring: false, level: 10,
                    recurringInterval: 0, status: 3, createdOn: "2026-11-01T09:00:00Z",
                    completedAt: "2026-11-02T12:00:00Z", completedBy: "u2",
                    statusHistories: [], reviewRound: 1, reviewVotes: []
                )
            },
            nextURL: next
        )
    }

    private func until(_ condition: @MainActor () -> Bool) async {
        for _ in 0..<400 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }
}

@MainActor
final class FakeChoreArchiveService: ChoreArchiveServicing {
    /// The answer to every first-page call.
    var first = ChoreArchivePage(chores: [], nextURL: nil)
    /// Next pages by `nextURL`.
    var next: [String: ChoreArchivePage] = [:]
    var failure: (any Error)?
    /// While set, calls wait for `releaseGate()`.
    var gate = false
    private(set) var firstCalls: [(houseID: String, from: Date, to: Date)] = []
    private(set) var nextCalls: [String] = []
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func firstPage(houseID: String, from: Date, to: Date) async throws -> ChoreArchivePage {
        firstCalls.append((houseID, from, to))
        let page = first
        if gate { await withCheckedContinuation { waiting.append($0) } }
        if let failure { throw failure }
        return page
    }

    func nextPage(nextURL: String) async throws -> ChoreArchivePage {
        nextCalls.append(nextURL)
        let page = next[nextURL] ?? ChoreArchivePage(chores: [], nextURL: nil)
        if gate { await withCheckedContinuation { waiting.append($0) } }
        if let failure { throw failure }
        return page
    }

    func releaseGate() {
        waiting.forEach { $0.resume() }
        waiting = []
    }
}
