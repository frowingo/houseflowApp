import Foundation
import XCTest
@testable import HouseFlowCore

@MainActor
final class RestoreSessionUseCaseTests: XCTestCase {
    func testRestoreUsesStoredTokenAndReturnsProfile() async throws {
        let store = FakeSessionStore(token: "stored-token")
        let client = FakeSessionHTTPClient(response: response(body: AuthUserFixtures.authenticatedUser))
        let useCase = RestoreSessionUseCase(httpClient: client, secureStore: store)

        let profile = try await useCase.restore()

        XCTAssertEqual(profile.id, "user-1")
        XCTAssertEqual(profile.fullName, "Ada Lovelace")
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests.first?.path, "auth/isAuth")
        XCTAssertEqual(client.requests.first?.method, "GET")
        XCTAssertEqual(client.requests.first?.headers["Authorization"], "Bearer stored-token")
        XCTAssertNil(client.requests.first?.body)
    }

    func testMissingTokenNeverCallsHTTP() async {
        let store = FakeSessionStore(token: nil)
        let client = FakeSessionHTTPClient(response: response(body: AuthUserFixtures.authenticatedUser))
        let useCase = RestoreSessionUseCase(httpClient: client, secureStore: store)

        do {
            _ = try await useCase.restore()
            XCTFail("Expected missing token")
        } catch SessionRestoreError.missingToken {
            XCTAssertTrue(client.requests.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testUnauthorizedPreservesServerMessageAndStatus() async {
        let client = FakeSessionHTTPClient(response: response(
            status: 401,
            body: Data(#"{"message":"Session expired."}"#.utf8)
        ))
        let useCase = RestoreSessionUseCase(httpClient: client, secureStore: FakeSessionStore(token: "expired"))

        do {
            _ = try await useCase.restore()
            XCTFail("Expected HTTP failure")
        } catch let failure as HTTPStatusFailure {
            XCTAssertEqual(failure.statusCode, 401)
            XCTAssertEqual(failure.message, "Session expired.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testOfflineErrorPassesThroughWithoutMutatingToken() async {
        let store = FakeSessionStore(token: "stored-token")
        let client = FakeSessionHTTPClient(response: response(body: Data()))
        client.error = URLError(.notConnectedToInternet)
        let useCase = RestoreSessionUseCase(httpClient: client, secureStore: store)

        do {
            _ = try await useCase.restore()
            XCTFail("Expected network failure")
        } catch let error as URLError {
            XCTAssertEqual(error.code, .notConnectedToInternet)
            XCTAssertEqual(store.authToken, "stored-token")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testInvalidProfileAndMalformedPayloadAreDistinct() async {
        let client = FakeSessionHTTPClient(response: response(body: Data(#"{"success":false}"#.utf8)))
        let useCase = RestoreSessionUseCase(httpClient: client, secureStore: FakeSessionStore(token: "token"))

        do {
            _ = try await useCase.restore()
            XCTFail("Expected invalid profile")
        } catch SessionRestoreError.invalidProfile {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        client.response = response(body: AuthUserFixtures.malformedAuthenticatedUser)
        do {
            _ = try await useCase.restore()
            XCTFail("Expected decoding failure")
        } catch is DecodingError {
            // Expected.
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testRepeatedRestoreMakesFreshRequest() async throws {
        let client = FakeSessionHTTPClient(response: response(body: AuthUserFixtures.authenticatedUser))
        let useCase = RestoreSessionUseCase(httpClient: client, secureStore: FakeSessionStore(token: "token"))

        _ = try await useCase.restore()
        _ = try await useCase.restore()

        XCTAssertEqual(client.requests.count, 2)
    }

    func testCancelledRestoreDoesNotCallHTTP() async {
        let client = FakeSessionHTTPClient(response: response(body: AuthUserFixtures.authenticatedUser))
        let useCase = RestoreSessionUseCase(httpClient: client, secureStore: FakeSessionStore(token: "token"))

        let task = Task {
            withUnsafeCurrentTask { $0?.cancel() }
            return try await useCase.restore()
        }

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertTrue(client.requests.isEmpty)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testCancellationAfterHTTPStartsDiscardsLateProfile() async {
        let started = expectation(description: "Restore request started")
        var pendingResponse: CheckedContinuation<HTTPResponse, Never>?
        let client = FakeSessionHTTPClient(response: response(body: Data()))
        client.handler = { _ in
            await withCheckedContinuation { continuation in
                pendingResponse = continuation
                started.fulfill()
            }
        }
        let useCase = RestoreSessionUseCase(httpClient: client, secureStore: FakeSessionStore(token: "token"))

        let task = Task { try await useCase.restore() }
        await fulfillment(of: [started], timeout: 1)
        task.cancel()
        pendingResponse?.resume(returning: response(body: AuthUserFixtures.authenticatedUser))

        do {
            _ = try await task.value
            XCTFail("Expected cancellation")
        } catch is CancellationError {
            XCTAssertEqual(client.requests.count, 1)
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    private func response(status: Int = 200, body: Data) -> HTTPResponse {
        HTTPResponse(statusCode: status, headers: [:], body: body)
    }
}

@MainActor
private final class FakeSessionHTTPClient: HTTPClient {
    var response: HTTPResponse
    var error: Error?
    var handler: ((HTTPRequest) async throws -> HTTPResponse)?
    private(set) var requests: [HTTPRequest] = []

    init(response: HTTPResponse) { self.response = response }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        if let error { throw error }
        if let handler { return try await handler(request) }
        return response
    }
}

@MainActor
private final class FakeSessionStore: SecureSessionStore {
    var authToken: String?
    var userEmail: String?
    var userFirstName: String?
    var userLastName: String?
    var pendingEmailVerification: String?

    init(token: String?) { authToken = token }
}
