import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class NotificationStoreTests: XCTestCase {
    private var service: FakeNotificationService!
    private var preferences: InMemoryPreferences!
    private var store: NotificationStore!

    override func setUp() async throws {
        service = FakeNotificationService()
        preferences = InMemoryPreferences()
        store = NotificationStore(service: service, preferences: preferences)
    }

    func testBadgeCountsPageOneItemsNewerThanTheStoredMarker() async {
        NotificationSeen.save(
            NotificationSeenMarker(createdAt: "2026-11-20T10:00:00Z", id: "n2"),
            to: preferences, userID: "u1", houseID: "h1"
        )
        service.pages = [nil: NotificationPage(items: [item("n3", "11:00"), item("n2", "10:00"), item("n1", "09:00")], nextCursor: nil)]

        store.setContext(userID: "u1", houseID: "h1")
        await until { self.store.phase == .loaded }

        XCTAssertEqual(store.unreadCount, 1)
        XCTAssertEqual(service.calls.map { $0.before }, [nil])
    }

    func testWithoutAStoredMarkerEveryPageOneItemIsUnread() async {
        service.pages = [nil: NotificationPage(items: [item("n2", "10:00"), item("n1", "09:00")], nextCursor: nil)]

        store.setContext(userID: "u1", houseID: "h1")
        await until { self.store.phase == .loaded }

        XCTAssertEqual(store.unreadCount, 2)
    }

    func testOpeningThePanelSavesTheNewestItemAndClearsTheBadge() async {
        service.pages = [nil: NotificationPage(items: [item("n2", "10:00"), item("n1", "09:00")], nextCursor: nil)]
        store.setContext(userID: "u1", houseID: "h1")
        await until { self.store.unreadCount == 2 }

        await store.openPanel()

        XCTAssertEqual(store.unreadCount, 0)
        XCTAssertTrue(store.isPanelOpen)
        XCTAssertEqual(
            NotificationSeen.load(from: preferences, userID: "u1", houseID: "h1"),
            NotificationSeenMarker(createdAt: "2026-11-20T10:00:00Z", id: "n2")
        )
        // The accent bars still know what was new when the panel opened.
        XCTAssertTrue(store.isUnread(item("n2", "10:00")))

        store.closePanel()
        await store.openPanel()
        XCTAssertFalse(store.isUnread(item("n2", "10:00")))
    }

    func testPagingUsesTheCursorAndStopsWhenItIsNil() async {
        service.pages = [
            nil: NotificationPage(items: [item("n3", "11:00")], nextCursor: "c1"),
            "c1": NotificationPage(items: [item("n2", "10:00"), item("n3", "11:00")], nextCursor: nil),
        ]
        await openPanel()

        await store.loadMore()
        await store.loadMore()

        XCTAssertEqual(service.calls.map { $0.before }, [nil, nil, "c1"])
        // The duplicate of page 1 is not added twice.
        XCTAssertEqual(store.items.map(\.id), ["n3", "n2"])
    }

    func testListForbiddenWhileOpeningClosesThePanelAndRefreshesTheProfile() async {
        service.failure = NotificationFailure(kind: .notMember, message: nil)
        var accessLost = 0
        store.onAccessLost = { accessLost += 1 }
        store.setContext(userID: "u1", houseID: "h1")
        await until { self.service.calls.count == 1 }

        await store.openPanel()

        XCTAssertFalse(store.isPanelOpen)
        XCTAssertEqual(accessLost, 1)
        XCTAssertEqual(store.phase, .failed)
    }

    func testBadgeFetchFailureIsSilent() async {
        service.failure = NotificationFailure(kind: .notFound, message: nil)
        var accessLost = 0
        store.onAccessLost = { accessLost += 1 }

        store.setContext(userID: "u1", houseID: "h1")
        await until { self.service.calls.count == 1 }
        await Task.yield()

        XCTAssertEqual(accessLost, 0)
        XCTAssertEqual(store.phase, .idle)
        XCTAssertEqual(store.unreadCount, 0)
    }

    func testFailureWithoutItemsShowsTheErrorStateAndRetryLoads() async {
        service.failure = URLError(.notConnectedToInternet)
        store.setContext(userID: "u1", houseID: "h1")
        await until { self.service.calls.count == 1 }

        await store.openPanel()
        XCTAssertEqual(store.phase, .failed)

        service.failure = nil
        service.pages = [nil: NotificationPage(items: [item("n1", "09:00")], nextCursor: nil)]
        await store.refresh()
        XCTAssertEqual(store.phase, .loaded)
        XCTAssertEqual(store.items.count, 1)
    }

    func testSilentRefreshWhileOpenKeepsThePagedList() async {
        service.pages = [
            nil: NotificationPage(items: [item("n3", "11:00")], nextCursor: "c1"),
            "c1": NotificationPage(items: [item("n2", "10:00")], nextCursor: nil),
        ]
        await openPanel()
        await store.loadMore()
        XCTAssertEqual(store.items.map(\.id), ["n3", "n2"])

        service.pages[nil] = NotificationPage(items: [item("n4", "12:00"), item("n3", "11:00")], nextCursor: "c1")
        store.notificationsChanged(houseID: "h1")
        await until { self.store.items.count == 3 }

        XCTAssertEqual(store.items.map(\.id), ["n4", "n3", "n2"])
        XCTAssertEqual(store.unreadCount, 0)
        // The old cursor is kept: nothing more to load after c1.
        await store.loadMore()
        XCTAssertEqual(service.calls.filter { $0.before == "c1" }.count, 1)
    }

    func testCancellationIsNotAFailure() async {
        service.failure = CancellationError()
        store.setContext(userID: "u1", houseID: "h1")
        await until { self.service.calls.count == 1 }

        await store.openPanel()

        XCTAssertEqual(store.phase, .idle)
    }

    func testClosingThePanelWithoutALoadedListRefetchesTheBadge() async {
        service.failure = URLError(.notConnectedToInternet)
        store.setContext(userID: "u1", houseID: "h1")
        await until { self.service.calls.count == 1 }
        await store.openPanel()
        XCTAssertEqual(store.phase, .failed)

        service.failure = nil
        service.pages = [nil: NotificationPage(items: [item("n1", "09:00")], nextCursor: nil)]
        store.closePanel()
        await until { self.store.unreadCount == 1 }

        XCTAssertEqual(store.unreadCount, 1)
    }

    func testLoadMoreForbiddenClosesThePanel() async {
        service.pages = [nil: NotificationPage(items: [item("n1", "09:00")], nextCursor: "c1")]
        await openPanel()
        var accessLost = 0
        store.onAccessLost = { accessLost += 1 }
        service.failure = NotificationFailure(kind: .notMember, message: nil)

        await store.loadMore()

        XCTAssertFalse(store.isPanelOpen)
        XCTAssertEqual(accessLost, 1)
    }

    func testHouseSwitchAndSignOutClearTheState() async {
        service.pages = [nil: NotificationPage(items: [item("n1", "09:00")], nextCursor: "c1")]
        await openPanel()
        XCTAssertEqual(store.items.count, 1)

        service.pages = [nil: NotificationPage(items: [], nextCursor: nil)]
        store.setContext(userID: "u1", houseID: "h2")
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.unreadCount, 0)
        XCTAssertFalse(store.isPanelOpen)
        XCTAssertEqual(store.phase, .idle)

        store.setContext(userID: nil, houseID: nil)
        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.phase, .idle)
    }

    func testAnAnswerForThePreviousHouseIsDropped() async {
        service.pages = [nil: NotificationPage(items: [item("n1", "09:00")], nextCursor: nil)]
        service.gate = true
        store.setContext(userID: "u1", houseID: "h1")
        await until { self.service.calls.count == 1 }

        service.gate = false
        service.pages = [nil: NotificationPage(items: [], nextCursor: nil)]
        store.setContext(userID: "u1", houseID: "h2")
        await until { self.store.phase == .loaded }
        service.releaseGate()
        try? await Task.sleep(for: .milliseconds(50))

        XCTAssertTrue(store.items.isEmpty)
        XCTAssertEqual(store.unreadCount, 0)
    }

    func testNotificationsChangedOnlyRefreshesTheSelectedHouse() async {
        service.pages = [nil: NotificationPage(items: [], nextCursor: nil)]
        store.setContext(userID: "u1", houseID: "h1")
        await until { self.store.phase == .loaded }

        store.notificationsChanged(houseID: "other")
        store.notificationsChanged(houseID: nil)
        await Task.yield()
        XCTAssertEqual(service.calls.count, 1)

        store.notificationsChanged(houseID: "h1")
        await until { self.service.calls.count == 2 }
        XCTAssertEqual(service.calls.count, 2)
    }

    // MARK: - Helpers

    private func openPanel() async {
        store.setContext(userID: "u1", houseID: "h1")
        await until { self.store.phase == .loaded }
        await store.openPanel()
    }

    private func item(_ id: String, _ time: String) -> HouseNotification {
        HouseNotification(
            id: id, kind: .announcement, houseID: "h1", senderUserID: "u2",
            title: "Title \(id)", message: "Message", createdAt: "2026-11-20T\(time):00Z"
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
final class FakeNotificationService: NotificationServicing {
    /// Pages by `before` cursor (nil is page 1).
    var pages: [String?: NotificationPage] = [:]
    var failure: (any Error)?
    /// While set, list calls wait for `releaseGate()`.
    var gate = false
    var remindHandler: (String) async throws -> Void = { _ in }
    private(set) var calls: [(houseID: String, before: String?)] = []
    private(set) var remindCalls: [String] = []
    private var waiting: [CheckedContinuation<Void, Never>] = []

    func list(houseID: String, before: String?) async throws -> NotificationPage {
        calls.append((houseID, before))
        let page = pages[before] ?? NotificationPage(items: [], nextCursor: nil)
        if gate { await withCheckedContinuation { waiting.append($0) } }
        if let failure { throw failure }
        return page
    }

    func remind(choreID: String) async throws {
        remindCalls.append(choreID)
        try await remindHandler(choreID)
    }

    func releaseGate() {
        waiting.forEach { $0.resume() }
        waiting = []
    }
}

@MainActor
final class InMemoryPreferences: PreferencesStore {
    private var values: [String: Any] = [:]

    func bool(forKey key: String) -> Bool { values[key] as? Bool ?? false }
    func string(forKey key: String) -> String? { values[key] as? String }
    func set(_ value: Bool, forKey key: String) { values[key] = value }
    func set(_ value: String, forKey key: String) { values[key] = value }
    func removeObject(forKey key: String) { values[key] = nil }
}
