import XCTest
@testable import HouseFlow

@MainActor
final class HouseRocketsLocalSessionTests: XCTestCase {
    private var latest: HouseRocketsSnapshot?

    private func waitFor(_ condition: () -> Bool) async throws {
        for _ in 0..<200 {
            if condition() { return }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTFail("Timed out waiting for local session state")
        throw NSError(domain: "HouseRocketsTests", code: 1)
    }

    func testPhysicsAdvancesWithoutSceneAndPauseDoesNotCatchUp() async throws {
        var time = 0.0
        let service = DemoHouseRocketsSession(now: { time })
        let stream = service.events()
        let observation = Task { for await snapshot in stream { self.latest = snapshot } }
        defer { service.disconnect(); observation.cancel() }
        await service.start(configuration: .init(botCount: 1))
        try await waitFor { latest?.phase == .playing }
        time += 0.1
        try await waitFor { (latest?.elapsedTime ?? 0) > 0.09 }
        XCTAssertEqual(try XCTUnwrap(latest?.humanPlayer).worldX, 280, accuracy: 0.001)

        service.pause()
        try await waitFor { latest?.phase == .paused }
        let paused = try XCTUnwrap(latest)
        time += 10
        try await Task.sleep(nanoseconds: 60_000_000)
        XCTAssertEqual(latest?.elapsedTime, paused.elapsedTime)
        XCTAssertEqual(latest?.players, paused.players)

        service.resume()
        time += 0.1
        try await waitFor { (latest?.elapsedTime ?? 0) > paused.elapsedTime + 0.09 }
        XCTAssertEqual(try XCTUnwrap(latest).elapsedTime, paused.elapsedTime + 0.1, accuracy: 0.001)
        XCTAssertEqual(try XCTUnwrap(latest?.humanPlayer).worldX, 310, accuracy: 0.001)
    }

    func testHeadlessEliminationResultRematchAndStaleInput() async throws {
        var time = 0.0
        let service = DemoHouseRocketsSession(now: { time })
        let stream = service.events()
        let observation = Task { for await snapshot in stream { self.latest = snapshot } }
        defer { service.disconnect(); observation.cancel() }
        await service.start(configuration: .init(botCount: 1))
        try await waitFor { latest?.phase == .playing }
        let first = try XCTUnwrap(latest)
        await service.send(.init(matchID: first.matchID, playerID: first.humanPlayer?.id,
                                 sequence: 1, action: .steer(heading: .pi)))
        for _ in 0..<10 where latest?.phase == .playing {
            time += 0.2
            try await Task.sleep(nanoseconds: 25_000_000)
        }
        try await waitFor { latest?.phase == .ended }
        let ended = try XCTUnwrap(latest)
        XCTAssertFalse(try XCTUnwrap(ended.humanPlayer).isAlive)
        XCTAssertEqual(ended.winner?.role, .bot)
        XCTAssertEqual(ended.aliveCount, 1)

        await service.send(.init(matchID: first.matchID, playerID: nil, sequence: 2, action: .restart))
        try await waitFor { latest?.matchID != first.matchID && latest?.phase == .countdown }
        let rematch = try XCTUnwrap(latest)
        XCTAssertEqual(rematch.aliveCount, 2)
        XCTAssertEqual(rematch.elapsedTime, 0)
        XCTAssertNil(rematch.winnerID)
        await service.send(.init(matchID: first.matchID, playerID: first.humanPlayer?.id,
                                 sequence: 999, action: .steer(heading: .pi)))
        try await waitFor { latest?.phase == .playing }
        time += 0.1
        try await waitFor { (latest?.elapsedTime ?? 0) > 0.09 }
        XCTAssertEqual(try XCTUnwrap(latest?.humanPlayer).worldX, 280, accuracy: 0.001)
    }

    func testFactoryCreatesIndependentSessionsAndNormalizesBotCount() async throws {
        let factory = HouseRocketsSessionFactory.localOnly
        let first = factory.makeBotSession()
        let second = factory.makeBotSession()
        var firstEvents = first.events().makeAsyncIterator()
        var secondEvents = second.events().makeAsyncIterator()
        defer { first.disconnect(); second.disconnect() }
        await first.start(configuration: .init(botCount: 0))
        await second.start(configuration: .init(botCount: 99))
        let firstSnapshot = await firstEvents.next()
        let secondSnapshot = await secondEvents.next()
        XCTAssertEqual(firstSnapshot?.players.count, 2)
        XCTAssertEqual(secondSnapshot?.players.count, 4)
        XCTAssertNotEqual(firstSnapshot?.matchID, secondSnapshot?.matchID)
        XCTAssertEqual(firstSnapshot?.players.filter { $0.role == .human }.count, 1)
        XCTAssertEqual(secondSnapshot?.players.filter { $0.role == .bot }.count, 3)
        XCTAssertTrue(secondSnapshot?.players.allSatisfy { $0.role != .remote } == true)
        first.disconnect()
        while await firstEvents.next() != nil {}
        let secondUpdate = await secondEvents.next()
        XCTAssertNotNil(secondUpdate)
    }
}
