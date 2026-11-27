import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class ChoreArchiveServiceTests: XCTestCase {
    private var http: RecordingHTTP!
    private var keychain: FakeKeychainStore!
    private var rejectedTokens: [String] = []
    private var service: ChoreArchiveService!

    private let nextURL = "/api/v1/chore/archive?cursor=ab+c/d%3D&from=2026-10-31T21%3A00%3A00Z&houseId=h1&to=2026-11-30T21%3A00%3A00Z"

    override func setUp() async throws {
        APILanguage.update(prefix: "tr")
        addTeardownBlock { await MainActor.run { APILanguage.update(prefix: "en") } }
        http = RecordingHTTP()
        keychain = FakeKeychainStore()
        keychain.authToken = "jwt-1"
        service = ChoreArchiveService(http: http, keychain: keychain, onUnauthorized: { [unowned self] in self.rejectedTokens.append($0) })
    }

    func testFirstPageSendsRangeSessionAndLanguage() async throws {
        http.response = response(200, #"{"success":true,"data":{"chores":[],"nextUrl":"\#(nextURL)"}}"#)

        let page = try await service.firstPage(
            houseID: "h1",
            from: Date(timeIntervalSince1970: 1_793_394_000),
            to: Date(timeIntervalSince1970: 1_795_986_000)
        )

        XCTAssertEqual(page.nextURL, nextURL)
        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "chore/archive")
        XCTAssertEqual(
            request.queryItems.map { "\($0.name)=\($0.value ?? "")" },
            ["houseId=h1", "from=2026-10-30T21:00:00Z", "to=2026-11-29T21:00:00Z"]
        )
        XCTAssertNil(request.percentEncodedQuery)
        XCTAssertEqual(request.headers["Authorization"], "Bearer jwt-1")
        XCTAssertEqual(request.headers["Accept-Language"], "tr")
    }

    func testNextPageKeepsTheQueryUntouched() async throws {
        http.response = response(200, #"{"success":true,"data":{"chores":[]}}"#)

        let page = try await service.nextPage(nextURL: nextURL)

        XCTAssertNil(page.nextURL)
        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.path, "chore/archive")
        XCTAssertTrue(request.queryItems.isEmpty)
        XCTAssertEqual(request.percentEncodedQuery, "cursor=ab+c/d%3D&from=2026-10-31T21%3A00%3A00Z&houseId=h1&to=2026-11-30T21%3A00%3A00Z")
        XCTAssertEqual(request.headers["Authorization"], "Bearer jwt-1")
        XCTAssertEqual(request.headers["Accept-Language"], "tr")
    }

    func testInvalidNextURLFailsWithoutSending() async {
        do {
            _ = try await service.nextPage(nextURL: "https://evil.example/api/v1/chore/archive?cursor=a")
            XCTFail("an invalid nextUrl should fail")
        } catch {
            XCTAssertEqual(error as? ChoreArchiveFailure, ChoreArchiveFailure(kind: .invalidRequest, message: nil))
        }
        XCTAssertTrue(http.requests.isEmpty)
    }

    func testUnauthorizedHandsTheRejectedTokenToTheSessionFlow() async {
        http.response = response(401, #"{"success":false,"error":"Expired"}"#)

        do {
            _ = try await service.nextPage(nextURL: nextURL)
            XCTFail("401 should fail")
        } catch {
            XCTAssertEqual((error as? ChoreArchiveFailure)?.kind, .unauthorized)
        }
        XCTAssertEqual(rejectedTokens, ["jwt-1"])
    }

    func testFailureKindsCarryTheServerMessage() async {
        let cases: [(Int, ChoreArchiveFailure.Kind)] = [(400, .invalidRequest), (403, .notMember), (500, .server)]
        for (status, kind) in cases {
            http.response = response(status, #"{"success":false,"error":"Server text"}"#)
            do {
                _ = try await service.nextPage(nextURL: nextURL)
                XCTFail("\(status) should fail")
            } catch {
                XCTAssertEqual(error as? ChoreArchiveFailure, ChoreArchiveFailure(kind: kind, message: "Server text"))
            }
        }
    }

    func testWithoutASessionNothingIsSent() async {
        keychain.authToken = nil

        do {
            _ = try await service.nextPage(nextURL: nextURL)
            XCTFail("no session should fail")
        } catch {
            XCTAssertEqual((error as? ChoreArchiveFailure)?.kind, .unauthorized)
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
