import Foundation

/// Values have the same lifetime as the platform's secure storage. A nil write
/// removes the value. The Core package does not persist or log these strings.
@MainActor
public protocol SecureSessionStore: AnyObject {
    var authToken: String? { get set }
    var userEmail: String? { get set }
    var userFirstName: String? { get set }
    var userLastName: String? { get set }
    var pendingEmailVerification: String? { get set }
}

/// Only the two preference value types used by the current session flows.
@MainActor
public protocol PreferencesStore: AnyObject {
    func bool(forKey key: String) -> Bool
    func string(forKey key: String) -> String?
    func set(_ value: Bool, forKey key: String)
    func set(_ value: String, forKey key: String)
    func removeObject(forKey key: String)
}

@MainActor
public protocol LocalizationCacheStore {
    func load(languagePrefix: String) -> [String: String]
    func loadMostRecent() -> (languagePrefix: String, values: [String: String])?
    func save(values: [String: String], languagePrefix: String)
}
