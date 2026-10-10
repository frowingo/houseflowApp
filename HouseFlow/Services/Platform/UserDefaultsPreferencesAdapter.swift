import Foundation
import HouseFlowCore

// Existing persisted keys remain in the same UserDefaults domain. In particular,
// hasSeenOnboarding and chosenHouse continue to load without a data migration.
extension UserDefaults: @retroactive PreferencesStore {
    public func set(_ value: String, forKey key: String) {
        set(value as Any, forKey: key)
    }
}
