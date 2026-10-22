import FacebookCore
import GoogleSignIn
import SCSDKLoginKit
import UIKit

/// Routes provider redirects back into the SDK that started the flow.
@MainActor
enum SocialURLHandler {
    /// Facebook needs this at launch; skipped while the app ID is still a placeholder so the
    /// SDK never starts (or logs events) with a fake ID.
    static func didFinishLaunching(_ application: UIApplication, options: [UIApplication.LaunchOptionsKey: Any]?) {
        guard SocialPresentation.configuredValue("FacebookAppID") != nil else { return }
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: options)
    }

    @discardableResult
    static func handle(_ url: URL) -> Bool {
        if GIDSignIn.sharedInstance.handle(url) { return true }
        if SocialPresentation.configuredValue("FacebookAppID") != nil,
           ApplicationDelegate.shared.application(UIApplication.shared, open: url, options: [:]) {
            return true
        }
        return SCSDKLoginClient.application(UIApplication.shared, open: url, options: [:])
    }
}
