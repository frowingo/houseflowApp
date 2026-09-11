import Foundation
import Combine

@MainActor
final class AuthenticationViewModel: ObservableObject {
    enum Mode: Equatable {
        case signIn
        case signUp
    }

    typealias LoginAction = (_ email: String, _ password: String) async -> Void
    typealias SignupAction = (
        _ email: String,
        _ password: String,
        _ firstName: String,
        _ lastName: String
    ) async -> Bool

    @Published private(set) var mode: Mode = .signIn
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var isForgotPasswordPresented = false

    private let authStore: AuthSessionStore
    private let localizationStore: LocalizationStore
    private let loginAction: LoginAction
    private let signupAction: SignupAction
    private var cancellables = Set<AnyCancellable>()

    init(
        authStore: AuthSessionStore,
        localizationStore: LocalizationStore,
        loginAction: @escaping LoginAction,
        signupAction: @escaping SignupAction
    ) {
        self.authStore = authStore
        self.localizationStore = localizationStore
        self.loginAction = loginAction
        self.signupAction = signupAction
        bindDependencies()
    }

    var isSignUp: Bool {
        mode == .signUp
    }

    var isLoading: Bool {
        authStore.isLoading
    }

    var errorMessage: String? {
        authStore.authError
    }

    var successMessage: String? {
        authStore.successToast
    }

    var isFormValid: Bool {
        if isSignUp {
            return !firstName.isEmpty
                && !lastName.isEmpty
                && !email.isEmpty
                && !password.isEmpty
        }
        return !email.isEmpty && !password.isEmpty
    }

    func localized(_ key: String) -> String {
        localizationStore.value(for: key)
    }

    func selectMode(_ newMode: Mode) {
        guard mode != newMode else { return }
        mode = newMode
        clearForm()
        authStore.clearFeedback()
    }

    func presentForgotPassword() {
        isForgotPasswordPresented = true
    }

    func submit() async {
        guard isFormValid, !isLoading else { return }

        if isSignUp {
            _ = await signupAction(email, password, firstName, lastName)
        } else {
            await loginAction(email, password)
        }
    }

    func beginSocialAuthentication(_ platform: String) {
        // The social providers are presentation-ready but do not have an
        // authentication use case yet. Keeping this boundary here prevents the
        // view from acquiring another application-wide dependency later.
    }

    private func clearForm() {
        firstName = ""
        lastName = ""
        email = ""
        password = ""
    }

    private func bindDependencies() {
        authStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)

        localizationStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &cancellables)
    }
}
