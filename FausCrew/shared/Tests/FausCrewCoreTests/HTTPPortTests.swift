import Foundation
import XCTest
@testable import FausCrewCore

final class HTTPPortTests: XCTestCase {
    func testPercentEncodedQueryDefaultsToNilAndIsStored() {
        XCTAssertNil(HTTPRequest(path: "p", method: "GET").percentEncodedQuery)

        let request = HTTPRequest(path: "p", method: "GET", percentEncodedQuery: "a=b%2B+c")
        XCTAssertEqual(request.percentEncodedQuery, "a=b%2B+c")
        XCTAssertTrue(request.queryItems.isEmpty)
    }

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

    func testStatusFailureRejectsHTMLAndXMLBodiesAndPreservesStatusCode() {
        for body in [
            "<!DOCTYPE html><html><body>502 Bad Gateway</body></html>",
            "  <error>Service unavailable</error>  ",
        ] {
            let response = HTTPResponse(statusCode: 502, headers: [:], body: Data(body.utf8))
            let failure = HTTPStatusFailure(response: response)

            XCTAssertNil(failure.message)
            XCTAssertEqual(failure.statusCode, 502)
        }
    }

    func testStatusFailureRejectsMultilineRawText() {
        for newline in ["\n", "\r", "\r\n", "\u{2028}", "\u{2029}"] {
            let body = "Server error\(newline)at handleRequest()"
            let response = HTTPResponse(statusCode: 500, headers: [:], body: Data(body.utf8))

            XCTAssertNil(HTTPStatusFailure(response: response).message)
        }
    }

    func testStatusFailureLimitsTrimmedRawTextTo200Characters() {
        for length in [199, 200, 201] {
            let text = String(repeating: "a", count: length)
            let response = HTTPResponse(statusCode: 503, headers: [:], body: Data("  \(text)  ".utf8))

            XCTAssertEqual(HTTPStatusFailure(response: response).message, length <= 200 ? text : nil)
        }
    }
}
