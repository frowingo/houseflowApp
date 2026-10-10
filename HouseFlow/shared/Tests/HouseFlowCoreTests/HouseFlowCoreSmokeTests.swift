import XCTest
@testable import HouseFlowCore

final class HouseFlowCoreSmokeTests: XCTestCase {
    func testPackageCanBeImported() {
        XCTAssertTrue(HouseFlowCoreAvailability.isAvailable)
    }
}
