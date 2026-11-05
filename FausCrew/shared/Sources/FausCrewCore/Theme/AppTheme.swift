import Foundation

/// The visual themes the apps can render. Raw values are the on-device storage contract and
/// match Android's `FausThemeId.storageValue`, so a new theme is one case here plus one palette
/// per platform.
public enum AppThemeID: String, CaseIterable, Sendable {
    case fausLight = "faus_light"
    case fausDark = "faus_dark"
    case fausBloom = "faus_bloom"
    case fausWeb = "faus_web"

    /// First launch, and any stored value this build does not know, use Faus Light.
    public static let defaultTheme: AppThemeID = .fausLight

    /// Reads a stored value, including names a theme was saved under before it was renamed
    /// (Faus Bloom was "fause_bloom").
    public init?(storageValue: String) {
        if let theme = AppThemeID(rawValue: storageValue) {
            self = theme
        } else if storageValue == "fause_bloom" {
            self = .fausBloom
        } else {
            return nil
        }
    }

    /// Remote copy key of the picker description. Faus Bloom keeps the key it had under its
    /// former storage value, so copy already published for it stays in use.
    public var descriptionKey: String {
        switch self {
        case .fausBloom: "theme_fause_bloom_description"
        default: "theme_\(rawValue)_description"
        }
    }

    /// Product names; they are brand copy and are not localized.
    public var displayName: String {
        switch self {
        case .fausLight: "Faus Light"
        case .fausDark: "Faus Dark"
        case .fausBloom: "Faus Bloom"
        case .fausWeb: "Faus Web"
        }
    }
}

/// Reads and writes the user's theme choice in the platform preferences store.
public enum AppThemePreference {
    public static let storageKey = "selectedTheme"

    @MainActor
    public static func load(from store: any PreferencesStore) -> AppThemeID {
        store.string(forKey: storageKey).flatMap(AppThemeID.init(storageValue:)) ?? .defaultTheme
    }

    @MainActor
    public static func save(_ theme: AppThemeID, to store: any PreferencesStore) {
        store.set(theme.rawValue, forKey: storageKey)
    }
}
