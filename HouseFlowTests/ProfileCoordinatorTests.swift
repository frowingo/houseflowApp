import XCTest
@testable import HouseFlow

@MainActor
final class ProfileCoordinatorTests: XCTestCase {
    func testSavingLanguageUpdatesProfileRefreshesLocalizationAndRequiresLogin() async throws {
        let keychain = FakeKeychainStore()
        let userService = FakeUserService()
        userService.updateProfileHandler = { _, request in
            XCTAssertEqual(request.language, "tr")
            return UpdateProfileResponse(
                data: TestFixture.userResult(language: "tr"),
                success: true,
                error: nil
            )
        }
        let authStore = AuthSessionStore(
            keychain: keychain,
            authService: FakeAuthService(),
            userService: userService
        )
        authStore.applyAuthenticatedUser(TestFixture.profile(language: "en"))

        let localizationService = FakeLocalizationService()
        localizationService.fetchPlaintextsHandler = { prefix in
            XCTAssertEqual(prefix, "tr")
            return [
                LocalizationPlaintextItem(
                    key: "language_settings_relogin_message",
                    language: "tr",
                    value: "Please log in again"
                )
            ]
        }
        let localization = TestFixture.localizationStore(service: localizationService)
        defer { try? FileManager.default.removeItem(at: localization.directory) }
        let toastStore = ToastStore()
        let coordinator = ProfileCoordinator(
            authStore: authStore,
            localizationStore: localization.store,
            toastStore: toastStore
        )
        var didRequireLogin = false

        try await coordinator.saveLanguagePreferenceAndRequireLogin(prefix: "tr") {
            didRequireLogin = true
        }

        XCTAssertEqual(userService.lastUpdatedUserId, "user-1")
        XCTAssertEqual(userService.lastUpdateRequest?.language, "tr")
        XCTAssertEqual(authStore.currentUserProfile?.language, "tr")
        XCTAssertEqual(localization.store.languagePrefix, "tr")
        XCTAssertTrue(didRequireLogin)
        XCTAssertEqual(toastStore.message, "Please log in again")
        XCTAssertFalse(toastStore.isError)
    }
}
