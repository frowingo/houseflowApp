import Foundation
import XCTest
@testable import HouseFlowCore

final class HTTPPortTests: XCTestCase {
    func testStatusFailurePreservesMessageThenErrorEnvelopePrecedence() {
        let both = HTTPResponse(
            statusCode: 401,
            headers: [:],
            body: Data(#"{"message":"Invalid credentials.","error":"fallback"}"#.utf8)
        )
        let errorOnly = HTTPResponse(
            statusCode: 404,
            headers: [:],
            body: Data(#"{"error":"House not found."}"#.utf8)
        )

        XCTAssertEqual(HTTPStatusFailure(response: both).message, "Invalid credentials.")
        XCTAssertEqual(HTTPStatusFailure(response: both).statusCode, 401)
        XCTAssertEqual(HTTPStatusFailure(response: errorOnly).message, "House not found.")
    }

    func testStatusFailurePreservesRawTextAndEmptyBodyBehavior() {
        let raw = HTTPResponse(statusCode: 500, headers: [:], body: Data("  server down  ".utf8))
        let empty = HTTPResponse(statusCode: 503, headers: [:], body: Data())
        let emptyEnvelope = HTTPResponse(statusCode: 400, headers: [:], body: Data("{}".utf8))

        XCTAssertEqual(HTTPStatusFailure(response: raw).message, "server down")
        XCTAssertNil(HTTPStatusFailure(response: empty).message)
        XCTAssertEqual(HTTPStatusFailure(response: emptyEnvelope).message, "Request failed.")
    }
}
