#if DEBUG
import Foundation
import FausCrewCore

/// Inert dependencies for `#Preview`s: nothing touches the network, the real Keychain or
/// the standard `UserDefaults`. Previews that need data set it on the view model directly.
extension AppDependencies {
    static var preview: AppDependencies {
        let services = PreviewServices()
        let suite = "FausCrewPreview"
        let defaults = UserDefaults(suiteName: suite) ?? .standard
        defaults.removePersistentDomain(forName: suite)
        return AppDependencies(
            keychain: PreviewKeychain(),
            authService: services,
            sessionRestorer: nil,
            userService: services,
            houseService: services,
            choreService: services,
            localizationService: services,
            userDefaults: defaults,
            localizationCache: LocalizationDiskCache(
                baseDirectory: FileManager.default.temporaryDirectory.appendingPathComponent(suite)
            ),
            houseRocketsSessionFactory: .localOnly
        )
    }
}

extension AppViewModel {
    static var preview: AppViewModel { AppViewModel(dependencies: .preview) }
}

private final class PreviewKeychain: KeychainStoring {
    var authToken: String?
    var userEmail: String?
    var userFirstName: String?
    var userLastName: String?
    var pendingEmailVerification: String?
}

private struct PreviewServiceError: Error {}

/// Every request fails; the language list is empty so previews fall back to built-in copy.
private final class PreviewServices: AuthServicing, UserServicing, HouseServicing, ChoreServicing,
                                      LocalizationServicing {
    func signup(email: String, password: String, firstName: String, lastName: String) async throws -> AuthTokenResponse {
        throw PreviewServiceError()
    }

    func login(email: String, password: String) async throws -> AuthTokenResponse { throw PreviewServiceError() }

    func forgotPassword(email: String) async throws -> ForgotPasswordResponse { throw PreviewServiceError() }

    func resetPassword(email: String, code: String, newPassword: String) async throws -> MessageResponse {
        throw PreviewServiceError()
    }

    func sendEmailVerificationCode() async throws -> ValidateEmailResponse { throw PreviewServiceError() }

    func validateEmail(code: String) async throws -> ValidateEmailResponse { throw PreviewServiceError() }

    func isAuth() async throws -> IsAuthResponse { throw PreviewServiceError() }

    func logout() {}

    func getImages(category: String) async throws -> GetImagesResponse { throw PreviewServiceError() }

    func updateProfile(userId: String, request: UpdateProfileRequest) async throws -> UpdateProfileResponse {
        throw PreviewServiceError()
    }

    func createHouse(name: String, type: Int, maxMemberCount: Int) async throws -> HouseResponse {
        throw PreviewServiceError()
    }

    func fetchDetails(houseId: String) async throws -> HouseDetailsResponse { throw PreviewServiceError() }

    func fetchInfo(houseId: String) async throws -> HouseInfoData { throw PreviewServiceError() }

    func updateProfile(houseId: String, request: UpdateHouseProfileRequest) async throws -> HouseInfoData {
        throw PreviewServiceError()
    }

    func createInviteCode(houseId: String) async throws -> HouseInviteCodeData { throw PreviewServiceError() }

    func removeMember(houseId: String, userId: String) async throws { throw PreviewServiceError() }

    func joinHouse(inviteCode: String) async throws -> HouseResponse { throw PreviewServiceError() }

    func createAnnouncement(title: String, description: String, houseId: String) async throws -> HouseAnnouncementDTO {
        throw PreviewServiceError()
    }

    func createChore(
        assignedTo: String, description: String, dueDate: String, houseId: String, isRecurring: Bool,
        level: ChoreLevel, recurringInterval: Int, title: String, category: ChoreCategoryKind
    ) async throws -> ChoreResponse {
        throw PreviewServiceError()
    }

    func updateChoreStatus(houseId: String, chores: [ChoreStatusUpdateItem]) async throws -> [ChoreResponse] {
        throw PreviewServiceError()
    }

    func updateChoreStatusWithReviewPhoto(
        houseId: String, choreId: String, photo: ChoreReviewPhotoUpload
    ) async throws -> [ChoreResponse] {
        throw PreviewServiceError()
    }

    func reviewChore(choreId: String, isApproved: Bool) async throws -> ChoreResponse { throw PreviewServiceError() }

    func fetchReviewPhotoURL(choreId: String, round: Int) async throws -> ChoreReviewPhotoURLResponse {
        throw PreviewServiceError()
    }

    func downloadReviewPhoto(from url: URL) async throws -> Data { throw PreviewServiceError() }

    func fetchLanguages() async throws -> [LocalizationLanguage] { [] }

    func fetchPlaintexts(languagePrefix: String) async throws -> [LocalizationPlaintextItem] { [] }
}
#endif
