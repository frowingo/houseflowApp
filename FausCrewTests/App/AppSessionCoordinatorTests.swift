import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class AppSessionCoordinatorTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        let previousLanguage = APILanguage.code
        APILanguage.update(prefix: "en")
        addTeardownBlock {
            await MainActor.run {
                APILanguage.update(prefix: previousLanguage)
            }
        }
    }

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

    func testCoreRestoreWithRejectedTokenShowsAuthenticationAndClearsToken() async throws {
        let harness = makeHarness(hasToken: true, useCoreRestore: true)
        let networkStub = try XCTUnwrap(harness.networkStub)
        networkStub.statusCode = 401
        networkStub.responseData = Data(#"{"message":"Session expired."}"#.utf8)

        await harness.coordinator.performAutoLogin()

        XCTAssertEqual(harness.router.route, .authentication)
        XCTAssertNil(harness.keychain.authToken)
        XCTAssertFalse(harness.authStore.isAuthenticated)
        XCTAssertNil(harness.toastStore.message)
        XCTAssertEqual(harness.authService.logoutCallCount, 1)
    }

    func testCoreRestoreUnauthorizedWithoutMessageStillSignsOut() async throws {
        let harness = makeHarness(hasToken: true, useCoreRestore: true)
        let networkStub = try XCTUnwrap(harness.networkStub)
        networkStub.statusCode = 401
        networkStub.responseData = Data()

        await harness.coordinator.performAutoLogin()

        XCTAssertEqual(harness.router.route, .authentication)
        XCTAssertNil(harness.keychain.authToken)
        XCTAssertFalse(harness.authStore.isAuthenticated)
        XCTAssertNil(harness.toastStore.message)
    }

    func testCoreRestorePreservesServerErrorAndHouseErrorRoute() async throws {
        let harness = makeHarness(hasToken: true, useCoreRestore: true)
        let networkStub = try XCTUnwrap(harness.networkStub)
        networkStub.statusCode = 500
        networkStub.responseData = Data(#"{"message":"Service unavailable."}"#.utf8)

        await harness.coordinator.performAutoLogin()

        XCTAssertFalse(harness.authStore.isAuthenticated)
        XCTAssertEqual(harness.router.route, .houseError)
        XCTAssertEqual(harness.toastStore.message, "Service unavailable.")
        XCTAssertEqual(harness.keychain.authToken, "token")
        XCTAssertEqual(harness.authService.logoutCallCount, 0)
    }

    func testRejectedStoredTokenSignsOut() async {
        let harness = makeHarness(hasToken: true)
        harness.authService.isAuthHandler = {
            IsAuthResponse(data: TestFixture.profile(houseIds: []), success: true)
        }
        await harness.coordinator.performAutoLogin()
        XCTAssertTrue(harness.authStore.isAuthenticated)

        harness.coordinator.handleRejectedToken("token")

        XCTAssertEqual(harness.router.route, .authentication)
        XCTAssertNil(harness.keychain.authToken)
        XCTAssertFalse(harness.authStore.isAuthenticated)
        XCTAssertNil(harness.authStore.currentUserProfile)
        XCTAssertEqual(harness.authService.logoutCallCount, 1)
    }

    func testRejectedOldTokenDoesNotSignOutCurrentSession() async {
        let harness = makeHarness(hasToken: true)
        harness.keychain.authToken = "new-token"
        harness.authService.isAuthHandler = {
            IsAuthResponse(data: TestFixture.profile(houseIds: []), success: true)
        }
        await harness.coordinator.performAutoLogin()

        harness.coordinator.handleRejectedToken("token")

        XCTAssertEqual(harness.keychain.authToken, "new-token")
        XCTAssertTrue(harness.authStore.isAuthenticated)
        XCTAssertEqual(harness.router.route, .houseSelection)
        XCTAssertEqual(harness.authService.logoutCallCount, 0)
    }

    func testRejectedTokenWithoutStoredTokenDoesNothing() {
        let harness = makeHarness(hasToken: false)
        var rejectionCount = 0
        harness.coordinator.onSessionRejected = { rejectionCount += 1 }

        harness.coordinator.handleRejectedToken("token")

        XCTAssertEqual(rejectionCount, 0)
        XCTAssertEqual(harness.authService.logoutCallCount, 0)
        XCTAssertEqual(harness.router.route, .authentication)
    }

    func testAppViewModelDecodedUnauthorizedClearsDomainStateWithoutAppEvents() async {
        let keychain = FakeKeychainStore()
        keychain.authToken = "token"
        let stub = NetworkRequestStub()
        stub.statusCode = 401
        let network = NetworkService(
            baseURL: URL(string: "https://example.com/api/v1")!,
            requestExecutor: stub.execute
        )
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("SessionRejectionTests-\(UUID().uuidString)")
        addTeardownBlock {
            try? FileManager.default.removeItem(at: directory)
        }
        let model = AppViewModel(dependencies: AppDependencies(
            keychain: keychain,
            authService: AuthService(network: network, keychain: keychain),
            sessionRestorer: nil,
            userService: FakeUserService(),
            houseService: FakeHouseService(),
            choreService: FakeChoreService(),
            localizationService: FakeLocalizationService(),
            userDefaults: makeDefaults(),
            localizationCache: LocalizationDiskCache(baseDirectory: directory),
            houseRocketsSessionFactory: .localOnly,
            network: network
        ))
        model.currentHouse = TestFixture.houseResponse()

        await model.performAutoLogin()

        XCTAssertEqual(stub.requests.count, 1)
        XCTAssertEqual(model.router.route, .authentication)
        XCTAssertNil(keychain.authToken)
        XCTAssertFalse(model.isAuthenticated)
        XCTAssertNil(model.currentHouse)
        XCTAssertNil(model.toastMessage)
    }

    func testRemovedHouseUnauthorizedKeepsAuthenticationRoute() async {
        let harness = makeHarness(hasToken: true)
        let profile = TestFixture.profile(houseIds: ["house-2"])
        harness.authStore.applyAuthenticatedUser(profile)
        harness.authStore.isAuthenticated = true
        harness.houseStore.applyHouseDetails(TestFixture.houseDetails(id: "removed-house"))
        harness.authService.isAuthHandler = { IsAuthResponse(data: profile, success: true) }
        harness.houseService.fetchDetailsHandler = { [weak coordinator = harness.coordinator] _ in
            coordinator?.handleRejectedToken("token")
            throw NetworkError.unauthorized
        }

        await harness.coordinator.refreshForAppEvent(profile: true, houseID: nil)

        XCTAssertEqual(harness.router.route, .authentication)
        XCTAssertNil(harness.keychain.authToken)
        XCTAssertFalse(harness.authStore.isAuthenticated)
        XCTAssertNil(harness.toastStore.message)
        XCTAssertEqual(harness.authService.logoutCallCount, 1)
    }

    func testRemovedHouseLateSuccessDoesNotReplaceNewSessionRoute() async {
        let harness = makeHarness(hasToken: true)
        let profile = TestFixture.profile(houseIds: ["house-2"])
        harness.authStore.applyAuthenticatedUser(profile)
        harness.authStore.isAuthenticated = true
        harness.houseStore.applyHouseDetails(TestFixture.houseDetails(id: "removed-house"))
        harness.authService.isAuthHandler = { IsAuthResponse(data: profile, success: true) }
        harness.houseService.fetchDetailsHandler = {
            [weak coordinator = harness.coordinator, weak authStore = harness.authStore,
             weak keychain = harness.keychain, weak router = harness.router] houseID in
            coordinator?.logout {}
            keychain?.authToken = "new-token"
            authStore?.applyAuthenticatedUser(TestFixture.profile(id: "user-2"))
            authStore?.isAuthenticated = true
            router?.navigate(to: .dashboard)
            return TestFixture.houseDetails(id: houseID)
        }

        await harness.coordinator.refreshForAppEvent(profile: true, houseID: nil)

        XCTAssertEqual(harness.router.route, .dashboard)
        XCTAssertEqual(harness.keychain.authToken, "new-token")
        XCTAssertEqual(harness.authStore.currentUserId, "user-2")
        XCTAssertNil(harness.houseStore.currentHouseDetails)
        XCTAssertTrue(harness.authStore.isAuthenticated)
        XCTAssertNil(harness.toastStore.message)
    }

    func testCoreRestoreInvalidProfileShowsSessionExpiredFallback() async throws {
        let harness = makeHarness(hasToken: true, useCoreRestore: true)
        let networkStub = try XCTUnwrap(harness.networkStub)
        networkStub.responseData = Data(#"{"success":false}"#.utf8)

        await harness.coordinator.performAutoLogin()

        XCTAssertEqual(harness.router.route, .houseError)
        XCTAssertEqual(harness.toastStore.message, "Your session has expired. Please sign in again.")
    }

    func testCoreRestoreInvalidProfileShowsTurkishSessionExpiredFallback() async throws {
        let harness = makeHarness(hasToken: true, useCoreRestore: true)
        let networkStub = try XCTUnwrap(harness.networkStub)
        networkStub.responseData = Data(#"{"success":false}"#.utf8)
        APILanguage.update(prefix: "tr")

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
        XCTAssertEqual(harness.toastStore.message, "Unable to connect. Please check your internet connection.")
    }

    func testAppEventRefreshIsIgnoredWhenNotAuthenticated() async {
        let harness = makeHarness(hasToken: true)
        harness.houseStore.applyHouseDetails(TestFixture.houseDetails(id: "house-1"))
        var requestCount = 0
        harness.authService.isAuthHandler = {
            requestCount += 1
            throw TestError.unimplemented
        }
        harness.houseService.fetchDetailsHandler = { _ in
            requestCount += 1
            throw TestError.unimplemented
        }

        await harness.coordinator.refreshForAppEvent(profile: true, houseID: "house-1")

        XCTAssertEqual(requestCount, 0)
        XCTAssertEqual(harness.houseStore.currentHouseDetails?.id, "house-1")
    }

    func testAppEventWithoutProfileRefreshForcesSelectedHouseRefreshPastCooldown() async throws {
        let harness = makeHarness(hasToken: true)
        authenticate(harness)
        var houseName = "Old Name"
        var profileRequestCount = 0
        harness.authService.isAuthHandler = {
            profileRequestCount += 1
            throw TestError.unimplemented
        }
        harness.houseService.fetchDetailsHandler = { houseId in
            TestFixture.houseDetails(id: houseId, name: houseName)
        }
        let cached = try await harness.houseStore.loadHouseDetails(houseId: "house-1")
        harness.houseStore.applyHouseDetails(cached)
        houseName = "New Name"

        await harness.coordinator.refreshForAppEvent(profile: false, houseID: "house-1")

        XCTAssertEqual(profileRequestCount, 0)
        XCTAssertEqual(harness.houseStore.currentHouseDetails?.name, "New Name")
        XCTAssertEqual(harness.houseStore.houseName, "New Name")
    }

    func testAppEventForAnotherHouseDoesNotRefreshTheSelectedHouse() async {
        let harness = makeHarness(hasToken: true)
        authenticate(harness)
        var fetchedHouseIds: [String] = []
        harness.houseService.fetchDetailsHandler = { houseId in
            fetchedHouseIds.append(houseId)
            return TestFixture.houseDetails(id: houseId, name: "Other")
        }

        await harness.coordinator.refreshForAppEvent(profile: false, houseID: "house-2")

        XCTAssertTrue(fetchedHouseIds.isEmpty)
        XCTAssertEqual(harness.houseStore.currentHouseDetails?.name, "Test House")
    }

    func testAppEventProfileRefreshStoresProfileAndRefreshesStillSelectedHouse() async {
        let harness = makeHarness(hasToken: true)
        authenticate(harness)
        let profile = TestFixture.profile(houseIds: ["house-1", "house-2"])
        harness.authService.isAuthHandler = { IsAuthResponse(data: profile, success: true) }
        harness.houseService.fetchDetailsHandler = { houseId in
            TestFixture.houseDetails(id: houseId, name: "Refreshed")
        }

        await harness.coordinator.refreshForAppEvent(profile: true, houseID: "house-1")

        XCTAssertEqual(harness.authStore.currentUserProfile?.houseList.map(\.houseId), ["house-1", "house-2"])
        XCTAssertEqual(harness.houseStore.currentHouseDetails?.name, "Refreshed")
    }

    func testAppEventProfileFetchFailureChangesNothing() async {
        let harness = makeHarness(hasToken: true)
        authenticate(harness)
        var houseRequestCount = 0
        harness.authService.isAuthHandler = { throw URLError(.notConnectedToInternet) }
        harness.houseService.fetchDetailsHandler = { _ in
            houseRequestCount += 1
            throw TestError.unimplemented
        }

        await harness.coordinator.refreshForAppEvent(profile: true, houseID: "house-1")

        XCTAssertEqual(houseRequestCount, 0)
        XCTAssertTrue(harness.authStore.isAuthenticated)
        XCTAssertEqual(harness.authStore.currentUserProfile?.houseList.map(\.houseId), ["house-1"])
        XCTAssertEqual(harness.router.route, .houseLoading(.checkingAuth))
        XCTAssertNil(harness.toastStore.message)
    }

    func testAppEventProfileFromSupersededFlowIsDiscarded() async {
        let harness = makeHarness(hasToken: true)
        authenticate(harness)
        var houseRequestCount = 0
        harness.authService.isAuthHandler = { [weak coordinator = harness.coordinator] in
            coordinator?.invalidateAuthenticationFlows()
            return IsAuthResponse(
                data: TestFixture.profile(id: "user-2", houseIds: ["house-1"]),
                success: true
            )
        }
        harness.houseService.fetchDetailsHandler = { _ in
            houseRequestCount += 1
            throw TestError.unimplemented
        }

        await harness.coordinator.refreshForAppEvent(profile: true, houseID: "house-1")

        XCTAssertEqual(harness.authStore.currentUserId, "user-1")
        XCTAssertEqual(houseRequestCount, 0)
    }

    func testAppEventRemovalFromSelectedHouseSwitchesToRemainingHouse() async {
        let harness = makeHarness(hasToken: true)
        authenticate(harness, selectedHouseId: "removed-house")
        harness.defaults.set("removed-house", forKey: "chosenHouse")
        let profile = TestFixture.profile(houseIds: ["house-2"])
        harness.authService.isAuthHandler = { IsAuthResponse(data: profile, success: true) }
        harness.houseService.fetchDetailsHandler = { houseId in
            XCTAssertEqual(houseId, "house-2")
            return TestFixture.houseDetails(id: houseId, name: "Second")
        }

        await harness.coordinator.refreshForAppEvent(profile: true, houseID: "removed-house")

        XCTAssertEqual(harness.houseStore.currentHouseDetails?.id, "house-2")
        XCTAssertEqual(harness.houseStore.houseName, "House house-2")
        XCTAssertEqual(harness.defaults.string(forKey: "chosenHouse"), "house-2")
        XCTAssertEqual(harness.router.route, .dashboard)
    }

    func testAppEventRemovalFromLastHouseClearsSelectionAndShowsHouseSelection() async {
        let harness = makeHarness(hasToken: true)
        authenticate(harness, selectedHouseId: "removed-house")
        harness.defaults.set("removed-house", forKey: "chosenHouse")
        let profile = TestFixture.profile(houseIds: [])
        harness.authService.isAuthHandler = { IsAuthResponse(data: profile, success: true) }
        var houseRequestCount = 0
        harness.houseService.fetchDetailsHandler = { _ in
            houseRequestCount += 1
            throw TestError.unimplemented
        }

        await harness.coordinator.refreshForAppEvent(profile: true, houseID: "removed-house")

        XCTAssertNil(harness.houseStore.currentHouseDetails)
        XCTAssertNil(harness.defaults.string(forKey: "chosenHouse"))
        XCTAssertEqual(houseRequestCount, 0)
        XCTAssertTrue(harness.authStore.isAuthenticated)
        XCTAssertEqual(harness.router.route, .houseSelection)
    }

    func testAppEventRemovalWithFailingReloadShowsHouseError() async {
        let harness = makeHarness(hasToken: true)
        authenticate(harness, selectedHouseId: "removed-house")
        let profile = TestFixture.profile(houseIds: ["house-2"])
        harness.authService.isAuthHandler = { IsAuthResponse(data: profile, success: true) }
        harness.houseService.fetchDetailsHandler = { _ in
            throw NetworkError.serverError("House unavailable.")
        }

        await harness.coordinator.refreshForAppEvent(profile: true, houseID: nil)

        XCTAssertNil(harness.houseStore.currentHouseDetails)
        XCTAssertFalse(harness.authStore.isAuthenticated)
        XCTAssertEqual(harness.toastStore.message, "House unavailable.")
        XCTAssertEqual(harness.router.route, .houseError)
    }

    private func authenticate(
        _ harness: Harness,
        houseIds: [String] = ["house-1"],
        selectedHouseId: String = "house-1"
    ) {
        harness.authStore.applyAuthenticatedUser(TestFixture.profile(houseIds: houseIds))
        harness.authStore.isAuthenticated = true
        harness.houseStore.applyHouseDetails(TestFixture.houseDetails(id: selectedHouseId))
    }

    private func makeHarness(hasToken: Bool, useCoreRestore: Bool = false) -> Harness {
        let keychain = FakeKeychainStore()
        keychain.authToken = hasToken ? "token" : nil
        let authService = FakeAuthService()
        authService.logoutHandler = { [weak keychain] in
            keychain?.authToken = nil
        }
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
        coordinator.onSessionRejected = { [weak coordinator] in
            coordinator?.logout {}
        }
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
