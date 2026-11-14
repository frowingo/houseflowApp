import Foundation

/// A bot's state right after a decision, the other running robots at that moment and
/// the tick of its next decision.
struct FausSwitchBotPlan: Sendable {
    let state: FausSwitchRunnerState
    let others: [FausSwitchBotObstacle]
    let fromTick: Int64
    let decisionTick: Int64
}

/// Thinks for the demo bots ahead of time, off the main thread.
///
/// Right after a decision the match records the bot's state and the other robots; the
/// next decision is made on that state run ahead to the decision tick, with the others
/// imagined running straight on (`FausSwitchBotObstacle`). That
/// input is fixed the moment it is recorded, so the planner can simulate and search in
/// the background; when the tick arrives the match takes the answer, or computes the
/// same answer itself (`decide`) if it is not ready. Results are therefore identical
/// with or without the planner, and a heavy search never holds up a frame. The bot
/// still flips only if its real state at that tick is supported.
public final class FausSwitchBotPlanner: @unchecked Sendable {
    struct Key: Hashable {
        let match: UUID
        let bot: String
        let tick: Int64
    }

    private let queue = DispatchQueue(label: "com.fauscrew.fausSwitch.botPlanner", qos: .userInitiated)
    private let lock = NSLock()
    private var answers: [Key: Bool] = [:]
    private var currentMatch: UUID?

    public init() {}

    /// The decision for `plan`: its state run ahead to the decision tick, then searched.
    static func decide(brain: FausSwitchBotBrain, plan: FausSwitchBotPlan, course: FausSwitchCourse) -> Bool {
        var runner = plan.state
        var tick = plan.fromTick
        while tick < plan.decisionTick, runner.isRunning {
            FausSwitchBotBrain.step(&runner, tick: tick, course: course, others: plan.others)
            tick += 1
        }
        guard runner.isRunning else { return false }
        return brain.prefersFlip(runner, tick: plan.decisionTick, course: course, others: plan.others)
    }

    /// Plans the decision at `plan.decisionTick` in the background.
    func request(match: UUID, bot: String, brain: FausSwitchBotBrain, plan: FausSwitchBotPlan, course: FausSwitchCourse) {
        lock.lock()
        if currentMatch != match {
            currentMatch = match
            answers.removeAll()
        }
        lock.unlock()
        queue.async { [weak self] in
            guard let self, self.isCurrent(match) else { return }
            let answer = Self.decide(brain: brain, plan: plan, course: course)
            self.lock.lock()
            if self.currentMatch == match { self.answers[Key(match: match, bot: bot, tick: plan.decisionTick)] = answer }
            self.lock.unlock()
        }
    }

    /// The planned answer, if ready; it is removed once taken.
    func take(match: UUID, bot: String, tick: Int64) -> Bool? {
        lock.lock()
        defer { lock.unlock() }
        return answers.removeValue(forKey: Key(match: match, bot: bot, tick: tick))
    }

    /// Waits for queued plans; tests use it to make the background path deterministic.
    public func waitUntilIdle() {
        queue.sync {}
    }

    private func isCurrent(_ match: UUID) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return currentMatch == match
    }
}
