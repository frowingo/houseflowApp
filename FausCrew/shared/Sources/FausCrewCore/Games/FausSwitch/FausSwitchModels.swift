import Foundation

/// Which surface pulls the robot. `down` pulls toward the floor rail (y = 0).
public enum FausSwitchGravity: String, Codable, Sendable {
    case down
    case up

    public var opposite: FausSwitchGravity { self == .down ? .up : .down }
    /// -1 toward the floor, +1 toward the ceiling.
    public var sign: Double { self == .down ? -1 : 1 }
}

/// Robot colors. Every robot in a match has its own color; the player picks one in
/// demo and asks for one online (the server keeps the first claim per color).
public enum FausSwitchColor: String, Codable, CaseIterable, Identifiable, Sendable {
    case plum
    case forest
    case ocean
    case lavender
    case olive
    case bronze
    case graphite
    case berry

    public var id: String { rawValue }

    /// Body tone, always darker than the light course background, and one per hue so
    /// robots tell apart at a glance: plum and forest are palette colors, the others are
    /// muted tones that sit with the palette (blue, purple, yellow-green, copper, warm
    /// grey, rose). Berry is lighter than the wine obstacles so it never blends in.
    public var bodyHex: UInt32 {
        switch self {
        case .plum: 0x30021F
        case .forest: 0x3D896D
        case .ocean: 0x3F6C9E
        case .lavender: 0x8467B8
        case .olive: 0x7D8B2E
        case .bronze: 0xB06A3B
        case .graphite: 0x5B5560
        case .berry: 0xB0446F
        }
    }

    public var titleKey: String { "faus_switch_color_\(rawValue)" }

    /// The first free colors after `taken`, in catalog order.
    public static func free(excluding taken: [FausSwitchColor], count: Int) -> [FausSwitchColor] {
        Array(allCases.filter { !taken.contains($0) }.prefix(max(0, count)))
    }
}

public enum FausSwitchMode: String, CaseIterable, Identifiable, Sendable {
    case demo
    case online

    public var id: String { rawValue }
}

public enum FausSwitchRunnerStatus: String, Codable, Sendable {
    case running
    case finished
    case crashed
}

public enum FausSwitchCrashReason: String, Codable, Sendable {
    /// Left the playfield vertically (fell through a rail gap).
    case boundary
    /// The whole body left the scrolling camera's left edge.
    case leftBehind
    /// Online only: left the match.
    case forfeit
    /// Online only: house membership was removed.
    case membershipRevoked
}

public enum FausSwitchBotSkill: String, Codable, CaseIterable, Sendable {
    case easy
    case normal
    case hard
}

public enum FausSwitchRunnerRole: String, Codable, Sendable {
    case human
    case bot
}

/// The fixed logical world every client draws, scaled to its screen. Values are the
/// SpriteKit tuning of the solo build on a 390-point-high landscape iPhone; gravity is
/// a little softer than the solo build so a flip reads as a glide, not a snap.
public enum FausSwitchMetrics {
    public static let physicsRate = 120
    public static let tickDuration = 1.0 / Double(physicsRate)

    public static let worldHeight = 390.0
    /// The camera's width in world units (a 390-point-high iPhone in landscape).
    public static let viewportWidth = 844.0
    /// The robot's x on screen at the start; the camera keeps this offset while scrolling.
    public static let spawnX = 380.0

    /// 80 % of the solo build's 34 × 42 house (first cut to 70 %, then enlarged a little).
    public static let runnerWidth = 27.2
    public static let runnerHeight = 33.6

    /// Rails are 7 % of the playfield high, as before.
    public static let railThickness = 27.3
    public static let floorSurface = railThickness
    public static let ceilingSurface = worldHeight - railThickness

    public static let runSpeed = 225.0
    /// The solo build's 3 600 (24 m/s² at 150 points per meter), softened by about 20 %.
    public static let gravity = 2_900.0
    public static let switchVelocity = 270.0
    /// Share of the current vertical speed kept by a flip (when it beats `switchVelocity`).
    public static let flipCarry = 0.34
    public static let boostExtraSpeed = 110.0
    public static let boostTicks: Int64 = 78 // 0.65 s
    /// A slow pad takes this off the run speed (225 → 125) for `slowTicks`.
    public static let slowPenalty = 100.0
    public static let slowTicks: Int64 = 96 // 0.8 s
    /// max(300, 0.8 × height): the push that drops a robot through a rail gap.
    public static let gapExitSpeed = 312.0
    public static let boundaryMargin = 80.0

    /// Countdown before the run, in whole seconds.
    public static let countdownSeconds = 3
    /// A match never runs longer than this (the course takes about 40 s).
    public static let maximumMatchTicks: Int64 = Int64(physicsRate) * 120

    public static func ticks(_ seconds: Double) -> Int64 { Int64((seconds * Double(physicsRate)).rounded()) }
    public static func seconds(_ ticks: Int64) -> Double { Double(ticks) * tickDuration }
}
