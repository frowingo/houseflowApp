import Foundation
import CoreGraphics

/// Shared geometry for collision, bot routing and rendering; no approximate hitboxes.
enum HouseRocketsCourse {
    static let firstGateX = 900.0
    static let spacing = 640.0
    static let transitionInterval = 25.0
    static let transitionDuration = 3.0

    static func turnProgress(at time: TimeInterval) -> Double {
        guard time >= transitionInterval else { return 0 }
        let cycleTime = time.truncatingRemainder(dividingBy: transitionInterval * 2)
        let turningVertical = cycleTime >= transitionInterval
        let elapsed = turningVertical ? cycleTime - transitionInterval : cycleTime
        let t = min(1, elapsed / transitionDuration)
        let progress = t * t * (3 - 2 * t)
        return turningVertical ? progress : 1 - progress
    }

    /// Show the destination direction for three seconds before and during each turn.
    static func transitionTargetIsVertical(at time: TimeInterval) -> Bool? {
        let phase = time.truncatingRemainder(dividingBy: transitionInterval)
        let verticalSegment = time.truncatingRemainder(dividingBy: transitionInterval * 2)
            >= transitionInterval
        if time >= transitionInterval, phase < transitionDuration { return verticalSegment }
        if phase >= transitionInterval - transitionDuration { return !verticalSegment }
        return nil
    }

    static func isTransitioning(at time: TimeInterval) -> Bool {
        time >= transitionInterval && time.truncatingRemainder(dividingBy: transitionInterval) < transitionDuration
    }

    static func angle(at time: TimeInterval) -> Double {
        turnProgress(at: time) * .pi / 2
    }

    static func gate(index: Int) -> HouseRocketsGateState {
        let x = firstGateX + Double(index) * spacing
        let profile: [(Double, Double, Double)]
        if index == 0 {
            profile = [(-46, 180, 190), (46, 180, 190)]
        } else {
            switch (index - 1) % 6 {
            case 0: // Long asymmetric funnel, like the reference's closing wedges.
                profile = [(-160, 180, 290), (160, 120, 88)]
            case 1: // Narrow entrance opens into a broad exit.
                profile = [(-145, 245, 90), (145, 180, 290)]
            case 2: // Climbing channel.
                profile = [(-170, 100, 108), (170, 255, 108)]
            case 3: // Hourglass with a narrow waist.
                profile = [(-150, 180, 280), (0, 195, 82), (150, 180, 280)]
            case 4: // Descending channel, a different slope and thickness.
                profile = [(-140, 255, 120), (140, 105, 100)]
            default: // Short, offset precision opening between longer wedges.
                profile = [(-38, 120, 88), (38, 120, 88)]
            }
        }
        return HouseRocketsGateState(id: UUID(), worldX: x, sections: profile.map {
            HouseRocketsPassageSection(offsetX: $0.0, lowerY: $0.1 - $0.2 / 2, upperY: $0.1 + $0.2 / 2)
        })
    }

    static func speedField(index: Int) -> HouseRocketsSpeedField {
        HouseRocketsSpeedField(
            id: UUID(), worldX: firstGateX + Double(index) * spacing + spacing / 2,
            effect: index.isMultiple(of: 2) ? .boost : .slow,
            phase: Double(index) * 1.7, period: (index.isMultiple(of: 2) ? 3.6 : 4.4) / 1.2
        )
    }
}

/// Rotate course coordinates (X = forward, Y = across) into the landscape screen.
/// Keep the rear boundary and leader anchor unchanged during the turn: resizing the
/// visible distance ahead must never eliminate a ship or move the camera by itself.
struct HouseRocketsProjection {
    static let cameraZoom = 1.16
    let angle: Double
    let isTurning: Bool
    let scale: Double
    let visibleLength: Double
    let origin: HouseRocketsPoint

    init(elapsedTime: TimeInterval, cameraX: Double, width: Double, height: Double) {
        let progress = HouseRocketsCourse.turnProgress(at: elapsedTime)
        isTurning = HouseRocketsCourse.isTransitioning(at: elapsedTime)
        angle = HouseRocketsCourse.angle(at: elapsedTime)
        let baseLength = (HouseRocketsSimulation.viewportWidth - 600 * progress) / Self.cameraZoom
        let c = cos(angle), s = sin(angle)
        let across = HouseRocketsSimulation.trackHeight
        // Keep all world objects at the same scale, with room for the information
        // panels outside the course on compact landscape screens.
        let informationClearance = min((width - 364) / across, (height - 116) / across)
        scale = min(width / (baseLength * c + across * s),
                    height / (baseLength * s + across * c),
                    informationClearance)
        // Extend only the visible course length to the screen's leading and rear
        // edges. Ease the extension away during each turn so its corners stay in view.
        let horizontalEdge = max(0, 1 - angle / (.pi / 6))
        let verticalEdge = max(0, 1 - (.pi / 2 - angle) / (.pi / 6))
        let horizontalExtra = max(0, width / scale - baseLength)
        let verticalExtra = max(0, height / scale - baseLength)
        let maximumFitX = c > 0.0001 ? (width / scale - across * s) / c : .infinity
        let maximumFitY = s > 0.0001 ? (height / scale - across * c) / s : .infinity
        visibleLength = min(baseLength
            + horizontalExtra * horizontalEdge * horizontalEdge
            + verticalExtra * verticalEdge * verticalEdge,
            maximumFitX, maximumFitY)
        let centerX = cameraX + visibleLength / 2
        origin = .init(x: width / 2 - (centerX * c - across / 2 * s) * scale,
                       y: height / 2 - (centerX * s + across / 2 * c) * scale)
    }

    func point(x: Double, y: Double) -> HouseRocketsPoint {
        .init(x: origin.x + (x * cos(angle) - y * sin(angle)) * scale,
              y: origin.y + (x * sin(angle) + y * cos(angle)) * scale)
    }

    /// Hide information while turning; stable vertical panels sit at the top of each side.
    func informationRegions(width: Double, height: Double) -> [CGRect] {
        guard !isTurning else { return [] }
        let inset = 8.0
        if angle > .pi / 4 {
            let sideWidth = (width - HouseRocketsSimulation.trackHeight * scale) / 2
            let panelWidth = max(0, min(240, sideWidth - 2 * inset - 6))
            return [CGRect(x: inset, y: inset, width: panelWidth, height: 120),
                    CGRect(x: width - inset - panelWidth, y: inset, width: panelWidth, height: 120)]
        }
        let panelWidth = min(440, width - 2 * inset)
        return [CGRect(x: (width - panelWidth) / 2, y: inset, width: panelWidth, height: 44),
                CGRect(x: (width - panelWidth) / 2, y: height - inset - 44, width: panelWidth, height: 44)]
    }

}

extension HouseRocketsGateState {
    /// Each segment forms two convex trapezoids, including triangular/sloping faces.
    var solidPolygons: [[HouseRocketsPoint]] {
        zip(sections, sections.dropFirst()).flatMap { left, right -> [[HouseRocketsPoint]] in
            let a = worldX + left.offsetX
            let b = worldX + right.offsetX
            return [
                [.init(x: a, y: 0), .init(x: b, y: 0),
                 .init(x: b, y: right.lowerY), .init(x: a, y: left.lowerY)],
                [.init(x: a, y: left.upperY), .init(x: b, y: right.upperY),
                 .init(x: b, y: HouseRocketsSimulation.trackHeight),
                 .init(x: a, y: HouseRocketsSimulation.trackHeight)],
            ]
        }
    }

    func passage(at x: Double) -> (center: Double, height: Double) {
        guard let first = sections.first, let last = sections.last else { return (180, 360) }
        let localX = max(first.offsetX, min(last.offsetX, x - worldX))
        for (left, right) in zip(sections, sections.dropFirst()) where localX <= right.offsetX {
            let t = (localX - left.offsetX) / (right.offsetX - left.offsetX)
            let lower = left.lowerY + (right.lowerY - left.lowerY) * t
            let upper = left.upperY + (right.upperY - left.upperY) * t
            return ((lower + upper) / 2, upper - lower)
        }
        return (last.centerY, last.upperY - last.lowerY)
    }
}

/// Circle vs convex polygon projection. Corrects penetration along the real face normal,
/// leaving tangential motion available for sliding, including on sloped surfaces.
enum HouseRocketsContact {
    static func resolve(_ point: HouseRocketsPoint, radius: Double,
                        polygon: [HouseRocketsPoint]) -> HouseRocketsPoint {
        var inside = true
        var closest = point
        var minimumDistanceSquared = Double.infinity
        var outward = HouseRocketsPoint(x: 0, y: 0)
        for index in polygon.indices {
            let a = polygon[index]
            let b = polygon[(index + 1) % polygon.count]
            let dx = b.x - a.x
            let dy = b.y - a.y
            let lengthSquared = dx * dx + dy * dy
            guard lengthSquared > 0 else { continue }
            let cross = dx * (point.y - a.y) - dy * (point.x - a.x)
            if cross < 0 { inside = false }
            let t = max(0, min(1, ((point.x - a.x) * dx + (point.y - a.y) * dy) / lengthSquared))
            let candidate = HouseRocketsPoint(x: a.x + t * dx, y: a.y + t * dy)
            let distanceSquared = pow(point.x - candidate.x, 2) + pow(point.y - candidate.y, 2)
            if distanceSquared < minimumDistanceSquared {
                minimumDistanceSquared = distanceSquared
                closest = candidate
                let length = sqrt(lengthSquared)
                outward = .init(x: dy / length, y: -dx / length)
            }
        }
        guard inside || minimumDistanceSquared < radius * radius else { return point }
        let distance = sqrt(minimumDistanceSquared)
        if !inside, distance > 0.000_001 {
            outward = .init(x: (point.x - closest.x) / distance, y: (point.y - closest.y) / distance)
        }
        return .init(x: closest.x + outward.x * radius, y: closest.y + outward.y * radius)
    }
}
