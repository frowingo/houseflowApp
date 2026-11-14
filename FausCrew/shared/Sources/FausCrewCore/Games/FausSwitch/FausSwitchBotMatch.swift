import Foundation

public struct FausSwitchMatchConfiguration: Equatable, Sendable {
    public static let botRange = 1...3

    public var humanColor: FausSwitchColor
    public var botCount: Int
    public var seed: UInt64

    public init(humanColor: FausSwitchColor, botCount: Int = 3, seed: UInt64 = UInt64.random(in: 1...UInt64.max)) {
        self.humanColor = humanColor
        self.botCount = min(Self.botRange.upperBound, max(Self.botRange.lowerBound, botCount))
        self.seed = seed
    }
}

public enum FausSwitchMatchPhase: String, Codable, Sendable {
    case countdown
    case playing
    case paused
    case ended
}

public struct FausSwitchRunner: Equatable, Identifiable, Sendable {
    public let id: String
    public let role: FausSwitchRunnerRole
    /// Bots carry a localization key; online robots a display name.
    public let nameKey: String?
    public let displayName: String?
    public let color: FausSwitchColor
    public var state: FausSwitchRunnerState

    public init(id: String, role: FausSwitchRunnerRole, nameKey: String?, displayName: String?,
                color: FausSwitchColor, state: FausSwitchRunnerState) {
        self.id = id
        self.role = role
        self.nameKey = nameKey
        self.displayName = displayName
        self.color = color
        self.state = state
    }
}

/// What the demo match did during one `advance`, for haptics and HUD.
public enum FausSwitchMatchEvent: Equatable, Sendable {
    case countdown(Int)
    case started
    case humanBoosted
    case humanSlowed
    /// The human ran into a portal and came out behind it on the other rail.
    case humanTeleported
    case humanCrashed(FausSwitchCrashReason)
    case humanFinished
    case ended
}

/// The demo race: one human against one to three bots on the shared course, with the
/// same physics as an online match. It owns no timers; the host feeds real elapsed
/// time and the match steps at a fixed 120 Hz.
public struct FausSwitchBotMatch: Sendable {
    public static let humanID = "human"
    /// Bot `i` (1-based seat) thinks only on ticks where `tick % 3 == i % 3`; with three
    /// bots at most one decision runs per physics tick.
    public static let decisionSlots: Int64 = 3
    public static let botNameKeys = ["faus_switch_bot_volt", "faus_switch_bot_byte", "faus_switch_bot_pixel"]
    private static let botSkills: [FausSwitchBotSkill] = [.normal, .hard, .easy]

    /// `FausSwitchCourse.race` for this match's robot count (start platforms included).
    public private(set) var course: FausSwitchCourse
    private let baseCourse: FausSwitchCourse
    public private(set) var matchID = UUID()
    public private(set) var phase: FausSwitchMatchPhase = .countdown
    public private(set) var tick: Int64 = 0
    public private(set) var runners: [FausSwitchRunner] = []
    /// Final ranks once the match ended.
    public private(set) var ranks: [String: Int] = [:]
    public private(set) var configuration: FausSwitchMatchConfiguration?
    private var countdownElapsed = 0.0
    private var accumulator = 0.0
    private var pausedFrom: FausSwitchMatchPhase?
    private var brains: [String: FausSwitchBotBrain] = [:]
    /// Each bot's state right after its last decision; the next decision is made on
    /// this state run ahead alone to the decision tick (see `FausSwitchBotPlanner`).
    private var plans: [String: FausSwitchBotPlan] = [:]
    private var random = FausSwitchRandom(seed: 1)
    /// Optional background thinking for the bots; results are the same without it.
    public var planner: FausSwitchBotPlanner?

    /// `course` is the base course; each start adds one platform per robot to it.
    public init(course: FausSwitchCourse = .standard, planner: FausSwitchBotPlanner? = nil) {
        baseCourse = course
        self.course = course
        self.planner = planner
    }

    public var elapsedSeconds: Double { FausSwitchMetrics.seconds(tick) }
    public var human: FausSwitchRunner? { runners.first { $0.role == .human } }

    /// Seconds left before the run, while counting down.
    public var countdown: Int? {
        guard phase == .countdown || (phase == .paused && pausedFrom == .countdown) else { return nil }
        return max(1, FausSwitchMetrics.countdownSeconds - Int(countdownElapsed))
    }

    public mutating func start(configuration: FausSwitchMatchConfiguration) {
        self.configuration = configuration
        matchID = UUID()
        phase = .countdown
        tick = 0
        ranks = [:]
        countdownElapsed = 0
        accumulator = 0
        pausedFrom = nil
        random = FausSwitchRandom(seed: configuration.seed)
        let botColors = FausSwitchColor.free(excluding: [configuration.humanColor], count: configuration.botCount)
        // Seat 0 is the human; every robot starts on its own platform at the same line.
        let lanes = FausSwitchStartGrid.lanes(count: botColors.count + 1,
                                              runnerScale: FausSwitchStartGrid.runnerScale(runnerCount: botColors.count + 1))
        course = baseCourse.adding(lanes.map(\.platform), kind: .platform)
        runners = [FausSwitchRunner(id: Self.humanID, role: .human, nameKey: "faus_switch_you", displayName: nil,
                                    color: configuration.humanColor, state: lanes[0].spawn)]
        brains = [:]
        plans = [:]
        for (index, color) in botColors.enumerated() {
            let id = "bot-\(index + 1)"
            runners.append(FausSwitchRunner(id: id, role: .bot, nameKey: Self.botNameKeys[index], displayName: nil,
                                            color: color, state: lanes[index + 1].spawn))
            brains[id] = FausSwitchBotBrain(skill: Self.botSkills[index])
        }
        for (seat, runner) in runners.enumerated() {
            guard let brain = brains[runner.id] else { continue }
            let plan = Self.plan(runners.map(\.state), index: seat, tick: 0, decisionTick: Int64(seat) % Self.decisionSlots)
            plans[runner.id] = plan
            planner?.request(match: matchID, bot: runner.id, brain: brain, plan: plan, course: course)
        }
    }

    /// Restarts with the same picks and a new seed.
    public mutating func restart() {
        guard var configuration else { return }
        configuration.seed = random.next() | 1
        start(configuration: configuration)
    }

    public mutating func pause() {
        guard phase == .countdown || phase == .playing else { return }
        pausedFrom = phase
        phase = .paused
    }

    public mutating func resume() {
        guard phase == .paused, let previous = pausedFrom else { return }
        phase = previous
        pausedFrom = nil
        accumulator = 0
    }

    public func isHumanSupported() -> Bool {
        guard let index = runners.firstIndex(where: { $0.role == .human }), runners[index].state.isRunning else { return false }
        return FausSwitchPhysics.isSupported(runners.map(\.state), index: index, course: course)
    }

    /// The human's tap: flips only from a surface while running.
    @discardableResult
    public mutating func flipHuman() -> FausSwitchPhysics.FlipOutcome {
        guard phase == .playing, let index = runners.firstIndex(where: { $0.role == .human }) else { return .notRunning }
        var states = runners.map(\.state)
        let outcome = FausSwitchPhysics.flip(&states, index: index, course: course)
        runners[index].state = states[index]
        return outcome
    }

    /// Feeds real time; countdown in whole seconds, then fixed physics steps.
    @discardableResult
    public mutating func advance(by seconds: Double) -> [FausSwitchMatchEvent] {
        guard seconds.isFinite, seconds > 0 else { return [] }
        // A long frame hitch never fast-forwards the race.
        let delta = min(seconds, 0.25)
        var events: [FausSwitchMatchEvent] = []
        switch phase {
        case .countdown:
            let before = countdown
            countdownElapsed += min(seconds, 1.5)
            if countdownElapsed >= Double(FausSwitchMetrics.countdownSeconds) {
                phase = .playing
                accumulator = countdownElapsed - Double(FausSwitchMetrics.countdownSeconds)
                events.append(.started)
                events += stepPhysics()
            } else if let now = countdown, now != before {
                events.append(.countdown(now))
            }
        case .playing:
            accumulator += delta
            events += stepPhysics()
        case .paused, .ended:
            break
        }
        return events
    }

    private mutating func stepPhysics() -> [FausSwitchMatchEvent] {
        var events: [FausSwitchMatchEvent] = []
        while accumulator >= FausSwitchMetrics.tickDuration, phase == .playing {
            accumulator -= FausSwitchMetrics.tickDuration
            events += stepOnce()
        }
        return events
    }

    /// One fixed physics step for every robot (bots decide on their own cadence, then
    /// all robots move together so they can block each other).
    public mutating func stepOnce() -> [FausSwitchMatchEvent] {
        guard phase == .playing else { return [] }
        var events: [FausSwitchMatchEvent] = []
        var states = runners.map(\.state)
        for index in runners.indices where states[index].isRunning {
            let id = runners[index].id
            guard runners[index].role == .bot, let brain = brains[id],
                  Self.isDecisionTick(tick, seat: index, interval: brain.decisionInterval) else { continue }
            let plan = plans[id] ?? Self.plan(states, index: index, tick: tick, decisionTick: tick)
            let prefers = planner?.take(match: matchID, bot: id, tick: tick)
                ?? FausSwitchBotPlanner.decide(brain: brain, plan: plan, course: course)
            if prefers, brain.confirmsFlip(random: &random) {
                FausSwitchPhysics.flip(&states, index: index, course: course)
            }
            let next = Self.plan(states, index: index, tick: tick, decisionTick: tick + brain.decisionInterval)
            plans[id] = next
            planner?.request(match: matchID, bot: id, brain: brain, plan: next, course: course)
        }
        let humanIndex = runners.firstIndex { $0.role == .human }
        let before = humanIndex.map { states[$0] }
        FausSwitchPhysics.step(&states, tick: tick, course: course)
        for index in runners.indices { runners[index].state = states[index] }
        if let humanIndex, let before, before.isRunning {
            let after = states[humanIndex]
            if after.usedBoosts.count > before.usedBoosts.count { events.append(.humanBoosted) }
            if after.usedSlows.count > before.usedSlows.count { events.append(.humanSlowed) }
            if after.x < before.x - 20 { events.append(.humanTeleported) }
            if after.status == .crashed, let reason = after.crashReason { events.append(.humanCrashed(reason)) }
            if after.status == .finished { events.append(.humanFinished) }
        }
        tick += 1
        if runners.allSatisfy({ !$0.state.isRunning }) || tick >= FausSwitchMetrics.maximumMatchTicks {
            phase = .ended
            ranks = FausSwitchRanking.ranks(runners.map { ($0.id, $0.state) })
            events.append(.ended)
        }
        return events
    }

    private static func plan(_ states: [FausSwitchRunnerState], index: Int, tick: Int64,
                             decisionTick: Int64) -> FausSwitchBotPlan {
        let others = states.indices.filter { $0 != index && states[$0].isRunning }
            .map { FausSwitchBotObstacle(states[$0], tick: tick) }
        return FausSwitchBotPlan(state: states[index], others: others, fromTick: tick, decisionTick: decisionTick)
    }

    static func isDecisionTick(_ tick: Int64, seat: Int, interval: Int64) -> Bool {
        let slot = Int64(seat) % decisionSlots
        guard tick % decisionSlots == slot else { return false }
        return ((tick - slot) / decisionSlots) % (interval / decisionSlots) == 0
    }

    /// The drawable state of this demo match.
    public func frame() -> FausSwitchRenderFrame {
        FausSwitchRenderFrame(
            matchID: matchID.uuidString, tick: tick, phase: phase, countdown: countdown,
            cameraFocus: course.cameraFocus(atTick: tick), cameraTrail: course.cameraTrail(atTick: tick),
            runners: runners.map {
                FausSwitchRenderRunner(id: $0.id, nameKey: $0.nameKey, displayName: $0.displayName, color: $0.color,
                                       state: $0.state, isLocal: $0.role == .human, isConnected: true,
                                       isBoosted: $0.state.isBoosted(atTick: tick), rank: ranks[$0.id])
            })
    }
}
