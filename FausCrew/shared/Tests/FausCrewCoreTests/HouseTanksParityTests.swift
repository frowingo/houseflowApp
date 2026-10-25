import Foundation
import XCTest
@testable import FausCrewCore
#if canImport(CryptoKit)
import CryptoKit
#endif

/// The backend's Go engine is the reference for contract houseTanks.v2. These tests replay
/// its fixtures (copied byte for byte into `shared/Fixtures`) the way
/// `houseflowApi/tests/houseTanksSimulation_test.go` records them. A mismatch is reported
/// to the backend with the diff; the fixtures are never edited here.
final class HouseTanksParityTests: XCTestCase {
    /// sha256 of the fixtures as copied from the backend. Update only together with a new copy.
    private static let fixtureHashes = [
        "houseTanksMaps.json": "fa8d64f37fb35c2e0c737325ac4e5c49acaf038438557a0bffe0a26a131681b9",
        "houseTanksSimulation.json": "4f7b5ce53fd81cf3ef6cf46c127d17ade68d73450699a3e0baf8c3400e19f712",
        "houseTanksProtocol.json": "f0efda9feca82f4cecdce4ebad058a734d77e56e9ad05cfe87ffa4201dab4289",
    ]

    func testFixturesAreTheBackendCopies() throws {
        #if canImport(CryptoKit)
        for (name, expected) in Self.fixtureHashes {
            let digest = SHA256.hash(data: try Data(contentsOf: Self.fixtureURL(name)))
            XCTAssertEqual(digest.map { String(format: "%02x", $0) }.joined(), expected, name)
        }
        #endif
    }

    func testFixtureConstantsMatchTheEngine() throws {
        let fixture = try Self.json("houseTanksSimulation.json")
        XCTAssertEqual(fixture["contractRevision"] as? String, HouseTanksMapCatalog.contractRevision)
        XCTAssertEqual(fixture["mapCatalogVersion"] as? Int, HouseTanksMapCatalog.catalogVersion)
        let constants = try XCTUnwrap(fixture["constants"] as? [String: Double])
        let engine: [String: Double] = [
            "arenaWidth": HouseTanksWorld.arenaSize.width, "arenaHeight": HouseTanksWorld.arenaSize.height,
            "physicsRateHz": Double(HouseTanksWorld.physicsRate), "minimumWallInset": 16, "wallInsetRatio": 0.035,
            "gameplayScale": HouseTanksMapCatalog.gameplayScale, "obstacleBaseScale": HouseTanksMapCatalog.obstacleBaseScale,
            "tankRadius": HouseTanksWorld.tankRadius, "tankLength": HouseTanksWorld.tankLength,
            "rotationSpeed": HouseTanksWorld.rotationSpeed, "driveForce": HouseTanksWorld.driveForce,
            "tankMass": HouseTanksWorld.tankMass, "tankDamping": HouseTanksWorld.tankDamping,
            "maximumTankSpeed": HouseTanksWorld.maxTankSpeed, "tankRestitution": HouseTanksWorld.tankRestitution,
            "obstacleRestitution": HouseTanksWorld.obstacleRestitution, "crateRestitution": HouseTanksWorld.crateRestitution,
            "crateMass": HouseTanksWorld.crateMass, "crateDamping": HouseTanksWorld.crateDamping,
            "contactIterations": Double(HouseTanksWorld.contactIterations),
            "shellSpeed": HouseTanksWorld.shellSpeed, "shellRadius": HouseTanksWorld.shellRadius,
            "shellMuzzleOffset": HouseTanksWorld.shellMuzzleOffset, "rocketSpeed": HouseTanksWorld.rocketSpeed,
            "rocketRadius": HouseTanksWorld.rocketRadius, "rocketLength": HouseTanksWorld.rocketLength,
            "rocketMuzzleOffset": HouseTanksWorld.rocketMuzzleOffset, "spawnClearance": HouseTanksMapCatalog.spawnClearance,
            "armorPerRound": Double(HouseTanksWorld.armorPerRound), "powerUpTokenRadius": HouseTanksWorld.tokenRadius,
            "fireCooldownTicks": Double(HouseTanksWorld.fireCooldownTicks),
            "rapidFireCooldownTicks": Double(HouseTanksPowerUpRules.rapidFireCooldownTicks),
            "hitProtectionTicks": Double(HouseTanksWorld.hitProtectionTicks),
            "shellLifetimeTicks": Double(HouseTanksWorld.shellLifetimeTicks),
            "rocketLifetimeTicks": Double(HouseTanksWorld.rocketLifetimeTicks),
            "powerUpDurationTicks": Double(HouseTanksPowerUpRules.durationTicks),
            "powerUpTokenLifetimeTicks": Double(HouseTanksPowerUpRules.tokenLifetimeTicks),
        ]
        XCTAssertEqual(constants, engine)
    }

    func testGeneratedCatalogMatchesTheFixture() throws {
        let fixture = try Self.json("houseTanksMaps.json")
        XCTAssertEqual(fixture["catalogVersion"] as? Int, HouseTanksMapCatalog.catalogVersion)
        XCTAssertEqual(fixture["contractRevision"] as? String, HouseTanksMapCatalog.contractRevision)
        XCTAssertEqual(fixture["arenaWidth"] as? Double, HouseTanksWorld.arenaSize.width)
        XCTAssertEqual(fixture["arenaHeight"] as? Double, HouseTanksWorld.arenaSize.height)
        let maps = try XCTUnwrap(fixture["maps"] as? [[String: Any]])
        XCTAssertEqual(maps.map { $0["id"] as? String }, HouseTanksMapCatalog.maps.map(\.id.rawValue))
        func point(_ point: HouseTanksNormalizedPoint) -> [String: Any] { ["x": point.x, "y": point.y] }
        for (expected, map) in zip(maps, HouseTanksMapCatalog.maps) {
            let actual: [String: Any] = [
                "id": map.id.rawValue, "version": map.version, "scale": map.scale,
                "minPlayers": map.minPlayers, "maxPlayers": map.maxPlayers,
                "spawnPoints": map.spawnPoints.map(point),
                "obstacles": map.obstacles.map { obstacle -> [String: Any] in [
                    "x": obstacle.center.x, "y": obstacle.center.y, "width": obstacle.size.width,
                    "height": obstacle.size.height, "rotation": obstacle.rotation,
                    "style": obstacle.style.rawValue, "tone": obstacle.tone.rawValue,
                ] },
                "floorLines": map.floorLines.map { ["start": point($0.start), "end": point($0.end)] },
                "floorMarkers": map.floorMarkers.map(point),
            ]
            // JSONSerialization may read a decimal one ulp off (0.07 → 0.07000000000000001);
            // the generator itself parses exactly.
            XCTAssertNil(Self.difference(expected, Self.roundTrip(actual), tolerance: 1e-12),
                         "\(map.id) differs from the fixture; run Scripts/generate_house_tanks_maps.py")
        }
    }

    func testEveryScenarioReachesTheReferenceCheckpoints() throws {
        let fixture = try Self.json("houseTanksSimulation.json")
        let tolerance = try XCTUnwrap(fixture["absoluteTolerance"] as? Double)
        let scenarios = try XCTUnwrap(fixture["scenarios"] as? [[String: Any]])
        XCTAssertEqual(scenarios.count, 17)
        for scenario in scenarios {
            let name = scenario["name"] as? String ?? "?"
            let expected = try XCTUnwrap(scenario["checkpoints"] as? [[String: Any]], name)
            let actual = try Self.run(scenario)
            XCTAssertEqual(actual.count, expected.count, name)
            for (index, checkpoint) in actual.enumerated() where index < expected.count {
                if let difference = Self.difference(expected[index], Self.roundTrip(checkpoint), tolerance: tolerance) {
                    XCTFail("\(name) tick \(checkpoint["tick"] ?? "?"): \(difference)")
                    break
                }
            }
        }
    }

    // MARK: - Replay

    /// Plays a scenario like the Go harness: overrides, then inputs at their tick before each
    /// step; events since the previous checkpoint go into the next one.
    private static func run(_ scenario: [String: Any]) throws -> [[String: Any]] {
        let mapID = try XCTUnwrap(HouseTanksMapID(rawValue: scenario["mapId"] as? String ?? ""))
        let players = try XCTUnwrap(scenario["players"] as? Int)
        let ids = (0..<players).map { "seat\($0)" }
        var world = HouseTanksWorld(map: HouseTanksMapCatalog.definition(for: mapID), playerIDs: ids)
        for setup in scenario["tanks"] as? [[String: Any]] ?? [] {
            let seat = try XCTUnwrap(setup["seat"] as? Int)
            world.debugSet(tank: seat) { tank in
                tank.position = HouseTanksVector(x: setup["x"] as? Double ?? 0, y: setup["y"] as? Double ?? 0)
                tank.rotation = setup["rotation"] as? Double ?? 0
                tank.rotationDirection = setup["rotationDirection"] as? Double ?? 0
                if let velocity = setup["velocity"] as? [Double] { tank.velocity = HouseTanksVector(x: velocity[0], y: velocity[1]) }
                if let armor = setup["armor"] as? Int { tank.armor = armor }
                if let fired = setup["firedAtTick"] as? Int {
                    tank.hasFired = true
                    tank.lastFireTick = fired
                }
            }
            if let kind = setup["powerUp"] as? String {
                XCTAssertTrue(world.grant(try XCTUnwrap(HouseTanksPowerUp(rawValue: kind)), to: ids[seat]))
            }
            if let controllable = setup["controllable"] as? Bool { world.setControllable(ids[seat], controllable) }
            if setup["wreck"] as? Bool == true {
                world.debugSet(tank: seat) { tank in
                    tank.isActive = false
                    tank.armor = 0
                }
            }
        }
        if let token = scenario["token"] as? [String: Any] {
            let kind = try XCTUnwrap(HouseTanksPowerUp(rawValue: token["kind"] as? String ?? ""))
            XCTAssertTrue(world.placeToken(kind, at: HouseTanksVector(x: token["x"] as? Double ?? 0, y: token["y"] as? Double ?? 0)))
        }

        let inputs = scenario["inputs"] as? [[String: Any]] ?? []
        let ticks = try XCTUnwrap(scenario["checkpoints"] as? [[String: Any]]).compactMap { $0["tick"] as? Int }
        var recorded: [[String: Any]] = []
        var events: [[String: Any]] = []
        var next = 0
        while true {
            for input in inputs where input["tick"] as? Int == world.tick {
                let id = ids[try XCTUnwrap(input["seat"] as? Int)]
                switch input["action"] as? String {
                case "press": world.press(id)
                case "release": world.release(id)
                case "loseControl": world.setControllable(id, false)
                case "regainControl": world.setControllable(id, true)
                default: XCTFail("unknown action \(input)")
                }
            }
            if world.tick == ticks.last { break }
            world.step()
            events += world.drainEvents().map(eventObject)
            if next < ticks.count, world.tick == ticks[next] {
                var checkpoint = checkpointObject(world)
                checkpoint["events"] = events
                events = []
                recorded.append(checkpoint)
                next += 1
            }
        }
        return recorded
    }

    private static func seat(_ id: String?) -> Int? {
        id.flatMap { Int($0.dropFirst("seat".count)) }
    }

    private static func eventObject(_ event: HouseTanksWorld.Event) -> [String: Any] {
        var object: [String: Any] = ["tick": event.tick, "kind": event.kind.rawValue]
        if let seat = seat(event.playerID) { object["seat"] = seat }
        if let seat = seat(event.sourceID) { object["sourceSeat"] = seat }
        if let position = event.position {
            object["x"] = position.x
            object["y"] = position.y
        }
        if let angle = event.angle { object["angle"] = angle }
        if let armor = event.armor { object["armor"] = armor }
        if event.lethal { object["lethal"] = true }
        if let crateIndex = event.crateIndex { object["crateIndex"] = crateIndex }
        if let powerUp = event.powerUp { object["powerUp"] = powerUp.rawValue }
        return object
    }

    private static func checkpointObject(_ world: HouseTanksWorld) -> [String: Any] {
        let tanks = world.tanks.map { tank -> [String: Any] in [
            "seat": tank.seat, "x": tank.position.x, "y": tank.position.y, "vx": tank.velocity.x, "vy": tank.velocity.y,
            "rotation": tank.rotation, "rotationDirection": tank.rotationDirection, "active": tank.isActive,
            "controllable": tank.isControllable, "driving": tank.isDriving, "aimLocks": tank.aimLocks, "armor": tank.armor,
            "lastFireTick": tank.hasFired ? tank.lastFireTick as Any : NSNull(),
            "protectedUntilTick": tank.protectedUntilTick,
            "powerUp": tank.powerUp?.kind.rawValue as Any? ?? NSNull(),
            "powerUpExpiresAtTick": tank.powerUp?.expiresAtTick as Any? ?? NSNull(),
        ] }
        let crates = world.obstacles.filter { $0.definition.style == .crate }.map { crate -> [String: Any] in [
            "index": crate.index, "x": crate.position.x, "y": crate.position.y,
            "vx": crate.velocity.x, "vy": crate.velocity.y, "destroyed": crate.isDestroyed,
        ] }
        let projectiles = world.projectiles.map { shot -> [String: Any] in [
            "id": shot.id, "ownerSeat": seat(shot.ownerID) ?? -1, "x": shot.position.x, "y": shot.position.y,
            "vx": shot.velocity.x, "vy": shot.velocity.y, "rocket": shot.isRocket, "holdsAim": shot.holdsAim,
            "radius": shot.radius, "age": shot.age, "spawnTick": shot.spawnTick,
        ] }
        let token: Any = world.token.map { ["kind": $0.kind.rawValue, "x": $0.position.x, "y": $0.position.y] } ?? NSNull()
        return ["tick": world.tick, "tanks": tanks, "crates": crates, "projectiles": projectiles, "token": token]
    }

    // MARK: - JSON

    private static func fixtureURL(_ name: String) -> URL {
        URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .deletingLastPathComponent().appendingPathComponent("Fixtures/\(name)")
    }

    private static func json(_ name: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: fixtureURL(name))) as? [String: Any])
    }

    /// Decodes the value the way the fixture was decoded, so both sides hold the same types.
    private static func roundTrip(_ value: [String: Any]) -> Any {
        (try? JSONSerialization.data(withJSONObject: value))
            .flatMap { try? JSONSerialization.jsonObject(with: $0) } ?? NSNull()
    }

    /// The first difference between decoded JSON values, numbers within `tolerance`.
    private static func difference(_ expected: Any, _ actual: Any, tolerance: Double, path: String = "") -> String? {
        switch (expected, actual) {
        case let (expected as [String: Any], actual as [String: Any]):
            guard Set(expected.keys) == Set(actual.keys) else {
                return "\(path) keys \(actual.keys.sorted()), want \(expected.keys.sorted())"
            }
            for key in expected.keys.sorted() {
                if let found = difference(expected[key]!, actual[key]!, tolerance: tolerance, path: "\(path).\(key)") {
                    return found
                }
            }
            return nil
        case let (expected as [Any], actual as [Any]):
            guard expected.count == actual.count else { return "\(path) has \(actual.count) items, want \(expected.count)" }
            for (index, pair) in zip(expected, actual).enumerated() {
                if let found = difference(pair.0, pair.1, tolerance: tolerance, path: "\(path)[\(index)]") { return found }
            }
            return nil
        case let (expected as String, actual as String):
            return expected == actual ? nil : "\(path) = \(actual), want \(expected)"
        case let (expected as NSNumber, actual as NSNumber):
            return abs(expected.doubleValue - actual.doubleValue) <= tolerance ? nil : "\(path) = \(actual), want \(expected)"
        case (is NSNull, is NSNull):
            return nil
        default:
            return "\(path) = \(actual), want \(expected)"
        }
    }
}
