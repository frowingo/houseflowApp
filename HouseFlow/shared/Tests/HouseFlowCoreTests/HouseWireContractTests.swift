import Foundation
import XCTest
@testable import HouseFlowCore

final class HouseWireContractTests: XCTestCase {
    func testRequestBodiesMatchExistingHouseEndpoints() throws {
        let create = try object(HouseWireContract.createBody(name: "Home", type: 2, maxMemberCount: 5))
        XCTAssertEqual(create["name"] as? String, "Home")
        XCTAssertEqual(create["maxMemberCount"] as? Int, 5)
        XCTAssertEqual(create["type"] as? Int, 2)
        let join = try object(HouseWireContract.joinBody(inviteCode: "ab-12 cd34"))
        XCTAssertEqual(join["inviteCode"] as? String, "AB12CD34")
        let exit = try object(HouseWireContract.exitBody(houseId: "h", userId: "u"))
        XCTAssertEqual(exit["houseId"] as? String, "h")
        XCTAssertEqual(exit["userId"] as? String, "u")
    }

    func testValidatesAllHouseEnvelopeShapes() throws {
        try HouseWireContract.validate(action: "create", response: reply(HouseFixtures.responseWithStringDates))
        try HouseWireContract.validate(action: "join", response: reply(HouseFixtures.responseWithObjectDatesAndNullInvite))
        try HouseWireContract.validate(action: "details", response: reply(HouseFixtures.detailsWithObjectDatesAndNullOptionals))
        try HouseWireContract.validate(action: "info", response: reply(HouseFixtures.houseInfo))
        try HouseWireContract.validate(action: "invite", response: HTTPResponse(statusCode: 200, headers: [:],
            body: Data(#"{"success":true,"data":{"inviteCode":"AB12CD34","expiresInSeconds":3600}}"#.utf8)))
        try HouseWireContract.validate(action: "exit", response: HTTPResponse(statusCode: 200, headers: [:],
            body: Data(#"{"success":true,"error":null}"#.utf8)))
    }

    func testInvalidDataAndRejectionNeverPassToDashboard() {
        XCTAssertThrowsError(try HouseWireContract.validate(action: "details", response: reply(HouseFixtures.malformedResponse)))
        XCTAssertThrowsError(try HouseWireContract.validate(action: "exit", response: HTTPResponse(statusCode: 200,
            headers: [:], body: Data(#"{"success":false,"error":"Denied"}"#.utf8)))) { error in
            XCTAssertEqual(error as? HouseWireError, .rejected("Denied"))
        }
    }

    func testPreferredHouseHonorsValidChosenAndFallsBackToFirst() {
        let houses = [AuthHouseSummary(houseId: "a", houseName: "A", houseProfile: ""),
            AuthHouseSummary(houseId: "b", houseName: "B", houseProfile: "")]
        XCTAssertEqual(HouseWireContract.preferredHouse(in: houses, chosenId: "b")?.houseId, "b")
        XCTAssertEqual(HouseWireContract.preferredHouse(in: houses, chosenId: "removed")?.houseId, "a")
        XCTAssertNil(HouseWireContract.preferredHouse(in: [], chosenId: "b"))
    }

    private func reply(_ data: Data) -> HTTPResponse {
        HTTPResponse(statusCode: 200, headers: [:], body: Data("{\"success\":true,\"data\":".utf8) + data + Data("}".utf8))
    }

    private func object(_ data: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
    }
}
