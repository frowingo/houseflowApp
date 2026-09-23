import XCTest
@testable import HouseFlow

final class LuckySpinWheelMathTests: XCTestCase {
    func testFinalRotationPlacesEverySelectedSegmentUnderPointer() {
        for count in 2...8 {
            for selectedIndex in 0..<count {
                let rotation = LuckySpinWheelMath.finalRotation(
                    currentRotation: 137,
                    selectedIndex: selectedIndex,
                    segmentCount: count,
                    fullRotations: 5
                )

                XCTAssertEqual(
                    LuckySpinWheelMath.selectedIndex(at: rotation, segmentCount: count),
                    selectedIndex
                )
            }
        }
    }

    func testFinalRotationNeverMovesBackward() {
        let rotation = LuckySpinWheelMath.finalRotation(
            currentRotation: 2_915,
            selectedIndex: 2,
            segmentCount: 6,
            fullRotations: 4
        )

        XCTAssertGreaterThan(rotation, 2_915 + 4 * 360)
    }

    func testInvalidSelectionKeepsCurrentRotation() {
        XCTAssertEqual(
            LuckySpinWheelMath.finalRotation(
                currentRotation: 90,
                selectedIndex: 4,
                segmentCount: 4,
                fullRotations: 5
            ),
            90
        )
    }
}
