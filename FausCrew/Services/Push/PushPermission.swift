import UIKit
import UserNotifications

enum PushPermission {
    static func status() async -> UNAuthorizationStatus {
        await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
    }

    /// Shows the system prompt only the first time; returns whether notifications are allowed afterwards.
    static func requestIfUndetermined() async -> Bool {
        if await status() == .notDetermined {
            _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        }
        return await isAllowed()
    }

    static func isAllowed() async -> Bool {
        switch await status() {
        case .authorized, .provisional, .ephemeral: return true
        default: return false
        }
    }

    static func openSettings() {
        guard let url = URL(string: UIApplication.openNotificationSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
