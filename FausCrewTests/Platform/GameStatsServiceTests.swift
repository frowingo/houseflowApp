import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class GameStatsServiceTests: XCTestCase {
    private var http: RecordingHTTP!
    private var keychain: FakeKeychainStore!
    private var rejectedTokens: [String] = []
    private var service: GameStatsService!

    override func setUp() async throws {
        APILanguage.update(prefix: "tr")
        addTeardownBlock { await MainActor.run { APILanguage.update(prefix: "en") } }
        http = RecordingHTTP()
        keychain = FakeKeychainStore()
        keychain.authToken = "jwt-1"
        service = GameStatsService(http: http, keychain: keychain, onUnauthorized: { [unowned self] in self.rejectedTokens.append($0) })
    }

    func testSendsHouseSessionAndLanguage() async throws {
        http.response = response(200, #"{"success":true,"data":[{"gameKey":"fausSwitch","players":[{"userId":"u1","wins":1,"matchesPlayed":2}]}]}"#)

        let stats = try await service.stats(houseID: "h1")

        XCTAssertEqual(stats, [HouseGameStats(gameKey: "fausSwitch", players: [PlayerGameStats(userId: "u1", wins: 1, matchesPlayed: 2)])])
        let request = try XCTUnwrap(http.requests.first)
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.path, "game/stats")
        XCTAssertEqual(request.queryItems, [HTTPQueryItem(name: "houseId", value: "h1")])
        XCTAssertEqual(request.headers["Authorization"], "Bearer jwt-1")
        XCTAssertEqual(request.headers["Accept-Language"], "tr")
    }

    func testUnauthorizedHandsTheRejectedTokenToTheSessionFlow() async {
        http.response = response(401, #"{"success":false,"error":"Expired"}"#)
        let error = await failure()
        XCTAssertEqual(error?.kind, .unauthorized)
        XCTAssertEqual(rejectedTokens, ["jwt-1"])
    }

    func testFailureKindsCarryTheServerMessage() async {
        let cases: [(Int, GameStatsFailure.Kind)] = [(400, .invalidRequest), (403, .accessLost), (404, .accessLost),
                                                     (429, .rateLimited), (500, .server)]
        for (status, kind) in cases {
            http.response = response(status, #"{"success":false,"error":"Server text"}"#)
            let error = await failure()
            XCTAssertEqual(error, GameStatsFailure(kind: kind, message: "Server text"), "\(status)")
        }
        XCTAssertTrue(rejectedTokens.isEmpty)
    }

    func testWithoutASessionOrWithABadHouseNothingIsSent() async {
        keychain.authToken = nil
        let missing = await failure()
        XCTAssertEqual(missing?.kind, .unauthorized)

        keychain.authToken = "jwt-1"
        let invalid = await failure(houseID: "a/b")
        XCTAssertEqual(invalid?.kind, .invalidRequest)
        XCTAssertTrue(http.requests.isEmpty)
    }

    private func failure(houseID: String = "h1") async -> GameStatsFailure? {
        do {
            _ = try await service.stats(houseID: houseID)
            XCTFail("the request should fail")
            return nil
        } catch {
            return error as? GameStatsFailure
        }
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
