import Foundation
import FausCrewCore
import XCTest

final class GameWireContractTests: XCTestCase {
    func testReleaseOneRoutesUseSessionNamespace() {
        XCTAssertEqual(GameRoute.catalog(houseId: "h1").path, "game/catalog")
        XCTAssertEqual(GameRoute.catalog(houseId: "h1").queryItems, [HTTPQueryItem(name: "houseId", value: "h1")])
        XCTAssertEqual(GameRoute.ensureSession(gameKey: GameKey.houseRockets).method, "PUT")
        XCTAssertEqual(GameRoute.ensureSession(gameKey: GameKey.houseRockets).path, "game/houseRockets/session")
        XCTAssertEqual(GameRoute.discoverSession(gameKey: GameKey.houseRockets, houseId: "h1").queryItems,
                       [HTTPQueryItem(name: "houseId", value: "h1")])
        XCTAssertEqual(GameRoute.result(sessionId: "s1").path, "game/sessions/s1/result")
        XCTAssertEqual(GameRoute.realtime(sessionId: "s1").path, "game/sessions/s1/realtime")
        XCTAssertEqual(GameRoute.realtime(sessionId: "s1").queryItems,
                       [HTTPQueryItem(name: "protocolVersion", value: "2")])
        XCTAssertTrue(GameRoute.realtime(sessionId: "s1").isRealtime)
        XCTAssertFalse(GameRoute.result(sessionId: "s1").isRealtime)
    }

    func testIdentifierValidationRejectsPathInjection() {
        for value in ["", " s1", "s1 ", ".", "..", "a/b", "a?b", "a#b", "a\\b", String(repeating: "x", count: 129)] {
            XCTAssertThrowsError(try GameWireContract.validateIdentifier(value), value)
        }
        XCTAssertNoThrow(try GameWireContract.validateIdentifier("6a11-house"))
    }

    func testCatalogDecodesHouseRocketsSettingsAndSkipsUnknownShapes() throws {
        let body = """
        {"success": true, "data": [
          {"gameKey": "houseRockets", "protocolVersion": 2, "mode": "realtime", "configVersion": 1,
           "rules": {"minimumPlayers": 2, "maximumPlayers": 8, "readyWindowMilliseconds": 30000, "countdownMilliseconds": 3000},
           "settings": {"physicsRateHz": 120, "schedulingRateHz": 60, "snapshotRateHz": 20, "maximumInputRateHz": 20,
             "maximumSteerMessagesPerSecond": 30, "controlHeartbeatMilliseconds": 2000, "controlTimeoutMilliseconds": 6000,
             "reconnectGraceMilliseconds": 10000, "maximumMatchMilliseconds": 300000}},
          {"gameKey": "ticTacToe", "protocolVersion": 2, "mode": "turn", "configVersion": 3,
           "rules": {"minimumPlayers": 2, "maximumPlayers": 2, "readyWindowMilliseconds": 30000, "countdownMilliseconds": 0},
           "settings": {"turnTimeoutMilliseconds": 30000}},
          {"gameKey": "broken"}
        ]}
        """
        let catalog = try GameWireContract.decodeCatalog(
            houseId: "h1", response: HTTPResponse(statusCode: 200, headers: [:], body: Data(body.utf8))
        )

        XCTAssertEqual(catalog.entries.map(\.gameKey), ["houseRockets", "ticTacToe"])
        let rockets = try XCTUnwrap(catalog.houseRockets)
        XCTAssertEqual(rockets.rules.maximumPlayers, 8)
        XCTAssertEqual(rockets.houseRocketsSettings, .releaseDefaults)
        XCTAssertNil(catalog.entry(for: "ticTacToe")?.houseRocketsSettings)
    }

    func testCatalogWithoutHouseRocketsMeansGameIsClosedForTheHouse() throws {
        let response = HTTPResponse(statusCode: 200, headers: [:], body: Data(#"{"success": true, "data": []}"#.utf8))
        XCTAssertNil(try GameWireContract.decodeCatalog(houseId: "h1", response: response).houseRockets)
    }

    func testCatalogIgnoresHouseRocketsWithUnsupportedProtocol() throws {
        let body = """
        {"success": true, "data": [{"gameKey": "houseRockets", "protocolVersion": 3, "mode": "realtime",
          "rules": {"minimumPlayers": 2, "maximumPlayers": 8, "readyWindowMilliseconds": 30000, "countdownMilliseconds": 3000}}]}
        """
        let response = HTTPResponse(statusCode: 200, headers: [:], body: Data(body.utf8))
        XCTAssertNil(try GameWireContract.decodeCatalog(houseId: "h1", response: response).houseRockets)
    }

    func testCatalogForbiddenSurfacesStatus() {
        let response = HTTPResponse(statusCode: 403, headers: [:], body: Data(#"{"code": "house.error.user_not_member"}"#.utf8))
        XCTAssertThrowsError(try GameWireContract.decodeCatalog(houseId: "h1", response: response)) { error in
            XCTAssertEqual(error as? GameHTTPError, GameHTTPError(statusCode: 403, code: "house.error.user_not_member"))
        }
    }

    func testErrorCodeIsReadFromEveryEnvelopeShape() {
        let bodies = [
            #"{"code": "game.error.unavailable", "message": "Oyun kapalı"}"#,
            #"{"errorCode": "game.error.unavailable"}"#,
            #"{"success": false, "error": {"code": "game.error.unavailable", "message": "Closed"}}"#,
            #"{"success": false, "error": "game.error.unavailable"}"#,
            #"{"message": "game.error.unavailable"}"#,
        ]
        for body in bodies {
            let error = GameHTTPError(statusCode: 409, body: Data(body.utf8))
            XCTAssertEqual(error.code, GameErrorCode.unavailable, body)
            XCTAssertTrue(error.isGameUnavailable, body)
        }
    }

    func testFreeTextAndOtherConflictsAreNotGameUnavailable() {
        XCTAssertNil(GameHTTPError(statusCode: 409, body: Data(#"{"error": "Ready window closed."}"#.utf8)).code)
        XCTAssertNil(GameHTTPError(statusCode: 409, body: Data("conflict".utf8)).code)
        XCTAssertFalse(GameHTTPError(statusCode: 409, code: "game.error.ready_closed").isGameUnavailable)
        XCTAssertFalse(GameHTTPError(statusCode: 400, code: GameErrorCode.unavailable).isGameUnavailable)
        XCTAssertEqual(GameHTTPError(statusCode: 409, body: Data(#"{"code": "game.error.not_your_turn"}"#.utf8)).code,
                       GameErrorCode.notYourTurn)
    }

    func testEnsureSessionBody() throws {
        let body = try GameWireContract.ensureSessionBody(houseId: "h1")
        XCTAssertEqual(try JSONSerialization.jsonObject(with: body) as? [String: String], ["houseId": "h1"])
        XCTAssertThrowsError(try GameWireContract.ensureSessionBody(houseId: "a/b"))
    }

    func testRuntimeSettingsDriveSteerRateAndValidation() {
        let settings = HouseRocketsRuntimeSettingsDTO.releaseDefaults
        XCTAssertTrue(settings.isUsable)
        XCTAssertEqual(settings.heartbeatInterval, 2)
        XCTAssertEqual(settings.heartbeatTimeout, 6)
        XCTAssertEqual(settings.reconnectGrace, 10)
        XCTAssertEqual(settings.steerRate(preferredHz: 20), 20)
        XCTAssertEqual(settings.steerRate(preferredHz: 60), 20)
        XCTAssertEqual(settings.steerRate(preferredHz: 0), 1)

        let raised = HouseRocketsRuntimeSettingsDTO(
            physicsRateHz: 120, schedulingRateHz: 60, snapshotRateHz: 30, maximumInputRateHz: 40,
            maximumSteerMessagesPerSecond: 25, controlHeartbeatMilliseconds: 1_000,
            controlTimeoutMilliseconds: 4_000, reconnectGraceMilliseconds: 5_000, maximumMatchMilliseconds: 300_000
        )
        XCTAssertEqual(raised.steerRate(preferredHz: 60), 25)

        let storm = HouseRocketsRuntimeSettingsDTO(
            physicsRateHz: 120, schedulingRateHz: 60, snapshotRateHz: 20, maximumInputRateHz: 20,
            maximumSteerMessagesPerSecond: 30, controlHeartbeatMilliseconds: 100,
            controlTimeoutMilliseconds: 6_000, reconnectGraceMilliseconds: 10_000, maximumMatchMilliseconds: 300_000
        )
        XCTAssertFalse(storm.isUsable)
    }
}
