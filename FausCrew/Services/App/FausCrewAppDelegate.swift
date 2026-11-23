import FirebaseCore
import FirebaseMessaging
import UIKit
import os

@MainActor
final class FausCrewAppDelegate: NSObject, UIApplicationDelegate {
    private static let log = Logger(subsystem: "com.fauscrew", category: "Push")

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        SocialURLHandler.didFinishLaunching(application, options: launchOptions)
        FirebaseApp.configure()
        UNUserNotificationCenter.current().delegate = PushNotificationCenter.shared
        Messaging.messaging().delegate = PushNotificationCenter.shared
        // Registering with APNs needs no user permission; the permission prompt comes later.
        application.registerForRemoteNotifications()
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        // Swizzling is on, but handing the token over explicitly keeps FCM independent of it.
        Messaging.messaging().apnsToken = deviceToken
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        let nsError = error as NSError
        Self.log.error("APNs registration failed: \(nsError.domain, privacy: .public) \(nsError.code, privacy: .public)")
    }

    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        GameOrientationController.allowedOrientations
    }
}
