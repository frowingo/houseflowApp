import Foundation

public struct HouseTanksBotObservation: Equatable, Sendable {
    public let aimError: Double
    public let targetDistance: Double
    public let hasTarget: Bool

    public init(aimError: Double, targetDistance: Double, hasTarget: Bool) {
        self.aimError = aimError
        self.targetDistance = targetDistance
        self.hasTarget = hasTarget
    }

    public static let none = HouseTanksBotObservation(aimError: .pi, targetDistance: 0, hasTarget: false)
}

/// Bot decisions per difficulty. Pure functions: the caller supplies the random draw, so
/// a seeded match decides the same way on every device.
public enum HouseTanksBotBrain {
    public static func shouldFire(observation: HouseTanksBotObservation, difficulty: HouseTanksDifficulty,
                                  roll: Double) -> Bool {
        guard observation.hasTarget else { return false }
        let tuning = tuning(for: difficulty)
        let distanceAllowance = min(0.12, observation.targetDistance / 4_000)
        return observation.aimError <= tuning.aimTolerance + distanceAllowance && roll <= tuning.triggerChance
    }

    /// Seconds between bot decisions.
    public static func decisionDelay(for difficulty: HouseTanksDifficulty) -> Double {
        switch difficulty {
        case .easy: 0.27
        case .normal: 0.17
        case .hard: 0.10
        }
    }

    /// How long a bot holds its press, in seconds.
    public static func holdDuration(for difficulty: HouseTanksDifficulty, travelDistance: Double? = nil) -> Double {
        let normal: Double = switch difficulty {
        case .easy: 0.36
        case .normal: 0.52
        case .hard: 0.68
        }
        guard let travelDistance else { return normal }
        // Release before overshooting a nearby corridor turn, then re-evaluate the route.
        return min(normal, max(0.16, sqrt(max(1, travelDistance) / 180)))
    }

    /// Bots engage whichever living tank is closest, human or bot alike.
    public static func nearestTarget(from position: HouseTanksVector,
                                     among candidates: [(id: UUID, position: HouseTanksVector)]) -> UUID? {
        candidates.min { $0.position.distance(to: position) < $1.position.distance(to: position) }?.id
    }

    /// The focused tank wins while it is still in play; otherwise fall back to the nearest one.
    public static func target(from position: HouseTanksVector,
                              among candidates: [(id: UUID, position: HouseTanksVector)], focus: UUID?) -> UUID? {
        if let focus, candidates.contains(where: { $0.id == focus }) { return focus }
        return nearestTarget(from: position, among: candidates)
    }

    private static func tuning(for difficulty: HouseTanksDifficulty) -> (aimTolerance: Double, triggerChance: Double) {
        switch difficulty {
        case .easy: (0.38, 0.66)
        case .normal: (0.22, 0.86)
        case .hard: (0.12, 0.98)
        }
    }
}
