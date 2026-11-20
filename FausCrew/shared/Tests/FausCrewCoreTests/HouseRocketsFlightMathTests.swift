import Foundation
import FausCrewCore
import XCTest

/// The optimized contact pass must give exactly what running every face three times gives.
final class HouseRocketsFlightMathTests: XCTestCase {
    private func gates(_ indices: Range<Int>) -> [HouseRocketsRenderGate] {
        indices.map { index in
            let gate = HouseRocketsCourse.gate(index: index)
            return HouseRocketsRenderGate(id: "gate:\(index)", worldX: gate.worldX, sections: gate.sections)
        }
    }

    /// The straightforward version: clamp, then every polygon, three times.
    private func reference(_ start: HouseRocketsPoint, _ gates: [HouseRocketsRenderGate]) -> HouseRocketsPoint {
        let solids = gates.flatMap(\.solidPolygons)
        var point = start
        for _ in 0..<3 {
            point.y = min(HouseRocketsSimulation.trackHeight - HouseRocketsSimulation.rocketRadius,
                          max(HouseRocketsSimulation.rocketRadius, point.y))
            for polygon in solids {
                point = HouseRocketsContact.resolve(point, radius: HouseRocketsSimulation.rocketRadius, polygon: polygon)
            }
        }
        return point
    }

    func testSolidSetResolvesLikeEveryFaceThreeTimes() {
        for layout in [0..<1, 0..<6, 3..<9, 10..<14] {
            let layoutGates = gates(layout)
            let solids = HouseRocketsSolidSet(gates: layoutGates)
            let first = layoutGates.first?.worldX ?? 0
            var generator = SystemRandomNumberGenerator()
            for _ in 0..<4_000 {
                let point = HouseRocketsPoint(x: first - 60 + Double.random(in: 0...900, using: &generator),
                                              y: Double.random(in: -30...390, using: &generator))
                XCTAssertEqual(solids.resolve(point), reference(point, layoutGates), "\(point)")
            }
        }
    }

    func testAdvanceMatchesTheStepwiseReferenceAcrossGates() {
        let layoutGates = gates(0..<8)
        let solids = HouseRocketsSolidSet(gates: layoutGates)
        let rocket = HouseRocketsRenderPlayer(id: "a", name: .displayName("A"), role: .human, color: .mint, isAlive: true,
                                              worldX: layoutGates[0].worldX - 200, worldY: 180, courseHeading: 0.3,
                                              speedEffect: nil, effectRemaining: 0)
        let optimized = HouseRocketsFlightMath.advance(rocket, from: 0, to: 2.5, solids: solids)
        var expected = rocket
        var time = 0.0
        while time < 2.5 - 0.000_001 {
            let step = min(1.0 / 120.0, 2.5 - time)
            let point = reference(HouseRocketsPoint(x: expected.worldX + cos(expected.courseHeading) * HouseRocketsSimulation.speed * step,
                                                    y: expected.worldY + sin(expected.courseHeading) * HouseRocketsSimulation.speed * step),
                                  layoutGates)
            expected.worldX = point.x
            expected.worldY = point.y
            time += step
        }
        XCTAssertEqual(optimized.worldX, expected.worldX)
        XCTAssertEqual(optimized.worldY, expected.worldY)
    }
}
