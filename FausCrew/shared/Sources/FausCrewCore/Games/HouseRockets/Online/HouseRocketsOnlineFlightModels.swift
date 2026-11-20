import Foundation


/// Presentation budgets, not wire rules or gameplay authority.
public struct HouseRocketsFlightConfiguration: Sendable {
    /// Remote rockets are drawn this far behind the newest snapshot, so there is nearly always
    /// a snapshot ahead to interpolate toward. It follows the snapshot rate and the measured
    /// arrival jitter, between these two bounds.
    public var minimumInterpolationDelay = 0.06
    public var maximumInterpolationDelay = 0.12
    /// How many recent snapshot arrivals the jitter estimate looks at.
    public var jitterWindow = 64
    /// How long past the newest snapshot remote rockets and the camera keep moving on screen.
    public var maximumExtrapolation = 0.35
    /// How long past the newest snapshot the local rocket is predicted: the display budget
    /// plus the interpolation delay, so it never freezes before the others do.
    public var maximumPrediction = 0.45
    /// A snapshot older than this stops steering (touches are counted as swallowed).
    public var steerFreshness = 0.4
    /// A playing match without snapshots for this long drops control and asks for a full sync.
    public var staleSnapshotResync = 1.0
    /// A display clock this far behind the newest snapshot's pace jumps forward to it
    /// instead of speeding up (a resync). One ahead of it only ever slows down.
    public var clockSnapLimit = 0.25
    /// A local or remote correction larger than this (world units) snaps instead of easing.
    public var correctionLimit = 180.0
    public var correctionTime = 0.15
    /// An easing never moves a rocket against its own motion faster than this share of its
    /// speed, so a correction pulling backwards slows down instead of rubber-banding.
    public var easingBackwardShare = 0.75
    public var snapshotCapacity = 8
    public var inputCapacity = 32
    /// The client's own steer rate; the server's settings are the real cap.
    public var inputRateHz = 30.0
    public var retransmitInterval = 0.25
    public var maximumRetransmits = 3

    public init() {}
}

public struct HouseRocketsOnlineElimination: Equatable, Identifiable, Sendable {
    public let sessionID: String
    public let epoch: Int64
    public let tick: Int64
    public let playerID: String
    public let displayName: String
    public let receivedUptime: TimeInterval
    public var id: String { "\(sessionID):\(epoch):\(tick):\(playerID)" }

    public init(sessionID: String, epoch: Int64, tick: Int64, playerID: String, displayName: String, receivedUptime: TimeInterval) {
        self.sessionID = sessionID
        self.epoch = epoch
        self.tick = tick
        self.playerID = playerID
        self.displayName = displayName
        self.receivedUptime = receivedUptime
    }
}

public struct HouseRocketsOnlinePresentation: Equatable, Sendable {
    public let frame: HouseRocketsRenderFrame
    public let canSteer: Bool
    public let isSyncing: Bool
    public let eliminations: [HouseRocketsOnlineElimination]

    public init(frame: HouseRocketsRenderFrame, canSteer: Bool, isSyncing: Bool, eliminations: [HouseRocketsOnlineElimination]) {
        self.frame = frame
        self.canSteer = canSteer
        self.isSyncing = isSyncing
        self.eliminations = eliminations
    }
}

public struct HouseRocketsPredictedInput {
    public let messageID: String
    public let sequence: Int64
    public let heading: Double
    public let simulationTime: TimeInterval
    public let sentUptime: TimeInterval

    public init(messageID: String, sequence: Int64, heading: Double, simulationTime: TimeInterval, sentUptime: TimeInterval) {
        self.messageID = messageID
        self.sequence = sequence
        self.heading = heading
        self.simulationTime = simulationTime
        self.sentUptime = sentUptime
    }
}

public struct HouseRocketsBufferedFrame {
    public let snapshot: HouseRocketsSnapshotDTO
    public let frame: HouseRocketsRenderFrame
    public let receivedUptime: TimeInterval
    /// Built once per snapshot: prediction and extrapolation run every display frame.
    public let solids: HouseRocketsSolidSet

    public init(snapshot: HouseRocketsSnapshotDTO, frame: HouseRocketsRenderFrame, receivedUptime: TimeInterval) {
        self.snapshot = snapshot
        self.frame = frame
        self.receivedUptime = receivedUptime
        solids = HouseRocketsSolidSet(gates: frame.gates)
    }
}

/// A clock that never runs backwards. Snapshots arrive early and late, so instead of
/// following each one it keeps running and only changes speed (10 % at most) toward the
/// pace the newest snapshot implies. It jumps forward when far behind, never back.
struct HouseRocketsPacedClock {
    private var uptime: TimeInterval
    private var time: TimeInterval
    private var speed = 1.0

    init(at uptime: TimeInterval, time: TimeInterval) {
        self.uptime = uptime
        self.time = time
    }

    func time(at now: TimeInterval) -> TimeInterval { time + max(0, now - uptime) * speed }

    /// Returns how far ahead of `target` the clock was (negative = behind) and whether it jumped.
    @discardableResult
    mutating func pace(toward target: TimeInterval, at now: TimeInterval, snapLimit: TimeInterval)
        -> (ahead: TimeInterval, snapped: Bool) {
        let shown = time(at: now)
        let ahead = shown - target
        let snapped = -ahead > snapLimit
        let speed = 1 - min(0.1, max(-0.1, ahead * 0.5))
        self = snapped ? .init(at: now, time: target) : .init(at: now, time: shown, speed: speed)
        return (ahead, snapped)
    }

    private init(at uptime: TimeInterval, time: TimeInterval, speed: Double) {
        self.uptime = uptime
        self.time = time
        self.speed = speed
    }
}

/// The solid faces of a frame's gates with their bounding boxes. A face farther from the
/// rocket than its radius cannot move it, so `resolve` skips it with four comparisons and
/// gives the same result as running every face.
public struct HouseRocketsSolidSet: Sendable {
    private struct Solid: Sendable {
        let points: [HouseRocketsPoint]
        let minX: Double, maxX: Double, minY: Double, maxY: Double

        init(_ points: [HouseRocketsPoint]) {
            self.points = points
            var low = HouseRocketsPoint(x: .infinity, y: .infinity)
            var high = HouseRocketsPoint(x: -.infinity, y: -.infinity)
            for point in points {
                low = .init(x: min(low.x, point.x), y: min(low.y, point.y))
                high = .init(x: max(high.x, point.x), y: max(high.y, point.y))
            }
            (minX, minY, maxX, maxY) = points.isEmpty ? (0, 0, 0, 0) : (low.x, low.y, high.x, high.y)
        }

        func mayTouch(_ point: HouseRocketsPoint, reach: Double) -> Bool {
            point.x >= minX - reach && point.x <= maxX + reach && point.y >= minY - reach && point.y <= maxY + reach
        }
    }

    private let solids: [Solid]

    public init(gates: [HouseRocketsRenderGate]) {
        solids = gates.flatMap(\.solidPolygons).map(Solid.init)
    }

    /// The track bounds and the gate faces, three passes like the server, stopping early
    /// once a pass changes nothing (the next one would repeat it).
    public func resolve(_ start: HouseRocketsPoint) -> HouseRocketsPoint {
        let radius = HouseRocketsSimulation.rocketRadius
        // A hair beyond the radius, so a face at exactly one radius still runs the exact test.
        let reach = radius + 0.001
        var point = start
        for _ in 0..<3 {
            let before = point
            point.y = min(HouseRocketsSimulation.trackHeight - radius, max(radius, point.y))
            for solid in solids where solid.mayTouch(point, reach: reach) {
                point = HouseRocketsContact.resolve(point, radius: radius, polygon: solid.points)
            }
            if point == before { break }
        }
        return point
    }
}

/// Bounded display physics. Never moves the camera, eliminates players or creates results.
public enum HouseRocketsFlightMath {
    public static func normalize(_ heading: Double) -> Double { atan2(sin(heading), cos(heading)) }

    public static func angle(_ frame: HouseRocketsRenderFrame, at elapsed: TimeInterval) -> Double {
        min(.pi / 2, max(0, frame.courseAngle + HouseRocketsCourse.angle(at: elapsed)
                         - HouseRocketsCourse.angle(at: frame.elapsedTime)))
    }

    public static func interpolate(_ a: HouseRocketsRenderFrame, _ b: HouseRocketsRenderFrame,
                            at time: TimeInterval) -> HouseRocketsRenderFrame {
        guard b.elapsedTime > a.elapsedTime else { return b }
        let t = max(0, min(1, (time - a.elapsedTime) / (b.elapsedTime - a.elapsedTime)))
        var frame = b
        frame.elapsedTime = a.elapsedTime + (b.elapsedTime - a.elapsedTime) * t
        frame.cameraX = a.cameraX + (b.cameraX - a.cameraX) * t
        frame.courseAngle = a.courseAngle + (b.courseAngle - a.courseAngle) * t
        frame.players = b.players.map { player in
            // Alive/phase are always the newest authoritative values, including simultaneous exits.
            guard player.isAlive, let old = a.players.first(where: { $0.id == player.id }), old.isAlive else { return player }
            var rendered = player
            rendered.worldX = old.worldX + (player.worldX - old.worldX) * t
            rendered.worldY = old.worldY + (player.worldY - old.worldY) * t
            rendered.courseHeading = normalize(old.courseHeading + normalize(player.courseHeading - old.courseHeading) * t)
            return rendered
        }
        return frame
    }

    public static func advance(_ initial: HouseRocketsRenderPlayer, from start: TimeInterval,
                        to end: TimeInterval, solids: HouseRocketsSolidSet,
                        inputs: [HouseRocketsPredictedInput] = [], intent: (heading: Double, time: TimeInterval)? = nil)
        -> HouseRocketsRenderPlayer {
        guard initial.isAlive, end > start else { return initial }
        var player = initial
        var time = start
        // Replay only unacknowledged intentions. Their times are in the same simulation clock.
        var index = 0
        while time < end - 0.000_001 {
            while index < inputs.count, inputs[index].simulationTime <= time + 0.000_001 {
                player.courseHeading = inputs[index].heading
                index += 1
            }
            if let intent, intent.time <= time + 0.000_001 { player.courseHeading = intent.heading }
            var step = min(1.0 / 120.0, end - time)
            if index < inputs.count, inputs[index].simulationTime > time {
                step = min(step, inputs[index].simulationTime - time)
            }
            if let intent, intent.time > time { step = min(step, intent.time - time) }
            player.effectRemaining = max(0, player.effectRemaining - step)
            if player.effectRemaining == 0 { player.speedEffect = nil }
            let speed = HouseRocketsSimulation.speed * (player.speedEffect?.multiplier ?? 1)
            var point = HouseRocketsPoint(x: player.worldX + cos(player.courseHeading) * speed * step,
                                         y: player.worldY + sin(player.courseHeading) * speed * step)
            point = solids.resolve(point)
            player.worldX = point.x
            player.worldY = point.y
            time += step
        }
        // Field contact history is private server state. Predict confirmed effects only;
        // a snapshot confirms new contacts instead of reapplying a previously touched field.
        return player
    }
}

