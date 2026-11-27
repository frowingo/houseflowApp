import XCTest
@testable import FausCrewAndroidBridge

/// The archive facade: Core's request shapes without the JWT, and the page projection.
final class ChoreArchiveBridgeTests: XCTestCase {
    private func object(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    private func chore(id: String, status: Int, round: Int, votes: String, completedAt: String, completedBy: String) -> String {
        """
        {"id":"\(id)","title":"Dishes","description":"","houseId":"h","houseOwnerId":"u","assignedTo":"u",
        "dueDate":"2026-11-10T18:00:00Z","isCompleted":false,"isRecurring":false,"level":20,"recurringInterval":0,
        "status":\(status),"createdOn":"2026-11-01T09:00:00Z","completedAt":"\(completedAt)","completedBy":"\(completedBy)",
        "statusHistories":[],"reviewRound":\(round),"reviewVotes":\(votes),"category":3}
        """
    }

    private var page: String {
        let rejected = #"[{"id":"v","choreId":"c1","houseId":"h","reviewRound":3,"reviewerId":"u2","isApproved":false,"createdOn":"2026-11-14T08:00:00Z"}]"#
        let failed = chore(id: "c1", status: 4, round: 3, votes: rejected, completedAt: "2026-11-14T08:00:00Z", completedBy: "system")
        let done = chore(id: "c2", status: 3, round: 1, votes: "[]", completedAt: "2026-11-12T10:00:00Z", completedBy: "u2")
        return #"{"success":true,"data":{"chores":[\#(failed),\#(done)],"nextUrl":"/api/v1/chore/archive?cursor=a%2Bb+c/d%3D&houseId=h"}}"#
    }

    func testFirstRequestSendsUtcBoundsWithoutJwt() throws {
        let result = try object(choreArchiveRequest(
            "first", #"{"houseId":"h1","fromEpochSeconds":1793480400,"toEpochSeconds":1796072400}"#))
        XCTAssertEqual(result["ok"] as? Bool, true)
        XCTAssertEqual(result["path"] as? String, "chore/archive")
        XCTAssertEqual(result["method"] as? String, "GET")
        XCTAssertNil(result["percentEncodedQuery"])
        let query = try XCTUnwrap(result["query"] as? [[String: String]])
        XCTAssertEqual(query, [
            ["name": "houseId", "value": "h1"],
            ["name": "from", "value": "2026-10-31T21:00:00Z"],
            ["name": "to", "value": "2026-11-30T21:00:00Z"],
        ])
        XCTAssertFalse(String(describing: result).contains("Bearer"))
    }

    func testReversedOrEmptyRangeIsRefused() throws {
        for fields in [#"{"houseId":"h","fromEpochSeconds":1796072400,"toEpochSeconds":1793480400}"#,
                       #"{"houseId":"h","fromEpochSeconds":1793480400,"toEpochSeconds":1793480400}"#,
                       #"{"houseId":"","fromEpochSeconds":1,"toEpochSeconds":2}"#] {
            let result = try object(choreArchiveRequest("first", fields))
            XCTAssertEqual(result["ok"] as? Bool, false, fields)
            XCTAssertEqual(result["kind"] as? String, "invalidRequest", fields)
        }
    }

    func testNextRequestKeepsTheQueryByteForByte() throws {
        let query = "cursor=a%2Bb+c/d%3D&houseId=h"
        let result = try object(choreArchiveRequest("next", #"{"nextUrl":"/api/v1/chore/archive?\#(query)"}"#))
        XCTAssertEqual(result["ok"] as? Bool, true)
        XCTAssertEqual(result["path"] as? String, "chore/archive")
        XCTAssertEqual(result["method"] as? String, "GET")
        XCTAssertEqual(result["percentEncodedQuery"] as? String, query)
        XCTAssertEqual((result["query"] as? [Any])?.count, 0)
        XCTAssertFalse(String(describing: result).contains("Bearer"))
    }

    func testInvalidNextUrlAndUnknownActionAreRefused() throws {
        for (action, fields) in [("next", #"{"nextUrl":"/other/chore/archive?cursor=a"}"#),
                                 ("next", #"{"nextUrl":"/api/v1/chore/archive?cursor=%zz"}"#),
                                 ("next", "{}"), ("nope", "{}")] {
            let result = try object(choreArchiveRequest(action, fields))
            XCTAssertEqual(result["ok"] as? Bool, false, fields)
            XCTAssertEqual(result["kind"] as? String, "invalidRequest", fields)
        }
    }

    func testResponseProjectsChoresAndNextUrl() throws {
        let result = try object(choreArchiveResponse(200, page))
        XCTAssertEqual(result["ok"] as? Bool, true)
        XCTAssertEqual(result["nextUrl"] as? String, "/api/v1/chore/archive?cursor=a%2Bb+c/d%3D&houseId=h")
        let chores = try XCTUnwrap(result["chores"] as? [[String: Any]])
        XCTAssertEqual(chores.map { $0["id"] as? String }, ["c1", "c2"])
        XCTAssertEqual(chores[0]["failureReason"] as? String, "reviewRejected")
        XCTAssertEqual(chores[0]["completedBy"] as? String, "system")
        XCTAssertEqual(chores[0]["completedAt"] as? String, "2026-11-14T08:00:00Z")
        XCTAssertNil(chores[1]["failureReason"])
        XCTAssertEqual(chores[1]["completedBy"] as? String, "u2")
        XCTAssertEqual(chores[1]["completedAt"] as? String, "2026-11-12T10:00:00Z")
    }

    func testResponseWithoutNextUrlIsTheLastPage() throws {
        for body in [#"{"success":true,"data":{"chores":[]}}"#, #"{"success":true,"data":{"chores":[],"nextUrl":null}}"#] {
            let result = try object(choreArchiveResponse(200, body))
            XCTAssertEqual(result["ok"] as? Bool, true)
            XCTAssertNil(result["nextUrl"])
            XCTAssertEqual((result["chores"] as? [Any])?.count, 0)
        }
    }

    func testFailures() throws {
        let bad = try object(choreArchiveResponse(400, #"{"success":false,"error":"Bad cursor"}"#))
        XCTAssertEqual(bad["ok"] as? Bool, false)
        XCTAssertEqual(bad["kind"] as? String, "invalidRequest")
        XCTAssertEqual(bad["message"] as? String, "Bad cursor")
        let forbidden = try object(choreArchiveResponse(403, #"{"success":false,"error":"Not a member"}"#))
        XCTAssertEqual(forbidden["kind"] as? String, "notMember")
        XCTAssertEqual(forbidden["message"] as? String, "Not a member")
        XCTAssertEqual(try object(choreArchiveResponse(401, ""))["kind"] as? String, "unauthorized")
        XCTAssertNil(try object(choreArchiveResponse(500, ""))["message"])
        XCTAssertEqual(try object(choreArchiveResponse(200, "garbage"))["kind"] as? String, "invalidResponse")
    }
}
