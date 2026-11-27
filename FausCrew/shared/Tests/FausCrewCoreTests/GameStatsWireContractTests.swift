import Foundation
import FausCrewCore
import XCTest

final class GameStatsWireContractTests: XCTestCase {
    private typealias Contract = GameStatsWireContract
    private let known: Set<String> = [GameKey.fausSwitch, GameKey.houseRockets, GameKey.houseTanks]

    private func response(_ status: Int, _ body: String) -> HTTPResponse {
        HTTPResponse(statusCode: status, headers: [:], body: Data(body.utf8))
    }

    private func failure(_ body: () throws -> Void) -> GameStatsFailure? {
        do { try body(); return nil } catch { return error as? GameStatsFailure }
    }

    private func stats(_ body: String) throws -> [HouseGameStats] {
        try Contract.decode(response(200, body))
    }

    private func game(_ key: String, _ players: [(String, Int, Int)]) -> HouseGameStats {
        HouseGameStats(gameKey: key, players: players.map { PlayerGameStats(userId: $0.0, wins: $0.1, matchesPlayed: $0.2) })
    }

    private func rows(_ section: GameStatsBoard.Section?) -> [String] {
        (section?.standings ?? []).map { "\($0.userId):\($0.wins)/\($0.matchesPlayed)\($0.isLeader ? "*" : "")" }
    }

    // MARK: - Request

    func testRequest() throws {
        let request = try Contract.request(houseID: "h1", jwt: "jwt")
        XCTAssertEqual(request.path, "game/stats")
        XCTAssertEqual(request.method, "GET")
        XCTAssertEqual(request.queryItems, [HTTPQueryItem(name: "houseId", value: "h1")])
        XCTAssertEqual(request.headers, ["Authorization": "Bearer jwt"])
        XCTAssertNil(request.percentEncodedQuery)
    }

    func testInvalidHouseIDIsRefusedBeforeSending() {
        for houseID in ["", " h1", "a/b", "..", "a?b"] {
            XCTAssertEqual(failure { _ = try Contract.request(houseID: houseID, jwt: "jwt") }?.kind, .invalidRequest, houseID)
        }
    }

    // MARK: - Decode

    func testEmptyHouseDecodesToNoGames() throws {
        XCTAssertEqual(try stats(#"{"success":true,"data":[]}"#), [])
    }

    func testDecodesGamesInServerOrder() throws {
        let decoded = try stats("""
        {"success":true,"data":[
          {"gameKey":"fausSwitch","players":[{"userId":"u2","wins":5,"matchesPlayed":9},{"userId":"u1","wins":3,"matchesPlayed":9}]},
          {"gameKey":"houseTanks","players":[{"userId":"u1","wins":1,"matchesPlayed":1},{"userId":"u2","wins":0,"matchesPlayed":0}]}
        ]}
        """)
        XCTAssertEqual(decoded, [
            game("fausSwitch", [("u2", 5, 9), ("u1", 3, 9)]),
            game("houseTanks", [("u1", 1, 1), ("u2", 0, 0)]),
        ])
    }

    func testMalformedGameDoesNotHideTheOthers() throws {
        let decoded = try stats("""
        {"success":true,"data":[
          {"gameKey":"houseRockets"},
          {"gameKey":"houseTanks","players":[{"userId":"u1","wins":"x","matchesPlayed":1}]},
          {"gameKey":"fausSwitch","players":[{"userId":"u1","wins":0,"matchesPlayed":2}]}
        ]}
        """)
        XCTAssertEqual(decoded.map(\.gameKey), ["fausSwitch"])
    }

    func testMissingDataOrFailedEnvelopeIsInvalid() {
        for body in [#"{"success":true,"data":null}"#, #"{"success":true}"#, #"{"success":false,"data":[]}"#,
                     #"{"success":true,"data":{}}"#, "not json"] {
            XCTAssertEqual(failure { _ = try stats(body) }?.kind, .invalidResponse, body)
        }
    }

    func testErrorStatusesMapToKinds() {
        let cases: [(Int, GameStatsFailure.Kind)] = [
            (400, .invalidRequest), (401, .unauthorized), (403, .accessLost), (404, .accessLost),
            (429, .rateLimited), (500, .server), (503, .server),
        ]
        for (status, kind) in cases {
            let body = #"{"success":false,"error":"Yerel mesaj"}"#
            let error = failure { _ = try Contract.decode(response(status, body)) }
            XCTAssertEqual(error, GameStatsFailure(kind: kind, message: "Yerel mesaj"), "\(status)")
        }
    }

    // MARK: - Board

    func testBoardKeepsServerOrderAndMarksTheLeader() {
        let board = GameStatsBoard.make(
            stats: [game("fausSwitch", [("u2", 5, 9), ("u1", 3, 9), ("u3", 0, 0)])],
            memberIDs: ["u1", "u2", "u3"], knownGameKeys: known
        )
        XCTAssertEqual(board.games.map(\.gameKey), ["fausSwitch"])
        XCTAssertEqual(rows(board.games.first), ["u2:5/9*", "u1:3/9", "u3:0/0"])
        XCTAssertFalse(board.games[0].standings[2].hasPlayed)
        XCTAssertNil(board.overall, "a single game has no overall ranking")
    }

    func testDrawsKeepWinsBelowMatchesAndNoWinMeansNoLeader() {
        let board = GameStatsBoard.make(
            stats: [game("houseTanks", [("u1", 0, 3), ("u2", 0, 3)])],
            memberIDs: ["u1", "u2"], knownGameKeys: known
        )
        XCTAssertEqual(rows(board.games.first), ["u1:0/3", "u2:0/3"])
    }

    func testUnknownGamesAndFormerMembersAreSkipped() {
        let board = GameStatsBoard.make(
            stats: [
                game("laterGame", [("u1", 9, 9)]),
                game("houseRockets", [("gone", 4, 4), ("u1", 2, 4)]),
                game("houseTanks", [("gone", 1, 1)]),
            ],
            memberIDs: ["u1"], knownGameKeys: known
        )
        XCTAssertEqual(board.games.map(\.gameKey), ["houseRockets"])
        XCTAssertEqual(rows(board.games.first), ["u1:2/4*"])
        XCTAssertNil(board.overall)
    }

    func testOnlyUnknownGamesMeansAnEmptyBoard() {
        let board = GameStatsBoard.make(stats: [game("laterGame", [("u1", 1, 1)])], memberIDs: ["u1"], knownGameKeys: known)
        XCTAssertTrue(board.isEmpty)
        XCTAssertTrue(GameStatsBoard.make(stats: [], memberIDs: ["u1"], knownGameKeys: known).isEmpty)
    }

    func testRepeatedGameOrPlayerKeepsTheFirst() {
        let board = GameStatsBoard.make(
            stats: [game("fausSwitch", [("u1", 2, 2), ("u1", 9, 9)]), game("fausSwitch", [("u1", 7, 7)])],
            memberIDs: ["u1"], knownGameKeys: known
        )
        XCTAssertEqual(board.games.count, 1)
        XCTAssertEqual(rows(board.games.first), ["u1:2/2*"])
    }

    func testOverallSumsKnownGamesWithTheBackendTieBreak() {
        let board = GameStatsBoard.make(
            stats: [
                game("fausSwitch", [("u1", 5, 9), ("u2", 3, 9), ("u3", 1, 6), ("u4", 0, 0)]),
                game("houseRockets", [("u2", 4, 7), ("u3", 2, 7), ("u1", 1, 5), ("u4", 0, 2)]),
                game("houseTanks", [("u3", 3, 4), ("u1", 1, 4), ("u2", 0, 2), ("u4", 0, 0)]),
                game("laterGame", [("u4", 50, 50)]),
            ],
            memberIDs: ["u2", "u1", "u3", "u4"], knownGameKeys: known
        )
        // u1 and u2 tie on 7 wins and 18 matches; u2 joined first.
        XCTAssertEqual(rows(board.overall), ["u2:7/18*", "u1:7/18", "u3:6/17", "u4:0/2"])
        XCTAssertNil(board.overall?.gameKey)
    }

    func testOverallWithoutAnyWinHasNoLeader() {
        let board = GameStatsBoard.make(
            stats: [game("fausSwitch", [("u1", 0, 1), ("u2", 0, 1)]), game("houseTanks", [("u2", 0, 2), ("u1", 0, 0)])],
            memberIDs: ["u1", "u2"], knownGameKeys: known
        )
        XCTAssertEqual(rows(board.overall), ["u2:0/3", "u1:0/1"])
    }
}
