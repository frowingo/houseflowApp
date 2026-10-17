import Foundation
import XCTest
import HouseFlowCore
@testable import HouseFlow

/// Wire, codec and HTTP-adapter checks against the shared protocol fixture. Lobby,
/// reconnect, flight and result behaviour is covered by HouseFlowCore's engine tests.
@MainActor
final class HouseRocketsWireContractTests: XCTestCase {
    func testAllSharedServerAndHTTPFixturesDecode() async throws {
        let fixture = try LobbyFixture.root()
        XCTAssertEqual(fixture["contractRevision"] as? String, "houseRockets.v2.1")
        XCTAssertEqual(fixture["schemaVersion"] as? Int, 1)
        for item in try XCTUnwrap(fixture["serverMessages"] as? [[String: Any]]) {
            _ = try GameRealtimeCodec.decode(JSONSerialization.data(withJSONObject: try XCTUnwrap(item["message"])))
        }
        let http = try XCTUnwrap(fixture["http"] as? [String: [String: Any]])
        for name in ["ensure", "discover"] {
            if let response = http[name]?["response"] {
                let data = try JSONSerialization.data(withJSONObject: response)
                _ = try GameRealtimeCodec.makeDecoder().decode(GameHTTPEnvelope<GameSessionDTO>.self, from: data)
            }
        }
        if let response = http["result"]?["response"] {
            _ = try GameRealtimeCodec.makeDecoder().decode(GameHTTPEnvelope<HouseRocketsResultDTO>.self,
                                                           from: JSONSerialization.data(withJSONObject: response))
        }
    }

    func testClientFixtureShapesPreserveFalseZeroAndInt64() async throws {
        for item in try XCTUnwrap(LobbyFixture.root()["clientMessages"] as? [[String: Any]]) {
            let expected = try XCTUnwrap(item["message"] as? [String: Any])
            let payload = expected["payload"] as? [String: Any] ?? [:]
            let action: GameRealtimeClientAction
            switch expected["type"] as? String {
            case "gameSession.join": action = .join
            case "gameSession.leave": action = .leave
            case "gameSession.cancel": action = .cancel
            case "houseRockets.resync": action = .resync
            case "gameSession.setReady": action = .setReady(try XCTUnwrap(payload["ready"] as? Bool))
            case "realtime.ping": action = .ping(id: try XCTUnwrap(payload["pingId"] as? String))
            case "houseRockets.steer":
                action = .steer(controlGeneration: try XCTUnwrap(payload["controlGeneration"] as? String),
                    inputSequence: try XCTUnwrap(payload["inputSequence"] as? NSNumber).int64Value,
                    courseHeading: try XCTUnwrap(payload["heading"] as? Double))
            default: XCTFail("Unknown client fixture"); continue
            }
            let data = try GameRealtimeCodec.encode(.init(messageId: try XCTUnwrap(expected["messageId"] as? String), action: action))
            XCTAssertTrue(NSDictionary(dictionary: try LobbyFixture.object(data)).isEqual(to: expected))
        }
        let encoded = try GameRealtimeCodec.encode(.init(messageId: "large", action: .steer(
            controlGeneration: "generation", inputSequence: Int64.max, courseHeading: 0)))
        let body = try XCTUnwrap(LobbyFixture.object(encoded)["payload"] as? [String: Any])
        XCTAssertEqual((body["inputSequence"] as? NSNumber)?.int64Value, Int64.max)
        XCTAssertEqual(body["heading"] as? Double, 0)
    }

    func testRequiredNullablesIntegersAndCompatibility() async throws {
        let missing = try LobbyFixture.server("playing") { message in
            var payload = message["payload"] as! [String: Any]
            payload.removeValue(forKey: "winnerId")
            message["payload"] = payload
        }
        XCTAssertThrowsError(try GameRealtimeCodec.decode(missing))
        let zero = try LobbyFixture.server("accepted") { $0["sequence"] = Int64(0) }
        XCTAssertEqual(try GameRealtimeCodec.decode(zero).sequence, 0)
        let large = try LobbyFixture.server("accepted") { $0["sequence"] = Int64.max }
        XCTAssertEqual(try GameRealtimeCodec.decode(large).sequence, Int64.max)
        for name in ["playing", "cancelledBeforeStartResult"] { _ = try GameRealtimeCodec.decode(LobbyFixture.server(name)) }
        XCTAssertThrowsError(try GameRealtimeCodec.decode(LobbyFixture.server("welcome") { $0["protocolVersion"] = 3 }))
        XCTAssertThrowsError(try GameRealtimeCodec.decode(LobbyFixture.server("playing") { message in
            var value = message["payload"] as! [String: Any]; value["courseVersion"] = 2; message["payload"] = value
        }))
        XCTAssertThrowsError(try GameRealtimeCodec.decode(LobbyFixture.server("accepted") { $0["payload"] = NSNull() }))
    }

    func testHTTPStatusesHeadersAndWebSocketAuthorization() async throws {
        let keychain = LobbyKeychain()
        keychain.authToken = "fixture-token"
        let http = LobbyHTTP()
        let service = GameSessionService(network: http, keychain: keychain, baseURL: LobbyFixture.baseURL)
        for status in [401, 403, 404, 409, 429, 503] {
            http.status = status
            do { _ = try await service.ensureHouseRocketsSession(houseID: LobbyFixture.houseID); XCTFail("Expected HTTP failure") }
            catch let error as NetworkHTTPFailure {
                XCTAssertEqual(error.statusCode, status)
                XCTAssertEqual(error.headers["retry-after"], "3")
                XCTAssertEqual(error.retryAfterSeconds(at: Date()), 3)
            }
        }
        let request = try service.realtimeRequest(sessionID: LobbyFixture.sessionID)
        XCTAssertEqual(request.url?.scheme, "wss")
        XCTAssertEqual(request.url?.path, "/api/v1/game/sessions/\(LobbyFixture.sessionID)/realtime")
        XCTAssertEqual(request.url?.query, "protocolVersion=2")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer fixture-token")
        keychain.authToken = "rotated-token"
        XCTAssertEqual(try service.realtimeRequest(sessionID: LobbyFixture.sessionID).value(forHTTPHeaderField: "Authorization"), "Bearer rotated-token")
    }

    func testNativeSocketCommandsUseTextFrames() async throws {
        for action in [GameRealtimeClientAction.join, .setReady(false), .ping(id: "fixture-ping")] {
            let data = try GameRealtimeCodec.encode(.init(messageId: "fixture-message", action: action))
            switch try GameRealtimeTransport.textMessage(from: data) {
            case .string(let text): XCTAssertEqual(Data(text.utf8), data)
            case .data: XCTFail("The gateway rejects binary client frames")
            @unknown default: XCTFail("Unsupported client frame")
            }
        }
        XCTAssertThrowsError(try GameRealtimeTransport.textMessage(from: Data([0xff])))
    }
}

private enum LobbyFixtureError: Error { case failed }

@MainActor
private enum LobbyFixture {
    static let baseURL = URL(string: "https://example.invalid/api/v1")!
    static let houseID = "507f1f77bcf86cd799439012"
    static let playerID = "507f1f77bcf86cd799439021"
    static let sessionID = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"
    static func root() throws -> [String: Any] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: HouseRocketsWireContractTests.self)
        #endif
        let url = bundle.url(forResource: "houseRocketsProtocol", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "houseRocketsProtocol", withExtension: "json")
        return try object(Data(contentsOf: XCTUnwrap(url)))
    }
    static func object(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
    static func server(_ name: String, mutate: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        let messages = try XCTUnwrap(root()["serverMessages"] as? [[String: Any]])
        var message = try XCTUnwrap(messages.first(where: { $0["name"] as? String == name })?["message"] as? [String: Any])
        mutate(&message)
        return try JSONSerialization.data(withJSONObject: message)
    }
    static func session(version: Int64, playerState: String? = nil, messageID: String? = nil) throws -> Data {
        try server("sessionSnapshot") { message in
            var payload = message["payload"] as! [String: Any]
            payload["state"] = "lobby"; payload["version"] = version
            payload.removeValue(forKey: "countdownEndsAt")
            if let playerState {
                payload["players"] = [["playerId": playerID, "state": playerState, "joinedAt": "2026-10-03T12:00:00Z"]]
            } else { payload["players"] = [] }
            message["payload"] = payload; message["sequence"] = version
            if let messageID { message["messageId"] = messageID }
        }
    }
    static func sessionDTO() throws -> GameSessionDTO {
        guard case .session(let dto) = try GameRealtimeCodec.decode(session(version: 1)).payload else { throw LobbyFixtureError.failed }
        return dto
    }
}

@MainActor
private final class LobbyKeychain: @preconcurrency KeychainStoring {
    var authToken: String?
    var userEmail: String?
    var userFirstName: String?
    var userLastName: String?
    var pendingEmailVerification: String?
}

@MainActor
private final class LobbyHTTP: HTTPRequestExecuting {
    var status = 503
    func execute(_ request: URLRequest) async throws -> NetworkHTTPResponse {
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Retry-After": "3"])!
        return .init(data: Data("{\"success\":false,\"error\":\"localized text\"}".utf8), response: response)
    }
}

