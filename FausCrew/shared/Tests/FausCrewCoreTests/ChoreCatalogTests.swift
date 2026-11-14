import Foundation
import XCTest
@testable import FausCrewCore

/// `shared/Fixtures/choreCatalogApi.json` holds the contract's examples
/// (`Documents/choreCatalogBackendContract.md`); Android reads the same file.
final class ChoreCatalogTests: XCTestCase {
    // MARK: Categories

    func testCategoryValuesMatchTheContract() throws {
        let fixture = try Self.fixture()
        let categories = try XCTUnwrap(fixture["categories"] as? [[String: Any]])
        XCTAssertEqual(categories.compactMap { $0["value"] as? Int }, ChoreCategoryKind.assignable.map(\.rawValue))
        XCTAssertEqual(ChoreCategoryKind.assignable.count, 9)
        XCTAssertFalse(ChoreCategoryKind.uncategorized.isAssignable)

        for pair in try XCTUnwrap(fixture["choreCategoryValues"] as? [[String: Int]]) {
            XCTAssertEqual(ChoreCategoryKind(apiValue: pair["raw"]).rawValue, pair["kind"], "raw \(pair["raw"] ?? -99)")
        }
        XCTAssertEqual(ChoreCategoryKind(apiValue: nil), .uncategorized)
    }

    func testChoreResponsesReadTheCategoryAndDefaultToUncategorized() throws {
        let legacy = try JSONDecoder().decode(ChoreResponse.self, from: ChoreFixtures.responseWithMixedISOStringsAndNullOptionals)
        XCTAssertEqual(legacy.category, 0)
        XCTAssertEqual(legacy.categoryKind, .uncategorized)

        for (raw, kind) in [(3, ChoreCategoryKind.toilet), (42, .uncategorized)] {
            let chore = try JSONDecoder().decode(ChoreResponse.self, from: Self.chore(category: raw))
            XCTAssertEqual(chore.category, raw)
            XCTAssertEqual(chore.categoryKind, kind)
        }
    }

    func testHouseDetailsChoresReadTheCategory() throws {
        let details = try JSONSerialization.jsonObject(with: HouseFixtures.detailsWithObjectDatesAndNullOptionals) as? [String: Any]
        let data = try XCTUnwrap((details?["data"] as? [String: Any]) ?? details)
        var chore = try XCTUnwrap((data["chores"] as? [[String: Any]])?.first)
        let legacy = try JSONDecoder().decode(HouseChoreDTO.self, from: JSONSerialization.data(withJSONObject: chore))
        XCTAssertEqual(legacy.categoryKind, .uncategorized)

        chore["category"] = 6
        let categorized = try JSONDecoder().decode(HouseChoreDTO.self, from: JSONSerialization.data(withJSONObject: chore))
        XCTAssertEqual(categorized.categoryKind, .pets)
    }

    func testChoreBodiesSendOnlyAnAssignableCategory() throws {
        func body(_ data: Data) throws -> [String: Any] {
            try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        }
        let create = try body(DashboardWireContract.choreBody(
            assignedTo: "u", description: "", dueDate: "2026-11-12T20:59:59Z", houseId: "h",
            isRecurring: false, level: 10, recurringInterval: 0, title: "Wash", category: 1))
        XCTAssertEqual(create["category"] as? Int, 1)
        XCTAssertEqual(create.count, 9)

        // An update without a category leaves the key out, so the chore keeps its category.
        let update = try body(DashboardWireContract.updateChoreBody(
            assignedTo: "u", description: "", dueDate: "2026-11-12T20:59:59Z", houseId: "h",
            isRecurring: false, level: 10, recurringInterval: 0, title: "Wash"))
        XCTAssertNil(update["category"])
        XCTAssertEqual(update.count, 8)

        for invalid in [0, 10, -1] {
            let sent = try body(DashboardWireContract.choreBody(
                assignedTo: "u", description: "", dueDate: "d", houseId: "h",
                isRecurring: false, level: 10, recurringInterval: 0, title: "Wash", category: invalid))
            XCTAssertNil(sent["category"], "category \(invalid)")
        }
    }

    // MARK: Records

    func testListDecodesSystemAndUserRecords() throws {
        let records = try ChoreCatalogWireContract.list(response: Self.ok(Self.fixtureData("list")))
        XCTAssertEqual(records.count, 4)
        XCTAssertEqual(records.systemRecords.map(\.title), ["Bulaşıkları yıka", "Çöpü çıkar"])
        XCTAssertEqual(records[1].description, "", "null description reads as empty")
        XCTAssertEqual(records[0].categoryKind, .kitchen)
        XCTAssertEqual(records[0].createdOn, "2026-11-12T08:30:00Z")
        // Newest first: the bottles were saved at 10:00, the sheets updated at 09:15.
        XCTAssertEqual(records.userRecords.map(\.id), ["6730f1c2a1b2c3d4e5f60719", "6730f1c2a1b2c3d4e5f60718"])
    }

    func testRequestEncodingLeavesOutServerFieldsAndNewIds() throws {
        let records = try ChoreCatalogWireContract.list(response: Self.ok(Self.fixtureData("list")))
        let copy = records[0].asNewUserRecord
        XCTAssertNil(copy.id)
        XCTAssertFalse(copy.isSystem)

        let body = try ChoreCatalogWireContract.upsertBody([copy, records[2].markedDeleted])
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: body) as? [[String: Any]])
        XCTAssertEqual(Set(sent[0].keys), ["title", "description", "recurringInterval", "level", "category", "isDeleted", "isSystem"])
        XCTAssertEqual(sent[0]["isSystem"] as? Bool, false)
        XCTAssertEqual(sent[1]["id"] as? String, "6730f1c2a1b2c3d4e5f60718")
        XCTAssertEqual(sent[1]["isDeleted"] as? Bool, true)
        XCTAssertNil(sent[1]["userId"])
        XCTAssertNil(sent[1]["updatedOn"])
    }

    func testFixtureRequestMatchesWhatTheClientSends() throws {
        let upsert = try XCTUnwrap(try Self.fixture()["upsert"] as? [String: Any])
        let request = try JSONSerialization.data(withJSONObject: try XCTUnwrap(upsert["request"]))
        let records = try JSONDecoder().decode([ChoreCatalogRecord].self, from: request)
        let body = try ChoreCatalogWireContract.upsertBody(records)
        XCTAssertEqual(try JSONSerialization.jsonObject(with: body) as? NSArray,
                       try JSONSerialization.jsonObject(with: request) as? NSArray)
    }

    func testUpsertPatchesAddUpdateAndDeleteByIndex() throws {
        let local = try ChoreCatalogWireContract.list(response: Self.ok(Self.fixtureData("list")))
        let upsert = try XCTUnwrap(try Self.fixture()["upsert"] as? [String: Any])
        let sent = try JSONDecoder().decode([ChoreCatalogRecord].self,
                                            from: JSONSerialization.data(withJSONObject: try XCTUnwrap(upsert["request"])))
        let response = try JSONSerialization.data(withJSONObject: try XCTUnwrap(upsert["response"]))

        let patched = try ChoreCatalogWireContract.upsert(response: Self.ok(response), sent: sent, local: local)
        XCTAssertEqual(patched.compactMap(\.id), upsert["expectedIds"] as? [String])
        let updated = try XCTUnwrap(patched.first { $0.id == "6730f1c2a1b2c3d4e5f60718" })
        XCTAssertEqual(updated.title, "Nevresimleri değiştir")
        XCTAssertEqual(updated.level, 30)
        XCTAssertEqual(updated.createdOn, "2026-11-12T09:00:00Z")
        XCTAssertEqual(updated.updatedOn, "2026-11-12T11:00:00Z")
        XCTAssertEqual(patched.last?.title, "Balkonu süpür")
        XCTAssertEqual(patched.userRecords.first?.id, "6730f1c2a1b2c3d4e5f60718", "same time; earlier in the list wins")
    }

    func testPatchRejectsAResponseThatDoesNotMatchTheRequest() {
        let sent = [ChoreCatalogRecord(title: "Water plants", category: 8)]
        XCTAssertThrowsError(try ChoreCatalogPatch.apply(response: [], sent: sent, to: [])) {
            XCTAssertEqual($0 as? ChoreCatalogPatchError, .countMismatch)
        }
        XCTAssertThrowsError(try ChoreCatalogPatch.apply(response: sent, sent: sent, to: [])) {
            XCTAssertEqual($0 as? ChoreCatalogPatchError, .missingId(index: 0))
        }
        XCTAssertThrowsError(try ChoreCatalogWireContract.upsert(response: Self.ok(Data("[]".utf8)), sent: sent, local: [])) {
            XCTAssertEqual(($0 as? ChoreCatalogFailure)?.kind, .invalidResponse)
        }
    }

    // MARK: Validation

    func testRulesMatchTheServerLimits() {
        func rules(_ change: (inout ChoreCatalogRecord) -> Void) -> [ChoreCatalogRule] {
            var record = ChoreCatalogRecord(title: "Wash", category: 1)
            change(&record)
            return ChoreCatalogRules.violations(of: record)
        }
        XCTAssertEqual(rules { _ in }, [])
        XCTAssertEqual(rules { $0.title = "ab" }, [.titleLength])
        XCTAssertEqual(rules { $0.title = "  abc  " }, [], "length is measured after trimming")
        XCTAssertEqual(rules { $0.title = "   ab   " }, [.titleLength])
        XCTAssertEqual(rules { $0.title = String(repeating: "ş", count: 200) }, [], "characters, not bytes")
        XCTAssertEqual(rules { $0.title = String(repeating: "a", count: 201) }, [.titleLength])
        XCTAssertEqual(rules { $0.description = String(repeating: "ğ", count: 1000) }, [])
        XCTAssertEqual(rules { $0.description = String(repeating: "a", count: 1001) }, [.descriptionTooLong])
        XCTAssertEqual(rules { $0.recurringInterval = 365 }, [])
        XCTAssertEqual(rules { $0.recurringInterval = 366 }, [.recurringIntervalOutOfRange])
        XCTAssertEqual(rules { $0.recurringInterval = -1 }, [.recurringIntervalOutOfRange])
        XCTAssertEqual(rules { $0.level = 15 }, [.invalidLevel])
        XCTAssertEqual(rules { $0.category = 0 }, [.invalidCategory])
        XCTAssertEqual(rules { $0.category = 10 }, [.invalidCategory])
        XCTAssertEqual(rules { $0.id = "short" }, [.invalidId])
        XCTAssertEqual(rules { $0.id = "" }, [], "an empty id is a new record")
        XCTAssertEqual(rules { $0.isDeleted = true }, [.deleteWithoutId])
        XCTAssertEqual(rules { $0.isSystem = true }, [.systemRecord])
    }

    func testBatchLimitsAreCheckedBeforeSending() {
        let record = ChoreCatalogRecord(title: "Wash", category: 1)
        XCTAssertEqual(ChoreCatalogRules.firstViolation(in: []), ChoreCatalogViolation(index: nil, rule: .emptyBatch))
        XCTAssertNil(ChoreCatalogRules.firstViolation(in: Array(repeating: record, count: 100)))
        XCTAssertEqual(ChoreCatalogRules.firstViolation(in: Array(repeating: record, count: 101)),
                       ChoreCatalogViolation(index: nil, rule: .tooManyRecords))

        var bad = record
        bad.category = 0
        XCTAssertThrowsError(try ChoreCatalogWireContract.upsertBody([record, bad])) {
            XCTAssertEqual($0 as? ChoreCatalogViolation, ChoreCatalogViolation(index: 1, rule: .invalidCategory))
        }
    }

    func testSentTextIsTrimmed() throws {
        let record = ChoreCatalogRecord(title: "  Wash dishes \n", description: " after dinner ", category: 1)
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: ChoreCatalogWireContract.upsertBody([record])) as? [[String: Any]])
        XCTAssertEqual(sent[0]["title"] as? String, "Wash dishes")
        XCTAssertEqual(sent[0]["description"] as? String, "after dinner")
        XCTAssertEqual(ChoreCatalogWireContract.sentRecords([record])[0].title, "Wash dishes")
    }

    // MARK: Errors

    func testErrorsKeepTheLocalizedMessageAndKind() throws {
        let errors = try XCTUnwrap(try Self.fixture()["errors"] as? [[String: Any]])
        for error in errors {
            let status = try XCTUnwrap(error["status"] as? Int)
            let body = try JSONSerialization.data(withJSONObject: try XCTUnwrap(error["body"]))
            let response = HTTPResponse(statusCode: status, headers: [:], body: body)
            let expectedMessage = (error["body"] as? [String: Any])?["error"] as? String
            XCTAssertThrowsError(try ChoreCatalogWireContract.list(response: response)) {
                let failure = $0 as? ChoreCatalogFailure
                XCTAssertEqual(failure?.kind.rawValue, error["kind"] as? String, "status \(status)")
                XCTAssertEqual(failure?.message, expectedMessage, "status \(status)")
                XCTAssertEqual(failure?.refreshesList, status == 404)
            }
        }
        XCTAssertThrowsError(try ChoreCatalogWireContract.list(response: Self.ok(Data("{}".utf8)))) {
            XCTAssertEqual($0 as? ChoreCatalogFailure, ChoreCatalogFailure(kind: .invalidResponse, message: nil))
        }
    }

    /// `Documents/choreCatalogSeed.json`, handed to the backend for the system templates: every
    /// record passes the server's rules (as one batch; only an admin may send `isSystem: true`).
    func testSeedRecordsPassTheServerRules() throws {
        struct Seed: Decodable {
            struct Reference: Decodable { let templateId: String }
            let records: [ChoreCatalogRecord]
            let reference: [Reference]
        }
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Documents/choreCatalogSeed.json")
        let seed = try JSONDecoder().decode(Seed.self, from: Data(contentsOf: url))
        XCTAssertEqual(seed.records.count, 62)
        XCTAssertEqual(seed.reference.count, seed.records.count)
        XCTAssertEqual(Set(seed.reference.map(\.templateId)).count, seed.records.count)
        XCTAssertTrue(seed.records.allSatisfy { $0.isSystem && !$0.isDeleted && $0.id == nil })
        XCTAssertEqual(Set(seed.records.map(\.categoryKind)), Set(ChoreCategoryKind.assignable))
        let asSent = seed.records.map { record -> ChoreCatalogRecord in
            var record = record
            record.isSystem = false
            return record
        }
        XCTAssertNil(ChoreCatalogRules.firstViolation(in: asSent))
        XCTAssertEqual(asSent.map(ChoreCatalogRules.prepared), asSent, "text is already trimmed")
    }

    // MARK: Helpers

    static func fixture() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Fixtures/choreCatalogApi.json")
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    static func fixtureData(_ key: String) throws -> Data {
        try JSONSerialization.data(withJSONObject: try XCTUnwrap(try fixture()[key]))
    }

    static func ok(_ body: Data) -> HTTPResponse {
        HTTPResponse(statusCode: 200, headers: [:], body: body)
    }

    static func chore(category: Int) throws -> Data {
        var object = try XCTUnwrap(
            try JSONSerialization.jsonObject(with: ChoreFixtures.responseWithMixedISOStringsAndNullOptionals) as? [String: Any])
        object["category"] = category
        return try JSONSerialization.data(withJSONObject: object)
    }
}
