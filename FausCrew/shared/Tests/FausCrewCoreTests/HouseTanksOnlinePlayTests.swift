import Foundation
@testable import FausCrewCore
import XCTest

/// The playing FauseTanks match through the engine with a mock server: the button gate
/// (grant, epoch, generation, landscape), press/release on change with a per-generation
/// sequence, late and duplicate frames, grant/snapshot order, ACK, interpolation,
/// own-tank prediction, shots and event replay; between rounds the vote; and the F5
/// lifecycle: drops and reconnects, a second device, a new runtime epoch, the background.
final class HouseTanksOnlinePlayTests: XCTestCase {
    private let houseID = "507f1f77bcf86cd799439012"
    private let playerID = "507f1f77bcf86cd799439021"
    private let otherID = "507f1f77bcf86cd799439022"
    private let sessionID = "7c51a2f7-3c83-4e76-8f97-2dc3cf3191a0"
    private var ids = 0
    /// The latency simulation's jitter units, in order; 0 once used up.
    private var jitterUnits: [Double] = []

    // MARK: Button gate

    func testButtonOpensOnlyWithGrantEpochAndOwnGeneration() throws {
        let (engine, socket) = try runningEngine()
        engine.received(text: try frame(sequence: 210, tick: 1_200), connection: socket, now: 10)
        XCTAssertEqual(engine.presentation(at: 10)?.canPress, false, "A snapshot without a grant keeps the button closed")
        engine.press(now: 10)
        XCTAssertTrue(presses(engine).isEmpty)
        engine.release(now: 10)

        engine.received(text: try grant(epoch: 8), connection: socket, now: 10.01)
        XCTAssertEqual(engine.presentation(at: 10.01)?.canPress, false, "A grant of another epoch does not match")

        let (fresh, freshSocket) = try runningEngine()
        fresh.received(text: try grant(epoch: 7), connection: freshSocket, now: 10)
        XCTAssertEqual(fresh.presentation(at: 10)?.canPress, nil, "Grant first: nothing to draw yet")
        fresh.received(text: try frame(sequence: 210, tick: 1_200), connection: freshSocket, now: 10.02)
        XCTAssertEqual(fresh.presentation(at: 10.02)?.canPress, true, "Either order opens the button")

        fresh.received(text: try frame(sequence: 211, tick: 1_206) { payload in
            self.player(&payload, 0) { $0["controlGeneration"] = "controlB" }
        }, connection: freshSocket, now: 10.05)
        XCTAssertEqual(fresh.presentation(at: 10.05)?.canPress, false, "The snapshot shows another generation")
    }

    func testPortraitAndOtherRoundPhasesKeepTheButtonClosed() throws {
        let (engine, socket) = try playingEngine()
        XCTAssertEqual(engine.presentation(at: 10)?.canPress, true)
        engine.setLandscape(false, now: 10.01)
        XCTAssertEqual(engine.presentation(at: 10.01)?.canPress, false)
        engine.setLandscape(true, now: 10.02)
        engine.received(text: try frame(sequence: 211, tick: 1_206) { $0["roundPhase"] = "roundCountdown" },
                        connection: socket, now: 10.05)
        XCTAssertEqual(engine.presentation(at: 10.05)?.canPress, false, "A press would be accepted but ignored")
        engine.press(now: 10.05)
        XCTAssertTrue(presses(engine).isEmpty)
    }

    // MARK: Press

    func testPressAndReleaseAreSentOnlyOnChangeWithTheDrawnTickAndHeading() throws {
        let (engine, _) = try playingEngine()
        let drawn = try XCTUnwrap(engine.presentation(at: 10.05)?.world.tank(playerID))
        engine.press(now: 10.05)
        engine.press(now: 10.06)
        let press = try XCTUnwrap(presses(engine).first)
        XCTAssertEqual(press["pressed"] as? Bool, true)
        XCTAssertEqual(press["controlGeneration"] as? String, "controlA")
        XCTAssertEqual(press["inputSequence"] as? Int, 18, "Above the generation's acknowledged 17")
        XCTAssertEqual(press["clientTick"] as? Int, 1_206, "The own tank is drawn 50 ms past the frame")
        XCTAssertEqual(try XCTUnwrap(press["heading"] as? Double), drawn.rotation, accuracy: 1e-12)
        XCTAssertTrue(presses(engine).isEmpty, "Holding the button sends nothing more")

        engine.release(now: 10.2)
        engine.release(now: 10.3)
        let sent = presses(engine)
        XCTAssertEqual(sent.map { $0["pressed"] as? Bool }, [false])
        XCTAssertEqual(sent.first?["inputSequence"] as? Int, 19)
    }

    func testAQuickTapSendsBothHalves() throws {
        let (engine, _) = try playingEngine()
        engine.press(now: 10.05)
        engine.release(now: 10.05)
        XCTAssertEqual(presses(engine).map { $0["pressed"] as? Bool }, [true, false])
    }

    func testANewGenerationCountsFromZero() throws {
        let (engine, socket) = try playingEngine()
        engine.press(now: 10.05)
        XCTAssertEqual(presses(engine).first?["inputSequence"] as? Int, 18)
        engine.received(text: try grant(epoch: 7, generation: "controlB"), connection: socket, now: 10.1)
        engine.received(text: try frame(sequence: 211, tick: 1_212) { payload in
            self.player(&payload, 0) {
                $0["controlGeneration"] = "controlB"
                $0["lastProcessedInputSequence"] = 0
            }
        }, connection: socket, now: 10.1)
        XCTAssertEqual(engine.presentation(at: 10.1)?.isPressed, true, "The finger is still down")
        engine.release(now: 10.15)
        XCTAssertTrue(presses(engine).isEmpty, "The old press died with its generation")
        engine.press(now: 10.2)
        let press = try XCTUnwrap(presses(engine).first)
        XCTAssertEqual(press["controlGeneration"] as? String, "controlB")
        XCTAssertEqual(press["inputSequence"] as? Int, 1)
    }

    func testARebindToTheSameGenerationContinuesAboveWhatWasSent() throws {
        let (engine, _) = try playingEngine()
        engine.press(now: 10.05)
        engine.release(now: 10.06)
        XCTAssertEqual(presses(engine).map { $0["inputSequence"] as? Int }, [18, 19])
        // Portrait and back: the same grant again, while the frame still acknowledges only 17.
        engine.setLandscape(false, now: 10.1)
        engine.setLandscape(true, now: 10.12)
        engine.press(now: 10.15)
        XCTAssertEqual(presses(engine).first?["inputSequence"] as? Int, 20,
                       "The server rejects any sequence it already accepted as stale_control")
    }

    func testAFingerHeldIntoANewRoundMustLiftBeforeItPressesAgain() throws {
        let (engine, socket) = try playingEngine()
        engine.press(now: 10.05)
        XCTAssertEqual(presses(engine).count, 1)
        engine.received(text: try frame(sequence: 211, tick: 1_206) { payload in
            payload["roundNumber"] = (payload["roundNumber"] as! Int) + 1
            payload["roundPhase"] = "roundCountdown"
        }, connection: socket, now: 10.1)
        engine.received(text: try frame(sequence: 212, tick: 1_212) { payload in
            payload["roundNumber"] = (payload["roundNumber"] as! Int) + 1
        }, connection: socket, now: 10.15)
        XCTAssertEqual(engine.presentation(at: 10.15)?.canPress, true)
        XCTAssertTrue(presses(engine).isEmpty, "The held finger does not drive or fire the new round")
        engine.release(now: 10.2)
        XCTAssertTrue(presses(engine).isEmpty, "The new round already released every tank")
        engine.press(now: 10.25)
        XCTAssertEqual(presses(engine).map { $0["pressed"] as? Bool }, [true])
    }

    func testAcknowledgementsMovingBackwardsFailTheMatchConnection() throws {
        let (engine, socket) = try playingEngine()
        engine.received(text: try frame(sequence: 211, tick: 1_206) { payload in
            self.player(&payload, 0) { $0["lastProcessedInputSequence"] = 12 }
        }, connection: socket, now: 10.05)
        XCTAssertEqual(engine.lobby.issue, .connection(.invalidPayload))
        XCTAssertNil(engine.lobby.game)
    }

    // MARK: Frames

    func testLateAndDuplicateFramesNeverMoveTheArenaBack() throws {
        let (engine, socket) = try playingEngine()
        engine.received(text: try frame(sequence: 212, tick: 1_212) { payload in
            self.tank(&payload, 1) { $0["x"] = 760.0 }
        }, connection: socket, now: 10.1)
        engine.received(text: try frame(sequence: 211, tick: 1_206) { payload in
            self.tank(&payload, 1) { $0["x"] = 100.0 }
        }, connection: socket, now: 10.12)
        engine.received(text: try frame(sequence: 212, tick: 1_212) { payload in
            self.tank(&payload, 1) { $0["x"] = 200.0 }
        }, connection: socket, now: 10.13)
        XCTAssertEqual(engine.lobby.game?.stateSequence, 212)
        let other = try XCTUnwrap(engine.presentation(at: 10.5)?.world.tank(otherID))
        XCTAssertEqual(other.position.x, 760, accuracy: 1e-9, "Neither the late nor the duplicate frame is drawn")
    }

    func testOtherTanksAreDrawnBetweenFramesBehindTheServer() throws {
        let (engine, socket) = try playingEngine()
        engine.received(text: try frame(sequence: 211, tick: 1_206) { payload in
            self.tank(&payload, 1) { $0["x"] = 760.41 }
        }, connection: socket, now: 10.05)
        let presentation = try XCTUnwrap(engine.presentation(at: 10.125))
        XCTAssertEqual(presentation.world.tick, 1_203, "100 ms behind the server clock")
        let other = try XCTUnwrap(presentation.world.tank(otherID))
        XCTAssertEqual(other.position.x, 754.41, accuracy: 1e-9, "Halfway between the two frames")
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(engine.presentation(at: 10.11)?.world.tick), 1_203,
                                    "The display never runs backwards")
    }

    func testFramesAfterAGapAreHeldNotSlidAcross() throws {
        let (engine, socket) = try playingEngine()
        // Half a second of lost frames (reconnect, resync).
        engine.received(text: try frame(sequence: 211, tick: 1_260) { payload in
            self.tank(&payload, 1) { $0["x"] = 100.0 }
        }, connection: socket, now: 10.5)
        let other = try XCTUnwrap(engine.presentation(at: 10.5)?.world.tank(otherID))
        XCTAssertEqual(other.position.x, 100, accuracy: 1e-9, "Drawn where the server is, not on the way there")
    }

    func testShotsFlyStraightFromTheirFrame() throws {
        let (engine, _) = try playingEngine()
        XCTAssertEqual(engine.presentation(at: 10.05)?.world.tick, 1_200, "Never before the first frame")
        let presentation = try XCTUnwrap(engine.presentation(at: 10.125))
        XCTAssertEqual(presentation.world.tick, 1_203)
        let shell = try XCTUnwrap(presentation.world.projectiles.first { $0.id == 31 })
        XCTAssertEqual(shell.position.x, 251.62 + 463.75 * 3 / 120, accuracy: 1e-6)
        XCTAssertEqual(shell.position.y, 190.78 + 212.25 * 3 / 120, accuracy: 1e-6)
        XCTAssertEqual(shell.age, 12)
    }

    func testTheOwnTankTurnsAheadOfTheFrameAndIsPulledBackSmoothly() throws {
        let (engine, socket) = try playingEngine { payload in
            self.tank(&payload, 0) { $0["isDriving"] = false; $0["vx"] = 0.0; $0["vy"] = 0.0 }
        }
        let ahead = try XCTUnwrap(engine.presentation(at: 10.1)?.world.tank(playerID))
        XCTAssertEqual(ahead.rotation, 0.42 + 1.5 * 12 / 120, accuracy: 1e-9, "1.5 rad/s in the sweep direction")

        // The server saw the tank 0.1 rad further on: what is drawn does not jump.
        engine.received(text: try frame(sequence: 211, tick: 1_212) { payload in
            self.tank(&payload, 0) { $0["isDriving"] = false; $0["vx"] = 0.0; $0["vy"] = 0.0; $0["rotation"] = 0.69 }
        }, connection: socket, now: 10.1)
        let kept = try XCTUnwrap(engine.presentation(at: 10.1)?.world.tank(playerID))
        XCTAssertEqual(kept.rotation, ahead.rotation, accuracy: 1e-9)
        let settled = try XCTUnwrap(engine.presentation(at: 10.3)?.world.tank(playerID))
        XCTAssertEqual(settled.rotation, 0.69 + 1.5 * 24 / 120, accuracy: 0.015, "The correction fades out")
    }

    // MARK: Events

    func testEventsPlayOnceByEpochAndSequence() throws {
        let (engine, socket) = try playingEngine()
        XCTAssertTrue(try XCTUnwrap(engine.presentation(at: 10.5)).events.isEmpty, "The first frame's events are history")

        engine.received(text: try frame(sequence: 211, tick: 1_206) { payload in
            payload["events"] = (payload["events"] as! [[String: Any]]) + [self.explosion(45, tick: 1_204)]
        }, connection: socket, now: 10.55)
        engine.received(text: try frame(sequence: 212, tick: 1_212) { payload in
            payload["events"] = (payload["events"] as! [[String: Any]]) + [self.explosion(45, tick: 1_204),
                                                                             self.explosion(46, tick: 1_210)]
        }, connection: socket, now: 10.6)
        var played: [HouseTanksWorld.Event] = []
        for step in 0..<20 { played += try XCTUnwrap(engine.presentation(at: 10.6 + Double(step) * 0.02)).events }
        XCTAssertEqual(played.map(\.tick), [1_204, 1_210], "Each event once, in display order")
        XCTAssertEqual(played.first?.kind, .explosion)

        // A new runtime epoch restarts the sequence; its first frame is history again.
        engine.received(text: try frame(sequence: 1, tick: 1_100, epoch: 8) { payload in
            payload["events"] = [self.explosion(1, tick: 1_099)]
            self.player(&payload, 0) { $0["controlGeneration"] = NSNull() }
        }, connection: socket, now: 11)
        engine.received(text: try frame(sequence: 2, tick: 1_106, epoch: 8) { payload in
            payload["events"] = [self.explosion(1, tick: 1_099), self.explosion(2, tick: 1_105)]
            self.player(&payload, 0) { $0["controlGeneration"] = NSNull() }
        }, connection: socket, now: 11.05)
        played = []
        for step in 0..<20 { played += try XCTUnwrap(engine.presentation(at: 11.05 + Double(step) * 0.02)).events }
        XCTAssertEqual(played.map(\.tick), [1_105])
    }

    // MARK: Round death and rejections

    func testADeadTankSaysDiedThisRoundAndClosesTheButton() throws {
        let (engine, socket) = try playingEngine()
        engine.received(text: try frame(sequence: 211, tick: 1_206) { payload in
            self.player(&payload, 0) { $0["isAlive"] = false }
        }, connection: socket, now: 10.05)
        let presentation = try XCTUnwrap(engine.presentation(at: 10.05))
        XCTAssertTrue(presentation.isLocalTankDestroyed)
        XCTAssertFalse(presentation.canPress)
        XCTAssertEqual(presentation.seats.first?.isAlive, false)
        XCTAssertEqual(engine.lobby.issue, nil, "Dying in a round is not leaving the match")
    }

    func testPlayerEliminatedRejectionIsARoundDeathWithoutResync() throws {
        let (engine, socket) = try playingEngine()
        engine.press(now: 10.05)
        let id = try XCTUnwrap(sentMessages(engine).first?["messageId"] as? String)
        engine.received(text: try message("rejected", id: id), connection: socket, now: 10.1)
        let presentation = try XCTUnwrap(engine.presentation(at: 10.1))
        XCTAssertTrue(presentation.isLocalTankDestroyed)
        XCTAssertFalse(presentation.canPress)
        XCTAssertFalse(types(engine).contains("houseTanks.resync"))
    }

    func testStaleControlDropsTheInputAndResyncsWithoutALoop() throws {
        let (engine, socket) = try playingEngine()
        engine.press(now: 10.05)
        let id = try XCTUnwrap(sentMessages(engine).first?["messageId"] as? String)
        engine.received(text: try staleRejection(id), connection: socket, now: 10.1)
        XCTAssertTrue(types(engine).isEmpty, "A resync now would take the tank back from a second device")
        XCTAssertEqual(engine.presentation(at: 10.1)?.canPress, false)
        engine.release(now: 10.2)
        engine.press(now: 10.3)
        XCTAssertTrue(presses(engine).isEmpty, "No press until a frame shows the grant again")
        engine.tick(now: 10.65)
        XCTAssertEqual(types(engine), ["houseTanks.resync"], "No takeover showed up: rebind once")
        engine.tick(now: 10.7)
        engine.tick(now: 11.2)
        XCTAssertFalse(types(engine).contains("houseTanks.resync"), "Never a resync loop")
    }

    // MARK: Drops, a second device, epochs and the background (F5)

    func testAnotherDeviceTakingTheTankIsNotFoughtBack() throws {
        let (engine, socket) = try playingEngine()
        engine.press(now: 10.05)
        let id = try XCTUnwrap(sentMessages(engine).first?["messageId"] as? String)
        // The new device's bind can reach us as a rejection before the frame that shows it.
        engine.received(text: try staleRejection(id), connection: socket, now: 10.08)
        engine.received(text: try frame(sequence: 211, tick: 1_206) { payload in
            self.player(&payload, 0) { $0["controlGeneration"] = NSNull() }
        }, connection: socket, now: 10.1)
        XCTAssertTrue(engine.lobby.controlTransferred)
        let presentation = try XCTUnwrap(engine.presentation(at: 10.1))
        XCTAssertFalse(presentation.canPress)
        XCTAssertFalse(presentation.isAwaitingControl)
        XCTAssertEqual(HouseTanksOnlineCopyKeys.matchNotice(engine.lobby, presentation)?.title, "house_tanks_online_control_moved")
        for step in 1...20 { engine.tick(now: 10.1 + Double(step) * 0.05) }
        XCTAssertFalse(types(engine).contains("houseTanks.resync"), "The old device never races the new one")

        engine.reclaimControl(now: 11.2)
        XCTAssertEqual(types(engine), ["houseTanks.resync"], "Only the player's own tap binds this device again")
    }

    func testAShortDropReopensTheSameMatchAndControlReturnsWithANewGeneration() throws {
        let (engine, socket) = try playingEngine()
        engine.press(now: 10.05)
        _ = engine.drainEffects()
        engine.connectionFailed(.transport, connection: socket, now: 10.1)
        XCTAssertEqual(engine.lobby.connection, .reconnecting)
        let dropped = try XCTUnwrap(engine.presentation(at: 10.1))
        XCTAssertFalse(dropped.canPress)
        XCTAssertTrue(dropped.isSyncing, "The arena holds still while the socket is gone")
        XCTAssertEqual(HouseTanksOnlineCopyKeys.matchNotice(engine.lobby, dropped)?.title, "house_tanks_online_reconnecting")
        XCTAssertNil(engine.lobby.issue.flatMap { _ in engine.result.result }, "A drop is not leaving the match")

        var reopened: Int?
        var now = 10.1
        while reopened == nil, now < 20 {
            now += 0.05
            engine.tick(now: now)
            for effect in engine.drainEffects() {
                if case .ensureSession = effect { XCTFail("A pinned match is reopened, never requested again") }
                if case .openSocket(let id, let connection) = effect {
                    XCTAssertEqual(id, sessionID)
                    reopened = connection
                }
            }
        }
        let next = try XCTUnwrap(reopened, "Bounded backoff reopens the socket")
        XCTAssertLessThan(now, 20.1, "Within the server's reconnect grace")
        engine.socketOpened(connection: next, now: now)
        engine.received(text: try message("welcome"), connection: next, now: now + 0.01)
        engine.received(text: try session(version: 9), connection: next, now: now + 0.02)
        // Back before the server rebinds: the tank is a stationary target for now.
        engine.received(text: try frame(sequence: 240, tick: 1_400) { payload in
            self.player(&payload, 0) { $0["controlGeneration"] = NSNull(); $0["connected"] = false }
            self.tank(&payload, 0) { $0["controllable"] = false }
        }, connection: next, now: now + 0.03)
        XCTAssertEqual(engine.lobby.connection, .connected)
        XCTAssertFalse(engine.lobby.controlTransferred, "Losing control to a drop is not a takeover")
        engine.received(text: try frame(sequence: 250, tick: 1_466) { payload in
            self.player(&payload, 0) { $0["controlGeneration"] = NSNull(); $0["connected"] = false }
            self.tank(&payload, 0) { $0["controllable"] = false }
        }, connection: next, now: now + 0.58)
        let waiting = try XCTUnwrap(engine.presentation(at: now + 0.6))
        XCTAssertTrue(waiting.isAwaitingControl)
        XCTAssertTrue(waiting.offlinePlayerIDs.contains(playerID), "Drawn as the stationary target it is")
        XCTAssertEqual(HouseTanksOnlineCopyKeys.matchNotice(engine.lobby, waiting)?.title, "house_tanks_online_awaiting_control")

        engine.received(text: try grant(epoch: 7, generation: "controlB"), connection: next, now: now + 0.7)
        engine.received(text: try frame(sequence: 251, tick: 1_472) { payload in
            self.player(&payload, 0) { $0["controlGeneration"] = "controlB"; $0["lastProcessedInputSequence"] = 0 }
        }, connection: next, now: now + 0.72)
        let back = try XCTUnwrap(engine.presentation(at: now + 0.72))
        XCTAssertTrue(back.canPress)
        XCTAssertNil(HouseTanksOnlineCopyKeys.matchNotice(engine.lobby, back))
        _ = engine.drainEffects()
        engine.press(now: now + 0.75)
        let press = try XCTUnwrap(presses(engine).first)
        XCTAssertEqual(press["controlGeneration"] as? String, "controlB")
        XCTAssertEqual(press["inputSequence"] as? Int, 1, "The held press before the drop is not replayed")
    }

    func testANewRuntimeEpochRecoversThenRebindsFromScratch() throws {
        let (engine, socket) = try playingEngine { payload in payload["events"] = [self.explosion(4, tick: 1_195)] }
        engine.press(now: 10.05)
        XCTAssertEqual(presses(engine).first?["inputSequence"] as? Int, 18)
        engine.received(text: try frame(sequence: 3, tick: 1_100, epoch: 8) { payload in
            payload["phase"] = "recovering"
            payload["events"] = [self.explosion(4, tick: 1_095)]
            for index in 0..<3 {
                self.player(&payload, index) { $0["controlGeneration"] = NSNull() }
                self.tank(&payload, index) { $0["controllable"] = false }
            }
        }, connection: socket, now: 10.1)
        let recovering = try XCTUnwrap(engine.presentation(at: 10.1))
        XCTAssertEqual(recovering.world.tick, 1_100, "The checkpoint may be older: the arena follows the new epoch")
        XCTAssertTrue(recovering.isSyncing)
        XCTAssertFalse(recovering.canPress)
        XCTAssertEqual(HouseTanksOnlineCopyKeys.matchNotice(engine.lobby, recovering)?.title, "house_tanks_online_recovering")
        XCTAssertTrue(recovering.events.isEmpty, "A new epoch's events are history at first")
        XCTAssertNil(engine.lobby.controlGrant, "The old epoch's grant is gone")
        engine.release(now: 10.15)
        XCTAssertTrue(presses(engine).isEmpty)

        engine.received(text: try grant(epoch: 8, generation: "controlC"), connection: socket, now: 10.2)
        engine.received(text: try frame(sequence: 4, tick: 1_106, epoch: 8) { payload in
            self.player(&payload, 0) { $0["controlGeneration"] = "controlC"; $0["lastProcessedInputSequence"] = 0 }
        }, connection: socket, now: 10.22)
        let rebound = try XCTUnwrap(engine.presentation(at: 10.22))
        XCTAssertTrue(rebound.canPress)
        XCTAssertFalse(rebound.isSyncing)
        engine.press(now: 10.25)
        let press = try XCTUnwrap(presses(engine).first)
        XCTAssertEqual(press["controlGeneration"] as? String, "controlC")
        XCTAssertEqual(press["inputSequence"] as? Int, 1, "Sequence counters start over with the epoch")
    }

    func testANewEpochDropsTheVoteAndThePlayerVotesAgain() throws {
        let (engine, socket) = try votingEngine()
        engine.setRoundReady(true, now: 10.06)
        _ = engine.drainEffects()
        engine.received(text: try grant(epoch: 8, generation: "controlC"), connection: socket, now: 10.1)
        engine.received(text: try frame(sequence: 4, tick: 1_106, epoch: 8) { payload in
            self.roundReady(&payload)
            self.player(&payload, 0) { $0["controlGeneration"] = "controlC"; $0["lastProcessedInputSequence"] = 0 }
        }, connection: socket, now: 10.12)
        let presentation = try XCTUnwrap(engine.presentation(at: 10.12))
        XCTAssertFalse(presentation.isLocalReady, "Votes in the window fall with the old owner")
        XCTAssertTrue(presentation.canVote)
        engine.setRoundReady(true, now: 10.15)
        let vote = try XCTUnwrap(try sentMessages(engine).first?["payload"] as? [String: Any])
        XCTAssertEqual(vote["controlGeneration"] as? String, "controlC")
    }

    func testTheBackgroundReleasesTheButtonStopsPingsAndResyncsOnReturn() throws {
        let (engine, socket) = try playingEngine()
        engine.press(now: 10.05)
        _ = engine.drainEffects()
        engine.setForeground(false, now: 10.1)
        XCTAssertEqual(presses(engine).map { $0["pressed"] as? Bool }, [false],
                       "Released while the grant still sends, so the tank does not drive on")
        engine.release(now: 10.12)
        for step in 1...40 { engine.tick(now: 10.1 + Double(step) * 0.1) }
        XCTAssertTrue(types(engine).isEmpty, "No pings or input in the background")
        XCTAssertNil(engine.lobby.issue, "The background is not a drop and not a leave")

        engine.setForeground(true, now: 14.2)
        let sent = try sentMessages(engine)
        XCTAssertEqual(sent.compactMap { $0["type"] as? String }, ["houseTanks.resync"])
        let resyncID = try XCTUnwrap(sent.first?["messageId"] as? String)
        XCTAssertEqual(engine.presentation(at: 14.2)?.canPress, false, "Not before fresh state")
        engine.received(text: try session(version: 10, id: resyncID), connection: socket, now: 14.25)
        engine.received(text: try grant(epoch: 7), connection: socket, now: 14.26)
        engine.received(text: try frame(sequence: 300, tick: 1_700, id: resyncID), connection: socket, now: 14.27)
        let back = try XCTUnwrap(engine.presentation(at: 14.27))
        XCTAssertTrue(back.canPress)
        XCTAssertNil(HouseTanksOnlineCopyKeys.matchNotice(engine.lobby, back))
    }

    func testRotatingToPortraitReleasesAHeldPress() throws {
        let (engine, _) = try playingEngine()
        engine.press(now: 10.05)
        _ = engine.drainEffects()
        engine.setLandscape(false, now: 10.1)
        XCTAssertEqual(presses(engine).map { $0["pressed"] as? Bool }, [false])
    }

    func testAShortGrantGapPassesSilentlyALongOneSaysSo() throws {
        let (engine, socket) = try runningEngine()
        engine.received(text: try frame(sequence: 210, tick: 1_200) { payload in
            self.player(&payload, 0) { $0["controlGeneration"] = NSNull() }
        }, connection: socket, now: 10)
        let early = try XCTUnwrap(engine.presentation(at: 10.3))
        XCTAssertFalse(early.isAwaitingControl)
        XCTAssertNil(HouseTanksOnlineCopyKeys.matchNotice(engine.lobby, early))
        let late = try XCTUnwrap(engine.presentation(at: 10.55))
        XCTAssertTrue(late.isAwaitingControl)
        XCTAssertFalse(late.isSpectating)
    }

    func testAPlayerWithoutATankWatches() throws {
        let (engine, socket) = try runningEngine()
        engine.received(text: try frame(sequence: 210, tick: 1_200) { payload in
            var players = payload["players"] as! [[String: Any]]
            players[0]["playerId"] = "507f1f77bcf86cd799439029"
            payload["players"] = players
            var tanks = payload["tanks"] as! [[String: Any]]
            tanks[0]["playerId"] = "507f1f77bcf86cd799439029"
            payload["tanks"] = tanks
        }, connection: socket, now: 10)
        let presentation = try XCTUnwrap(engine.presentation(at: 10.05))
        XCTAssertTrue(presentation.isSpectating)
        XCTAssertFalse(presentation.isAwaitingControl)
        XCTAssertFalse(presentation.isLocalTankDestroyed)
        XCTAssertEqual(HouseTanksOnlineCopyKeys.matchNotice(engine.lobby, presentation)?.title, "house_tanks_online_spectating")

        // Between rounds the watcher sees the round panel (who took it) instead of the banner.
        engine.received(text: try frame(sequence: 211, tick: 1_206) { payload in
            var players = payload["players"] as! [[String: Any]]
            players[0]["playerId"] = "507f1f77bcf86cd799439029"
            payload["players"] = players
            var tanks = payload["tanks"] as! [[String: Any]]
            tanks[0]["playerId"] = "507f1f77bcf86cd799439029"
            payload["tanks"] = tanks
            payload["roundPhase"] = "roundReady"
        }, connection: socket, now: 10.1)
        let between = try XCTUnwrap(engine.presentation(at: 10.15))
        XCTAssertTrue(between.isSpectating)
        XCTAssertNil(HouseTanksOnlineCopyKeys.matchNotice(engine.lobby, between))
    }

    func testClosingTheScreenMidMatchStopsEverything() throws {
        let (engine, socket) = try playingEngine()
        engine.press(now: 10.05)
        _ = engine.drainEffects()
        engine.disconnect()
        XCTAssertTrue(engine.drainEffects().contains { if case .closeSocket = $0 { return true } else { return false } })
        XCTAssertTrue(engine.isClosed)
        XCTAssertNil(engine.presentation(at: 10.1))
        engine.received(text: try frame(sequence: 211, tick: 1_206), connection: socket, now: 10.1)
        engine.press(now: 10.2)
        for step in 1...20 { engine.tick(now: 10.2 + Double(step) * 0.5) }
        XCTAssertTrue(engine.drainEffects().isEmpty, "No socket, ping, press or reconnect after cleanup")
        XCTAssertNil(engine.presentation(at: 20))
    }

    // MARK: Between rounds

    func testTheRoundVoteIsSentOnceAndShowsAtOnce() throws {
        let (engine, socket) = try votingEngine()
        let before = try XCTUnwrap(engine.presentation(at: 10.05))
        XCTAssertTrue(before.canVote)
        XCTAssertFalse(before.canPress)
        XCTAssertFalse(before.isLocalReady)
        XCTAssertEqual(before.voterCount, 3)
        XCTAssertEqual(before.readyCount, 0)
        XCTAssertNil(HouseTanksOnlineCopyKeys.matchNotice(engine.lobby, before), "The round panel speaks instead")
        XCTAssertEqual(HouseTanksOnlineCopyKeys.roundTitle(before, localPlayerID: playerID), "house_tanks_online_round_winner")

        engine.setRoundReady(true, now: 10.06)
        engine.setRoundReady(true, now: 10.07)
        let votes = try sentMessages(engine).filter { $0["type"] as? String == "houseTanks.roundReady" }
        XCTAssertEqual(votes.count, 1, "The same vote twice sends nothing more")
        let payload = try XCTUnwrap(votes.first?["payload"] as? [String: Any])
        XCTAssertEqual(payload["controlGeneration"] as? String, "controlA")
        XCTAssertEqual(payload["ready"] as? Bool, true)
        let pending = try XCTUnwrap(engine.presentation(at: 10.08))
        XCTAssertTrue(pending.isLocalReady)
        XCTAssertTrue(pending.isVotePending)
        XCTAssertEqual(pending.readyCount, 1)
        XCTAssertEqual(pending.seats.first?.roundReady, true)

        engine.received(text: try frame(sequence: 212, tick: 1_212) { payload in
            self.roundReady(&payload)
            self.player(&payload, 0) { $0["roundReady"] = true }
        }, connection: socket, now: 10.1)
        let confirmed = try XCTUnwrap(engine.presentation(at: 10.1))
        XCTAssertTrue(confirmed.isLocalReady)
        XCTAssertFalse(confirmed.isVotePending, "The snapshot confirmed it")

        engine.setRoundReady(false, now: 10.15)
        XCTAssertEqual(try sentMessages(engine).compactMap { ($0["payload"] as? [String: Any])?["ready"] as? Bool }, [false])
    }

    func testADeadTanksPlayerStillVotes() throws {
        let (engine, _) = try votingEngine { payload in self.player(&payload, 0) { $0["isAlive"] = false } }
        let presentation = try XCTUnwrap(engine.presentation(at: 10.05))
        XCTAssertTrue(presentation.canVote)
        XCTAssertFalse(presentation.isLocalTankDestroyed, "No death banner over the round panel")
        engine.setRoundReady(true, now: 10.05)
        XCTAssertEqual(try sentMessages(engine).count, 1)
    }

    func testOnlyAPlayerWithControlVotesAndOnlyBetweenRounds() throws {
        let (playing, _) = try playingEngine()
        XCTAssertEqual(playing.presentation(at: 10.05)?.canVote, false)
        playing.setRoundReady(true, now: 10.05)
        XCTAssertTrue(try sentMessages(playing).isEmpty, "No vote during play")

        let (engine, _) = try votingEngine { payload in self.player(&payload, 0) { $0["controlGeneration"] = NSNull() } }
        let presentation = try XCTUnwrap(engine.presentation(at: 10.05))
        XCTAssertFalse(presentation.canVote)
        XCTAssertEqual(HouseTanksOnlineCopyKeys.roundDetail(presentation, windowSeconds: nil), "house_tanks_online_round_no_vote")
        engine.setRoundReady(true, now: 10.05)
        XCTAssertTrue(try sentMessages(engine).isEmpty)
    }

    func testARejectedVoteFallsBackToTheSnapshot() throws {
        let (engine, socket) = try votingEngine()
        engine.setRoundReady(true, now: 10.05)
        let id = try XCTUnwrap(sentMessages(engine).first?["messageId"] as? String)
        engine.received(text: try message("rejected", id: id) { $0["error"] = ["code": "houseTanks.error.invalid_input",
                                                                             "args": [], "retryable": false] },
                        connection: socket, now: 10.1)
        let presentation = try XCTUnwrap(engine.presentation(at: 10.1))
        XCTAssertFalse(presentation.isLocalReady)
        XCTAssertFalse(presentation.isVotePending)
        XCTAssertTrue(try sentMessages(engine).isEmpty, "The round had started: no resync, no retry")
    }

    func testTheVoteWindowCountsDownAndANewRoundClearsTheVote() throws {
        let (engine, socket) = try votingEngine { payload in payload["roundReadyWindowEndsAt"] = "2026-10-24T12:01:00Z" }
        let first = try XCTUnwrap(engine.roomCountdown(at: 10))
        XCTAssertEqual(engine.roomCountdown(at: 11), first - 1)
        let presentation = try XCTUnwrap(engine.presentation(at: 10.05))
        XCTAssertEqual(HouseTanksOnlineCopyKeys.roundDetail(presentation, windowSeconds: first), "house_tanks_online_round_window")

        engine.setRoundReady(true, now: 10.06)
        engine.received(text: try frame(sequence: 212, tick: 1_212) { payload in
            payload["roundNumber"] = (payload["roundNumber"] as! Int) + 1
            payload["roundPhase"] = "roundCountdown"
        }, connection: socket, now: 10.1)
        let next = try XCTUnwrap(engine.presentation(at: 10.1))
        XCTAssertFalse(next.isLocalReady)
        XCTAssertFalse(next.canVote)
    }

    func testTheChampionAndResultCopy() throws {
        let result = try GameRealtimeCodec.makeDecoder().decode(HouseTanksResultDTO.self, from: resultData("result"))
        var state = HouseTanksOnlineResultState()
        state.phase = .waiting
        XCTAssertEqual(HouseTanksOnlineCopyKeys.resultTitle(state, localPlayerID: playerID), .key("house_tanks_online_finalizing"))
        state.phase = .available
        state.result = result
        XCTAssertEqual(HouseTanksOnlineCopyKeys.resultTitle(state, localPlayerID: playerID), .key("house_tanks_champion_you"))
        XCTAssertEqual(HouseTanksOnlineCopyKeys.resultTitle(state, localPlayerID: otherID), .champion(playerID: playerID))
        XCTAssertEqual(HouseTanksOnlineCopyKeys.resultDetail(state), "house_tanks_champion_detail")
        XCTAssertEqual(HouseTanksOnlineCopyKeys.orderedResultPlayers(result).map(\.finalRank), [1, 2, 2])

        let cancelled = try GameRealtimeCodec.makeDecoder().decode(HouseTanksResultDTO.self, from: resultData("insufficientPlayersResult"))
        state.result = cancelled
        state.endReason = cancelled.endReason
        XCTAssertEqual(HouseTanksOnlineCopyKeys.resultTitle(state, localPlayerID: playerID), .key("house_tanks_online_result_cancelled"))
        XCTAssertEqual(HouseTanksOnlineCopyKeys.resultDetail(state), "house_tanks_online_result_insufficient_players")
        let wins = HouseTanksOnlineCopyKeys.orderedResultPlayers(cancelled).map(\.roundsWon)
        XCTAssertEqual(wins, wins.sorted(by: >), "Unranked players by round wins")
    }

    func testTheEndMenuShowsStandingsBeforeTheResult() throws {
        let (engine, socket) = try playingEngine()
        engine.received(text: try frame(sequence: 211, tick: 1_206) { payload in
            self.player(&payload, 1) { $0["roundsWon"] = 2 }
        }, connection: socket, now: 10.05)
        let playing = try XCTUnwrap(engine.presentation(at: 10.05))
        XCTAssertFalse(HouseTanksOnlineCopyKeys.isMatchOver(engine.lobby, playing))
        engine.received(text: try frame(sequence: 212, tick: 1_212) { payload in
            payload["phase"] = "finalizing"
            payload["roundPhase"] = "matchEnded"
        }, connection: socket, now: 10.1)
        XCTAssertTrue(HouseTanksOnlineCopyKeys.isMatchOver(engine.lobby, engine.presentation(at: 10.1)))
        XCTAssertGreaterThan(engine.displayFramesPerSecond(at: 10.1), 0)

        // Before the lookup: finalizing, the last seats by round wins, unranked.
        var state = HouseTanksOnlineResultState()
        XCTAssertEqual(HouseTanksOnlineCopyKeys.resultTitle(state, localPlayerID: playerID), .key("house_tanks_online_finalizing"))
        let provisional = HouseTanksOnlineCopyKeys.standings(state, seats: playing.seats)
        XCTAssertEqual(provisional.map(\.displayName), ["Ece", "Deniz", "Ada"])
        XCTAssertTrue(provisional.allSatisfy { $0.isProvisional && $0.rank == nil })

        // The stored ranks replace them; names come from the seats when the result has none.
        state.phase = .available
        state.result = try GameRealtimeCodec.makeDecoder().decode(HouseTanksResultDTO.self, from: resultData("result"))
        let stored = HouseTanksOnlineCopyKeys.standings(state, seats: playing.seats)
        XCTAssertEqual(stored.map(\.rank), [1, 2, 2])
        XCTAssertFalse(stored.contains { $0.isProvisional || $0.displayName == nil })
    }

    func testOfflineTanksAreMarkedForTheArena() throws {
        let (engine, socket) = try playingEngine()
        engine.received(text: try frame(sequence: 211, tick: 1_206) { payload in
            self.player(&payload, 1) { $0["connected"] = false }
            self.tank(&payload, 1) { $0["controllable"] = false }
        }, connection: socket, now: 10.05)
        let presentation = try XCTUnwrap(engine.presentation(at: 10.05))
        XCTAssertEqual(presentation.offlinePlayerIDs, [otherID])
        XCTAssertEqual(presentation.seats.map(\.isConnected), [true, false, true])
        XCTAssertEqual(presentation.seats.map(\.displayName), ["Deniz", "Ece", "Ada"])
    }

    // MARK: Device acceptance tools (F6)

    func testTheLatencySimulationHoldsSocketTrafficBothWaysInOrder() throws {
        let (engine, socket) = try playingEngine()
        engine.setLatencySimulation(.init(roundTripMilliseconds: 200, jitterMilliseconds: 50), now: 10)
        engine.press(now: 10.05)
        XCTAssertTrue(presses(engine).isEmpty, "Held for half the round trip")
        engine.tick(now: 10.14)
        XCTAssertTrue(presses(engine).isEmpty)
        engine.tick(now: 10.16)
        XCTAssertEqual(presses(engine).map { $0["pressed"] as? Bool }, [true])

        // +50 ms jitter, then -50 ms: the second frame still arrives after the first.
        jitterUnits = [1, -1]
        engine.received(text: try frame(sequence: 211, tick: 1_206), connection: socket, now: 10.2)
        engine.received(text: try frame(sequence: 212, tick: 1_212), connection: socket, now: 10.21)
        XCTAssertEqual(engine.lobby.game?.stateSequence, 210, "Nothing arrives before its time")
        engine.tick(now: 10.33)
        XCTAssertEqual(engine.lobby.game?.stateSequence, 210)
        engine.tick(now: 10.36)
        XCTAssertEqual(engine.lobby.game?.stateSequence, 212, "Order kept, as on a TCP socket")
        XCTAssertEqual(engine.lobby.gameReceivedUptime ?? 0, 10.35, accuracy: 1e-9, "Delivered at its own time")

        engine.release(now: 10.4)
        engine.connectionFailed(.transport, connection: socket, now: 10.41)
        engine.tick(now: 10.6)
        XCTAssertTrue(presses(engine).isEmpty, "A closed socket loses what it still held")

        let (direct, _) = try playingEngine()
        direct.setLatencySimulation(.init(roundTripMilliseconds: 400, jitterMilliseconds: 0), now: 10)
        direct.press(now: 10.05)
        direct.setLatencySimulation(.off, now: 10.06)
        XCTAssertEqual(presses(direct).count, 1, "Turning it off sends what was held")
    }

    func testDiagnosticsMeasureTheLinkAndTheDisplay() throws {
        let (engine, socket) = try playingEngine()
        engine.tick(now: 10.01)
        let ping = try XCTUnwrap(try sentMessages(engine).first { $0["type"] as? String == "realtime.ping" })
        let pingID = try XCTUnwrap((ping["payload"] as? [String: Any])?["pingId"] as? String)
        engine.received(text: try message("pong") { $0["pingId"] = pingID }, connection: socket, now: 10.13)
        engine.press(now: 10.02)
        _ = engine.drainEffects()
        for step in 1...4 {
            engine.received(text: try frame(sequence: 210 + step, tick: 1_200 + step * 6) { payload in
                if step >= 3 { self.player(&payload, 0) { $0["lastProcessedInputSequence"] = 18 } }
            }, connection: socket, now: 10 + Double(step) * 0.05)
        }
        engine.received(text: try frame(sequence: 212, tick: 1_212) { payload in
            self.player(&payload, 0) { $0["lastProcessedInputSequence"] = 18 }
        }, connection: socket, now: 10.21)
        XCTAssertEqual(engine.lobby.connection, .connected)
        _ = engine.presentation(at: 10.22)
        _ = engine.presentation(at: 10.24)
        let diagnostics = engine.diagnostics(at: 10.24)
        XCTAssertEqual(diagnostics.roundTripMilliseconds, 120)
        XCTAssertEqual(diagnostics.snapshotIntervalMilliseconds, 50)
        XCTAssertEqual(diagnostics.snapshotJitterMilliseconds, 0)
        XCTAssertEqual(diagnostics.frameAgeMilliseconds, 40)
        XCTAssertEqual(diagnostics.inputAcknowledgementMilliseconds, 130, "Sent at 10.02, acknowledged by the frame of 10.15")
        XCTAssertEqual(diagnostics.unacknowledgedInputs, 0)
        XCTAssertEqual(diagnostics.lateFrames, 1)
        XCTAssertEqual(diagnostics.displayFramesPerSecond, 2)
        XCTAssertGreaterThan(diagnostics.receivedKilobytesPerSecond, 0)
        XCTAssertEqual(diagnostics.lines.count, 7)
        XCTAssertEqual(diagnostics.lines[1], "RTT 120 ms")
    }

    // MARK: Helpers

    private func makeEngine() -> HouseTanksOnlineEngine {
        HouseTanksOnlineEngine(context: .init(houseID: houseID, localPlayerID: playerID),
                               policy: .init(jitter: { 1 }), makeID: { [unowned self] in ids += 1; return "id\(ids)" },
                               jitter: { [unowned self] in jitterUnits.isEmpty ? 0 : jitterUnits.removeFirst() })
    }

    /// Socket open, welcome, a running session with the local player and landscape on.
    private func runningEngine() throws -> (HouseTanksOnlineEngine, Int) {
        let engine = makeEngine()
        engine.start(isForeground: true, isLandscape: true, now: 9)
        guard case .ensureSession(_, let connection) = try XCTUnwrap(engine.drainEffects().first) else { throw XCTSkip("No ensure") }
        engine.sessionResponse(try envelope(sessionPayload(version: 5)), retryAfter: nil, connection: connection, now: 9.1)
        guard case .openSocket(_, let socket) = try XCTUnwrap(engine.drainEffects().last) else { throw XCTSkip("No socket") }
        engine.socketOpened(connection: socket, now: 9.2)
        engine.received(text: try message("welcome"), connection: socket, now: 9.3)
        // Tests that `tick` stay within the 6 s heartbeat timeout; `types` skips the pings.
        engine.received(text: try session(version: 9), connection: socket, now: 9.4)
        _ = engine.drainEffects()
        return (engine, socket)
    }

    /// Running engine with grant `controlA` and the `roundPlaying` frame received at 10 s.
    private func playingEngine(_ change: @escaping (inout [String: Any]) -> Void = { _ in }) throws
        -> (HouseTanksOnlineEngine, Int) {
        let (engine, socket) = try runningEngine()
        engine.received(text: try grant(epoch: 7), connection: socket, now: 9.95)
        engine.received(text: try frame(sequence: 210, tick: 1_200, change), connection: socket, now: 10)
        _ = engine.drainEffects()
        return (engine, socket)
    }

    /// Playing engine whose second frame (received at 10.05 s) ended the round for `otherID`.
    private func votingEngine(_ change: @escaping (inout [String: Any]) -> Void = { _ in }) throws
        -> (HouseTanksOnlineEngine, Int) {
        let (engine, socket) = try playingEngine()
        engine.received(text: try frame(sequence: 211, tick: 1_206) { payload in
            self.roundReady(&payload)
            change(&payload)
        }, connection: socket, now: 10.05)
        _ = engine.drainEffects()
        return (engine, socket)
    }

    private func roundReady(_ payload: inout [String: Any]) {
        payload["roundPhase"] = "roundReady"
        payload["roundWinnerId"] = otherID
    }

    private func resultData(_ name: String) throws -> Data {
        let object = try XCTUnwrap(JSONSerialization.jsonObject(with: HouseTanksWireContractTests.data(name)) as? [String: Any])
        return try JSONSerialization.data(withJSONObject: try XCTUnwrap(object["payload"]))
    }

    private func frame(sequence: Int, tick: Int, epoch: Int = 7, id: String? = nil,
                       _ change: (inout [String: Any]) -> Void = { _ in }) throws -> String {
        try message("roundPlaying", id: id) { payload in
            payload["stateSequence"] = sequence
            payload["tick"] = tick
            payload["runtimeEpoch"] = epoch
            change(&payload)
        }
    }

    private func grant(epoch: Int, generation: String = "controlA") throws -> String {
        try message("controlGranted") { $0["runtimeEpoch"] = epoch; $0["controlGeneration"] = generation }
    }

    private func staleRejection(_ id: String) throws -> String {
        try message("rejected", id: id) { $0["error"] = ["code": "houseTanks.error.stale_control", "args": [], "retryable": false] }
    }

    private func explosion(_ sequence: Int, tick: Int) -> [String: Any] {
        ["sequence": sequence, "tick": tick, "kind": "explosion", "x": 400.0, "y": 200.0]
    }

    private func player(_ payload: inout [String: Any], _ index: Int, _ change: (inout [String: Any]) -> Void) {
        var players = payload["players"] as! [[String: Any]]
        change(&players[index])
        payload["players"] = players
    }

    private func tank(_ payload: inout [String: Any], _ index: Int, _ change: (inout [String: Any]) -> Void) {
        var tanks = payload["tanks"] as! [[String: Any]]
        change(&tanks[index])
        payload["tanks"] = tanks
    }

    /// A fixture message; `id` replaces its messageId (a rejection answering our press).
    private func message(_ name: String, id: String? = nil, _ change: (inout [String: Any]) -> Void = { _ in }) throws -> String {
        var object = try XCTUnwrap(JSONSerialization.jsonObject(with: HouseTanksWireContractTests.data(name, change)) as? [String: Any])
        if let id { object["messageId"] = id }
        if name == "rejected", var error = object["error"] as? [String: Any] {
            var payload: [String: Any] = ["error": error]
            change(&payload)
            error = payload["error"] as? [String: Any] ?? error
            object["error"] = error
        }
        return String(decoding: try JSONSerialization.data(withJSONObject: object), as: UTF8.self)
    }

    private func sentMessages(_ engine: HouseTanksOnlineEngine) throws -> [[String: Any]] {
        try engine.drainEffects().compactMap { effect in
            guard case .send(let text, _) = effect else { return nil }
            return try XCTUnwrap(JSONSerialization.jsonObject(with: Data(text.utf8)) as? [String: Any])
        }
    }

    private func presses(_ engine: HouseTanksOnlineEngine) -> [[String: Any]] {
        ((try? sentMessages(engine)) ?? []).filter { $0["type"] as? String == "houseTanks.press" }
            .compactMap { $0["payload"] as? [String: Any] }
    }

    private func types(_ engine: HouseTanksOnlineEngine) -> [String] {
        ((try? sentMessages(engine)) ?? []).compactMap { $0["type"] as? String }.filter { $0 != "realtime.ping" }
    }

    private func envelope(_ payload: [String: Any]) throws -> HTTPResponse {
        .init(statusCode: 200, headers: [:], body: try JSONSerialization.data(withJSONObject: ["success": true, "data": payload]))
    }

    private func sessionPayload(version: Int64) -> [String: Any] {
        [
            "sessionId": sessionID, "houseId": houseID, "gameKey": "houseTanks", "protocolVersion": 2,
            "mode": "realtime", "state": "running",
            "rules": ["minimumPlayers": 2, "maximumPlayers": 8, "readyWindowMilliseconds": 30_000, "countdownMilliseconds": 3_000],
            "players": [playerID, otherID, "507f1f77bcf86cd799439023"].map { id -> [String: Any] in
                ["playerId": id, "state": "playing", "joinedAt": "2026-10-24T12:00:00Z", "readyAt": NSNull(), "leftAt": NSNull()]
            },
            "createdBy": playerID, "createdAt": "2026-10-24T12:00:00Z", "updatedAt": "2026-10-24T12:00:30Z",
            "readyWindowEndsAt": NSNull(), "countdownEndsAt": NSNull(),
            "startedAt": "2026-10-24T12:00:33Z", "endedAt": NSNull(), "endReason": NSNull(), "version": version,
        ]
    }

    private func session(version: Int64, id: String? = nil) throws -> String {
        var message: [String: Any] = [
            "protocolVersion": 2, "type": "gameSession.snapshot", "sentAt": "2026-10-24T12:00:30.125Z", "sequence": version,
            "payload": sessionPayload(version: version),
        ]
        if let id { message["messageId"] = id }
        return String(decoding: try JSONSerialization.data(withJSONObject: message), as: UTF8.self)
    }
}
