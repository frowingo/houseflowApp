import Foundation
import Combine
import HouseFlowCore

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

    typealias SocialSignInAction = (_ provider: SocialProvider) async -> SocialSignInResult

    @Published private(set) var mode: Mode = .signIn
    @Published var firstName = ""
    @Published var lastName = ""
    @Published var email = ""
    @Published var password = ""
    @Published var isForgotPasswordPresented = false
    @Published var isSocialEmailPresented = false

    private let authStore: AuthSessionStore
    private let localizationStore: LocalizationStore
    private let loginAction: LoginAction
    private let signupAction: SignupAction
    private let socialSignInAction: SocialSignInAction?
    private var cancellables = Set<AnyCancellable>()

    init(
        authStore: AuthSessionStore,
        localizationStore: LocalizationStore,
        loginAction: @escaping LoginAction,
        signupAction: @escaping SignupAction,
        socialSignInAction: SocialSignInAction? = nil
    ) {
        self.socialSignInAction = socialSignInAction
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

    /// Buttons to show, in display order: every listed provider, configured or not.
    var socialProviders: [SocialProvider] {
        let order: [SocialProvider] = [.google, .apple, .facebook, .snapchat]
        return order.filter { authStore.shownSocialProviders.contains($0) }
    }

    var infoMessage: String? {
        authStore.authInfo
    }

    func signInWithSocial(_ provider: SocialProvider) async {
        guard !isLoading, let socialSignInAction else { return }
        if await socialSignInAction(provider) == .needsEmail {
            isSocialEmailPresented = true
        }
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
