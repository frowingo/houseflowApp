import XCTest
@testable import FausCrewAndroidBridge

/// The catalog facade: Core's rules on the way out, the patched list (full records) on the way in.
final class ChoreCatalogBridgeTests: XCTestCase {
    private let system = #"{"id":"6730f1c2a1b2c3d4e5f60701","title":"Bulaşıkları yıka","description":null,"recurringInterval":1,"level":10,"category":1,"isDeleted":false,"isSystem":true,"userId":"6730f1c2a1b2c3d4e5f60001","createdOn":"2026-11-12T08:30:00Z","updatedOn":"2026-11-12T08:30:00Z"}"#
    private let draft = #"{"id":"6730f1c2a1b2c3d4e5f60718","title":"Nevresimler","description":"","recurringInterval":7,"level":20,"category":2,"isDeleted":false,"isSystem":false,"userId":"u","createdOn":"2026-11-12T09:00:00Z","updatedOn":"2026-11-12T09:00:00Z"}"#

    private func object(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    func testRequestBodyTrimsAndLeavesServerFieldsOut() throws {
        let result = try object(choreCatalogRequestBody(#"[{"title":"  Balkonu süpür ","description":"","recurringInterval":14,"level":20,"category":8,"isDeleted":false,"isSystem":false,"userId":"u"}]"#))
        XCTAssertEqual(result["ok"] as? Bool, true)
        let body = try XCTUnwrap(result["body"] as? String)
        let sent = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(body.utf8)) as? [[String: Any]])
        XCTAssertEqual(sent.first?["title"] as? String, "Balkonu süpür")
        XCTAssertNil(sent.first?["id"])
        XCTAssertNil(sent.first?["userId"])
    }

    func testRequestBodyRefusesWhatTheServerWould() throws {
        let short = try object(choreCatalogRequestBody(#"[{"title":"ab","level":10,"category":1}]"#))
        XCTAssertEqual(short["ok"] as? Bool, false)
        XCTAssertEqual(short["kind"] as? String, "validation")
        XCTAssertEqual(short["rule"] as? String, "titleLength")
        XCTAssertEqual(short["index"] as? Int, 0)
        XCTAssertEqual(try object(choreCatalogRequestBody("[]"))["rule"] as? String, "emptyBatch")
        XCTAssertEqual(try object(choreCatalogRequestBody("nope"))["ok"] as? Bool, false)
    }

    func testListKeepsEveryField() throws {
        let result = try object(choreCatalogResponse("list", 200, "[\(system),\(draft)]", "", ""))
        let records = try XCTUnwrap(result["records"] as? [[String: Any]])
        XCTAssertEqual(records.count, 2)
        XCTAssertEqual(records[0]["isSystem"] as? Bool, true)
        XCTAssertEqual(records[0]["description"] as? String, "")
        XCTAssertEqual(records[1]["updatedOn"] as? String, "2026-11-12T09:00:00Z")
        XCTAssertEqual(records[1]["userId"] as? String, "u")
    }

    func testUpsertPatchesTheLocalList() throws {
        let sent = #"[{"title":"Balkonu süpür","level":20,"category":8},{"id":"6730f1c2a1b2c3d4e5f60718","title":"Nevresimler","level":20,"category":2,"isDeleted":true}]"#
        let response = #"[{"id":"6730f1c2a1b2c3d4e5f60720","title":"Balkonu süpür","description":"","recurringInterval":0,"level":20,"category":8,"isDeleted":false,"isSystem":false},{"id":"6730f1c2a1b2c3d4e5f60718","title":"Nevresimler","description":"","recurringInterval":7,"level":20,"category":2,"isDeleted":true,"isSystem":false}]"#
        let result = try object(choreCatalogResponse("upsert", 200, response, sent, "[\(system),\(draft)]"))
        let ids = try XCTUnwrap(result["records"] as? [[String: Any]]).map { $0["id"] as? String }
        XCTAssertEqual(ids, ["6730f1c2a1b2c3d4e5f60701", "6730f1c2a1b2c3d4e5f60720"])
    }

    func testFailuresCarryKindAndServerMessage() throws {
        let missing = try object(choreCatalogResponse("upsert", 404, #"{"success":false,"error":"Bulunamadı"}"#, "[]", "[]"))
        XCTAssertEqual(missing["ok"] as? Bool, false)
        XCTAssertEqual(missing["kind"] as? String, "notFound")
        XCTAssertEqual(missing["message"] as? String, "Bulunamadı")
        XCTAssertEqual(try object(choreCatalogResponse("list", 403, #"{"error":"Hayır"}"#, "", ""))["kind"] as? String, "forbidden")
        XCTAssertEqual(try object(choreCatalogResponse("list", 200, "{}", "", ""))["kind"] as? String, "invalidResponse")
    }
}
