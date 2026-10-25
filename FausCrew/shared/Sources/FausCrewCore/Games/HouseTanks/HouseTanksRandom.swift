import Foundation

/// Seedable SplitMix64, draw for draw the backend's `Random`. The demo draws every random
/// choice (joker order and spots, bot triggers) from one of these; online the server draws
/// and sends the outcome, so clients never need to reproduce its sequence.
public struct HouseTanksRandom: RandomNumberGenerator, Codable, Equatable, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var value = state
        value = (value ^ (value >> 30)) &* 0xBF58_476D_1CE4_E5B9
        value = (value ^ (value >> 27)) &* 0x94D0_49BB_1331_11EB
        return value ^ (value >> 31)
    }

    /// A uniform value in [0, 1).
    public mutating func unit() -> Double {
        Double(next() >> 11) / Double(1 << 53)
    }

    /// A uniform value in [lower, upper).
    public mutating func between(_ lower: Double, _ upper: Double) -> Double {
        lower + unit() * (upper - lower)
    }

    /// A uniform integer in [0, count).
    public mutating func below(_ count: Int) -> Int {
        Int(next() % UInt64(count))
    }
}
