import UIKit

@MainActor
final class HouseFlowAppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        supportedInterfaceOrientationsFor window: UIWindow?
    ) -> UIInterfaceOrientationMask {
        GameOrientationController.allowedOrientations
    }
}

@MainActor
enum GameOrientationController {
    private(set) static var allowedOrientations: UIInterfaceOrientationMask = defaultOrientations

    private static var defaultOrientations: UIInterfaceOrientationMask {
        UIDevice.current.userInterfaceIdiom == .pad ? .all : .allButUpsideDown
    }

    private static var foregroundWindowScene: UIWindowScene? {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }
    }

    static func lockToLandscape(onFailure: @escaping () -> Void) {
        allowedOrientations = .landscape

        guard let windowScene = foregroundWindowScene else {
            onFailure()
            return
        }

        windowScene.windows.forEach {
            $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }

        let preferences = UIWindowScene.GeometryPreferences.iOS(
            interfaceOrientations: .landscape
        )
        windowScene.requestGeometryUpdate(preferences) { _ in
            Task { @MainActor in
                onFailure()
            }
        }
    }

    static func restoreDefaultOrientations() {
        allowedOrientations = defaultOrientations
        foregroundWindowScene?.windows.forEach {
            $0.rootViewController?.setNeedsUpdateOfSupportedInterfaceOrientations()
        }
    }
}
