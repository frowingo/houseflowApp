import Foundation
import HouseFlowCore
import XCTest
@testable import HouseFlow

/// Backend Release 1 (v38): catalog, `/game/sessions/{id}/…` routes and the
/// 409 `game.error.unavailable` conflict, as consumed by the iOS adapter.
@MainActor
final class GameReleaseOneContractTests: XCTestCase {
    private let baseURL = URL(string: "https://example.test/api/v1")!

    func testSessionScopedRoutesAndCatalogRequest() async throws {
        let (service, http) = makeService()
        http.respond(200, #"{"success": true, "data": []}"#)
        let catalog = try await service.gameCatalog(houseID: "house-1")
        XCTAssertNil(catalog.houseRockets)
        XCTAssertEqual(http.requests.last?.url?.path, "/api/v1/game/catalog")
        XCTAssertEqual(http.requests.last?.url?.query, "houseId=house-1")
        XCTAssertEqual(http.requests.last?.httpMethod, "GET")
        XCTAssertEqual(http.requests.last?.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-token")

        http.respond(503, "{}")
        _ = try? await service.houseRocketsResult(sessionID: "session-1")
        XCTAssertEqual(http.requests.last?.url?.path, "/api/v1/game/sessions/session-1/result")

        let socket = try service.realtimeRequest(sessionID: "session-1")
        XCTAssertEqual(socket.url?.absoluteString,
                       "wss://example.test/api/v1/game/sessions/session-1/realtime?protocolVersion=2")

        http.respond(503, "{}")
        _ = try? await service.ensureHouseRocketsSession(houseID: "house-1")
        XCTAssertEqual(http.requests.last?.httpMethod, "PUT")
        XCTAssertEqual(http.requests.last?.url?.path, "/api/v1/game/houseRockets/session")
        XCTAssertEqual(try JSONSerialization.jsonObject(with: XCTUnwrap(http.requests.last?.httpBody)) as? [String: String],
                       ["houseId": "house-1"])
    }

    func testCatalogListsHouseRocketsWithServerLimits() async throws {
        let (service, http) = makeService()
        http.respond(200, """
        {"success": true, "data": [{"gameKey": "houseRockets", "protocolVersion": 2, "mode": "realtime", "configVersion": 1,
          "rules": {"minimumPlayers": 2, "maximumPlayers": 6, "readyWindowMilliseconds": 30000, "countdownMilliseconds": 3000},
          "settings": {"physicsRateHz": 120, "schedulingRateHz": 60, "snapshotRateHz": 20, "maximumInputRateHz": 20,
            "maximumSteerMessagesPerSecond": 30, "controlHeartbeatMilliseconds": 2000, "controlTimeoutMilliseconds": 6000,
            "reconnectGraceMilliseconds": 10000, "maximumMatchMilliseconds": 300000}}]}
        """)
        let catalog = try await service.gameCatalog(houseID: "house-1")
        let entry = try XCTUnwrap(catalog.houseRockets)
        XCTAssertEqual(entry.rules.maximumPlayers, 6)
        XCTAssertEqual(entry.houseRocketsSettings, .releaseDefaults)
    }

    func testClosedGameConflictIsTerminalAndDistinctFromOtherConflicts() async throws {
        let (service, http) = makeService()
        http.respond(409, #"{"success": false, "code": "game.error.unavailable", "message": "Bu oyun şu anda kapalı."}"#)
        do {
            _ = try await service.ensureHouseRocketsSession(houseID: "house-1")
            XCTFail("Expected game unavailable")
        } catch {
            XCTAssertEqual(error as? GameRealtimeError, .gameUnavailable)
        }

        http.respond(409, #"{"success": false, "error": "Ready window closed."}"#)
        do {
            _ = try await service.ensureHouseRocketsSession(houseID: "house-1")
            XCTFail("Expected HTTP conflict")
        } catch {
            XCTAssertEqual((error as? NetworkHTTPFailure)?.statusCode, 409)
        }

        var state = HouseRocketsOnlineLobbyState()
        state.connection = .failed
        state.issue = .connection(.protocolFailure(.gameUnavailable))
        XCTAssertFalse(state.canReconnect(at: .infinity))
        XCTAssertFalse(HouseRocketsReconnectPolicy.automaticallyRetries(.connection(.protocolFailure(.gameUnavailable))))
    }

    func testCatalogAvailabilityGatesHousematesMode() async throws {
        var catalog = GameCatalog(houseId: "house-1", entries: [])
        var loads = 0
        let factory = HouseRocketsSessionFactory(
            makeBotSession: { DemoHouseRocketsSession() },
            makeOnlineSession: { preconditionFailure("Gate checks must not construct a session") },
            loadCatalog: { _ in loads += 1; return catalog }
        )
        let model = HouseRocketsViewModel(sessionFactory: factory,
                                          context: .init(houseID: "house-1", localPlayerID: "user-1"))
        XCTAssertNil(model.onlineBlocker, "An unknown catalog must not block; the server still guards the session")

        await model.refreshCatalog()
        XCTAssertEqual(model.catalogAvailability, .unavailable)
        XCTAssertEqual(model.onlineBlocker, .gameUnavailable)

        catalog = GameCatalog(houseId: "house-1", entries: [GameCatalogEntryDTO(
            gameKey: GameKey.houseRockets, protocolVersion: 2, mode: "realtime", configVersion: 1,
            rules: GameRulesDTO(minimumPlayers: 2, maximumPlayers: 8, readyWindowMilliseconds: 30_000,
                                countdownMilliseconds: 3_000),
            houseRocketsSettings: .releaseDefaults)])
        await model.refreshCatalog()
        XCTAssertEqual(model.catalogAvailability, .available(maximumPlayers: 8))
        XCTAssertNil(model.onlineBlocker)

        model.updateContext(.init(houseID: "house-2", localPlayerID: "user-1"))
        XCTAssertEqual(model.catalogAvailability, .unknown)
        XCTAssertEqual(loads, 2)
        model.stop()
    }

    private func makeService() -> (GameSessionService, RecordingGameHTTP) {
        let keychain = FakeKeychainStore()
        keychain.authToken = "fixture-token"
        let http = RecordingGameHTTP()
        return (GameSessionService(network: http, keychain: keychain, baseURL: baseURL), http)
    }
}

@MainActor
private final class RecordingGameHTTP: HTTPRequestExecuting {
    private var status = 200
    private var body = Data()
    private(set) var requests: [URLRequest] = []

    func respond(_ status: Int, _ body: String) {
        self.status = status
        self.body = Data(body.utf8)
    }

    func execute(_ request: URLRequest) async throws -> NetworkHTTPResponse {
        requests.append(request)
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: [:])!
        return .init(data: body, response: response)
    }
}
