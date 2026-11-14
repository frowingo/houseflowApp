import Foundation
import XCTest
#if canImport(CryptoKit)
import CryptoKit
#endif
@testable import FausCrewCore

/// `Fixtures/fausSwitchSimulation.json`: whole races recorded from this engine for the
/// backend's Go port (`houseflowApi/.../fausSwitch/simulationFixture_test.go` replays the
/// same file bit for bit).
///
/// Each scenario starts from `FausSwitchStartGrid.lanes(count:runnerScale:)` on
/// `FausSwitchCourse.race(runnerCount:)`. Tick by tick the flips listed for that tick are
/// applied in list order with `FausSwitchPhysics.flip(_:index:course:)`, then the field
/// steps. The checkpoint at tick T is the state after the step that reaches T, before T's
/// flips. Flips are attempts: an unsupported one is recorded and changes nothing.
///
/// The file is only written on demand, after a course or physics change:
/// `FAUS_SWITCH_WRITE_SIMULATION=1 swift test --package-path shared --filter FausSwitchSimulationFixtureTests`,
/// then update `fixtureSha256` and send the new file and hash to the backend.
final class FausSwitchSimulationFixtureTests: XCTestCase {
    /// sha256 of the file the backend has. Changes only with a regenerated fixture.
    private static let fixtureSha256 = "5bf34d8ddd81cdf4773565212e7ee389d8bd985ab55e359e9864a3d6ce807976"

    func testFixtureReplaysBitForBit() throws {
        let fixture = try Self.loadFixture()
        XCTAssertEqual(fixture.courseVersion, FausSwitchCourse.currentVersion)
        XCTAssertFalse(fixture.scenarios.isEmpty)
        for scenario in fixture.scenarios {
            try Self.replay(scenario)
        }
    }

    func testFixtureIsTheOneTheBackendHas() throws {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: try Data(contentsOf: Self.fixtureURL))
        let hex = digest.map { String(format: "%02x", $0) }.joined()
        XCTAssertEqual(hex, Self.fixtureSha256, "regenerated fixture: update fixtureSha256 and send the file to the backend")
        #endif
    }

    /// The races exercise every rule the backend must match, at both robot sizes.
    func testFixtureCoversTheRules() throws {
        let fixture = try Self.loadFixture()
        let counts = Set(fixture.scenarios.map { $0.runnerCount })
        XCTAssertTrue(counts.isSuperset(of: [2, 4, 8]), "\(counts)")
        XCTAssertTrue(counts.contains { $0 > FausSwitchStartGrid.crowdedRunnerThreshold })
        XCTAssertTrue(counts.contains { $0 <= FausSwitchStartGrid.crowdedRunnerThreshold })

        var outcomes = Set<String>()
        for scenario in fixture.scenarios {
            guard let last = scenario.checkpoints.last else { return XCTFail("\(scenario.name) has no checkpoints") }
            for runner in last.runners {
                outcomes.insert(runner.status == FausSwitchRunnerStatus.crashed ? runner.eliminationReason?.rawValue ?? "?" : runner.status.rawValue)
            }
            let coverage = Self.coverage(of: scenario)
            XCTAssertGreaterThan(coverage.portals, 0, "\(scenario.name) never sends a robot through a portal")
            XCTAssertGreaterThan(coverage.unsupportedFlips, 0, "\(scenario.name) never tries a flip in the air")
            if scenario.runnerCount > 1 {
                XCTAssertGreaterThan(coverage.robotSupport, 0, "\(scenario.name) never has a robot standing on another")
            }
        }
        XCTAssertTrue(outcomes.isSuperset(of: ["finished", "boundary", "leftBehind"]), "\(outcomes)")
    }

    func testWriteFixtureWhenAsked() throws {
        guard ProcessInfo.processInfo.environment["FAUS_SWITCH_WRITE_SIMULATION"] == "1" else {
            throw XCTSkip("set FAUS_SWITCH_WRITE_SIMULATION=1 to regenerate Fixtures/fausSwitchSimulation.json")
        }
        let scenarios = try Self.recipes.map { recipe in
            try XCTUnwrap(Self.firstCovering(recipe), "no seed of \(recipe.name) covers the rules; widen the search")
        }
        let fixture = SimulationFixture(courseVersion: FausSwitchCourse.currentVersion, scenarios: scenarios)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        var data = try encoder.encode(fixture)
        data.append(0x0A)
        try data.write(to: Self.fixtureURL)
        #if canImport(CryptoKit)
        let hex = SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
        print("fausSwitchSimulation.json sha256 \(hex)")
        #endif
        for scenario in fixture.scenarios {
            let last = scenario.checkpoints.last!
            let coverage = Self.coverage(of: scenario)
            print(scenario.name, "ticks", last.tick, "flips", scenario.flips.count, "checkpoints", scenario.checkpoints.count,
                  "outcomes", last.runners.map { $0.status == .crashed ? $0.eliminationReason!.rawValue : $0.status.rawValue },
                  "portals", coverage.portals, "unsupported", coverage.unsupportedFlips, "robotSupport", coverage.robotSupport)
        }
    }

    // MARK: Replay

    private static func replay(_ scenario: SimulationScenario) throws {
        let name = scenario.name
        XCTAssertTrue((1...FausSwitchStartGrid.maximumRunners).contains(scenario.runnerCount), name)
        XCTAssertEqual(scenario.flips.map(\.tick), scenario.flips.map(\.tick).sorted(), "\(name) flips are not in tick order")
        XCTAssertEqual(scenario.checkpoints.map(\.tick), scenario.checkpoints.map(\.tick).sorted(), name)

        let course = FausSwitchCourse.race(runnerCount: scenario.runnerCount)
        let scale = FausSwitchStartGrid.runnerScale(runnerCount: scenario.runnerCount)
        var runners = FausSwitchStartGrid.lanes(count: scenario.runnerCount, runnerScale: scale).map(\.spawn)
        var flips = scenario.flips[...]
        var tick: Int64 = 0
        for checkpoint in scenario.checkpoints {
            while tick < checkpoint.tick {
                while let flip = flips.first, flip.tick == tick {
                    FausSwitchPhysics.flip(&runners, index: flip.seat, course: course)
                    flips.removeFirst()
                }
                FausSwitchPhysics.step(&runners, tick: tick, course: course)
                tick += 1
            }
            XCTAssertEqual(checkpoint.runners.count, runners.count, "\(name) tick \(checkpoint.tick)")
            for (seat, want) in checkpoint.runners.enumerated() where seat < runners.count {
                let got = SimulationRunner(runners[seat])
                guard got.isBitwiseEqual(to: want) else {
                    throw Mismatch(description: "\(name) tick \(checkpoint.tick) seat \(seat): got \(got), want \(want)")
                }
            }
        }
        XCTAssertTrue(flips.isEmpty, "\(name) has flips after its last checkpoint")
    }

    private struct Mismatch: Error, CustomStringConvertible { let description: String }

    /// What a scenario exercises, worked out by replaying it.
    private static func coverage(of scenario: SimulationScenario) -> (portals: Int, unsupportedFlips: Int, robotSupport: Int) {
        let course = FausSwitchCourse.race(runnerCount: scenario.runnerCount)
        let scale = FausSwitchStartGrid.runnerScale(runnerCount: scenario.runnerCount)
        var runners = FausSwitchStartGrid.lanes(count: scenario.runnerCount, runnerScale: scale).map(\.spawn)
        var flips = scenario.flips[...]
        var portals = 0, unsupported = 0, support = 0
        let end = scenario.checkpoints.last?.tick ?? 0
        for tick in 0..<end {
            while let flip = flips.first, flip.tick == tick {
                if FausSwitchPhysics.flip(&runners, index: flip.seat, course: course) == .unsupported { unsupported += 1 }
                flips.removeFirst()
            }
            let before = runners
            FausSwitchPhysics.step(&runners, tick: tick, course: course)
            for seat in runners.indices where before[seat].isRunning && runners[seat].isRunning {
                if runners[seat].gravity != before[seat].gravity, runners[seat].x < before[seat].x { portals += 1 }
                if !FausSwitchPhysics.isSupported(runners[seat], course: course),
                   FausSwitchPhysics.isSupported(runners, index: seat, course: course) { support += 1 }
            }
        }
        return (portals, unsupported, support)
    }

    // MARK: Recording

    /// Seeded races. Each seat has a way of looking ahead and a skill: its chance to act
    /// on a decision tick; the rest of the time it taps at random.
    private struct Recipe {
        let name: String
        let runnerCount: Int
        let seed: UInt64
        let seats: [Seat]
    }

    private struct Seat {
        /// `field` looks ahead with every robot; `alone` ignores the others, so it gets
        /// stuck behind them and is left behind more often.
        enum Sight { case field, alone }
        let sight: Sight
        let skill: Double
        static func field(_ skill: Double) -> Seat { Seat(sight: .field, skill: skill) }
        static func alone(_ skill: Double) -> Seat { Seat(sight: .alone, skill: skill) }
    }

    private static let recipes: [Recipe] = [
        Recipe(name: "duel", runnerCount: 2, seed: 0x5EED_0021, seats: [.field(0.99), .alone(0.97)]),
        Recipe(name: "four", runnerCount: 4, seed: 0x5EED_0004,
               seats: [.field(0.99), .field(0.90), .alone(0.95), .field(0.70)]),
        Recipe(name: "crowdedFive", runnerCount: 5, seed: 0x5EED_000C,
               seats: [.field(0.99), .alone(0.95), .field(0.90), .field(0.80), .alone(0.80)]),
        Recipe(name: "crowdedEight", runnerCount: 8, seed: 0x5EED_000C,
               seats: [.field(0.99), .field(0.95), .alone(0.95), .field(0.90),
                       .field(0.85), .alone(0.85), .field(0.70), .field(0.60)]),
    ]

    /// The first of `seedAttempts` seeds (from the recipe's) whose race lasts, throws a
    /// robot through a portal, tries a flip in the air, has a robot on another and ends
    /// with a robot finished and one crashed.
    private static let seedAttempts: UInt64 = 40

    private static func firstCovering(_ recipe: Recipe) -> SimulationScenario? {
        for attempt in 0..<seedAttempts {
            let candidate = Recipe(name: recipe.name, runnerCount: recipe.runnerCount, seed: recipe.seed &+ attempt,
                                   seats: recipe.seats)
            let scenario = record(candidate)
            let coverage = coverage(of: scenario)
            guard let last = scenario.checkpoints.last, last.tick >= 3_000 else { continue }
            let statuses = last.runners.map(\.status)
            if coverage.portals > 0, coverage.unsupportedFlips > 0, recipe.runnerCount == 1 || coverage.robotSupport > 0,
               statuses.contains(.finished), statuses.contains(.crashed) {
                print(recipe.name, "seed", String(candidate.seed, radix: 16))
                return scenario
            }
        }
        return nil
    }

    /// Every seat decides every third tick (staggered by seat). A deciding seat runs what
    /// it sees ahead (nobody else flipping) with and without its flip and flips if
    /// that keeps its robot alive longer, or alive and clearly further along.
    private static func record(_ recipe: Recipe) -> SimulationScenario {
        let course = FausSwitchCourse.race(runnerCount: recipe.runnerCount)
        let scale = FausSwitchStartGrid.runnerScale(runnerCount: recipe.runnerCount)
        var runners = FausSwitchStartGrid.lanes(count: recipe.runnerCount, runnerScale: scale).map(\.spawn)
        var random = SplitMix64(seed: recipe.seed)
        var flips: [SimulationFlip] = []
        var checkpoints = [SimulationCheckpoint(tick: 0, runners: runners.map(SimulationRunner.init))]
        var tick: Int64 = 0
        while runners.contains(where: \.isRunning), tick < FausSwitchMetrics.maximumMatchTicks {
            for seat in runners.indices where runners[seat].isRunning && (tick + Int64(seat)) % 3 == 0 {
                let player = recipe.seats[seat]
                let wantsFlip: Bool
                if random.unit() < player.skill {
                    wantsFlip = player.sight == .field ? prefersFlip(runners, seat: seat, tick: tick, course: course)
                        : prefersFlip([runners[seat]], seat: 0, tick: tick, course: course)
                } else {
                    wantsFlip = random.unit() < 0.04
                }
                if wantsFlip {
                    flips.append(SimulationFlip(tick: tick, seat: seat))
                    FausSwitchPhysics.flip(&runners, index: seat, course: course)
                }
            }
            let before = runners.map(\.status)
            FausSwitchPhysics.step(&runners, tick: tick, course: course)
            tick += 1
            if tick.isMultiple(of: 30) || runners.map(\.status) != before {
                checkpoints.append(SimulationCheckpoint(tick: tick, runners: runners.map(SimulationRunner.init)))
            }
        }
        if checkpoints.last?.tick != tick {
            checkpoints.append(SimulationCheckpoint(tick: tick, runners: runners.map(SimulationRunner.init)))
        }
        return SimulationScenario(name: recipe.name, runnerCount: recipe.runnerCount, flips: flips, checkpoints: checkpoints)
    }

    private static let lookahead: Int64 = 120

    private static func prefersFlip(_ runners: [FausSwitchRunnerState], seat: Int, tick: Int64,
                                    course: FausSwitchCourse) -> Bool {
        guard FausSwitchPhysics.isSupported(runners, index: seat, course: course) else { return false }
        var flipped = runners
        FausSwitchPhysics.flip(&flipped, index: seat, course: course)
        let stay = outlook(runners, seat: seat, tick: tick, course: course)
        let flip = outlook(flipped, seat: seat, tick: tick, course: course)
        if flip.ticks != stay.ticks { return flip.ticks > stay.ticks }
        return flip.x > stay.x + 6
    }

    /// How long the seat's robot lasts in the lookahead (a finish beats any survival) and
    /// where it ends up.
    private static func outlook(_ start: [FausSwitchRunnerState], seat: Int, tick: Int64,
                                course: FausSwitchCourse) -> (ticks: Int64, x: Double) {
        var field = start
        for ahead in 0..<lookahead {
            FausSwitchPhysics.step(&field, tick: tick + ahead, course: course)
            switch field[seat].status {
            case .running: continue
            case .finished: return (2 * lookahead - ahead, field[seat].x)
            case .crashed: return (ahead, field[seat].x)
            }
        }
        return (lookahead, field[seat].x)
    }

    // MARK: File

    private static let fixtureURL = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
        .deletingLastPathComponent().appendingPathComponent("Fixtures/fausSwitchSimulation.json")

    private static func loadFixture() throws -> SimulationFixture {
        try JSONDecoder().decode(SimulationFixture.self, from: Data(contentsOf: fixtureURL))
    }
}

private struct SimulationFixture: Codable {
    let courseVersion: Int
    let scenarios: [SimulationScenario]
}

private struct SimulationScenario: Codable {
    let name: String
    let runnerCount: Int
    let flips: [SimulationFlip]
    let checkpoints: [SimulationCheckpoint]
}

private struct SimulationFlip: Codable {
    let tick: Int64
    let seat: Int
}

private struct SimulationCheckpoint: Codable {
    let tick: Int64
    let runners: [SimulationRunner]
}

/// A robot as the backend's fixture reader has it: the finish tick only for a finished
/// robot, the elimination tick and reason only for a crashed one; optionals are `null`.
private struct SimulationRunner: Codable, CustomStringConvertible {
    let x: Double
    let y: Double
    let velocityY: Double
    let gravity: FausSwitchGravity
    let status: FausSwitchRunnerStatus
    let finishedAtTick: Int64?
    let eliminatedAtTick: Int64?
    let eliminationReason: FausSwitchCrashReason?

    init(_ state: FausSwitchRunnerState) {
        x = state.x
        y = state.y
        velocityY = state.velocityY
        gravity = state.gravity
        status = state.status
        finishedAtTick = state.status == .finished ? state.finishedAtTick : nil
        eliminatedAtTick = state.status == .crashed ? state.crashedAtTick : nil
        eliminationReason = state.status == .crashed ? state.crashReason : nil
    }

    private enum CodingKeys: String, CodingKey {
        case x, y, velocityY, gravity, status, finishedAtTick, eliminatedAtTick, eliminationReason
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        x = try values.decode(Double.self, forKey: .x)
        y = try values.decode(Double.self, forKey: .y)
        velocityY = try values.decode(Double.self, forKey: .velocityY)
        gravity = try values.decode(FausSwitchGravity.self, forKey: .gravity)
        status = try values.decode(FausSwitchRunnerStatus.self, forKey: .status)
        finishedAtTick = try values.decode(Int64?.self, forKey: .finishedAtTick)
        eliminatedAtTick = try values.decode(Int64?.self, forKey: .eliminatedAtTick)
        eliminationReason = try values.decode(FausSwitchCrashReason?.self, forKey: .eliminationReason)
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(x, forKey: .x)
        try values.encode(y, forKey: .y)
        try values.encode(velocityY, forKey: .velocityY)
        try values.encode(gravity, forKey: .gravity)
        try values.encode(status, forKey: .status)
        try values.encode(finishedAtTick, forKey: .finishedAtTick)
        try values.encode(eliminatedAtTick, forKey: .eliminatedAtTick)
        try values.encode(eliminationReason, forKey: .eliminationReason)
    }

    func isBitwiseEqual(to other: SimulationRunner) -> Bool {
        x.bitPattern == other.x.bitPattern && y.bitPattern == other.y.bitPattern
            && velocityY.bitPattern == other.velocityY.bitPattern && gravity == other.gravity && status == other.status
            && finishedAtTick == other.finishedAtTick && eliminatedAtTick == other.eliminatedAtTick
            && eliminationReason == other.eliminationReason
    }

    var description: String {
        "(\(x), \(y), vy \(velocityY), \(gravity), \(status), finished \(finishedAtTick.map(String.init) ?? "nil"), "
            + "eliminated \(eliminatedAtTick.map(String.init) ?? "nil") \(eliminationReason?.rawValue ?? "nil"))"
    }
}

/// Deterministic generator for the recorded races (the file, not this, is the reference).
private struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}
