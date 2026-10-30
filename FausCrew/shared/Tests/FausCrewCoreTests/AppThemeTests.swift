import XCTest
@testable import FausCrewCore

@MainActor
final class AppThemeTests: XCTestCase {
    private final class MemoryPreferences: PreferencesStore {
        var strings: [String: String] = [:]
        func bool(forKey key: String) -> Bool { false }
        func string(forKey key: String) -> String? { strings[key] }
        func set(_ value: Bool, forKey key: String) {}
        func set(_ value: String, forKey key: String) { strings[key] = value }
        func removeObject(forKey key: String) { strings[key] = nil }
    }

    func testFirstLaunchUsesFausLight() {
        XCTAssertEqual(AppThemePreference.load(from: MemoryPreferences()), .fausLight)
    }

    func testSavedThemeRoundTrips() {
        let store = MemoryPreferences()
        AppThemePreference.save(.fausDark, to: store)
        XCTAssertEqual(store.strings["selectedTheme"], "faus_dark")
        XCTAssertEqual(AppThemePreference.load(from: store), .fausDark)
    }

    func testUnknownStoredValueFallsBackToDefault() {
        let store = MemoryPreferences()
        store.strings["selectedTheme"] = "retired_theme"
        XCTAssertEqual(AppThemePreference.load(from: store), .fausLight)
    }

    func testStorageContractMatchesAndroid() {
        XCTAssertEqual(AppThemeID.allCases.map(\.rawValue), ["faus_light", "faus_dark"])
        XCTAssertEqual(AppThemeID.allCases.map(\.displayName), ["Faus Light", "Faus Dark"])
    }
}
