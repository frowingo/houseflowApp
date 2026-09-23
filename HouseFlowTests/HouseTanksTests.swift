import CoreGraphics
import XCTest
@testable import HouseFlow

@MainActor
final class HouseTanksTests: XCTestCase {
    func testDamageRemovesOneArmorAndEliminatesAtZero() {
        let targetID = UUID()
        var players = makePlayers(targetID: targetID, targetArmor: 2)

        players = HouseTanksMatchRules.applyingDamage(to: players, targetID: targetID)
        XCTAssertEqual(players.first { $0.id == targetID }?.armor, 1)
        XCTAssertEqual(players.first { $0.id == targetID }?.isAlive, true)

        players = HouseTanksMatchRules.applyingDamage(to: players, targetID: targetID)
        XCTAssertEqual(players.first { $0.id == targetID }?.armor, 0)
        XCTAssertEqual(players.first { $0.id == targetID }?.isAlive, false)
    }

    func testRoundEndsOnlyWhenOneTankRemains() {
        let players = makePlayers().enumerated().map { index, player in
            var updated = player
            updated.isAlive = index == 0
            updated.armor = index == 0 ? 3 : 0
            return updated
        }

        XCTAssertEqual(
            HouseTanksMatchRules.resolveRound(players: players, timeExpired: false),
            .winner(players[0].id)
        )
    }

    func testSimultaneousEliminationIsDraw() {
        let players = makePlayers().map { player in
            var updated = player
            updated.isAlive = false
            updated.armor = 0
            return updated
        }

        XCTAssertEqual(
            HouseTanksMatchRules.resolveRound(players: players, timeExpired: false),
            .draw
        )
    }

    func testTimerUsesUniqueHighestArmorAndDrawsOnTie() {
        var players = makePlayers()
        players[0].armor = 4
        players[1].armor = 2
        players[2].armor = 1
        XCTAssertEqual(
            HouseTanksMatchRules.resolveRound(players: players, timeExpired: true),
            .winner(players[0].id)
        )

        players[1].armor = 4
        XCTAssertEqual(
            HouseTanksMatchRules.resolveRound(players: players, timeExpired: true),
            .draw
        )
    }

    func testThreeRoundWinsProducesChampion() {
        var players = makePlayers()
        let winnerID = players[1].id

        for _ in 0..<3 {
            players = HouseTanksMatchRules.awardingRound(to: winnerID, players: players)
        }

        XCTAssertEqual(HouseTanksMatchRules.champion(in: players, winsNeeded: 3), winnerID)
        XCTAssertEqual(players[1].roundsWon, 3)
    }

    func testAnglesAreNormalizedForAimLocking() {
        XCTAssertEqual(HouseTanksMath.normalizedAngle(.pi * 3), .pi, accuracy: 0.001)
        XCTAssertEqual(HouseTanksMath.normalizedAngle(-.pi * 3), -.pi, accuracy: 0.001)
    }

    func testBotDifficultyChangesAimTolerance() {
        let bot = HouseTanksBotController(playerID: UUID(), randomUnit: { 0 })
        let observation = HouseTanksBotObservation(
            aimError: 0.32,
            targetDistance: 200,
            hasTarget: true
        )

        XCTAssertTrue(bot.shouldFire(observation: observation, difficulty: .easy))
        XCTAssertFalse(bot.shouldFire(observation: observation, difficulty: .hard))
        XCTAssertGreaterThan(
            bot.holdDuration(for: .hard),
            bot.holdDuration(for: .easy)
        )
    }

    private func makePlayers(
        targetID: UUID = UUID(),
        targetArmor: Int = 5
    ) -> [HouseTanksPlayer] {
        [
            HouseTanksPlayer(
                id: targetID,
                nameKey: "human",
                role: .human,
                color: .teal,
                armor: targetArmor,
                roundsWon: 0,
                isAlive: true
            ),
            HouseTanksPlayer(
                id: UUID(),
                nameKey: "bot-1",
                role: .bot,
                color: .orange,
                armor: 5,
                roundsWon: 0,
                isAlive: true
            ),
            HouseTanksPlayer(
                id: UUID(),
                nameKey: "bot-2",
                role: .bot,
                color: .blue,
                armor: 5,
                roundsWon: 0,
                isAlive: true
            ),
        ]
    }
}
