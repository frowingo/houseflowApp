import Foundation

public enum PushPlatform: String, Sendable {
    case ios
    case android
}

/// The wire `type` of a notification. Unknown values are kept so the server can add types.
public enum NotificationKind: Equatable, Sendable {
    case announcement
    case choreReminder
    case unknown(String)

    public init(wire: String) {
        switch wire {
        case "announcement": self = .announcement
        case "chore_reminder": self = .choreReminder
        default: self = .unknown(wire)
        }
    }

    public var wire: String {
        switch self {
        case .announcement: "announcement"
        case .choreReminder: "chore_reminder"
        case .unknown(let value): value
        }
    }
}

/// One entry of `GET notification`.
public struct HouseNotification: Equatable, Sendable, Identifiable, Decodable {
    public let id: String
    public let kind: NotificationKind
    public let houseID: String
    public let senderUserID: String
    /// Only chore reminders carry one.
    public let choreID: String?
    public let title: String
    public let message: String
    /// The wire string, e.g. `2026-11-20T22:15:33Z`.
    public let createdAt: String

    public var createdDate: Date? { APIDate.parse(createdAt) }

    public init(
        id: String, kind: NotificationKind, houseID: String, senderUserID: String, choreID: String? = nil,
        title: String, message: String, createdAt: String
    ) {
        self.id = id
        self.kind = kind
        self.houseID = houseID
        self.senderUserID = senderUserID
        self.choreID = choreID
        self.title = title
        self.message = message
        self.createdAt = createdAt
    }

    private enum CodingKeys: String, CodingKey {
        case id, title, message, createdAt
        case type, houseId, senderUserId, choreId
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            id: try values.decode(String.self, forKey: .id),
            kind: NotificationKind(wire: try values.decode(String.self, forKey: .type)),
            houseID: try values.decode(String.self, forKey: .houseId),
            senderUserID: try values.decode(String.self, forKey: .senderUserId),
            choreID: try values.decodeIfPresent(String.self, forKey: .choreId),
            title: try values.decode(String.self, forKey: .title),
            message: try values.decode(String.self, forKey: .message),
            createdAt: try values.decode(String.self, forKey: .createdAt)
        )
    }
}

public struct NotificationPage: Equatable, Sendable {
    public let items: [HouseNotification]
    /// Pass as `before` for the next page; `nil` on the last one.
    public let nextCursor: String?

    public init(items: [HouseNotification], nextCursor: String?) {
        self.items = items
        self.nextCursor = nextCursor
    }
}

/// Where a tapped push leads. Built from the FCM `data` (iOS userInfo / Android intent extras).
public struct PushTarget: Equatable, Sendable {
    public let houseID: String
    public let choreID: String?
    public let notificationID: String?
    public let kind: NotificationKind?

    /// `nil` when `houseId` is missing or blank. Blank optional values count as absent.
    public init?(data: [String: String]) {
        func value(_ key: String) -> String? {
            data[key].flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
        }
        guard let houseID = value("houseId") else { return nil }
        self.houseID = houseID
        choreID = value("choreId")
        notificationID = value("notificationId")
        kind = value("type").map(NotificationKind.init(wire:))
    }

    /// Keeps the String values of the known keys; APNs adds keys and non-String values of its own.
    public init?(userInfo: [AnyHashable: Any]) {
        var data: [String: String] = [:]
        for key in ["houseId", "choreId", "notificationId", "type"] {
            if let value = userInfo[key] as? String { data[key] = value }
        }
        self.init(data: data)
    }
}
