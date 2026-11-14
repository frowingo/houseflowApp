import XCTest
import FausCrewCore
@testable import FausCrewAndroidBridge

/// The Faus Switch demo over JNI: one call per frame returns the world (camera, robot
/// poses, platforms and the lost zone only when they change) and the overlays Core fills.
final class FausSwitchBridgeTests: XCTestCase {
    private func object(_ json: String) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: Data(json.utf8)) as? [String: Any])
    }

    func testDemoRaceLifecycleThroughTheFacade() throws {
        let handle = fausSwitchBotCreate()
        defer { XCTAssertTrue(fausSwitchBotDestroy(handle)) }

        let idle = try object(fausSwitchBotStep(handle, 0.016))
        XCTAssertEqual(idle["ok"] as? Bool, true)
        XCTAssertNil(idle["frame"], "No race before start")
        XCTAssertEqual(try object(fausSwitchBotViewport(handle, 844, 390))["changed"] as? Bool, true)

        let started = try object(fausSwitchBotStart(handle, "ocean", 3))
        let frame = try XCTUnwrap(started["frame"] as? [String: Any])
        XCTAssertEqual(frame["phase"] as? String, "countdown")
        let runners = try XCTUnwrap(frame["runners"] as? [[String: Any]])
        XCTAssertEqual(runners.count, 4)
        XCTAssertEqual(runners.first?["color"] as? String, "ocean")
        XCTAssertEqual(runners.first?["local"] as? Bool, true)
        XCTAssertEqual((frame["platforms"] as? [[String: Any]])?.count, 4, "One start platform per robot")
        XCTAssertNotNil(frame["lostZone"])
        let camera = try XCTUnwrap(frame["camera"] as? [String: Any])
        XCTAssertGreaterThan(camera["scale"] as? Double ?? 0, 0)

        let match = try XCTUnwrap(started["match"] as? [String: Any])
        XCTAssertEqual(match["countdown"] as? Int, 3)
        XCTAssertEqual(match["canFlip"] as? Bool, false)
        XCTAssertEqual((match["nameTags"] as? [[String: Any]])?.count, 4, "Names stand beside the robots until the run")
        XCTAssertEqual((match["standings"] as? [[String: Any]])?.count, 4)

        // A static field is not resent.
        let still = try XCTUnwrap(try object(fausSwitchBotStep(handle, 0.016))["frame"] as? [String: Any])
        XCTAssertNil(still["platforms"])
        XCTAssertNil(still["lostZone"])

        var events: [String] = []
        for _ in 0..<200 {
            let step = try object(fausSwitchBotStep(handle, 1.0 / 60))
            events += (step["events"] as? [[String: Any]] ?? []).compactMap { $0["type"] as? String }
        }
        XCTAssertTrue(events.contains("countdown"))
        XCTAssertTrue(events.contains("started"))
        let running = try object(fausSwitchBotStep(handle, 1.0 / 60))
        XCTAssertEqual((running["frame"] as? [String: Any])?["phase"] as? String, "playing")
        XCTAssertEqual((running["match"] as? [String: Any])?["canFlip"] as? Bool, true)
        XCTAssertEqual(((running["match"] as? [String: Any])?["nameTags"] as? [[String: Any]])?.count, 0)

        let flip = try object(fausSwitchBotFlip(handle))
        XCTAssertEqual(flip["flip"] as? String, "flipped")
        XCTAssertEqual(flip["gravity"] as? String, "up")
        XCTAssertEqual(try object(fausSwitchBotFlip(handle))["flip"] as? String, "unsupported", "Mid-air taps do nothing")

        XCTAssertEqual(try object(fausSwitchBotPause(handle))["changed"] as? Bool, true)
        let paused = try object(fausSwitchBotStep(handle, 0.5))
        XCTAssertEqual((paused["frame"] as? [String: Any])?["phase"] as? String, "paused")
        XCTAssertEqual(try object(fausSwitchBotFlip(handle))["flip"] as? String, "ignored")
        XCTAssertEqual(try object(fausSwitchBotResume(handle))["changed"] as? Bool, true)

        let restarted = try object(fausSwitchBotRestart(handle))
        XCTAssertEqual(restarted["changed"] as? Bool, true)
        let again = try XCTUnwrap(restarted["frame"] as? [String: Any])
        XCTAssertEqual(again["phase"] as? String, "countdown")
        XCTAssertNotEqual(again["matchId"] as? String, frame["matchId"] as? String)
        XCTAssertNotNil(again["platforms"], "A new race resends its platforms")
    }

    /// Robots are posed through the track exactly as the iOS scene poses them.
    func testRunnerPosesComeFromTheTrack() throws {
        let handle = fausSwitchBotCreate()
        defer { XCTAssertTrue(fausSwitchBotDestroy(handle)) }
        _ = fausSwitchBotStart(handle, "plum", 1)
        for _ in 0..<600 { _ = fausSwitchBotStep(handle, 1.0 / 60) }
        let frame = try XCTUnwrap(try object(fausSwitchBotStep(handle, 1.0 / 60))["frame"] as? [String: Any])
        let track = FausSwitchCourse.standard.track
        for runner in try XCTUnwrap(frame["runners"] as? [[String: Any]]) {
            let trackX = try XCTUnwrap(runner["trackX"] as? Double)
            let trackY = try XCTUnwrap(runner["trackY"] as? Double)
            XCTAssertGreaterThan(trackX, FausSwitchMetrics.spawnX)
            let pose = track.pose(x: trackX, y: trackY)
            XCTAssertEqual(pose.x, runner["x"] as? Double ?? .nan, accuracy: 1e-9)
            XCTAssertEqual(pose.y, runner["y"] as? Double ?? .nan, accuracy: 1e-9)
            XCTAssertEqual(pose.angle, runner["angle"] as? Double ?? .nan, accuracy: 1e-9)
        }
    }

    func testTooManyBotsAreClampedToTheDemoRange() throws {
        let handle = fausSwitchBotCreate()
        defer { XCTAssertTrue(fausSwitchBotDestroy(handle)) }
        let constants = try object(fausSwitchConstants())
        let maximum = try XCTUnwrap(constants["maximumBots"] as? Int)
        let frame = try XCTUnwrap(try object(fausSwitchBotStart(handle, "berry", 99))["frame"] as? [String: Any])
        let runners = try XCTUnwrap(frame["runners"] as? [[String: Any]])
        XCTAssertEqual(runners.count, maximum + 1)
        let scale = FausSwitchStartGrid.runnerScale(runnerCount: maximum + 1)
        XCTAssertTrue(runners.allSatisfy { $0["scale"] as? Double == scale })
    }

    func testCourseIsTheDrawnStandardCourse() throws {
        let course = try object(fausSwitchCourse())
        let standard = FausSwitchCourse.standard
        let sections = try XCTUnwrap(course["sections"] as? [[String: Any]])
        XCTAssertEqual(sections.count, standard.track.straightRanges(length: standard.length).count)
        XCTAssertEqual((course["turns"] as? [[String: Any]])?.count, standard.track.turns.count)
        XCTAssertEqual((course["blocks"] as? [[String: Any]])?.count, standard.solids.filter { $0.kind == .block }.count)
        XCTAssertEqual((course["gaps"] as? [[String: Any]])?.count, standard.gaps.count)
        XCTAssertEqual((course["boosts"] as? [[String: Any]])?.count, standard.boosts.count)
        XCTAssertEqual((course["slows"] as? [[String: Any]])?.count, standard.slows.count)
        XCTAssertEqual((course["portals"] as? [[String: Any]])?.count, standard.portals.count)
        XCTAssertEqual(course["finishX"] as? Double, standard.finishX)
        XCTAssertEqual(course["version"] as? Int, FausSwitchCourse.currentVersion)
        // Every rail piece lies inside its section.
        for rail in try XCTUnwrap(course["rails"] as? [[String: Any]]) {
            let section = sections[try XCTUnwrap(rail["section"] as? Int)]
            let rect = try XCTUnwrap(rail["rect"] as? [Double])
            XCTAssertGreaterThanOrEqual(rect[0], section["startX"] as? Double ?? .nan)
            XCTAssertLessThanOrEqual(rect[2], section["endX"] as? Double ?? .nan)
        }
        let finish = try XCTUnwrap(course["finishSection"] as? Int)
        XCTAssertTrue(sections.indices.contains(finish))
    }

    func testCopyAndConstants() throws {
        XCTAssertEqual(try object(fausSwitchCopy("en"))["faus_switch_title"] as? String, "Faus Switch")
        XCTAssertEqual(try object(fausSwitchCopy("tr"))["faus_switch_you"] as? String, "Sen")
        let constants = try object(fausSwitchConstants())
        let colors = try XCTUnwrap(constants["colors"] as? [[String: Any]])
        XCTAssertEqual(colors.map { $0["id"] as? String }, FausSwitchColor.allCases.map(\.rawValue))
        XCTAssertEqual(colors.first?["hex"] as? Int, Int(FausSwitchColor.allCases[0].bodyHex))
        XCTAssertEqual(constants["minimumBots"] as? Int, 1)
        XCTAssertEqual(constants["maximumRunners"] as? Int, 8)
    }

    func testUnknownHandleAndColorFailCleanly() throws {
        XCTAssertEqual(try object(fausSwitchBotStep(9_999, 0.016))["ok"] as? Bool, false)
        XCTAssertFalse(fausSwitchBotDestroy(9_999))
        let handle = fausSwitchBotCreate()
        defer { XCTAssertTrue(fausSwitchBotDestroy(handle)) }
        XCTAssertEqual(try object(fausSwitchBotStart(handle, "rainbow", 3))["ok"] as? Bool, false)
        XCTAssertEqual(try object(fausSwitchBotRestart(handle))["changed"] as? Bool, false, "Nothing to restart yet")
        XCTAssertEqual(try object(fausSwitchBotViewport(handle, 0, 390))["changed"] as? Bool, false)
    }
}
