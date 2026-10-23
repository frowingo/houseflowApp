import Foundation

/// Platform-free 2D math for the FauseTanks engine. Coordinates are arena points with
/// SpriteKit's convention (origin bottom-left, y up); renderers flip for y-down canvases.
public struct HouseTanksVector: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double

    public init(x: Double, y: Double) {
        self.x = x
        self.y = y
    }

    public init(angle: Double, length: Double = 1) {
        self.init(x: cos(angle) * length, y: sin(angle) * length)
    }

    public static let zero = HouseTanksVector(x: 0, y: 0)

    public var length: Double { hypot(x, y) }
    public var angle: Double { atan2(y, x) }

    public var normalized: HouseTanksVector {
        let value = length
        return value > 0 ? HouseTanksVector(x: x / value, y: y / value) : .zero
    }

    public func dot(_ other: HouseTanksVector) -> Double { x * other.x + y * other.y }

    public func distance(to other: HouseTanksVector) -> Double { (self - other).length }

    /// Rotates by `angle` radians counter-clockwise.
    public func rotated(by angle: Double) -> HouseTanksVector {
        let c = cos(angle)
        let s = sin(angle)
        return HouseTanksVector(x: x * c - y * s, y: x * s + y * c)
    }

    public static func + (lhs: Self, rhs: Self) -> Self { .init(x: lhs.x + rhs.x, y: lhs.y + rhs.y) }
    public static func - (lhs: Self, rhs: Self) -> Self { .init(x: lhs.x - rhs.x, y: lhs.y - rhs.y) }
    public static func * (lhs: Self, rhs: Double) -> Self { .init(x: lhs.x * rhs, y: lhs.y * rhs) }
    public static prefix func - (value: Self) -> Self { .init(x: -value.x, y: -value.y) }
    public static func += (lhs: inout Self, rhs: Self) { lhs = lhs + rhs }
    public static func -= (lhs: inout Self, rhs: Self) { lhs = lhs - rhs }
}

public struct HouseTanksSize: Codable, Equatable, Hashable, Sendable {
    public var width: Double
    public var height: Double

    public init(width: Double, height: Double) {
        self.width = width
        self.height = height
    }

    public static let zero = HouseTanksSize(width: 0, height: 0)
    /// The reference arena maps are authored and validated against.
    public static let reference = HouseTanksSize(width: 1_180, height: 640)

    public var isUsable: Bool { width > 0 && height > 0 && width.isFinite && height.isFinite }
}

public struct HouseTanksRect: Codable, Equatable, Hashable, Sendable {
    public var x: Double
    public var y: Double
    public var width: Double
    public var height: Double

    public init(x: Double, y: Double, width: Double, height: Double) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }

    public init(size: HouseTanksSize) {
        self.init(x: 0, y: 0, width: size.width, height: size.height)
    }

    public var minX: Double { x }
    public var minY: Double { y }
    public var maxX: Double { x + width }
    public var maxY: Double { y + height }
    public var midX: Double { x + width / 2 }
    public var midY: Double { y + height / 2 }
    public var center: HouseTanksVector { .init(x: midX, y: midY) }

    public func contains(_ point: HouseTanksVector) -> Bool {
        point.x >= minX && point.x <= maxX && point.y >= minY && point.y <= maxY
    }

    public func insetBy(dx: Double, dy: Double) -> HouseTanksRect {
        HouseTanksRect(x: x + dx, y: y + dy, width: width - dx * 2, height: height - dy * 2)
    }

    public func contains(_ other: HouseTanksRect) -> Bool {
        other.minX >= minX && other.maxX <= maxX && other.minY >= minY && other.maxY <= maxY
    }
}
