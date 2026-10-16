import Foundation
import HouseFlowCore
import XCTest

final class HouseRocketsBotMatchTests: XCTestCase {
    func testStartBuildsHumanAndBotsInColorOrder() throws {
        for botCount in [0, 1, 2, 3, 7] {
            var match = HouseRocketsBotMatch()
            match.start(configuration: .init(botCount: botCount))
            let snapshot = try XCTUnwrap(match.snapshot)
            let bots = min(3, max(1, botCount))
            XCTAssertEqual(snapshot.players.count, bots + 1)
            XCTAssertEqual(snapshot.players.map(\.role), [.human] + Array(repeating: .bot, count: bots))
            XCTAssertEqual(snapshot.players.map(\.color), Array(HouseRocketsColor.allCases.prefix(bots + 1)))
            XCTAssertEqual(snapshot.players.map(\.nameKey),
                           ["house_rockets_you"] + Array(HouseRocketsBotMatch.botNameKeys.prefix(bots)))
            XCTAssertEqual(snapshot.phase, .countdown)
            XCTAssertEqual(snapshot.countdown, 3)
            XCTAssertEqual(snapshot.revision, 1)
            XCTAssertFalse(snapshot.gates.isEmpty)
            XCTAssertTrue(snapshot.players.allSatisfy { $0.worldX == HouseRocketsSimulation.spawnX })
        }
    }

    func testCountdownStepsThreeTwoOneThenPlays() throws {
        var match = HouseRocketsBotMatch()
        match.start(configuration: .demo)
        XCTAssertFalse(match.advanceCountdown())
        XCTAssertEqual(match.snapshot?.countdown, 2)
        XCTAssertFalse(match.advanceCountdown())
        XCTAssertEqual(match.snapshot?.countdown, 1)
        XCTAssertTrue(match.advanceCountdown())
        XCTAssertEqual(match.phase, .playing)
        XCTAssertNil(match.snapshot?.countdown)
        XCTAssertFalse(match.advanceCountdown(), "No countdown step while playing")
        XCTAssertEqual(match.snapshot?.revision, 4)
    }

    func testPhysicsOnlyRunsWhilePlaying() throws {
        var match = HouseRocketsBotMatch()
        match.start(configuration: .demo)
        XCTAssertEqual(match.advance(by: 1), [])
        XCTAssertEqual(match.snapshot?.elapsedTime, 0)
        play(&match)
        match.advance(by: 0.1)
        XCTAssertEqual(try XCTUnwrap(match.snapshot?.elapsedTime), 0.1, accuracy: 0.000_1)
    }

    func testHumanSteeringRequiresPlayingLiveHumanAndIncreasingSequence() throws {
        var match = HouseRocketsBotMatch()
        match.start(configuration: .demo)
        let snapshot = try XCTUnwrap(match.snapshot)
        let human = try XCTUnwrap(snapshot.humanPlayer)
        let bot = try XCTUnwrap(snapshot.players.last)
        func steer(_ player: UUID?, _ sequence: Int, _ heading: Double = 0.4, match matchID: UUID? = nil) -> Bool {
            match.send(.init(matchID: matchID ?? snapshot.matchID, playerID: player, sequence: sequence,
                             action: .steer(heading: heading)))
        }
        XCTAssertFalse(steer(human.id, 1), "Countdown ignores steering")
        play(&match)
        XCTAssertFalse(steer(bot.id, 1), "Bots are not human controlled")
        XCTAssertFalse(steer(nil, 1))
        XCTAssertFalse(steer(human.id, 1, match: UUID()), "Stale match")
        XCTAssertFalse(steer(human.id, 1, .nan))
        XCTAssertTrue(steer(human.id, 1))
        XCTAssertFalse(steer(human.id, 1), "Duplicate sequence")
        XCTAssertFalse(steer(human.id, 0), "Older sequence")
        XCTAssertTrue(steer(human.id, 2))
    }

    func testPauseAndResumeKeepThePausedPhase() throws {
        var match = HouseRocketsBotMatch()
        match.start(configuration: .demo)
        match.advanceCountdown()
        XCTAssertTrue(match.pause())
        XCTAssertEqual(match.phase, .paused)
        XCTAssertFalse(match.pause())
        XCTAssertFalse(match.advanceCountdown(), "Paused countdown does not step")
        XCTAssertEqual(match.resume(), .countdown)
        XCTAssertEqual(match.snapshot?.countdown, 2, "Countdown continues from its value")
        play(&match)
        match.advance(by: 0.2)
        let elapsed = try XCTUnwrap(match.snapshot?.elapsedTime)
        XCTAssertTrue(match.pause())
        match.advance(by: 1)
        XCTAssertEqual(match.snapshot?.elapsedTime, elapsed)
        XCTAssertEqual(match.resume(), .playing)
        XCTAssertNil(match.resume())
    }

    func testHumanFlyingBackwardsIsEliminatedAndBotsFinishTheMatch() throws {
        var match = HouseRocketsBotMatch()
        match.start(configuration: .init(botCount: 1))
        play(&match)
        let snapshot = try XCTUnwrap(match.snapshot)
        let human = try XCTUnwrap(snapshot.humanPlayer)
        XCTAssertTrue(match.send(.init(matchID: snapshot.matchID, playerID: human.id, sequence: 1,
                                       action: .steer(heading: .pi))))
        var eliminatedHuman = false
        for _ in 0..<(60 * 120) where match.phase == .playing {
            if match.advance(by: 1.0 / 60).contains(human.id) { eliminatedHuman = true }
        }
        let final = try XCTUnwrap(match.snapshot)
        XCTAssertTrue(eliminatedHuman)
        XCTAssertEqual(final.phase, .ended)
        XCTAssertEqual(final.lastEliminatedID, human.id)
        XCTAssertEqual(final.winnerID, final.players.last?.id, "The bot outlives a backwards human")
        XCTAssertEqual(final.aliveCount, 1)
        XCTAssertEqual(match.advance(by: 1), [], "An ended match does not move")
    }

    func testRestartIsAcceptedOnlyAfterTheMatchEnded() throws {
        var match = HouseRocketsBotMatch()
        match.start(configuration: .init(botCount: 2))
        let first = try XCTUnwrap(match.snapshot)
        XCTAssertFalse(match.send(.init(matchID: first.matchID, playerID: nil, sequence: 0, action: .restart)))
        play(&match)
        let human = try XCTUnwrap(first.humanPlayer)
        match.send(.init(matchID: first.matchID, playerID: human.id, sequence: 1, action: .steer(heading: .pi)))
        for _ in 0..<(60 * 300) where match.phase == .playing { match.advance(by: 1.0 / 60) }
        XCTAssertEqual(match.phase, .ended)
        XCTAssertTrue(match.send(.init(matchID: first.matchID, playerID: nil, sequence: 0, action: .restart)))
        let second = try XCTUnwrap(match.snapshot)
        XCTAssertNotEqual(second.matchID, first.matchID)
        XCTAssertEqual(second.phase, .countdown)
        XCTAssertEqual(second.players.count, 3, "Restart keeps the bot count")
    }

    func testLocalRenderFrameUsesCourseRelativeHeadingsAndStringIdentities() throws {
        var match = HouseRocketsBotMatch()
        match.start(configuration: .demo)
        play(&match)
        for _ in 0..<(60 * 26) where match.phase == .playing { match.advance(by: 1.0 / 60) }
        let snapshot = try XCTUnwrap(match.snapshot)
        let frame = HouseRocketsRenderFrame.local(snapshot)
        XCTAssertEqual(frame.sessionID, snapshot.matchID.uuidString)
        XCTAssertEqual(frame.courseAngle, HouseRocketsCourse.angle(at: snapshot.elapsedTime))
        XCTAssertEqual(frame.players.map(\.id), snapshot.players.map(\.id.uuidString))
        XCTAssertEqual(frame.players.first?.name, .localizationKey("house_rockets_you"))
        for (player, rendered) in zip(snapshot.players, frame.players) {
            let expected = player.heading - frame.courseAngle
            XCTAssertEqual(cos(rendered.courseHeading), cos(expected), accuracy: 0.000_1)
            XCTAssertEqual(sin(rendered.courseHeading), sin(expected), accuracy: 0.000_1)
        }
        XCTAssertEqual(frame.gates.map(\.id), snapshot.gates.map(\.id.uuidString))
        XCTAssertEqual(frame.speedFields.count, snapshot.speedFields.count)
    }

    func testProjectionInformationRegionsAreHiddenWhileTurning() {
        let steady = HouseRocketsProjection(elapsedTime: 10, cameraX: 0, width: 844, height: 390)
        let regions = steady.informationRegions(width: 844, height: 390)
        XCTAssertEqual(regions.count, 2)
        XCTAssertEqual(regions[0], HouseRocketsRect(x: 202, y: 8, width: 440, height: 44))
        XCTAssertEqual(regions[1].maxY, 382)
        let turning = HouseRocketsProjection(elapsedTime: 26, cameraX: 0, width: 844, height: 390)
        XCTAssertTrue(turning.informationRegions(width: 844, height: 390).isEmpty)
    }

    private func play(_ match: inout HouseRocketsBotMatch) {
        while match.phase == .countdown { match.advanceCountdown() }
    }
}
