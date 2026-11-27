import Foundation
import FausCrewCore
import XCTest

final class ChoreArchiveWireContractTests: XCTestCase {
    private typealias Contract = ChoreArchiveWireContract

    private let cursor = "eyJ0IjoiMjAyNi0xMS0yMFQyMjoxNTozM1oiLCJpZCI6IjZiMDBjNjg1OWMyZmUyZWZiODU5MjAwNyIs+/Z4=="

    private func response(_ status: Int, _ body: String) -> HTTPResponse {
        HTTPResponse(statusCode: status, headers: [:], body: Data(body.utf8))
    }

    private func failure(_ body: () throws -> Void) -> ChoreArchiveFailure? {
        do { try body(); return nil } catch { return error as? ChoreArchiveFailure }
    }

    private func date(_ iso: String) throws -> Date {
        try XCTUnwrap(ISO8601DateFormatter().date(from: iso))
    }

    // MARK: - First page

    func testFirstPageRequest() throws {
        let request = try Contract.firstPageRequest(
            houseID: " h1 ", from: try date("2026-10-31T21:00:00Z"), to: try date("2026-11-30T21:00:05Z"), jwt: "jwt"
        )
        XCTAssertEqual(request.path, "chore/archive")
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.headers, ["Authorization": "Bearer jwt"])
        XCTAssertNil(request.body)
        XCTAssertNil(request.percentEncodedQuery)
        XCTAssertEqual(request.queryItems, [
            HTTPQueryItem(name: "houseId", value: "h1"),
            HTTPQueryItem(name: "from", value: "2026-10-31T21:00:00Z"),
            HTTPQueryItem(name: "to", value: "2026-11-30T21:00:05Z"),
        ])
    }

    func testLocalMidnightIsSentAsUTC() throws {
        let from = try date("2026-11-01T00:00:00+03:00")
        let to = try date("2026-12-01T00:00:00+03:00")
        let request = try Contract.firstPageRequest(houseID: "h1", from: from, to: to, jwt: "j")
        XCTAssertEqual(request.queryItems.map(\.value), ["h1", "2026-10-31T21:00:00Z", "2026-11-30T21:00:00Z"])
    }

    func testFractionalSecondsAreNotSent() throws {
        let from = Date(timeIntervalSince1970: 1_793_394_000.75)
        let request = try Contract.firstPageRequest(houseID: "h1", from: from, to: from.addingTimeInterval(60), jwt: "j")
        XCTAssertEqual(request.queryItems[1].value, "2026-10-30T21:00:00Z")
    }

    func testEmptyReversedRangeAndBlankHouseAreRefused() throws {
        let a = try date("2026-11-01T00:00:00Z")
        let b = try date("2026-11-02T00:00:00Z")
        let invalid = ChoreArchiveFailure(kind: .invalidRequest, message: nil)
        XCTAssertEqual(failure { _ = try Contract.firstPageRequest(houseID: "h", from: a, to: a, jwt: "j") }, invalid)
        XCTAssertEqual(failure { _ = try Contract.firstPageRequest(houseID: "h", from: b, to: a, jwt: "j") }, invalid)
        XCTAssertEqual(failure { _ = try Contract.firstPageRequest(houseID: "  \n", from: a, to: b, jwt: "j") }, invalid)
        XCTAssertEqual(failure { _ = try Contract.firstPageRequest(houseID: "", from: a, to: b, jwt: "j") }, invalid)
    }

    // MARK: - nextUrl

    func testNextURLIsKeptByteForByte() throws {
        let queries = [
            "cursor=abc&from=2026-10-31T21%3A00%3A00Z&houseId=h1&to=2026-11-30T21%3A00%3A00Z",
            "cursor=a%2Bb%2Fc%3D&from=x",
            "cursor=a+b/c=&from=x",
            "cursor=\(cursor)&from=2026-10-31T21:00:00Z&houseId=h1&to=2026-11-30T21:00:00Z",
            "q=a?b@c!$()*,;~._-",
        ]
        for query in queries {
            let request = try XCTUnwrap(Contract.nextPageRequest(nextURL: "/api/v1/chore/archive?\(query)", jwt: "jwt"), query)
            XCTAssertEqual(request.path, "chore/archive")
            XCTAssertEqual(request.method, "GET")
            XCTAssertEqual(request.percentEncodedQuery, query)
            XCTAssertTrue(request.queryItems.isEmpty)
            XCTAssertEqual(request.headers, ["Authorization": "Bearer jwt"])
            XCTAssertNil(request.body)
        }
    }

    func testInvalidNextURLsAreRefused() {
        let invalid = [
            "/chore/archive?cursor=a",
            "api/v1/chore/archive?cursor=a",
            "http://host/api/v1/chore/archive?cursor=a",
            "https://host/api/v1/chore/archive?cursor=a",
            "//host/api/v1/chore/archive?cursor=a",
            "/api/v1/../chore/archive?cursor=a",
            "/api/v1/chore/./archive?cursor=a",
            "/api/v1/chore//archive?cursor=a",
            "/api/v1/chore/archive/?cursor=a",
            "/api/v1/chore%2Farchive?cursor=a",
            "/api/v1/?cursor=a",
            "/api/v1/?",
            "/api/v1/chore/archive",
            "/api/v1/chore/archive?",
            "/api/v1/chore/archive?cursor=a b",
            "/api/v1/chore/archive?cursor=a%",
            "/api/v1/chore/archive?cursor=a%2",
            "/api/v1/chore/archive?cursor=a%zz",
            "/api/v1/chore/archive?cursor=a#frag",
            "/api/v1/chore/archive?cursor=a'b",
            "/api/v1/chore/archive?cursor=ç",
            "/api/v1/chore/archive?cursor=a\n",
            "/api/v1/chore/arçhive?cursor=a",
            "",
        ]
        for nextURL in invalid {
            XCTAssertNil(Contract.nextPageRequest(nextURL: nextURL, jwt: "jwt"), nextURL)
        }
    }

    // MARK: - Page

    private static let pageJSON = """
    {
      "success": true,
      "data": {
        "chores": [
          {
            "id": "c1", "title": "Dishes", "description": "", "houseId": "h1", "houseOwnerId": "u1",
            "assignedTo": "u2", "dueDate": "2026-11-02T18:00:00Z", "isCompleted": true, "isRecurring": false,
            "level": 10, "recurringInterval": 0, "status": 3, "createdOn": "2026-11-01T09:00:00Z",
            "completedAt": "2026-11-02T12:00:00Z", "completedBy": "u2",
            "statusHistories": [], "reviewRound": 1, "reviewVotes": []
          },
          {
            "id": "c2", "title": "Trash", "description": "", "houseId": "h1", "houseOwnerId": "u1",
            "assignedTo": "u2", "dueDate": { "time.Time": "2026-11-03T18:00:00Z" }, "isCompleted": false,
            "isRecurring": false, "level": 10, "recurringInterval": 0, "status": 4,
            "createdOn": { "time.Time": "2026-11-01T09:00:00Z" },
            "completedAt": { "time.Time": "2026-11-03T18:00:00Z" }, "completedBy": "system",
            "statusHistories": [], "reviewRound": 0, "reviewVotes": []
          }
        ],
        "nextUrl": "/api/v1/chore/archive?cursor=abc&from=x&houseId=h1&to=y"
      }
    }
    """

    func testPageDecodesChoresAndNextURL() throws {
        let page = try Contract.page(response(200, Self.pageJSON))
        XCTAssertEqual(page.chores.map(\.id), ["c1", "c2"])
        XCTAssertEqual(page.nextURL, "/api/v1/chore/archive?cursor=abc&from=x&houseId=h1&to=y")
        XCTAssertEqual(page.chores[0].completedAt, "2026-11-02T12:00:00Z")
        XCTAssertEqual(page.chores[1].dueDate, "2026-11-03T18:00:00Z")
        XCTAssertEqual(page.chores[1].completedBy, "system")
        XCTAssertEqual(page.chores[1].failureReason, .dueDatePassed)
        XCTAssertNil(page.chores[0].failureReason)
    }

    func testBlankNextURLMeansLastPage() throws {
        for next in [#""nextUrl": null"#, #""nextUrl": "  ""#, #""other": 1"#] {
            let body = #"{"success":true,"data":{"chores":[],\#(next)}}"#
            let page = try Contract.page(response(200, body))
            XCTAssertEqual(page, ChoreArchivePage(chores: [], nextURL: nil), next)
        }
    }

    func testStatusesMapToKindsAndKeepTheServerMessage() {
        let expected: [(Int, ChoreArchiveFailure.Kind)] = [
            (400, .invalidRequest), (401, .unauthorized), (403, .notMember), (500, .server), (404, .server),
        ]
        for (status, kind) in expected {
            let result = failure { _ = try Contract.page(response(status, #"{"error":"Nope."}"#)) }
            XCTAssertEqual(result, ChoreArchiveFailure(kind: kind, message: "Nope."), "\(status)")
        }
        XCTAssertNil(failure { _ = try Contract.page(response(502, "")) }?.message)
    }

    func testUnexpectedBodiesAreInvalidResponses() {
        let invalid = ChoreArchiveFailure(kind: .invalidResponse, message: nil)
        for body in [
            #"{"success":false,"data":{"chores":[],"nextUrl":null}}"#,
            #"{"success":true}"#,
            #"{"success":true,"data":{"nextUrl":null}}"#,
            #"{"success":true,"data":{"chores":[{"id":"c"}]}}"#,
            "not json",
            "",
        ] {
            XCTAssertEqual(failure { _ = try Contract.page(response(200, body)) }, invalid, body)
        }
    }

    func testBlankFailureMessageIsDropped() {
        XCTAssertNil(ChoreArchiveFailure(kind: .server, message: "  ").message)
        XCTAssertEqual(ChoreArchiveFailure(kind: .server, message: "x").message, "x")
    }
}
