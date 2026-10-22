import XCTest
@testable import FausCrewCore

final class FausCrewCoreSmokeTests: XCTestCase {
    func testPackageCanBeImported() {
        XCTAssertTrue(FausCrewCoreAvailability.isAvailable)
    }
}
