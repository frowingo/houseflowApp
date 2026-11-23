import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class PushRouteHandlerTests: XCTestCase {
    private var state = PushRouteHandler.Snapshot(
        isSignedIn: true, houseIDs: ["h1", "h2"], selectedHouseID: "h1", isSwitchingHouse: false,
        isDashboardRoute: true, isOverlayPresented: false, loadedChoreIDs: ["c1"]
    )
    private var switched: [String] = []
    private var inbox: PushInbox!
    private var handler: PushRouteHandler!

    override func setUp() async throws {
        inbox = PushInbox()
        handler = PushRouteHandler(
            snapshot: { [unowned self] in self.state },
            switchHouse: { [unowned self] in self.switched.append($0) },
            inbox: inbox
        )
        handler.start()
    }

    func testAChoreReminderOpensTheChoreAndClearsTheTarget() {
        inbox.offer(["houseId": "h1", "choreId": "c1"])

        XCTAssertEqual(handler.choreToOpen, "c1")
        handler.consumeChoreToOpen()
        handler.evaluate()
        XCTAssertNil(handler.choreToOpen)
    }

    func testATapBeforeSignInWaitsAndFiresOnceTheContextIsReady() {
        state.isSignedIn = false
        state.houseIDs = nil
        inbox.offer(["houseId": "h1", "choreId": "c1"])
        XCTAssertNil(handler.choreToOpen)

        state.isSignedIn = true
        state.houseIDs = ["h1"]
        handler.evaluate()

        XCTAssertEqual(handler.choreToOpen, "c1")
    }

    func testAColdStartTapIsTakenWhenTheHandlerStarts() {
        let early = PushInbox()
        early.offer(["houseId": "h1", "choreId": "c1"])
        let late = PushRouteHandler(snapshot: { [unowned self] in self.state }, switchHouse: { _ in }, inbox: early)

        late.start()

        XCTAssertEqual(late.choreToOpen, "c1")
        XCTAssertNil(early.pending)
    }

    func testANewerTapReplacesThePendingOne() {
        state.isSwitchingHouse = true
        inbox.offer(["houseId": "h1", "choreId": "c1"])
        inbox.offer(["houseId": "h2"])

        state.isSwitchingHouse = false
        handler.evaluate()

        XCTAssertEqual(switched, ["h2"])
        XCTAssertNil(handler.choreToOpen)
    }

    func testSwitchingHouseIsStartedOncePerTargetAndThenFollowedThrough() {
        inbox.offer(["houseId": "h2", "choreId": "c1"])
        handler.evaluate()
        handler.evaluate()
        XCTAssertEqual(switched, ["h2"])

        // The switch is running, then the new house is selected with its chores loaded.
        state.isSwitchingHouse = true
        state.isDashboardRoute = false
        handler.evaluate()
        state.isSwitchingHouse = false
        state.isDashboardRoute = true
        state.selectedHouseID = "h2"
        state.loadedChoreIDs = ["c1"]
        handler.evaluate()

        XCTAssertEqual(switched, ["h2"])
        XCTAssertEqual(handler.choreToOpen, "c1")
    }

    func testAFailedSwitchDropsTheTapSoItDoesNotFireLater() {
        inbox.offer(["houseId": "h2", "choreId": "c1"])
        XCTAssertEqual(switched, ["h2"])

        // The switch ran, failed and left the user on the old house.
        state.isSwitchingHouse = true
        state.isDashboardRoute = false
        handler.evaluate()
        state.isSwitchingHouse = false
        state.isDashboardRoute = true
        handler.evaluate()

        // Opening that house by hand later does nothing.
        state.selectedHouseID = "h2"
        state.loadedChoreIDs = ["c1"]
        handler.evaluate()
        XCTAssertEqual(switched, ["h2"])
        XCTAssertNil(handler.choreToOpen)
    }

    func testShowingTheDashboardClosesPopupsOnceThenOpensTheChore() {
        handler.selectedTab = .profile
        state.isOverlayPresented = true
        inbox.offer(["houseId": "h1", "choreId": "c1"])

        XCTAssertEqual(handler.selectedTab, .home)
        XCTAssertEqual(handler.dashboardResetCount, 1)

        // Still covered: the same step is not performed again.
        handler.evaluate()
        XCTAssertEqual(handler.dashboardResetCount, 1)
        XCTAssertNil(handler.choreToOpen)

        state.isOverlayPresented = false
        handler.evaluate()
        XCTAssertEqual(handler.choreToOpen, "c1")
        XCTAssertEqual(handler.dashboardResetCount, 1)
    }

    func testAnOpenGameBlocksEverythingUntilItCloses() {
        handler.selectedTab = .games
        handler.isGameOpen = true
        state.selectedHouseID = "h2"
        inbox.offer(["houseId": "h1", "choreId": "c1"])

        XCTAssertTrue(switched.isEmpty)
        XCTAssertEqual(handler.selectedTab, .games)
        XCTAssertEqual(handler.dashboardResetCount, 0)

        handler.isGameOpen = false
        handler.evaluate()
        XCTAssertEqual(switched, ["h1"])
    }

    func testAForeignHouseIsDroppedAndNothingFiresLater() {
        state.houseIDs = ["h2"]
        inbox.offer(["houseId": "h1", "choreId": "c1"])

        state.houseIDs = ["h1"]
        handler.evaluate()

        XCTAssertNil(handler.choreToOpen)
        XCTAssertTrue(switched.isEmpty)
    }

    func testAChoreThatIsNotLoadedJustLeavesTheHouseOpen() {
        inbox.offer(["houseId": "h1", "choreId": "missing"])

        XCTAssertNil(handler.choreToOpen)
        state.loadedChoreIDs = ["missing"]
        handler.evaluate()
        XCTAssertNil(handler.choreToOpen)
    }

    func testChoresStillLoadingKeepTheTarget() {
        state.loadedChoreIDs = nil
        inbox.offer(["houseId": "h1", "choreId": "c1"])
        XCTAssertNil(handler.choreToOpen)

        state.loadedChoreIDs = ["c1"]
        handler.evaluate()
        XCTAssertEqual(handler.choreToOpen, "c1")
    }

    func testSignOutClearsThePendingTargetAndTheInbox() {
        state.isSignedIn = false
        inbox.offer(["houseId": "h1", "choreId": "c1"])

        handler.clear()
        state.isSignedIn = true
        handler.evaluate()

        XCTAssertNil(handler.choreToOpen)
        XCTAssertNil(inbox.pending)
    }

    func testTapsWithoutAHouseAreIgnored() {
        inbox.offer(["choreId": "c1"])
        handler.evaluate()
        XCTAssertNil(handler.choreToOpen)
    }

    func testLeavingTheDashboardRouteResetsTheTabAndTheGameFlag() {
        handler.selectedTab = .games
        handler.isGameOpen = true

        state.isDashboardRoute = false
        handler.evaluate()

        XCTAssertEqual(handler.selectedTab, .home)
        XCTAssertFalse(handler.isGameOpen)
    }
}
