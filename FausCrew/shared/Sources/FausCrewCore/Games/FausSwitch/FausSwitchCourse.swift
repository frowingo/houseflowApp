import Foundation

/// Axis-aligned rectangle in world units; y grows toward the ceiling.
public struct FausSwitchRect: Equatable, Sendable {
    public var minX: Double
    public var minY: Double
    public var maxX: Double
    public var maxY: Double

    public init(minX: Double, minY: Double, maxX: Double, maxY: Double) {
        self.minX = minX
        self.minY = minY
        self.maxX = maxX
        self.maxY = maxY
    }

    public init(centerX: Double, centerY: Double, width: Double, height: Double) {
        self.init(minX: centerX - width / 2, minY: centerY - height / 2,
                  maxX: centerX + width / 2, maxY: centerY + height / 2)
    }

    public var width: Double { maxX - minX }
    public var height: Double { maxY - minY }
    public var midX: Double { (minX + maxX) / 2 }
    public var midY: Double { (minY + maxY) / 2 }

    /// Strict overlap: rectangles that only touch do not intersect.
    public func intersects(_ other: FausSwitchRect) -> Bool {
        minX < other.maxX && other.minX < maxX && minY < other.maxY && other.minY < maxY
    }
}

/// A solid surface. Every face is safe to touch; only the scrolling camera and gaps end
/// a run.
public struct FausSwitchSolid: Equatable, Sendable, Identifiable {
    public enum Kind: String, Sendable {
        /// Floor or ceiling rail segment between gaps.
        case rail
        /// An obstacle block: attached to a rail or floating.
        case block
        /// A robot's own start platform (`FausSwitchStartGrid`).
        case platform
    }

    public let id: Int
    public let kind: Kind
    public let rect: FausSwitchRect

    public init(id: Int, kind: Kind, rect: FausSwitchRect) {
        self.id = id
        self.kind = kind
        self.rect = rect
    }
}

/// A doorway standing on one rail, just big enough for a robot to run through. A robot
/// that touches its opening comes out on the opposite rail at `exitX` (behind the
/// portal), pulled toward that rail and with no vertical speed. It is not solid and never
/// ends a run by itself; it costs ground and puts the robot on the other rail.
public struct FausSwitchPortal: Equatable, Sendable, Identifiable {
    /// The opening: a robot (33.6 high) fits with a little room.
    public static let height = 40.0
    /// Drawn ring width; the opening itself is `openingWidth` wide at `x`.
    public static let width = 22.0
    public static let openingWidth = 8.0

    public let id: Int
    public let x: Double
    /// `.down` stands on the floor, `.up` hangs from the ceiling.
    public let rail: FausSwitchGravity
    /// Track x where the robot comes out, on the opposite rail; always behind `x`.
    public let exitX: Double

    public init(id: Int, x: Double, rail: FausSwitchGravity, exitX: Double) {
        self.id = id
        self.x = x
        self.rail = rail
        self.exitX = exitX
    }

    public var opening: FausSwitchRect {
        let half = Self.openingWidth / 2
        return rail == .down
            ? FausSwitchRect(minX: x - half, minY: FausSwitchMetrics.floorSurface,
                             maxX: x + half, maxY: FausSwitchMetrics.floorSurface + Self.height)
            : FausSwitchRect(minX: x - half, minY: FausSwitchMetrics.ceilingSurface - Self.height,
                             maxX: x + half, maxY: FausSwitchMetrics.ceilingSurface)
    }

    /// Room kept in front of the trail when the exit would be behind it.
    public static let trailRoom = 24.0

    /// The landing x: `exitX`, or just in front of the trail if `exitX` is behind it,
    /// but never at the portal itself. The opposite rail is clear from `exitX` to `x`.
    public func landingX(trail: Double) -> Double {
        let safe = trail + FausSwitchMetrics.runnerWidth / 2 + Self.trailRoom
        return min(max(exitX, safe), x - Self.openingWidth / 2 - FausSwitchMetrics.runnerWidth / 2 - 1)
    }

    /// Where a robot comes out: on the opposite rail's surface, pulled toward it.
    public var exitGravity: FausSwitchGravity { rail.opposite }
    public var exitY: Double {
        let half = FausSwitchMetrics.runnerHeight / 2
        return exitGravity == .down ? FausSwitchMetrics.floorSurface + half : FausSwitchMetrics.ceilingSurface - half
    }
}

/// A hole in one rail. A robot that reaches it while pulled toward that rail falls out.
public struct FausSwitchGap: Equatable, Sendable, Identifiable {
    /// The trigger keeps a body-width margin on both sides, as before.
    public static let sensorInset = FausSwitchMetrics.runnerWidth + 10

    public let id: Int
    public let minX: Double
    public let maxX: Double
    /// `.down` is a floor gap, `.up` a ceiling gap.
    public let rail: FausSwitchGravity

    public init(id: Int, minX: Double, maxX: Double, rail: FausSwitchGravity) {
        self.id = id
        self.minX = minX
        self.maxX = maxX
        self.rail = rail
    }

    public var sensor: FausSwitchRect {
        let edge = rail == .down ? FausSwitchMetrics.floorSurface + 5 : FausSwitchMetrics.ceilingSurface - 5
        return FausSwitchRect(minX: minX + Self.sensorInset, minY: edge - 18,
                              maxX: max(minX + Self.sensorInset + 4, maxX - Self.sensorInset), maxY: edge + 18)
    }
}

/// A one-time speed strip floating in the band, clear of both rails: a robot gets the
/// boost by passing through it (usually mid-flip). Each robot can use each pad once.
public struct FausSwitchBoostPad: Equatable, Sendable, Identifiable {
    public static let width = 48.0
    /// Tall enough to be an easy target mid-flip.
    public static let height = 28.0

    public let id: Int
    public let x: Double
    /// Center height.
    public let y: Double

    public init(id: Int, x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }

    public var rect: FausSwitchRect {
        FausSwitchRect(centerX: x, centerY: y, width: Self.width, height: Self.height)
    }
}

/// A one-time brake strip: a robot that touches it runs `slowPenalty` slower for
/// `slowTicks`. Some lie flat on a rail (any robot running there hits them), some float
/// in the band where flips usually pass. Each robot can hit each pad once.
public struct FausSwitchSlowPad: Equatable, Sendable, Identifiable {
    public static let width = 48.0
    /// Tall enough to be an easy target mid-flip.
    public static let height = 28.0

    public let id: Int
    public let x: Double
    /// Center height.
    public let y: Double

    public init(id: Int, x: Double, y: Double) {
        self.id = id
        self.x = x
        self.y = y
    }

    /// Lying on the floor rail, or hanging from the ceiling rail, at `x`.
    public static func onRail(_ rail: FausSwitchGravity, id: Int, x: Double) -> Self {
        let y = rail == .down ? FausSwitchMetrics.floorSurface + height / 2 : FausSwitchMetrics.ceilingSurface - height / 2
        return .init(id: id, x: x, y: y)
    }

    public var rect: FausSwitchRect {
        FausSwitchRect(centerX: x, centerY: y, width: Self.width, height: Self.height)
    }
}

/// The shared race course. Obstacles come in groups of two or three blocks that split
/// the screen into lanes instead of single floor or ceiling columns.
public struct FausSwitchCourse: Equatable, Sendable {
    public let version: Int
    /// World x where the course (and the camera's travel) ends.
    public let length: Double
    public let finishX: Double
    public let solids: [FausSwitchSolid]
    public let portals: [FausSwitchPortal]
    public let gaps: [FausSwitchGap]
    public let boosts: [FausSwitchBoostPad]
    public let slows: [FausSwitchSlowPad]
    /// How the course bends in the world (drawing and camera only).
    public let track: FausSwitchTrack
    private let buckets: [[Int]]
    /// The first bucket each solid sits in; a query spanning buckets visits a solid only
    /// once without allocating (this runs several times per physics step).
    private let firstBucket: [Int]
    private static let bucketWidth = 200.0

    public init(version: Int, length: Double, solids: [FausSwitchSolid], portals: [FausSwitchPortal] = [],
                gaps: [FausSwitchGap], boosts: [FausSwitchBoostPad], slows: [FausSwitchSlowPad] = [],
                track: FausSwitchTrack = .straight) {
        self.version = version
        self.length = length
        finishX = length - 120
        self.solids = solids
        self.portals = portals
        self.gaps = gaps
        self.boosts = boosts
        self.slows = slows
        self.track = track
        var buckets = [[Int]](repeating: [], count: Int(length / Self.bucketWidth) + 2)
        var firstBuckets: [Int] = []
        for (index, solid) in solids.enumerated() {
            let first = max(0, Int(solid.rect.minX / Self.bucketWidth))
            let last = min(buckets.count - 1, max(first, Int(solid.rect.maxX / Self.bucketWidth)))
            for bucket in first...last { buckets[bucket].append(index) }
            firstBuckets.append(first)
        }
        self.buckets = buckets
        firstBucket = firstBuckets
    }

    public static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.version == rhs.version && lhs.length == rhs.length && lhs.solids == rhs.solids
            && lhs.portals == rhs.portals && lhs.gaps == rhs.gaps && lhs.boosts == rhs.boosts && lhs.slows == rhs.slows
            && lhs.track == rhs.track
    }

    /// Track x the camera follows at `tick` (`FausSwitchCamera.focus`).
    public func cameraFocus(atTick tick: Int64) -> Double { FausSwitchCamera.focus(atTick: tick, course: self) }

    /// The view's trailing edge in track x: a robot whose body is entirely behind it is
    /// left behind. 380 behind the focus on horizontal stretches, 140 on vertical ones.
    public func cameraTrail(atTick tick: Int64) -> Double {
        let focus = cameraFocus(atTick: tick)
        return focus - FausSwitchCamera.behind(atX: focus, track: track)
    }

    /// Solids that may touch a rectangle (a small superset).
    public func solids(near rect: FausSwitchRect, visit: (FausSwitchSolid) -> Void) {
        let first = max(0, Int(rect.minX / Self.bucketWidth))
        let last = min(buckets.count - 1, max(first, Int(rect.maxX / Self.bucketWidth)))
        guard first <= last else { return }
        if first == last {
            for index in buckets[first] { visit(solids[index]) }
            return
        }
        for bucket in first...last {
            for index in buckets[bucket] where max(firstBucket[index], first) == bucket { visit(solids[index]) }
        }
    }

    public func overlapsSolid(_ rect: FausSwitchRect) -> Bool {
        var found = false
        solids(near: rect) { if !found, $0.rect.intersects(rect) { found = true } }
        return found
    }

    /// The same course with extra solids appended (ids continue after the last one).
    public func adding(_ rects: [FausSwitchRect], kind: FausSwitchSolid.Kind) -> FausSwitchCourse {
        var all = solids
        for rect in rects { all.append(.init(id: all.count, kind: kind, rect: rect)) }
        return FausSwitchCourse(version: version, length: length, solids: all, portals: portals, gaps: gaps,
                                boosts: boosts, slows: slows, track: track)
    }

    /// The course a race of `runnerCount` robots runs on: `standard` plus one start
    /// platform per robot, at that race's robot size. Built once per count.
    public static func race(runnerCount: Int) -> FausSwitchCourse {
        raceCourses[FausSwitchStartGrid.clamped(runnerCount) - 1]
    }

    private static let raceCourses: [FausSwitchCourse] = (1...FausSwitchStartGrid.maximumRunners).map {
        standard.adding(FausSwitchStartGrid.lanes(count: $0, runnerScale: FausSwitchStartGrid.runnerScale(runnerCount: $0))
            .map(\.platform), kind: .platform)
    }

    // MARK: Course 3

    /// 2: robots collide with each other and start from their own platforms.
    /// 3: after the horizontal run the course turns and climbs (`turnStartX`).
    /// 4: after the climb it turns again and runs to the left (`secondTurnStartX`).
    /// 5: fair bends (margin share kept through turns, robot contacts by approach side).
    /// 6: portals replace the lasers; slow pads.
    /// 7: races of more than four robots run at 75 % robot size (`FausSwitchStartGrid`).
    public static let currentVersion = 7

    /// Where the band bends upward, and the bends' center-line radius. Bends have no
    /// obstacles; the climb starts at `turnStartX + turnRadius·π/2`.
    public static let turnStartX = 9_100.0
    /// Where the climb bends to the left; the leftward run starts a quarter circle later.
    public static let secondTurnStartX = 15_450.0
    public static let turnRadius = 395.0

    public static let standard: FausSwitchCourse = {
        let length = 20_400.0
        let top = FausSwitchMetrics.worldHeight
        var blocks: [FausSwitchRect] = []
        func block(_ centerX: Double, _ width: Double, _ minY: Double, _ maxY: Double) {
            blocks.append(FausSwitchRect(minX: centerX - width / 2, minY: minY, maxX: centerX + width / 2, maxY: maxY))
        }

        // 1. Floor wall with an island above it.
        block(1_000, 62, 0, 150); block(1_080, 70, 232, 287)
        // 2. Ceiling wall with an island under it.
        block(1_400, 62, 240, top); block(1_480, 70, 103, 158)
        // 3. Rising diagonal trio.
        block(1_820, 58, 0, 118); block(1_870, 64, 172, 218); block(1_920, 58, 272, top)
        // 4. Falling diagonal trio.
        block(2_440, 58, 272, top); block(2_490, 64, 172, 218); block(2_540, 58, 0, 118)
        // 5. Floating pillar, then a floor wall.
        block(2_920, 66, 128, 262); block(3_060, 62, 0, 140)
        // 6. Stacked trio: two narrow passes through the middle.
        block(3_580, 60, 0, 96); block(3_580, 60, 166, 224); block(3_580, 60, 294, top)
        // 7. Ceiling wall with a low island.
        block(4_260, 62, 232, top); block(4_345, 70, 96, 150)
        // 8. Two islands split the screen in thirds, then a floor wall.
        block(5_420, 70, 112, 160); block(5_420, 70, 230, 278); block(5_560, 60, 0, 130)
        // 9. Zig-zag trio.
        block(5_900, 56, 250, top); block(5_990, 56, 0, 140); block(6_080, 56, 250, top)
        // 10. Floating block with a ceiling wall behind it.
        block(6_950, 64, 150, 240); block(7_050, 62, 260, top)
        // 11. Stacked trio, wider passes.
        block(7_560, 60, 0, 110); block(7_560, 60, 180, 210); block(7_560, 60, 280, top)
        // 12. Two mirrored pairs before the finish.
        block(8_250, 62, 0, 150); block(8_330, 70, 232, 290)
        block(8_760, 62, 240, top); block(8_840, 70, 100, 155)

        // The turn: 9 100 … 9 720. Then the climb, read with the floor as the right wall
        // and the ceiling as the left wall. Groups sit a little farther apart because
        // the view shows less ahead while climbing.
        // 13. Floor wall with an island.
        block(10_100, 62, 0, 150); block(10_180, 70, 232, 287)
        // 14. Ceiling wall with an island.
        block(10_600, 62, 240, top); block(10_680, 70, 103, 158)
        // 15. Rising diagonal trio.
        block(11_100, 58, 0, 118); block(11_150, 64, 172, 218); block(11_200, 58, 272, top)
        // 16. Stacked trio.
        block(11_750, 60, 0, 96); block(11_750, 60, 166, 224); block(11_750, 60, 294, top)
        // 17. Zig-zag trio.
        block(12_450, 56, 250, top); block(12_540, 56, 0, 140); block(12_630, 56, 250, top)
        // 18. Two islands, then a floor wall.
        block(13_050, 70, 112, 160); block(13_050, 70, 230, 278); block(13_190, 60, 0, 130)
        // 19. Falling diagonal trio.
        block(13_850, 58, 272, top); block(13_900, 64, 172, 218); block(13_950, 58, 0, 118)
        // 20. Floating pillar, then a floor wall.
        block(14_450, 66, 128, 262); block(14_590, 62, 0, 140)
        // 21. A mirrored pair before the second bend.
        block(15_050, 62, 0, 150); block(15_130, 70, 232, 290)

        // The second bend: 15 450 … 16 070. Then the run to the left; the band is the
        // first stretch turned upside down, so the floor rail is on top.
        // 22. Floor wall with an island.
        block(16_470, 62, 0, 150); block(16_550, 70, 232, 287)
        // 23. Ceiling wall with a low island.
        block(16_900, 62, 232, top); block(16_985, 70, 96, 150)
        // 24. Stacked trio.
        block(17_350, 60, 0, 96); block(17_350, 60, 166, 224); block(17_350, 60, 294, top)
        // 25. Rising diagonal trio.
        block(17_850, 58, 0, 118); block(17_900, 64, 172, 218); block(17_950, 58, 272, top)
        // 26. Zig-zag trio.
        block(18_360, 56, 250, top); block(18_450, 56, 0, 140); block(18_540, 56, 250, top)
        // 27. Floating block with a ceiling wall behind it.
        block(18_800, 64, 150, 240); block(18_900, 62, 260, top)
        // 28. Two islands, then a floor wall.
        block(19_420, 70, 112, 160); block(19_420, 70, 230, 278); block(19_560, 60, 0, 130)
        // 29. A last mirrored pair before the finish.
        block(19_950, 62, 240, top); block(20_030, 70, 100, 155)

        let gaps = [
            FausSwitchGap(id: 0, minX: 3_820, maxX: 4_010, rail: .down),
            FausSwitchGap(id: 1, minX: 4_580, maxX: 4_770, rail: .up),
            FausSwitchGap(id: 2, minX: 6_520, maxX: 6_710, rail: .down),
            FausSwitchGap(id: 3, minX: 7_800, maxX: 7_990, rail: .up),
            FausSwitchGap(id: 4, minX: 12_000, maxX: 12_190, rail: .down),
            FausSwitchGap(id: 5, minX: 13_420, maxX: 13_610, rail: .up),
            FausSwitchGap(id: 6, minX: 17_480, maxX: 17_670, rail: .down),
            FausSwitchGap(id: 7, minX: 19_040, maxX: 19_230, rail: .up),
        ]
        let floor = FausSwitchMetrics.floorSurface
        let ceiling = FausSwitchMetrics.ceilingSurface
        // Portals stand where the lasers were, alternating rails. The exit is on the
        // other rail, 220 back on the runs and 100 back on the climb (where the view
        // keeps only 140 behind the focus), always on clear rail with no slow pad.
        let portals = [
            FausSwitchPortal(id: 0, x: 2_190, rail: .down, exitX: 1_970),
            FausSwitchPortal(id: 1, x: 3_330, rail: .up, exitX: 3_110),
            FausSwitchPortal(id: 2, x: 5_150, rail: .down, exitX: 4_930),
            FausSwitchPortal(id: 3, x: 7_260, rail: .up, exitX: 7_040),
            FausSwitchPortal(id: 4, x: 11_450, rail: .down, exitX: 11_350),
            FausSwitchPortal(id: 5, x: 14_200, rail: .up, exitX: 14_100),
            FausSwitchPortal(id: 6, x: 18_220, rail: .down, exitX: 18_000),
            FausSwitchPortal(id: 7, x: 19_830, rail: .up, exitX: 19_610),
        ]
        // Slow pads where they hurt: on the rail right after a gap (where a robot that
        // jumped it lands), on the rail a robot must leave just before a block, and
        // floating in passages that flips usually cross.
        let slows = [
            FausSwitchSlowPad.onRail(.down, id: 0, x: 1_200),
            FausSwitchSlowPad.onRail(.up, id: 1, x: 2_330),
            FausSwitchSlowPad.onRail(.down, id: 2, x: 4_100),
            FausSwitchSlowPad.onRail(.up, id: 3, x: 4_880),
            FausSwitchSlowPad(id: 4, x: 6_170, y: 205),
            FausSwitchSlowPad.onRail(.down, id: 5, x: 7_380),
            FausSwitchSlowPad.onRail(.up, id: 6, x: 8_080),
            FausSwitchSlowPad.onRail(.down, id: 7, x: 12_270),
            FausSwitchSlowPad(id: 8, x: 13_310, y: 195),
            FausSwitchSlowPad.onRail(.up, id: 9, x: 13_690),
            FausSwitchSlowPad.onRail(.down, id: 10, x: 14_320),
            FausSwitchSlowPad.onRail(.down, id: 11, x: 17_750),
            FausSwitchSlowPad.onRail(.up, id: 12, x: 19_310),
            FausSwitchSlowPad(id: 13, x: 19_700, y: 200),
        ]
        let boosts = [
            FausSwitchBoostPad(id: 0, x: 1_660, y: 150),
            FausSwitchBoostPad(id: 1, x: 2_720, y: 230),
            FausSwitchBoostPad(id: 2, x: 5_170, y: 190),
            FausSwitchBoostPad(id: 3, x: 6_300, y: 140),
            FausSwitchBoostPad(id: 4, x: 8_520, y: 250),
            FausSwitchBoostPad(id: 5, x: 12_900, y: 200),
            FausSwitchBoostPad(id: 6, x: 14_850, y: 150),
            FausSwitchBoostPad(id: 7, x: 16_700, y: 200),
            FausSwitchBoostPad(id: 8, x: 18_670, y: 230),
        ]

        var solids: [FausSwitchSolid] = []
        for rail in [FausSwitchGravity.down, .up] {
            let minY = rail == .down ? 0 : ceiling
            let maxY = rail == .down ? floor : top
            var cursor = 0.0
            for gap in gaps.filter({ $0.rail == rail }).sorted(by: { $0.minX < $1.minX }) {
                if gap.minX > cursor {
                    solids.append(.init(id: solids.count, kind: .rail,
                                        rect: .init(minX: cursor, minY: minY, maxX: gap.minX, maxY: maxY)))
                }
                cursor = max(cursor, gap.maxX)
            }
            solids.append(.init(id: solids.count, kind: .rail,
                                rect: .init(minX: cursor, minY: minY, maxX: length, maxY: maxY)))
        }
        for rect in blocks { solids.append(.init(id: solids.count, kind: .block, rect: rect)) }

        return FausSwitchCourse(version: currentVersion, length: length, solids: solids,
                                portals: portals, gaps: gaps, boosts: boosts, slows: slows,
                                track: FausSwitchTrack(turns: [
                                    .init(startX: turnStartX, radius: turnRadius, isLeft: true),
                                    .init(startX: secondTurnStartX, radius: turnRadius, isLeft: true),
                                ]))
    }()
}

/// Every robot starts on its own short platform at the same start line, so no two
/// robots overlap at the start. The band between the rails is split into one lane per
/// robot; even seats (0, 2, …) stand on top of their platform with gravity down, odd
/// seats hang under theirs with gravity up. From the floor up the lanes hold seats
/// 0, 2, 4, 6, then 7, 5, 3, 1: seat 0 is lowest and seat 1 highest.
public enum FausSwitchStartGrid {
    public static let maximumRunners = 8
    public static let platformThickness = 6.0
    /// Platforms start this far behind the start line and end this far past it.
    public static let platformBack = 40.0
    public static let platformAhead = 120.0

    public struct Lane: Equatable, Sendable {
        public let gravity: FausSwitchGravity
        public let platform: FausSwitchRect
        public let spawn: FausSwitchRunnerState
    }

    static func clamped(_ count: Int) -> Int { min(maximumRunners, max(1, count)) }

    /// A race of more than this many robots is crowded: every robot runs at
    /// `crowdedRobotScale` of its size so eight lanes keep room between them (course 7).
    public static let crowdedRunnerThreshold = 4
    public static let crowdedRobotScale = 0.75

    /// The robot size of a race of `runnerCount` robots, fixed when it starts (online,
    /// the server sends it as the snapshot's `runnerScale`).
    public static func runnerScale(runnerCount: Int) -> Double {
        runnerCount > crowdedRunnerThreshold ? crowdedRobotScale : 1
    }

    /// Index = seat. Heights are worked out in whole tenths of a unit with integer
    /// (floor) division, so every platform agrees on them exactly. `runnerScale` sizes the
    /// robots (`runnerScale(runnerCount:)`); only their height changes the platforms.
    public static func lanes(count: Int, runnerScale: Double = 1) -> [Lane] {
        let count = clamped(count)
        func tenths(_ value: Double) -> Int { Int((value * 10).rounded()) }
        let floor = tenths(FausSwitchMetrics.floorSurface)               // 273
        let band = tenths(FausSwitchMetrics.ceilingSurface) - floor       // 3354
        let height = tenths(FausSwitchMetrics.runnerHeight * runnerScale) // 336
        let thickness = tenths(platformThickness)                         // 60
        let halfBlock = (height + thickness) / 2                          // 198
        let x = FausSwitchMetrics.spawnX
        return (0..<count).map { seat in
            let gravity: FausSwitchGravity = seat.isMultiple(of: 2) ? .down : .up
            let lane = gravity == .down ? seat / 2 : count - 1 - seat / 2
            let center = floor + band * (2 * lane + 1) / (2 * count)
            let platformBottom: Int
            let spawnCenter: Int
            if gravity == .down {
                platformBottom = center - halfBlock
                spawnCenter = platformBottom + thickness + height / 2
            } else {
                platformBottom = center + halfBlock - thickness
                spawnCenter = platformBottom - height / 2
            }
            let platformMinY = Double(platformBottom) / 10
            let spawnY = Double(spawnCenter) / 10
            let platform = FausSwitchRect(minX: x - platformBack, minY: platformMinY,
                                          maxX: x + platformAhead, maxY: Double(platformBottom + thickness) / 10)
            return Lane(gravity: gravity, platform: platform, spawn: FausSwitchRunnerState(x: x, y: spawnY, gravity: gravity,
                                                                                    scale: runnerScale))
        }
    }
}
