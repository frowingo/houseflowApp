import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class GameStatsStoreTests: XCTestCase {
    private var service: FakeGameStatsService!
    private var sleeps: [Duration] = []
    private var accessLost = 0

    override func setUp() async throws {
        service = FakeGameStatsService()
        sleeps = []
        accessLost = 0
    }

    private func makeStore() -> GameStatsStore {
        let store = GameStatsStore(service: service, rateLimitDelay: .seconds(2), sleep: { [unowned self] in self.sleeps.append($0) })
        store.onAccessLost = { [unowned self] in self.accessLost += 1 }
        return store
    }

    private let fausSwitch = HouseGameStats(gameKey: "fausSwitch", players: [PlayerGameStats(userId: "u1", wins: 2, matchesPlayed: 3)])
    private let tanks = HouseGameStats(gameKey: "houseTanks", players: [PlayerGameStats(userId: "u1", wins: 0, matchesPlayed: 1)])

    func testNothingLoadsWithoutContextOrRefresh() async {
        let store = makeStore()
        await store.refresh()
        XCTAssertTrue(service.calls.isEmpty)

        store.setContext(userID: "u1", houseID: "h1")
        XCTAssertTrue(service.calls.isEmpty, "loading waits for the card")
        XCTAssertEqual(store.phase, .idle)
    }

    func testRefreshLoadsTheSelectedHouse() async {
        let store = makeStore()
        service.results = [.success([fausSwitch])]
        store.setContext(userID: "u1", houseID: "h1")

        await store.refresh()

        XCTAssertEqual(service.calls, ["h1"])
        XCTAssertEqual(store.phase, .loaded)
        XCTAssertEqual(store.stats, [fausSwitch])
    }

    func testEmptyHouseIsLoadedNotFailed() async {
        let store = makeStore()
        service.results = [.success([])]
        store.setContext(userID: "u1", houseID: "h1")
        await store.refresh()
        XCTAssertEqual(store.phase, .loaded)
        XCTAssertTrue(store.stats.isEmpty)
    }

    func testFailedRefreshKeepsTheShownStandings() async {
        let store = makeStore()
        service.results = [.success([fausSwitch]), .failure(GameStatsFailure(kind: .server, message: "Down"))]
        store.setContext(userID: "u1", houseID: "h1")
        await store.refresh()
        await store.refresh()

        XCTAssertEqual(store.phase, .loaded)
        XCTAssertEqual(store.stats, [fausSwitch])
        XCTAssertNil(store.failureMessage)
    }

    func testFirstLoadFailureShowsTheServerMessage() async {
        let store = makeStore()
        service.results = [.failure(GameStatsFailure(kind: .server, message: "Down"))]
        store.setContext(userID: "u1", houseID: "h1")
        await store.refresh()
        XCTAssertEqual(store.phase, .failed)
        XCTAssertEqual(store.failureMessage, "Down")
    }

    func testRateLimitWithNothingShownRetriesOnceAfterAWait() async {
        let store = makeStore()
        service.results = [.failure(GameStatsFailure(kind: .rateLimited, message: nil)), .success([tanks])]
        store.setContext(userID: "u1", houseID: "h1")

        await store.refresh()

        XCTAssertEqual(sleeps, [.seconds(2)])
        XCTAssertEqual(service.calls, ["h1", "h1"])
        XCTAssertEqual(store.stats, [tanks])
        XCTAssertEqual(store.phase, .loaded)
    }

    func testRateLimitTwiceFails() async {
        let store = makeStore()
        let limited = GameStatsFailure(kind: .rateLimited, message: "Slow down")
        service.results = [.failure(limited), .failure(limited)]
        store.setContext(userID: "u1", houseID: "h1")

        await store.refresh()

        XCTAssertEqual(service.calls.count, 2)
        XCTAssertEqual(store.phase, .failed)
        XCTAssertEqual(store.failureMessage, "Slow down")
    }

    func testRateLimitWithStandingsShownKeepsThemQuietly() async {
        let store = makeStore()
        service.results = [.success([fausSwitch]), .failure(GameStatsFailure(kind: .rateLimited, message: nil))]
        store.setContext(userID: "u1", houseID: "h1")
        await store.refresh()
        await store.refresh()

        XCTAssertTrue(sleeps.isEmpty)
        XCTAssertEqual(service.calls.count, 2)
        XCTAssertEqual(store.phase, .loaded)
        XCTAssertEqual(store.stats, [fausSwitch])
    }

    func testAccessLostIsReportedOncePerContext() async {
        let store = makeStore()
        let lost = GameStatsFailure(kind: .accessLost, message: nil)
        service.results = [.failure(lost), .failure(lost), .failure(lost)]
        store.setContext(userID: "u1", houseID: "h1")
        await store.refresh()
        await store.refresh()
        XCTAssertEqual(accessLost, 1, "an unchanged house must not loop")

        store.setContext(userID: "u1", houseID: "h2")
        await store.refresh()
        XCTAssertEqual(accessLost, 2)
    }

    func testContextChangeClearsAndDropsTheOldAnswer() async {
        let store = makeStore()
        service.results = [.success([fausSwitch])]
        store.setContext(userID: "u1", houseID: "h1")
        service.beforeAnswer = { store.setContext(userID: "u1", houseID: "h2") }

        await store.refresh()

        XCTAssertTrue(store.stats.isEmpty)
        XCTAssertEqual(store.phase, .idle)
    }

    func testCancellationLeavesNoError() async {
        let store = makeStore()
        service.results = [.failure(CancellationError())]
        store.setContext(userID: "u1", houseID: "h1")
        await store.refresh()
        XCTAssertEqual(store.phase, .idle)
        XCTAssertNil(store.failureMessage)
    }
}

@MainActor
private final class FakeGameStatsService: GameStatsServicing {
    var results: [Result<[HouseGameStats], any Error>] = []
    var beforeAnswer: (() -> Void)?
    private(set) var calls: [String] = []

    func stats(houseID: String) async throws -> [HouseGameStats] {
        calls.append(houseID)
        beforeAnswer?()
        beforeAnswer = nil
        guard !results.isEmpty else { return [] }
        return try results.removeFirst().get()
    }
}
