import Foundation

/// Presentation budgets, not wire rules or gameplay authority.
struct HouseRocketsFlightConfiguration {
    var interpolationDelay = 0.10
    var maximumExtrapolation = 0.15
    var maximumPrediction = 0.25
    var snapshotCapacity = 8
    var inputCapacity = 32
    var inputRateHz = 20.0
    var retransmitInterval = 0.25
    var maximumRetransmits = 3
}

struct HouseRocketsOnlineElimination: Equatable, Identifiable, Sendable {
    let sessionID: String
    let epoch: Int64
    let tick: Int64
    let playerID: String
    let displayName: String
    let receivedUptime: TimeInterval
    var id: String { "\(sessionID):\(epoch):\(tick):\(playerID)" }
}

struct HouseRocketsOnlinePresentation: Equatable, Sendable {
    let frame: HouseRocketsRenderFrame
    let canSteer: Bool
    let isSyncing: Bool
    let eliminations: [HouseRocketsOnlineElimination]
}

struct HouseRocketsPredictedInput {
    let messageID: String
    let sequence: Int64
    let heading: Double
    let simulationTime: TimeInterval
    let sentUptime: TimeInterval
}

struct HouseRocketsBufferedFrame {
    let snapshot: HouseRocketsSnapshotDTO
    let frame: HouseRocketsRenderFrame
    let receivedUptime: TimeInterval
}

/// Bounded display physics. Never moves the camera, eliminates players or creates results.
enum HouseRocketsFlightMath {
    static func normalize(_ heading: Double) -> Double { atan2(sin(heading), cos(heading)) }

    static func angle(_ frame: HouseRocketsRenderFrame, at elapsed: TimeInterval) -> Double {
        min(.pi / 2, max(0, frame.courseAngle + HouseRocketsCourse.angle(at: elapsed)
                         - HouseRocketsCourse.angle(at: frame.elapsedTime)))
    }

    static func interpolate(_ a: HouseRocketsRenderFrame, _ b: HouseRocketsRenderFrame,
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

    static func advance(_ initial: HouseRocketsRenderPlayer, from start: TimeInterval,
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
