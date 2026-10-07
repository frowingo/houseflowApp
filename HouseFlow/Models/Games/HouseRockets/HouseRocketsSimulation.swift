import Foundation

/// Device-independent world units. The renderer never decides movement or eliminations.
struct HouseRocketsSimulation {
    static let viewportWidth = 1_200.0
    static let trackHeight = 360.0
    static let speed = 300.0
    static let rocketRadius = 10.0
    static let leaderAnchorX = 420.0
    static let spawnX = 250.0

    struct Body {
        let id: UUID
        var x: Double
        var y: Double
        var heading: Double = 0
        var isAlive = true
        var speedEffect: HouseRocketsSpeedEffect?
        var effectRemaining = 0.0
        var touchedFields: Set<UUID> = []
        var currentSpeed: Double { HouseRocketsSimulation.speed * (speedEffect?.multiplier ?? 1) }
    }

    private(set) var bodies: [Body]
    private(set) var gates: [HouseRocketsGateState] = []
    private(set) var speedFields: [HouseRocketsSpeedField] = []
    private(set) var cameraX = 0.0
    private(set) var elapsedTime = 0.0
    private var nextGateIndex = 0
    var courseAngle: Double { HouseRocketsCourse.angle(at: elapsedTime) }

    func screenHeading(for body: Body) -> Double {
        let heading = body.heading + courseAngle
        return atan2(sin(heading), cos(heading))
    }

    init(playerIDs: [UUID]) {
        bodies = playerIDs.enumerated().map { index, id in
            Body(id: id, x: Self.spawnX,
                 y: 105 + Double(index) * 150 / Double(max(1, playerIDs.count - 1)))
        }
        extendCourse()
    }

    mutating func steer(playerID: UUID, heading: Double) {
        guard heading.isFinite,
              let index = bodies.firstIndex(where: { $0.id == playerID && $0.isAlive }) else { return }
        let localHeading = heading - courseAngle
        bodies[index].heading = atan2(sin(localHeading), cos(localHeading))
    }

    /// Fixed substeps prevent tunneling and keep contacts independent of rendering FPS.
    mutating func advance(by delta: TimeInterval) {
        guard delta.isFinite, delta > 0 else { return }
        var remaining = min(delta, 0.25)
        while remaining > 0.000_001, bodies.filter(\.isAlive).count > 1 {
            let step = min(remaining, 1.0 / 120.0)
            extendCourse()
            let solids = gates.flatMap(\.solidPolygons)
            for index in bodies.indices where bodies[index].isAlive {
                bodies[index].effectRemaining = max(0, bodies[index].effectRemaining - step)
                if bodies[index].effectRemaining == 0 { bodies[index].speedEffect = nil }
                move(index: index, delta: step, solids: solids)
                applySpeedFields(index: index, at: elapsedTime + step)
            }
            // Follow actual post-collision progress. The camera never retreats.
            let leaderX = bodies.filter(\.isAlive).map(\.x).max() ?? Self.spawnX
            cameraX = max(cameraX, leaderX - Self.leaderAnchorX)
            for index in bodies.indices where bodies[index].isAlive {
                if Self.isBehindCamera(centerX: bodies[index].x, cameraX: cameraX) {
                    bodies[index].isAlive = false
                }
            }
            elapsedTime += step
            remaining -= step
        }
        gates.removeAll { $0.maxX < cameraX - 100 }
        speedFields.removeAll { $0.worldX + HouseRocketsSpeedField.radius < cameraX - 100 }
        let activeFields = Set(speedFields.map(\.id))
        for index in bodies.indices { bodies[index].touchedFields.formIntersection(activeFields) }
    }

    static func isBehindCamera(centerX: Double, cameraX: Double) -> Bool {
        centerX + rocketRadius < cameraX
    }

    /// Simple route following: approach the next opening, then clear its far face.
    func botHeading(playerID: UUID, laneOffset: Double) -> Double? {
        guard let body = bodies.first(where: { $0.id == playerID && $0.isAlive }) else { return nil }
        guard let gate = gates.first(where: { $0.maxX + 30 > body.x }) else { return courseAngle }
        // Aim ahead along the actual sloping opening, not just its entrance center.
        let targetX = min(gate.maxX + 30, max(gate.minX, body.x + 85))
        let opening = gate.passage(at: targetX)
        let safeOffset = min(20, opening.height / 2 - Self.rocketRadius - 14)
        let targetY = opening.center + max(-safeOffset, min(safeOffset, laneOffset))
        return atan2(targetY - body.y, max(30, targetX - body.x)) + courseAngle
    }

    private mutating func extendCourse() {
        while HouseRocketsCourse.firstGateX + Double(nextGateIndex) * HouseRocketsCourse.spacing
                < cameraX + Self.viewportWidth + 620 {
            gates.append(HouseRocketsCourse.gate(index: nextGateIndex))
            // Skip every fifth field: 20% fewer tokens, balanced across both effects.
            if nextGateIndex % 5 != 4 {
                speedFields.append(HouseRocketsCourse.speedField(index: nextGateIndex))
            }
            nextGateIndex += 1
        }
    }

    private mutating func applySpeedFields(index: Int, at time: TimeInterval) {
        for field in speedFields where !bodies[index].touchedFields.contains(field.id) {
            let distance = hypot(bodies[index].x - field.worldX, bodies[index].y - field.worldY(at: time))
            guard distance <= Self.rocketRadius + HouseRocketsSpeedField.radius else { continue }
            bodies[index].touchedFields.insert(field.id)
            // Latest field replaces the previous effect; multipliers never stack.
            bodies[index].speedEffect = field.effect
            bodies[index].effectRemaining = field.effect.duration
        }
    }

    private mutating func move(index: Int, delta: Double, solids: [[HouseRocketsPoint]]) {
        let body = bodies[index]
        var point = HouseRocketsPoint(
            x: body.x + cos(body.heading) * body.currentSpeed * delta,
            y: body.y + sin(body.heading) * body.currentSpeed * delta
        )
        // Multiple contacts can meet at a seam or rail; settle all faces in the same substep.
        for _ in 0..<3 {
            point.y = min(Self.trackHeight - Self.rocketRadius, max(Self.rocketRadius, point.y))
            for polygon in solids {
                point = HouseRocketsContact.resolve(point, radius: Self.rocketRadius, polygon: polygon)
            }
        }
        bodies[index].x = point.x
        bodies[index].y = point.y
    }
}
