import XCTest
@testable import FausCrewAndroidBridge

final class HouseNameBridgeTests: XCTestCase {
    private let filler = String(repeating: "a", count: 29)

    func testNamesAreCutAndCountedInCharactersNotUTF16Units() {
        for character in ["👨‍👩‍👧‍👦", "🇹🇷", "e\u{301}"] {
            let name = filler + character + "tail"
            XCTAssertEqual(limitedHouseName(name), filler + character, character)
            XCTAssertEqual(houseNameLength(filler + character), 30, character)
        }
        XCTAssertEqual(limitedHouseName("Bahçeli Ev"), "Bahçeli Ev")
    }

    func testFormValidityCountsCharacters() {
        XCTAssertTrue(isHouseCreationValid(filler + "👨‍👩‍👧‍👦", 2, 4))
        XCTAssertFalse(isHouseCreationValid(filler + "👨‍👩‍👧‍👦" + "👨‍👩‍👧‍👦", 2, 4))
        XCTAssertFalse(isHouseCreationValid("   ", 2, 4))
        XCTAssertFalse(isHouseCreationValid("Ev", 9, 4))
        XCTAssertFalse(isHouseCreationValid("Ev", 2, 9))
    }
}
