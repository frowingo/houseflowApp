import Foundation
import CoreGraphics

/// Gameplay time is advanced only while playing, so pause/countdown cannot spend a joker.
struct HouseTanksPowerUpRules {
    static let duration: TimeInterval = 6
    static let tokenLifetime: TimeInterval = 8
    static let spawnInterval: ClosedRange<TimeInterval> = 7...11
    static let rapidFireCooldown: TimeInterval = 0.16
    static let speedMultiplier: CGFloat = 1.55
    static let spreadAngles: [CGFloat] = [-0.28, -0.14, 0, 0.14, 0.28]

    struct Token {
        let kind: HouseTanksPowerUp
        let position: CGPoint
        let expiresAt: TimeInterval
    }

    private(set) var time: TimeInterval = 0
    private(set) var token: Token?
    private var effects: [UUID: (kind: HouseTanksPowerUp, expiresAt: TimeInterval)] = [:]

    mutating func advance(by delta: TimeInterval) {
        time += max(0, delta)
        if let token, time >= token.expiresAt { self.token = nil }
        effects = effects.filter { time < $0.value.expiresAt }
    }

    @discardableResult
    mutating func spawn(kind: HouseTanksPowerUp, at position: CGPoint) -> Bool {
        guard token == nil else { return false }
        token = Token(kind: kind, position: position, expiresAt: time + Self.tokenLifetime)
        return true
    }

    @discardableResult
    mutating func collect(playerID: UUID) -> HouseTanksPowerUp? {
        guard let token, time < token.expiresAt else { return nil }
        self.token = nil
        effects[playerID] = (token.kind, time + Self.duration)
        return token.kind
    }

    func status(for playerID: UUID) -> HouseTanksPowerUpStatus? {
        guard let effect = effects[playerID], effect.expiresAt > time else { return nil }
        return .init(kind: effect.kind, remaining: effect.expiresAt - time)
    }

    mutating func remove(playerID: UUID) { effects[playerID] = nil }
    mutating func removeToken() { token = nil }

    /// Rejection sampling uses the actual, possibly moved crate bounds, not the authored layout.
    static func isValidSpawn(
        _ point: CGPoint,
        arena: CGRect,
        starts: [CGPoint],
        tanks: [CGPoint],
        obstacles: [CGRect]
    ) -> Bool {
        guard arena.contains(point) else { return false }
        let startClearance = max(80, arena.height * 0.22)
        guard starts.allSatisfy({ hypot($0.x - point.x, $0.y - point.y) >= startClearance }),
              tanks.allSatisfy({ hypot($0.x - point.x, $0.y - point.y) >= 50 }) else { return false }
        return obstacles.allSatisfy { !$0.insetBy(dx: -26, dy: -26).contains(point) }
    }
}
