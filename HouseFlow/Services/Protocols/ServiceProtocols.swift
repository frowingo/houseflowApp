import Foundation

protocol KeychainStoring: AnyObject {
    var authToken: String? { get set }
    var userEmail: String? { get set }
    var userFirstName: String? { get set }
    var userLastName: String? { get set }
    var pendingEmailVerification: String? { get set }
}

protocol AuthServicing: AnyObject {
    func signup(
        email: String,
        password: String,
        firstName: String,
        lastName: String
    ) async throws -> AuthTokenResponse
    func login(email: String, password: String) async throws -> AuthTokenResponse
    func forgotPassword(email: String) async throws -> ForgotPasswordResponse
    func resetPassword(email: String, code: String, newPassword: String) async throws -> MessageResponse
    func sendEmailVerificationCode() async throws -> ValidateEmailResponse
    func validateEmail(code: String) async throws -> ValidateEmailResponse
    func isAuth() async throws -> IsAuthResponse
    func logout()
}

protocol UserServicing: AnyObject {
    func getImages(category: String) async throws -> GetImagesResponse
    func updateProfile(
        userId: String,
        request: UpdateProfileRequest
    ) async throws -> UpdateProfileResponse
}

protocol HouseServicing: AnyObject {
    func createHouse(name: String, type: Int, maxMemberCount: Int) async throws -> HouseResponse
    func fetchDetails(houseId: String) async throws -> HouseDetailsResponse
    func joinHouse(inviteCode: String) async throws -> HouseResponse
    func createAnnouncement(
        title: String,
        description: String,
        houseId: String
    ) async throws -> HouseAnnouncementDTO
}

protocol ChoreServicing: AnyObject {
    func createChore(
        assignedTo: String,
        description: String,
        dueDate: String,
        houseId: String,
        isRecurring: Bool,
        level: ChoreLevel,
        recurringInterval: Int,
        title: String
    ) async throws -> ChoreResponse
    func updateChoreStatus(
        houseId: String,
        chores: [ChoreStatusUpdateItem]
    ) async throws -> [ChoreResponse]
    func reviewChore(choreId: String, isApproved: Bool) async throws -> ChoreResponse
}

protocol LocalizationServicing: AnyObject {
    func fetchLanguages() async throws -> [LocalizationLanguage]
    func fetchPlaintexts(languagePrefix: String) async throws -> [LocalizationPlaintextItem]
}

extension KeychainService: KeychainStoring {}
extension AuthService: AuthServicing {}
extension UserService: UserServicing {}
extension HouseService: HouseServicing {}
extension ChoreService: ChoreServicing {}
extension LocalizationService: LocalizationServicing {}
