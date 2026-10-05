import Foundation
import XCTest
@testable import HouseFlow

@MainActor
final class HouseRocketsReconnectTests: XCTestCase {
    func testRetryClassificationAndMinimumJitterDelay() throws {
        let policy = HouseRocketsReconnectPolicy(jitter: { 0.8 })
        XCTAssertEqual(policy.delay(attempt: 1, minimum: 0), 0.4)
        XCTAssertEqual(policy.delay(attempt: 5, minimum: 9), 9)
        for status in [408, 429, 500, 502, 503, 504] {
            XCTAssertTrue(HouseRocketsReconnectPolicy.automaticallyRetries(.connection(.http(statusCode: status, retryAfterSeconds: 1))))
        }
        for status in [401, 403, 404, 409, 422] {
            XCTAssertFalse(HouseRocketsReconnectPolicy.automaticallyRetries(.connection(.http(statusCode: status, retryAfterSeconds: nil))))
        }
        for error in [GameRealtimeError.authenticationRequired, .unsupportedProtocol(3), .unsupportedCourse(2), .invalidResponse, .accessRevoked] {
            XCTAssertFalse(HouseRocketsReconnectPolicy.automaticallyRetries(.connection(.protocolFailure(error))))
        }
    }

    func testShortDropKeepsFramePinsSessionAndDoesNotReplayInputsOrJoin() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        rig.flight.steer(screenHeading: 0.5); rig.flight.tick(at: rig.now)
        try await eventually { rig.transport.count("houseRockets.steer") == 1 }
        let oldGeneration = try XCTUnwrap(rig.latest.controlGrant?.controlGeneration)
        let oldFrame = try XCTUnwrap(rig.flight.presentation()?.frame)
        rig.transport.drop()
        try await eventually { rig.latest.connection == .reconnecting }
        XCTAssertEqual(rig.flight.presentation()?.frame.sessionID, oldFrame.sessionID)
        XCTAssertEqual(rig.flight.presentation()?.frame.cameraX, oldFrame.cameraX)
        XCTAssertEqual(rig.flight.presentation()?.frame.players.map(\.worldX), oldFrame.players.map(\.worldX))
        XCTAssertFalse(rig.flight.presentation()?.canSteer == true)
        XCTAssertNil(rig.latest.controlGrant)
        rig.advanceToRetry()
        try await eventually { rig.transport.connects == 2 && rig.latest.connection == .connected }
        XCTAssertEqual(rig.sessions.ensures, 1)
        XCTAssertEqual(rig.sessions.requestedIDs, [ReconnectFixture.sessionID, ReconnectFixture.sessionID])
        XCTAssertEqual(rig.transport.count("gameSession.join"), 0)
        rig.flight.tick(at: rig.now); await settle()
        XCTAssertEqual(rig.transport.count("houseRockets.steer"), 1)
        XCTAssertNotEqual(rig.latest.controlGrant?.controlGeneration, oldGeneration)
        rig.flight.steer(screenHeading: 0.2); rig.flight.tick(at: rig.now + 0.06)
        try await eventually { rig.transport.count("houseRockets.steer") == 2 }
        XCTAssertEqual(rig.transport.lastPayload("houseRockets.steer")?["inputSequence"] as? Int, 1)
        XCTAssertEqual(rig.notices, 0)
    }

    func test503UpgradePinsIDAndHonorsRetryAfterWithCurrentToken() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        rig.transport.connectFailures[1] = ReconnectFixture.http(503, retry: "3")
        rig.lobby.start(isForeground: true, isLandscape: true)
        try await eventually { rig.latest.connection == .reconnecting }
        XCTAssertEqual(rig.latest.session?.sessionId, ReconnectFixture.sessionID)
        XCTAssertEqual(rig.latest.retryNotBefore, 103)
        rig.sessions.token = "rotated-fixture-token"
        rig.now = 102.99; await pause()
        XCTAssertEqual(rig.transport.connects, 1)
        rig.now = 103.01
        try await eventually { rig.transport.connects == 2 && rig.latest.connection == .connected }
        XCTAssertEqual(rig.sessions.ensures, 1)
        XCTAssertEqual(rig.transport.authorizations.last, "Bearer rotated-fixture-token")
    }

    func testRepeated503HasFiveAutomaticAttemptsAndStops() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        for attempt in 1...8 { rig.transport.connectFailures[attempt] = ReconnectFixture.http(503) }
        rig.lobby.start(isForeground: true, isLandscape: true)
        try await eventually { rig.latest.reconnectAttempt == 1 }
        for attempt in 1...5 {
            rig.advanceToRetry()
            try await eventually { rig.transport.connects == attempt + 1 }
            if attempt < 5 { try await eventually { rig.latest.reconnectAttempt == attempt + 1 } }
        }
        try await eventually { rig.latest.connection == .failed }
        rig.now += 100; await pause()
        XCTAssertEqual(rig.transport.connects, 6)
        XCTAssertEqual(rig.sessions.ensures, 1)
        XCTAssertNil(rig.latest.result)
    }

    func testAuthForbiddenAndTerminalUpgradeDoNotRetry() async throws {
        for status in [401, 403, 409] {
            let rig = try ReconnectRig()
            rig.transport.connectFailures[1] = ReconnectFixture.http(status)
            rig.lobby.start(isForeground: true, isLandscape: true)
            try await eventually { rig.latest.connection == .failed }
            rig.now += 30; await pause()
            XCTAssertEqual(rig.transport.connects, 1)
            XCTAssertEqual(rig.latest.requiresAuthentication, status == 401)
            XCTAssertEqual(rig.latest.terminalConflict, status == 409)
            XCTAssertFalse(rig.latest.canReconnect(at: rig.now))
            rig.close()
        }
    }

    func testMissingTokenOnReconnectUsesAuthFailureWithoutLoop() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        rig.sessions.token = nil
        rig.transport.drop()
        try await eventually { rig.latest.connection == .reconnecting }
        rig.advanceToRetry()
        try await eventually { rig.latest.requiresAuthentication }
        XCTAssertEqual(rig.transport.connects, 1)
        rig.now += 30; await pause()
        XCTAssertEqual(rig.transport.connects, 1)
    }

    func testBackgroundStopsSteeringHeartbeatAndScheduledReconnect() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        rig.flight.steer(screenHeading: 0.3)
        rig.lobby.setForeground(false)
        let pings = rig.transport.count("realtime.ping")
        rig.now += 1
        rig.flight.tick(at: rig.now); await pause()
        XCTAssertEqual(rig.transport.count("houseRockets.steer"), 0)
        XCTAssertEqual(rig.transport.count("realtime.ping"), pings)
        XCTAssertEqual(rig.latest.game?.phase, .playing)
        rig.transport.drop()
        try await eventually { rig.latest.connection == .reconnecting }
        rig.now += 20; await pause()
        XCTAssertEqual(rig.transport.connects, 1)
        rig.lobby.setForeground(true)
        rig.advanceToRetry()
        try await eventually { rig.transport.connects == 2 && rig.latest.isSynced }
        XCTAssertEqual(rig.sessions.ensures, 1)
    }

    func testForegroundRequiresCorrelatedGameAndSessionBeforeControl() async throws {
        for gameFirst in [false, true] {
            let generation = gameFirst ? "generation-1" : "fresh-grant"
            let rig = try ReconnectRig()
            try await rig.start()
            rig.lobby.setForeground(false); rig.lobby.setForeground(true)
            try await eventually { rig.transport.lastID("houseRockets.resync") != nil }
            let nonce = try XCTUnwrap(rig.transport.lastID("houseRockets.resync"))
            XCTAssertFalse(rig.latest.isSynced)
            rig.transport.push(try ReconnectFixture.grant(generation: generation))
            rig.transport.push(try ReconnectFixture.game(sequence: 21, generation: generation))
            await pause()
            XCTAssertFalse(rig.latest.isSynced) // Periodic motion alone is not foreground sync.
            if gameFirst {
                rig.transport.push(try ReconnectFixture.game(sequence: 21, generation: generation, messageID: nonce))
            } else {
                rig.transport.push(try ReconnectFixture.session(messageID: nonce))
            }
            await pause()
            XCTAssertFalse(rig.latest.isSynced)
            XCTAssertFalse(rig.flight.presentation()?.canSteer == true)
            if gameFirst { rig.transport.push(try ReconnectFixture.session(messageID: nonce)) }
            else { rig.transport.push(try ReconnectFixture.game(sequence: 21, generation: generation, messageID: nonce)) }
            try await eventually { rig.latest.isSynced }
            XCTAssertTrue(rig.flight.presentation()?.canSteer == true)
            rig.flight.tick(at: rig.now); await settle()
            XCTAssertEqual(rig.transport.count("houseRockets.steer"), 0)
            rig.close()
        }
    }

    func testTargetedPlayingSyncIsCriticalUnderSnapshotPressure() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        rig.lobby.setForeground(false); rig.lobby.setForeground(true)
        try await eventually { rig.transport.lastID("houseRockets.resync") != nil }
        let nonce = try XCTUnwrap(rig.transport.lastID("houseRockets.resync"))
        rig.transport.push(try ReconnectFixture.session(messageID: nonce))
        rig.transport.push(try ReconnectFixture.game(sequence: 21, generation: "generation-1", messageID: nonce))
        for sequence in 22...200 { rig.transport.push(try ReconnectFixture.game(sequence: Int64(sequence), generation: "generation-1")) }
        try await eventually { rig.latest.isSynced && (rig.latest.game?.stateSequence ?? 0) > 21 }
    }

    func testHigherEpochDirectPlayingDiscardsOldInputAndLowerEpoch() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        rig.flight.steer(screenHeading: 0.4)
        rig.transport.push(try ReconnectFixture.grant(epoch: 8, generation: "recovered"))
        rig.transport.push(try ReconnectFixture.game(sequence: 1, epoch: 8, generation: "recovered", alive: false))
        try await eventually { rig.latest.game?.runtimeEpoch == 8 }
        XCTAssertFalse(rig.flight.presentation()?.canSteer == true)
        XCTAssertEqual(rig.notices, 0)
        rig.transport.push(try ReconnectFixture.game(sequence: 999, epoch: 7, generation: "generation-1"))
        await pause()
        XCTAssertEqual(rig.latest.game?.runtimeEpoch, 8)
        XCTAssertEqual(rig.latest.game?.players.first?.isAlive, false)
        rig.flight.tick(at: rig.now); await settle()
        XCTAssertEqual(rig.transport.count("houseRockets.steer"), 0)
    }

    func testRecoveryAndNewGrantArrivalOrderGateSteering() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        rig.transport.push(try ReconnectFixture.game(sequence: 1, epoch: 8, generation: nil, phase: "recovering"))
        try await eventually { rig.latest.game?.phase == .recovering }
        XCTAssertTrue(rig.flight.presentation()?.isSyncing == true)
        XCTAssertFalse(rig.flight.presentation()?.canSteer == true)
        rig.transport.push(try ReconnectFixture.game(sequence: 2, epoch: 8, generation: "recovered"))
        try await eventually { rig.latest.game?.phase == .playing }
        XCTAssertFalse(rig.flight.presentation()?.canSteer == true)
        rig.transport.push(try ReconnectFixture.grant(epoch: 8, generation: "recovered"))
        try await eventually { rig.flight.presentation()?.canSteer == true }
        rig.flight.steer(screenHeading: 0.1); rig.flight.tick(at: rig.now)
        try await eventually { rig.transport.count("houseRockets.steer") == 1 }
        XCTAssertEqual(rig.transport.lastPayload("houseRockets.steer")?["inputSequence"] as? Int, 1)
    }

    func testEliminatedPlayerReconnectsAsSpectatorWithoutHistoricalHaptic() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        rig.alive = false
        rig.transport.drop()
        try await eventually { rig.latest.connection == .reconnecting }
        rig.advanceToRetry()
        try await eventually { rig.latest.connection == .connected && rig.transport.connects == 2 }
        XCTAssertFalse(rig.latest.game?.players.first?.isAlive == true)
        XCTAssertNil(rig.latest.validControl(playerID: ReconnectFixture.playerID))
        XCTAssertFalse(rig.flight.presentation()?.canSteer == true)
        XCTAssertEqual(rig.notices, 0)
        rig.flight.steer(screenHeading: 1); rig.flight.tick(at: rig.now)
        await settle()
        XCTAssertEqual(rig.transport.count("houseRockets.steer"), 0)
        XCTAssertEqual(rig.transport.count("gameSession.join"), 0)
    }

    func testControlTransferStopsResyncRaceUntilExplicitReclaim() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        rig.transport.push(try ReconnectFixture.game(sequence: 21, generation: nil))
        try await eventually { rig.latest.controlTransferred }
        rig.now += 3
        rig.flight.tick(at: rig.now); rig.lobby.resyncGameplay(); await pause()
        XCTAssertEqual(rig.transport.count("houseRockets.resync"), 0)
        XCTAssertFalse(rig.flight.presentation()?.canSteer == true)
        rig.lobby.reclaimControl()
        try await eventually { rig.transport.count("houseRockets.resync") == 1 }
        let nonce = try XCTUnwrap(rig.transport.lastID("houseRockets.resync"))
        rig.transport.push(try ReconnectFixture.session(messageID: nonce))
        rig.transport.push(try ReconnectFixture.grant(generation: "reclaimed"))
        rig.transport.push(try ReconnectFixture.game(sequence: 22, generation: "reclaimed", messageID: nonce))
        try await eventually { rig.latest.isSynced }
        XCTAssertFalse(rig.latest.controlTransferred)
        XCTAssertTrue(rig.flight.presentation()?.canSteer == true)
    }

    func testMatchedStaleControlStopsRebindAndAutomaticReconnect() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        rig.flight.steer(screenHeading: 0.1); rig.flight.tick(at: rig.now)
        try await eventually { rig.transport.lastID("houseRockets.steer") != nil }
        rig.transport.push(try ReconnectFixture.rejection(code: "houseRockets.error.stale_control", id: rig.transport.lastID("houseRockets.steer")))
        try await eventually { rig.latest.controlTransferred }
        rig.transport.drop()
        try await eventually { rig.latest.connection == .failed }
        rig.now += 5; rig.flight.tick(at: rig.now); await pause()
        XCTAssertEqual(rig.transport.connects, 1)
        XCTAssertEqual(rig.transport.count("houseRockets.resync"), 0)
        rig.lobby.retry()
        try await eventually { rig.transport.connects == 2 && rig.latest.connection == .connected }
        XCTAssertFalse(rig.latest.controlTransferred)
    }

    func testLeaveDuringReconnectCancelsRetryAndNeverCreatesAnotherSession() async throws {
        let rig = try ReconnectRig()
        try await rig.start()
        rig.transport.drop()
        try await eventually { rig.latest.connection == .reconnecting }
        await rig.lobby.leave()
        rig.now += 20; await pause()
        XCTAssertEqual(rig.transport.connects, 1)
        XCTAssertEqual(rig.transport.count("gameSession.leave"), 0) // Unreachable exit relies on server grace.
        XCTAssertEqual(rig.sessions.ensures, 1)
        let disconnects = rig.transport.disconnects
        rig.close(); rig.close()
        XCTAssertEqual(rig.transport.disconnects, disconnects)
    }

    func testExplicitLeaveWhileSyncingStillSendsBusinessCommand() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        rig.lobby.setForeground(false); rig.lobby.setForeground(true)
        try await eventually { rig.latest.connection == .syncing }
        let leaving = Task { await rig.lobby.leave() }
        try await eventually { rig.transport.count("gameSession.leave") == 1 }
        rig.transport.push(try ReconnectFixture.session(version: 11, playerState: "left"))
        await leaving.value
        XCTAssertEqual(rig.latest.connection, .idle)
    }

    func testLogoutOrHouseChangeCleanupRejectsLateHTTPAndOldEvents() async throws {
        let old = try ReconnectRig()
        var pending: CheckedContinuation<GameSessionDTO, Error>?
        old.sessions.ensureHandler = { try await withCheckedThrowingContinuation { pending = $0 } }
        old.lobby.start(isForeground: true, isLandscape: true)
        try await eventually { pending != nil }
        old.close()
        let fresh = try ReconnectRig(houseID: "new-house", playerID: "new-user")
        defer { fresh.close() }
        try await fresh.start()
        pending?.resume(returning: old.sessions.initial); pending = nil
        old.transport.push(try ReconnectFixture.game(sequence: 999, generation: "obsolete"))
        await pause()
        XCTAssertEqual(old.transport.connects, 0)
        XCTAssertEqual(fresh.latest.session?.houseId, "new-house")
        XCTAssertEqual(fresh.latest.controlGrant?.playerId, "new-user")
        XCTAssertEqual(fresh.transport.connects, 1)
    }

    func testCleanupDuringLateReconnectCannotPublishIntoFreshContext() async throws {
        let rig = try ReconnectRig()
        try await rig.start()
        var connect: CheckedContinuation<Void, Error>?
        rig.transport.connectHandler = { index in
            if index == 2 { try await withCheckedThrowingContinuation { connect = $0 } }
        }
        rig.transport.drop()
        try await eventually { rig.latest.connection == .reconnecting }
        rig.advanceToRetry()
        try await eventually { connect != nil }
        rig.close()
        connect?.resume(); connect = nil
        await pause()
        XCTAssertEqual(rig.latest.connection, .idle)
        XCTAssertNil(rig.latest.game)
        XCTAssertEqual(rig.transport.count("gameSession.join"), 0)
    }

    func testMembershipRevocationStopsSocketRetry() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        rig.transport.drop(GameRealtimeError.accessRevoked)
        try await eventually { rig.latest.connection == .failed }
        rig.now += 20; await pause()
        XCTAssertEqual(rig.transport.connects, 1)
        XCTAssertFalse(rig.latest.canReconnect(at: rig.now))
        XCTAssertFalse(rig.flight.presentation()?.canSteer == true)
    }

    func testGraceBudgetExpiresWithoutLocalEliminationAndManualRetryRemainsSameID() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        rig.transport.drop()
        try await eventually { rig.latest.connection == .reconnecting }
        rig.now += 11
        try await eventually { rig.latest.connection == .failed }
        XCTAssertEqual(rig.latest.game?.players.first?.isAlive, true)
        XCTAssertNil(rig.latest.result)
        rig.alive = false
        rig.lobby.retry()
        try await eventually { rig.transport.connects == 2 && rig.latest.connection == .connected }
        XCTAssertEqual(rig.latest.game?.players.first?.isAlive, false)
        XCTAssertEqual(rig.sessions.ensures, 1)
    }

    func testAnnouncedEliminationCannotBeRevivedByRecoveryFrame() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        rig.transport.push(try ReconnectFixture.game(sequence: 21, generation: nil, alive: false))
        try await eventually { rig.latest.game?.players.first?.isAlive == false }
        rig.transport.push(try ReconnectFixture.game(sequence: 1, epoch: 8, generation: "recovered", alive: true))
        try await eventually { rig.latest.connection == .failed }
        XCTAssertEqual(rig.latest.game?.players.first?.isAlive, false)
        XCTAssertEqual(rig.latest.issue, .connection(.invalidPayload))
        XCTAssertFalse(rig.latest.canReconnect(at: rig.now))
    }

    func testStaleAliveFrameAfterEliminationIsIgnored() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        rig.transport.push(try ReconnectFixture.game(sequence: 21, epoch: 8, generation: nil, alive: false))
        try await eventually { rig.latest.game?.runtimeEpoch == 8 }
        rig.transport.push(try ReconnectFixture.game(sequence: 999, epoch: 7, generation: "old", alive: true))
        rig.transport.push(try ReconnectFixture.game(sequence: 20, epoch: 8, generation: "old", alive: true))
        await pause()
        XCTAssertEqual(rig.latest.connection, .connected)
        XCTAssertEqual(rig.latest.game?.players.first?.isAlive, false)
        XCTAssertEqual(rig.latest.game?.stateSequence, 21)
    }

    func testInitialBackgroundWaitsUntilForegroundBeforeConnecting() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        rig.lobby.start(isForeground: false, isLandscape: true)
        await pause()
        XCTAssertEqual(rig.transport.connects, 0)
        rig.lobby.setForeground(true)
        try await eventually { rig.latest.connection == .connected }
        XCTAssertEqual(rig.transport.connects, 1)
        XCTAssertEqual(rig.sessions.ensures, 1)
    }

    func testRapidConnectDropDoesNotResetRetryBudgetOnEveryWelcome() async throws {
        let rig = try ReconnectRig()
        defer { rig.close() }
        try await rig.start()
        for attempt in 1...3 {
            rig.transport.drop()
            try await eventually { rig.latest.connection == .reconnecting }
            XCTAssertEqual(rig.latest.reconnectAttempt, attempt)
            rig.advanceToRetry()
            try await eventually { rig.latest.connection == .connected && rig.transport.connects == attempt + 1 }
        }
        rig.transport.drop()
        try await eventually { rig.latest.connection == .reconnecting }
        XCTAssertEqual(rig.latest.reconnectAttempt, 4)
    }

    private func eventually(_ condition: () -> Bool) async throws {
        let deadline = ProcessInfo.processInfo.systemUptime + 1.5
        while !condition() {
            guard ProcessInfo.processInfo.systemUptime < deadline else { XCTFail("Condition timed out"); throw CancellationError() }
            try await Task.sleep(for: .milliseconds(2))
        }
    }
    private func settle() async { for _ in 0..<30 { await Task.yield() } }
    private func pause() async { try? await Task.sleep(for: .milliseconds(30)) }
}

@MainActor
private final class ReconnectClockState { var now: TimeInterval = 100 }

@MainActor
private final class ReconnectRig {
    private let time = ReconnectClockState()
    var now: TimeInterval { get { time.now } set { time.now = newValue } }
    var alive = true
    var notices = 0
    var latest = HouseRocketsOnlineLobbyState()
    let sessions: ReconnectSessions
    let transport = ReconnectTransport()
    var lobby: HouseRocketsOnlineLobby!
    var flight: HouseRocketsOnlineFlight!
    let houseID: String
    let playerID: String
    init(houseID: String = "507f1f77bcf86cd799439012", playerID: String = "507f1f77bcf86cd799439021") throws {
        self.houseID = houseID; self.playerID = playerID
        sessions = try ReconnectSessions(houseID: houseID, playerID: playerID)
        let time = self.time
        let clock = GameRealtimeClock(wallTime: { Date() }, uptime: { time.now }, sleep: { duration in
            if duration >= 0.4 {
                let deadline = await time.now + duration
                while await time.now < deadline { try await Task.sleep(for: .milliseconds(2)) }
            } else { try await Task.sleep(for: .milliseconds(2)) }
        })
        let session = OnlineHouseRocketsSession(sessions: sessions, transport: transport, clock: clock)
        lobby = HouseRocketsOnlineLobby(session: session, context: .init(houseID: houseID, localPlayerID: playerID),
            clock: clock, reconnectPolicy: .init(jitter: { 1 }))
        let lobby = self.lobby!
        flight = HouseRocketsOnlineFlight(localPlayerID: playerID, clock: clock,
            send: { [weak lobby] message, grant in try await lobby?.sendSteering(message, grant: grant) },
            resync: { [weak lobby] in lobby?.resyncGameplay() })
        flight.onControlLost = { [weak lobby] in lobby?.controlLost() }
        flight.onEliminations = { [weak self] _ in self?.notices += 1 }
        lobby.onGameplayRejected = { [weak self] id, rejection in self?.flight.reject(messageID: id, rejection: rejection) }
        lobby.onStateChange = { [weak self] state in
            guard let self else { return }
            self.latest = state
            do { try self.flight.consume(state) } catch { XCTFail("Invalid flight projection: \(error)") }
        }
        transport.onConnect = { [weak self] index in
            guard let self else { return }
            let generation = "generation-\(index)"
            self.transport.push(try ReconnectFixture.wire("welcome"))
            self.transport.push(try ReconnectFixture.session(houseID: houseID, playerID: playerID))
            if index % 2 == 0 { self.transport.push(try ReconnectFixture.grant(generation: generation, playerID: playerID)) }
            self.transport.push(try ReconnectFixture.game(sequence: Int64(20 + index - 1), generation: self.alive ? generation : nil,
                alive: self.alive, playerID: playerID))
            if index % 2 != 0 { self.transport.push(try ReconnectFixture.grant(generation: generation, playerID: playerID)) }
        }
    }
    func start() async throws {
        lobby.start(isForeground: true, isLandscape: true)
        let deadline = ProcessInfo.processInfo.systemUptime + 1.5
        while latest.connection != .connected || latest.controlGrant == nil {
            guard ProcessInfo.processInfo.systemUptime < deadline else { throw CancellationError() }
            try await Task.sleep(for: .milliseconds(2))
        }
    }
    func advanceToRetry() { now = max(now, (latest.retryNotBefore ?? now) + 0.01) }
    func close() { lobby.disconnect(); flight.disconnect() }
}

@MainActor
private final class ReconnectSessions: GameSessionServicing {
    let initial: GameSessionDTO
    var ensures = 0
    var token: String? = "fixture-token"
    var requestedIDs: [String] = []
    var ensureHandler: (() async throws -> GameSessionDTO)?
    init(houseID: String, playerID: String) throws {
        guard case .session(let session) = try GameRealtimeCodec.decode(ReconnectFixture.session(houseID: houseID, playerID: playerID)).payload else { throw CancellationError() }
        initial = session
    }
    func ensureHouseRocketsSession(houseID: String) async throws -> GameSessionDTO { ensures += 1; return try await ensureHandler?() ?? initial }
    func discoverHouseRocketsSession(houseID: String) async throws -> GameSessionDTO { initial }
    func houseRocketsResult(sessionID: String) async throws -> HouseRocketsResultDTO { throw ReconnectFixture.http(404) }
    func realtimeRequest(sessionID: String) throws -> URLRequest {
        guard let token else { throw GameRealtimeError.authenticationRequired }
        requestedIDs.append(sessionID)
        return try GameEndpointBuilder(baseURL: URL(string: "https://example.test/api/v1")!).realtimeRequest(sessionID: sessionID, token: token)
    }
}

@MainActor
private final class ReconnectTransport: GameRealtimeTransporting {
    var connects = 0
    var disconnects = 0
    var connectFailures: [Int: Error] = [:]
    var connectHandler: ((Int) async throws -> Void)?
    var onConnect: ((Int) throws -> Void)?
    var sent: [[String: Any]] = []
    var authorizations: [String] = []
    private var queued: [Data] = []
    private var receiving: CheckedContinuation<Data, Error>?
    private var receiveFailure: Error?
    func connect(request: URLRequest) async throws {
        connects += 1
        receiveFailure = nil
        authorizations.append(request.value(forHTTPHeaderField: "Authorization") ?? "")
        if let error = connectFailures[connects] { throw error }
        try await connectHandler?(connects)
        try onConnect?(connects)
    }
    func send(_ data: Data) async throws {
        let value = try JSONSerialization.jsonObject(with: data) as! [String: Any]
        sent.append(value)
        if value["type"] as? String == "realtime.ping" {
            var pong = try ReconnectFixture.payload("pong")
            pong["pingId"] = (value["payload"] as? [String: Any])?["pingId"]
            push(try ReconnectFixture.wire("pong", payload: pong))
        }
    }
    func receive() async throws -> Data {
        if let receiveFailure { throw receiveFailure }
        if !queued.isEmpty { return queued.removeFirst() }
        return try await withCheckedThrowingContinuation { receiving = $0 }
    }
    func ping() async throws {}
    func disconnect() { disconnects += 1; receiving?.resume(throwing: CancellationError()); receiving = nil; queued.removeAll() }
    func drop(_ error: Error = URLError(.networkConnectionLost)) { receiveFailure = error; receiving?.resume(throwing: error); receiving = nil }
    func push(_ data: Data) {
        if let receiving { self.receiving = nil; receiving.resume(returning: data) }
        else { queued.append(data) }
    }
    func count(_ type: String) -> Int { sent.filter { $0["type"] as? String == type }.count }
    func lastID(_ type: String) -> String? { sent.last(where: { $0["type"] as? String == type })?["messageId"] as? String }
    func lastPayload(_ type: String) -> [String: Any]? { sent.last(where: { $0["type"] as? String == type })?["payload"] as? [String: Any] }
}

@MainActor
private enum ReconnectFixture {
    static let sessionID = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"
    static let houseID = "507f1f77bcf86cd799439012"
    static let playerID = "507f1f77bcf86cd799439021"
    static func message(_ name: String) throws -> [String: Any] {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: HouseRocketsReconnectTests.self)
        #endif
        let url = bundle.url(forResource: "houseRocketsProtocol", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "houseRocketsProtocol", withExtension: "json")
        let root = try JSONSerialization.jsonObject(with: Data(contentsOf: XCTUnwrap(url))) as! [String: Any]
        let messages = root["serverMessages"] as! [[String: Any]]
        return try XCTUnwrap(messages.first { $0["name"] as? String == name }?["message"] as? [String: Any])
    }
    static func payload(_ name: String) throws -> [String: Any] { try XCTUnwrap(message(name)["payload"] as? [String: Any]) }
    static func wire(_ name: String, payload: [String: Any]? = nil, id: String? = nil) throws -> Data {
        var value = try message(name)
        if let payload { value["payload"] = payload }
        if let id { value["messageId"] = id }
        return try JSONSerialization.data(withJSONObject: value)
    }
    static func session(version: Int64 = 10, messageID: String? = nil, playerState: String = "playing",
                        houseID: String? = nil, playerID: String? = nil) throws -> Data {
        var value = try payload("sessionSnapshot")
        value["state"] = "running"; value["version"] = version
        value["startedAt"] = "2026-10-03T12:00:33Z"
        value["houseId"] = houseID ?? self.houseID
        value["players"] = [["playerId": playerID ?? self.playerID, "state": playerState, "joinedAt": "2026-10-03T12:00:00Z"]]
        return try wire("sessionSnapshot", payload: value, id: messageID)
    }
    static func game(sequence: Int64, epoch: Int64 = 7, generation: String?, phase: String = "playing", alive: Bool = true,
                     messageID: String? = nil, playerID: String? = nil) throws -> Data {
        var value = try payload("playing")
        value["runtimeEpoch"] = epoch; value["stateSequence"] = sequence
        value["phase"] = phase; value["tick"] = sequence * 10; value["elapsedSeconds"] = Double(sequence) / 12
        var players = value["players"] as! [[String: Any]]
        players[0]["playerId"] = playerID ?? self.playerID
        players[0]["controlGeneration"] = generation.map { $0 as Any } ?? NSNull()
        players[0]["isAlive"] = alive
        players[0]["lastProcessedInputSequence"] = 0
        if !alive { players[0]["eliminatedAtTick"] = 100; players[0]["eliminationReason"] = "connectionExpired" }
        value["players"] = players
        return try wire("playing", payload: value, id: messageID)
    }
    static func grant(epoch: Int64 = 7, generation: String, playerID: String? = nil) throws -> Data {
        var value = try payload("controlGranted")
        value["runtimeEpoch"] = epoch; value["controlGeneration"] = generation; value["playerId"] = playerID ?? self.playerID
        return try wire("controlGranted", payload: value)
    }
    static func rejection(code: String, id: String?) throws -> Data {
        var value = try message("rejected")
        value["messageId"] = id
        value["error"] = ["code": code, "args": [], "retryable": false]
        return try JSONSerialization.data(withJSONObject: value)
    }
    static func http(_ status: Int, retry: String? = nil) -> NetworkHTTPFailure {
        let response = HTTPURLResponse(url: URL(string: "https://example.test")!, statusCode: status,
            httpVersion: nil, headerFields: retry.map { ["Retry-After": $0] })!
        return .init(response: .init(data: Data(), response: response))
    }
}
