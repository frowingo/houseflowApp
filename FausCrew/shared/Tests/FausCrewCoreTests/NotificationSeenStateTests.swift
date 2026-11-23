import Foundation
import FausCrewCore
import XCTest

final class NotificationSeenStateTests: XCTestCase {
    private final class MemoryPreferences: PreferencesStore {
        var strings: [String: String] = [:]
        func bool(forKey key: String) -> Bool { false }
        func string(forKey key: String) -> String? { strings[key] }
        func set(_ value: Bool, forKey key: String) {}
        func set(_ value: String, forKey key: String) { strings[key] = value }
        func removeObject(forKey key: String) { strings[key] = nil }
    }

    private func item(_ id: String, _ createdAt: String) -> HouseNotification {
        HouseNotification(id: id, kind: .announcement, houseID: "h", senderUserID: "s", title: "T", message: "M", createdAt: createdAt)
    }

    private lazy var items = [
        item("c", "2026-11-20T10:00:02Z"),
        item("b", "2026-11-20T10:00:01Z"),
        item("a", "2026-11-20T10:00:01Z"),
    ]

    func testWithoutAMarkerEveryItemIsUnread() {
        XCTAssertEqual(NotificationSeen.unreadCount(items: items, seen: nil), 3)
        XCTAssertEqual(NotificationSeen.unreadCount(items: [], seen: nil), 0)
    }

    func testEqualTimesAreSplitById() {
        let seen = NotificationSeenMarker(createdAt: "2026-11-20T10:00:01Z", id: "a")
        XCTAssertEqual(NotificationSeen.unreadCount(items: items, seen: seen), 2)
        XCTAssertEqual(NotificationSeen.unreadCount(items: items, seen: NotificationSeenMarker(createdAt: "2026-11-20T10:00:01Z", id: "b")), 1)
    }

    func testNothingIsUnreadWhenTheMarkerIsNewestOrNewer() {
        XCTAssertEqual(NotificationSeen.unreadCount(items: items, seen: NotificationSeenMarker(createdAt: "2026-11-20T10:00:02Z", id: "c")), 0)
        XCTAssertEqual(NotificationSeen.unreadCount(items: items, seen: NotificationSeenMarker(createdAt: "2026-11-21T00:00:00Z", id: "a")), 0)
    }

    func testTimeWinsOverId() {
        let seen = NotificationSeenMarker(createdAt: "2026-11-20T10:00:00Z", id: "z")
        XCTAssertEqual(NotificationSeen.unreadCount(items: items, seen: seen), 3)
    }

    func testUnreadableTimesFallBackToId() {
        let seen = NotificationSeenMarker(createdAt: "garbage", id: "b")
        XCTAssertEqual(NotificationSeen.unreadCount(items: items, seen: seen), 1)
    }

    func testMarkerIsTheNewestItemInAnyOrder() {
        XCTAssertEqual(NotificationSeen.marker(newestOf: items), NotificationSeenMarker(createdAt: "2026-11-20T10:00:02Z", id: "c"))
        XCTAssertEqual(NotificationSeen.marker(newestOf: items.reversed()), NotificationSeen.marker(newestOf: items))
        XCTAssertEqual(NotificationSeen.marker(newestOf: Array(items.dropFirst())), NotificationSeenMarker(createdAt: "2026-11-20T10:00:01Z", id: "b"))
        XCTAssertNil(NotificationSeen.marker(newestOf: []))
    }

    @MainActor
    func testStorageRoundTripPerUserAndHouse() {
        let store = MemoryPreferences()
        let marker = NotificationSeenMarker(createdAt: "2026-11-20T10:00:02Z", id: "c")
        XCTAssertEqual(NotificationSeen.storageKey(userID: "u", houseID: "h"), "fauscrew.notifications-seen.u.h")
        XCTAssertNil(NotificationSeen.load(from: store, userID: "u", houseID: "h"))
        NotificationSeen.save(marker, to: store, userID: "u", houseID: "h")
        XCTAssertEqual(NotificationSeen.load(from: store, userID: "u", houseID: "h"), marker)
        XCTAssertNil(NotificationSeen.load(from: store, userID: "u", houseID: "other"))
        XCTAssertNil(NotificationSeen.load(from: store, userID: "other", houseID: "h"))
    }

    @MainActor
    func testCorruptStoredValueIsNil() {
        let store = MemoryPreferences()
        store.strings[NotificationSeen.storageKey(userID: "u", houseID: "h")] = "{not json"
        XCTAssertNil(NotificationSeen.load(from: store, userID: "u", houseID: "h"))
    }
}
