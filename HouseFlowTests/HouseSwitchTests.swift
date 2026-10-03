import XCTest
@testable import HouseFlow

final class HouseSwitchTests: XCTestCase {
    func testSolidPlatformContactsAreNotLethal() {
        XCTAssertFalse(HouseSwitchSurfaceKind.solid.isLethal)
        XCTAssertFalse(HouseSwitchSurfaceKind.finish.isLethal)
        XCTAssertTrue(HouseSwitchSurfaceKind.laser.isLethal)
        XCTAssertTrue(HouseSwitchSurfaceKind.boundary.isLethal)

        XCTAssertFalse(HouseSwitchCollisionPolicy.isLethalContact(
            HouseSwitchPhysicsCategory.player,
            HouseSwitchPhysicsCategory.solid
        ))
        XCTAssertTrue(HouseSwitchCollisionPolicy.isLethalContact(
            HouseSwitchPhysicsCategory.player,
            HouseSwitchPhysicsCategory.hazard
        ))
        XCTAssertFalse(HouseSwitchCollisionPolicy.isLethalContact(
            HouseSwitchPhysicsCategory.solid,
            HouseSwitchPhysicsCategory.player
        ))
        XCTAssertTrue(HouseSwitchCollisionPolicy.isLethalContact(
            HouseSwitchPhysicsCategory.hazard,
            HouseSwitchPhysicsCategory.player
        ))
        XCTAssertTrue(HouseSwitchCollisionPolicy.isFinishContact(
            HouseSwitchPhysicsCategory.finish,
            HouseSwitchPhysicsCategory.player
        ))
        XCTAssertFalse(HouseSwitchCollisionPolicy.isLethalContact(
            HouseSwitchPhysicsCategory.finish,
            HouseSwitchPhysicsCategory.player
        ))
        XCTAssertTrue(HouseSwitchCollisionPolicy.isGapContact(
            HouseSwitchPhysicsCategory.player,
            HouseSwitchPhysicsCategory.gap
        ))
        XCTAssertTrue(HouseSwitchCollisionPolicy.isBoostContact(
            HouseSwitchPhysicsCategory.boost,
            HouseSwitchPhysicsCategory.player
        ))
        XCTAssertFalse(HouseSwitchCollisionPolicy.isLethalContact(
            HouseSwitchPhysicsCategory.player,
            HouseSwitchPhysicsCategory.boost
        ))
    }

    func testGravityAlwaysSwitchesToTheOppositeDirection() {
        XCTAssertEqual(HouseSwitchGravity.down.opposite, .up)
        XCTAssertEqual(HouseSwitchGravity.up.opposite, .down)
        XCTAssertEqual(HouseSwitchGravity.down.opposite.opposite, .down)
    }

    func testProgressIsClampedToTheCourse() {
        XCTAssertEqual(HouseSwitchRunMetrics.progress(position: -20, courseLength: 1_000), 0)
        XCTAssertEqual(HouseSwitchRunMetrics.progress(position: 500, courseLength: 1_000), 0.5)
        XCTAssertEqual(HouseSwitchRunMetrics.progress(position: 1_200, courseLength: 1_000), 1)
        XCTAssertEqual(HouseSwitchRunMetrics.progress(position: 20, courseLength: 0), 0)
    }

    func testRunnerFailsOnlyAfterCompletelyLeavingTheLeftEdge() {
        XCTAssertFalse(HouseSwitchRunMetrics.isCompletelyBehindViewport(
            playerCenterX: 17,
            playerWidth: 34,
            viewportMinX: 0
        ))
        XCTAssertTrue(HouseSwitchRunMetrics.isCompletelyBehindViewport(
            playerCenterX: -17,
            playerWidth: 34,
            viewportMinX: 0
        ))
        XCTAssertTrue(HouseSwitchRunMetrics.isCompletelyBehindViewport(
            playerCenterX: -24,
            playerWidth: 34,
            viewportMinX: 0
        ))
    }

    func testSupportProbeFollowsTheActiveGravitySurface() {
        let position = CGPoint(x: 100, y: 200)
        let size = CGSize(width: 34, height: 42)
        let downProbe = HouseSwitchSupportProbe.frame(
            playerPosition: position,
            playerSize: size,
            gravity: .down
        )
        let upProbe = HouseSwitchSupportProbe.frame(
            playerPosition: position,
            playerSize: size,
            gravity: .up
        )

        XCTAssertLessThan(downProbe.midY, position.y - size.height / 2)
        XCTAssertGreaterThan(upProbe.midY, position.y + size.height / 2)
        XCTAssertGreaterThan(downProbe.minX, position.x - size.width / 2)
        XCTAssertLessThan(downProbe.maxX, position.x + size.width / 2)
        XCTAssertEqual(downProbe.width, upProbe.width, accuracy: 0.001)

        let playerBottomY = position.y - size.height / 2
        let touchingFloor = CGRect(
            x: downProbe.minX,
            y: playerBottomY - 12,
            width: downProbe.width,
            height: 12
        )
        let floorWithOnePointGap = touchingFloor.offsetBy(dx: 0, dy: -1)

        XCTAssertTrue(downProbe.intersects(touchingFloor))
        XCTAssertFalse(downProbe.intersects(floorWithOnePointGap))
    }

    func testVerticalPhysicsKeepsAlternatingPlatformsReachableOnPhoneAndTablet() {
        let obstacleSpacing: CGFloat = 345

        for playfieldHeight: CGFloat in [390, 768] {
            let railToRailDistance = playfieldHeight * 0.86 - 42
            let travelTime = HouseSwitchPhysicsTuning.estimatedVerticalTravelTime(
                distance: railToRailDistance,
                playfieldHeight: playfieldHeight
            )
            let horizontalTravel = HouseSwitchPhysicsTuning.runSpeed * CGFloat(travelTime)

            XCTAssertLessThan(horizontalTravel, obstacleSpacing)
        }

        XCTAssertGreaterThan(
            HouseSwitchPhysicsTuning.switchVelocity(for: 768),
            HouseSwitchPhysicsTuning.switchVelocity(for: 390)
        )
    }

    func testPlatformHeightScalesWithThePlayfield() {
        let platform = HouseSwitchPlatformSpec(
            x: 400,
            width: 100,
            centerY: 0.25,
            heightRatio: 0.20
        )

        let phoneFrame = platform.frame(in: 800)
        let tabletFrame = platform.frame(in: 1_200)

        XCTAssertEqual(phoneFrame.midX, 400, accuracy: 0.001)
        XCTAssertEqual(phoneFrame.midY, 200, accuracy: 0.001)
        XCTAssertEqual(phoneFrame.height, 160, accuracy: 0.001)
        XCTAssertEqual(tabletFrame.midY, 300, accuracy: 0.001)
        XCTAssertEqual(tabletFrame.height, 240, accuracy: 0.001)
    }

    func testFirstCourseHasAReachableFinishAndExplicitHazards() {
        let level = HouseSwitchLevel.firstCourse

        XCTAssertEqual(level.length, 8_840)
        XCTAssertGreaterThanOrEqual(level.platforms.count, 20)
        XCTAssertEqual(level.lasers.count, 4)
        XCTAssertEqual(level.gaps.count, 4)
        XCTAssertEqual(level.boosts.count, 5)
        XCTAssertTrue(level.platforms.allSatisfy { $0.x >= 0 && $0.x <= level.length })
        XCTAssertTrue(level.lasers.allSatisfy { $0.x > 0 && $0.x < level.length })
        XCTAssertTrue(level.boosts.allSatisfy { $0.x > 0 && $0.x < level.length })
    }

    func testFloorAndCeilingGapsContainNoSolidRail() {
        let level = HouseSwitchLevel.firstCourse
        let railHeight: CGFloat = 390

        for gap in level.gaps {
            let centerY: CGFloat = gap.anchor == .floor ? 0.035 : 0.965
            let railFrames = level.platforms
                .filter { $0.centerY == centerY && $0.heightRatio == 0.07 }
                .map { $0.frame(in: railHeight) }
            let gapMidpoint = gap.startX + gap.width / 2

            XCTAssertTrue(gap.startX > 0 && gap.endX < level.length)
            XCTAssertFalse(railFrames.contains { $0.minX < gapMidpoint && $0.maxX > gapMidpoint })
            XCTAssertTrue(railFrames.contains { $0.maxX == gap.startX })
            XCTAssertTrue(railFrames.contains { $0.minX == gap.endX })
        }

        for boost in level.boosts {
            XCTAssertFalse(level.gaps.contains {
                $0.anchor == boost.anchor
                    && boost.x + boost.width / 2 > $0.startX
                    && boost.x - boost.width / 2 < $0.endX
            })
        }
    }

    func testRunClockExcludesPausedTimeAndCanRestart() {
        var clock = HouseSwitchRunClock()

        clock.start(at: 10)
        XCTAssertEqual(clock.elapsed(at: 13), 3, accuracy: 0.001)

        clock.pause(at: 13)
        XCTAssertEqual(clock.elapsed(at: 100), 3, accuracy: 0.001)

        clock.resume(at: 20)
        XCTAssertEqual(clock.elapsed(at: 25), 8, accuracy: 0.001)

        clock.start(at: 30)
        XCTAssertEqual(clock.elapsed(at: 31), 1, accuracy: 0.001)
    }
}
