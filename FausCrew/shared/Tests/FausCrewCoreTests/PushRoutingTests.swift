import XCTest
@testable import FausCrewCore

final class PushRoutingTests: XCTestCase {
    private let chore = PushTarget(data: ["houseId": "h1", "choreId": "c1"])!
    private let plain = PushTarget(data: ["houseId": "h1"])!

    private func context(
        signedIn: Bool = true, houses: [String]? = ["h1", "h2"], selected: String? = "h1", switching: Bool = false,
        game: Bool = false, dashboard: Bool = true, chores: Set<String>? = ["c1"]
    ) -> PushRouteContext {
        PushRouteContext(
            isSignedIn: signedIn, houseIDs: houses, selectedHouseID: selected, isSwitchingHouse: switching,
            isGameOpen: game, isDashboardShown: dashboard, loadedChoreIDs: chores)
    }

    func testWaitsUntilSignedInAndHousesLoaded() {
        XCTAssertEqual(PushRouting.next(chore, in: context(signedIn: false)), .wait)
        XCTAssertEqual(PushRouting.next(chore, in: context(houses: nil)), .wait)
    }

    func testDropsForeignHouse() {
        XCTAssertEqual(PushRouting.next(chore, in: context(houses: ["h2"])), .drop)
        XCTAssertEqual(PushRouting.next(chore, in: context(houses: [])), .drop)
    }

    func testGameAndSwitchingWait() {
        XCTAssertEqual(PushRouting.next(chore, in: context(selected: "h2", game: true)), .wait)
        XCTAssertEqual(PushRouting.next(chore, in: context(selected: "h2", switching: true)), .wait)
    }

    func testNotMemberWhileSwitchingDrops() {
        XCTAssertEqual(PushRouting.next(chore, in: context(houses: ["h2"], switching: true, game: true)), .drop)
    }

    func testSwitchesHouse() {
        XCTAssertEqual(PushRouting.next(chore, in: context(selected: "h2")), .switchHouse("h1"))
        XCTAssertEqual(PushRouting.next(chore, in: context(selected: nil)), .switchHouse("h1"))
    }

    func testShowsDashboardBeforeWaitingForChores() {
        XCTAssertEqual(PushRouting.next(chore, in: context(dashboard: false, chores: nil)), .showDashboard)
    }

    func testWaitsForChoresThenOpens() {
        XCTAssertEqual(PushRouting.next(chore, in: context(chores: nil)), .wait)
        XCTAssertEqual(PushRouting.next(chore, in: context()), .openChore("c1"))
    }

    func testMissingChoreOrNoChoreFinishes() {
        XCTAssertEqual(PushRouting.next(chore, in: context(chores: ["other"])), .finished)
        XCTAssertEqual(PushRouting.next(plain, in: context()), .finished)
        XCTAssertEqual(PushRouting.next(plain, in: context(chores: nil)), .wait)
    }
}
