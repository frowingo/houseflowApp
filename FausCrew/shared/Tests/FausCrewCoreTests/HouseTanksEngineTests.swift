import Foundation
import XCTest
@testable import FausCrewCore

final class HouseTanksEngineTests: XCTestCase {
    // MARK: - Maps and navigation

    func testMapCatalogMapsAreValidAndSeatEveryPlayer() {
        XCTAssertEqual(HouseTanksMapID.allCases.count, 5)
        for mapID in HouseTanksMapID.allCases {
            let map = HouseTanksMapCatalog.definition(for: mapID)
            XCTAssertEqual(map.id, mapID)
            XCTAssertGreaterThanOrEqual(map.spawnPoints.count, map.maxPlayers)
            XCTAssertTrue(map.obstacles.contains(where: \.isMovable))
            XCTAssertTrue(map.obstacles.contains(where: { !$0.isMovable }))
            XCTAssertEqual(HouseTanksMapCatalog.validationIssues(for: map), [], "\(mapID)")
        }
    }

    func testBotRoutesReachEveryOtherSpawnWithoutClippingCover() {
        do {
            let size = HouseTanksWorld.arenaSize
            for id in HouseTanksMapID.allCases {
                let map = HouseTanksMapCatalog.definition(for: id)
                let starts = map.spawnPoints.map { $0.point(in: size) }
                let inset = max(16, size.height * 0.035) + 16
                let frame = HouseTanksRect(size: size).insetBy(dx: inset, dy: inset)
                let scale = map.scale
                for goal in starts.dropFirst() {
                    var position = starts[0]
                    for _ in 0..<900 {
                        if position.distance(to: goal) < 20 * scale { break }
                        let waypoint = HouseTanksNavigation.waypoint(
                            from: position, to: goal, arena: frame,
                            obstacles: map.obstacles.map { $0.bounds(in: size, mapScale: scale) },
                            padding: 14 * scale, step: 16 * scale)
                        let distance = position.distance(to: waypoint)
                        guard distance > 0.01 else { break }
                        position += (waypoint - position) * min(1, 8 * scale / distance)
                        XCTAssertTrue(map.obstacles.allSatisfy { $0.clearance(from: position, in: size, mapScale: scale) >= 12 * scale },
                                      "\(id) at \(size)")
                    }
                    XCTAssertLessThan(position.distance(to: goal), 20 * scale, "\(id) at \(size)")
                }
            }
        }
    }

    func testRayLengthStopsAtTheFirstWall() {
        let bounds = HouseTanksRect(x: 20, y: 20, width: 800, height: 360)
        let origin = HouseTanksVector(x: 120, y: 200)
        XCTAssertEqual(HouseTanksMath.rayLength(from: origin, angle: 0, in: bounds), 700, accuracy: 0.001)
        XCTAssertEqual(HouseTanksMath.rayLength(from: origin, angle: .pi / 2, in: bounds), 180, accuracy: 0.001)
        XCTAssertEqual(HouseTanksMath.rayLength(from: origin, angle: .pi / 4, in: bounds), 180 * sqrt(2), accuracy: 0.001)
        XCTAssertEqual(HouseTanksMath.rayLength(from: .zero, angle: 0, in: bounds), 0)
    }

    // MARK: - Jokers

    func testJokerLastsEightSecondsAndTokenTwelve() {
        var world = makeWorld(.livingRoom)
        let id = world.tanks[0].id
        XCTAssertTrue(world.grant(.shield, to: id))
        XCTAssertTrue(world.placeToken(.rocket, at: HouseTanksVector(x: 590, y: 320)))
        XCTAssertFalse(world.placeToken(.aim, at: HouseTanksVector(x: 600, y: 320)), "one token at a time")
        steps(&world, 7 * 120)
        XCTAssertEqual(world.powerUpStatus(for: id)?.remaining ?? 0, 1, accuracy: 0.0001)
        steps(&world, 120)
        XCTAssertNil(world.powerUpStatus(for: id))
        XCTAssertNotNil(world.token)
        steps(&world, 4 * 120)
        XCTAssertNil(world.token)
    }

    func testJokerBagShufflesEveryKindAndNeverRepeatsBackToBack() {
        var bag = HouseTanksJokerBag()
        var random = HouseTanksRandom(seed: 42)
        let count = HouseTanksPowerUp.allCases.count
        let drawn = (0..<(count * 40)).map { _ in bag.next(using: &random) }
        for (previous, next) in zip(drawn, drawn.dropFirst()) { XCTAssertNotEqual(previous, next) }
        for start in stride(from: 0, to: drawn.count, by: count) {
            XCTAssertEqual(Set(drawn[start..<(start + count)]), Set(HouseTanksPowerUp.allCases))
        }
    }

    // MARK: - Bots and rules

    func testBotsTargetNearestTankUnlessFocused() {
        let human = "human"
        let bot = "bot"
        let origin = HouseTanksVector(x: 100, y: 100)
        let nearBot = (id: bot, position: HouseTanksVector(x: 120, y: 100))
        let farHuman = (id: human, position: HouseTanksVector(x: 700, y: 300))
        XCTAssertEqual(HouseTanksBotBrain.nearestTarget(from: origin, among: [nearBot, farHuman]), bot)
        XCTAssertEqual(HouseTanksBotBrain.target(from: origin, among: [nearBot, farHuman], focus: human), human)
        XCTAssertEqual(HouseTanksBotBrain.target(from: origin, among: [nearBot], focus: human), bot)
        XCTAssertNil(HouseTanksBotBrain.nearestTarget(from: origin, among: []))
    }

    func testDifficultyChangesAimToleranceAndTempo() {
        let observation = HouseTanksBotObservation(aimError: 0.32, targetDistance: 200, hasTarget: true)
        XCTAssertTrue(HouseTanksBotBrain.shouldFire(observation: observation, difficulty: .easy, roll: 0))
        XCTAssertFalse(HouseTanksBotBrain.shouldFire(observation: observation, difficulty: .hard, roll: 0))
        XCTAssertLessThan(HouseTanksBotBrain.decisionDelay(for: .hard), HouseTanksBotBrain.decisionDelay(for: .easy))
        XCTAssertLessThan(HouseTanksBotBrain.holdDuration(for: .hard, travelDistance: 24), HouseTanksBotBrain.holdDuration(for: .hard))
    }

    func testRoundsHaveNoClockAndRocketDamageIsLethal() {
        var players = makePlayers()
        XCTAssertEqual(HouseTanksMatchRules.resolveRound(players: players), .ongoing)
        players = HouseTanksMatchRules.applyingDamage(to: players, targetID: players[1].id, amount: 5)
        XCTAssertFalse(players[1].isAlive)
        players = players.enumerated().map { index, player in
            var updated = player
            updated.isAlive = index == 0
            return updated
        }
        XCTAssertEqual(HouseTanksMatchRules.resolveRound(players: players), .winner(players[0].id))
        XCTAssertEqual(HouseTanksMatchRules.resolveRound(players: players.map { var p = $0; p.isAlive = false; return p }), .draw)
    }

    // MARK: - World

    func testPressFiresOnceAndDrivesAlongTheBarrel() {
        var world = makeWorld(.livingRoom)
        let human = world.tanks[0]
        XCTAssertTrue(world.press(human.id))
        XCTAssertEqual(world.projectiles.count, 1)
        let start = world.tank(human.id)!.position
        run(&world, seconds: 0.3)
        let moved = world.tank(human.id)!.position - start
        XCTAssertGreaterThan(moved.length, 5)
        XCTAssertLessThan(abs(HouseTanksMath.normalizedAngle(moved.angle - human.rotation)), 0.3)
        XCTAssertFalse(world.press(human.id), "a held press does not fire again")
        world.release(human.id)
        XCTAssertEqual(world.tank(human.id)!.rotationDirection, -human.rotationDirection)
    }

    func testIdleTanksSweepAtTheConfiguredRate() {
        var world = makeWorld(.livingRoom)
        let before = world.tanks[0].rotation
        steps(&world, 12)
        XCTAssertEqual(world.tanks[0].rotation - before, HouseTanksWorld.rotationSpeed * 0.1 * world.tanks[0].rotationDirection,
                       accuracy: 1e-9)
    }

    func testShellBreaksACrateAndHitsATank() {
        var world = makeWorld(.livingRoom, obstacles: [Self.crate(at: 0.5, 0.36), Self.divider(at: 0.5, 0.8)])
        let crateIndex = 0
        aim(&world, tank: 0, at: world.obstacles[crateIndex].position)
        world.press(world.tanks[0].id)
        world.release(world.tanks[0].id)
        let broken = run(&world) { world, _ in world.obstacles[crateIndex].isDestroyed }
        XCTAssertTrue(world.obstacles[crateIndex].isDestroyed)
        XCTAssertTrue(broken.contains { $0.kind == .crateBroken && $0.crateIndex == crateIndex })

        var duel = makeWorld(.livingRoom, clearCover: true)
        aim(&duel, tank: 0, at: duel.tanks[1].position)
        duel.press(duel.tanks[0].id)
        duel.release(duel.tanks[0].id)
        let hit = run(&duel) { _, events in events.contains { $0.kind == .hit } }.first { $0.kind == .hit }
        XCTAssertEqual(hit?.playerID, duel.tanks[1].id)
        XCTAssertEqual(hit?.sourceID, duel.tanks[0].id)
        XCTAssertEqual(hit?.armor, 4)
        XCTAssertEqual(hit?.lethal, false)
        XCTAssertEqual(duel.tanks[1].armor, 4)
    }

    func testTanksPushCratesButNotFurniture() {
        var world = makeWorld(.livingRoom, obstacles: [Self.crate(at: 0.5, 0.36), Self.divider(at: 0.5, 0.8)])
        let crateIndex = 0
        let crate = world.obstacles[crateIndex]
        place(&world, tank: 0, at: crate.position - HouseTanksVector(x: crate.radius + HouseTanksWorld.tankRadius + 2, y: 0))
        aimAngle(&world, tank: 0, 0)
        // Hold fire (cooling down) so the tank drives into the crate instead of shooting it.
        world.debugSet(tank: 0) { $0.hasFired = true }
        world.press(world.tanks[0].id)
        XCTAssertTrue(world.projectiles.isEmpty)
        run(&world, seconds: 0.5)
        XCTAssertGreaterThan(world.obstacles[crateIndex].position.x, crate.position.x + 4)
        let fixed = world.obstacles.first { !$0.isMovable }!
        XCTAssertEqual(world.obstacles[fixed.index].position, fixed.position)
    }

    func testShieldBlocksAndRocketIsLethal() {
        var world = makeWorld(.livingRoom, clearCover: true)
        grant(&world, .rocket, to: 0)
        aim(&world, tank: 0, at: world.tanks[1].position)
        world.press(world.tanks[0].id)
        XCTAssertTrue(world.projectiles.first?.isRocket == true)
        let rocket = run(&world) { _, events in events.contains { $0.kind == .eliminated } }
        XCTAssertEqual(rocket.first { $0.kind == .hit }?.lethal, true)
        XCTAssertFalse(world.tanks[1].isActive, "a rocket destroys a full-armor tank")

        var shielded = makeWorld(.livingRoom, clearCover: true)
        grant(&shielded, .shield, to: 1)
        aim(&shielded, tank: 0, at: shielded.tanks[1].position)
        shielded.press(shielded.tanks[0].id)
        let outcome = run(&shielded) { _, events in events.contains { $0.kind == .shielded } }
        XCTAssertFalse(outcome.contains { $0.kind == .hit })
        XCTAssertEqual(outcome.first { $0.kind == .shielded }?.sourceID, shielded.tanks[0].id)
        XCTAssertEqual(shielded.tanks[1].armor, 5)
    }

    func testAimJokerHoldsHeadingUntilTheShotLandsAndStillFires() {
        var world = makeWorld(.livingRoom, clearCover: true)
        grant(&world, .aim, to: 0)
        XCTAssertNotNil(world.aimLength(for: world.tanks[0].id))
        let id = world.tanks[0].id
        world.press(id)
        world.release(id)
        let locked = world.tank(id)!.rotation
        run(&world, seconds: 0.2)
        XCTAssertEqual(world.tank(id)!.aimLocks, 1)
        XCTAssertEqual(world.tank(id)!.rotation, locked, accuracy: 0.0001)
        // Firing again at the normal cadence while locked.
        run(&world, seconds: 0.4)
        XCTAssertTrue(world.press(id))
        world.release(id)
        run(&world) { world, _ in world.tank(id)!.aimLocks == 0 && world.projectiles.isEmpty }
        let free = world.tank(id)!.rotation
        run(&world, seconds: 0.2)
        XCTAssertNotEqual(world.tank(id)!.rotation, free)
    }

    func testSameSeedReplaysTheSameJokers() {
        func tokens(seed: UInt64) -> [HouseTanksPowerUp] {
            var world = HouseTanksWorld(map: HouseTanksMapCatalog.courtyard, playerIDs: ["a", "b", "c", "d"])
            world.startJokers(random: HouseTanksRandom(seed: seed), bag: HouseTanksJokerBag())
            var kinds: [HouseTanksPowerUp] = []
            for _ in 0..<(120 * 60) {
                world.step()
                if let kind = world.token?.kind, kinds.last != kind { kinds.append(kind) }
            }
            return kinds
        }
        XCTAssertFalse(tokens(seed: 7).isEmpty)
        XCTAssertEqual(tokens(seed: 7), tokens(seed: 7))
    }

    // MARK: - Match

    func testMatchFieldsOneHumanAndThreeDistinctBotsAndCountsDown() {
        var match = HouseTanksBotMatch(seed: 1)
        match.start(configuration: .init(difficulty: .hard, humanColor: .olive, mapID: .warehouse))
        let snapshot = match.snapshot!
        XCTAssertEqual(snapshot.players.count, 4)
        XCTAssertEqual(snapshot.players.filter { $0.role == .bot }.count, 3)
        XCTAssertEqual(Set(snapshot.players.map(\.color)).count, 4)
        XCTAssertEqual(snapshot.humanPlayer?.color, .olive)
        XCTAssertEqual(snapshot.phase, .countdown)
        XCTAssertFalse(match.advanceCountdown())
        XCTAssertFalse(match.advanceCountdown())
        XCTAssertTrue(match.advanceCountdown())
        XCTAssertEqual(match.snapshot?.phase, .playing)
        XCTAssertNotNil(match.world?.jokers, "jokers are dealt once the round plays")
    }

    func testBotsPlayARoundToItsEndAndTheNextRoundRestoresCrates() {
        var match = HouseTanksBotMatch(seed: 3)
        match.start(configuration: .init(difficulty: .hard, humanColor: .plum, mapID: .courtyard))
        while match.advanceCountdown() == false {}
        let crates = match.world!.obstacles.filter(\.isMovable).count
        for _ in 0..<(60 * 240) where match.snapshot?.phase == .playing {
            match.advance(by: 1 / 60)
        }
        let phase = match.snapshot!.phase
        XCTAssertTrue(phase == .roundEnded || phase == .matchEnded, "a hard round between bots resolves")
        if phase == .roundEnded {
            let snapshot = match.snapshot!
            XCTAssertTrue(match.send(.init(matchID: snapshot.matchID, playerID: nil, sequence: 0, action: .nextRound)))
            XCTAssertEqual(match.snapshot?.roundNumber, 2)
            XCTAssertEqual(match.world?.obstacles.filter { $0.isMovable && !$0.isDestroyed }.count, crates)
            XCTAssertTrue(match.snapshot!.players.allSatisfy { $0.isAlive && $0.armor == 5 })
        }
    }

    func testBasementSeatsSixToEightTanksAtASmallerScale() {
        let basement = HouseTanksMapCatalog.definition(for: .basement)
        XCTAssertEqual(basement.playerCounts, 6...8)
        XCTAssertLessThan(basement.scale, 1)
        XCTAssertGreaterThan(basement.obstacles.count, HouseTanksMapCatalog.definition(for: .livingRoom).obstacles.count)

        var match = HouseTanksBotMatch(seed: 8)
        match.start(configuration: .init(difficulty: .normal, humanColor: .sky, mapID: .basement, playerCount: 8))
        let players = match.snapshot!.players
        XCTAssertEqual(players.count, 8)
        XCTAssertEqual(Set(players.map(\.color)).count, 8)
        XCTAssertEqual(Set(players.map(\.nameKey)).count, 8)
        let world = match.world!
        XCTAssertEqual(world.bodyRadius, HouseTanksWorld.tankRadius * basement.scale, accuracy: 1e-9)
        XCTAssertEqual(world.tanks.count, 8)

        // Out-of-range counts are clamped to the map's demo range; standard maps stay at four.
        XCTAssertEqual(HouseTanksMatchConfiguration(difficulty: .easy, humanColor: .plum, mapID: .basement, playerCount: 3).playerCount, 6)
        XCTAssertEqual(HouseTanksMatchConfiguration(difficulty: .easy, humanColor: .plum, mapID: .basement, playerCount: 12).playerCount, 8)
        XCTAssertEqual(HouseTanksMatchConfiguration(difficulty: .easy, humanColor: .plum, mapID: .warehouse, playerCount: 8).playerCount, 4)
    }

    func testBotsResolveACrowdedBasementRound() {
        var match = HouseTanksBotMatch(seed: 21)
        match.start(configuration: .init(difficulty: .hard, humanColor: .crimson, mapID: .basement, playerCount: 7))
        while match.advanceCountdown() == false {}
        for _ in 0..<(60 * 300) where match.snapshot?.phase == .playing { match.advance(by: 1 / 60) }
        let phase = match.snapshot!.phase
        XCTAssertTrue(phase == .roundEnded || phase == .matchEnded)
    }

    func testPauseStopsTheArena() {
        var match = HouseTanksBotMatch(seed: 5)
        match.start(configuration: .init(difficulty: .easy, humanColor: .blue))
        while match.advanceCountdown() == false {}
        XCTAssertTrue(match.pause())
        let rotation = match.world!.tanks[0].rotation
        match.advance(by: 0.5)
        XCTAssertEqual(match.world!.tanks[0].rotation, rotation)
        XCTAssertTrue(match.resume())
        match.advance(by: 0.05)
        XCTAssertNotEqual(match.world!.tanks[0].rotation, rotation)
    }

    // MARK: - Helpers

    private func makePlayers() -> [HouseTanksPlayer] {
        HouseTanksColor.allCases.enumerated().map { index, color in
            HouseTanksPlayer(id: UUID(), nameKey: "p\(index)", role: index == 0 ? .human : .bot, color: color,
                             armor: 5, roundsWon: 0, isAlive: true)
        }
    }

    private static func crate(at x: Double, _ y: Double) -> HouseTanksObstacleDefinition {
        .init(center: .init(x: x, y: y), size: .init(width: 0.12, height: 0.12), rotation: 0, style: .crate, tone: .wood)
    }

    private static func divider(at x: Double, _ y: Double) -> HouseTanksObstacleDefinition {
        .init(center: .init(x: x, y: y), size: .init(width: 0.3, height: 0.06), rotation: 0, style: .divider, tone: .navy)
    }

    /// A world with live physics; `clearCover` removes all furniture for an open duel lane.
    private func makeWorld(_ map: HouseTanksMapID, clearCover: Bool = false,
                           obstacles: [HouseTanksObstacleDefinition]? = nil) -> HouseTanksWorld {
        var definition = HouseTanksMapCatalog.definition(for: map)
        if clearCover || obstacles != nil {
            definition = HouseTanksMapDefinition(id: definition.id, version: definition.version,
                                                 spawnPoints: definition.spawnPoints, obstacles: obstacles ?? [],
                                                 floorLines: [], floorMarkers: [], scale: definition.scale,
                                                 minPlayers: definition.minPlayers, maxPlayers: definition.maxPlayers)
        }
        return HouseTanksWorld(map: definition, playerIDs: (0..<4).map { "seat\($0)" })
    }

    private func aim(_ world: inout HouseTanksWorld, tank index: Int, at point: HouseTanksVector) {
        aimAngle(&world, tank: index, (point - world.tanks[index].position).angle)
    }

    private func aimAngle(_ world: inout HouseTanksWorld, tank index: Int, _ angle: Double) {
        world.debugSet(tank: index) { $0.rotation = angle }
    }

    private func place(_ world: inout HouseTanksWorld, tank index: Int, at point: HouseTanksVector) {
        world.debugSet(tank: index) { $0.position = point }
    }

    private func grant(_ world: inout HouseTanksWorld, _ kind: HouseTanksPowerUp, to index: Int) {
        XCTAssertTrue(world.grant(kind, to: world.tanks[index].id))
    }

    /// Steps tick by tick (five seconds at most) until `done`; returns the events on the way.
    @discardableResult
    private func run(_ world: inout HouseTanksWorld, ticks: Int = 600,
                     until done: (HouseTanksWorld, [HouseTanksWorld.Event]) -> Bool = { _, _ in false })
    -> [HouseTanksWorld.Event] {
        var events = world.drainEvents()
        for _ in 0..<ticks {
            world.step()
            events += world.drainEvents()
            if done(world, events) { break }
        }
        return events
    }

    private func run(_ world: inout HouseTanksWorld, seconds: Double) {
        run(&world, ticks: Int((seconds * 120).rounded()))
    }

    private func steps(_ world: inout HouseTanksWorld, _ count: Int) {
        for _ in 0..<count { world.step() }
    }
}
