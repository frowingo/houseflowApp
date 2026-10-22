import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
private final class FakeCredentials: SocialCredentialProviding {
    var result: Result<SocialCredential, Error> = .success(SocialCredential(idToken: "id"))
    private(set) var signOutCount = 0
    private(set) var authenticated: [SocialProvider] = []

    func credential(for provider: SocialProvider) async throws -> SocialCredential { try result.get() }
    func signOutAll() { signOutCount += 1 }
    func didAuthenticate(provider: SocialProvider) { authenticated.append(provider) }
}

@MainActor
private final class FakeSocialService: SocialAuthServicing {
    var signInResult: Result<SocialSignInOutcome, Error> = .success(.signedIn(token: "t", isNewUser: true))
    var linkResult: Result<[SocialProvider], Error> = .success([.apple])
    var sessionValid: Bool? = true
    private(set) var deleted = false

    func signIn(provider: SocialProvider, credential: SocialCredential) async throws -> SocialSignInOutcome { try signInResult.get() }
    func requestEmailCode(pendingToken: String, email: String) async throws {}
    func complete(_ request: SocialCompleteRequest) async throws -> (token: String, isNewUser: Bool) { ("t", true) }
    func link(provider: SocialProvider, credential: SocialCredential) async throws -> [SocialProvider] { try linkResult.get() }
    func unlink(provider: SocialProvider) async throws -> [SocialProvider] { [] }
    func deleteAccount() async throws { deleted = true }
    func isSessionValid() async -> Bool? { sessionValid }
}

@MainActor
final class SocialAuthTests: XCTestCase {
    // MARK: Service

    func testSignInStoresOurJWTAndSendsLanguageHeader() async throws {
        let stub = NetworkRequestStub()
        stub.statusCode = 201
        stub.responseData = Data(#"{"token":"jwt","isNewUser":true}"#.utf8)
        let keychain = FakeKeychainStore()
        let service = makeService(stub, keychain)

        let outcome = try await service.signIn(provider: .apple, credential: SocialCredential(idToken: "apple-id", nonce: "raw"))

        XCTAssertEqual(outcome, .signedIn(token: "jwt", isNewUser: true))
        XCTAssertEqual(keychain.authToken, "jwt")
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.url?.path, "/api/v1/auth/social/apple")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Accept-Language"), "tr")
    }

    func testNeedsEmailLeavesNoTokenBehind() async throws {
        let stub = NetworkRequestStub()
        stub.responseData = Data(#"{"isNewUser":false,"needsEmail":true,"pendingToken":"p"}"#.utf8)
        let keychain = FakeKeychainStore()
        let outcome = try await makeService(stub, keychain).signIn(provider: .snapchat, credential: SocialCredential(accessToken: "a"))
        XCTAssertEqual(outcome, .needsEmail(pendingToken: "p"))
        XCTAssertNil(keychain.authToken)
    }

    func testConflictSurfacesStatusAndMessage() async {
        let stub = NetworkRequestStub()
        stub.statusCode = 409
        stub.responseData = Data(#"{"success":false,"error":"Kayıtlı"}"#.utf8)
        do {
            _ = try await makeService(stub, FakeKeychainStore()).signIn(provider: .google, credential: SocialCredential(idToken: "x"))
            XCTFail("expected failure")
        } catch {
            XCTAssertEqual(error as? SocialAuthError, SocialAuthError(statusCode: 409, message: "Kayıtlı"))
        }
    }

    func testDeleteAccountAcceptsEmpty204() async throws {
        let stub = NetworkRequestStub()
        stub.statusCode = 204
        let keychain = FakeKeychainStore()
        keychain.authToken = "jwt"
        try await makeService(stub, keychain).deleteAccount()
        let request = try XCTUnwrap(stub.requests.first)
        XCTAssertEqual(request.httpMethod, "DELETE")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer jwt")
    }

    // MARK: Store

    func testStoreKeepsPendingTokenInMemoryOnNeedsEmail() async {
        let h = makeStore()
        h.service.signInResult = .success(.needsEmail(pendingToken: "p"))
        let result = await h.store.socialSignIn(.apple)
        XCTAssertEqual(result, .needsEmail)
        XCTAssertEqual(h.store.socialPending?.pendingToken, "p")
    }

    func testCancelledProviderSheetIsSilent() async {
        let h = makeStore()
        h.credentials.result = .failure(SocialSignInError.cancelled)
        let result = await h.store.socialSignIn(.apple)
        XCTAssertEqual(result, .cancelled)
        XCTAssertNil(h.store.authError)
    }

    func testUnauthorizedSignInClosesProviderSession() async {
        let h = makeStore()
        h.service.signInResult = .failure(SocialAuthError(statusCode: 401, message: "expired"))
        let result = await h.store.socialSignIn(.apple)
        XCTAssertEqual(result, .failed)
        XCTAssertEqual(h.store.authError, "expired")
        XCTAssertEqual(h.credentials.signOutCount, 1)
    }

    func testDisabledProviderNeverReachesTheSDK() async {
        let h = makeStore(enabled: [])
        let result = await h.store.socialSignIn(.google)
        XCTAssertEqual(result, .failed)
        XCTAssertNotNil(h.store.authError)
    }

    func testShownButUnconfiguredProviderExplainsInsteadOfOpeningTheSDK() async {
        let service = FakeSocialService()
        let credentials = FakeCredentials()
        credentials.result = .failure(TestError.sample)
        let store = AuthSessionStore(
            keychain: FakeKeychainStore(), authService: FakeAuthService(), userService: FakeUserService(),
            socialAuthService: service, socialCredentials: credentials,
            socialConfig: SocialAuthConfig(shownProviders: [.google, .facebook], configuredProviders: [.google])
        )
        XCTAssertEqual(store.shownSocialProviders, [.google, .facebook])
        let result = await store.socialSignIn(.facebook)
        XCTAssertEqual(result, .notConfigured)
        XCTAssertNotNil(store.authInfo)
        XCTAssertNil(store.authError)
        XCTAssertFalse(store.isLoading)
        do {
            _ = try await store.linkSocialProvider(.facebook)
            XCTFail("expected an explanation")
        } catch {
            XCTAssertTrue(error.isInfo)
        }
    }

    func testLinkUnauthorizedChecksSessionBeforeSigningOut() async throws {
        let h = makeStore()
        h.service.linkResult = .failure(SocialAuthError(statusCode: 401, message: "x"))
        h.service.sessionValid = true
        do {
            _ = try await h.store.linkSocialProvider(.apple)
            XCTFail("expected provider-token error")
        } catch {
            XCTAssertEqual(error.statusCode, 401)
        }
        h.service.sessionValid = false
        let stillSignedIn = try await h.store.linkSocialProvider(.apple)
        XCTAssertFalse(stillSignedIn)
    }

    func testDeleteAccountWipesSessionAndProviderSDKs() async throws {
        let h = makeStore()
        try await h.store.deleteAccount()
        XCTAssertTrue(h.service.deleted)
        XCTAssertEqual(h.auth.logoutCallCount, 1)
        XCTAssertGreaterThanOrEqual(h.credentials.signOutCount, 1)
    }

    // MARK: Apple

    func testAppleNonceHashIsLowercaseHexSHA256() {
        XCTAssertEqual(
            AppleCredentialProvider.sha256Hex("abc"),
            "ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad"
        )
        XCTAssertEqual(try AppleCredentialProvider.randomNonce().count, 32)
        XCTAssertNotEqual(try AppleCredentialProvider.randomNonce(), try AppleCredentialProvider.randomNonce())
    }

    // MARK: Helpers

    private func makeService(_ stub: NetworkRequestStub, _ keychain: FakeKeychainStore) -> SocialAuthService {
        let network = NetworkService(baseURL: URL(string: "https://example.com/api/v1")!, requestExecutor: stub.execute)
        return SocialAuthService(http: network, keychain: keychain, language: { "tr" })
    }

    private func makeStore(enabled: [SocialProvider] = [.apple, .google]) -> (
        store: AuthSessionStore, service: FakeSocialService, credentials: FakeCredentials, auth: FakeAuthService
    ) {
        let service = FakeSocialService()
        let credentials = FakeCredentials()
        let auth = FakeAuthService()
        let store = AuthSessionStore(
            keychain: FakeKeychainStore(),
            authService: auth,
            userService: FakeUserService(),
            socialAuthService: service,
            socialCredentials: credentials,
            socialConfig: SocialAuthConfig(enabledProviders: enabled)
        )
        return (store, service, credentials, auth)
    }
}
