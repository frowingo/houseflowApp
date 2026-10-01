import XCTest
@testable import HouseFlow

final class HouseRocketsTests: XCTestCase {
    func testFullCircleSteeringKeepsEqualSpeedWithoutFurtherInput() {
        for degrees in stride(from: -180, through: 180, by: 15) {
            var world = makeWorld()
            let before = world.bodies
            let heading = Double(degrees) * .pi / 180
            for body in before { world.steer(playerID: body.id, heading: heading) }
            advance(&world, seconds: 0.2)
            for (start, end) in zip(before, world.bodies) {
                XCTAssertEqual(end.x - start.x, cos(heading) * (HouseRocketsSimulation.speed * 0.2), accuracy: 0.0001)
                XCTAssertEqual(end.y - start.y, sin(heading) * (HouseRocketsSimulation.speed * 0.2), accuracy: 0.0001)
                XCTAssertEqual(hypot(end.x - start.x, end.y - start.y), HouseRocketsSimulation.speed * 0.2, accuracy: 0.0001)
                XCTAssertTrue(end.isAlive)
            }
        }
    }

    func testLeaderMovesCameraAndObstaclesStayFixedInWorld() {
        var world = makeWorld()
        let gates = world.gates
        advance(&world, seconds: 2)
        XCTAssertEqual(world.cameraX, HouseRocketsSimulation.spawnX + HouseRocketsSimulation.speed * 2 - HouseRocketsSimulation.leaderAnchorX, accuracy: 0.0001)
        XCTAssertEqual(world.bodies.map(\.x).max()! - world.cameraX, 420, accuracy: 0.0001)
        for gate in gates { XCTAssertEqual(world.gates.first { $0.id == gate.id }, gate) }
        let camera = world.cameraX
        for body in world.bodies { world.steer(playerID: body.id, heading: .pi) }
        advance(&world, seconds: 0.5)
        XCTAssertEqual(world.cameraX, camera, accuracy: 0.0001)
    }

    func testPlatformsDoNotKillAndThereIsNoAutomaticCameraOrTimeout() {
        for heading in [-Double.pi / 2, Double.pi / 2] {
            var world = makeWorld()
            for body in world.bodies { world.steer(playerID: body.id, heading: heading) }
            advance(&world, seconds: 60)
            XCTAssertEqual(world.bodies.filter(\.isAlive).count, 2)
            XCTAssertEqual(world.elapsedTime, 60, accuracy: 0.0001)
            XCTAssertEqual(world.cameraX, 0)
            let boundaryY = heading < 0 ? HouseRocketsSimulation.rocketRadius
                : HouseRocketsSimulation.trackHeight - HouseRocketsSimulation.rocketRadius
            for body in world.bodies { XCTAssertEqual(body.y, boundaryY, accuracy: 0.0001) }
        }
    }

    func testSolidObstacleBlocksWithoutKillingAndStopsCamera() {
        var world = blockedWorld()
        let gate = world.gates[0]
        for body in world.bodies {
            XCTAssertTrue(body.isAlive)
            XCTAssertEqual(body.x, gate.worldX - gate.width / 2 - HouseRocketsSimulation.rocketRadius,
                           accuracy: 0.0001)
        }
        let camera = world.cameraX
        advance(&world, seconds: 3)
        XCTAssertEqual(world.cameraX, camera)
        XCTAssertTrue(world.bodies.allSatisfy(\.isAlive))
    }

    func testShipCanSlideAlongObstacleAndEscapeThroughOpening() {
        var world = blockedWorld()
        let x = world.bodies[0].x
        for body in world.bodies { world.steer(playerID: body.id, heading: .pi / 4) }
        advance(&world, seconds: 0.25)
        XCTAssertEqual(world.bodies[0].x, x, accuracy: 0.0001)
        XCTAssertGreaterThan(world.bodies[0].y, HouseRocketsSimulation.rocketRadius)
        advance(&world, seconds: 0.55)
        for body in world.bodies { world.steer(playerID: body.id, heading: 0) }
        advance(&world, seconds: 1)
        XCTAssertGreaterThan(world.bodies[0].x, world.gates[0].worldX + world.gates[0].width / 2)
        XCTAssertTrue(world.bodies.allSatisfy(\.isAlive))
    }

    func testObstacleBackFaceAlsoBlocksWithoutEliminating() {
        var world = makeWorld()
        advance(&world, seconds: 2.45)
        for body in world.bodies { world.steer(playerID: body.id, heading: -.pi / 2) }
        advance(&world, seconds: 2)
        for body in world.bodies { world.steer(playerID: body.id, heading: .pi) }
        advance(&world, seconds: 0.5)
        for body in world.bodies {
            XCTAssertEqual(body.x, HouseRocketsCourse.firstGateX + 46 + HouseRocketsSimulation.rocketRadius, accuracy: 0.0001)
            XCTAssertTrue(body.isAlive)
        }
    }

    func testOnlyEntireRearExitEliminatesAndLastSurvivorStopsSimulation() {
        let radius = HouseRocketsSimulation.rocketRadius
        XCTAssertFalse(HouseRocketsSimulation.isBehindCamera(centerX: 100 - radius, cameraX: 100))
        XCTAssertTrue(HouseRocketsSimulation.isBehindCamera(centerX: 100 - radius - 0.001, cameraX: 100))
        var world = makeWorld()
        world.steer(playerID: world.bodies[0].id, heading: -.pi / 2)
        advance(&world, seconds: 3)
        XCTAssertFalse(world.bodies[0].isAlive)
        XCTAssertTrue(world.bodies[1].isAlive)
        XCTAssertLessThan(world.bodies[0].x + radius, world.cameraX)
        let positions = world.bodies.map(\.x)
        let endTime = world.elapsedTime
        advance(&world, seconds: 2)
        XCTAssertEqual(world.bodies.map(\.x), positions)
        XCTAssertEqual(world.elapsedTime, endTime)
    }

    func testSimultaneousRearExitsAreResolvedTogether() {
        var world = makeWorld()
        for body in world.bodies { world.steer(playerID: body.id, heading: .pi) }
        advance(&world, seconds: 2)
        XCTAssertEqual(world.bodies.filter(\.isAlive).count, 0)
    }

    func testFrameRatesProduceSameMovementAndContacts() {
        var lowFPS = makeWorld()
        var highFPS = lowFPS
        for index in 0..<2 {
            lowFPS.steer(playerID: lowFPS.bodies[index].id, heading: -0.1)
            highFPS.steer(playerID: highFPS.bodies[index].id, heading: -0.1)
        }
        advance(&lowFPS, seconds: 6, fps: 30)
        advance(&highFPS, seconds: 6, fps: 120)
        for (a, b) in zip(lowFPS.bodies, highFPS.bodies) {
            XCTAssertEqual(a.x, b.x, accuracy: 0.0001)
            XCTAssertEqual(a.y, b.y, accuracy: 0.0001)
            XCTAssertEqual(a.isAlive, b.isAlive)
        }
        XCTAssertEqual(lowFPS.cameraX, highFPS.cameraX, accuracy: 0.0001)
    }

    func testBotsPassStationaryObstaclesAtSharedSpeed() throws {
        var world = makeWorld()
        for tick in 0..<600 {
            if tick.isMultiple(of: 7) {
                for (index, body) in world.bodies.enumerated() {
                    let heading = try XCTUnwrap(world.botHeading(playerID: body.id, laneOffset: index == 0 ? -18 : 20))
                    world.steer(playerID: body.id, heading: heading)
                }
            }
            world.advance(by: 1.0 / 60)
        }
        XCTAssertTrue(world.bodies.allSatisfy(\.isAlive))
        XCTAssertGreaterThan(world.bodies.map(\.x).min()!, 2_000)
    }

    func testInvalidInputCannotCorruptWorld() {
        var world = makeWorld()
        world.steer(playerID: world.bodies[0].id, heading: .nan)
        world.steer(playerID: world.bodies[0].id, heading: .infinity)
        world.advance(by: .nan)
        world.advance(by: .infinity)
        world.advance(by: -1)
        XCTAssertEqual(world.elapsedTime, 0)
        XCTAssertEqual(world.bodies[0].heading, 0)
        XCTAssertEqual(world.bodies[0].x, HouseRocketsSimulation.spawnX)
    }

    func testWinnerDependsOnlyOnSurvivorsAndSteeringRoundTrips() throws {
        var players = [HouseRocketsPlayer(id: UUID(), nameKey: "human", role: .human, color: .mint,
            isAlive: true, distance: 100, heading: 0, worldX: 350, worldY: 180),
            HouseRocketsPlayer(id: UUID(), nameKey: "bot", role: .bot, color: .blue,
            isAlive: true, distance: 200, heading: 0, worldX: 450, worldY: 180)]
        XCTAssertEqual(HouseRocketsRules.resolve(players: players), .ongoing)
        players[1].isAlive = false
        XCTAssertEqual(HouseRocketsRules.resolve(players: players), .winner(players[0].id))
        players[0].isAlive = false
        XCTAssertEqual(HouseRocketsRules.resolve(players: players), .draw)
        let command = HouseRocketsCommand(matchID: UUID(), playerID: players[0].id,
                                         sequence: 1, action: .steer(heading: -.pi / 4))
        let data = try JSONEncoder().encode(command)
        XCTAssertEqual(try JSONDecoder().decode(HouseRocketsCommand.self, from: data), command)
    }

    func testCourseContainsNarrowingWideningSlopedAndWaistedOpenings() {
        let gates = (1...6).map { HouseRocketsCourse.gate(index: $0) }
        XCTAssertGreaterThan(gates[0].passage(at: gates[0].minX).height,
                             gates[0].passage(at: gates[0].maxX).height)
        XCTAssertLessThan(gates[1].passage(at: gates[1].minX).height,
                          gates[1].passage(at: gates[1].maxX).height)
        XCTAssertLessThan(gates[2].passage(at: gates[2].minX).center,
                          gates[2].passage(at: gates[2].maxX).center)
        XCTAssertLessThan(gates[3].passage(at: gates[3].worldX).height,
                          gates[3].passage(at: gates[3].minX).height)
        XCTAssertGreaterThan(gates[4].passage(at: gates[4].minX).center,
                             gates[4].passage(at: gates[4].maxX).center)
        for gate in gates {
            for section in gate.sections {
                XCTAssertGreaterThan(section.upperY - section.lowerY, HouseRocketsSimulation.rocketRadius * 6)
                XCTAssertGreaterThanOrEqual(section.lowerY, 0)
                XCTAssertLessThanOrEqual(section.upperY, HouseRocketsSimulation.trackHeight)
            }
        }
    }

    func testSlopedFacesResolveAlongNormalInsteadOfInvisibleRectangle() {
        let polygon = [HouseRocketsPoint(x: 0, y: 0), .init(x: 100, y: 0), .init(x: 100, y: 100)]
        let freePoint = HouseRocketsPoint(x: 40, y: 65)
        XCTAssertEqual(HouseRocketsContact.resolve(freePoint, radius: 10, polygon: polygon), freePoint)
        let contact = HouseRocketsContact.resolve(.init(x: 50, y: 53), radius: 10, polygon: polygon)
        XCTAssertLessThan(contact.x, 50)
        XCTAssertGreaterThan(contact.y, 53)
        XCTAssertEqual((contact.y - contact.x) / sqrt(2), 10, accuracy: 0.0001)
    }

    func testSpeedFieldsOscillateOnlyVerticallyAndSerialize() throws {
        for index in 0..<6 {
            let field = HouseRocketsCourse.speedField(index: index)
            XCTAssertEqual(field.worldX, HouseRocketsCourse.firstGateX + Double(index) * HouseRocketsCourse.spacing + 320)
            XCTAssertNotEqual(field.worldY(at: 0), field.worldY(at: field.period / 4))
            XCTAssertEqual(field.worldY(at: 0), field.worldY(at: field.period), accuracy: 0.0001)
            for tick in 0..<100 {
                XCTAssertTrue((68...292).contains(field.worldY(at: Double(tick) / 10)))
            }
            let data = try JSONEncoder().encode(field)
            XCTAssertEqual(try JSONDecoder().decode(HouseRocketsSpeedField.self, from: data), field)
        }
    }

    func testBoostAppliesOncePerShipAndExpiresWithoutChangingHeading() throws {
        var world = makeWorld()
        advance(&world, seconds: 2.45)
        let field = try XCTUnwrap(world.speedFields.first)
        for _ in 0..<360 {
            for body in world.bodies where !body.touchedFields.contains(field.id) {
                let heading = atan2(field.worldY(at: world.elapsedTime + 0.05) - body.y, field.worldX - body.x)
                world.steer(playerID: body.id, heading: heading)
            }
            world.advance(by: 1.0 / 120)
            if world.bodies.allSatisfy({ $0.touchedFields.contains(field.id) }) { break }
        }
        XCTAssertTrue(world.bodies.allSatisfy { $0.touchedFields.contains(field.id) })
        XCTAssertTrue(world.bodies.allSatisfy { $0.speedEffect == .boost })
        for body in world.bodies { XCTAssertEqual(body.currentSpeed, 435, accuracy: 0.001) }
        // Keep X fixed: crossing the moving field again must not renew the effect.
        for body in world.bodies { world.steer(playerID: body.id, heading: .pi / 2) }
        advance(&world, seconds: 2)
        for body in world.bodies {
            XCTAssertNil(body.speedEffect)
            XCTAssertEqual(body.currentSpeed, 300)
            XCTAssertEqual(body.heading, .pi / 2)
        }
    }

    func testSlowFieldAppliesOnContactThenRestoresBaseSpeed() throws {
        var world = makeWorld()
        for tick in 0..<900 {
            if tick.isMultiple(of: 7) {
                for body in world.bodies {
                    world.steer(playerID: body.id, heading: try XCTUnwrap(world.botHeading(playerID: body.id, laneOffset: 0)))
                }
            }
            world.advance(by: 1.0 / 60)
            if world.bodies.allSatisfy({ $0.x > 1_730 }) { break }
        }
        let field = try XCTUnwrap(world.speedFields.first { $0.effect == .slow })
        for _ in 0..<360 {
            for body in world.bodies where !body.touchedFields.contains(field.id) {
                world.steer(playerID: body.id,
                            heading: atan2(field.worldY(at: world.elapsedTime + 0.05) - body.y, field.worldX - body.x))
            }
            world.advance(by: 1.0 / 120)
            if world.bodies.allSatisfy({ $0.touchedFields.contains(field.id) }) { break }
        }
        XCTAssertTrue(world.bodies.allSatisfy { $0.speedEffect == .slow })
        for body in world.bodies {
            XCTAssertEqual(body.currentSpeed, 195)
            XCTAssertLessThanOrEqual(body.effectRemaining, 1.4)
            world.steer(playerID: body.id, heading: .pi / 2)
        }
        advance(&world, seconds: 2)
        XCTAssertTrue(world.bodies.allSatisfy { $0.speedEffect == nil && $0.currentSpeed == 300 })
        let freshWorld = makeWorld()
        XCTAssertTrue(freshWorld.bodies.allSatisfy { $0.speedEffect == nil && $0.touchedFields.isEmpty })
    }

    func testBotsCanNavigateAnEntireCoursePattern() throws {
        var world = makeWorld()
        for tick in 0..<1_800 {
            if tick.isMultiple(of: 7) {
                for body in world.bodies {
                    world.steer(playerID: body.id, heading: try XCTUnwrap(world.botHeading(playerID: body.id, laneOffset: 0)))
                }
            }
            world.advance(by: 1.0 / 60)
        }
        XCTAssertTrue(world.bodies.allSatisfy(\.isAlive))
        XCTAssertGreaterThan(world.bodies.map(\.x).min()!, 7_000)
        XCTAssertLessThan(world.gates.count, 6)
        XCTAssertLessThan(world.speedFields.count, 6)
    }

    func testVerticalTurnPreservesBlockedShipsAndCamera() {
        var world = blockedWorld()
        let positions = world.bodies.map { HouseRocketsPoint(x: $0.x, y: $0.y) }
        let camera = world.cameraX
        advance(&world, seconds: 23)
        XCTAssertEqual(world.courseAngle, .pi / 2, accuracy: 0.0001)
        XCTAssertEqual(world.cameraX, camera)
        XCTAssertEqual(world.bodies.map { HouseRocketsPoint(x: $0.x, y: $0.y) }, positions)
        XCTAssertTrue(world.bodies.allSatisfy(\.isAlive))
    }

    func testVerticalJoystickUsesScreenDirectionsAndBottomExitEliminates() {
        var world = makeWorld()
        for body in world.bodies { world.steer(playerID: body.id, heading: .pi / 2) }
        advance(&world, seconds: 29)
        let initialX = world.bodies[0].x
        for body in world.bodies { world.steer(playerID: body.id, heading: .pi / 2) }
        advance(&world, seconds: 0.2)
        XCTAssertEqual(world.bodies[0].x - initialX, 60, accuracy: 0.0001)
        XCTAssertEqual(world.screenHeading(for: world.bodies[0]), .pi / 2, accuracy: 0.0001)
        let acrossBefore = world.bodies[0].y
        for body in world.bodies { world.steer(playerID: body.id, heading: 0) }
        advance(&world, seconds: 0.2)
        XCTAssertEqual(acrossBefore - world.bodies[0].y, 60, accuracy: 0.0001)
        for body in world.bodies { world.steer(playerID: body.id, heading: -.pi / 2) }
        advance(&world, seconds: 2)
        XCTAssertTrue(world.bodies.allSatisfy { !$0.isAlive })
    }

    func testCourseProjectionFitsLandscapeAndMapsRearEdgeToBottom() {
        for (width, height) in [(844.0, 390.0), (1_024.0, 768.0)] {
            for time in stride(from: 25.0, through: 53.0, by: 0.1) {
                let projection = HouseRocketsProjection(elapsedTime: time, cameraX: 5_000,
                                                       width: width, height: height)
                for x in [5_000.0, 5_000 + projection.visibleLength] {
                    for y in [0.0, HouseRocketsSimulation.trackHeight] {
                        let p = projection.point(x: x, y: y)
                        XCTAssertGreaterThanOrEqual(p.x, -0.001)
                        XCTAssertLessThanOrEqual(p.x, width + 0.001)
                        XCTAssertGreaterThanOrEqual(p.y, -0.001)
                        XCTAssertLessThanOrEqual(p.y, height + 0.001)
                    }
                }
            }
            let vertical = HouseRocketsProjection(elapsedTime: 28, cameraX: 5_000,
                                                 width: width, height: height)
            let rear = vertical.point(x: 5_000, y: 180)
            let forward = vertical.point(x: 5_100, y: 180)
            XCTAssertGreaterThanOrEqual(rear.y, 0)
            XCTAssertEqual(rear.x, forward.x, accuracy: 0.0001)
            XCTAssertGreaterThan(forward.y, rear.y)
        }
    }

    func testTokenSizeAndOscillationSpeed() {
        XCTAssertEqual(HouseRocketsSpeedField.radius, 15.4, accuracy: 0.0001)
        XCTAssertEqual(HouseRocketsCourse.speedField(index: 0).period, 3.6 / 1.2, accuracy: 0.0001)
        XCTAssertEqual(HouseRocketsCourse.speedField(index: 1).period, 4.4 / 1.2, accuracy: 0.0001)
    }

    func testCameraZoomPreservesWorldObjectProportionsAndInformationClearance() {
        let width = 726.0, height = 369.0
        let projection = HouseRocketsProjection(elapsedTime: 10, cameraX: 5_000,
                                               width: width, height: height)
        XCTAssertEqual(projection.visibleLength,
                       HouseRocketsSimulation.viewportWidth / HouseRocketsProjection.cameraZoom,
                       accuracy: 0.0001)
        let forward = projection.point(x: 5_100, y: 180)
        let across = projection.point(x: 5_000, y: 280)
        let origin = projection.point(x: 5_000, y: 180)
        XCTAssertEqual(forward.x - origin.x, across.y - origin.y, accuracy: 0.0001)
        XCTAssertGreaterThan(projection.scale, width / HouseRocketsSimulation.viewportWidth)
        let rail = projection.point(x: 5_000, y: 0).y
        XCTAssertGreaterThanOrEqual(rail - projection.informationRegions(width: width, height: height)[0].maxY, 6)
    }

    func testCourseCoversLongitudinalScreenEdgesInBothOrientations() {
        for (width, height) in [(852.0, 393.0), (1_024.0, 768.0)] {
            let horizontal = HouseRocketsProjection(elapsedTime: 24, cameraX: 5_000,
                                                    width: width, height: height)
            XCTAssertLessThanOrEqual(horizontal.point(x: 5_000, y: 180).x, 0.001)
            XCTAssertGreaterThanOrEqual(
                horizontal.point(x: 5_000 + horizontal.visibleLength, y: 180).x,
                width - 0.001)

            let vertical = HouseRocketsProjection(elapsedTime: 29, cameraX: 5_000,
                                                  width: width, height: height)
            XCTAssertLessThanOrEqual(vertical.point(x: 5_000, y: 180).y, 0.001)
            XCTAssertGreaterThanOrEqual(
                vertical.point(x: 5_000 + vertical.visibleLength, y: 180).y,
                height - 0.001)
        }
    }

    func testCourseAlternatesEvery25SecondsWithMatchingWarnings() {
        XCTAssertEqual(HouseRocketsCourse.angle(at: 0), 0)
        XCTAssertEqual(HouseRocketsCourse.angle(at: 24.9), 0)
        XCTAssertNil(HouseRocketsCourse.transitionTargetIsVertical(at: 0))
        for turn in 1...8 {
            let start = Double(turn) * 25
            let vertical = !turn.isMultiple(of: 2)
            let before = vertical ? 0.0 : Double.pi / 2
            let after = vertical ? Double.pi / 2 : 0.0
            XCTAssertEqual(HouseRocketsCourse.angle(at: start), before, accuracy: 0.0001)
            XCTAssertEqual(HouseRocketsCourse.angle(at: start + 1.5), .pi / 4, accuracy: 0.0001)
            XCTAssertEqual(HouseRocketsCourse.angle(at: start + 3), after, accuracy: 0.0001)
            XCTAssertEqual(HouseRocketsCourse.angle(at: start + 24.9), after, accuracy: 0.0001)
            XCTAssertNil(HouseRocketsCourse.transitionTargetIsVertical(at: start - 3.01))
            XCTAssertEqual(HouseRocketsCourse.transitionTargetIsVertical(at: start - 3), vertical)
            XCTAssertEqual(HouseRocketsCourse.transitionTargetIsVertical(at: start + 2.9), vertical)
            XCTAssertNil(HouseRocketsCourse.transitionTargetIsVertical(at: start + 3))
        }
    }

    func testRepeatedTurnsPreserveStationaryShipsAndRestoreScreenSteering() {
        var world = blockedWorld()
        let positions = world.bodies.map { HouseRocketsPoint(x: $0.x, y: $0.y) }
        let camera = world.cameraX
        advance(&world, seconds: 98)
        XCTAssertEqual(world.courseAngle, 0, accuracy: 0.0001)
        XCTAssertEqual(world.cameraX, camera)
        XCTAssertEqual(world.bodies.map { HouseRocketsPoint(x: $0.x, y: $0.y) }, positions)
        XCTAssertTrue(world.bodies.allSatisfy(\.isAlive))
        for body in world.bodies { world.steer(playerID: body.id, heading: .pi / 2) }
        advance(&world, seconds: 0.2)
        XCTAssertEqual(world.bodies[0].y - positions[0].y, 60, accuracy: 0.0001)
        XCTAssertEqual(world.screenHeading(for: world.bodies[0]), .pi / 2, accuracy: 0.0001)
        XCTAssertEqual(makeWorld().courseAngle, 0)
    }

    func testInformationHidesDuringTurnsAndReturnsAtTopInVerticalMode() {
        for (width, height) in [(568.0, 320.0), (726.0, 369.0), (1_024.0, 726.0)] {
            for time in stride(from: 24.0, through: 54.0, by: 0.1) {
                let projection = HouseRocketsProjection(elapsedTime: time, cameraX: 4_000,
                                                       width: width, height: height)
                let regions = projection.informationRegions(width: width, height: height)
                if HouseRocketsCourse.isTransitioning(at: time) {
                    XCTAssertTrue(regions.isEmpty)
                    continue
                }
                XCTAssertEqual(regions.count, 2)
                if projection.angle > .pi / 4 {
                    XCTAssertEqual(regions[0].minY, 8)
                    XCTAssertEqual(regions[1].minY, 8)
                }
                for (index, region) in regions.enumerated() {
                    XCTAssertGreaterThanOrEqual(region.width, 160 - 0.001)
                    XCTAssertGreaterThanOrEqual(region.height, 44)
                    XCTAssertGreaterThanOrEqual(region.minX, 0)
                    XCTAssertGreaterThanOrEqual(region.minY, 0)
                    XCTAssertLessThanOrEqual(region.maxX, width)
                    XCTAssertLessThanOrEqual(region.maxY, height)
                    for x in [region.minX, region.maxX] {
                        for y in [region.minY, region.maxY] {
                            let across = (x - width / 2) * sin(projection.angle)
                                + (y - height / 2) * cos(projection.angle)
                            let distance = index == 0 ? -across : across
                            XCTAssertGreaterThanOrEqual(distance,
                                HouseRocketsSimulation.trackHeight / 2 * projection.scale + 5.99)
                        }
                    }
                }
            }
        }
    }

    private func makeWorld() -> HouseRocketsSimulation {
        HouseRocketsSimulation(playerIDs: [UUID(), UUID()])
    }

    private func blockedWorld() -> HouseRocketsSimulation {
        var world = makeWorld()
        for body in world.bodies { world.steer(playerID: body.id, heading: -.pi / 2) }
        advance(&world, seconds: 2)
        for body in world.bodies { world.steer(playerID: body.id, heading: 0) }
        advance(&world, seconds: 4)
        return world
    }

    private func advance(_ world: inout HouseRocketsSimulation, seconds: Double, fps: Int = 60) {
        for _ in 0..<Int((seconds * Double(fps)).rounded()) { world.advance(by: 1 / Double(fps)) }
    }
}
