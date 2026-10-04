import Foundation
import XCTest
@testable import HouseFlow

@MainActor
final class HouseRocketsOnlineLobbyTests: XCTestCase {
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
        XCTAssertEqual(request.url?.path, "/api/v1/game/\(LobbyFixture.sessionID)/realtime")
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

    func testJoinWaitsForWelcomeAndSocketSync() async throws {
        let rig = try LobbyRig()
        defer { rig.close() }
        rig.start()
        try await eventually { rig.transport.connectCount == 1 }
        rig.transport.push(try LobbyFixture.server("welcome"))
        await pause()
        XCTAssertEqual(rig.transport.count("gameSession.join"), 0)
        rig.transport.push(try LobbyFixture.session(version: 1))
        try await eventually { rig.transport.count("gameSession.join") == 1 }
        XCTAssertEqual(rig.latest?.participants.count, 0)
        let id = try XCTUnwrap(rig.transport.lastID("gameSession.join"))
        rig.transport.push(try LobbyFixture.server("accepted") { $0["messageId"] = id })
        try await eventually { rig.latest?.pendingCommand?.accepted == true }
        XCTAssertEqual(rig.latest?.participants.count, 0)
        rig.transport.push(try LobbyFixture.session(version: 2, playerState: "waiting"))
        try await eventually { rig.latest?.pendingCommand == nil && rig.latest?.participants.count == 1 }
        XCTAssertEqual(rig.transport.count("gameSession.join"), 1)
    }

    func testSessionBeforeWelcomeDoesNotDuplicateExistingJoin() async throws {
        let rig = try LobbyRig()
        defer { rig.close() }
        rig.start()
        try await eventually { rig.transport.connectCount == 1 }
        rig.transport.push(try LobbyFixture.session(version: 2, playerState: "waiting"))
        await pause()
        XCTAssertEqual(rig.transport.count("gameSession.join"), 0)
        rig.transport.push(try LobbyFixture.server("welcome"))
        try await eventually { rig.latest?.connection == .connected }
        XCTAssertEqual(rig.transport.count("gameSession.join"), 0)
    }

    func testLandscapeAndAuthoritativeReadyConfirmation() async throws {
        let rig = try LobbyRig()
        defer { rig.close() }
        try await rig.connectJoined()
        rig.lobby.setReady(true)
        await pause()
        XCTAssertEqual(rig.transport.count("gameSession.setReady"), 0)
        rig.lobby.setLandscape(true)
        rig.lobby.setReady(true)
        try await eventually { rig.transport.count("gameSession.setReady") == 1 }
        let id = try XCTUnwrap(rig.transport.lastID("gameSession.setReady"))
        rig.transport.push(try LobbyFixture.server("accepted") { $0["messageId"] = id })
        try await eventually { rig.latest?.pendingCommand?.accepted == true }
        XCTAssertEqual(rig.latest?.readyCount, 0)
        rig.transport.push(try LobbyFixture.session(version: 3, playerState: "ready"))
        try await eventually { rig.latest?.readyCount == 1 && rig.latest?.pendingCommand == nil }
        rig.transport.push(try LobbyFixture.server("rejected") { $0["messageId"] = id })
        rig.transport.push(try LobbyFixture.session(version: 2, playerState: "waiting"))
        rig.transport.push(try LobbyFixture.session(version: 3, playerState: "ready"))
        await pause()
        XCTAssertEqual(rig.latest?.readyCount, 1)
        XCTAssertNil(rig.latest?.issue)
        XCTAssertEqual(rig.latest?.session?.version, 3)
    }

    func testReadyRejectionKeepsServerRosterAndRequiresCorrelatedResync() async throws {
        let rig = try LobbyRig()
        defer { rig.close() }
        try await rig.connectJoined()
        rig.lobby.setLandscape(true)
        rig.lobby.setReady(true)
        try await eventually { rig.transport.lastID("gameSession.setReady") != nil }
        let id = try XCTUnwrap(rig.transport.lastID("gameSession.setReady"))
        rig.transport.push(try LobbyFixture.server("rejected") { $0["messageId"] = id })
        try await eventually { rig.transport.lastID("houseRockets.resync") != nil }
        XCTAssertEqual(rig.latest?.readyCount, 0)
        XCTAssertNotNil(rig.latest?.issue)
        XCTAssertEqual(rig.latest?.isSynced, false)
        rig.transport.push(try LobbyFixture.session(version: 2, playerState: "waiting"))
        await pause()
        XCTAssertEqual(rig.latest?.isSynced, false)
        let sync = try XCTUnwrap(rig.transport.lastID("houseRockets.resync"))
        rig.transport.push(try LobbyFixture.session(version: 2, playerState: "waiting", messageID: sync))
        try await eventually { rig.latest?.isSynced == true }
        XCTAssertEqual(rig.latest?.readyCount, 0)
    }

    func testCountdownZeroDoesNotLocallyStartPhysics() async throws {
        let rig = try LobbyRig()
        defer { rig.close() }
        try await rig.connectJoined()
        rig.transport.push(try LobbyFixture.server("countdown"))
        try await eventually { rig.latest?.game?.phase == .countdown }
        let state = try XCTUnwrap(rig.latest)
        let remaining = state.remainingSeconds(until: state.game?.countdownEndsAt, uptime: rig.time + 100)
        XCTAssertEqual(remaining, 0)
        XCTAssertEqual(rig.latest?.game?.phase, .countdown)
        XCTAssertNil(rig.latest?.result)
    }

    func testIndependentGameOrderAndGrantBeforeSnapshot() async throws {
        let rig = try LobbyRig()
        defer { rig.close() }
        try await rig.connectJoined()
        rig.transport.push(try LobbyFixture.server("controlGranted") { message in
            var payload = message["payload"] as! [String: Any]; payload["runtimeEpoch"] = 20
            payload["playerId"] = LobbyFixture.playerID; message["payload"] = payload
        })
        rig.transport.push(try LobbyFixture.server("playing"))
        try await eventually { rig.latest?.game?.stateSequence == 2 && rig.latest?.controlGrant?.runtimeEpoch == 20 }
        XCTAssertEqual(rig.latest?.session?.version, 2)
        rig.transport.push(try LobbyFixture.server("countdown"))
        await pause()
        XCTAssertEqual(rig.latest?.game?.stateSequence, 2)
        XCTAssertEqual(rig.latest?.game?.phase, .playing)
        rig.transport.push(try LobbyFixture.server("recovering"))
        try await eventually { rig.latest?.game?.runtimeEpoch == 8 }
        XCTAssertEqual(rig.latest?.game?.stateSequence, 1)
        XCTAssertEqual(rig.latest?.controlGrant?.runtimeEpoch, 20)
    }

    func testRetryUsesSameLifecycleIdentityAndEventuallyTimesOut() async throws {
        let rig = try LobbyRig()
        defer { rig.close() }
        try await rig.connectJoined()
        rig.lobby.setLandscape(true)
        rig.lobby.setReady(true)
        try await eventually { rig.transport.count("gameSession.setReady") == 1 }
        rig.time += 3.1
        try await eventually { rig.transport.count("gameSession.setReady") == 2 }
        let ids = rig.transport.ids("gameSession.setReady")
        XCTAssertEqual(ids[0], ids[1])
        XCTAssertEqual(rig.latest?.readyCount, 0)
        rig.time += 5.1
        try await eventually { rig.latest?.connection == .failed }
        XCTAssertEqual(rig.latest?.issue, .commandTimeout)
    }

    func testHeartbeatStopsInBackgroundAndResumeRequiresFreshSession() async throws {
        let rig = try LobbyRig()
        defer { rig.close() }
        try await rig.connectJoined()
        try await eventually { rig.transport.count("realtime.ping") > 0 }
        rig.lobby.setForeground(false)
        await pause()
        let count = rig.transport.count("realtime.ping")
        rig.time += 10
        await pause()
        XCTAssertEqual(rig.transport.count("realtime.ping"), count)
        XCTAssertEqual(rig.latest?.connection, .connected)
        rig.lobby.setForeground(true)
        try await eventually { rig.transport.lastID("houseRockets.resync") != nil }
        XCTAssertEqual(rig.latest?.isSynced, false)
        let id = try XCTUnwrap(rig.transport.lastID("houseRockets.resync"))
        rig.transport.push(try LobbyFixture.session(version: 2, playerState: "waiting", messageID: id))
        try await eventually { rig.latest?.isSynced == true }
    }

    func testDisconnectRejectsLateHTTPAndDoesNotOpenSocket() async throws {
        let rig = try LobbyRig()
        defer { rig.close() }
        var pending: CheckedContinuation<GameSessionDTO, Error>?
        rig.sessions.ensureHandler = { try await withCheckedThrowingContinuation { pending = $0 } }
        rig.start()
        try await eventually { pending != nil }
        rig.lobby.disconnect()
        pending?.resume(returning: rig.sessions.initial)
        pending = nil
        await pause()
        XCTAssertEqual(rig.transport.connectCount, 0)
        XCTAssertEqual(rig.latest?.connection, .idle)
    }

    func testExplicitLeaveAndIdempotentCleanup() async throws {
        let rig = try LobbyRig()
        defer { rig.close() }
        try await rig.connectJoined()
        let exit = Task { await rig.lobby.leave() }
        try await eventually { rig.transport.lastID("gameSession.leave") != nil }
        rig.transport.push(try LobbyFixture.session(version: 3, playerState: "left"))
        await exit.value
        XCTAssertEqual(rig.transport.count("gameSession.leave"), 1)
        let count = rig.transport.disconnectCount
        rig.lobby.disconnect()
        XCTAssertEqual(rig.transport.disconnectCount, count)
    }

    func testReadyIsWithdrawnWhenConfirmationArrivesAfterBackground() async throws {
        let rig = try LobbyRig()
        defer { rig.close() }
        try await rig.connectJoined()
        rig.lobby.setLandscape(true)
        rig.lobby.setReady(true)
        try await eventually { rig.transport.count("gameSession.setReady") == 1 }
        rig.lobby.setForeground(false)
        rig.transport.push(try LobbyFixture.session(version: 3, playerState: "ready"))
        try await eventually { rig.transport.count("gameSession.setReady") == 2 }
        let last = try XCTUnwrap(rig.transport.sent.last { $0["type"] as? String == "gameSession.setReady" })
        XCTAssertEqual((last["payload"] as? [String: Any])?["ready"] as? Bool, false)
        rig.transport.push(try LobbyFixture.session(version: 4, playerState: "waiting"))
        try await eventually { rig.latest?.readyCount == 0 && rig.latest?.pendingCommand == nil }
    }

    func testPlayingSnapshotPressureDoesNotDropRejectionOrResult() async throws {
        let rig = try LobbyRig()
        defer { rig.close() }
        try await rig.connectJoined()
        rig.lobby.setLandscape(true)
        rig.lobby.setReady(true)
        try await eventually { rig.transport.lastID("gameSession.setReady") != nil }
        let id = try XCTUnwrap(rig.transport.lastID("gameSession.setReady"))
        for sequence in 3...90 {
            rig.transport.push(try LobbyFixture.server("playing") { message in
                var value = message["payload"] as! [String: Any]; value["stateSequence"] = sequence; message["payload"] = value
            })
        }
        rig.transport.push(try LobbyFixture.server("rejected") { $0["messageId"] = id })
        try await eventually { rig.latest?.issue != nil && rig.latest?.game?.stateSequence == 90 }
        rig.transport.push(try LobbyFixture.server("result"))
        try await eventually { rig.latest?.result != nil }
        XCTAssertTrue(rig.latest?.isTerminal == true)
    }

    func testRetryAfterIsAMinimumAndAuthProtocolFailuresDoNotReconnect() async throws {
        var state = HouseRocketsOnlineLobbyState()
        state.connection = .failed
        state.issue = .connection(.http(statusCode: 503, retryAfterSeconds: 5))
        state.retryNotBefore = 105
        XCTAssertFalse(state.canReconnect(at: 104.99))
        XCTAssertTrue(state.canReconnect(at: 105))
        for status in [401, 403, 409] {
            state.issue = .connection(.http(statusCode: status, retryAfterSeconds: nil))
            XCTAssertFalse(state.canReconnect(at: 110))
        }
        state.issue = .connection(.protocolFailure(.unsupportedProtocol(3)))
        XCTAssertFalse(state.canReconnect(at: 110))
    }

    private func eventually(_ predicate: () -> Bool, file: StaticString = #filePath, line: UInt = #line) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        while !predicate() {
            if ProcessInfo.processInfo.systemUptime >= deadline {
                XCTFail("Condition did not become true", file: file, line: line)
                throw LobbyFixtureError.failed
            }
            try await Task.sleep(for: .milliseconds(2))
        }
    }

    private func pause() async { try? await Task.sleep(for: .milliseconds(20)) }
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
        let bundle = Bundle(for: HouseRocketsOnlineLobbyTests.self)
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

@MainActor
private final class LobbySessions: GameSessionServicing {
    let initial: GameSessionDTO
    var ensureHandler: (() async throws -> GameSessionDTO)?
    init() throws { initial = try LobbyFixture.sessionDTO() }
    func ensureHouseRocketsSession(houseID: String) async throws -> GameSessionDTO { try await ensureHandler?() ?? initial }
    func discoverHouseRocketsSession(houseID: String) async throws -> GameSessionDTO { initial }
    func houseRocketsResult(sessionID: String) async throws -> HouseRocketsResultDTO { throw LobbyFixtureError.failed }
    func realtimeRequest(sessionID: String) throws -> URLRequest {
        try GameEndpointBuilder(baseURL: LobbyFixture.baseURL).realtimeRequest(sessionID: sessionID, token: "fixture-token")
    }
}

@MainActor
private final class LobbyTransport: GameRealtimeTransporting {
    var connectCount = 0
    var disconnectCount = 0
    var sent: [[String: Any]] = []
    var queued: [Data] = []
    var receiving: CheckedContinuation<Data, Error>?
    func connect(request: URLRequest) async throws { connectCount += 1 }
    func send(_ data: Data) async throws {
        let message = try LobbyFixture.object(data)
        sent.append(message)
        if message["type"] as? String == "realtime.ping" {
            let payload = message["payload"] as! [String: Any]
            push(try LobbyFixture.server("pong") { value in
                var pong = value["payload"] as! [String: Any]; pong["pingId"] = payload["pingId"]; value["payload"] = pong
            })
        }
    }
    func receive() async throws -> Data {
        if !queued.isEmpty { return queued.removeFirst() }
        return try await withCheckedThrowingContinuation { receiving = $0 }
    }
    func ping() async throws {}
    func disconnect() {
        disconnectCount += 1
        receiving?.resume(throwing: CancellationError()); receiving = nil
    }
    func push(_ data: Data) {
        if let receiving { self.receiving = nil; receiving.resume(returning: data) }
        else { queued.append(data) }
    }
    func ids(_ type: String) -> [String] { sent.filter { $0["type"] as? String == type }.compactMap { $0["messageId"] as? String } }
    func count(_ type: String) -> Int { ids(type).count }
    func lastID(_ type: String) -> String? { ids(type).last }
}

@MainActor
private final class LobbyRig {
    let sessions: LobbySessions
    let transport = LobbyTransport()
    private(set) var lobby: HouseRocketsOnlineLobby!
    var latest: HouseRocketsOnlineLobbyState?
    var time: TimeInterval = 100
    var observation: Task<Void, Never>?
    init() throws {
        sessions = try LobbySessions()
        let clock = GameRealtimeClock(wallTime: { Date(timeIntervalSince1970: 1_791_028_800) }, uptime: { [weak self] in self?.time ?? 100 },
            sleep: { _ in try await Task.sleep(for: .milliseconds(2)) })
        let session = OnlineHouseRocketsSession(sessions: sessions, transport: transport, clock: clock)
        lobby = HouseRocketsOnlineLobby(session: session, context: .init(houseID: LobbyFixture.houseID, localPlayerID: LobbyFixture.playerID), clock: clock)
        let events = lobby.events()
        observation = Task { [weak self] in
            for await incoming in events { guard !Task.isCancelled, let self else { return }; self.latest = incoming }
        }
    }
    func start() { lobby.start(isForeground: true, isLandscape: false) }
    func connectJoined() async throws {
        start()
        while transport.connectCount == 0 { try await Task.sleep(for: .milliseconds(2)) }
        transport.push(try LobbyFixture.server("welcome"))
        transport.push(try LobbyFixture.session(version: 2, playerState: "waiting"))
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        while latest?.connection != .connected {
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw LobbyFixtureError.failed }
            try await Task.sleep(for: .milliseconds(2))
        }
    }
    func close() { lobby.disconnect(); observation?.cancel() }
}
