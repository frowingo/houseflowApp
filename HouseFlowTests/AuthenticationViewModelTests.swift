import XCTest
@testable import HouseFlow

@MainActor
final class AuthenticationViewModelTests: XCTestCase {
    func testSelectingAnotherModeClearsFormAndAuthenticationError() async {
        let authService = FakeAuthService()
        authService.loginHandler = { _, _ in throw TestError.sample }
        let harness = makeHarness(authService: authService)

        _ = await harness.authStore.login(email: "failed@example.com", password: "secret")
        harness.viewModel.firstName = "Ada"
        harness.viewModel.lastName = "Lovelace"
        harness.viewModel.email = "ada@example.com"
        harness.viewModel.password = "secret"

        harness.viewModel.selectMode(.signUp)

        XCTAssertTrue(harness.viewModel.isSignUp)
        XCTAssertEqual(harness.viewModel.firstName, "")
        XCTAssertEqual(harness.viewModel.lastName, "")
        XCTAssertEqual(harness.viewModel.email, "")
        XCTAssertEqual(harness.viewModel.password, "")
        XCTAssertNil(harness.viewModel.errorMessage)
    }

    func testSignInSubmitForwardsCurrentCredentials() async {
        var submittedEmail: String?
        var submittedPassword: String?
        let harness = makeHarness(
            loginAction: { email, password in
                submittedEmail = email
                submittedPassword = password
            }
        )
        harness.viewModel.email = "ada@example.com"
        harness.viewModel.password = "secret"

        await harness.viewModel.submit()

        XCTAssertEqual(submittedEmail, "ada@example.com")
        XCTAssertEqual(submittedPassword, "secret")
    }

    func testSignUpSubmitForwardsAllFormValues() async {
        var submittedValues: (String, String, String, String)?
        let harness = makeHarness(
            signupAction: { email, password, firstName, lastName in
                submittedValues = (email, password, firstName, lastName)
                return true
            }
        )
        harness.viewModel.selectMode(.signUp)
        harness.viewModel.firstName = "Ada"
        harness.viewModel.lastName = "Lovelace"
        harness.viewModel.email = "ada@example.com"
        harness.viewModel.password = "secret"

        await harness.viewModel.submit()

        XCTAssertEqual(submittedValues?.0, "ada@example.com")
        XCTAssertEqual(submittedValues?.1, "secret")
        XCTAssertEqual(submittedValues?.2, "Ada")
        XCTAssertEqual(submittedValues?.3, "Lovelace")
    }

    func testInvalidFormDoesNotSubmit() async {
        var loginCallCount = 0
        let harness = makeHarness(
            loginAction: { _, _ in loginCallCount += 1 }
        )
        harness.viewModel.email = "ada@example.com"

        await harness.viewModel.submit()

        XCTAssertEqual(loginCallCount, 0)
        XCTAssertFalse(harness.viewModel.isFormValid)
    }

    private func makeHarness(
        authService: FakeAuthService? = nil,
        loginAction: @escaping AuthenticationViewModel.LoginAction = { _, _ in },
        signupAction: @escaping AuthenticationViewModel.SignupAction = { _, _, _, _ in false }
    ) -> Harness {
        let keychain = FakeKeychainStore()
        let resolvedAuthService = authService ?? FakeAuthService()
        let authStore = AuthSessionStore(
            keychain: keychain,
            authService: resolvedAuthService,
            userService: FakeUserService()
        )
        let localization = TestFixture.localizationStore()
        addTeardownBlock {
            try? FileManager.default.removeItem(at: localization.directory)
        }
        let viewModel = AuthenticationViewModel(
            authStore: authStore,
            localizationStore: localization.store,
            loginAction: loginAction,
            signupAction: signupAction
        )
        return Harness(viewModel: viewModel, authStore: authStore)
    }
}

@MainActor
private struct Harness {
    let viewModel: AuthenticationViewModel
    let authStore: AuthSessionStore
}
