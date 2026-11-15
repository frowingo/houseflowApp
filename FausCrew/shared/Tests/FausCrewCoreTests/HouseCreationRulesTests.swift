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

    func testLimitedNameKeepsShortNamesAndCutsLongOnes() {
        XCTAssertEqual(HouseCreationRules.limitedName("Bahçeli Ev"), "Bahçeli Ev")
        let longName = String(repeating: "a", count: HouseCreationRules.nameMaxLength + 5)
        XCTAssertEqual(HouseCreationRules.limitedName(longName).count, HouseCreationRules.nameMaxLength)
    }

    func testLimitedNameNeverSplitsACharacter() {
        let filler = String(repeating: "a", count: HouseCreationRules.nameMaxLength - 1)
        let family = "👨‍👩‍👧‍👦"
        let flag = "🇹🇷"
        let accented = "e\u{301}"
        for character in [family, flag, accented] {
            XCTAssertEqual(HouseCreationRules.limitedName(filler + character + "tail"), filler + character, character)
            XCTAssertTrue(HouseCreationRules.isValid(name: filler + character, type: 2, memberCount: 4), character)
            XCTAssertFalse(HouseCreationRules.isValid(name: filler + character + character, type: 2, memberCount: 4), character)
        }
    }
}
