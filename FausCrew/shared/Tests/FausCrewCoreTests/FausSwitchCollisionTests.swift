import XCTest
@testable import FausCrewCore

/// Robots are solid to each other: stacked, sole to sole or nose to tail, never inside.
final class FausSwitchCollisionTests: XCTestCase {
    private let course = FausSwitchCourse.standard
    private let height = FausSwitchMetrics.runnerHeight

    private func run(_ runners: inout [FausSwitchRunnerState], ticks: Range<Int64>, course: FausSwitchCourse? = nil) {
        for tick in ticks {
            FausSwitchPhysics.step(&runners, tick: tick, course: course ?? self.course)
            assertNoOverlap(runners, tick: tick)
        }
    }

    private func assertNoOverlap(_ runners: [FausSwitchRunnerState], tick: Int64, file: StaticString = #filePath,
                                 line: UInt = #line) {
        let bodies = FausSwitchPhysics.bodies(of: runners)
        for i in bodies.indices {
            for j in bodies.indices where j > i {
                guard let a = bodies[i], let b = bodies[j], a.intersects(b) else { continue }
                let overlapX = min(a.maxX, b.maxX) - max(a.minX, b.minX)
                let overlapY = min(a.maxY, b.maxY) - max(a.minY, b.minY)
                XCTAssertLessThan(min(overlapX, overlapY), 1e-6, "Robots \(i) and \(j) overlap at tick \(tick)",
                                  file: file, line: line)
            }
        }
    }

    func testRobotLandsOnAnotherRobotsHeadAndCanFlipFromIt() {
        let bottom = FausSwitchRunnerState.spawn(on: .down, x: 420)
        var top = bottom
        top.y += 90
        var runners = [top, bottom]
        run(&runners, ticks: 0..<60)
        XCTAssertEqual(runners[0].body.minY, runners[1].body.maxY, accuracy: 1e-9, "Stands on the other robot's head")
        XCTAssertEqual(runners[0].x, runners[1].x)
        XCTAssertTrue(runners.allSatisfy(\.isRunning))
        XCTAssertFalse(FausSwitchPhysics.isSupported(runners[0], course: course), "No course under the feet")
        XCTAssertTrue(FausSwitchPhysics.isSupported(runners, index: 0, course: course), "The head below is a surface")
        XCTAssertEqual(FausSwitchPhysics.flip(&runners, index: 0, course: course), .flipped)
    }

    func testOppositeGravityRobotsMeetSoleToSoleAndRunOnTogether() {
        var floor = FausSwitchRunnerState.spawn(on: .down, x: 420)
        var ceiling = FausSwitchRunnerState.spawn(on: .up, x: 420)
        XCTAssertEqual(FausSwitchPhysics.flip(&floor, course: course), .flipped)
        XCTAssertEqual(FausSwitchPhysics.flip(&ceiling, course: course), .flipped)
        var runners = [floor, ceiling]
        run(&runners, ticks: 0..<90)
        let lower = runners[0]
        let upper = runners[1]
        XCTAssertEqual(lower.gravity, .up)
        XCTAssertEqual(upper.gravity, .down)
        XCTAssertEqual(lower.body.maxY, upper.body.minY, accuracy: 1e-6, "Feet press against feet")
        XCTAssertGreaterThan(lower.body.minY, FausSwitchMetrics.floorSurface + 50, "They meet in mid-air")
        XCTAssertLessThan(upper.body.maxY, FausSwitchMetrics.ceilingSurface - 50)
        XCTAssertEqual(lower.x, 420 + FausSwitchMetrics.runSpeed * 0.75, accuracy: 1e-6, "Still running forward")
        XCTAssertTrue(FausSwitchPhysics.isSupported(runners, index: 0, course: course))
        XCTAssertTrue(FausSwitchPhysics.isSupported(runners, index: 1, course: course))

        // The upper one flips to the ceiling; the lower one, pulled up too, follows and
        // ends up hanging from its head.
        XCTAssertEqual(FausSwitchPhysics.flip(&runners, index: 1, course: course), .flipped)
        run(&runners, ticks: 90..<150)
        XCTAssertEqual(runners[1].body.maxY, FausSwitchMetrics.ceilingSurface, accuracy: 1e-6)
        XCTAssertEqual(runners[0].body.maxY, FausSwitchMetrics.ceilingSurface - height, accuracy: 1e-6,
                       "Hangs from the head of the robot on the ceiling")
    }

    func testFasterRobotBehindIsHeldBack() {
        let front = FausSwitchRunnerState.spawn(on: .down, x: 500)
        var rear = FausSwitchRunnerState.spawn(on: .down, x: 460)
        rear.boostedUntilTick = 200
        for order in [[front, rear], [rear, front]] {
            var runners = order
            run(&runners, ticks: 0..<90)
            let frontAfter = runners.max { $0.x < $1.x }!
            let rearAfter = runners.min { $0.x < $1.x }!
            XCTAssertEqual(frontAfter.x, 500 + FausSwitchMetrics.runSpeed * 0.75, accuracy: 1e-6, "Never pushed")
            // Nose to tail, at most one tick of travel apart (when the rear one moved first).
            XCTAssertLessThanOrEqual(rearAfter.body.maxX, frontAfter.body.minX + 1e-6)
            XCTAssertGreaterThan(rearAfter.body.maxX, frontAfter.body.minX - 2)
        }
    }

    func testFinishedOrCrashedRobotsNoLongerCollide() {
        var gone = FausSwitchRunnerState.spawn(on: .down, x: 500)
        FausSwitchPhysics.crash(&gone, reason: .boundary, at: 0)
        var runners = [gone, FausSwitchRunnerState.spawn(on: .down, x: 480)]
        FausSwitchPhysics.step(&runners, tick: 0, course: course)
        XCTAssertEqual(runners[1].x, 480 + FausSwitchMetrics.runSpeed * FausSwitchMetrics.tickDuration, accuracy: 1e-9)
    }

    func testEveryRobotStartsOnItsOwnPlatform() {
        for count in 1...FausSwitchStartGrid.maximumRunners {
            let lanes = FausSwitchStartGrid.lanes(count: count)
            let race = FausSwitchCourse.race(runnerCount: count)
            XCTAssertEqual(race.solids.filter { $0.kind == .platform }.map(\.rect), lanes.map(\.platform))
            XCTAssertEqual(race.version, FausSwitchCourse.currentVersion)
            let states = lanes.map(\.spawn)
            for (seat, lane) in lanes.enumerated() {
                XCTAssertEqual(lane.spawn.x, FausSwitchMetrics.spawnX, "Same start line")
                XCTAssertEqual(lane.gravity, seat.isMultiple(of: 2) ? .down : .up)
                XCTAssertTrue(lane.platform.intersects(FausSwitchPhysics.supportProbe(of: lane.spawn)), "Seat \(seat) of \(count)")
                XCTAssertGreaterThan(lane.platform.minY, FausSwitchMetrics.floorSurface)
                XCTAssertLessThan(lane.platform.maxY, FausSwitchMetrics.ceilingSurface)
                var depth = 0.0
                race.solids(near: lane.spawn.body) { solid in
                    let a = solid.rect, b = lane.spawn.body
                    guard a.intersects(b) else { return }
                    depth = max(depth, min(min(a.maxX, b.maxX) - max(a.minX, b.minX), min(a.maxY, b.maxY) - max(a.minY, b.minY)))
                }
                XCTAssertLessThan(depth, 1e-9, "Seat \(seat) of \(count) starts clear")
            }
            assertNoOverlap(states, tick: -1)
        }
        XCTAssertGreaterThan(FausSwitchStartGrid.lanes(count: 8)[1].spawn.y, FausSwitchStartGrid.lanes(count: 8)[7].spawn.y,
                             "Seat 1 is the highest lane")
    }

    func testTwoRobotStartMatchesTheProtocolFixture() {
        let lanes = FausSwitchStartGrid.lanes(count: 2)
        XCTAssertEqual(lanes.map(\.spawn.y), [114.1, 275.8])
    }

    func testRobotsLeaveTheirPlatformsAndLandOnTheRails() {
        let race = FausSwitchCourse.race(runnerCount: 2)
        var runners = FausSwitchStartGrid.lanes(count: 2).map(\.spawn)
        run(&runners, ticks: 0..<120, course: race)
        XCTAssertTrue(runners.allSatisfy(\.isRunning))
        XCTAssertEqual(runners[0].body.minY, FausSwitchMetrics.floorSurface, accuracy: 1e-6)
        XCTAssertEqual(runners[1].body.maxY, FausSwitchMetrics.ceilingSurface, accuracy: 1e-6)
    }

    func testFullDemoRaceNeverOverlapsRobots() {
        var match = FausSwitchBotMatch()
        match.start(configuration: .init(humanColor: .plum, botCount: 3, seed: 99))
        while match.phase == .countdown { match.advance(by: 1) }
        XCTAssertEqual(match.phase, .playing)
        var contacts = 0
        while match.phase == .playing {
            // The human taps now and then so robots meet in every way.
            if match.tick % 47 == 0 { match.flipHuman() }
            _ = match.stepOnce()
            let bodies = FausSwitchPhysics.bodies(of: match.runners.map(\.state)).compactMap { $0 }
            for a in bodies.indices { for b in bodies.indices where b > a {
                let one = bodies[a], two = bodies[b]
                let touchX = one.minX <= two.maxX + 1e-6 && two.minX <= one.maxX + 1e-6
                let touchY = one.minY <= two.maxY + 1e-6 && two.minY <= one.maxY + 1e-6
                if touchX && touchY { contacts += 1 }
            } }
            assertNoOverlap(match.runners.map(\.state), tick: match.tick)
        }
        XCTAssertGreaterThan(contacts, 100, "Robots met during the race")
        XCTAssertGreaterThan(match.runners.filter { $0.state.status == .finished }.count, 0, "Bots still get through")
    }
}
