import UIKit

/// Where provider SDKs present their sheets, and how a build tells real IDs from placeholders.
@MainActor
enum SocialPresentation {
    static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        var top = root
        while let presented = top?.presentedViewController { top = presented }
        return top
    }

    /// Info.plist values ship as `YOUR_…` placeholders until the real IDs are filled in.
    static func configuredValue(_ key: String, in bundle: Bundle = .main) -> String? {
        guard let value = bundle.object(forInfoDictionaryKey: key) as? String,
              !value.isEmpty, !value.contains("YOUR_") else { return nil }
        return value
    }
}
