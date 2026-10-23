import Foundation

/// Hands out jokers from a shuffled bag: every kind appears once per bag, in a fresh order,
/// and a new bag never starts with the kind the previous one ended on.
public struct HouseTanksJokerBag: Codable, Equatable, Sendable {
    private var queue: [HouseTanksPowerUp] = []
    public private(set) var last: HouseTanksPowerUp?

    public init() {}

    public mutating func next() -> HouseTanksPowerUp {
        var generator = SystemRandomNumberGenerator()
        return next(using: &generator)
    }

    public mutating func next<Generator: RandomNumberGenerator>(using generator: inout Generator) -> HouseTanksPowerUp {
        if queue.isEmpty {
            queue = HouseTanksPowerUp.allCases.shuffled(using: &generator)
            if queue.first == last, queue.count > 1 {
                queue.swapAt(0, Int.random(in: 1..<queue.count, using: &generator))
            }
        }
        let kind = queue.removeFirst()
        last = kind
        return kind
    }
}

/// Gameplay time is advanced only while playing, so pause/countdown cannot spend a joker.
public struct HouseTanksPowerUpRules: Codable, Equatable, Sendable {
    public static let duration = 8.0
    public static let tokenLifetime = 12.0
    public static let spawnInterval: ClosedRange<Double> = 7...11
    public static let rapidFireCooldown = 0.16
    public static let spreadAngles: [Double] = [-0.28, -0.14, 0, 0.14, 0.28]

    public struct Token: Codable, Equatable, Sendable {
        public let kind: HouseTanksPowerUp
        public let position: HouseTanksVector
        public let expiresAt: Double
    }

    private struct Effect: Codable, Equatable, Sendable {
        let kind: HouseTanksPowerUp
        let expiresAt: Double
    }

    public private(set) var time = 0.0
    public private(set) var token: Token?
    private var effects: [UUID: Effect] = [:]

    public init() {}

    public mutating func advance(by delta: Double) {
        time += max(0, delta)
        if let token, time >= token.expiresAt { self.token = nil }
        effects = effects.filter { time < $0.value.expiresAt }
    }

    @discardableResult
    public mutating func spawn(kind: HouseTanksPowerUp, at position: HouseTanksVector) -> Bool {
        guard token == nil else { return false }
        token = Token(kind: kind, position: position, expiresAt: time + Self.tokenLifetime)
        return true
    }

    @discardableResult
    public mutating func collect(playerID: UUID) -> HouseTanksPowerUp? {
        guard let token, time < token.expiresAt else { return nil }
        self.token = nil
        effects[playerID] = Effect(kind: token.kind, expiresAt: time + Self.duration)
        return token.kind
    }

    public func status(for playerID: UUID) -> HouseTanksPowerUpStatus? {
        guard let effect = effects[playerID], effect.expiresAt > time else { return nil }
        return .init(kind: effect.kind, remaining: effect.expiresAt - time)
    }

    public mutating func remove(playerID: UUID) { effects[playerID] = nil }
    public mutating func removeToken() { token = nil }

    /// Rejection sampling uses the actual, possibly moved crate bounds, not the authored layout.
    public static func isValidSpawn(_ point: HouseTanksVector, arena: HouseTanksRect, starts: [HouseTanksVector],
                                    tanks: [HouseTanksVector], obstacles: [HouseTanksRect]) -> Bool {
        guard arena.contains(point) else { return false }
        let startClearance = max(80, arena.height * 0.22)
        guard starts.allSatisfy({ $0.distance(to: point) >= startClearance }),
              tanks.allSatisfy({ $0.distance(to: point) >= 50 }) else { return false }
        return obstacles.allSatisfy { !$0.insetBy(dx: -26, dy: -26).contains(point) }
    }
}
