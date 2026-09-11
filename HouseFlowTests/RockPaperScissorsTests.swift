import XCTest
@testable import HouseFlow

@MainActor
final class RockPaperScissorsTests: XCTestCase {
    func testAllNineMoveCombinations() async throws {
        for first in RPSMove.allCases {
            for second in RPSMove.allCases {
                XCTAssertEqual(first.beats(second), [(RPSMove.rock, RPSMove.scissors), (.paper, .rock), (.scissors, .paper)].contains { $0 == first && $1 == second })
                var calls = 0
                let service = DemoRPSGameService(countdownNanoseconds: 0) { limit in
                    calls += 1
                    return calls == 1 ? limit - 1 : RPSMove.allCases.firstIndex(of: second)!
                }
                let driver = Driver(service: service)
                try await driver.start(count: 2)
                try await driver.send(.advance)
                let match = try XCTUnwrap(driver.state.activeMatch)
                try await driver.send(.play(matchID: match.id, attempt: 1, move: first))
                XCTAssertEqual(driver.state.phase, .countdown)
                XCTAssertNil(driver.state.activeMatch?.firstMove)
                XCTAssertNil(driver.state.activeMatch?.secondMove)
                await driver.reveal()
                XCTAssertEqual(driver.state.activeMatch?.firstMove, first)
                XCTAssertEqual(driver.state.activeMatch?.secondMove, second)
                XCTAssertEqual(driver.state.activeMatch?.winnerID, first == second ? nil : (first.beats(second) ? match.first.id : match.second.id))
                if first == second {
                    try await driver.send(.advance)
                    XCTAssertEqual(driver.state.activeMatch?.id, match.id)
                    XCTAssertEqual(driver.state.activeMatch?.attempt, 2)
                    XCTAssertNil(driver.state.activeMatch?.firstMove)
                    XCTAssertEqual(driver.state.phase, .choosing)
                }
                service.disconnect()
            }
        }
    }

    func testEveryPlayerCountCompletesWithValidPairings() async throws {
        for count in 2...8 {
            for seed in 1...20 {
                var rng = UInt64(seed)
                let service = DemoRPSGameService(countdownNanoseconds: 0) { limit in
                    rng = rng &* 6364136223846793005 &+ 1442695040888963407
                    return Int((rng >> 32) % UInt64(limit))
                }
                let driver = Driver(service: service)
                try await driver.start(count: count)
                var expected = Set(driver.state.players.map(\.id))
                var eliminated = Set<UUID>()
                var steps = 0
                while driver.state.phase != .finished && steps < 500 {
                    steps += 1
                    switch driver.state.phase {
                    case .draw:
                        let round = try XCTUnwrap(driver.state.currentRound)
                        let assigned = round.matches.flatMap { [$0.first.id, $0.second.id] } + [round.bye?.id].compactMap { $0 }
                        XCTAssertEqual(Set(assigned), expected)
                        XCTAssertEqual(assigned.count, expected.count)
                        XCTAssertEqual(round.bye != nil, !expected.count.isMultiple(of: 2))
                        XCTAssertTrue(round.matches.allSatisfy { $0.first.id != $0.second.id })
                        XCTAssertTrue(Set(assigned).isDisjoint(with: eliminated))
                        try await driver.send(.advance)
                    case .choosing:
                        let match = try XCTUnwrap(driver.state.activeMatch)
                        let move: RPSMove? = driver.state.localPlayerIsPlaying ? RPSMove.allCases[steps % 3] : nil
                        try await driver.send(.play(matchID: match.id, attempt: match.attempt, move: move))
                        await driver.reveal()
                    case .reveal: try await driver.send(.advance)
                    case .roundComplete:
                        let round = try XCTUnwrap(driver.state.currentRound)
                        XCTAssertTrue(round.isComplete)
                        let next = Set(round.advancingPlayers.map(\.id))
                        XCTAssertEqual(next.count, (expected.count + 1) / 2)
                        eliminated.formUnion(expected.subtracting(next))
                        expected = next
                        try await driver.send(.advance)
                    default: XCTFail("Unexpected phase"); return
                    }
                }
                XCTAssertLessThan(steps, 500)
                XCTAssertEqual(driver.state.phase, .finished)
                XCTAssertEqual(expected, [try XCTUnwrap(driver.state.champion).id])
                XCTAssertEqual(eliminated.count, count - 1)
                XCTAssertEqual(driver.state.rounds.flatMap(\.matches).count, count - 1)
                let data = try JSONEncoder().encode(driver.state)
                XCTAssertEqual(try JSONDecoder().decode(RPSSnapshot.self, from: data), driver.state)
                service.disconnect()
            }
        }
    }

    func testEveryPlayerIsEligibleForOddRoundBye() async throws {
        for count in [3, 5, 7] {
            for selected in 0..<count {
                var firstDraw = true
                let service = DemoRPSGameService { limit in
                    defer { firstDraw = false }
                    return firstDraw ? selected : limit - 1
                }
                let driver = Driver(service: service)
                try await driver.start(count: count)
                XCTAssertEqual(driver.state.currentRound?.bye?.id, driver.state.players[selected].id)
                service.disconnect()
            }
        }
    }

    func testInvalidRostersAndDuplicateInputsAreRejected() async throws {
        let service = DemoRPSGameService(countdownNanoseconds: 0)
        for count in [0, 1, 9] {
            let players = roster(count)
            do {
                try await service.start(players: players, localPlayerID: players.first?.id ?? UUID())
                XCTFail("Invalid player count accepted")
            } catch { XCTAssertTrue(error is RPSGameError) }
        }
        let duplicate = roster(2).map { RPSPlayer(name: " same ", avatarIndex: $0.avatarIndex) }
        do {
            try await service.start(players: duplicate, localPlayerID: duplicate[0].id)
            XCTFail("Duplicate name accepted")
        } catch { XCTAssertTrue(error is RPSGameError) }
        let driver = Driver(service: service)
        try await driver.start(count: 2)
        let oldCommand = RPSCommand(sessionID: driver.state.sessionID, expectedRevision: driver.state.revision, action: .advance)
        try await driver.send(.advance)
        do { try await service.send(oldCommand); XCTFail("Duplicate command accepted") }
        catch { XCTAssertTrue(error is RPSGameError) }
        let match = try XCTUnwrap(driver.state.activeMatch)
        for action in [RPSAction.play(matchID: UUID(), attempt: 1, move: .rock),
                       .play(matchID: match.id, attempt: 99, move: .rock),
                       .play(matchID: match.id, attempt: 1, move: nil), .advance] {
            do {
                try await service.send(RPSCommand(sessionID: driver.state.sessionID, expectedRevision: driver.state.revision, action: action))
                XCTFail("Invalid action accepted")
            } catch { XCTAssertTrue(error is RPSGameError) }
        }
        try await driver.start(count: 3)
        do { try await service.send(oldCommand); XCTFail("Previous session command accepted") }
        catch { XCTAssertTrue(error is RPSGameError) }
        service.disconnect()
    }

    func testRestartCancelsPendingRevealAndDisconnectFinishesStream() async throws {
        let service = DemoRPSGameService(countdownNanoseconds: 1_000_000)
        let driver = Driver(service: service)
        try await driver.start(count: 2)
        let oldSession = driver.state.sessionID
        try await driver.send(.advance)
        let match = try XCTUnwrap(driver.state.activeMatch)
        try await driver.send(.play(matchID: match.id, attempt: 1, move: .rock))
        try await driver.start(count: 5)
        XCTAssertNotEqual(driver.state.sessionID, oldSession)
        try await Task.sleep(nanoseconds: 10_000_000)
        service.disconnect()
        let next = await driver.next()
        XCTAssertNil(next, "Cancelled reveal must not publish into a new session")
    }

    func testLobbyLimitsAndProtectedLocalPlayer() async {
        let model = RockPaperScissorsViewModel(service: DemoRPSGameService())
        let local = model.players[0]
        model.removePlayer(local)
        XCTAssertEqual(model.players.count, 4)
        for name in ["One", "Two", "Three", "Four", "Five"] {
            model.newPlayerName = name
            model.addPlayer()
        }
        XCTAssertEqual(model.players.count, 8)
        XCTAssertEqual(Set(model.players.map(\.avatarIndex)).count, 8)
        while model.players.count > 2 { model.removePlayer(model.players.last!) }
        model.removePlayer(model.players.last!)
        XCTAssertEqual(model.players.count, 2)
        model.newPlayerName = "  "
        XCTAssertFalse(model.canAddPlayer)
        model.newPlayerName = local.name.uppercased()
        XCTAssertFalse(model.canAddPlayer)
        model.newPlayerName = String(repeating: "a", count: 25)
        XCTAssertFalse(model.canAddPlayer)
    }

    private func roster(_ count: Int) -> [RPSPlayer] {
        (0..<count).map { RPSPlayer(name: "Player \($0)", avatarIndex: $0) }
    }
}

@MainActor
private final class Driver {
    let service: DemoRPSGameService
    var iterator: AsyncStream<RPSSnapshot>.Iterator
    var state: RPSSnapshot!

    init(service: DemoRPSGameService) {
        self.service = service
        iterator = service.events().makeAsyncIterator()
    }

    func start(count: Int) async throws {
        let players = (0..<count).map { RPSPlayer(name: "Player \($0)", avatarIndex: $0) }
        try await service.start(players: players, localPlayerID: players[0].id)
        state = await next()
    }

    func send(_ action: RPSAction) async throws {
        try await service.send(RPSCommand(sessionID: state.sessionID, expectedRevision: state.revision, action: action))
        state = await next()
    }

    func next() async -> RPSSnapshot? {
        var pending = iterator
        let snapshot = await pending.next()
        iterator = pending
        return snapshot
    }

    func reveal() async {
        while state.phase == .countdown {
            state = await next()
        }
    }
}
