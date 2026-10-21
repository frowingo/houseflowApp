import CoreGraphics
import Foundation

struct HouseTanksBotObservation: Equatable {
    let aimError: CGFloat
    let targetDistance: CGFloat
    let hasTarget: Bool
}

@MainActor
final class HouseTanksBotController {
    let playerID: UUID
    private let randomUnit: () -> Double

    init(
        playerID: UUID,
        randomUnit: @escaping () -> Double = { Double.random(in: 0...1) }
    ) {
        self.playerID = playerID
        self.randomUnit = randomUnit
    }

    func shouldFire(
        observation: HouseTanksBotObservation,
        difficulty: HouseTanksDifficulty
    ) -> Bool {
        guard observation.hasTarget else { return false }

        let tuning = tuning(for: difficulty)
        let distanceAllowance = min(0.12, observation.targetDistance / 4_000)
        let allowedError = tuning.aimTolerance + distanceAllowance
        return observation.aimError <= allowedError && randomUnit() <= tuning.triggerChance
    }

    func decisionDelay(for difficulty: HouseTanksDifficulty) -> UInt64 {
        switch difficulty {
        case .easy: 320_000_000
        case .normal: 210_000_000
        case .hard: 130_000_000
        }
    }

    func holdDuration(for difficulty: HouseTanksDifficulty, travelDistance: CGFloat? = nil) -> UInt64 {
        let normal: UInt64 = switch difficulty {
        case .easy: 360_000_000
        case .normal: 520_000_000
        case .hard: 680_000_000
        }
        guard let travelDistance else { return normal }
        // Release before overshooting a nearby corridor turn, then re-evaluate the route.
        let travelTime = max(0.16, sqrt(max(1, Double(travelDistance)) / 180))
        return min(normal, UInt64(travelTime * 1_000_000_000))
    }

    private func tuning(
        for difficulty: HouseTanksDifficulty
    ) -> (aimTolerance: CGFloat, triggerChance: Double) {
        switch difficulty {
        case .easy: (0.42, 0.55)
        case .normal: (0.25, 0.76)
        case .hard: (0.14, 0.94)
        }
    }
}
