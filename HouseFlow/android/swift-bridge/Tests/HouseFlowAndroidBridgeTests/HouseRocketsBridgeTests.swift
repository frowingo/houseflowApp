import XCTest
@testable import HouseFlowAndroidBridge

final class HouseRocketsBridgeTests: XCTestCase {
    private func object(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    func testBotMatchLifecycleThroughTheFacade() throws {
        let handle = houseRocketsBotCreate()
        defer { XCTAssertTrue(houseRocketsBotDestroy(handle)) }

        XCTAssertEqual(try object(houseRocketsBotViewport(handle, 844, 390, 800, 369))["ok"] as? Bool, true,
                       "A viewport before the first start is accepted")
        let start = try object(houseRocketsBotStart(handle, 2))
        XCTAssertEqual(start["ok"] as? Bool, true)
        XCTAssertEqual(start["phase"] as? String, "countdown")
        XCTAssertEqual(start["countdown"] as? Int, 3)
        let players = try XCTUnwrap(start["players"] as? [[String: Any]])
        XCTAssertEqual(players.map { $0["role"] as? String }, ["human", "bot", "bot"])
        XCTAssertEqual(players.map { $0["color"] as? String }, ["mint", "coral", "blue"])
        XCTAssertEqual(players.first?["nameKey"] as? String, "house_rockets_you")
        let gates = try XCTUnwrap(start["gates"] as? [[String: Any]], "The first frame carries the course")
        XCTAssertFalse(gates.isEmpty)
        XCTAssertEqual((gates.first?["polygons"] as? [[Double]])?.first?.count, 8, "Quads as flat x,y pairs")
        XCTAssertNotNil(start["projection"] as? [String: Any])
        let regions = try XCTUnwrap(start["regions"] as? [[Double]])
        XCTAssertEqual(regions.count, 2)
        XCTAssertEqual(regions[0], [180, 8, 440, 44], "Regions use the HUD size, not the canvas")

        var started = false
        for _ in 0..<3 { started = try object(houseRocketsBotCountdown(handle))["started"] as? Bool ?? false }
        XCTAssertTrue(started)

        let step = try object(houseRocketsBotStep(handle, 1.0 / 60, true, 0.3, 1))
        XCTAssertEqual(step["phase"] as? String, "playing")
        XCTAssertEqual(step["steered"] as? Bool, true)
        XCTAssertNil(step["gates"], "Unchanged course is not resent")
        XCTAssertEqual(try XCTUnwrap(step["elapsed"] as? Double), 1.0 / 60, accuracy: 0.000_1)

        let stale = try object(houseRocketsBotStep(handle, 1.0 / 60, true, 0.6, 1))
        XCTAssertEqual(stale["steered"] as? Bool, false, "Sequence must increase")

        XCTAssertEqual(try object(houseRocketsBotPause(handle))["phase"] as? String, "paused")
        XCTAssertEqual(try object(houseRocketsBotResume(handle))["resumed"] as? String, "playing")
        XCTAssertEqual(try object(houseRocketsBotRestart(handle))["changed"] as? Bool, false,
                       "Restart waits for the end")
        let resized = try object(houseRocketsBotViewport(handle, 390, 844, 390, 800))
        XCTAssertNotNil(resized["gates"], "A resize resends the course")
        XCTAssertEqual(resized["revision"] as? Int, stale["revision"].flatMap { $0 as? Int }.map { $0 + 2 },
                       "Pause and resume each count once; a resize does not advance")
    }

    func testUnknownHandleAndCopy() throws {
        XCTAssertEqual(try object(houseRocketsBotStep(-1, 0.016, false, 0, 0))["ok"] as? Bool, false)
        XCTAssertFalse(houseRocketsBotDestroy(-1))
        let turkish = try object(houseRocketsCopy("tr"))
        let english = try object(houseRocketsCopy("en-US"))
        XCTAssertEqual(turkish["house_rockets_start"] as? String, "Uçuşu başlat")
        XCTAssertEqual(english["house_rockets_start"] as? String, "Start flight")
        let constants = try object(houseRocketsConstants())
        XCTAssertEqual(constants["countdownStepMillis"] as? Int, 750)
        XCTAssertEqual(constants["trackHeight"] as? Double, 360)
    }
}
