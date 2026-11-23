import FirebaseMessaging
import os

protocol PushTokenProviding: AnyObject {
    func currentToken() async -> String?
    func deleteToken() async
}

final class FirebasePushTokenProvider: PushTokenProviding {
    private static let log = Logger(subsystem: "com.fauscrew", category: "Push")

    func currentToken() async -> String? {
        do {
            return try await Messaging.messaging().token()
        } catch {
            Self.log.error("FCM token fetch failed: \((error as NSError).code, privacy: .public)")
            return nil
        }
    }

    func deleteToken() async {
        do {
            try await Messaging.messaging().deleteToken()
        } catch {
            Self.log.error("FCM token delete failed: \((error as NSError).code, privacy: .public)")
        }
    }
}
