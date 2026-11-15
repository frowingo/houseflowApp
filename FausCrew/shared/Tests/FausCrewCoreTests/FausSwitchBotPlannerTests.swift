import Foundation
@testable import FausCrewCore
import XCTest

final class FausSwitchBotPlannerTests: XCTestCase {
    func testDelayedPlansNeverRetainConsumedAnswers() {
        let queue = DispatchQueue(label: "FausSwitchBotPlannerTests.delayed")
        let planner = FausSwitchBotPlanner(queue: queue)
        let match = UUID()
        let bots = ["bot-1", "bot-2", "bot-3"]
        queue.suspend()
        for tick in Int64(0)..<200 {
            for bot in bots {
                request(planner, match: match, bot: bot, tick: tick)
                XCTAssertNil(planner.take(match: match, bot: bot, tick: tick))
            }
        }
        queue.resume()
        planner.waitUntilIdle()
        XCTAssertEqual(planner.storedAnswerCount, 0, "All 600 delayed decisions were already consumed by fallback")

        for tick in Int64(200)..<220 {
            for bot in bots { request(planner, match: match, bot: bot, tick: tick) }
            planner.waitUntilIdle()
            XCTAssertEqual(planner.storedAnswerCount, bots.count)
            for bot in bots { XCTAssertNotNil(planner.take(match: match, bot: bot, tick: tick)) }
            XCTAssertEqual(planner.storedAnswerCount, 0)
        }
    }

    func testSkippingADecisionPrunesItsAnswerAndMatchChangeResetsTheCutoff() {
        let planner = FausSwitchBotPlanner()
        let match = UUID()
        request(planner, match: match, bot: "bot", tick: 10)
        planner.waitUntilIdle()
        XCTAssertEqual(planner.storedAnswerCount, 1)
        XCTAssertNil(planner.take(match: match, bot: "bot", tick: 11))
        XCTAssertEqual(planner.storedAnswerCount, 0)
        request(planner, match: match, bot: "bot", tick: 10)
        planner.waitUntilIdle()
        XCTAssertEqual(planner.storedAnswerCount, 0)

        let nextMatch = UUID()
        request(planner, match: nextMatch, bot: "bot", tick: 0)
        planner.waitUntilIdle()
        XCTAssertNil(planner.take(match: match, bot: "bot", tick: 100))
        XCTAssertNotNil(planner.take(match: nextMatch, bot: "bot", tick: 0))
        XCTAssertEqual(planner.storedAnswerCount, 0)
    }

    private func request(_ planner: FausSwitchBotPlanner, match: UUID, bot: String, tick: Int64) {
        let plan = FausSwitchBotPlan(state: .spawn(on: .down), others: [], fromTick: tick, decisionTick: tick)
        planner.request(match: match, bot: bot, brain: .init(skill: .hard), plan: plan, course: .standard)
    }
}
