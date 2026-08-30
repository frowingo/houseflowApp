import XCTest
@testable import HouseFlow

@MainActor
final class AppRouterTests: XCTestCase {
    func testInitialRoutePrioritizesStoredToken() async {
        let defaults = makeDefaults(hasSeenOnboarding: false)

        let router = AppRouter(
            hasAuthToken: true,
            pendingEmailVerification: "pending@example.com",
            userDefaults: defaults,
            isAuthenticated: { false },
            pendingEmailVerification: { "pending@example.com" }
        )

        XCTAssertEqual(router.route, .houseLoading(.checkingAuth))
    }

    func testInitialRouteShowsOnboardingBeforePendingVerification() async {
        let defaults = makeDefaults(hasSeenOnboarding: false)

        let router = AppRouter(
            hasAuthToken: false,
            pendingEmailVerification: "pending@example.com",
            userDefaults: defaults,
            isAuthenticated: { false },
            pendingEmailVerification: { "pending@example.com" }
        )

        XCTAssertEqual(router.route, .onboarding)
    }

    func testInitialRouteShowsPendingVerificationAfterOnboarding() async {
        let defaults = makeDefaults(hasSeenOnboarding: true)

        let router = AppRouter(
            hasAuthToken: false,
            pendingEmailVerification: "pending@example.com",
            userDefaults: defaults,
            isAuthenticated: { false },
            pendingEmailVerification: { "pending@example.com" }
        )

        XCTAssertEqual(router.route, .emailVerification(email: "pending@example.com"))
    }

    func testProtectedRouteRedirectsUnauthenticatedUser() async {
        let defaults = makeDefaults(hasSeenOnboarding: true)
        let router = AppRouter(
            hasAuthToken: false,
            pendingEmailVerification: nil,
            userDefaults: defaults,
            isAuthenticated: { false },
            pendingEmailVerification: { nil }
        )

        router.navigate(to: .dashboard)

        XCTAssertEqual(router.route, .authentication)
    }

    func testProtectedRouteAllowsAuthenticatedUser() async {
        let defaults = makeDefaults(hasSeenOnboarding: true)
        let router = AppRouter(
            hasAuthToken: false,
            pendingEmailVerification: nil,
            userDefaults: defaults,
            isAuthenticated: { true },
            pendingEmailVerification: { nil }
        )

        router.navigate(to: .dashboard)

        XCTAssertEqual(router.route, .dashboard)
    }

    func testNonOnboardingLoadingRouteCanBeForced() async {
        let defaults = makeDefaults(hasSeenOnboarding: false)
        let router = AppRouter(
            hasAuthToken: false,
            pendingEmailVerification: nil,
            userDefaults: defaults,
            isAuthenticated: { false },
            pendingEmailVerification: { nil }
        )

        router.navigate(to: .houseLoading(.loadingUser), respectingOnboarding: false)

        XCTAssertEqual(router.route, .houseLoading(.loadingUser))
    }

    func testCompletingOnboardingPreservesPendingVerificationPriority() async {
        let defaults = makeDefaults(hasSeenOnboarding: false)
        let router = AppRouter(
            hasAuthToken: false,
            pendingEmailVerification: nil,
            userDefaults: defaults,
            isAuthenticated: { false },
            pendingEmailVerification: { "pending@example.com" }
        )

        router.completeOnboarding(needsBirthdaySetup: true)

        XCTAssertTrue(defaults.bool(forKey: "hasSeenOnboarding"))
        XCTAssertEqual(router.route, .emailVerification(email: "pending@example.com"))
    }

    private func makeDefaults(hasSeenOnboarding: Bool) -> UserDefaults {
        let suiteName = "AppRouterTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defaults.set(hasSeenOnboarding, forKey: "hasSeenOnboarding")
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
