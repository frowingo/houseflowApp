import Foundation

enum LuckySpinWheelMath {
    static func finalRotation(
        currentRotation: Double,
        selectedIndex: Int,
        segmentCount: Int,
        fullRotations: Int
    ) -> Double {
        guard segmentCount > 0, (0..<segmentCount).contains(selectedIndex) else {
            return currentRotation
        }

        let segmentAngle = 360.0 / Double(segmentCount)
        let selectedCenterFromTop = (Double(selectedIndex) + 0.5) * segmentAngle
        let desiredRotation = normalizedDegrees(-selectedCenterFromTop)
        let currentNormalized = normalizedDegrees(currentRotation)
        let remainingRotation = normalizedDegrees(desiredRotation - currentNormalized)

        return currentRotation
            + Double(max(0, fullRotations)) * 360.0
            + remainingRotation
    }

    static func selectedIndex(at rotation: Double, segmentCount: Int) -> Int? {
        guard segmentCount > 0 else { return nil }
        let segmentAngle = 360.0 / Double(segmentCount)
        let angleUnderPointer = normalizedDegrees(-rotation)
        return min(segmentCount - 1, Int(angleUnderPointer / segmentAngle))
    }

    static func normalizedDegrees(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360.0)
        return value >= 0 ? value : value + 360.0
    }
}
