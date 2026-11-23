import Foundation

/// The newest notification the user has seen in a house. The backend keeps no read state.
public struct NotificationSeenMarker: Codable, Equatable, Sendable {
    public let createdAt: String
    public let id: String

    public init(createdAt: String, id: String) {
        self.createdAt = createdAt
        self.id = id
    }

    /// By time; equal or unreadable times fall back to the id (Mongo ids sort by creation).
    fileprivate func isNewer(than other: NotificationSeenMarker) -> Bool {
        if let date = APIDate.parse(createdAt), let otherDate = APIDate.parse(other.createdAt), date != otherDate {
            return date > otherDate
        }
        return id > other.id
    }
}

/// Unread badge rules. The list is already filtered per person, so nothing is excluded by sender.
public enum NotificationSeen {
    /// Items newer than the marker; with no marker every item counts.
    public static func unreadCount(items: [HouseNotification], seen: NotificationSeenMarker?) -> Int {
        guard let seen else { return items.count }
        return items.filter { marker(for: $0).isNewer(than: seen) }.count
    }

    /// The newest of `items` (`nil` when empty), saved when the panel is opened.
    public static func marker(newestOf items: [HouseNotification]) -> NotificationSeenMarker? {
        items.map(marker(for:)).max { $1.isNewer(than: $0) }
    }

    /// Per user and house, like `AnnouncementReadStore`.
    public static func storageKey(userID: String, houseID: String) -> String {
        "fauscrew.notifications-seen.\(userID).\(houseID)"
    }

    /// `nil` when nothing was saved or the saved value is unreadable.
    @MainActor
    public static func load(from store: any PreferencesStore, userID: String, houseID: String) -> NotificationSeenMarker? {
        store.string(forKey: storageKey(userID: userID, houseID: houseID))
            .flatMap { try? JSONDecoder().decode(NotificationSeenMarker.self, from: Data($0.utf8)) }
    }

    @MainActor
    public static func save(_ marker: NotificationSeenMarker, to store: any PreferencesStore, userID: String, houseID: String) {
        guard let data = try? JSONEncoder().encode(marker) else { return }
        store.set(String(decoding: data, as: UTF8.self), forKey: storageKey(userID: userID, houseID: houseID))
    }

    private static func marker(for item: HouseNotification) -> NotificationSeenMarker {
        NotificationSeenMarker(createdAt: item.createdAt, id: item.id)
    }
}
