import CoreGraphics
import Foundation

enum HouseSwitchPhase: Equatable {
    case briefing
    case playing
    case paused
    case crashed
    case finished
}

enum HouseSwitchCrashReason: Equatable {
    case laser
    case boundary
    case leftBehind
}

enum HouseSwitchGravity: CGFloat, Equatable {
    case down = -1
    case up = 1

    var opposite: HouseSwitchGravity {
        self == .down ? .up : .down
    }

    var rotation: CGFloat {
        self == .down ? 0 : .pi
    }
}

enum HouseSwitchSurfaceKind: Equatable {
    case solid
    case laser
    case boundary
    case finish

    var isLethal: Bool {
        switch self {
        case .laser, .boundary:
            return true
        case .solid, .finish:
            return false
        }
    }
}

enum HouseSwitchPhysicsCategory {
    static let player: UInt32 = 1 << 0
    static let solid: UInt32 = 1 << 1
    static let hazard: UInt32 = 1 << 2
    static let finish: UInt32 = 1 << 3
    static let gap: UInt32 = 1 << 4
    static let boost: UInt32 = 1 << 5
}

enum HouseSwitchCollisionPolicy {
    static func isLethalContact(_ first: UInt32, _ second: UInt32) -> Bool {
        let categories = first | second
        return categories & HouseSwitchPhysicsCategory.player != 0
            && categories & HouseSwitchPhysicsCategory.hazard != 0
    }

    static func isFinishContact(_ first: UInt32, _ second: UInt32) -> Bool {
        let categories = first | second
        return categories & HouseSwitchPhysicsCategory.player != 0
            && categories & HouseSwitchPhysicsCategory.finish != 0
    }

    static func isGapContact(_ first: UInt32, _ second: UInt32) -> Bool {
        let categories = first | second
        return categories & HouseSwitchPhysicsCategory.player != 0
            && categories & HouseSwitchPhysicsCategory.gap != 0
    }

    static func isBoostContact(_ first: UInt32, _ second: UInt32) -> Bool {
        let categories = first | second
        return categories & HouseSwitchPhysicsCategory.player != 0
            && categories & HouseSwitchPhysicsCategory.boost != 0
    }
}

struct HouseSwitchPlatformSpec: Equatable {
    let x: CGFloat
    let width: CGFloat
    let centerY: CGFloat
    let heightRatio: CGFloat

    func frame(in playfieldHeight: CGFloat) -> CGRect {
        let resolvedHeight = heightRatio * playfieldHeight
        return CGRect(
            x: x - width / 2,
            y: centerY * playfieldHeight - resolvedHeight / 2,
            width: width,
            height: resolvedHeight
        )
    }
}

struct HouseSwitchLaserSpec: Equatable {
    enum VerticalAnchor: Equatable {
        case floor
        case ceiling
    }

    let x: CGFloat
    let anchor: VerticalAnchor
    let heightRatio: CGFloat
    let initialDelay: TimeInterval
}

struct HouseSwitchGapSpec: Equatable {
    let startX: CGFloat
    let width: CGFloat
    let anchor: HouseSwitchLaserSpec.VerticalAnchor

    var endX: CGFloat { startX + width }
}

struct HouseSwitchBoostSpec: Equatable {
    let x: CGFloat
    let width: CGFloat
    let anchor: HouseSwitchLaserSpec.VerticalAnchor
}

struct HouseSwitchLevel: Equatable {
    let length: CGFloat
    let platforms: [HouseSwitchPlatformSpec]
    let lasers: [HouseSwitchLaserSpec]
    let gaps: [HouseSwitchGapSpec]
    let boosts: [HouseSwitchBoostSpec]

    static let firstCourse: HouseSwitchLevel = {
        let length: CGFloat = 8_840
        let gaps = [
            HouseSwitchGapSpec(startX: 4_730, width: 260, anchor: .floor),
            HouseSwitchGapSpec(startX: 5_680, width: 260, anchor: .ceiling),
            HouseSwitchGapSpec(startX: 6_730, width: 260, anchor: .floor),
            HouseSwitchGapSpec(startX: 7_670, width: 260, anchor: .ceiling),
        ]

        return HouseSwitchLevel(
            length: length,
            platforms:
                railSegments(length: length, anchor: .floor, gaps: gaps)
                + railSegments(length: length, anchor: .ceiling, gaps: gaps)
                + [
                    // Solid front and side impacts remain recoverable.
                    HouseSwitchPlatformSpec(x: 780, width: 88, centerY: 0.20, heightRatio: 0.34),
                    HouseSwitchPlatformSpec(x: 1_125, width: 96, centerY: 0.77, heightRatio: 0.39),
                    HouseSwitchPlatformSpec(x: 1_480, width: 104, centerY: 0.29, heightRatio: 0.52),
                    HouseSwitchPlatformSpec(x: 1_845, width: 92, centerY: 0.72, heightRatio: 0.49),
                    HouseSwitchPlatformSpec(x: 2_540, width: 120, centerY: 0.27, heightRatio: 0.46),
                    HouseSwitchPlatformSpec(x: 2_890, width: 110, centerY: 0.74, heightRatio: 0.43),
                    HouseSwitchPlatformSpec(x: 3_230, width: 100, centerY: 0.31, heightRatio: 0.56),
                    HouseSwitchPlatformSpec(x: 3_570, width: 98, centerY: 0.70, heightRatio: 0.54),
                    HouseSwitchPlatformSpec(x: 3_820, width: 150, centerY: 0.22, heightRatio: 0.18),
                    HouseSwitchPlatformSpec(x: 4_060, width: 150, centerY: 0.78, heightRatio: 0.18),
                    HouseSwitchPlatformSpec(x: 5_150, width: 110, centerY: 0.27, heightRatio: 0.44),
                    HouseSwitchPlatformSpec(x: 5_480, width: 104, centerY: 0.73, heightRatio: 0.42),
                    HouseSwitchPlatformSpec(x: 6_120, width: 110, centerY: 0.28, heightRatio: 0.49),
                    HouseSwitchPlatformSpec(x: 6_480, width: 112, centerY: 0.72, heightRatio: 0.48),
                    HouseSwitchPlatformSpec(x: 7_150, width: 108, centerY: 0.27, heightRatio: 0.46),
                    HouseSwitchPlatformSpec(x: 7_420, width: 104, centerY: 0.74, heightRatio: 0.41),
                    HouseSwitchPlatformSpec(x: 8_150, width: 110, centerY: 0.28, heightRatio: 0.47),
                    HouseSwitchPlatformSpec(x: 8_450, width: 108, centerY: 0.72, heightRatio: 0.43),
                ],
            lasers: [
                HouseSwitchLaserSpec(x: 2_180, anchor: .floor, heightRatio: 0.58, initialDelay: 1.1),
                HouseSwitchLaserSpec(x: 3_390, anchor: .ceiling, heightRatio: 0.56, initialDelay: 0.35),
                HouseSwitchLaserSpec(x: 5_940, anchor: .floor, heightRatio: 0.53, initialDelay: 0.7),
                HouseSwitchLaserSpec(x: 8_020, anchor: .ceiling, heightRatio: 0.51, initialDelay: 0.9),
            ],
            gaps: gaps,
            boosts: [
                HouseSwitchBoostSpec(x: 1_320, width: 68, anchor: .floor),
                HouseSwitchBoostSpec(x: 3_040, width: 68, anchor: .floor),
                HouseSwitchBoostSpec(x: 5_260, width: 72, anchor: .ceiling),
                HouseSwitchBoostSpec(x: 6_330, width: 72, anchor: .floor),
                HouseSwitchBoostSpec(x: 7_980, width: 72, anchor: .floor),
            ]
        )
    }()

    private static func railSegments(
        length: CGFloat,
        anchor: HouseSwitchLaserSpec.VerticalAnchor,
        gaps: [HouseSwitchGapSpec]
    ) -> [HouseSwitchPlatformSpec] {
        let centerY: CGFloat = anchor == .floor ? 0.035 : 0.965
        var cursor: CGFloat = 0
        var segments: [HouseSwitchPlatformSpec] = []

        for gap in gaps.filter({ $0.anchor == anchor }).sorted(by: { $0.startX < $1.startX }) {
            if gap.startX > cursor {
                let width = gap.startX - cursor
                segments.append(HouseSwitchPlatformSpec(
                    x: cursor + width / 2,
                    width: width,
                    centerY: centerY,
                    heightRatio: 0.07
                ))
            }
            cursor = max(cursor, gap.endX)
        }

        if cursor < length {
            let width = length - cursor
            segments.append(HouseSwitchPlatformSpec(
                x: cursor + width / 2,
                width: width,
                centerY: centerY,
                heightRatio: 0.07
            ))
        }

        return segments
    }
}

enum HouseSwitchRunMetrics {
    static func progress(position: CGFloat, courseLength: CGFloat) -> Double {
        guard courseLength > 0 else { return 0 }
        return min(1, max(0, Double(position / courseLength)))
    }

    static func isCompletelyBehindViewport(
        playerCenterX: CGFloat,
        playerWidth: CGFloat,
        viewportMinX: CGFloat
    ) -> Bool {
        playerCenterX + playerWidth / 2 <= viewportMinX
    }
}

enum HouseSwitchHorizontalLayout {
    static let originalSpawnX: CGFloat = 150

    static func spawnX(for viewportWidth: CGFloat) -> CGFloat {
        max(originalSpawnX, viewportWidth * 0.45)
    }

    static func courseOffset(for viewportWidth: CGFloat) -> CGFloat {
        spawnX(for: viewportWidth) - originalSpawnX
    }
}

enum HouseSwitchPhysicsTuning {
    static let runSpeed: CGFloat = 225
    private static let referencePlayfieldHeight: CGFloat = 390
    private static let baseGravityStrength: CGFloat = 24
    private static let baseSwitchVelocity: CGFloat = 270

    static func verticalScale(for playfieldHeight: CGFloat) -> CGFloat {
        max(0.82, playfieldHeight / referencePlayfieldHeight)
    }

    static func gravityStrength(for playfieldHeight: CGFloat) -> CGFloat {
        baseGravityStrength * verticalScale(for: playfieldHeight)
    }

    static func switchVelocity(for playfieldHeight: CGFloat) -> CGFloat {
        baseSwitchVelocity * verticalScale(for: playfieldHeight)
    }

    static func estimatedVerticalTravelTime(
        distance: CGFloat,
        playfieldHeight: CGFloat
    ) -> TimeInterval {
        guard distance > 0 else { return 0 }
        let velocity = switchVelocity(for: playfieldHeight)
        let acceleration = gravityStrength(for: playfieldHeight)
        let discriminant = velocity * velocity + 2 * acceleration * distance
        return TimeInterval((-velocity + sqrt(discriminant)) / acceleration)
    }
}

enum HouseSwitchSupportProbe {
    static func frame(
        playerPosition: CGPoint,
        playerSize: CGSize,
        gravity: HouseSwitchGravity
    ) -> CGRect {
        let horizontalInset = min(7, playerSize.width * 0.2)
        let probeDepth: CGFloat = 1
        let bodyOverlap: CGFloat = 0.5
        let edgeY = playerPosition.y + gravity.rawValue * playerSize.height / 2
        let originY = gravity == .down
            ? edgeY - probeDepth + bodyOverlap
            : edgeY - bodyOverlap

        return CGRect(
            x: playerPosition.x - playerSize.width / 2 + horizontalInset,
            y: originY,
            width: max(2, playerSize.width - horizontalInset * 2),
            height: probeDepth
        )
    }
}

struct HouseSwitchRunClock: Equatable {
    private(set) var startedAt: TimeInterval?
    private(set) var pausedAt: TimeInterval?
    private(set) var pausedDuration: TimeInterval = 0

    mutating func start(at time: TimeInterval) {
        startedAt = time
        pausedAt = nil
        pausedDuration = 0
    }

    mutating func pause(at time: TimeInterval) {
        guard startedAt != nil, pausedAt == nil else { return }
        pausedAt = time
    }

    mutating func resume(at time: TimeInterval) {
        guard let pausedAt else { return }
        pausedDuration += max(0, time - pausedAt)
        self.pausedAt = nil
    }

    func elapsed(at time: TimeInterval) -> TimeInterval {
        guard let startedAt else { return 0 }
        let effectiveEnd = pausedAt ?? time
        return max(0, effectiveEnd - startedAt - pausedDuration)
    }
}
