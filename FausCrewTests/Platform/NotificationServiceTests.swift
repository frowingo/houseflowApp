import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class NotificationServiceTests: XCTestCase {
    private var http: RecordingHTTP!
    private var keychain: FakeKeychainStore!
    private var rejectedTokens: [String] = []
    private var service: NotificationService!

    override func setUp() async throws {
        APILanguage.update(prefix: "tr")
        addTeardownBlock { await MainActor.run { APILanguage.update(prefix: "en") } }
        http = RecordingHTTP()
        keychain = FakeKeychainStore()
        keychain.authToken = "jwt-1"
        service = NotificationService(http: http, keychain: keychain, onUnauthorized: { [unowned self] in self.rejectedTokens.append($0) })
    }

    func testListSendsHouseCursorPageSizeSessionAndLanguage() async throws {
        http.response = response(200, #"{"success":true,"data":{"items":[{"id":"n1","type":"announcement","houseId":"h1","senderUserId":"u2","title":"T","message":"M","createdAt":"2026-11-20T22:15:33Z"}],"nextCursor":"n1"}}"#)

        let page = try await service.list(houseID: "h1", before: "n9")

        XCTAssertEqual(page.items.map(\.id), ["n1"])
        XCTAssertEqual(page.nextCursor, "n1")
        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "notification")
        XCTAssertEqual(request.queryItems.map { "\($0.name)=\($0.value ?? "")" }, ["houseId=h1", "before=n9", "limit=20"])
        XCTAssertEqual(request.headers["Authorization"], "Bearer jwt-1")
        XCTAssertEqual(request.headers["Accept-Language"], "tr")
    }

    func testRemindPostsWithoutABody() async throws {
        http.response = response(200, #"{"success":true}"#)

        try await service.remind(choreID: "c1")

        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "chore/c1/remind")
        XCTAssertNil(request.body)
        XCTAssertEqual(request.headers["Accept-Language"], "tr")
    }

    func testFailureKindsCarryTheServerMessage() async {
        let cases: [(Int, NotificationFailure.Kind)] = [(400, .invalidRequest), (403, .notMember), (404, .notFound), (409, .alreadyReminded)]
        for (status, kind) in cases {
            http.response = response(status, #"{"success":false,"error":"Server text"}"#)
            do {
                try await service.remind(choreID: "c1")
                XCTFail("\(status) should fail")
            } catch {
                XCTAssertEqual(error as? NotificationFailure, NotificationFailure(kind: kind, message: "Server text"))
            }
        }
    }

    func testUnauthorizedHandsTheRejectedTokenToTheSessionFlow() async {
        http.response = response(401, #"{"success":false,"error":"Expired"}"#)

        do {
            _ = try await service.list(houseID: "h1", before: nil)
            XCTFail("401 should fail")
        } catch {
            XCTAssertEqual((error as? NotificationFailure)?.kind, .unauthorized)
        }
        XCTAssertEqual(rejectedTokens, ["jwt-1"])
    }

    func testWithoutASessionNothingIsSent() async {
        keychain.authToken = nil

        do {
            try await service.remind(choreID: "c1")
            XCTFail("no session should fail")
        } catch {
            XCTAssertEqual((error as? NotificationFailure)?.kind, .unauthorized)
        }
        XCTAssertTrue(http.requests.isEmpty)
    }

    private func response(_ status: Int, _ body: String) -> HTTPResponse {
        HTTPResponse(statusCode: status, headers: [:], body: Data(body.utf8))
    }
}

@MainActor
private final class RecordingHTTP: HTTPClient {
    var response = HTTPResponse(statusCode: 200, headers: [:], body: Data())
    private(set) var requests: [HTTPRequest] = []

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        return response
    }
}
