import Foundation

@MainActor
final class ProfileCoordinator {
    private let authStore: AuthSessionStore
    private let localizationStore: LocalizationStore
    private let toastStore: ToastStore

    init(
        authStore: AuthSessionStore,
        localizationStore: LocalizationStore,
        toastStore: ToastStore
    ) {
        self.authStore = authStore
        self.localizationStore = localizationStore
        self.toastStore = toastStore
    }

    var currentLanguagePrefix: String? {
        authStore.currentUserProfile?.language ?? localizationStore.languagePrefix
    }

    func updateProfile(_ request: UpdateProfileRequest) async throws {
        let profile = try await authStore.updateProfile(request)
        authStore.applyAuthenticatedUser(profile)
    }

    func fetchProfileImages(category: String) async throws -> GetImagesResponse {
        try await authStore.fetchProfileImages(category: category)
    }

    func updateLocalizationLanguage(prefix: String) async throws {
        let request = UpdateProfileRequest(
            imageUrl: nil,
            birthDay: nil,
            firstName: nil,
            lastName: nil,
            phoneNumber: nil,
            language: prefix
        )
        try await updateProfile(request)
        try await localizationStore.refreshLanguagePrefix(prefix)
    }

    func saveLanguagePreferenceAndRequireLogin(
        prefix: String,
        onRequireLogin: () -> Void
    ) async throws {
        try await updateLocalizationLanguage(prefix: prefix)
        onRequireLogin()
        toastStore.show(
            message: localizationStore.value(for: "language_settings_relogin_message"),
            isError: false
        )
    }
}
