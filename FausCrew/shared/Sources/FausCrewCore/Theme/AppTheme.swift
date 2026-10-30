import Foundation

/// The visual themes the apps can render. Raw values are the on-device storage contract and
/// match Android's `FausThemeId.storageValue`, so a new theme is one case here plus one palette
/// per platform.
public enum AppThemeID: String, CaseIterable, Sendable {
    case fausLight = "faus_light"
    case fausDark = "faus_dark"

    /// First launch, and any stored value this build does not know, use Faus Light.
    public static let defaultTheme: AppThemeID = .fausLight

    /// Product names; they are brand copy and are not localized.
    public var displayName: String {
        switch self {
        case .fausLight: "Faus Light"
        case .fausDark: "Faus Dark"
        }
    }
}

/// Reads and writes the user's theme choice in the platform preferences store.
public enum AppThemePreference {
    public static let storageKey = "selectedTheme"

    @MainActor
    public static func load(from store: any PreferencesStore) -> AppThemeID {
        store.string(forKey: storageKey).flatMap(AppThemeID.init(rawValue:)) ?? .defaultTheme
    }

    @MainActor
    public static func save(_ theme: AppThemeID, to store: any PreferencesStore) {
        store.set(theme.rawValue, forKey: storageKey)
    }
}
