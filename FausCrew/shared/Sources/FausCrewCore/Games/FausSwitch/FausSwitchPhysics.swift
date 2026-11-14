import Foundation

/// One robot's physical state. Robots are solid to each other, so a race steps all of
/// them together (`FausSwitchPhysics.step(_:tick:course:)` over the seat-ordered
/// array); the server and every client produce the same numbers for the same ticks
/// and flips.
public struct FausSwitchRunnerState: Equatable, Sendable {
    /// Body center.
    public var x: Double
    public var y: Double
    public var velocityY: Double
    public var gravity: FausSwitchGravity
    /// The run is boosted while the current tick is below this.
    public var boostedUntilTick: Int64
    /// Boost pads this robot already used (each pad works once per robot).
    public var usedBoosts: Set<Int>
    /// The run is slowed while the current tick is below this.
    public var slowedUntilTick: Int64
    /// Slow pads this robot already hit (each pad works once per robot).
    public var usedSlows: Set<Int>
    public var status: FausSwitchRunnerStatus
    public var finishedAtTick: Int64?
    public var crashedAtTick: Int64?
    public var crashReason: FausSwitchCrashReason?
    /// Body size against `FausSwitchMetrics.runnerWidth` and `runnerHeight`: 1, or
    /// `FausSwitchStartGrid.crowdedRobotScale` in a race of more than four robots. It sizes
    /// the body and the support probe only; portal exits and gap sensors keep full size.
    public var scale: Double

    public init(x: Double, y: Double, velocityY: Double = 0, gravity: FausSwitchGravity,
                boostedUntilTick: Int64 = 0, usedBoosts: Set<Int> = [], slowedUntilTick: Int64 = 0,
                usedSlows: Set<Int> = [], status: FausSwitchRunnerStatus = .running,
                finishedAtTick: Int64? = nil, crashedAtTick: Int64? = nil, crashReason: FausSwitchCrashReason? = nil,
                scale: Double = 1) {
        self.x = x
        self.y = y
        self.velocityY = velocityY
        self.gravity = gravity
        self.boostedUntilTick = boostedUntilTick
        self.usedBoosts = usedBoosts
        self.slowedUntilTick = slowedUntilTick
        self.usedSlows = usedSlows
        self.status = status
        self.finishedAtTick = finishedAtTick
        self.crashedAtTick = crashedAtTick
        self.crashReason = crashReason
        self.scale = scale
    }

    /// Standing on the floor (`.down`) or hanging on the ceiling (`.up`) at the start
    /// line. Races start from `FausSwitchStartGrid` instead; this is for solo checks.
    public static func spawn(on gravity: FausSwitchGravity, x: Double = FausSwitchMetrics.spawnX) -> Self {
        let half = FausSwitchMetrics.runnerHeight / 2
        let y = gravity == .down ? FausSwitchMetrics.floorSurface + half : FausSwitchMetrics.ceilingSurface - half
        return .init(x: x, y: y, gravity: gravity)
    }

    public var body: FausSwitchRect {
        FausSwitchRect(centerX: x, centerY: y, width: FausSwitchMetrics.runnerWidth * scale,
                       height: FausSwitchMetrics.runnerHeight * scale)
    }

    public func isBoosted(atTick tick: Int64) -> Bool { tick < boostedUntilTick }
    public func isSlowed(atTick tick: Int64) -> Bool { tick < slowedUntilTick }

    public var isRunning: Bool { status == .running }
}

/// The run's rules at a fixed 120 Hz step. Integration and contact follow the solo
/// SpriteKit build: constant forward speed, gravity toward one rail, a flip only
/// from a surface, safe solid faces, portals that send a robot back on the other rail,
/// slow pads, and lethal gaps and camera edge.
///
/// Robots never pass through each other. Each running robot is a solid box to the
/// others: one can stand on another's head, two with opposite gravity press sole to
/// sole, and a faster robot behind another is held back. A robot touching another
/// with its feet is supported and may flip. A race steps robots one at a time in seat
/// order; each moves, then is pushed out of the robots (where they are at that moment)
/// and the course. Finished and crashed robots no longer collide.
public enum FausSwitchPhysics {
    public enum FlipOutcome: Equatable, Sendable {
        case flipped
        /// Mid-air: the tap is ignored.
        case unsupported
        case notRunning
    }

    /// The thin probe under the feet (in the gravity direction) that must touch a solid.
    public static func supportProbe(of runner: FausSwitchRunnerState) -> FausSwitchRect {
        let width = FausSwitchMetrics.runnerWidth * runner.scale
        let inset = min(7, width * 0.2)
        let edge = runner.y + runner.gravity.sign * FausSwitchMetrics.runnerHeight * runner.scale / 2
        return FausSwitchRect(minX: runner.x - width / 2 + inset, minY: edge - 0.5,
                              maxX: runner.x + width / 2 - inset, maxY: edge + 0.5)
    }

    /// Supported by the course alone (a robot without others around).
    public static func isSupported(_ runner: FausSwitchRunnerState, course: FausSwitchCourse) -> Bool {
        course.overlapsSolid(supportProbe(of: runner))
    }

    /// Supported by the course or by another running robot of the race.
    public static func isSupported(_ runners: [FausSwitchRunnerState], index: Int, course: FausSwitchCourse) -> Bool {
        isSupported(runners[index], course: course, robots: bodies(of: runners), skipping: index)
    }

    /// The bodies of running robots, by seat; `nil` for robots that left the race.
    public static func bodies(of runners: [FausSwitchRunnerState]) -> [FausSwitchRect?] {
        runners.map { $0.isRunning ? $0.body : nil }
    }

    static func isSupported(_ runner: FausSwitchRunnerState, course: FausSwitchCourse,
                            robots: [FausSwitchRect?], skipping skip: Int) -> Bool {
        let probe = supportProbe(of: runner)
        for (index, body) in robots.enumerated() where index != skip {
            if let body, body.intersects(probe) { return true }
        }
        return course.overlapsSolid(probe)
    }

    /// Reverses gravity and launches toward the new surface; only a supported robot
    /// flips. Course-only support (solo checks and bot lookahead).
    @discardableResult
    public static func flip(_ runner: inout FausSwitchRunnerState, course: FausSwitchCourse) -> FlipOutcome {
        flip(&runner, supported: isSupported(runner, course: course))
    }

    /// A race robot's flip: standing on another robot counts as support.
    @discardableResult
    public static func flip(_ runners: inout [FausSwitchRunnerState], index: Int, course: FausSwitchCourse) -> FlipOutcome {
        let supported = runners[index].isRunning && isSupported(runners, index: index, course: course)
        return flip(&runners[index], supported: supported)
    }

    static func flip(_ runner: inout FausSwitchRunnerState, supported: Bool) -> FlipOutcome {
        guard runner.isRunning else { return .notRunning }
        guard supported else { return .unsupported }
        runner.gravity = runner.gravity.opposite
        let launch = max(FausSwitchMetrics.switchVelocity, abs(runner.velocityY) * FausSwitchMetrics.flipCarry)
        runner.velocityY = runner.gravity.sign * launch
        return .flipped
    }

    /// Advances one robot alone (no other robots) from `tick` to `tick + 1`.
    public static func step(_ runner: inout FausSwitchRunnerState, tick: Int64, course: FausSwitchCourse) {
        step(&runner, tick: tick, course: course, robots: [], skipping: -1)
    }

    /// Advances every running robot of a race from `tick` to `tick + 1`, in seat order.
    public static func step(_ runners: inout [FausSwitchRunnerState], tick: Int64, course: FausSwitchCourse) {
        var robots = bodies(of: runners)
        for index in runners.indices where runners[index].isRunning {
            step(&runners[index], tick: tick, course: course, robots: robots, skipping: index)
            robots[index] = runners[index].isRunning ? runners[index].body : nil
        }
    }

    static func step(_ runner: inout FausSwitchRunnerState, tick: Int64, course: FausSwitchCourse,
                     robots: [FausSwitchRect?], skipping skip: Int) {
        guard runner.isRunning else { return }
        let dt = FausSwitchMetrics.tickDuration
        let next = tick + 1
        let speed = FausSwitchMetrics.runSpeed + (runner.isBoosted(atTick: tick) ? FausSwitchMetrics.boostExtraSpeed : 0)
            - (runner.isSlowed(atTick: tick) ? FausSwitchMetrics.slowPenalty : 0)

        // In a turn the robot also keeps its share of the camera margin (0 on straights).
        let before = runner.body
        let carry = FausSwitchCamera.turnCarry(front: before.maxX, tick: tick, course: course)
        runner.velocityY += runner.gravity.sign * FausSwitchMetrics.gravity * dt
        runner.x += speed * dt + carry
        runner.y += runner.velocityY * dt
        resolveContacts(&runner, before: before, course: course, robots: robots, skipping: skip)

        // A portal sends the robot back to its exit on the opposite rail; never behind
        // the camera's trail, so a portal alone does not eliminate anyone.
        if let portal = course.portals.first(where: { $0.opening.intersects(runner.body) }) {
            runner.x = portal.landingX(trail: course.cameraTrail(atTick: next))
            runner.y = portal.exitY
            runner.gravity = portal.exitGravity
            runner.velocityY = 0
            let arrival = runner.body
            resolveContacts(&runner, before: arrival, course: course, robots: robots, skipping: skip)
        }

        let body = runner.body
        let supported = isSupported(runner, course: course, robots: robots, skipping: skip)

        for gap in course.gaps where gap.rail == runner.gravity && !supported && gap.sensor.intersects(body) {
            let exit = max(abs(runner.velocityY), FausSwitchMetrics.gapExitSpeed)
            runner.velocityY = runner.gravity.sign * exit
        }

        for pad in course.boosts where !runner.usedBoosts.contains(pad.id) && pad.rect.intersects(body) {
            runner.usedBoosts.insert(pad.id)
            runner.boostedUntilTick = max(runner.boostedUntilTick, next + FausSwitchMetrics.boostTicks)
        }

        for pad in course.slows where !runner.usedSlows.contains(pad.id) && pad.rect.intersects(body) {
            runner.usedSlows.insert(pad.id)
            runner.slowedUntilTick = max(runner.slowedUntilTick, next + FausSwitchMetrics.slowTicks)
        }

        if body.maxX >= course.finishX - 8 {
            runner.status = .finished
            runner.finishedAtTick = next
            runner.velocityY = 0
            return
        }

        if runner.y < -FausSwitchMetrics.boundaryMargin
            || runner.y > FausSwitchMetrics.worldHeight + FausSwitchMetrics.boundaryMargin {
            crash(&runner, reason: .boundary, at: next)
            return
        }

        if body.maxX <= course.cameraTrail(atTick: next) {
            crash(&runner, reason: .leftBehind, at: next)
        }
    }

    public static func crash(_ runner: inout FausSwitchRunnerState, reason: FausSwitchCrashReason, at tick: Int64) {
        guard runner.isRunning else { return }
        runner.status = .crashed
        runner.crashReason = reason
        runner.crashedAtTick = tick
        runner.velocityY = 0
    }

    /// Pushes the body out of each other robot, then out of each solid, along the
    /// shallower overlap (up to four passes; the course goes last so a robot never
    /// ends inside a rail). Against another robot the side it came from wins: if the
    /// body `before` the move was clear of it vertically (and not sideways), the push is
    /// vertical, and the other way round. A push against the vertical motion stops it
    /// (no bounce); sideways pushes only block progress.
    static func resolveContacts(_ runner: inout FausSwitchRunnerState, before: FausSwitchRect,
                                course: FausSwitchCourse, robots: [FausSwitchRect?], skipping skip: Int) {
        let epsilon = 1e-9
        for _ in 0..<4 {
            var moved = false
            var body = runner.body
            func push(out rect: FausSwitchRect, sweep: Bool) {
                guard rect.intersects(body) else { return }
                let overlapX = min(body.maxX - rect.minX, rect.maxX - body.minX)
                let overlapY = min(body.maxY - rect.minY, rect.maxY - body.minY)
                guard overlapX > epsilon, overlapY > epsilon else { return }
                var vertical = overlapY <= overlapX
                if sweep {
                    let clearX = before.maxX <= rect.minX + epsilon || before.minX >= rect.maxX - epsilon
                    let clearY = before.maxY <= rect.minY + epsilon || before.minY >= rect.maxY - epsilon
                    if clearY != clearX { vertical = clearY }
                }
                if vertical {
                    if body.midY >= rect.midY {
                        runner.y += rect.maxY - body.minY
                        if runner.velocityY < 0 { runner.velocityY = 0 }
                    } else {
                        runner.y -= body.maxY - rect.minY
                        if runner.velocityY > 0 { runner.velocityY = 0 }
                    }
                } else if body.midX <= rect.midX {
                    runner.x -= body.maxX - rect.minX
                } else {
                    runner.x += rect.maxX - body.minX
                }
                body = runner.body
                moved = true
            }
            for (index, other) in robots.enumerated() where index != skip {
                if let other { push(out: other, sweep: true) }
            }
            course.solids(near: body) { push(out: $0.rect, sweep: false) }
            if !moved { return }
        }
    }
}

/// Finishers first by finish tick, then robots still running (time limit) by distance,
/// then crashes, the later the better. Equal results share a rank (1, 1, 3).
public enum FausSwitchRanking {
    public static func ranks(_ runners: [(id: String, state: FausSwitchRunnerState)]) -> [String: Int] {
        func key(_ state: FausSwitchRunnerState) -> (Int, Double) {
            switch state.status {
            case .finished: return (0, Double(state.finishedAtTick ?? .max))
            case .running: return (1, -state.x)
            case .crashed: return (2, -Double(state.crashedAtTick ?? 0))
            }
        }
        let sorted = runners.sorted { key($0.state) < key($1.state) }
        var ranks: [String: Int] = [:]
        for (index, entry) in sorted.enumerated() {
            if index > 0, key(sorted[index - 1].state) == key(entry.state) {
                ranks[entry.id] = ranks[sorted[index - 1].id]
            } else {
                ranks[entry.id] = index + 1
            }
        }
        return ranks
    }
}
