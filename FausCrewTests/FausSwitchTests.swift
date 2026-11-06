import FausCrewCore
import XCTest
@testable import FausCrew

/// App-side Faus Switch: the view model's demo loop, color choice and bundled copy.
/// Physics, bots and the online engine are covered in FausCrewCore's tests.
@MainActor
final class FausSwitchTests: XCTestCase {
    private func makeModel() -> (FausSwitchViewModel, UserDefaults) {
        let suite = "FausSwitchTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defaults.removePersistentDomain(forName: suite)
        return (FausSwitchViewModel(userDefaults: defaults), defaults)
    }

    private func frame(_ model: FausSwitchViewModel, seconds: TimeInterval) -> FausSwitchRenderFrame? {
        var last: FausSwitchRenderFrame?
        var remaining = seconds
        while remaining > 0 {
            last = model.scene.frameProvider?(min(0.1, remaining))
            remaining -= 0.1
        }
        return last
    }

    func testRobotColorIsRememberedAndBotsTakeOtherColors() {
        let (model, defaults) = makeModel()
        model.robotColor = .ocean
        model.botCount = 3
        XCTAssertEqual(defaults.string(forKey: "faus_switch_color"), "ocean")
        XCTAssertEqual(model.demoBotColors.count, 3)
        XCTAssertFalse(model.demoBotColors.contains(.ocean))
        XCTAssertEqual(FausSwitchViewModel(userDefaults: defaults).robotColor, .ocean)
    }

    func testDemoCountsDownThenRunsEveryRobot() throws {
        let (model, _) = makeModel()
        model.selectMode(.demo)
        model.botCount = 2
        model.startDemo()
        XCTAssertTrue(model.isDemoVisible)
        XCTAssertEqual(model.match?.phase, .countdown)

        let start = try XCTUnwrap(frame(model, seconds: 0.1))
        XCTAssertEqual(start.runners.count, 3)
        XCTAssertEqual(start.localRunner?.color, model.robotColor)

        let running = try XCTUnwrap(frame(model, seconds: 4))
        XCTAssertEqual(running.phase, .playing)
        XCTAssertGreaterThan(running.cameraFocus, FausSwitchMetrics.spawnX)
        XCTAssertEqual(model.match?.standings.count, 3)
    }

    func testPauseFreezesTheRace() throws {
        let (model, _) = makeModel()
        model.startDemo()
        _ = frame(model, seconds: 4)
        model.pauseDemo()
        XCTAssertTrue(model.isPaused)
        let before = try XCTUnwrap(frame(model, seconds: 0.1)).tick
        let after = try XCTUnwrap(frame(model, seconds: 1)).tick
        XCTAssertEqual(before, after)
        model.resumeDemo()
        XCTAssertGreaterThan(try XCTUnwrap(frame(model, seconds: 0.5)).tick, after)
    }

    func testIdlePlayerEventuallySeesTheResult() {
        let (model, _) = makeModel()
        model.botCount = 1
        model.startDemo()
        var seconds = 0.0
        while !model.showsDemoResult, seconds < 60 {
            _ = frame(model, seconds: 1)
            seconds += 1
        }
        XCTAssertTrue(model.showsDemoResult, "A robot that never flips crashes or is left behind")
        guard case .crashed = model.match?.localStatus else { return XCTFail("Expected a crash") }
        model.exitDemo()
        XCTAssertFalse(model.isDemoVisible)
        XCTAssertNil(model.scene.frameProvider?(0.1))
    }

    func testOnlinePortalIsHeardWhenTheRobotIsThrownBack() {
        let before = FausSwitchRunnerState.spawn(on: .down, x: 2_180)
        var thrown = before
        thrown.x = 1_970
        thrown.gravity = .up
        var running = before
        running.x += 2
        XCTAssertTrue(FausSwitchViewModel.wentThroughPortal(from: before, to: thrown))
        XCTAssertFalse(FausSwitchViewModel.wentThroughPortal(from: before, to: running))
        XCTAssertFalse(FausSwitchViewModel.wentThroughPortal(from: nil, to: thrown))
    }

    /// The rules card's gap clip slides a gap from beyond the right edge to beyond the
    /// left; every position must give valid rail pieces (a reversed range crashed the lobby).
    func testRuleClipRailsSurviveGapsOffEitherEdge() {
        var phase = 0.0
        while phase < 1 {
            let gap = 170 - 240 * CGFloat(phase)
            let parts = FausSwitchClipRails.parts(from: -10, to: 170, around: [gap...(gap + 30)])
            for part in parts {
                XCTAssertLessThan(part.lowerBound, part.upperBound)
                XCTAssertGreaterThanOrEqual(part.lowerBound, -10)
                XCTAssertLessThanOrEqual(part.upperBound, 170)
                XCTAssertFalse(part.lowerBound < gap + 30 && part.upperBound > gap, "No rail inside the gap")
            }
            phase += 0.01
        }
        XCTAssertEqual(FausSwitchClipRails.parts(from: -10, to: 170, around: [200...230]), [-10...170])
        XCTAssertEqual(FausSwitchClipRails.parts(from: -10, to: 170, around: [-60 ... -30]), [-10...170])
        XCTAssertEqual(FausSwitchClipRails.parts(from: -10, to: 170, around: [50...80]), [-10...50, 80...170])
    }

    func testEveryKeyTheGameShowsHasBundledCopy() {
        var keys = ["games_faus_switch_title", "games_faus_switch_card_description", "faus_switch_title"]
        keys += FausSwitchColor.allCases.map(\.titleKey)
        keys += FausSwitchBotMatch.botNameKeys
        keys += ["faus_switch_rule_slow_title", "faus_switch_rule_slow_detail", "faus_switch_rule_portal_title",
                 "faus_switch_rule_portal_detail", "faus_switch_music_on", "faus_switch_music_off",
                 "faus_switch_sound_on", "faus_switch_sound_off"]
        let reasons: [FausSwitchCrashReason?] = [.boundary, .leftBehind, .forfeit, .membershipRevoked, nil]
        for reason in reasons {
            let key = FausSwitchOnlineCopyKeys.crashReason(reason)
            keys += [key, key + "_detail", key + "_short"]
        }
        var state = FausSwitchOnlineLobbyState()
        keys += [FausSwitchOnlineCopyKeys.roomStatus(state), FausSwitchOnlineCopyKeys.roomDetail(state)]
        state.connection = .failed
        keys += [FausSwitchOnlineCopyKeys.roomStatus(state), FausSwitchOnlineCopyKeys.roomDetail(state)]
        keys += [GameSessionPlayerState.ready, .waiting, .playing, .finished].map(FausSwitchOnlineCopyKeys.playerStatus)
        for key in keys {
            XCTAssertNotNil(FausSwitchLocalization.value(for: key, language: "tr"), key)
            XCTAssertNotNil(FausSwitchLocalization.value(for: key, language: "en"), key)
        }
        XCTAssertEqual(FausSwitchLocalization.value(for: "faus_switch_title", language: "en"), "Faus Switch")
        XCTAssertNil(FausSwitchLocalization.value(for: "games_house_switch_title", language: "tr"))
    }
}
