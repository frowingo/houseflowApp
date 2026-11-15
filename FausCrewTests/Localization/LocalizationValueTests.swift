import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class LocalizationValueTests: XCTestCase {
    private let gameKey = "house_tanks_subtitle"
    private var gameEnglish: String? { HouseTanksLocalization.value(for: gameKey, language: "en") }
    private var gameTurkish: String? { HouseTanksLocalization.value(for: gameKey, language: "tr") }

    override func setUp() async throws {
        try await super.setUp()
        let previousLanguage = APILanguage.code
        addTeardownBlock {
            await MainActor.run {
                APILanguage.update(prefix: previousLanguage)
            }
        }
    }

    func testServerValueWinsOverBuiltInCopy() async throws {
        let service = FakeLocalizationService()
        service.fetchPlaintextsHandler = { prefix in
            [LocalizationPlaintextItem(key: "greeting", language: prefix, value: "Server hello")]
        }
        let store = makeStore(service: service)

        try await store.refreshLanguagePrefix("en")

        XCTAssertEqual(store.value(for: "greeting", tr: "Merhaba", en: "Hello"), "Server hello")
    }

    func testBuiltInCopyFollowsAPILanguage() {
        let store = makeStore()

        APILanguage.update(prefix: "tr")
        XCTAssertEqual(store.value(for: "greeting", tr: "Merhaba", en: "Hello"), "Merhaba")

        APILanguage.update(prefix: "en")
        XCTAssertEqual(store.value(for: "greeting", tr: "Merhaba", en: "Hello"), "Hello")
    }

    func testGameKeyFollowsAPILanguage() {
        let store = makeStore()

        APILanguage.update(prefix: "tr")
        XCTAssertEqual(store.value(for: gameKey), gameTurkish)

        APILanguage.update(prefix: "en")
        XCTAssertEqual(store.value(for: gameKey), gameEnglish)
    }

    func testGameKeyInUnknownLanguageResolvesToEnglish() async throws {
        let store = makeStore()

        try await store.refreshLanguagePrefix("de")

        XCTAssertEqual(store.value(for: gameKey), gameEnglish)
    }

    func testUnknownKeyFallsBackToKey() {
        XCTAssertEqual(makeStore().value(for: "no_such_key"), "no_such_key")
    }

    private func makeStore(service: FakeLocalizationService? = nil) -> LocalizationStore {
        let localization = TestFixture.localizationStore(service: service ?? FakeLocalizationService())
        addTeardownBlock {
            try? FileManager.default.removeItem(at: localization.directory)
        }
        return localization.store
    }
}
