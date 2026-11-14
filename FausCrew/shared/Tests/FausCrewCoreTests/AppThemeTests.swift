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
        XCTAssertEqual(AppThemeID.allCases.map(\.rawValue), ["faus_light", "faus_dark", "faus_bloom", "faus_web"])
        XCTAssertEqual(AppThemeID.allCases.map(\.displayName), ["Faus Light", "Faus Dark", "Faus Bloom", "Faus Web"])
    }

    func testBloomRoundTrips() {
        let store = MemoryPreferences()
        AppThemePreference.save(.fausBloom, to: store)
        XCTAssertEqual(store.strings["selectedTheme"], "faus_bloom")
        XCTAssertEqual(AppThemePreference.load(from: store), .fausBloom)
    }

    func testBloomSavedUnderItsFormerNameStillLoads() {
        let store = MemoryPreferences()
        store.set("fause_bloom", forKey: AppThemePreference.storageKey)
        XCTAssertEqual(AppThemePreference.load(from: store), .fausBloom)
        XCTAssertEqual(AppThemeID.fausBloom.descriptionKey, "theme_fause_bloom_description")
        XCTAssertEqual(AppThemeID.fausWeb.descriptionKey, "theme_faus_web_description")
    }

    func testWebRoundTrips() {
        let store = MemoryPreferences()
        AppThemePreference.save(.fausWeb, to: store)
        XCTAssertEqual(store.strings["selectedTheme"], "faus_web")
        XCTAssertEqual(AppThemePreference.load(from: store), .fausWeb)
    }
}
