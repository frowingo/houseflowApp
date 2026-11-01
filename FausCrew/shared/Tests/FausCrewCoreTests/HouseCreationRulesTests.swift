import XCTest
@testable import FausCrewCore

final class HouseCreationRulesTests: XCTestCase {
    func testAddHouseOptionsHideAtTheHouseLimit() {
        XCTAssertTrue(HouseCreationRules.canAddHouse(currentHouseCount: 0))
        XCTAssertTrue(HouseCreationRules.canAddHouse(currentHouseCount: HouseCreationRules.maximumHouseCount - 1))
        XCTAssertFalse(HouseCreationRules.canAddHouse(currentHouseCount: HouseCreationRules.maximumHouseCount))
    }

    func testFormNeedsNameTypeAndMemberCount() {
        XCTAssertTrue(HouseCreationRules.isValid(name: "Bahçeli Ev", type: 2, memberCount: 4))
        XCTAssertFalse(HouseCreationRules.isValid(name: "   ", type: 2, memberCount: 4))
        XCTAssertFalse(HouseCreationRules.isValid(name: "Bahçeli Ev", type: nil, memberCount: 4))
        XCTAssertFalse(HouseCreationRules.isValid(name: "Bahçeli Ev", type: 2, memberCount: nil))
    }

    func testFormRejectsOutOfRangeValues() {
        let longName = String(repeating: "a", count: HouseCreationRules.nameMaxLength + 1)
        XCTAssertFalse(HouseCreationRules.isValid(name: longName, type: 2, memberCount: 4))
        XCTAssertFalse(HouseCreationRules.isValid(name: "Ev", type: 9, memberCount: 4))
        XCTAssertFalse(HouseCreationRules.isValid(name: "Ev", type: 2, memberCount: 1))
        XCTAssertFalse(HouseCreationRules.isValid(name: "Ev", type: 2, memberCount: 9))
    }
}
