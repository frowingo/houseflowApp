import Foundation

/// Where a robot of the track sits in the drawn world, and which way it faces.
public struct FausSwitchPose: Equatable, Sendable {
    public var x: Double
    public var y: Double
    /// Radians, counterclockwise from "running to the right".
    public var angle: Double

    public init(x: Double, y: Double, angle: Double) {
        self.x = x
        self.y = y
        self.angle = angle
    }
}

/// How the course bends in the world. Physics never sees this: every rule runs in
/// track coordinates, where `x` is the distance along the course and `y` is the height
/// across the band (floor rail at the bottom, ceiling rail at the top). The track maps
/// those coordinates onto straight sections joined by quarter turns, so a course can
/// run to the right, turn and climb upward. In an upward section the floor rail is the
/// right wall and the ceiling rail the left wall, so robots switch left and right.
public struct FausSwitchTrack: Equatable, Sendable {
    /// A quarter turn of the whole band around a fixed center.
    public struct Turn: Equatable, Sendable {
        /// Track `x` where the bend starts.
        public let startX: Double
        /// Radius of the band's center line.
        public let radius: Double
        /// Left turns are counterclockwise (right → up), right turns clockwise.
        public let isLeft: Bool

        public init(startX: Double, radius: Double, isLeft: Bool) {
            self.startX = startX
            self.radius = radius
            self.isLeft = isLeft
        }

        /// Measured on the center line; the inner rail is shorter, the outer one longer.
        public var length: Double { radius * .pi / 2 }
        public var endX: Double { startX + length }
    }

    /// A straight stretch: track x `startX` maps to `origin` on the center line.
    struct Straight: Equatable, Sendable {
        let startX: Double
        let originX: Double
        let originY: Double
        /// Unit run direction; always axis aligned.
        let directionX: Double
        let directionY: Double

        var angle: Double { atan2(directionY, directionX) }
    }

    public static let centerY = FausSwitchMetrics.worldHeight / 2
    /// The whole course runs to the right (the first course).
    public static let straight = FausSwitchTrack(turns: [])

    public let turns: [Turn]
    let straights: [Straight]

    public init(turns: [Turn]) {
        self.turns = turns.sorted { $0.startX < $1.startX }
        var straights = [Straight(startX: 0, originX: 0, originY: Self.centerY, directionX: 1, directionY: 0)]
        for turn in self.turns {
            let previous = straights[straights.count - 1]
            let exit = Self.turnPose(turn, in: previous, x: turn.endX, y: Self.centerY)
            // Exact quarter rotations keep the straight sections exactly axis aligned;
            // `+ 0` turns a negative zero into zero so running left faces +π, not −π.
            let direction = turn.isLeft ? (-previous.directionY, previous.directionX)
                : (previous.directionY, -previous.directionX)
            straights.append(Straight(startX: turn.endX, originX: exit.x, originY: exit.y,
                                      directionX: direction.0 + 0, directionY: direction.1 + 0))
        }
        self.straights = straights
    }

    /// The world position and facing of track point (`x`, `y`).
    public func pose(x: Double, y: Double) -> FausSwitchPose {
        for (index, turn) in turns.enumerated() where x < turn.endX {
            let straight = straights[index]
            if x <= turn.startX { return Self.straightPose(straight, x: x, y: y) }
            return Self.turnPose(turn, in: straight, x: x, y: y)
        }
        return Self.straightPose(straights[straights.count - 1], x: x, y: y)
    }

    /// 0 on the straight before turn `index`, 1 after it, eased in between.
    public func turnBlend(_ index: Int, atX x: Double) -> Double {
        let turn = turns[index]
        guard x > turn.startX else { return 0 }
        guard x < turn.endX else { return 1 }
        return Self.smoothstep((x - turn.startX) / turn.length)
    }

    /// Whether the run direction at the end of straight `index` is vertical.
    func isVertical(straight index: Int) -> Bool { straights[index].directionX == 0 }

    /// `3x² − 2x³`: plain arithmetic, so every platform gets the same numbers.
    public static func smoothstep(_ value: Double) -> Double {
        let clamped = min(1, max(0, value))
        return clamped * clamped * (3 - 2 * clamped)
    }

    // MARK: Mapping

    static func straightPose(_ straight: Straight, x: Double, y: Double) -> FausSwitchPose {
        let along = x - straight.startX
        let across = y - centerY
        // The ceiling side is the run direction turned counterclockwise.
        return FausSwitchPose(x: straight.originX + along * straight.directionX - across * straight.directionY,
                              y: straight.originY + along * straight.directionY + across * straight.directionX,
                              angle: straight.angle)
    }

    static func turnPose(_ turn: Turn, in straight: Straight, x: Double, y: Double) -> FausSwitchPose {
        let start = straightPose(straight, x: turn.startX, y: centerY)
        let normalX = -straight.directionY
        let normalY = straight.directionX
        let across = y - centerY
        let phi = (x - turn.startX) / turn.radius
        let sign: Double = turn.isLeft ? 1 : -1
        // The center sits on the inner side: the ceiling side for a left turn.
        let centerX = start.x + sign * normalX * turn.radius
        let centerY = start.y + sign * normalY * turn.radius
        let radius = turn.radius - sign * across
        // From the center toward the band at the start of the bend, then rotated by phi.
        let startAngle = atan2(-sign * normalY, -sign * normalX)
        let angle = startAngle + sign * phi
        return FausSwitchPose(x: centerX + radius * cos(angle), y: centerY + radius * sin(angle),
                              angle: straight.angle + sign * phi)
    }

    /// Drawing helper: the bend's center, start angle (from the center to the band) and
    /// sweep direction, for turn `index`.
    public func turnArc(_ index: Int) -> (centerX: Double, centerY: Double, startAngle: Double, isLeft: Bool) {
        let turn = turns[index]
        let straight = straights[index]
        let start = Self.straightPose(straight, x: turn.startX, y: Self.centerY)
        let sign: Double = turn.isLeft ? 1 : -1
        let normalX = -straight.directionY
        let normalY = straight.directionX
        return (start.x + sign * normalX * turn.radius, start.y + sign * normalY * turn.radius,
                atan2(-sign * normalY, -sign * normalX), turn.isLeft)
    }

    /// Track-x ranges of the straight sections (the first starts far before 0, the last
    /// ends far after `length`), for drawing each one as a rotated copy.
    public func straightRanges(length: Double) -> [(startX: Double, endX: Double, pose: FausSwitchPose)] {
        straights.enumerated().map { index, straight in
            let start = index == 0 ? -2_000 : straight.startX
            let end = index < turns.count ? turns[index].startX : length + 2_000
            return (start, end, FausSwitchPose(x: straight.originX, y: straight.originY, angle: straight.angle))
        }
    }

    /// Track x where straight `index` begins (its pose origin).
    public func straightStartX(_ index: Int) -> Double { straights[index].startX }
}

/// The scrolling view and the "left behind" line. The camera follows a focus point
/// that moves along the course at the run speed from the start line. The trail (the
/// "left behind" line) is `behind` units behind the focus: 380 on horizontal stretches,
/// 140 on vertical ones, where the landscape screen is short along the run. Each turn
/// eases `behind` and `ahead` between the two kinds of stretch.
///
/// Fairness through the turns:
/// - **Same share of the margin.** In a turn, a robot keeps the share of the margin it
///   was using (`FausSwitchCamera.turnCarry`), so a turn alone never eliminates anyone:
///   a robot 300 of 380 behind leaves the first turn 110.5 of 140 behind, and the
///   second turn gives the same distance back.
/// - **Alive means on screen.** The view always fits the whole band from the trail to
///   some way past the focus (`view`). On straight stretches that is exactly the trail
///   at the trailing screen edge; in a bend the view zooms out a little more.
public enum FausSwitchCamera {
    public static let horizontalBehind = FausSwitchMetrics.spawnX
    public static let verticalBehind = 140.0
    public static let verticalZoom = 0.75

    /// World units visible ahead of the focus on a stretch of each kind.
    public static let horizontalAhead = FausSwitchMetrics.viewportWidth - horizontalBehind
    public static let verticalAhead = FausSwitchMetrics.worldHeight / verticalZoom - verticalBehind

    /// Track x of the focus at `tick`; it stops once the finish is in view.
    public static func focus(atTick tick: Int64, course: FausSwitchCourse) -> Double {
        let last = course.track.straights.count - 1
        let ahead = course.track.isVertical(straight: last) ? verticalAhead : horizontalAhead
        return min(FausSwitchMetrics.spawnX + FausSwitchMetrics.runSpeed * FausSwitchMetrics.seconds(tick),
                   course.length - ahead)
    }

    /// How far behind the focus the trail is, at track x `x`.
    public static func behind(atX x: Double, track: FausSwitchTrack) -> Double {
        blended(atX: x, track: track, horizontal: horizontalBehind, vertical: verticalBehind)
    }

    /// How far ahead of the focus the view must reach, at track x `x`.
    public static func ahead(atX x: Double, track: FausSwitchTrack) -> Double {
        blended(atX: x, track: track, horizontal: horizontalAhead, vertical: verticalAhead)
    }

    /// Near a bend the view need not reach the full `ahead` (bends and their edges have
    /// no obstacles), which keeps the zoom-out small: it reaches only to the bend start
    /// until the focus is `bendAhead` from it, then `bendAhead` past the focus through the
    /// bend, and widens back over `bendRelease` units after it.
    public static let bendAhead = 200.0
    public static let bendRelease = 300.0

    /// How far ahead of the focus the view reaches (drawing only).
    static func viewAhead(atX x: Double, track: FausSwitchTrack) -> Double {
        var value = ahead(atX: x, track: track)
        for (index, turn) in track.turns.enumerated() {
            let cap: Double
            if x < turn.endX {
                cap = max(turn.startX - x, bendAhead)
            } else {
                let full = track.isVertical(straight: index + 1) ? verticalAhead : horizontalAhead
                cap = bendAhead + (full - bendAhead) * FausSwitchTrack.smoothstep((x - turn.endX) / bendRelease)
            }
            value = min(value, cap)
        }
        return value
    }

    static func zoom(atX x: Double, track: FausSwitchTrack) -> Double {
        blended(atX: x, track: track, horizontal: 1, vertical: verticalZoom)
    }

    static func blended(atX x: Double, track: FausSwitchTrack, horizontal: Double, vertical: Double) -> Double {
        var value = track.isVertical(straight: 0) ? vertical : horizontal
        for index in track.turns.indices {
            let next = track.isVertical(straight: index + 1) ? vertical : horizontal
            value += (next - value) * track.turnBlend(index, atX: x)
        }
        return value
    }

    /// Extra track x for a running robot whose body front is at `front`, for the step from
    /// `tick` to `tick + 1`: it keeps the robot's share of the margin behind the focus (or
    /// of the view ahead of it) while a turn changes them. Exactly 0 on straight stretches.
    public static func turnCarry(front: Double, tick: Int64, course: FausSwitchCourse) -> Double {
        let focus = Self.focus(atTick: tick, course: course)
        let next = Self.focus(atTick: tick + 1, course: course)
        let gap = focus - front
        if gap > 0 {
            let now = behind(atX: focus, track: course.track)
            return gap * (1 - behind(atX: next, track: course.track) / now)
        }
        let now = ahead(atX: focus, track: course.track)
        return gap * (1 - ahead(atX: next, track: course.track) / now)
    }

    /// World bounding box of the whole band (including the area outside the rails)
    /// between track x `from` and `to`. A turn is an exact quarter between axis
    /// directions, so only the ends and the turn edges can be extreme.
    static func bounds(from: Double, to: Double, track: FausSwitchTrack)
        -> (minX: Double, minY: Double, maxX: Double, maxY: Double) {
        var xs = [from, to]
        for turn in track.turns {
            if turn.startX > from, turn.startX < to { xs.append(turn.startX) }
            if turn.endX > from, turn.endX < to { xs.append(turn.endX) }
        }
        var box = (minX: Double.infinity, minY: Double.infinity, maxX: -Double.infinity, maxY: -Double.infinity)
        for x in xs {
            for y in [0, FausSwitchMetrics.worldHeight] {
                let pose = track.pose(x: x, y: y)
                box = (min(box.minX, pose.x), min(box.minY, pose.y), max(box.maxX, pose.x), max(box.maxY, pose.y))
            }
        }
        return box
    }

    /// The camera for a frame whose focus is track x `focus`: the band from the trail to
    /// `viewAhead` past the focus, as large as it fits but no larger than the stretch's zoom.
    /// Spare screen goes ahead of the run (so the trail stays at the trailing edge), and
    /// is split evenly across it.
    public static func view(focus: Double, track: FausSwitchTrack, viewport: FausSwitchViewport) -> FausSwitchCameraView {
        let box = bounds(from: focus - behind(atX: focus, track: track), to: focus + viewAhead(atX: focus, track: track),
                         track: track)
        let width = box.maxX - box.minX
        let height = box.maxY - box.minY
        let scale = min(viewport.scale * zoom(atX: focus, track: track),
                        viewport.screenWidth / width, viewport.screenHeight / height)
        let direction = track.pose(x: focus, y: FausSwitchTrack.centerY).angle
        let spareX = viewport.screenWidth - width * scale
        let spareY = viewport.screenHeight - height * scale
        let left = spareX * (1 - cos(direction)) / 2
        let bottom = spareY * (1 - sin(direction)) / 2
        return FausSwitchCameraView(scale: scale, focusX: box.minX, focusY: box.minY, anchorX: left, anchorY: bottom)
    }
}

/// One frame's camera: world point (`focusX`, `focusY`) is drawn at screen point
/// (`anchorX`, `anchorY`) with `scale` points per world unit. Screen y grows upward.
public struct FausSwitchCameraView: Equatable, Sendable {
    public let scale: Double
    public let focusX: Double
    public let focusY: Double
    public let anchorX: Double
    public let anchorY: Double

    public func screenPoint(worldX: Double, worldY: Double) -> (x: Double, y: Double) {
        (anchorX + (worldX - focusX) * scale, anchorY + (worldY - focusY) * scale)
    }

    /// The world origin's screen position, for a world node scaled by `scale`.
    public var worldOrigin: (x: Double, y: Double) { (anchorX - focusX * scale, anchorY - focusY * scale) }
}
