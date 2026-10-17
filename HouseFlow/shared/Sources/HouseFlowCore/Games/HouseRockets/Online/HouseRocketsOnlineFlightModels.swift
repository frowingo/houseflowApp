import Foundation


/// Presentation budgets, not wire rules or gameplay authority.
public struct HouseRocketsFlightConfiguration: Sendable {
    public var interpolationDelay = 0.10
    public var maximumExtrapolation = 0.15
    public var maximumPrediction = 0.25
    public var snapshotCapacity = 8
    public var inputCapacity = 32
    public var inputRateHz = 20.0
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

    public init(snapshot: HouseRocketsSnapshotDTO, frame: HouseRocketsRenderFrame, receivedUptime: TimeInterval) {
        self.snapshot = snapshot
        self.frame = frame
        self.receivedUptime = receivedUptime
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
        let previous = Dictionary(uniqueKeysWithValues: a.players.map { ($0.id, $0) })
        frame.players = b.players.map { player in
            // Alive/phase are always the newest authoritative values, including simultaneous exits.
            guard player.isAlive, let old = previous[player.id], old.isAlive else { return player }
            var rendered = player
            rendered.worldX = old.worldX + (player.worldX - old.worldX) * t
            rendered.worldY = old.worldY + (player.worldY - old.worldY) * t
            rendered.courseHeading = normalize(old.courseHeading + normalize(player.courseHeading - old.courseHeading) * t)
            return rendered
        }
        return frame
    }

    public static func advance(_ initial: HouseRocketsRenderPlayer, from start: TimeInterval,
                        to end: TimeInterval, gates: [HouseRocketsRenderGate],
                        inputs: [HouseRocketsPredictedInput] = [], intent: (heading: Double, time: TimeInterval)? = nil)
        -> HouseRocketsRenderPlayer {
        guard initial.isAlive, end > start else { return initial }
        var player = initial
        var time = start
        let solids = gates.flatMap(\.solidPolygons)
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
            for _ in 0..<3 {
                point.y = min(HouseRocketsSimulation.trackHeight - HouseRocketsSimulation.rocketRadius,
                              max(HouseRocketsSimulation.rocketRadius, point.y))
                for polygon in solids {
                    point = HouseRocketsContact.resolve(point, radius: HouseRocketsSimulation.rocketRadius, polygon: polygon)
                }
            }
            player.worldX = point.x
            player.worldY = point.y
            time += step
        }
        // Field contact history is private server state. Predict confirmed effects only;
        // a snapshot confirms new contacts instead of reapplying a previously touched field.
        return player
    }
}

