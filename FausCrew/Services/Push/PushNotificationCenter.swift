import FirebaseMessaging
import UserNotifications
import os

/// Receives everything the system and FCM deliver: foreground pushes, notification taps and
/// FCM token changes. It decides nothing; the app wires the handlers.
@MainActor
final class PushNotificationCenter: NSObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = PushNotificationCenter()

    /// Data of a push that arrived while the app is in the foreground.
    var onForegroundNotification: (([String: String]) -> Void)?
    var onTokenChange: ((String) -> Void)?

    private static let log = Logger(subsystem: "com.fauscrew", category: "Push")
    private static let dataKeys = ["notificationId", "type", "houseId", "choreId"]

    /// FCM puts its data keys at the top level of `userInfo`; anything else is not ours.
    nonisolated static func pushData(from userInfo: [AnyHashable: Any]) -> [String: String] {
        var data: [String: String] = [:]
        for key in dataKeys {
            if let value = userInfo[key] as? String { data[key] = value }
        }
        return data
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        let data = Self.pushData(from: notification.request.content.userInfo)
        await foregroundNotificationArrived(data)
        return [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        guard response.actionIdentifier == UNNotificationDefaultActionIdentifier else { return }
        let data = Self.pushData(from: response.notification.request.content.userInfo)
        await notificationTapped(data)
    }

    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let fcmToken else { return }
        Task { @MainActor in tokenReceived(fcmToken) }
    }

    private func foregroundNotificationArrived(_ data: [String: String]) {
        onForegroundNotification?(data)
    }

    private func notificationTapped(_ data: [String: String]) {
        guard data["houseId"]?.isEmpty == false else { return }
        PushInbox.shared.offer(data)
    }

    private func tokenReceived(_ token: String) {
        Self.log.debug("FCM token \(token.prefix(8), privacy: .public)")
        onTokenChange?(token)
    }
}
