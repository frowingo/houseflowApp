import XCTest
import HouseFlowCore
@testable import HouseFlow

@MainActor
final class AppSessionCoordinatorTests: XCTestCase {
    func testAutoLoginWithoutTokenShowsAuthentication() async {
        let harness = makeHarness(hasToken: false)

        await harness.coordinator.performAutoLogin()

        XCTAssertFalse(harness.authStore.isAuthenticated)
        XCTAssertEqual(harness.router.route, .authentication)
    }

    func testAutoLoginWithVerifiedUserAndNoHouseShowsHouseSelection() async {
        let harness = makeHarness(hasToken: true)
        harness.authService.isAuthHandler = {
            IsAuthResponse(data: TestFixture.profile(houseIds: []), success: true)
        }

        await harness.coordinator.performAutoLogin()

        XCTAssertTrue(harness.authStore.isAuthenticated)
        XCTAssertEqual(harness.authStore.currentUserId, "user-1")
        XCTAssertEqual(harness.router.route, .houseSelection)
    }

    func testAutoLoginUsesCachedChosenHouseWhenItIsStillAvailable() async {
        let harness = makeHarness(hasToken: true)
        harness.defaults.set("house-2", forKey: "chosenHouse")
        harness.authService.isAuthHandler = {
            IsAuthResponse(
                data: TestFixture.profile(houseIds: ["house-1", "house-2"]),
                success: true
            )
        }
        harness.houseService.fetchDetailsHandler = { houseId in
            XCTAssertEqual(houseId, "house-2")
            return TestFixture.houseDetails(id: houseId, name: "Second House")
        }

        await harness.coordinator.performAutoLogin()

        XCTAssertEqual(harness.houseStore.currentHouseDetails?.id, "house-2")
        XCTAssertEqual(harness.defaults.string(forKey: "chosenHouse"), "house-2")
        XCTAssertEqual(harness.router.route, .dashboard)
    }

    func testAutoLoginFallsBackToFirstHouseWhenCachedChoiceIsStale() async {
        let harness = makeHarness(hasToken: true)
        harness.defaults.set("removed-house", forKey: "chosenHouse")
        harness.authService.isAuthHandler = {
            IsAuthResponse(
                data: TestFixture.profile(houseIds: ["house-1", "house-2"]),
                success: true
            )
        }
        harness.houseService.fetchDetailsHandler = { houseId in
            XCTAssertEqual(houseId, "house-1")
            return TestFixture.houseDetails(id: houseId)
        }

        await harness.coordinator.performAutoLogin()

        XCTAssertEqual(harness.houseStore.currentHouseDetails?.id, "house-1")
        XCTAssertEqual(harness.defaults.string(forKey: "chosenHouse"), "house-1")
    }

    func testAutoLoginWithUnverifiedUserRequiresEmailVerification() async {
        let harness = makeHarness(hasToken: true)
        harness.authService.isAuthHandler = {
            IsAuthResponse(
                data: TestFixture.profile(isVerified: false),
                success: true
            )
        }

        await harness.coordinator.performAutoLogin()

        XCTAssertFalse(harness.authStore.isAuthenticated)
        XCTAssertEqual(harness.keychain.pendingEmailVerification, "user@example.com")
        XCTAssertEqual(
            harness.router.route,
            .emailVerification(email: "user@example.com")
        )
    }

    func testLogoutPreventsStaleAutoLoginResponseFromRestoringSession() async {
        let harness = makeHarness(hasToken: true)
        let requestStarted = expectation(description: "Authentication request started")
        var continuation: CheckedContinuation<IsAuthResponse, Error>?

        harness.authService.isAuthHandler = {
            requestStarted.fulfill()
            return try await withCheckedThrowingContinuation { pendingContinuation in
                continuation = pendingContinuation
            }
        }

        let autoLoginTask = Task {
            await harness.coordinator.performAutoLogin()
        }
        await fulfillment(of: [requestStarted], timeout: 1)

        var didClearDomainState = false
        harness.coordinator.logout {
            didClearDomainState = true
        }
        continuation?.resume(
            returning: IsAuthResponse(
                data: TestFixture.profile(houseIds: []),
                success: true
            )
        )
        await autoLoginTask.value

        XCTAssertTrue(didClearDomainState)
        XCTAssertEqual(harness.authService.logoutCallCount, 1)
        XCTAssertFalse(harness.authStore.isAuthenticated)
        XCTAssertNil(harness.authStore.currentUserProfile)
        XCTAssertEqual(harness.router.route, .authentication)
    }

    func testCoreRestoreUsesAuthenticatedEndpointAndKeepsHouseSelectionRoute() async throws {
        let harness = makeHarness(hasToken: true, useCoreRestore: true)
        let networkStub = try XCTUnwrap(harness.networkStub)
        networkStub.responseData = coreRestorePayload(isVerified: true)
        harness.authService.isAuthHandler = {
            XCTFail("The legacy auth service should not handle startup restore")
            throw TestError.unimplemented
        }

        await harness.coordinator.performAutoLogin()

        XCTAssertTrue(harness.authStore.isAuthenticated)
        XCTAssertEqual(harness.router.route, .houseSelection)
        XCTAssertEqual(harness.authStore.currentUserId, "user-1")
        let request = try XCTUnwrap(networkStub.requests.first)
        XCTAssertEqual(networkStub.requests.count, 1)
        XCTAssertEqual(request.url?.path, "/api/v1/auth/isAuth")
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), "Bearer token")
    }

    func testCoreRestoreKeepsEmailVerificationRoute() async throws {
        let harness = makeHarness(hasToken: true, useCoreRestore: true)
        let networkStub = try XCTUnwrap(harness.networkStub)
        networkStub.responseData = coreRestorePayload(isVerified: false)

        await harness.coordinator.performAutoLogin()

        XCTAssertFalse(harness.authStore.isAuthenticated)
        XCTAssertEqual(harness.keychain.pendingEmailVerification, "user@example.com")
        XCTAssertEqual(harness.router.route, .emailVerification(email: "user@example.com"))
    }

    func testCoreRestorePreservesServerErrorAndHouseErrorRoute() async throws {
        let harness = makeHarness(hasToken: true, useCoreRestore: true)
        let networkStub = try XCTUnwrap(harness.networkStub)
        networkStub.statusCode = 401
        networkStub.responseData = Data(#"{"message":"Session expired."}"#.utf8)

        await harness.coordinator.performAutoLogin()

        XCTAssertFalse(harness.authStore.isAuthenticated)
        XCTAssertEqual(harness.router.route, .houseError)
        XCTAssertEqual(harness.toastStore.message, "Session expired.")
        XCTAssertEqual(harness.keychain.authToken, "token")
    }

    func testCoreRestoreInvalidProfileKeepsPreviousErrorMessage() async throws {
        let harness = makeHarness(hasToken: true, useCoreRestore: true)
        let networkStub = try XCTUnwrap(harness.networkStub)
        networkStub.responseData = Data(#"{"success":false}"#.utf8)

        await harness.coordinator.performAutoLogin()

        XCTAssertEqual(harness.router.route, .houseError)
        XCTAssertEqual(harness.toastStore.message, "Oturumunuz sona ermiş. Lütfen tekrar giriş yapın.")
    }

    func testCoreRestoreOfflineKeepsTokenForLaterRetry() async throws {
        let harness = makeHarness(hasToken: true, useCoreRestore: true)
        let networkStub = try XCTUnwrap(harness.networkStub)
        networkStub.error = URLError(.notConnectedToInternet)

        await harness.coordinator.performAutoLogin()

        XCTAssertEqual(harness.router.route, .houseError)
        XCTAssertFalse(harness.authStore.isAuthenticated)
        XCTAssertEqual(harness.keychain.authToken, "token")
    }

    private func makeHarness(hasToken: Bool, useCoreRestore: Bool = false) -> Harness {
        let keychain = FakeKeychainStore()
        keychain.authToken = hasToken ? "token" : nil
        let authService = FakeAuthService()
        let userService = FakeUserService()
        let networkStub = useCoreRestore ? NetworkRequestStub() : nil
        let restorer = networkStub.map { stub in
            SessionRestoreAdapter(useCase: RestoreSessionUseCase(
                httpClient: NetworkService(
                    baseURL: URL(string: "https://example.com/api/v1")!,
                    requestExecutor: stub.execute
                ),
                secureStore: keychain
            ))
        }
        let authStore = AuthSessionStore(
            keychain: keychain,
            authService: authService,
            userService: userService,
            sessionRestorer: restorer
        )
        let defaults = makeDefaults()
        let houseService = FakeHouseService()
        let houseStore = HouseSessionStore(
            houseService: houseService,
            userDefaults: defaults
        )
        let localization = TestFixture.localizationStore()
        addTeardownBlock {
            try? FileManager.default.removeItem(at: localization.directory)
        }
        let toastStore = ToastStore()
        let router = AppRouter(
            hasAuthToken: hasToken,
            pendingEmailVerification: nil,
            userDefaults: defaults,
            isAuthenticated: { authStore.isAuthenticated },
            pendingEmailVerification: { authStore.pendingEmailVerification }
        )
        let coordinator = AppSessionCoordinator(
            keychain: keychain,
            authStore: authStore,
            houseStore: houseStore,
            localizationStore: localization.store,
            toastStore: toastStore,
            router: router,
            authenticationSettleDelay: .zero
        )
        return Harness(
            coordinator: coordinator,
            keychain: keychain,
            authService: authService,
            authStore: authStore,
            houseService: houseService,
            houseStore: houseStore,
            router: router,
            defaults: defaults,
            toastStore: toastStore,
            networkStub: networkStub
        )
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "AppSessionCoordinatorTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(true, forKey: "hasSeenOnboarding")
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }

    private func coreRestorePayload(isVerified: Bool) -> Data {
        Data(
            #"{"success":true,"data":{"birthDay":"1990-01-01","createdOn":"2026-01-01","email":"user@example.com","firstName":"Ada","houseList":[],"id":"user-1","imageUrl":"","isActive":true,"isVerifyEmail":\#(isVerified),"isVerifyPhone":false,"language":"en","lastLogin":"2026-01-01","lastName":"Lovelace","phoneNumber":"","updatedOn":"2026-01-01"}}"#.utf8
        )
    }
}

@MainActor
private struct Harness {
    let coordinator: AppSessionCoordinator
    let keychain: FakeKeychainStore
    let authService: FakeAuthService
    let authStore: AuthSessionStore
    let houseService: FakeHouseService
    let houseStore: HouseSessionStore
    let router: AppRouter
    let defaults: UserDefaults
    let toastStore: ToastStore
    let networkStub: NetworkRequestStub?
}
