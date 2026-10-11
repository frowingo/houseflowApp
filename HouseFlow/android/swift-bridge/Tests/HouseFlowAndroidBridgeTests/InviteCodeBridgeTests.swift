import XCTest
@testable import HouseFlowAndroidBridge

final class InviteCodeBridgeTests: XCTestCase {
    func testVersionAndCoreRule() {
        XCTAssertEqual(bridgeVersion(), 1)
        XCTAssertEqual(normalizeInviteCode("ab-12 cd34xyz"), "AB12CD34")
        XCTAssertEqual(normalizeInviteCode(""), "")
        XCTAssertEqual(normalizeInviteCode("１２３４５６７８ 12345678"), "12345678")
    }
}
