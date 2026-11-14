import Foundation

/// SplitMix64: small, seedable and identical on every platform.
public struct FausSwitchRandom: Sendable {
    private var state: UInt64

    public init(seed: UInt64) { state = seed }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    /// Uniform in 0..<1.
    public mutating func unit() -> Double { Double(next() >> 11) / Double(1 << 53) }
}

/// Bots look ahead with the same physics the robots run: from a surface they try the
/// run without a flip and, only if that run is blocked or ends, a flip now or a little
/// later. Lower skills look less far, decide less often and sometimes hesitate.
///
/// Other robots are seen as `FausSwitchBotObstacle`s that keep running straight on, so
/// a bot knows it can stand on a head or be blocked by a robot ahead.
///
/// The search is kept linear so it fits inside one display frame: each plan holds at
/// most one flip beyond the one being decided (bots re-plan every few ticks anyway),
/// and a step budget caps any decision.
public struct FausSwitchBotBrain: Sendable {
    public let skill: FausSwitchBotSkill

    public init(skill: FausSwitchBotSkill) { self.skill = skill }

    var horizonTicks: Int64 {
        switch skill {
        case .easy: 96
        case .normal: 132
        case .hard: 168
        }
    }

    /// Ticks between decisions; the match only asks on these ticks. All are multiples of
    /// `FausSwitchBotMatch.decisionSlots`, so two bots never think on the same tick.
    public var decisionInterval: Int64 {
        switch skill {
        case .easy: 18
        case .normal: 12
        case .hard: 9
        }
    }

    /// Physics steps one decision may simulate (about 1.5 ms in a debug build).
    static let stepBudget = 2_400

    var hesitation: Double {
        switch skill {
        case .easy: 0.12
        case .normal: 0.04
        case .hard: 0
        }
    }

    /// Whether to flip now. Only called for a running robot.
    public func wantsFlip(_ runner: FausSwitchRunnerState, tick: Int64, course: FausSwitchCourse,
                          others: [FausSwitchBotObstacle] = [], random: inout FausSwitchRandom) -> Bool {
        guard prefersFlip(runner, tick: tick, course: course, others: others) else { return false }
        return random.unit() >= hesitation
    }

    /// The search alone, before the skill's hesitation roll: pure, so it may run ahead
    /// of time on another thread (`FausSwitchBotPlanner`).
    public func prefersFlip(_ runner: FausSwitchRunnerState, tick: Int64, course: FausSwitchCourse,
                            others: [FausSwitchBotObstacle] = []) -> Bool {
        guard runner.isRunning, Self.isSupported(runner, tick: tick, course: course, others: others) else { return false }
        let ideal = runner.x + FausSwitchMetrics.runSpeed * FausSwitchMetrics.seconds(horizonTicks) - 1
        var budget = Self.stepBudget
        let stay = evaluate(runner, tick: tick, remaining: horizonTicks, flips: 1, flipNow: false, ideal: ideal,
                            course: course, others: others, budget: &budget)
        if stay >= ideal { return false }
        budget = Self.stepBudget
        let flip = evaluate(runner, tick: tick, remaining: horizonTicks, flips: 1, flipNow: true, ideal: ideal,
                            course: course, others: others, budget: &budget)
        return flip > stay + 1
    }

    /// The hesitation roll that follows a preferred flip.
    public func confirmsFlip(random: inout FausSwitchRandom) -> Bool {
        random.unit() >= hesitation
    }

    /// The best score reachable from here: the robot's x at the horizon, a large bonus
    /// for finishing, and a large penalty (later is better) for crashing.
    private func evaluate(_ start: FausSwitchRunnerState, tick: Int64, remaining: Int64, flips: Int,
                          flipNow: Bool, ideal: Double, course: FausSwitchCourse, others: [FausSwitchBotObstacle],
                          budget: inout Int) -> Double {
        var runner = start
        var tick = tick
        if flipNow, FausSwitchPhysics.flip(&runner, supported: Self.isSupported(runner, tick: tick, course: course,
                                                                                 others: others)) != .flipped {
            return -.infinity
        }
        let span = min(decisionInterval, remaining)
        budget -= Int(span)
        for _ in 0..<span {
            Self.step(&runner, tick: tick, course: course, others: others)
            tick += 1
            switch runner.status {
            case .running: continue
            case .finished: return 1e6 - Double(tick)
            case .crashed: return -1e6 + Double(tick)
            }
        }
        let left = remaining - span
        guard left > 0 else {
            // Keep a margin from the camera's edge: a stuck robot is about to be lost.
            let margin = runner.body.minX - course.cameraTrail(atTick: tick)
            return runner.x - (margin < 60 ? 400 : 0)
        }
        var best = evaluate(runner, tick: tick, remaining: left, flips: flips, flipNow: false, ideal: ideal,
                            course: course, others: others, budget: &budget)
        if best >= ideal || flips == 0 || budget <= 0 
            || !Self.isSupported(runner, tick: tick, course: course, others: others) {
            return best
        }
        best = max(best, evaluate(runner, tick: tick, remaining: left, flips: flips - 1, flipNow: true,
                                  ideal: ideal, course: course, others: others, budget: &budget))
        return best
    }

    // MARK: Other robots

    static func isSupported(_ runner: FausSwitchRunnerState, tick: Int64, course: FausSwitchCourse,
                            others: [FausSwitchBotObstacle]) -> Bool {
        guard !others.isEmpty else { return FausSwitchPhysics.isSupported(runner, course: course) }
        return FausSwitchPhysics.isSupported(runner, course: course, robots: others.map { $0.body(at: tick) }, skipping: -1)
    }

    /// One lookahead step; the bot itself is not in `others`.
    static func step(_ runner: inout FausSwitchRunnerState, tick: Int64, course: FausSwitchCourse,
                     others: [FausSwitchBotObstacle]) {
        guard !others.isEmpty else { return FausSwitchPhysics.step(&runner, tick: tick, course: course) }
        FausSwitchPhysics.step(&runner, tick: tick, course: course, robots: others.map { $0.body(at: tick) }, skipping: -1)
    }
}

/// Another robot in a bot's lookahead: it keeps its height and runs straight on at its
/// current pace (boosted until its boost ends). Only a guess, which is enough to stand
/// on a head or to see a robot ahead; the real race decides what happens.
public struct FausSwitchBotObstacle: Equatable, Sendable {
    let body: FausSwitchRect
    let tick: Int64
    let boostedUntilTick: Int64

    /// `state` as it is before the step of `tick`.
    public init(_ state: FausSwitchRunnerState, tick: Int64) {
        body = state.body
        self.tick = tick
        boostedUntilTick = state.boostedUntilTick
    }

    func body(at target: Int64) -> FausSwitchRect? {
        let dt = FausSwitchMetrics.tickDuration
        let ticks = Double(target - tick)
        let boosted = Double(max(0, min(target, boostedUntilTick) - tick))
        let shift = FausSwitchMetrics.runSpeed * dt * ticks + FausSwitchMetrics.boostExtraSpeed * dt * boosted
        return FausSwitchRect(minX: body.minX + shift, minY: body.minY, maxX: body.maxX + shift, maxY: body.maxY)
    }
}
