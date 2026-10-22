import CoreGraphics
import SpriteKit
import XCTest
@testable import FausCrew

@MainActor
final class HouseTanksTests: XCTestCase {
    func testBotRoutesKeepTankClearanceAroundCorners() {
        for size in [CGSize(width: 667, height: 320), CGSize(width: 1_180, height: 640)] {
            for id in HouseTanksMapID.allCases {
                let map = HouseTanksMapCatalog.definition(for: id)
                let starts = map.spawnPoints.map { CGPoint(x: $0.x * size.width, y: $0.y * size.height) }
                let inset = max(16, size.height * 0.035) + 16
                let arena = CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset)
                for goal in starts.dropFirst() {
                    var position = starts[0]
                    for _ in 0..<600 {
                        if hypot(position.x - goal.x, position.y - goal.y) < 20 { break }
                        let waypoint = HouseTanksNavigation.waypoint(
                            from: position, to: goal, arena: arena,
                            obstacles: map.obstacles.map { $0.bounds(in: size) }
                        )
                        let distance = hypot(waypoint.x - position.x, waypoint.y - position.y)
                        guard distance > 0.01 else { break }
                        let fraction = min(1, 8 / distance)
                        position.x += (waypoint.x - position.x) * fraction
                        position.y += (waypoint.y - position.y) * fraction
                        XCTAssertTrue(map.obstacles.allSatisfy { $0.clearance(from: position, in: size) >= 12 })
                    }
                    XCTAssertLessThan(hypot(position.x - goal.x, position.y - goal.y), 20, "\(id) at \(size)")
                }
            }
        }
    }

    func testRoundRebuildRestoresMovedAndDestroyedCrates() {
        let scene = HouseTanksScene(size: CGSize(width: 844, height: 390))
        let map = HouseTanksMapCatalog.definition(for: .warehouse)
        let players = makePlayers()
        scene.prepareRound(players: players, map: map)
        let crates = scene.children.filter { $0.userData?["breaksOnHit"] as? Bool == true }
        XCTAssertGreaterThan(crates.count, 1)
        XCTAssertTrue(crates.allSatisfy { $0.physicsBody?.isDynamic == true })
        let originalPositions = crates.map(\.position)
        crates.first?.position = CGPoint(x: 100, y: 100)
        crates.last?.removeFromParent()
        scene.prepareRound(players: players, map: map)
        let restored = scene.children.filter { $0.userData?["breaksOnHit"] as? Bool == true }
        XCTAssertEqual(restored.map(\.position), originalPositions)
    }

    func testBotsNavigateAroundFixedCoverAndShortenPressBeforeTurns() {
        let start = CGPoint(x: 80, y: 200)
        let goal = CGPoint(x: 680, y: 200)
        let arena = CGRect(x: 32, y: 32, width: 720, height: 340)
        let wall = CGRect(x: 340, y: 120, width: 20, height: 160)
        XCTAssertEqual(HouseTanksNavigation.waypoint(from: start, to: goal, arena: arena, obstacles: []), goal)
        let waypoint = HouseTanksNavigation.waypoint(from: start, to: goal, arena: arena, obstacles: [wall])
        XCTAssertNotEqual(waypoint, goal)
        XCTAssertFalse(wall.insetBy(dx: -14, dy: -14).contains(waypoint))
        let bot = HouseTanksBotController(playerID: UUID())
        XCTAssertLessThan(bot.holdDuration(for: .hard, travelDistance: 24), bot.holdDuration(for: .hard))
    }

    func testJokerIsCollectedOnlyOnceAndExpiresAfterSixPlayingSeconds() {
        var rules = HouseTanksPowerUpRules()
        let playerID = UUID()
        XCTAssertTrue(rules.spawn(kind: .shield, at: .zero))
        XCTAssertEqual(rules.collect(playerID: playerID), .shield)
        XCTAssertNil(rules.collect(playerID: UUID()))
        rules.advance(by: 5)
        XCTAssertEqual(rules.status(for: playerID)?.remaining, 1)
        rules.advance(by: 1)
        XCTAssertNil(rules.status(for: playerID))
    }

    func testUnclaimedJokerExpiresAndNewPowerReplacesOldPower() {
        var rules = HouseTanksPowerUpRules()
        let playerID = UUID()
        rules.spawn(kind: .speed, at: .zero)
        rules.advance(by: 8)
        XCTAssertNil(rules.token)
        XCTAssertNil(rules.collect(playerID: playerID))

        rules.spawn(kind: .rapidFire, at: .zero)
        rules.collect(playerID: playerID)
        rules.advance(by: 2)
        rules.spawn(kind: .spreadShot, at: .zero)
        rules.collect(playerID: playerID)
        XCTAssertEqual(rules.status(for: playerID)?.kind, .spreadShot)
        XCTAssertEqual(rules.status(for: playerID)?.remaining, 6)
        rules.advance(by: 0)
        XCTAssertEqual(rules.status(for: playerID)?.remaining, 6)
        rules.remove(playerID: playerID)
        XCTAssertNil(rules.status(for: playerID))
    }

    func testJokerPlacementExcludesSpawnsActorsAndMovedObstacles() {
        let arena = CGRect(x: 40, y: 40, width: 760, height: 300)
        let start = CGPoint(x: 120, y: 180)
        let tank = CGPoint(x: 400, y: 200)
        let crate = CGRect(x: 600, y: 200, width: 24, height: 24)
        for rejected in [start, tank, CGPoint(x: 590, y: 210), CGPoint(x: 10, y: 10)] {
            XCTAssertFalse(HouseTanksPowerUpRules.isValidSpawn(
                rejected, arena: arena, starts: [start], tanks: [tank], obstacles: [crate]
            ))
        }
        XCTAssertTrue(HouseTanksPowerUpRules.isValidSpawn(
            CGPoint(x: 300, y: 100), arena: arena, starts: [start], tanks: [tank], obstacles: [crate]
        ))
    }

    func testEveryArenaMixesMovableCratesWithFixedCoverAtPhoneSizes() {
        for mapID in HouseTanksMapID.allCases {
            let map = HouseTanksMapCatalog.definition(for: mapID)
            XCTAssertTrue(map.obstacles.contains(where: \.isMovable))
            XCTAssertTrue(map.obstacles.contains(where: { !$0.isMovable }))
            XCTAssertTrue(map.obstacles.filter(\.breaksOnHit).allSatisfy { $0.style == .crate })
            for size in [CGSize(width: 844, height: 390), CGSize(width: 667, height: 320)] {
                XCTAssertTrue(HouseTanksMapCatalog.validationIssues(for: map, arenaSize: size).isEmpty,
                              "\(mapID) at \(size)")
            }
        }
    }

    func testMapCatalogContainsFourValidVersionedMaps() {
        XCTAssertEqual(HouseTanksMapID.allCases.count, 4)

        for mapID in HouseTanksMapID.allCases {
            let definition = HouseTanksMapCatalog.definition(for: mapID)
            XCTAssertEqual(definition.id, mapID)
            XCTAssertGreaterThan(definition.version, 0)
            XCTAssertEqual(definition.spawnPoints.count, 3)
            XCTAssertTrue(
                HouseTanksMapCatalog.validationIssues(for: definition).isEmpty,
                "\(mapID.rawValue) contains invalid normalized geometry"
            )
        }
    }

    func testDemoSnapshotKeepsSelectedMapIdentity() async throws {
        let service = DemoHouseTanksGameSession()
        let stream = service.events()
        var iterator = stream.makeAsyncIterator()

        await service.start(configuration: HouseTanksMatchConfiguration(
            difficulty: .normal,
            humanColor: .teal,
            mapID: .warehouse
        ))

        let received = await iterator.next()
        let snapshot = try XCTUnwrap(received)
        XCTAssertEqual(snapshot.mapID, .warehouse)
        XCTAssertEqual(
            snapshot.mapVersion,
            HouseTanksMapCatalog.definition(for: .warehouse).version
        )
        service.disconnect()
    }

    func testGameplayGeometryUsesHalfScale() {
        XCTAssertEqual(HouseTanksMapCatalog.gameplayScale, 0.5)
        XCTAssertEqual(
            HouseTanksMapCatalog.obstacleBaseScale * HouseTanksMapCatalog.gameplayScale,
            0.36,
            accuracy: 0.0001
        )
    }

    func testDamageRemovesOneArmorAndEliminatesAtZero() async {
        let targetID = UUID()
        var players = makePlayers(targetID: targetID, targetArmor: 2)

        players = HouseTanksMatchRules.applyingDamage(to: players, targetID: targetID)
        XCTAssertEqual(players.first { $0.id == targetID }?.armor, 1)
        XCTAssertEqual(players.first { $0.id == targetID }?.isAlive, true)

        players = HouseTanksMatchRules.applyingDamage(to: players, targetID: targetID)
        XCTAssertEqual(players.first { $0.id == targetID }?.armor, 0)
        XCTAssertEqual(players.first { $0.id == targetID }?.isAlive, false)
    }

    func testRoundEndsOnlyWhenOneTankRemains() async {
        let players = makePlayers().enumerated().map { index, player in
            var updated = player
            updated.isAlive = index == 0
            updated.armor = index == 0 ? 3 : 0
            return updated
        }

        XCTAssertEqual(
            HouseTanksMatchRules.resolveRound(players: players, timeExpired: false),
            .winner(players[0].id)
        )
    }

    func testSimultaneousEliminationIsDraw() async {
        let players = makePlayers().map { player in
            var updated = player
            updated.isAlive = false
            updated.armor = 0
            return updated
        }

        XCTAssertEqual(
            HouseTanksMatchRules.resolveRound(players: players, timeExpired: false),
            .draw
        )
    }

    func testTimerUsesUniqueHighestArmorAndDrawsOnTie() async {
        var players = makePlayers()
        players[0].armor = 4
        players[1].armor = 2
        players[2].armor = 1
        XCTAssertEqual(
            HouseTanksMatchRules.resolveRound(players: players, timeExpired: true),
            .winner(players[0].id)
        )

        players[1].armor = 4
        XCTAssertEqual(
            HouseTanksMatchRules.resolveRound(players: players, timeExpired: true),
            .draw
        )
    }

    func testThreeRoundWinsProducesChampion() async {
        var players = makePlayers()
        let winnerID = players[1].id

        for _ in 0..<3 {
            players = HouseTanksMatchRules.awardingRound(to: winnerID, players: players)
        }

        XCTAssertEqual(HouseTanksMatchRules.champion(in: players, winsNeeded: 3), winnerID)
        XCTAssertEqual(players[1].roundsWon, 3)
    }

    func testAnglesAreNormalizedForAimLocking() async {
        XCTAssertEqual(HouseTanksMath.normalizedAngle(.pi * 3), .pi, accuracy: 0.001)
        XCTAssertEqual(HouseTanksMath.normalizedAngle(-.pi * 3), -.pi, accuracy: 0.001)
    }

    func testIdleRotationDirectionAlternatesAfterEveryPress() async {
        let clockwise: CGFloat = 1
        let counterClockwise = HouseTanksMath.oppositeRotationDirection(after: clockwise)
        let clockwiseAgain = HouseTanksMath.oppositeRotationDirection(after: counterClockwise)

        XCTAssertEqual(counterClockwise, -1)
        XCTAssertEqual(clockwiseAgain, 1)
    }

    func testBotDifficultyChangesAimTolerance() async {
        let bot = HouseTanksBotController(playerID: UUID(), randomUnit: { 0 })
        let observation = HouseTanksBotObservation(
            aimError: 0.32,
            targetDistance: 200,
            hasTarget: true
        )

        XCTAssertTrue(bot.shouldFire(observation: observation, difficulty: .easy))
        XCTAssertFalse(bot.shouldFire(observation: observation, difficulty: .hard))
        XCTAssertGreaterThan(
            bot.holdDuration(for: .hard),
            bot.holdDuration(for: .easy)
        )
    }

    private func makePlayers(
        targetID: UUID = UUID(),
        targetArmor: Int = 5
    ) -> [HouseTanksPlayer] {
        [
            HouseTanksPlayer(
                id: targetID,
                nameKey: "human",
                role: .human,
                color: .teal,
                armor: targetArmor,
                roundsWon: 0,
                isAlive: true
            ),
            HouseTanksPlayer(
                id: UUID(),
                nameKey: "bot-1",
                role: .bot,
                color: .orange,
                armor: 5,
                roundsWon: 0,
                isAlive: true
            ),
            HouseTanksPlayer(
                id: UUID(),
                nameKey: "bot-2",
                role: .bot,
                color: .blue,
                armor: 5,
                roundsWon: 0,
                isAlive: true
            ),
        ]
    }
}
