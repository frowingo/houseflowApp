import XCTest
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

    private func makeHarness(hasToken: Bool) -> Harness {
        let keychain = FakeKeychainStore()
        keychain.authToken = hasToken ? "token" : nil
        let authService = FakeAuthService()
        let userService = FakeUserService()
        let authStore = AuthSessionStore(
            keychain: keychain,
            authService: authService,
            userService: userService
        )
        let houseStore = HouseSessionStore(houseService: FakeHouseService())
        let localization = TestFixture.localizationStore()
        addTeardownBlock {
            try? FileManager.default.removeItem(at: localization.directory)
        }
        let toastStore = ToastStore()
        let defaults = makeDefaults()
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
            router: router
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
}

@MainActor
private struct Harness {
    let coordinator: AppSessionCoordinator
    let keychain: FakeKeychainStore
    let authService: FakeAuthService
    let authStore: AuthSessionStore
    let router: AppRouter
}
