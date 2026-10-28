import Foundation
import FausCrewCore
import XCTest

/// The FauseTanks wire layer against the backend's protocol fixture (contract
/// houseTanks.v2): every server example decodes and re-encodes to the same JSON,
/// every client example is produced exactly, and no invalid example can be.
final class HouseTanksWireContractTests: XCTestCase {
    func testFixtureRulesMatchTheClient() throws {
        let fixture = try Self.fixture()
        XCTAssertEqual(fixture["contractRevision"] as? String, HouseTanksMapCatalog.contractRevision)
        XCTAssertEqual(fixture["mapCatalogVersion"] as? Int, HouseTanksMapCatalog.catalogVersion)
        XCTAssertEqual(fixture["protocolVersion"] as? Int, GameRoute.realtimeProtocolVersion)
        XCTAssertEqual(fixture["playerColors"] as? [String], HouseTanksColor.allCases.map(\.rawValue))
        XCTAssertEqual(fixture["powerUps"] as? [String], HouseTanksPowerUp.allCases.map(\.rawValue))
        XCTAssertEqual(fixture["mapIds"] as? [String], HouseTanksMapCatalog.maps.map(\.id.rawValue))

        let rules = try XCTUnwrap(fixture["rules"] as? [String: Any])
        XCTAssertEqual(rules["minimumPlayers"] as? Int, HouseTanksMapCatalog.minimumPlayers)
        XCTAssertEqual(rules["maximumPlayers"] as? Int, HouseTanksMapCatalog.maximumPlayers)
        XCTAssertEqual(rules["physicsRateHz"] as? Int, HouseTanksWorld.physicsRate)
        XCTAssertEqual(rules["arenaWidth"] as? Double, HouseTanksWorld.arenaSize.width)
        XCTAssertEqual(rules["arenaHeight"] as? Double, HouseTanksWorld.arenaSize.height)
        XCTAssertEqual(rules["armorPerRound"] as? Int, HouseTanksWorld.armorPerRound)
        XCTAssertEqual(rules["roundWinsNeeded"] as? Int, HouseTanksMatchRules.roundWinsNeeded)

        let welcome = try XCTUnwrap(try Self.decode("welcome").payload.welcome)
        XCTAssertEqual(welcome.settings, .releaseDefaults, "The client defaults are the contract defaults")
        XCTAssertTrue(welcome.settings.isUsable)
        XCTAssertEqual(welcome.settings.pressRate(preferredHz: 60), 20)
    }

    func testEveryServerExampleRoundTrips() throws {
        let messages = try XCTUnwrap(Self.fixture()["serverMessages"] as? [[String: Any]])
        XCTAssertEqual(messages.count, 14)
        let encoder = GameRealtimeCodec.makeEncoder()
        for example in messages {
            let name = try XCTUnwrap(example["name"] as? String)
            let json = try XCTUnwrap(example["message"] as? [String: Any])
            let message = try Self.decode(name)
            XCTAssertEqual(message.messageId, json["messageId"] as? String, name)
            XCTAssertEqual(message.sequence, (json["sequence"] as? NSNumber)?.int64Value, name)
            XCTAssertEqual(message.sentAt, try Self.date(json["sentAt"]), name)

            let encoded: Data
            let expected: Any?
            switch message.payload {
            case .welcome(let value): encoded = try encoder.encode(value); expected = json["payload"]
            case .pong(let value): encoded = try encoder.encode(value); expected = json["payload"]
            case .accepted: encoded = try encoder.encode(GameRealtimeEmptyPayload()); expected = json["payload"]
            case .session(let value): XCTFail("No session example: \(value)"); continue
            case .controlGranted(let value): encoded = try encoder.encode(value); expected = json["payload"]
            case .snapshot(let value): encoded = try encoder.encode(value); expected = json["payload"]
            case .result(let value): encoded = try encoder.encode(value); expected = json["payload"]
            case .rejected(let value): encoded = try encoder.encode(value); expected = json["error"]
            }
            try Self.assertSameJSON(try JSONSerialization.jsonObject(with: encoded), try XCTUnwrap(expected), name)
        }
    }

    func testSnapshotsKeepNullAndAbsentFieldsApart() throws {
        let preview = try XCTUnwrap(try Self.decode("countdown").payload.snapshot)
        XCTAssertNil(preview.roundPhase, "The lobby preview has no round yet")
        XCTAssertEqual(preview.roundNumber, 0)
        XCTAssertTrue(preview.isBeforeStart)
        XCTAssertEqual(preview.map?.id, .livingRoom)

        let playing = try XCTUnwrap(try Self.decode("roundPlaying").payload.snapshot)
        XCTAssertEqual(playing.phase, .playing)
        XCTAssertEqual(playing.roundPhase, .roundPlaying)
        XCTAssertFalse(playing.isBeforeStart)
        XCTAssertEqual(playing.token?.kind, .shield)
        let hit = try XCTUnwrap(playing.events.first { $0.kind == .hit })
        XCTAssertNil(hit.lethal, "lethal is written only when true")
        let local = try XCTUnwrap(playing.controlSeat(of: "507f1f77bcf86cd799439021"))
        XCTAssertEqual(local, .init(controlGeneration: "controlA", canHoldControl: true, connected: true))

        let ready = try XCTUnwrap(try Self.decode("roundReady").payload.snapshot)
        let dead = try XCTUnwrap(ready.players.first { !$0.isAlive && $0.connected })
        XCTAssertEqual(ready.controlSeat(of: dead.playerId)?.canHoldControl, true, "A dead tank still votes")
        let ended = try XCTUnwrap(ready.events.last)
        XCTAssertEqual(ended.kind, .roundEnded)
        XCTAssertEqual(ended.winnerId, ready.roundWinnerId)

        let gone = try XCTUnwrap(try Self.decode("ended").payload.snapshot)
        XCTAssertEqual(gone.championId, "507f1f77bcf86cd799439021")
        XCTAssertEqual(gone.controlSeat(of: "507f1f77bcf86cd799439023")?.canHoldControl, false, "A player who left never holds control")
    }

    func testClientProducesEveryExampleExactly() throws {
        let examples = try XCTUnwrap(Self.fixture()["clientMessages"] as? [[String: Any]])
        let actions: [String: HouseTanksClientMessage] = [
            "join": .init(messageId: "join1", action: .join),
            "ready": .init(messageId: "ready1", action: .setReady(true)),
            "notReady": .init(messageId: "notReady1", action: .setReady(false)),
            "leave": .init(messageId: "leave1", action: .leave),
            "cancel": .init(messageId: "cancel1", action: .cancel),
            "press": .init(messageId: "press1", action: .gameplay(.press(
                controlGeneration: "controlA", inputSequence: 42, pressed: true, clientTick: 1_180, heading: 0))),
            "release": .init(messageId: "release1", action: .gameplay(.press(
                controlGeneration: "controlA", inputSequence: 43, pressed: false, clientTick: 1_192, heading: 0.42))),
            "roundReady": .init(messageId: "roundReady1", action: .gameplay(.roundReady(controlGeneration: "controlA", ready: true))),
            "roundNotReady": .init(messageId: "roundNotReady1", action: .gameplay(.roundReady(controlGeneration: "controlA", ready: false))),
            "resync": .init(messageId: "resync1", action: .resync),
            "ping": .init(messageId: "ping1", action: .ping(id: "clock1")),
        ]
        XCTAssertEqual(Set(examples.compactMap { $0["name"] as? String }), Set(actions.keys))
        for example in examples {
            let name = try XCTUnwrap(example["name"] as? String)
            let encoded = try GameRealtimeCodec.encode(try XCTUnwrap(actions[name]))
            try Self.assertSameJSON(try JSONSerialization.jsonObject(with: encoded), try XCTUnwrap(example["message"]), name)
        }
    }

    func testNoInvalidExampleCanBeProduced() throws {
        let invalid = try XCTUnwrap(Self.fixture()["invalidClientMessages"] as? [[String: Any]])
        XCTAssertEqual(invalid.count, 25)

        // Values the server rejects are refused before they are encoded.
        let refused: [HouseTanksClientMessage] = [
            press(sequence: 0), press(sequence: -1), press(clientTick: -1),
            press(heading: .infinity), press(heading: -.infinity), press(heading: .nan),
            press(generation: ""), press(generation: " controlA"), press(generation: String(repeating: "g", count: 129)),
            .init(messageId: "roundReady1", action: .gameplay(.roundReady(controlGeneration: "", ready: true))),
            .init(messageId: " ", action: .gameplay(.roundReady(controlGeneration: "controlA", ready: true))),
            .init(messageId: "", action: .join),
        ]
        for message in refused {
            XCTAssertThrowsError(try GameRealtimeCodec.encode(message), "\(message)")
        }

        // Everything else the client writes has the exact fixture schema: the four
        // envelope keys, protocol 2, a FauseTanks or shared type and its payload keys.
        let schemas: [String: Set<String>] = [
            "gameSession.join": [], "gameSession.leave": [], "gameSession.cancel": [], "houseTanks.resync": [],
            "gameSession.setReady": ["ready"], "realtime.ping": ["pingId"], "houseTanks.roundReady": ["controlGeneration", "ready"],
            "houseTanks.press": ["controlGeneration", "inputSequence", "pressed", "clientTick", "heading"],
        ]
        var produced: [[String: Any]] = []
        for sequence in [1, 2, 42, Int64.max] as [Int64] {
            for tick in [0, 1_180, Int64.max] as [Int64] {
                for heading in [0, 0.42, -.pi, 12 * .pi, 1e308] as [Double] {
                    produced.append(try Self.object(press(sequence: sequence, clientTick: tick, heading: heading, pressed: sequence.isMultiple(of: 2))))
                }
            }
        }
        for action in [HouseTanksClientMessage.init(messageId: "a", action: .join), .init(messageId: "a", action: .leave),
                       .init(messageId: "a", action: .cancel), .init(messageId: "a", action: .resync),
                       .init(messageId: "a", action: .setReady(true)), .init(messageId: "a", action: .ping(id: "p")),
                       .init(messageId: "a", action: .gameplay(.roundReady(controlGeneration: "controlA", ready: false)))] {
            produced.append(try Self.object(action))
        }
        for message in produced {
            XCTAssertEqual(Set(message.keys), ["protocolVersion", "messageId", "type", "payload"])
            XCTAssertEqual(message["protocolVersion"] as? Int, 2)
            let type = try XCTUnwrap(message["type"] as? String)
            let payload = try XCTUnwrap(message["payload"] as? [String: Any])
            XCTAssertEqual(Set(payload.keys), try XCTUnwrap(schemas[type], type), type)
            if type == "houseTanks.press" {
                XCTAssertTrue(Self.isInteger(payload["inputSequence"]) && Self.isInteger(payload["clientTick"]))
                XCTAssertTrue(Self.isBool(payload["pressed"]))
                XCTAssertTrue((payload["heading"] as? Double)?.isFinite ?? false)
            }
        }
        for example in invalid {
            let name = try XCTUnwrap(example["name"] as? String)
            let text = try XCTUnwrap(example["json"] as? String)
            guard let object = try? JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any] else { continue }
            XCTAssertFalse(produced.contains { NSDictionary(dictionary: $0).isEqual(to: object) }, name)
            let type = object["type"] as? String ?? ""
            let payload = object["payload"] as? [String: Any] ?? [:]
            let matchesSchema = Set(object.keys) == ["protocolVersion", "messageId", "type", "payload"]
                && object["protocolVersion"] as? Int == 2 && (object["messageId"] as? String)?.trimmingCharacters(in: .whitespaces).isEmpty == false
                && schemas[type] == Set(payload.keys) && payload.values.allSatisfy { !($0 is NSNull) }
                && (type != "houseTanks.press" || (Self.isInteger(payload["inputSequence"]) && Self.isInteger(payload["clientTick"])
                    && Self.isBool(payload["pressed"]) && (payload["inputSequence"] as? Int64 ?? 0) > 0
                    && (payload["clientTick"] as? Int64 ?? -1) >= 0 && (payload["heading"] as? Double)?.isFinite == true
                    && (payload["controlGeneration"] as? String)?.isEmpty == false))
            XCTAssertFalse(matchesSchema, "\(name) fits the schema the client writes")
        }
    }

    func testIncompatibleContractsAskForAnUpdate() throws {
        func error(_ name: String, _ change: (inout [String: Any]) -> Void) -> GameRealtimeError? {
            do { _ = try Self.decode(name, change); return nil } catch { return error as? GameRealtimeError }
        }
        XCTAssertEqual(error("welcome") { $0["contractRevision"] = "houseTanks.v3" }, .unsupportedContract("houseTanks.v3"))
        XCTAssertEqual(error("welcome") { $0["mapCatalogVersion"] = 3 }, .unsupportedContract("houseTanks.v2"))
        XCTAssertEqual(error("welcome") { $0["protocolVersion"] = 3 }, .unsupportedProtocol(3))
        XCTAssertEqual(error("welcome") { $0["gameKey"] = "houseRockets" }, .invalidResponse)
        for (key, value) in [("arenaWidth", 1_180), ("arenaHeight", 640), ("physicsRateHz", 60),
                             ("armorPerRound", 3), ("roundWinsNeeded", 5)] {
            XCTAssertEqual(error("welcome") { payload in
                var settings = payload["settings"] as! [String: Any]
                settings[key] = value
                payload["settings"] = settings
            }, .unsupportedContract("houseTanks.v2"), key)
        }
        XCTAssertEqual(error("roundPlaying") { $0["mapVersion"] = 4 }, .unsupportedMap("livingRoom", 4))
        XCTAssertEqual(error("roundPlaying") { $0["mapId"] = "attic" }, .unsupportedMap("attic", 3))
        XCTAssertEqual(error("roundPlaying") { $0["gameKey"] = "houseRockets" }, .invalidResponse)
        XCTAssertEqual(error("result") { $0["protocolVersion"] = 1 }, .unsupportedProtocol(1))
        XCTAssertNil(error("roundPlaying") { $0["seed"] = "0000000000000000" }, "The seed is information only")

        var state = HouseTanksOnlineLobbyState()
        state.issue = .connection(.protocolFailure(.unsupportedMap("attic", 3)))
        XCTAssertTrue(state.requiresUpdate)
        state.issue = .connection(.protocolFailure(.gameUnavailable))
        XCTAssertFalse(state.requiresUpdate)
    }

    func testResultsFollowTheChampionRules() throws {
        let houseID = "507f1f77bcf86cd799439012", sessionID = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"
        for name in ["result", "insufficientPlayersResult", "cancelledBeforeStartResult"] {
            let result = try XCTUnwrap(try Self.decode(name).payload.result, name)
            XCTAssertNoThrow(try result.validate(sessionID: sessionID, houseID: houseID), name)
        }
        let result = try XCTUnwrap(try Self.decode("result").payload.result)
        XCTAssertEqual(result.players.map(\.finalRank), [1, 2, 2], "Ties share a rank")
        XCTAssertThrowsError(try result.validate(sessionID: "other", houseID: houseID))

        func rejects(_ name: String, _ change: (inout [String: Any]) -> Void, file: StaticString = #filePath, line: UInt = #line) throws {
            let changed = try XCTUnwrap(try Self.decode(name, change).payload.result, file: file, line: line)
            XCTAssertThrowsError(try changed.validate(sessionID: sessionID, houseID: houseID), file: file, line: line)
        }
        try rejects("result") { $0["championId"] = "507f1f77bcf86cd799439022" }
        try rejects("result") { $0["championId"] = NSNull() }
        try rejects("result") { $0["endReason"] = "sessionExpired" }
        try rejects("result") { $0["roundsPlayed"] = 4 }
        try rejects("result") { payload in
            var players = payload["players"] as! [[String: Any]]
            players[2]["finalRank"] = 3
            payload["players"] = players
        }
        try rejects("result") { $0["mapVersion"] = NSNull() }
        try rejects("insufficientPlayersResult") { $0["championId"] = "507f1f77bcf86cd799439021" }
        try rejects("insufficientPlayersResult") { payload in
            var players = payload["players"] as! [[String: Any]]
            players[0]["finalRank"] = 1
            payload["players"] = players
        }
        try rejects("cancelledBeforeStartResult") { $0["durationSeconds"] = 5 }
    }

    func testCatalogOffersFauseTanksWithItsSettings() throws {
        let welcome = try XCTUnwrap(try Self.fixture()["serverMessages"] as? [[String: Any]])
            .first { $0["name"] as? String == "welcome" }
        let settings = try XCTUnwrap(((welcome?["message"] as? [String: Any])?["payload"] as? [String: Any])?["settings"])
        let entry: [String: Any] = [
            "gameKey": "houseTanks", "protocolVersion": 2, "mode": "realtime", "configVersion": 1,
            "rules": ["minimumPlayers": 2, "maximumPlayers": 8, "readyWindowMilliseconds": 30_000, "countdownMilliseconds": 3_000],
            "settings": settings,
        ]
        let body = try JSONSerialization.data(withJSONObject: ["success": true, "data": [entry]])
        let catalog = try GameWireContract.decodeCatalog(houseId: "house", response: .init(statusCode: 200, headers: [:], body: body))
        XCTAssertEqual(catalog.houseTanks?.houseTanksSettings, .releaseDefaults)
        XCTAssertNil(catalog.houseRockets)

        var bare = entry
        bare["settings"] = NSNull()
        let bareBody = try JSONSerialization.data(withJSONObject: ["success": true, "data": [bare]])
        XCTAssertNil(try GameWireContract.decodeCatalog(houseId: "house", response: .init(statusCode: 200, headers: [:], body: bareBody)).houseTanks)
        XCTAssertEqual(GameRoute.ensureSession(gameKey: GameKey.houseTanks).path, "game/houseTanks/session")
    }

    // MARK: Helpers

    private func press(sequence: Int64 = 42, clientTick: Int64 = 1_180, heading: Double = 0, pressed: Bool = true,
                       generation: String = "controlA") -> HouseTanksClientMessage {
        .init(messageId: "press1", action: .gameplay(.press(controlGeneration: generation, inputSequence: sequence,
                                                            pressed: pressed, clientTick: clientTick, heading: heading)))
    }

    static func fixture() throws -> [String: Any] {
        let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Fixtures/houseTanksProtocol.json")
        return try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
    }

    /// A fixture server message, with its payload changed by `change`.
    static func data(_ name: String, _ change: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        let messages = try XCTUnwrap(fixture()["serverMessages"] as? [[String: Any]])
        var message = try XCTUnwrap(messages.first { $0["name"] as? String == name }?["message"] as? [String: Any], name)
        if var payload = message["payload"] as? [String: Any] {
            change(&payload)
            message["payload"] = payload
        }
        return try JSONSerialization.data(withJSONObject: message)
    }

    static func decode(_ name: String, _ change: (inout [String: Any]) -> Void = { _ in }) throws -> HouseTanksServerMessage {
        try GameRealtimeCodec.decode(try data(name, change), as: HouseTanksRealtime.self)
    }

    private static func object(_ message: HouseTanksClientMessage) throws -> [String: Any] {
        try XCTUnwrap(try JSONSerialization.jsonObject(with: GameRealtimeCodec.encode(message)) as? [String: Any])
    }

    private static func date(_ value: Any?) throws -> Date {
        let text = try XCTUnwrap(value as? String)
        return try GameRealtimeCodec.makeDecoder().decode(Date.self, from: Data("\"\(text)\"".utf8))
    }

    private static func isBool(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber else { return false }
        return CFGetTypeID(number) == CFBooleanGetTypeID()
    }

    private static func isInteger(_ value: Any?) -> Bool {
        guard let number = value as? NSNumber, !isBool(number) else { return false }
        return number.doubleValue.rounded() == number.doubleValue && !"\(number)".contains(".")
    }

    /// Same keys (null kept apart from absent), same booleans, numbers equal as
    /// doubles and timestamps equal as instants.
    private static func assertSameJSON(_ actual: Any, _ expected: Any, _ path: String,
                                       file: StaticString = #filePath, line: UInt = #line) throws {
        switch (actual, expected) {
        case (let actual as [String: Any], let expected as [String: Any]):
            XCTAssertEqual(Set(actual.keys), Set(expected.keys), path, file: file, line: line)
            for (key, value) in expected {
                guard let other = actual[key] else { continue }
                try assertSameJSON(other, value, "\(path).\(key)", file: file, line: line)
            }
        case (let actual as [Any], let expected as [Any]):
            XCTAssertEqual(actual.count, expected.count, path, file: file, line: line)
            for (index, pair) in zip(actual, expected).enumerated() {
                try assertSameJSON(pair.0, pair.1, "\(path)[\(index)]", file: file, line: line)
            }
        case (is NSNull, is NSNull):
            break
        case (let actual as NSNumber, let expected as NSNumber):
            XCTAssertEqual(isBool(actual), isBool(expected), path, file: file, line: line)
            XCTAssertEqual(actual.doubleValue, expected.doubleValue, path, file: file, line: line)
        case (let actual as String, let expected as String):
            if actual != expected, let left = try? date(actual), let right = try? date(expected) {
                XCTAssertEqual(left.timeIntervalSince1970, right.timeIntervalSince1970, accuracy: 1e-6, path, file: file, line: line)
            } else {
                XCTAssertEqual(actual, expected, path, file: file, line: line)
            }
        default:
            XCTFail("\(path): \(actual) is not \(expected)", file: file, line: line)
        }
    }
}

extension GameRealtimeServerPayloadOf {
    var welcome: Game.Welcome? { if case .welcome(let value) = self { return value }; return nil }
    var snapshot: Game.Snapshot? { if case .snapshot(let value) = self { return value }; return nil }
    var result: Game.Result? { if case .result(let value) = self { return value }; return nil }
}
