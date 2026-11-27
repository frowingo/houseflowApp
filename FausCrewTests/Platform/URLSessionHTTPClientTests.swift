import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class URLSessionHTTPClientTests: XCTestCase {
    func testPercentEncodedQueryReachesTheURLByteForByte() async throws {
        let query = "cursor=a+b%2Bc/d%3D&from=2026-10-31T21%3A00%3A00Z&houseId=h1"
        var captured: URLRequest?
        let client = URLSessionHTTPClient(
            baseURL: URL(string: "https://example.com/api/v1")!,
            requestExecutor: { request in
                captured = request
                return (Data(), HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!)
            }
        )

        _ = try await client.send(HTTPRequest(
            path: "chore/archive", method: "GET", headers: ["Authorization": "Bearer jwt"], percentEncodedQuery: query
        ))

        let url = try XCTUnwrap(captured?.url)
        XCTAssertEqual(url.path, "/api/v1/chore/archive")
        XCTAssertEqual(URLComponents(url: url, resolvingAgainstBaseURL: false)?.percentEncodedQuery, query)
        XCTAssertTrue(url.absoluteString.hasSuffix("/chore/archive?\(query)"))
        XCTAssertEqual(captured?.value(forHTTPHeaderField: "Authorization"), "Bearer jwt")
    }
}
