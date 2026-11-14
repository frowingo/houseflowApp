import Foundation
import FausCrewCore
import XCTest

final class FausSwitchBotMatchTests: XCTestCase {
    func testStartBuildsHumanAndBotsWithDistinctColors() throws {
        for botCount in [0, 1, 2, 3, 9] {
            var match = FausSwitchBotMatch()
            match.start(configuration: .init(humanColor: .ocean, botCount: botCount, seed: 7))
            let bots = min(3, max(1, botCount))
            XCTAssertEqual(match.runners.count, bots + 1)
            XCTAssertEqual(match.human?.color, .ocean)
            XCTAssertEqual(Set(match.runners.map(\.color)).count, match.runners.count)
            XCTAssertEqual(match.phase, .countdown)
            XCTAssertEqual(match.countdown, 3)
        }
    }

    /// The demo has at most four robots, so they keep their full size (crowded races are
    /// online only); each stands on its own platform without touching, and the race runs
    /// to the end.
    func testDemoRobotsStartApartAtFullSizeAndRunToTheEnd() {
        for botCount in FausSwitchMatchConfiguration.botRange {
            var match = FausSwitchBotMatch()
            match.start(configuration: .init(humanColor: .plum, botCount: botCount, seed: 42))
            XCTAssertTrue(match.runners.allSatisfy { $0.state.scale == 1 })
            let bodies = match.runners.map(\.state.body)
            for i in bodies.indices {
                for j in bodies.indices where j > i { XCTAssertFalse(bodies[i].intersects(bodies[j])) }
            }
            XCTAssertTrue(match.runners.indices.allSatisfy {
                FausSwitchPhysics.isSupported(match.runners.map(\.state), index: $0, course: match.course)
            })
            for _ in 0..<(120 * 130) where match.phase != .ended { match.advance(by: 1.0 / 120) }
            XCTAssertEqual(match.phase, .ended)
            XCTAssertEqual(match.ranks.count, botCount + 1)
        }
    }

    func testCountdownThenPhysicsAndPause() {
        var match = FausSwitchBotMatch()
        match.start(configuration: .init(humanColor: .plum, botCount: 1, seed: 3))
        XCTAssertEqual(match.advance(by: 1.01), [.countdown(2)])
        XCTAssertEqual(match.flipHuman(), .notRunning, "No flips during the countdown")
        match.advance(by: 1)
        XCTAssertTrue(match.advance(by: 1).contains(.started))
        XCTAssertEqual(match.phase, .playing)
        match.pause()
        let tick = match.tick
        match.advance(by: 0.2)
        XCTAssertEqual(match.tick, tick)
        match.resume()
        match.advance(by: 0.1)
        XCTAssertGreaterThan(match.tick, tick)
    }

    func testHardBotFinishesTheWholeCourse() {
        var runner = FausSwitchRunnerState.spawn(on: .down)
        let course = FausSwitchCourse.standard
        let brain = FausSwitchBotBrain(skill: .hard)
        var random = FausSwitchRandom(seed: 11)
        var tick: Int64 = 0
        while runner.isRunning, tick < FausSwitchMetrics.maximumMatchTicks {
            if tick % brain.decisionInterval == 0, brain.wantsFlip(runner, tick: tick, course: course, random: &random) {
                FausSwitchPhysics.flip(&runner, course: course)
            }
            FausSwitchPhysics.step(&runner, tick: tick, course: course)
            tick += 1
        }
        XCTAssertEqual(runner.status, .finished, "Crashed at x \(runner.x) by \(String(describing: runner.crashReason))")
    }

    func testHardBotFinishesFromTheCeilingToo() {
        var runner = FausSwitchRunnerState.spawn(on: .up)
        let course = FausSwitchCourse.standard
        let brain = FausSwitchBotBrain(skill: .hard)
        var random = FausSwitchRandom(seed: 5)
        var tick: Int64 = 0
        while runner.isRunning, tick < FausSwitchMetrics.maximumMatchTicks {
            if tick % brain.decisionInterval == 0, brain.wantsFlip(runner, tick: tick, course: course, random: &random) {
                FausSwitchPhysics.flip(&runner, course: course)
            }
            FausSwitchPhysics.step(&runner, tick: tick, course: course)
            tick += 1
        }
        XCTAssertEqual(runner.status, .finished, "Crashed at x \(runner.x) by \(String(describing: runner.crashReason))")
    }

    func testIdleHumanIsLostAndMatchEndsWithRanks() {
        var match = FausSwitchBotMatch()
        match.start(configuration: .init(humanColor: .forest, botCount: 3, seed: 21))
        play(&match)
        var events: [FausSwitchMatchEvent] = []
        var guardTicks = 0
        while match.phase == .playing, guardTicks < Int(FausSwitchMetrics.maximumMatchTicks) {
            events += match.stepOnce()
            guardTicks += 1
        }
        XCTAssertEqual(match.phase, .ended)
        XCTAssertTrue(events.contains { if case .humanCrashed = $0 { true } else { false } })
        XCTAssertEqual(match.ranks.count, 4)
        XCTAssertEqual(match.human?.state.status, .crashed)
        XCTAssertTrue(match.runners.contains { $0.role == .bot && $0.state.status == .finished },
                      "At least one bot completes the course")
    }

    func testSameSeedSameRace() {
        func race() -> [FausSwitchRunnerState] {
            var match = FausSwitchBotMatch()
            match.start(configuration: .init(humanColor: .olive, botCount: 3, seed: 99))
            play(&match)
            for _ in 0..<1_200 { _ = match.stepOnce() }
            return match.runners.map(\.state)
        }
        XCTAssertEqual(race(), race())
    }

    /// Background planning only moves the bots' thinking off the frame; the race is the
    /// same whether answers arrive in time (idle waits) or not (no waits).
    func testPlannerGivesTheSameRace() {
        func race(planner: FausSwitchBotPlanner?, waits: Bool) -> [FausSwitchRunnerState] {
            var match = FausSwitchBotMatch(planner: planner)
            match.start(configuration: .init(humanColor: .olive, botCount: 3, seed: 1234))
            play(&match)
            for _ in 0..<4_000 {
                if waits { planner?.waitUntilIdle() }
                _ = match.stepOnce()
            }
            return match.runners.map(\.state)
        }
        let reference = race(planner: nil, waits: false)
        XCTAssertEqual(race(planner: FausSwitchBotPlanner(), waits: true), reference)
        XCTAssertEqual(race(planner: FausSwitchBotPlanner(), waits: false), reference)
    }

    private func play(_ match: inout FausSwitchBotMatch) {
        while match.phase == .countdown { match.advance(by: 0.5) }
        XCTAssertEqual(match.phase, .playing)
    }
}
