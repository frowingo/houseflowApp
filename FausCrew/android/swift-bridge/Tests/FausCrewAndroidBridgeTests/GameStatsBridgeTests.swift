import XCTest
@testable import FausCrewAndroidBridge

/// The stats facade: Core's request shape without the JWT, and the board projection.
final class GameStatsBridgeTests: XCTestCase {
    private let context = #"{"memberIds":["u1","u2"],"knownGameKeys":["fausSwitch","houseRockets","houseTanks"]}"#

    private func object(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    private func rows(_ section: Any?) throws -> [String] {
        let standings = try XCTUnwrap((section as? [String: Any])?["standings"] as? [[String: Any]])
        return standings.map {
            "\($0["userId"] as? String ?? ""):\($0["wins"] as? Int ?? -1)/\($0["matchesPlayed"] as? Int ?? -1)"
                + (($0["isLeader"] as? Bool) == true ? "*" : "")
        }
    }

    func testRequestHasRouteAndHouseWithoutJwt() throws {
        let result = try object(gameStatsRequest("h1"))
        XCTAssertEqual(result["ok"] as? Bool, true)
        XCTAssertEqual(result["path"] as? String, "game/stats")
        XCTAssertEqual(result["method"] as? String, "GET")
        XCTAssertEqual(result["query"] as? [[String: String]], [["name": "houseId", "value": "h1"]])
        XCTAssertFalse(String(describing: result).contains("Bearer"))
    }

    func testInvalidHouseIsRefused() throws {
        let result = try object(gameStatsRequest("a/b"))
        XCTAssertEqual(result["ok"] as? Bool, false)
        XCTAssertEqual(result["kind"] as? String, "invalidRequest")
    }

    func testBoardProjection() throws {
        let body = """
        {"success":true,"data":[
          {"gameKey":"fausSwitch","players":[{"userId":"u2","wins":5,"matchesPlayed":9},{"userId":"gone","wins":4,"matchesPlayed":9},{"userId":"u1","wins":0,"matchesPlayed":0}]},
          {"gameKey":"laterGame","players":[{"userId":"u1","wins":9,"matchesPlayed":9}]},
          {"gameKey":"houseTanks","players":[{"userId":"u1","wins":2,"matchesPlayed":2},{"userId":"u2","wins":0,"matchesPlayed":2}]}
        ]}
        """
        let result = try object(gameStatsResponse(200, body, context))
        XCTAssertEqual(result["ok"] as? Bool, true)
        let games = try XCTUnwrap(result["games"] as? [[String: Any]])
        XCTAssertEqual(games.map { $0["gameKey"] as? String }, ["fausSwitch", "houseTanks"])
        XCTAssertEqual(try rows(games[0]), ["u2:5/9*", "u1:0/0"])
        XCTAssertEqual(try rows(result["overall"]), ["u2:5/11*", "u1:2/2"])
        XCTAssertNil((result["overall"] as? [String: Any])?["gameKey"])
    }

    func testEmptyHouseHasNoGamesAndNoOverall() throws {
        let result = try object(gameStatsResponse(200, #"{"success":true,"data":[]}"#, context))
        XCTAssertEqual(result["ok"] as? Bool, true)
        XCTAssertEqual((result["games"] as? [Any])?.count, 0)
        XCTAssertNil(result["overall"])
    }

    func testFailuresCarryKindAndMessage() throws {
        let cases: [(Int32, String)] = [(400, "invalidRequest"), (401, "unauthorized"), (403, "accessLost"),
                                        (404, "accessLost"), (429, "rateLimited"), (500, "server")]
        for (status, kind) in cases {
            let result = try object(gameStatsResponse(status, #"{"success":false,"error":"Mesaj"}"#, context))
            XCTAssertEqual(result["ok"] as? Bool, false)
            XCTAssertEqual(result["kind"] as? String, kind, "\(status)")
            XCTAssertEqual(result["message"] as? String, "Mesaj")
        }
        let invalid = try object(gameStatsResponse(200, #"{"success":true,"data":null}"#, context))
        XCTAssertEqual(invalid["kind"] as? String, "invalidResponse")
    }
}
