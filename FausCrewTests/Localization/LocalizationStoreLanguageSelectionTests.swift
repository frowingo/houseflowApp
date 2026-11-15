import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class LocalizationStoreLanguageSelectionTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        let previousLanguage = APILanguage.code
        APILanguage.update(prefix: "en")
        addTeardownBlock {
            await MainActor.run {
                APILanguage.update(prefix: previousLanguage)
            }
        }
    }

    func testPreferredLanguageIsNormalizedAndKeepsAPILanguageInStep() {
        let store = makeStore()

        store.applyPreferredLanguage("  TR ")

        XCTAssertEqual(store.languagePrefix, "tr")
        XCTAssertEqual(APILanguage.code, "tr")
    }

    func testMissingOrBlankPreferredLanguageIsIgnored() {
        let store = makeStore()

        store.applyPreferredLanguage(nil)
        store.applyPreferredLanguage("   ")

        XCTAssertNil(store.languagePrefix)
        XCTAssertEqual(APILanguage.code, "en")
    }

    func testDeviceLanguageIsUsedWhenNothingWasChosen() async throws {
        let store = makeStore(
            deviceLanguages: ["tr-TR"],
            languages: [language("en", isDefault: true), language("tr")]
        )

        try await store.loadAvailableLanguages()

        XCTAssertEqual(store.languagePrefix, "tr")
        XCTAssertEqual(APILanguage.code, "tr")
    }

    func testDefaultLanguageIsUsedWhenDeviceLanguageIsNotOffered() async throws {
        let store = makeStore(
            deviceLanguages: ["de-DE"],
            languages: [language("en"), language("tr", isDefault: true)]
        )

        try await store.loadAvailableLanguages()

        XCTAssertEqual(store.languagePrefix, "tr")
    }

    func testFirstActiveLanguageIsUsedWhenThereIsNoDefault() async throws {
        let store = makeStore(
            deviceLanguages: ["de-DE"],
            languages: [language("fr", isActive: false), language("en"), language("tr")]
        )

        try await store.loadAvailableLanguages()

        XCTAssertEqual(store.languagePrefix, "en")
    }

    func testInactiveDeviceLanguageIsNotSelected() async throws {
        let store = makeStore(
            deviceLanguages: ["tr-TR"],
            languages: [language("en", isDefault: true), language("tr", isActive: false)]
        )

        try await store.loadAvailableLanguages()

        XCTAssertEqual(store.languagePrefix, "en")
        XCTAssertEqual(APILanguage.code, "en")
    }

    func testChosenLanguageIsNotReplacedByDeviceLanguage() async throws {
        let store = makeStore(
            deviceLanguages: ["tr-TR"],
            languages: [language("en", isDefault: true), language("tr")]
        )
        store.applyPreferredLanguage("en")

        try await store.loadAvailableLanguages()

        XCTAssertEqual(store.languagePrefix, "en")
        XCTAssertEqual(APILanguage.code, "en")
    }

    func testNoLanguageIsSelectedWhenNoneIsActive() async throws {
        let store = makeStore(
            deviceLanguages: ["tr-TR"],
            languages: [language("tr", isActive: false)]
        )

        try await store.loadAvailableLanguages()

        XCTAssertNil(store.languagePrefix)
    }

    private func language(
        _ prefix: String,
        isActive: Bool = true,
        isDefault: Bool = false
    ) -> LocalizationLanguage {
        LocalizationLanguage(
            image: "",
            isActive: isActive,
            isDefault: isDefault,
            name: prefix,
            nativeName: prefix,
            prefix: prefix
        )
    }

    private func makeStore(
        deviceLanguages: [String] = [],
        languages: [LocalizationLanguage] = []
    ) -> LocalizationStore {
        let service = FakeLocalizationService()
        service.fetchLanguagesHandler = { languages }
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FausCrewTests-\(UUID().uuidString)", isDirectory: true)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        return LocalizationStore(
            service: service,
            cache: LocalizationDiskCache(baseDirectory: directory),
            deviceLanguages: { deviceLanguages }
        )
    }
}
