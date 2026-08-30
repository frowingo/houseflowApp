import XCTest
@testable import HouseFlow

@MainActor
final class NetworkServiceTests: XCTestCase {
    private struct RequestBody: Encodable {
        let email: String
        let rememberMe: Bool
    }

    private struct ResponseBody: Decodable, Equatable {
        let id: String
        let success: Bool
    }

    func testRequestBuildsPostAndDecodesSuccessfulResponse() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data(#"{"id":"result-1","success":true}"#.utf8)
        let service = makeService(stub: stub)

        let response = try await service.request(
            path: "auth/login",
            body: RequestBody(email: "user@example.com", rememberMe: true),
            successType: ResponseBody.self
        )

        XCTAssertEqual(response, ResponseBody(id: "result-1", success: true))
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.url?.absoluteString, "https://example.com/api/v1/auth/login")
        XCTAssertEqual(request.httpMethod, "POST")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")

        let bodyData = try XCTUnwrap(request.httpBody)
        let body = try XCTUnwrap(
            JSONSerialization.jsonObject(with: bodyData) as? [String: Any]
        )
        XCTAssertEqual(body["email"] as? String, "user@example.com")
        XCTAssertEqual(body["rememberMe"] as? Bool, true)
    }

    func testAuthenticatedGetAddsBearerTokenAndQueryItems() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data(#"{"id":"result-2","success":true}"#.utf8)
        let service = makeService(stub: stub)

        let response = try await service.get(
            path: "house/details",
            queryItems: [URLQueryItem(name: "houseId", value: "house 1")],
            successType: ResponseBody.self,
            token: "secret-token"
        )

        XCTAssertEqual(response.id, "result-2")
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer secret-token")
        let components = try XCTUnwrap(URLComponents(url: try XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        XCTAssertEqual(components.path, "/api/v1/house/details")
        XCTAssertEqual(components.queryItems, [URLQueryItem(name: "houseId", value: "house 1")])
    }

    func testStructuredAPIFailureUsesServerMessage() async throws {
        let stub = NetworkRequestStub()
        stub.statusCode = 401
        stub.responseData = Data(#"{"message":"Invalid credentials."}"#.utf8)
        let service = makeService(stub: stub)

        do {
            let _: ResponseBody = try await service.get(
                path: "auth/isAuth",
                successType: ResponseBody.self
            )
            XCTFail("Expected server error")
        } catch NetworkError.serverError(let message) {
            XCTAssertEqual(message, "Invalid credentials.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvalidSuccessPayloadUsesDecodingError() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data(#"{"unexpected":true}"#.utf8)
        let service = makeService(stub: stub)

        do {
            let _: ResponseBody = try await service.get(
                path: "health",
                successType: ResponseBody.self
            )
            XCTFail("Expected decoding error")
        } catch NetworkError.decodingError {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func makeService(stub: NetworkRequestStub) -> NetworkService {
        NetworkService(
            baseURL: URL(string: "https://example.com/api/v1")!,
            requestExecutor: stub.execute
        )
    }
}
