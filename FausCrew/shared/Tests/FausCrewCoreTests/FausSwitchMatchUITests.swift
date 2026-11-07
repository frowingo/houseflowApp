import XCTest
@testable import FausCrewCore

/// The overlay rules iOS and Android both draw (`FausSwitchMatchUI`), and the bundled copy
/// they read.
final class FausSwitchMatchUITests: XCTestCase {
    func testDemoCountdownShowsNameTagsAndNoFlip() {
        var match = FausSwitchBotMatch()
        match.start(configuration: FausSwitchMatchConfiguration(humanColor: .ocean, botCount: 2, seed: 7))
        let ui = FausSwitchMatchUI.demo(match.frame(), canFlip: false)
        XCTAssertEqual(ui.phase, .countdown)
        XCTAssertEqual(ui.countdown, 3)
        XCTAssertEqual(ui.runnerCount, 3)
        XCTAssertEqual(ui.nameTags.count, 3)
        XCTAssertEqual(ui.standings.first { $0.isLocal }?.color, .ocean)
        XCTAssertEqual(ui.localStatus, .running)
        XCTAssertEqual(ui.demoOutcome, .timeUp)
    }

    func testDemoRaceToTheEndFillsTheResult() {
        var match = FausSwitchBotMatch()
        match.start(configuration: FausSwitchMatchConfiguration(humanColor: .plum, botCount: 1, seed: 11))
        while match.phase == .countdown { _ = match.advance(by: 1) }
        while match.phase == .playing { _ = match.stepOnce() }
        let ui = FausSwitchMatchUI.demo(match.frame(), canFlip: false)
        XCTAssertEqual(ui.phase, .ended)
        XCTAssertTrue(ui.nameTags.isEmpty)
        XCTAssertEqual(ui.standings.map(\.rank), [1, 2], "Ranked, best first")
        // The human never taps here, so it crashes.
        XCTAssertEqual(ui.demoOutcome, .crashed)
        guard case .crashed(let reason) = ui.localStatus else { return XCTFail("\(String(describing: ui.localStatus))") }
        XCTAssertEqual(ui.demoResultKeys.title, FausSwitchOnlineCopyKeys.crashReason(reason))
        XCTAssertEqual(ui.demoResultKeys.detail, FausSwitchOnlineCopyKeys.crashDetail(reason))
    }

    func testStandingStatusKeys() {
        func standing(_ status: FausSwitchStanding.Status) -> FausSwitchStanding {
            FausSwitchStanding(id: "a", nameKey: nil, displayName: nil, color: .forest, rank: nil, status: status, isLocal: false)
        }
        XCTAssertEqual(standing(.running).statusKey, "faus_switch_status_running")
        XCTAssertEqual(standing(.finished).statusKey, "faus_switch_status_finished")
        XCTAssertEqual(standing(.crashed(.leftBehind)).statusKey, "faus_switch_crashed_left_behind_short")
        XCTAssertTrue(standing(.crashed(nil)).isOut)
        XCTAssertFalse(standing(.finished).isOut)
        for status: FausSwitchStanding.Status in [.running, .finished, .crashed(.boundary), .crashed(.leftBehind), .crashed(.forfeit)] {
            XCTAssertNotNil(FausSwitchLocalization.value(for: standing(status).statusKey, language: "en"))
        }
    }

    func testOnlineWithoutARaceShowsOnlyTheRoom() {
        let ui = FausSwitchMatchUI.online(state: FausSwitchOnlineLobbyState(), presentation: nil, lastFrame: nil,
                                          result: FausSwitchOnlineResultState(), isRematchRoom: true, now: 0)
        XCTAssertTrue(ui.standings.isEmpty)
        XCTAssertFalse(ui.showsResult)
        XCTAssertTrue(ui.showsRematchRoom)
        XCTAssertFalse(ui.canFlip)
    }

    func testBlockGroupsSplitAtWideSpaces() {
        let course = FausSwitchCourse.standard
        let groups = course.blockGroups()
        let blocks = course.solids.filter { $0.kind == .block }.sorted { $0.rect.minX < $1.rect.minX }
        XCTAssertEqual(groups.count, blocks.count)
        XCTAssertEqual(groups[blocks[0].id], 0)
        var end = -Double.infinity
        for (previous, block) in zip(blocks, blocks.dropFirst()) {
            end = max(end, previous.rect.maxX)
            let step = (groups[block.id] ?? 0) - (groups[previous.id] ?? 0)
            XCTAssertEqual(step, block.rect.minX - end >= 200 ? 1 : 0, "block \(block.id)")
        }
    }

    func testCopyTableHasBothLanguages() {
        let english = FausSwitchLocalization.table(language: "en-GB")
        let turkish = FausSwitchLocalization.table(language: "tr")
        XCTAssertEqual(english.count, turkish.count)
        XCTAssertEqual(english["faus_switch_you"], "You")
        XCTAssertEqual(turkish["faus_switch_you"], "Sen")
        XCTAssertEqual(FausSwitchLocalization.table(language: nil)["faus_switch_you"], "Sen", "Turkish by default")
    }
}
