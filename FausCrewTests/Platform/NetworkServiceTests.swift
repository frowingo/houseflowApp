import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class NetworkServiceTests: XCTestCase {
    private struct RequestBody: Encodable {
        let email: String
        let rememberMe: Bool
    }

    nonisolated private struct ResponseBody: Decodable, Equatable, Sendable {
        let id: String
        let success: Bool
    }

    nonisolated private struct DecodeContextResponse: Decodable, Sendable {
        let resultId: String
        let decodedOnMainThread: Bool

        private enum CodingKeys: String, CodingKey {
            case resultId
        }

        init(from decoder: any Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            resultId = try container.decode(String.self, forKey: .resultId)
            decodedOnMainThread = Thread.isMainThread
        }
    }

    func testDecodingLeavesMainThreadAndPreservesDecoderConfiguration() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data(#"{"result_id":"result-1"}"#.utf8)
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let service = NetworkService(
            baseURL: URL(string: "https://example.com/api/v1")!,
            decoder: decoder,
            requestExecutor: stub.execute
        )

        let response = try await service.get(path: "health", successType: DecodeContextResponse.self)

        XCTAssertEqual(response.resultId, "result-1")
        XCTAssertFalse(response.decodedOnMainThread)
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
        var rejectedTokens: [String] = []
        service.onUnauthorized = { rejectedTokens.append($0) }

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
        XCTAssertTrue(rejectedTokens.isEmpty)
    }

    func testAuthenticatedUnauthorizedRejectsTokenOnce() async throws {
        let stub = NetworkRequestStub()
        stub.statusCode = 401
        stub.responseData = Data(#"{"message":"Session expired."}"#.utf8)
        let service = makeService(stub: stub)
        var rejectedTokens: [String] = []
        service.onUnauthorized = { rejectedTokens.append($0) }

        do {
            let _: ResponseBody = try await service.get(
                path: "auth/isAuth",
                successType: ResponseBody.self,
                token: "expired-token"
            )
            XCTFail("Expected unauthorized error")
        } catch NetworkError.unauthorized {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
        XCTAssertEqual(rejectedTokens, ["expired-token"])
        XCTAssertEqual(stub.requests.count, 1)
    }

    func testRawUnauthorizedResponseDoesNotRejectToken() async throws {
        let stub = NetworkRequestStub()
        stub.statusCode = 401
        stub.responseData = Data(#"{"message":"Provider token rejected."}"#.utf8)
        let service = makeService(stub: stub)
        var rejectedTokens: [String] = []
        service.onUnauthorized = { rejectedTokens.append($0) }

        let response = try await service.send(HTTPRequest(
            path: "auth/social",
            method: "POST",
            headers: ["Authorization": "Bearer provider-token"]
        ))

        XCTAssertEqual(response.statusCode, 401)
        XCTAssertEqual(response.body, stub.responseData)
        XCTAssertTrue(rejectedTokens.isEmpty)
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
        } catch NetworkError.decodingError(let error) {
            XCTAssertTrue(error is DecodingError)
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
