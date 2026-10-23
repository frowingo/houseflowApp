import XCTest
@testable import FausCrewAndroidBridge

final class HouseTanksBridgeTests: XCTestCase {
    private func object(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    func testDemoMatchLifecycleThroughTheFacade() throws {
        let handle = houseTanksBotCreate()
        defer { XCTAssertTrue(houseTanksBotDestroy(handle)) }

        XCTAssertEqual(try object(houseTanksBotViewport(handle, 844, 390))["ok"] as? Bool, true)
        XCTAssertEqual(try object(houseTanksBotStart(handle, "hard", "teal", "warehouse"))["ok"] as? Bool, false,
                       "Unknown colors are rejected")

        let start = try object(houseTanksBotStart(handle, "hard", "olive", "warehouse"))
        XCTAssertEqual(start["ok"] as? Bool, true)
        XCTAssertEqual(start["phase"] as? String, "countdown")
        XCTAssertEqual(start["countdown"] as? Int, 3)
        let players = try XCTUnwrap(start["players"] as? [[String: Any]])
        XCTAssertEqual(players.map { $0["role"] as? String }, ["human", "bot", "bot", "bot"])
        XCTAssertEqual(players.first?["color"] as? String, "olive")
        XCTAssertEqual(Set(players.compactMap { $0["color"] as? String }).count, 4)
        let arena = try XCTUnwrap(start["arena"] as? [String: Any], "The first frame carries the arena")
        XCTAssertEqual(arena["mapId"] as? String, "warehouse")
        XCTAssertFalse(try XCTUnwrap(arena["obstacles"] as? [[String: Any]]).isEmpty)
        XCTAssertEqual((start["tanks"] as? [[String: Any]])?.count, 4)
        XCTAssertEqual(start["width"] as? Double, 844)

        var started = false
        for _ in 0..<3 { started = try object(houseTanksBotCountdown(handle))["started"] as? Bool ?? false }
        XCTAssertTrue(started)

        let press = try object(houseTanksBotPress(handle, true))
        XCTAssertEqual(press["changed"] as? Bool, true)
        let events = try XCTUnwrap(press["events"] as? [[String: Any]])
        XCTAssertTrue(events.contains { $0["type"] as? String == "fired" })
        XCTAssertEqual((press["projectiles"] as? [[String: Any]])?.isEmpty, false)

        let step = try object(houseTanksBotStep(handle, 1.0 / 60))
        XCTAssertEqual(step["phase"] as? String, "playing")
        XCTAssertNil(step["arena"], "An unchanged arena is not resent")
        XCTAssertEqual(try object(houseTanksBotPress(handle, false))["changed"] as? Bool, true)

        XCTAssertEqual(try object(houseTanksBotPause(handle))["phase"] as? String, "paused")
        XCTAssertEqual(try object(houseTanksBotResume(handle))["phase"] as? String, "playing")
        XCTAssertNotNil(try object(houseTanksBotViewport(handle, 800, 360))["arena"], "A resize resends the arena")
    }

    func testCopyMapsAndConstants() throws {
        XCTAssertEqual(try object(houseTanksCopy("en"))["house_tanks_title"] as? String, "FauseTanks")
        XCTAssertEqual(try object(houseTanksCopy("tr"))["house_tanks_power_rocket"] as? String, "Dev roket")
        let maps = try XCTUnwrap(try object(houseTanksMaps())["maps"] as? [[String: Any]])
        XCTAssertEqual(maps.map { $0["id"] as? String }, ["livingRoom", "corridors", "warehouse", "courtyard"])
        XCTAssertEqual((maps.first?["spawns"] as? [[Double]])?.count, 4)
        let constants = try object(houseTanksConstants())
        XCTAssertEqual(constants["countdownStepMillis"] as? Int, 720)
        XCTAssertEqual(constants["jokers"] as? [String], ["rocket", "rapidFire", "spreadShot", "shield", "aim"])
    }

    func testUnknownHandleFailsCleanly() throws {
        XCTAssertEqual(try object(houseTanksBotStep(-7, 0.016))["ok"] as? Bool, false)
    }
}
