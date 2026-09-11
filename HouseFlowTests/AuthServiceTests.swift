import XCTest
@testable import HouseFlow

@MainActor
final class AuthServiceTests: XCTestCase {
    func testLoginStoresTokenAndEmailInInjectedKeychain() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data(#"{"token":"token-123"}"#.utf8)
        let keychain = FakeKeychainStore()
        let service = makeService(stub: stub, keychain: keychain)

        let response = try await service.login(
            email: "user@example.com",
            password: "password"
        )

        XCTAssertEqual(response.token, "token-123")
        XCTAssertEqual(keychain.authToken, "token-123")
        XCTAssertEqual(keychain.userEmail, "user@example.com")
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.url?.path, "/api/v1/auth/login")
        XCTAssertEqual(request.httpMethod, "POST")
    }

    func testAuthenticatedOperationUsesTokenFromInjectedKeychain() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data(#"{"success":true}"#.utf8)
        let keychain = FakeKeychainStore()
        keychain.authToken = "stored-token"
        let service = makeService(stub: stub, keychain: keychain)

        let response = try await service.sendEmailVerificationCode()

        XCTAssertTrue(response.success)
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer stored-token")
    }

    func testAuthenticatedOperationWithoutTokenDoesNotReachNetwork() async throws {
        let stub = NetworkRequestStub()
        let service = makeService(stub: stub, keychain: FakeKeychainStore())

        do {
            _ = try await service.isAuth()
            XCTFail("Expected missing-token error")
        } catch NetworkError.serverError(let message) {
            XCTAssertEqual(message, "No token stored.")
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        XCTAssertTrue(stub.requests.isEmpty)
    }

    private func makeService(
        stub: NetworkRequestStub,
        keychain: FakeKeychainStore
    ) -> AuthService {
        let network = NetworkService(
            baseURL: URL(string: "https://example.com/api/v1")!,
            requestExecutor: stub.execute
        )
        return AuthService(network: network, keychain: keychain)
    }
}
