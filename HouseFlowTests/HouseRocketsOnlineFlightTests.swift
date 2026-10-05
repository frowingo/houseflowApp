import Foundation
import XCTest
@testable import HouseFlow

@MainActor
final class HouseRocketsOnlineFlightTests: XCTestCase {
    func testTwoFourEightPlayerMappingAndLiteralNames() async throws {
        for count in [2, 4, 8] {
            let snapshot = try FlightFixture.snapshot(players: count)
            let frame = try HouseRocketsRenderMapper.online(snapshot, localPlayerID: FlightFixture.playerID)
            XCTAssertEqual(frame.players.count, count)
            XCTAssertEqual(frame.players.filter { $0.role == .human }.count, 1)
            XCTAssertEqual(frame.players[0].name, .displayName("house_rockets_you"))
            XCTAssertEqual(Set(frame.players.map(\.color)).count, count)
        }
    }

    func testGrantAndSnapshotCanArriveInEitherOrder() async throws {
        for grantFirst in [true, false] {
            let rig = try FlightRig()
            defer { rig.flight.disconnect() }
            if grantFirst {
                rig.state.controlGrant = try FlightFixture.grant()
                try rig.flight.consume(rig.state)
            }
            try rig.feed(grant: grantFirst)
            if !grantFirst {
                XCTAssertFalse(try XCTUnwrap(rig.flight.presentation()).canSteer)
                rig.state.controlGrant = try FlightFixture.grant()
                try rig.flight.consume(rig.state)
            }
            XCTAssertTrue(try XCTUnwrap(rig.flight.presentation()).canSteer)
        }
    }

    func testAllControlGates() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        try rig.feed()
        let valid = rig.state
        let variants: [(inout HouseRocketsOnlineLobbyState) -> Void] = [
            { $0.isForeground = false }, { $0.isLandscape = false }, { $0.isSynced = false },
            { $0.isLeaving = true }, { $0.connection = .failed }, { $0.controlGrant = nil }
        ]
        for mutate in variants {
            var invalid = valid; mutate(&invalid)
            XCTAssertNil(invalid.validControl(playerID: FlightFixture.playerID))
        }
        var invalid = valid
        invalid.controlGrant = try FlightFixture.grant(epoch: 8)
        XCTAssertNil(invalid.validControl(playerID: FlightFixture.playerID))
        invalid = valid; invalid.game = try FlightFixture.snapshot(generation: "other")
        XCTAssertNil(invalid.validControl(playerID: FlightFixture.playerID))
        invalid = valid; invalid.game = try FlightFixture.snapshot(alive: [false, true])
        XCTAssertNil(invalid.validControl(playerID: FlightFixture.playerID))
    }

    func testInterpolationSharesCameraCourseAndFieldTime() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        try rig.feed(elapsed: 24.95, x: 100, camera: 20)
        rig.now = 100.05
        try rig.feed(sequence: 3, elapsed: 25.10, x: 145, camera: 65)
        let frame = try XCTUnwrap(rig.flight.render(at: 100.075)).frame
        XCTAssertEqual(frame.elapsedTime, 25.025, accuracy: 0.000_001)
        XCTAssertEqual(frame.cameraX, 42.5, accuracy: 0.000_001)
        XCTAssertEqual(frame.players[1].worldX, 122.5, accuracy: 0.000_001)
        XCTAssertEqual(frame.courseAngle, (HouseRocketsCourse.angle(at: 24.95) + HouseRocketsCourse.angle(at: 25.10)) / 2, accuracy: 0.000_001)
        let field = HouseRocketsRenderField(id: "field", worldX: 100, effect: .boost, phase: 0.2, period: 3)
        XCTAssertEqual(field.worldY(at: frame.elapsedTime), 180 + sin(frame.elapsedTime * 2 * .pi / 3 + 0.2) * 112)
    }

    func testLatestIntentIsCoalescedAndSentAtMostTwentyHz() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        try rig.feed()
        for value in 0..<100 { rig.flight.steer(screenHeading: Double(value) / 100) }
        rig.flight.tick(at: rig.now)
        await Task.yield()
        XCTAssertEqual(rig.messages.count, 1)
        XCTAssertEqual(try heading(rig.messages[0]), 0.99, accuracy: 0.000_001)
        rig.now += 0.049
        rig.flight.steer(screenHeading: 1.5)
        rig.flight.tick(at: rig.now)
        await Task.yield()
        XCTAssertEqual(rig.messages.count, 1)
        rig.now += 0.002
        rig.flight.tick(at: rig.now)
        await Task.yield()
        XCTAssertEqual(rig.messages.count, 2)
        XCTAssertEqual(try inputSequence(rig.messages[1]), 2)
    }

    func testJoystickConvertsCourseAngleOnceAndPredictionUsesIt() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        try rig.feed(elapsed: 28.1)
        rig.flight.steer(screenHeading: 0)
        XCTAssertEqual(try XCTUnwrap(rig.flight.presentation()).frame.players[0].courseHeading, -.pi / 2, accuracy: 0.000_001)
        rig.flight.tick(at: rig.now)
        await Task.yield()
        XCTAssertEqual(try heading(rig.messages[0]), -.pi / 2, accuracy: 0.000_001)
        let predicted = try XCTUnwrap(rig.flight.render(at: rig.now + 0.1)).frame.players[0]
        XCTAssertEqual(predicted.worldX, 100, accuracy: 0.000_001)
        XCTAssertEqual(predicted.worldY, 150, accuracy: 0.000_001)
    }

    func testACKPrunesInputsAndSteadyDirectionDoesNotKeepSending() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        try rig.feed()
        rig.flight.steer(screenHeading: 0.5)
        rig.flight.tick(at: rig.now)
        await Task.yield()
        rig.now += 0.1
        try rig.feed(sequence: 3, elapsed: 10.1, ack: 1)
        rig.now += 0.21
        try rig.feed(sequence: 4, elapsed: 10.31, ack: 1)
        rig.flight.tick(at: rig.now)
        await Task.yield()
        XCTAssertEqual(rig.messages.count, 1)
        XCTAssertEqual(rig.resyncCount, 0)
    }

    func testUnacknowledgedRetransmitUsesNewSequenceAndMessageID() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        try rig.feed()
        rig.flight.steer(screenHeading: 0.4)
        rig.flight.tick(at: rig.now)
        await Task.yield()
        rig.now += 0.26
        try rig.feed(sequence: 3, elapsed: 10.26)
        rig.flight.tick(at: rig.now)
        await Task.yield()
        XCTAssertEqual(rig.messages.count, 2)
        XCTAssertEqual(try inputSequence(rig.messages[1]), 2)
        XCTAssertNotEqual(rig.messages[0].messageId, rig.messages[1].messageId)
        XCTAssertEqual(try heading(rig.messages[0]), try heading(rig.messages[1]))
    }

    func testEpochAndGenerationDiscardOldIntentsAndRejections() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        try rig.feed()
        rig.flight.steer(screenHeading: 0.5)
        rig.flight.tick(at: rig.now)
        await Task.yield()
        let oldID = rig.messages[0].messageId
        rig.now += 0.06
        try rig.feed(sequence: 3, epoch: 8, generation: "new-control")
        rig.flight.tick(at: rig.now)
        await Task.yield()
        XCTAssertEqual(rig.messages.count, 1)
        rig.flight.steer(screenHeading: 0.2)
        rig.flight.tick(at: rig.now)
        await Task.yield()
        XCTAssertEqual(try inputSequence(rig.messages[1]), 1)
        rig.flight.reject(messageID: oldID, rejection: .init(code: "houseRockets.error.stale_control", args: [], retryable: false))
        XCTAssertEqual(rig.resyncCount, 0)
        XCTAssertTrue(try XCTUnwrap(rig.flight.presentation()).canSteer)
    }

    func testSnapshotLossFreezesExtrapolationAndRequestsBoundedResync() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        try rig.feed(grant: false)
        let first = try XCTUnwrap(rig.flight.render(at: rig.now + 0.3))
        let later = try XCTUnwrap(rig.flight.render(at: rig.now + 3))
        XCTAssertEqual(first.frame, later.frame)
        XCTAssertTrue(first.isSyncing)
        rig.flight.tick(at: rig.now + 0.3)
        rig.flight.tick(at: rig.now + 0.4)
        XCTAssertEqual(rig.resyncCount, 1)
    }

    func testPredictionDoesNotEliminateOrAdvanceAuthoritativeCamera() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        try rig.feed(x: 100, camera: 1_000)
        let frame = try XCTUnwrap(rig.flight.render(at: rig.now + 0.1)).frame
        XCTAssertTrue(frame.players.allSatisfy(\.isAlive))
        XCTAssertEqual(frame.cameraX, 1_000)
    }

    func testSimultaneousEliminationsSurviveTerminalPhaseAndDoNotReplay() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        try rig.feed()
        rig.now += 0.05
        try rig.feed(sequence: 3, elapsed: 10.05, alive: [false, false], phase: "finalizing")
        XCTAssertEqual(rig.eliminations.count, 2)
        XCTAssertEqual(try XCTUnwrap(rig.flight.presentation()).eliminations.count, 2)
        try rig.flight.consume(rig.state)
        XCTAssertEqual(rig.eliminations.count, 2)
        try rig.feed(sequence: 1, epoch: 8, elapsed: 10.05, alive: [false, false], phase: "finalizing")
        XCTAssertEqual(rig.eliminations.count, 2)
    }

    func testPredictionUsesConfirmedSpeedEffectsAndExactContacts() async throws {
        var player = try HouseRocketsRenderMapper.online(FlightFixture.snapshot(), localPlayerID: FlightFixture.playerID).players[0]
        player.worldX = 0; player.worldY = 50
        player.speedEffect = .boost; player.effectRemaining = 1
        let boosted = HouseRocketsFlightMath.advance(player, from: 0, to: 0.1, gates: [])
        XCTAssertEqual(boosted.worldX, 43.5, accuracy: 0.000_001)
        player.speedEffect = .slow
        XCTAssertEqual(HouseRocketsFlightMath.advance(player, from: 0, to: 0.1, gates: []).worldX, 19.5, accuracy: 0.000_001)
        player.speedEffect = nil; player.effectRemaining = 0
        let gate = HouseRocketsRenderGate(id: "gate", worldX: 50, sections: [
            .init(offsetX: -10, lowerY: 100, upperY: 260), .init(offsetX: 10, lowerY: 100, upperY: 260)
        ])
        let blocked = HouseRocketsFlightMath.advance(player, from: 0, to: 0.2, gates: [gate])
        XCTAssertLessThanOrEqual(blocked.worldX, 30.000_001)
        XCTAssertTrue(blocked.isAlive)
    }

    func testFiniteValidationAndSequenceOverflowAreBounded() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        try rig.feed(ack: Int64.max)
        rig.flight.steer(screenHeading: .nan)
        rig.flight.tick(at: rig.now)
        XCTAssertEqual(rig.messages.count, 0)
        rig.flight.steer(screenHeading: 0.3)
        rig.flight.tick(at: rig.now)
        await Task.yield()
        XCTAssertEqual(rig.messages.count, 0)
        XCTAssertEqual(rig.resyncCount, 1)
    }

    func testInputBufferCapacityForcesResyncWithoutGrowing() async throws {
        var config = HouseRocketsFlightConfiguration(); config.inputCapacity = 2
        let rig = try FlightRig(configuration: config)
        defer { rig.flight.disconnect() }
        try rig.feed()
        rig.flight.steer(screenHeading: 0.2)
        rig.flight.tick(at: rig.now)
        await Task.yield()
        for index in 1...2 {
            rig.now += 0.26
            try rig.feed(sequence: Int64(index + 2), elapsed: 10 + Double(index) * 0.26)
            rig.flight.tick(at: rig.now)
            await Task.yield()
        }
        XCTAssertEqual(rig.messages.count, 2)
        XCTAssertEqual(rig.resyncCount, 1)
    }

    func testMissingGrantEventuallyResyncsWhileSnapshotsContinue() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        try rig.feed(grant: false)
        rig.now += 0.6
        try rig.feed(sequence: 3, elapsed: 10.6, grant: false)
        rig.flight.tick(at: rig.now)
        XCTAssertEqual(rig.resyncCount, 1)
    }

    func testBackgroundAndFreshSyncDoNotReplayPreviousTouch() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        try rig.feed()
        rig.flight.steer(screenHeading: 0.4)
        rig.state.isForeground = false
        try rig.flight.consume(rig.state)
        rig.state.isForeground = true; rig.state.isSynced = false
        try rig.flight.consume(rig.state)
        rig.state.isSynced = true
        try rig.flight.consume(rig.state)
        rig.flight.tick(at: rig.now)
        await Task.yield()
        XCTAssertEqual(rig.messages.count, 0)
    }

    func testEliminatedLocalPlayerCanSpectateFourPlayerFlight() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        try rig.feed(players: 4)
        rig.now += 0.05
        try rig.feed(sequence: 3, elapsed: 10.05, alive: [false, true], players: 4)
        let presentation = try XCTUnwrap(rig.flight.presentation())
        XCTAssertFalse(presentation.canSteer)
        XCTAssertEqual(presentation.frame.players.filter(\.isAlive).count, 3)
        XCTAssertEqual(presentation.eliminations.count, 1)
        rig.flight.steer(screenHeading: 0.2)
        rig.flight.tick(at: rig.now)
        await Task.yield()
        XCTAssertEqual(rig.messages.count, 0)
    }

    func testSnapshotBufferKeepsOnlyRecentFrames() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        for index in 0..<20 {
            rig.now = 100 + Double(index) * 0.05
            try rig.feed(sequence: Int64(index + 2), elapsed: 10 + Double(index) * 0.05, grant: false)
        }
        let frame = try XCTUnwrap(rig.flight.render(at: 100)).frame
        XCTAssertGreaterThanOrEqual(frame.elapsedTime, 10.6)
    }

    func testOldBlockedWriteCompletesWithoutBlockingNewGeneration() async throws {
        let rig = try FlightRig()
        defer { rig.flight.disconnect() }
        var continuation: CheckedContinuation<Void, Never>?
        rig.sendHandler = { _ in await withCheckedContinuation { continuation = $0 } }
        try rig.feed()
        rig.flight.steer(screenHeading: 0.3)
        rig.flight.tick(at: rig.now)
        await Task.yield()
        XCTAssertNotNil(continuation)
        rig.now += 0.06
        try rig.feed(sequence: 3, epoch: 8, generation: "new")
        rig.flight.steer(screenHeading: 0.4)
        rig.flight.tick(at: rig.now)
        XCTAssertEqual(rig.messages.count, 1)
        rig.sendHandler = nil
        continuation?.resume(); continuation = nil
        await Task.yield()
        rig.flight.tick(at: rig.now)
        await Task.yield()
        XCTAssertEqual(rig.messages.count, 2)
        XCTAssertEqual(try inputSequence(rig.messages[1]), 1)
    }

    private func heading(_ message: GameRealtimeClientMessage) throws -> Double {
        guard case .steer(_, _, let value) = message.action else { throw FlightTestError.failed }
        return value
    }
    private func inputSequence(_ message: GameRealtimeClientMessage) throws -> Int64 {
        guard case .steer(_, let sequence, _) = message.action else { throw FlightTestError.failed }
        return sequence
    }
}

private enum FlightTestError: Error { case failed }

@MainActor
private enum FlightFixture {
    static let playerID = "507f1f77bcf86cd799439021"
    static func payload(_ name: String) throws -> [String: Any] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: HouseRocketsOnlineFlightTests.self)
        #endif
        let url = bundle.url(forResource: "houseRocketsProtocol", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "houseRocketsProtocol", withExtension: "json")
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: XCTUnwrap(url))) as? [String: Any])
        let entries = try XCTUnwrap(root["serverMessages"] as? [[String: Any]])
        let message = try XCTUnwrap(entries.first(where: { $0["name"] as? String == name })?["message"] as? [String: Any])
        return try XCTUnwrap(message["payload"] as? [String: Any])
    }
    static func decode<T: Decodable>(_ object: [String: Any], as type: T.Type) throws -> T {
        try GameRealtimeCodec.makeDecoder().decode(type, from: JSONSerialization.data(withJSONObject: object))
    }
    static func grant(epoch: Int64 = 7, generation: String = "fixture-control") throws -> HouseRocketsControlGrantDTO {
        var p = try payload("controlGranted")
        p["runtimeEpoch"] = epoch; p["playerId"] = playerID; p["controlGeneration"] = generation
        return try decode(p, as: HouseRocketsControlGrantDTO.self)
    }
    static func snapshot(sequence: Int64 = 2, epoch: Int64 = 7, elapsed: Double = 10, x: Double = 100,
                         camera: Double = 20, ack: Int64 = 0, generation: String = "fixture-control",
                         alive: [Bool] = [true, true], phase: String = "playing", players count: Int = 2) throws -> HouseRocketsSnapshotDTO {
        var p = try payload("playing")
        let originals = p["players"] as! [[String: Any]]
        p["runtimeEpoch"] = epoch; p["stateSequence"] = sequence; p["tick"] = Int64((elapsed * 120).rounded())
        p["elapsedSeconds"] = elapsed; p["cameraX"] = camera; p["courseAngle"] = HouseRocketsCourse.angle(at: elapsed)
        p["phase"] = phase; p["gates"] = []; p["speedFields"] = []
        p["players"] = (0..<count).map { index -> [String: Any] in
            var player = originals[index % originals.count]
            player["playerId"] = index == 0 ? playerID : "remote-\(index)"
            player["displayName"] = index == 0 ? "house_rockets_you" : "Player \(index)"
            player["color"] = HouseRocketsColor.allCases[index].rawValue
            player["worldX"] = x; player["worldY"] = 180.0; player["courseHeading"] = 0.0
            player["isAlive"] = index < alive.count ? alive[index] : true
            player["connected"] = true
            player["speedEffect"] = NSNull(); player["effectRemainingSeconds"] = 0.0
            player["controlGeneration"] = index == 0 ? generation as Any : NSNull()
            player["lastProcessedInputSequence"] = index == 0 ? ack : 0
            player["eliminatedAtTick"] = (player["isAlive"] as? Bool == false) ? p["tick"] : NSNull()
            return player
        }
        return try decode(p, as: HouseRocketsSnapshotDTO.self)
    }
}

@MainActor
private final class FlightRig {
    var now: TimeInterval = 100
    var state = HouseRocketsOnlineLobbyState()
    var messages: [GameRealtimeClientMessage] = []
    var resyncCount = 0
    var sendHandler: ((GameRealtimeClientMessage) async -> Void)?
    var eliminations: [HouseRocketsOnlineElimination] = []
    var flight: HouseRocketsOnlineFlight!
    init(configuration: HouseRocketsFlightConfiguration? = nil) throws {
        var session = try FlightFixture.payload("sessionSnapshot"); session["state"] = "running"
        state.session = try FlightFixture.decode(session, as: GameSessionDTO.self)
        state.connection = .connected; state.isSynced = true; state.isLandscape = true
        state.runtimeSettings = try FlightFixture.decode(FlightFixture.payload("welcome")["settings"] as! [String: Any], as: HouseRocketsRuntimeSettingsDTO.self)
        let clock = GameRealtimeClock(wallTime: { Date() }, uptime: { [weak self] in self?.now ?? 100 })
        flight = HouseRocketsOnlineFlight(localPlayerID: FlightFixture.playerID, clock: clock, configuration: configuration,
            send: { [weak self] message, _ in
                self?.messages.append(message)
                await self?.sendHandler?(message)
            },
            resync: { [weak self] in self?.resyncCount += 1 })
        flight.onEliminations = { [weak self] in self?.eliminations.append(contentsOf: $0) }
    }
    func feed(sequence: Int64 = 2, epoch: Int64 = 7, elapsed: Double = 10, x: Double = 100, camera: Double = 20,
              ack: Int64 = 0, generation: String = "fixture-control", alive: [Bool] = [true, true],
              phase: String = "playing", grant: Bool = true, players: Int = 2) throws {
        state.game = try FlightFixture.snapshot(sequence: sequence, epoch: epoch, elapsed: elapsed, x: x, camera: camera,
            ack: ack, generation: generation, alive: alive, phase: phase, players: players)
        state.gameReceivedUptime = now
        if grant { state.controlGrant = try FlightFixture.grant(epoch: epoch, generation: generation) }
        try flight.consume(state)
    }
}
