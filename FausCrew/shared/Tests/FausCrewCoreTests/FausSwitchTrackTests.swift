import XCTest
@testable import FausCrewCore

/// The course runs right, bends and climbs; physics stays in track coordinates.
final class FausSwitchTrackTests: XCTestCase {
    private let course = FausSwitchCourse.standard
    private var track: FausSwitchTrack { course.track }

    private func assertPose(_ a: FausSwitchPose, _ b: FausSwitchPose, accuracy: Double = 1e-6,
                            file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(a.x, b.x, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(a.y, b.y, accuracy: accuracy, file: file, line: line)
        XCTAssertEqual(a.angle, b.angle, accuracy: accuracy, file: file, line: line)
    }

    func testFirstStretchIsTheOldFlatCourse() {
        assertPose(track.pose(x: 380, y: 44.1), FausSwitchPose(x: 380, y: 44.1, angle: 0))
        assertPose(track.pose(x: 8_000, y: 300), FausSwitchPose(x: 8_000, y: 300, angle: 0))
    }

    func testBendIsContinuousAndTheClimbGoesUp() throws {
        let turn = try XCTUnwrap(track.turns.first)
        XCTAssertTrue(turn.isLeft)
        for y in [0.0, FausSwitchMetrics.floorSurface, 195, FausSwitchMetrics.ceilingSurface, 390] {
            assertPose(track.pose(x: turn.startX - 1e-9, y: y), track.pose(x: turn.startX + 1e-9, y: y), accuracy: 1e-5)
            assertPose(track.pose(x: turn.endX - 1e-9, y: y), track.pose(x: turn.endX + 1e-9, y: y), accuracy: 1e-5)
        }
        let start = track.pose(x: turn.endX, y: 195)
        let later = track.pose(x: turn.endX + 500, y: 195)
        XCTAssertEqual(later.x, start.x, accuracy: 1e-9, "Straight up")
        XCTAssertEqual(later.y - start.y, 500, accuracy: 1e-9)
        XCTAssertEqual(later.angle, .pi / 2, accuracy: 1e-12)

        // The floor rail becomes the right wall, the ceiling rail the left wall.
        let floorSide = track.pose(x: turn.endX + 200, y: FausSwitchMetrics.floorSurface)
        let ceilingSide = track.pose(x: turn.endX + 200, y: FausSwitchMetrics.ceilingSurface)
        XCTAssertGreaterThan(floorSide.x, ceilingSide.x)
        XCTAssertEqual(floorSide.x - ceilingSide.x, FausSwitchMetrics.ceilingSurface - FausSwitchMetrics.floorSurface,
                       accuracy: 1e-9, "The shaft is exactly as wide as the band")
        XCTAssertEqual(floorSide.y, ceilingSide.y, accuracy: 1e-9)

        // Mid-bend the robot faces diagonally up and to the right.
        XCTAssertEqual(track.pose(x: turn.startX + turn.length / 2, y: 195).angle, .pi / 4, accuracy: 1e-9)
    }

    func testClimbBendsAgainIntoARunToTheLeft() throws {
        XCTAssertEqual(track.turns.count, 2)
        let turn = track.turns[1]
        XCTAssertTrue(turn.isLeft)
        for y in [0.0, FausSwitchMetrics.floorSurface, 195, FausSwitchMetrics.ceilingSurface, 390] {
            assertPose(track.pose(x: turn.startX - 1e-9, y: y), track.pose(x: turn.startX + 1e-9, y: y), accuracy: 1e-5)
            assertPose(track.pose(x: turn.endX - 1e-9, y: y), track.pose(x: turn.endX + 1e-9, y: y), accuracy: 1e-5)
        }
        let start = track.pose(x: turn.endX, y: 195)
        let later = track.pose(x: turn.endX + 500, y: 195)
        XCTAssertEqual(later.x - start.x, -500, accuracy: 1e-9, "Straight to the left")
        XCTAssertEqual(later.y, start.y, accuracy: 1e-9)
        XCTAssertEqual(later.angle, .pi, accuracy: 1e-12)
        // Upside down: the floor rail is the top one, the ceiling rail the bottom one.
        let floorSide = track.pose(x: turn.endX + 200, y: FausSwitchMetrics.floorSurface)
        let ceilingSide = track.pose(x: turn.endX + 200, y: FausSwitchMetrics.ceilingSurface)
        XCTAssertEqual(floorSide.y - ceilingSide.y, FausSwitchMetrics.ceilingSurface - FausSwitchMetrics.floorSurface,
                       accuracy: 1e-9)
        // The leftward run passes high above the first stretch, never across the climb.
        XCTAssertGreaterThan(ceilingSide.y - 195, FausSwitchMetrics.worldHeight * 10)
        let climbLeftWall = track.pose(x: track.turns[0].endX + 100, y: FausSwitchMetrics.worldHeight).x
        XCTAssertLessThan(track.pose(x: turn.endX + 1, y: 0).x, climbLeftWall + 1)
    }

    func testCourseKeepsTheBendsClearAndEverySectionHasObstacles() throws {
        for turn in track.turns {
            let inBend = FausSwitchRect(minX: turn.startX, minY: FausSwitchMetrics.floorSurface + 0.01,
                                        maxX: turn.endX, maxY: FausSwitchMetrics.ceilingSurface - 0.01)
            XCTAssertFalse(course.overlapsSolid(inBend), "No blocks in the bend")
            XCTAssertFalse(course.portals.contains { $0.exitX > turn.startX - 50 && $0.x < turn.endX + 50 })
            XCTAssertFalse(course.slows.contains { $0.x > turn.startX - 50 && $0.x < turn.endX + 50 })
            XCTAssertFalse(course.gaps.contains { $0.maxX > turn.startX - 50 && $0.minX < turn.endX + 50 })
            XCTAssertFalse(course.boosts.contains { $0.x > turn.startX - 50 && $0.x < turn.endX + 50 })
        }
        let sections = [(track.turns[0].endX, track.turns[1].startX), (track.turns[1].endX, course.finishX)]
        for (start, end) in sections {
            let blocks = course.solids.filter { $0.kind == .block && $0.rect.minX > start && $0.rect.maxX < end }
            XCTAssertGreaterThanOrEqual(blocks.count, 15)
            XCTAssertTrue(course.gaps.contains { $0.minX > start && $0.maxX < end })
            XCTAssertTrue(course.portals.contains { $0.exitX > start && $0.x < end })
            XCTAssertTrue(course.slows.contains { $0.x > start && $0.x < end })
            XCTAssertTrue(course.boosts.contains { $0.x > start && $0.x < end })
        }
        XCTAssertGreaterThan(course.finishX, track.turns[1].endX + 4_000)
        XCTAssertLessThan(FausSwitchMetrics.seconds(FausSwitchMetrics.ticks((course.finishX - FausSwitchMetrics.spawnX)
                                                                            / FausSwitchMetrics.runSpeed)),
                          Double(FausSwitchMetrics.maximumMatchTicks) / Double(FausSwitchMetrics.physicsRate) - 30,
                          "Room to finish inside the time limit")
    }

    func testCameraTrailTightensThroughTheBendAndNeverGoesBack() throws {
        let turn = try XCTUnwrap(track.turns.first)
        XCTAssertEqual(course.cameraTrail(atTick: 0), 0, accuracy: 1e-9, "Same start as the flat course")
        XCTAssertEqual(FausSwitchCamera.behind(atX: turn.startX - 1, track: track), 380)
        XCTAssertEqual(FausSwitchCamera.behind(atX: turn.endX + 1, track: track), 140)
        XCTAssertEqual(FausSwitchCamera.behind(atX: track.turns[1].startX - 1, track: track), 140)
        XCTAssertEqual(FausSwitchCamera.behind(atX: track.turns[1].endX + 1, track: track), 380)
        var previous = -Double.infinity
        for tick in stride(from: Int64(0), through: FausSwitchMetrics.maximumMatchTicks, by: 7) {
            let trail = course.cameraTrail(atTick: tick)
            XCTAssertGreaterThanOrEqual(trail, previous)
            previous = trail
        }
        // At the end (a horizontal run) the camera stops with the finish line in view.
        let lastFocus = course.cameraFocus(atTick: FausSwitchMetrics.maximumMatchTicks)
        XCTAssertEqual(lastFocus, course.length - (FausSwitchMetrics.viewportWidth - FausSwitchCamera.horizontalBehind))
        XCTAssertLessThan(course.finishX, lastFocus + FausSwitchMetrics.viewportWidth - FausSwitchCamera.horizontalBehind)
    }

    func testCameraAnchorsTheRunOnEachKindOfStretch() throws {
        let viewport = FausSwitchViewport(screenWidth: 844, screenHeight: 390)
        let flat = FausSwitchCamera.view(focus: 2_000, track: track, viewport: viewport)
        XCTAssertEqual(flat.screenPoint(worldX: 2_000, worldY: 195).x, 380, accuracy: 1e-9)
        XCTAssertEqual(flat.screenPoint(worldX: 2_000, worldY: 195).y, 195, accuracy: 1e-9)
        XCTAssertEqual(flat.scale, 1)

        let turn = try XCTUnwrap(track.turns.first)
        let climbing = FausSwitchCamera.view(focus: turn.endX + 1_000, track: track, viewport: viewport)
        XCTAssertEqual(climbing.scale, FausSwitchCamera.verticalZoom)
        let focus = track.pose(x: turn.endX + 1_000, y: 195)
        let point = climbing.screenPoint(worldX: focus.x, worldY: focus.y)
        XCTAssertEqual(point.x, 422, accuracy: 1e-9, "The shaft is centered")
        XCTAssertEqual(point.y, 140 * FausSwitchCamera.verticalZoom, accuracy: 1e-9)
        // The trailing edge on screen is the trail line.
        let trail = track.pose(x: turn.endX + 1_000 - FausSwitchCamera.verticalBehind, y: 195)
        XCTAssertEqual(climbing.screenPoint(worldX: trail.x, worldY: trail.y).y, 0, accuracy: 1e-9)

        // Running left, the run sits 380 from the right edge.
        let left = FausSwitchCamera.view(focus: track.turns[1].endX + 800, track: track, viewport: viewport)
        XCTAssertEqual(left.scale, 1)
        let leftFocus = track.pose(x: track.turns[1].endX + 800, y: 195)
        XCTAssertEqual(left.screenPoint(worldX: leftFocus.x, worldY: leftFocus.y).x, 844 - 380, accuracy: 1e-9)
        XCTAssertEqual(left.screenPoint(worldX: leftFocus.x, worldY: leftFocus.y).y, 195, accuracy: 1e-9)

        // The camera moves smoothly through each bend and its approach.
        var previous: (x: Double, y: Double, scale: Double)?
        let from = track.turns[0].startX - 600
        for step in 0...Int((track.turns[1].endX + 600 - from) / 0.5) {
            let focus = from + Double(step) * 0.5
            let view = FausSwitchCamera.view(focus: focus, track: track, viewport: viewport)
            let point = track.pose(x: focus, y: 195)
            let screen = view.screenPoint(worldX: point.x, worldY: point.y)
            if let previous {
                XCTAssertEqual(screen.x, previous.x, accuracy: 1.5, "focus \(focus)")
                XCTAssertEqual(screen.y, previous.y, accuracy: 1.5, "focus \(focus)")
                XCTAssertEqual(view.scale, previous.scale, accuracy: 2e-3, "focus \(focus)")
            }
            previous = (screen.x, screen.y, view.scale)
            XCTAssertGreaterThan(view.scale, 0.65, "Bends zoom out only a little")
        }
    }

    func testEveryRobotStillInTheRaceIsOnScreen() {
        // Everything between the trail and the focus, on both rails, is in view, on
        // phones and tablets, through the whole course.
        for viewport in [FausSwitchViewport(screenWidth: 844, screenHeight: 390),
                         FausSwitchViewport(screenWidth: 852, screenHeight: 393),
                         FausSwitchViewport(screenWidth: 1194, screenHeight: 834)] {
            var focus = FausSwitchMetrics.spawnX
            while focus < course.length - FausSwitchCamera.horizontalAhead {
                let view = FausSwitchCamera.view(focus: focus, track: track, viewport: viewport)
                let trail = focus - FausSwitchCamera.behind(atX: focus, track: track)
                for along in stride(from: trail, through: focus, by: 20) {
                    for y in [0.0, FausSwitchMetrics.worldHeight] {
                        let pose = track.pose(x: along, y: y)
                        let screen = view.screenPoint(worldX: pose.x, worldY: pose.y)
                        XCTAssertTrue((-1e-6...viewport.screenWidth + 1e-6).contains(screen.x)
                                      && (-1e-6...viewport.screenHeight + 1e-6).contains(screen.y),
                                      "x \(along) off screen at focus \(focus)")
                    }
                }
                focus += 25
            }
        }
    }

    func testTurnsKeepEachRobotsShareOfTheMargin() {
        // A carry only in turns, and none on straights.
        XCTAssertEqual(FausSwitchCamera.turnCarry(front: 2_000, tick: 2_000, course: course), 0)
        for share in [0.2, 0.79, 0.97] {
            for gravity in [FausSwitchGravity.down, .up] {
                let first = track.turns[0]
                // Start early in the first bend (clear of the last blocks), `share` of the margin behind.
                let tick = FausSwitchMetrics.ticks((first.startX + 250 - FausSwitchMetrics.spawnX) / FausSwitchMetrics.runSpeed)
                let focus = course.cameraFocus(atTick: tick)
                var runner = FausSwitchRunnerState.spawn(on: gravity, x: 0)
                runner.x = focus - share * FausSwitchCamera.behind(atX: focus, track: track) - FausSwitchMetrics.runnerWidth / 2
                var now = tick
                func gapShare() -> Double {
                    let focus = course.cameraFocus(atTick: now)
                    return (focus - runner.body.maxX) / FausSwitchCamera.behind(atX: focus, track: track)
                }
                // Through the first bend into the climb.
                while course.cameraFocus(atTick: now) < first.endX + 20 {
                    FausSwitchPhysics.step(&runner, tick: now, course: course)
                    now += 1
                    XCTAssertTrue(runner.isRunning, "A bend alone never eliminates (share \(share))")
                    XCTAssertEqual(gapShare(), share, accuracy: 0.01)
                }
                XCTAssertEqual(course.cameraFocus(atTick: now) - runner.body.maxX, share * 140, accuracy: 4)
            }
        }
        // Through the second bend the distance comes back.
        let second = track.turns[1]
        let tick = FausSwitchMetrics.ticks((second.startX - 100 - FausSwitchMetrics.spawnX) / FausSwitchMetrics.runSpeed)
        var runner = FausSwitchRunnerState.spawn(on: .down, x: 0)
        runner.x = course.cameraFocus(atTick: tick) - 0.79 * 140 - FausSwitchMetrics.runnerWidth / 2
        var now = tick
        while course.cameraFocus(atTick: now) < second.endX + 20 {
            FausSwitchPhysics.step(&runner, tick: now, course: course)
            now += 1
            XCTAssertTrue(runner.isRunning)
        }
        XCTAssertEqual(course.cameraFocus(atTick: now) - runner.body.maxX, 0.79 * 380, accuracy: 4)

        // A robot ahead of the focus (after a boost) keeps its share of the view ahead.
        let first = track.turns[0]
        let start = FausSwitchMetrics.ticks((first.startX - 300 - FausSwitchMetrics.spawnX) / FausSwitchMetrics.runSpeed)
        var leader = FausSwitchRunnerState.spawn(on: .down, x: 0)
        leader.x = course.cameraFocus(atTick: start) + 100 - FausSwitchMetrics.runnerWidth / 2
        now = start
        while course.cameraFocus(atTick: now) < first.endX + 20 {
            FausSwitchPhysics.step(&leader, tick: now, course: course)
            now += 1
        }
        XCTAssertEqual(leader.body.maxX - course.cameraFocus(atTick: now),
                       100 * FausSwitchCamera.verticalAhead / FausSwitchCamera.horizontalAhead, accuracy: 3)
    }

    func testRaceCoursesKeepTheTrack() {
        XCTAssertEqual(FausSwitchCourse.race(runnerCount: 4).track, track)
    }
}
