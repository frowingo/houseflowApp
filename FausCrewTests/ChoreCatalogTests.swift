import XCTest
import FausCrewCore
@testable import FausCrew

/// The shelves are presentation data mirrored on both platforms; `shared/Fixtures/choreCatalog.json`
/// is the contract. Android `ChoreCatalogTest` checks the Kotlin shelves against the same file.
/// The chores on the shelves come from the server (`ChoreCatalogStoreTests`).
final class ChoreCatalogTests: XCTestCase {
    private struct Copy: Decodable, Equatable { let tr: String; let en: String }
    private struct Category: Decodable {
        let id, icon, tint, deep: String
        let name, tagline: Copy
    }
    private struct Fixture: Decodable {
        let repeatPresets: [Int]
        let endOfDay: String
        let defaultCustomCategory: String
        let categories: [Category]
    }

    private func fixture() throws -> Fixture {
        let repositoryDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let url = repositoryDirectory.appendingPathComponent("FausCrew/shared/Fixtures/choreCatalog.json")
        return try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    }

    private func copy(_ value: ChoreCatalogCopy) -> Copy { Copy(tr: value.tr, en: value.en) }

    func testCategoriesMatchTheSharedFixture() throws {
        let fixture = try fixture()
        XCTAssertEqual(fixture.categories.map(\.id), ChoreCatalog.categories.map(\.id))
        for (json, category) in zip(fixture.categories, ChoreCatalog.categories) {
            XCTAssertEqual(json.icon, category.icon, category.id)
            XCTAssertEqual(json.tint, category.tintHex, category.id)
            XCTAssertEqual(json.deep, category.deepHex, category.id)
            XCTAssertEqual(json.name, copy(category.name), category.id)
            XCTAssertEqual(json.tagline, copy(category.tagline), category.id)
        }
    }

    func testDefaultCategoryAndPresetsMatchTheSharedFixture() throws {
        let fixture = try fixture()
        XCTAssertEqual(fixture.repeatPresets, ChoreRepeatPreset.all)
        let end = ChoreDueDate.endOfDay
        XCTAssertEqual(fixture.endOfDay, String(format: "%02d:%02d:%02d", end.hour, end.minute, end.second))
        XCTAssertEqual(fixture.defaultCustomCategory, ChoreCatalog.defaultCustomCategoryId)
        XCTAssertEqual(ChoreCatalog.blankTemplate.categoryId, ChoreCatalog.defaultCustomCategoryId)
        XCTAssertNotNil(ChoreCatalog.category(id: ChoreCatalog.defaultCustomCategoryId))
    }

    /// Shelves against the API's category values in `shared/Fixtures/choreCatalogApi.json`.
    func testShelvesMapToTheApiCategoryValues() throws {
        struct Api: Decodable {
            struct Category: Decodable { let value: Int; let catalogId: String }
            let categories: [Category]
        }
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("FausCrew/shared/Fixtures/choreCatalogApi.json")
        let api = try JSONDecoder().decode(Api.self, from: Data(contentsOf: url))
        XCTAssertEqual(api.categories.map(\.catalogId), ChoreCatalog.categories.map(\.id))
        for entry in api.categories {
            let kind = try XCTUnwrap(ChoreCategoryKind(rawValue: entry.value))
            XCTAssertEqual(ChoreCatalog.category(kind: kind)?.id, entry.catalogId)
            XCTAssertEqual(ChoreCatalog.category(id: entry.catalogId)?.kind, kind)
        }
        XCTAssertNil(ChoreCatalog.category(kind: .uncategorized))
        XCTAssertEqual(ChoreCatalog.category(id: ChoreCatalog.blankTemplate.categoryId)?.kind, .kitchen)
    }

    func testBathroomAndLaundryShareOneShelf() {
        XCTAssertNotNil(ChoreCatalog.category(id: "bath_laundry"))
        XCTAssertNil(ChoreCatalog.category(id: "bathroom"))
        XCTAssertNil(ChoreCatalog.category(id: "laundry"))
    }

    func testLocalizationKeysAreUnique() {
        let keys = ChoreCatalog.categories.flatMap { [$0.nameKey, $0.taglineKey] }
        XCTAssertEqual(keys.count, Set(keys).count)
        XCTAssertEqual(ChoreCatalog.category(id: "kitchen")?.nameKey, "chore_catalog_category_kitchen_name")
    }

    func testRecordsBecomeCardsOnTheirShelf() throws {
        let system = ChoreTemplate(record: ChoreCatalogRecord(
            id: "6730f1c2a1b2c3d4e5f60701", title: "Bulaşıkları yıka", description: "Akşam",
            recurringInterval: 1, level: 20, category: 7, isSystem: true))
        XCTAssertEqual(system.origin, .system)
        XCTAssertFalse(system.isDraft)
        XCTAssertEqual(system.categoryId, "trash")
        XCTAssertEqual(system.icon, ChoreCatalog.category(id: "trash")?.icon)
        XCTAssertEqual(system.level, .medium)
        XCTAssertEqual(system.repeatDays, 1)
        XCTAssertEqual(system.detail, "Akşam")

        // A value this build does not know lands on the default shelf instead of disappearing.
        let draft = ChoreTemplate(record: ChoreCatalogRecord(id: "6730f1c2a1b2c3d4e5f60718", title: "Kendi işim", category: 42))
        XCTAssertTrue(draft.isDraft)
        XCTAssertEqual(draft.categoryId, ChoreCatalog.defaultCustomCategoryId)
        XCTAssertEqual(ChoreCatalog.blankTemplate.origin, .blank)
    }

    func testDueDateDefaultsToEndOfDayAndKeepsAPickedTime() throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = try XCTUnwrap(TimeZone(identifier: "Europe/Istanbul"))
        let day = try XCTUnwrap(calendar.date(from: DateComponents(year: 2026, month: 11, day: 12, hour: 10)))
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        XCTAssertEqual(formatter.string(from: ChoreDueDate.resolve(day: day, hour: nil, minute: nil, calendar: calendar)),
                       "2026-11-12T23:59:59+03:00")
        XCTAssertEqual(formatter.string(from: ChoreDueDate.resolve(day: day, hour: 18, minute: 30, calendar: calendar)),
                       "2026-11-12T18:30:00+03:00")
    }

    func testSearchIgnoresCaseAndTurkishDiacritics() {
        let cards = [
            ChoreTemplate(record: ChoreCatalogRecord(id: "a", title: "Bulaşıkları yıka", category: 1, isSystem: true)),
            ChoreTemplate(record: ChoreCatalogRecord(id: "b", title: "Çöpü çıkar", description: "Geri dönüşüm", category: 7)),
        ]
        let resolve: (ChoreTemplate) -> (String, String) = { ($0.title, $0.detail) }
        XCTAssertEqual(ChoreCatalog.search("BULAŞIK", among: cards, resolve: resolve).map(\.id), ["a"])
        XCTAssertEqual(ChoreCatalog.search("cop", among: cards, resolve: resolve).map(\.id), ["b"])
        XCTAssertEqual(ChoreCatalog.search("donusum", among: cards, resolve: resolve).map(\.id), ["b"])
        XCTAssertTrue(ChoreCatalog.search("   ", among: cards, resolve: resolve).isEmpty)
        XCTAssertTrue(ChoreCatalog.search("zzzz", among: cards, resolve: resolve).isEmpty)
    }
}
