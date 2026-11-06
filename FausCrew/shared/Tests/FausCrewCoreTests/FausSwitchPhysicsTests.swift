import Foundation
import FausCrewCore
import XCTest

final class FausSwitchPhysicsTests: XCTestCase {
    private let course = FausSwitchCourse.standard

    func testGravityAlwaysSwitchesToTheOppositeDirection() {
        XCTAssertEqual(FausSwitchGravity.down.opposite, .up)
        XCTAssertEqual(FausSwitchGravity.up.opposite.opposite, .up)
        XCTAssertEqual(FausSwitchGravity.down.sign, -1)
    }

    func testRobotIsThirtyPercentSmallerThanTheSoloHouse() {
        XCTAssertEqual(FausSwitchMetrics.runnerWidth, 34 * 0.8, accuracy: 0.0001)
        XCTAssertEqual(FausSwitchMetrics.runnerHeight, 42 * 0.8, accuracy: 0.0001)
    }

    func testRunKeepsConstantSpeedAndRestsOnTheFloor() {
        var runner = FausSwitchRunnerState.spawn(on: .down)
        for tick in 0..<120 { FausSwitchPhysics.step(&runner, tick: Int64(tick), course: course) }
        XCTAssertEqual(runner.status, .running)
        XCTAssertEqual(runner.x, FausSwitchMetrics.spawnX + FausSwitchMetrics.runSpeed, accuracy: 0.01)
        XCTAssertEqual(runner.body.minY, FausSwitchMetrics.floorSurface, accuracy: 0.0001)
        XCTAssertTrue(FausSwitchPhysics.isSupported(runner, course: course))
    }

    func testFlipNeedsASurfaceAndLaunchesWithTheSoloVelocity() {
        var runner = FausSwitchRunnerState.spawn(on: .down)
        XCTAssertEqual(FausSwitchPhysics.flip(&runner, course: course), .flipped)
        XCTAssertEqual(runner.gravity, .up)
        XCTAssertEqual(runner.velocityY, FausSwitchMetrics.switchVelocity)
        FausSwitchPhysics.step(&runner, tick: 0, course: course)
        XCTAssertEqual(FausSwitchPhysics.flip(&runner, course: course), .unsupported, "Mid-air taps are ignored")
        XCTAssertEqual(runner.gravity, .up)
    }

    func testFlipCrossesThePlayfieldInAboutPointFourSeconds() {
        var runner = FausSwitchRunnerState.spawn(on: .down)
        FausSwitchPhysics.flip(&runner, course: course)
        var tick: Int64 = 0
        while !FausSwitchPhysics.isSupported(runner, course: course) || runner.body.maxY < FausSwitchMetrics.ceilingSurface - 0.01 {
            FausSwitchPhysics.step(&runner, tick: tick, course: course)
            tick += 1
            XCTAssertLessThan(tick, 120)
        }
        // Softer than the solo build's 0.34 s.
        XCTAssertEqual(FausSwitchMetrics.seconds(tick), 0.375, accuracy: 0.02)
        XCTAssertEqual(runner.velocityY, 0)
    }

    func testFlipKeepsAShareOfAFastVerticalSpeed() {
        var runner = FausSwitchRunnerState(x: 500, y: 200, velocityY: -1_200, gravity: .down)
        runner.y = FausSwitchMetrics.floorSurface + FausSwitchMetrics.runnerHeight / 2
        XCTAssertEqual(FausSwitchPhysics.flip(&runner, course: course), .flipped)
        XCTAssertEqual(runner.velocityY, 1_200 * FausSwitchMetrics.flipCarry, accuracy: 0.0001)
    }

    func testSolidFrontFaceBlocksButNeverKills() throws {
        let wall = try XCTUnwrap(course.solids.first { $0.kind == .block && $0.rect.minY <= 0 })
        var runner = FausSwitchRunnerState.spawn(on: .down, x: wall.rect.minX - 40)
        let startTick = FausSwitchMetrics.ticks((runner.x - FausSwitchMetrics.spawnX) / FausSwitchMetrics.runSpeed)
        for offset in 0..<60 { FausSwitchPhysics.step(&runner, tick: startTick + Int64(offset), course: course) }
        XCTAssertEqual(runner.status, .running)
        XCTAssertEqual(runner.body.maxX, wall.rect.minX, accuracy: 0.001)
        XCTAssertTrue(FausSwitchPhysics.isSupported(runner, course: course), "A blocked robot can still flip")
    }

    func testBlockedRobotIsLostOnlyAfterLeavingTheCameraCompletely() throws {
        let wall = try XCTUnwrap(course.solids.first { $0.kind == .block && $0.rect.minY <= 0 })
        var runner = FausSwitchRunnerState.spawn(on: .down, x: wall.rect.minX - 20)
        var tick = FausSwitchMetrics.ticks((runner.x - FausSwitchMetrics.spawnX) / FausSwitchMetrics.runSpeed)
        while runner.isRunning {
            FausSwitchPhysics.step(&runner, tick: tick, course: course)
            tick += 1
        }
        XCTAssertEqual(runner.crashReason, .leftBehind)
        XCTAssertLessThanOrEqual(runner.body.maxX, course.cameraTrail(atTick: tick))
        XCTAssertGreaterThan(runner.body.maxX, course.cameraTrail(atTick: tick - 1))
    }

    func testFloorGapDropsARobotOffScreen() throws {
        let gap = try XCTUnwrap(course.gaps.first { $0.rail == .down })
        var runner = FausSwitchRunnerState.spawn(on: .down, x: gap.minX - 30)
        var tick = FausSwitchMetrics.ticks((runner.x - FausSwitchMetrics.spawnX) / FausSwitchMetrics.runSpeed)
        while runner.isRunning, tick < 100_000 {
            FausSwitchPhysics.step(&runner, tick: tick, course: course)
            tick += 1
        }
        XCTAssertEqual(runner.crashReason, .boundary)
    }

    func testBoostPadsFloatClearOfTheRails() {
        for pad in course.boosts {
            XCTAssertGreaterThan(pad.rect.minY, FausSwitchMetrics.floorSurface + FausSwitchMetrics.runnerHeight,
                                 "Pad \(pad.id) is out of reach from the floor")
            XCTAssertLessThan(pad.rect.maxY, FausSwitchMetrics.ceilingSurface - FausSwitchMetrics.runnerHeight,
                              "Pad \(pad.id) is out of reach from the ceiling")
            XCTAssertFalse(course.overlapsSolid(pad.rect))
        }
        // Running along a rail never touches a pad.
        for rail in [FausSwitchGravity.down, .up] {
            var runner = FausSwitchRunnerState.spawn(on: rail, x: course.boosts[0].x - 120)
            var tick = FausSwitchMetrics.ticks((runner.x - FausSwitchMetrics.spawnX) / FausSwitchMetrics.runSpeed)
            for _ in 0..<80 { FausSwitchPhysics.step(&runner, tick: tick, course: course); tick += 1 }
            XCTAssertTrue(runner.usedBoosts.isEmpty)
        }
    }

    func testBoostPadWorksOncePerRobot() throws {
        let pad = try XCTUnwrap(course.boosts.first)
        // Mid-flip through the pad: falling from just above it.
        var runner = FausSwitchRunnerState(x: pad.x - 40, y: pad.y + 40, gravity: .down)
        var tick = FausSwitchMetrics.ticks((runner.x - FausSwitchMetrics.spawnX) / FausSwitchMetrics.runSpeed)
        var boostedTicks = 0
        for _ in 0..<200 {
            FausSwitchPhysics.step(&runner, tick: tick, course: course)
            tick += 1
            if runner.isBoosted(atTick: tick) { boostedTicks += 1 }
        }
        XCTAssertEqual(runner.usedBoosts, [pad.id])
        XCTAssertEqual(Int64(boostedTicks), FausSwitchMetrics.boostTicks)
    }

    private func run(_ runner: inout FausSwitchRunnerState, from x: Double, ticks: Int) -> Int64 {
        var tick = FausSwitchMetrics.ticks((x - FausSwitchMetrics.spawnX) / FausSwitchMetrics.runSpeed)
        for _ in 0..<ticks { FausSwitchPhysics.step(&runner, tick: tick, course: course); tick += 1 }
        return tick
    }

    func testPortalSendsTheRobotBackOnTheOtherRail() throws {
        for portal in course.portals {
            var runner = FausSwitchRunnerState.spawn(on: portal.rail, x: portal.x - 40)
            var tick = FausSwitchMetrics.ticks((runner.x - FausSwitchMetrics.spawnX) / FausSwitchMetrics.runSpeed)
            var teleported = false
            for _ in 0..<40 {
                let before = runner.x
                FausSwitchPhysics.step(&runner, tick: tick, course: course)
                tick += 1
                if runner.x < before {
                    teleported = true
                    XCTAssertEqual(runner.x, portal.exitX, accuracy: 1e-9, "Portal \(portal.id)")
                    XCTAssertEqual(runner.gravity, portal.rail.opposite)
                    XCTAssertEqual(runner.velocityY, 0)
                    XCTAssertTrue(FausSwitchPhysics.isSupported(runner, course: course), "Lands on the other rail")
                    break
                }
            }
            XCTAssertTrue(teleported, "Portal \(portal.id) catches a robot running on its rail")
            XCTAssertEqual(runner.status, .running)
            // The robot runs on from the exit without falling or meeting another portal.
            for _ in 0..<120 { FausSwitchPhysics.step(&runner, tick: tick, course: course); tick += 1 }
            XCTAssertEqual(runner.status, .running, "Portal \(portal.id) exit is safe")
            XCTAssertEqual(runner.gravity, portal.rail.opposite)
        }
    }

    func testPortalLeavesTheOtherRailAlone() throws {
        let portal = try XCTUnwrap(course.portals.first)
        var runner = FausSwitchRunnerState.spawn(on: portal.rail.opposite, x: portal.x - 40)
        _ = run(&runner, from: runner.x, ticks: 60)
        XCTAssertGreaterThan(runner.x, portal.x + 40)
        XCTAssertEqual(runner.gravity, portal.rail.opposite)
    }

    func testPortalIsJustBigEnoughForARobot() {
        XCTAssertGreaterThan(FausSwitchPortal.height, FausSwitchMetrics.runnerHeight)
        XCTAssertLessThan(FausSwitchPortal.height, FausSwitchMetrics.runnerHeight * 1.3)
        for portal in course.portals {
            XCTAssertLessThan(portal.exitX, portal.x, "Exits are behind the portal")
            XCTAssertFalse(course.overlapsSolid(portal.opening), "Portal \(portal.id) is clear of blocks")
            let exit = FausSwitchRect(centerX: portal.exitX, centerY: portal.exitY,
                                      width: FausSwitchMetrics.runnerWidth, height: FausSwitchMetrics.runnerHeight)
            XCTAssertFalse(course.overlapsSolid(exit), "Portal \(portal.id) exit is clear")
            XCTAssertFalse(course.gaps.contains { $0.sensor.intersects(exit) || ($0.rail == portal.exitGravity
                && $0.maxX > exit.minX - 40 && $0.minX < exit.maxX + 40) })
            XCTAssertFalse(course.portals.contains { $0.opening.intersects(exit) })
            // Every possible landing, from the exit up to the portal, is on clear rail.
            let stretch = FausSwitchRect(minX: portal.exitX - FausSwitchMetrics.runnerWidth / 2, minY: exit.minY + 0.01,
                                         maxX: portal.x, maxY: exit.maxY - 0.01)
            XCTAssertFalse(course.overlapsSolid(stretch), "Portal \(portal.id) landing stretch is clear")
            XCTAssertFalse(course.gaps.contains { $0.rail == portal.exitGravity
                && $0.maxX > stretch.minX - 40 && $0.minX < stretch.maxX + 40 })
            XCTAssertFalse(course.slows.contains { $0.rect.intersects(stretch) }, "Portal \(portal.id) landing has no slow pad")
            // A real throw back: 220 on the runs, 100 on the climb.
            let climbing = portal.x > course.track.turns[0].endX && portal.x < course.track.turns[1].startX
            XCTAssertGreaterThanOrEqual(portal.x - portal.exitX, climbing ? 100 : 220, "Portal \(portal.id)")
        }

    func testPortalNeverDropsARobotBehindTheTrail() throws {
        // A robot that reaches a climb portal at the very edge of the view lands just in
        // front of the trail instead of being lost.
        let portal = try XCTUnwrap(course.portals.first { $0.x > course.track.turns[0].endX && $0.x < course.track.turns[1].startX })
        var runner = FausSwitchRunnerState.spawn(on: portal.rail, x: portal.x - 30)
        // Start so the robot's front is 120 of the climb's 140 behind the focus.
        let focus = runner.body.maxX + 120
        var tick = FausSwitchMetrics.ticks((focus - FausSwitchMetrics.spawnX) / FausSwitchMetrics.runSpeed)
        var landed = false
        for _ in 0..<40 {
            let before = runner.x
            FausSwitchPhysics.step(&runner, tick: tick, course: course)
            tick += 1
            if runner.x < before {
                landed = true
                XCTAssertGreaterThan(runner.x, portal.exitX, "Pulled forward of the fixed exit")
                break
            }
        }
        XCTAssertTrue(landed)
        for _ in 0..<60 { FausSwitchPhysics.step(&runner, tick: tick, course: course); tick += 1 }
        XCTAssertEqual(runner.status, .running)
    }
    }

    func testSlowPadSlowsOncePerRobot() throws {
        let pad = try XCTUnwrap(course.slows.first { $0.y < 100 })
        let start = pad.x - 60
        var slowed = FausSwitchRunnerState.spawn(on: .down, x: start)
        var free = FausSwitchRunnerState.spawn(on: .up, x: start)
        _ = run(&slowed, from: start, ticks: 130)
        _ = run(&free, from: start, ticks: 20)
        XCTAssertEqual(slowed.usedSlows, [pad.id])
        XCTAssertTrue(free.usedSlows.isEmpty, "The pad lies on the floor; the ceiling is clear")
        let lost = FausSwitchMetrics.slowPenalty * FausSwitchMetrics.seconds(FausSwitchMetrics.slowTicks)
        XCTAssertEqual(start + FausSwitchMetrics.runSpeed * FausSwitchMetrics.seconds(130) - slowed.x, lost, accuracy: 0.01)
    }

    func testSlowPadsSitClearOfBlocksAndBoosts() {
        for pad in course.slows {
            var inner = pad.rect
            inner.minY += 0.01; inner.maxY -= 0.01
            XCTAssertFalse(course.overlapsSolid(inner), "Slow pad \(pad.id) is clear of solids")
            XCTAssertFalse(course.boosts.contains { $0.rect.intersects(pad.rect) })
            XCTAssertFalse(course.gaps.contains { $0.maxX > pad.rect.minX && $0.minX < pad.rect.maxX })
        }
        XCTAssertGreaterThanOrEqual(course.slows.count, 10)
        // Pads are tall targets, about as high as a robot's body is wide.
        XCTAssertGreaterThanOrEqual(FausSwitchSlowPad.height, FausSwitchMetrics.runnerWidth)
        XCTAssertGreaterThanOrEqual(FausSwitchBoostPad.height, FausSwitchMetrics.runnerWidth)
    }

    func testCourseUsesSplitGroupsInsteadOfSingleColumns() {
        let blocks = course.solids.filter { $0.kind == .block }
        // Groups are blocks within 200 units of each other; every group has two or three.
        var groups: [[FausSwitchSolid]] = []
        for block in blocks.sorted(by: { $0.rect.minX < $1.rect.minX }) {
            if let last = groups.last?.last, block.rect.minX - last.rect.maxX < 200 {
                groups[groups.count - 1].append(block)
            } else {
                groups.append([block])
            }
        }
        XCTAssertGreaterThanOrEqual(groups.count, 10)
        XCTAssertTrue(groups.allSatisfy { (2...3).contains($0.count) })
        XCTAssertTrue(blocks.contains { $0.rect.minY > 0 && $0.rect.maxY < FausSwitchMetrics.worldHeight },
                      "Floating blocks split the screen")
    }

    func testRankingOrdersFinishersThenLaterCrashes() {
        func state(_ status: FausSwitchRunnerStatus, finished: Int64? = nil, crashed: Int64? = nil) -> FausSwitchRunnerState {
            FausSwitchRunnerState(x: 0, y: 0, gravity: .down, status: status, finishedAtTick: finished, crashedAtTick: crashed)
        }
        let ranks = FausSwitchRanking.ranks([
            ("a", state(.crashed, crashed: 500)), ("b", state(.finished, finished: 4_000)),
            ("c", state(.finished, finished: 4_000)), ("d", state(.crashed, crashed: 900)),
        ])
        XCTAssertEqual(ranks, ["b": 1, "c": 1, "d": 3, "a": 4])
    }
}
