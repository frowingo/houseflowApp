import Foundation
import Combine

@MainActor
class AppViewModel: ObservableObject {
    private let authStore: AuthSessionStore
    private let toastStore: ToastStore
    private let overlayStore: OverlayStore
    private let houseStore: HouseSessionStore
    private let dashboardStore: DashboardStore
    private let choreStore: ChoreStore
    private let localizationStore: LocalizationStore
    let router: AppRouter
    let authenticationViewModel: AuthenticationViewModel
    private let sessionCoordinator: AppSessionCoordinator
    private let houseFlowCoordinator: HouseFlowCoordinator
    private let dashboardCoordinator: DashboardCoordinator
    private let profileCoordinator: ProfileCoordinator
    private var storeCancellables = Set<AnyCancellable>()

    var signupSuccessMessage: String? { sessionCoordinator.signupSuccessMessage }

    /// The server-assigned ID of the logged-in user (used to gate chore status edits).
    var currentUserId: String? { authStore.currentUserId }

    /// Full server profile of the logged-in user (used for profile display & edit).
    var currentUserProfile: IsAuthUserData? { authStore.currentUserProfile }

    var dashboardMembers: [User] { dashboardCoordinator.members }
    var dashboardChores: [Chore] { dashboardCoordinator.dashboardChores }
    var currentLanguagePrefix: String? { profileCoordinator.currentLanguagePrefix }
    var localizationLanguages: [LocalizationLanguage] { localizationStore.availableLanguages }
    var isLoadingLocalizationLanguages: Bool { localizationStore.isLoadingLanguages }

    var chores: [Chore] {
        get { dashboardCoordinator.chores }
        set { dashboardCoordinator.chores = newValue }
    }

    var isAuthenticated: Bool {
        get { authStore.isAuthenticated }
        set { authStore.isAuthenticated = newValue }
    }

    var currentUser: User? {
        get { authStore.currentUser }
        set { authStore.currentUser = newValue }
    }

    var currentHouse: HouseResponse? {
        get { houseStore.currentHouse }
        set { houseStore.currentHouse = newValue }
    }

    var currentHouseDetails: HouseDetailsResponse? {
        houseStore.currentHouseDetails
    }

    var houseName: String {
        houseStore.houseName
    }

    var houseIsLoading: Bool {
        get { houseStore.houseIsLoading }
        set { houseStore.houseIsLoading = newValue }
    }

    var houseError: String? {
        get { houseStore.houseError }
        set { houseStore.houseError = newValue }
    }

    var toastMessage: String? { toastStore.message }
    var toastIsError: Bool { toastStore.isError }

    /// Set to true whenever a modal / popup is covering the screen so the tab bar hides.
    var isOverlayPresented: Bool {
        get { overlayStore.isPresented }
        set { overlayStore.isPresented = newValue }
    }

    var sampleUsers: [User] { dashboardCoordinator.sampleUsers }
    var sampleChores: [Chore] { dashboardCoordinator.sampleChores }

    convenience init() {
        self.init(dependencies: .live())
    }

    convenience init(dependencies: AppDependencies) {
        self.init(
            keychain: dependencies.keychain,
            authStore: AuthSessionStore(
                keychain: dependencies.keychain,
                authService: dependencies.authService,
                userService: dependencies.userService
            ),
            toastStore: ToastStore(),
            overlayStore: OverlayStore(),
            houseStore: HouseSessionStore(houseService: dependencies.houseService),
            dashboardStore: DashboardStore(),
            choreStore: ChoreStore(choreService: dependencies.choreService),
            localizationStore: LocalizationStore(
                service: dependencies.localizationService,
                cache: dependencies.localizationCache
            ),
            userDefaults: dependencies.userDefaults
        )
    }

    init(
        keychain: any KeychainStoring,
        authStore: AuthSessionStore,
        toastStore: ToastStore,
        overlayStore: OverlayStore,
        houseStore: HouseSessionStore,
        dashboardStore: DashboardStore,
        choreStore: ChoreStore,
        localizationStore: LocalizationStore,
        userDefaults: UserDefaults
    ) {
        self.authStore = authStore
        self.toastStore = toastStore
        self.overlayStore = overlayStore
        self.houseStore = houseStore
        self.dashboardStore = dashboardStore
        self.choreStore = choreStore
        self.localizationStore = localizationStore

        let router = AppRouter(
            hasAuthToken: keychain.authToken != nil,
            pendingEmailVerification: keychain.pendingEmailVerification,
            userDefaults: userDefaults,
            isAuthenticated: { authStore.isAuthenticated },
            pendingEmailVerification: { authStore.pendingEmailVerification }
        )
        self.router = router
        let sessionCoordinator = AppSessionCoordinator(
            keychain: keychain,
            authStore: authStore,
            houseStore: houseStore,
            localizationStore: localizationStore,
            toastStore: toastStore,
            router: router
        )
        self.sessionCoordinator = sessionCoordinator
        authenticationViewModel = AuthenticationViewModel(
            authStore: authStore,
            localizationStore: localizationStore,
            loginAction: { email, password in
                await sessionCoordinator.login(email: email, password: password)
            },
            signupAction: { email, password, firstName, lastName in
                await sessionCoordinator.signup(
                    email: email,
                    password: password,
                    firstName: firstName,
                    lastName: lastName
                )
            }
        )
        houseFlowCoordinator = HouseFlowCoordinator(
            authStore: authStore,
            houseStore: houseStore,
            toastStore: toastStore,
            router: router
        )
        dashboardCoordinator = DashboardCoordinator(
            authStore: authStore,
            houseStore: houseStore,
            dashboardStore: dashboardStore,
            choreStore: choreStore,
            localizationStore: localizationStore,
            toastStore: toastStore
        )
        profileCoordinator = ProfileCoordinator(
            authStore: authStore,
            localizationStore: localizationStore,
            toastStore: toastStore
        )

        bindStoreChanges()
    }

    private func bindStoreChanges() {
        sessionCoordinator.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &storeCancellables)

        authStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &storeCancellables)

        authStore.$currentUserProfile
            .dropFirst()
            .sink { [weak self] profile in
                if let language = profile?.language {
                    self?.localizationStore.applyPreferredLanguage(language)
                }
            }
            .store(in: &storeCancellables)

        toastStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &storeCancellables)

        overlayStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &storeCancellables)

        houseStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &storeCancellables)

        dashboardStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &storeCancellables)

        choreStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &storeCancellables)

        localizationStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &storeCancellables)
    }

    var weeklyLeader: User {
        dashboardCoordinator.weeklyLeader
    }
    
    func completeOnboarding() {
        sessionCoordinator.completeOnboarding()
    }

    // MARK: - Scene Phase Handlers

    /// Call when the app moves to the background.
    func handleBackground() {
        sessionCoordinator.handleBackground()
    }

    /// Call when the app returns to the foreground.
    /// Only triggers the auth/data refresh if the app was backgrounded long enough.
    /// Cold-start auth is handled separately by `performAutoLogin()` via `.task`.
    func handleForeground() async {
        await sessionCoordinator.handleForeground()
    }

    // MARK: - Localization

    func prepareLocalization() {
        localizationStore.start()
    }

    func localized(_ key: String) -> String {
        localizationStore.value(for: key)
    }

    func localized(_ key: String, fallback: String) -> String {
        localizationStore.value(for: key, fallback: fallback)
    }

    func localized(_ key: String, replacements: [String: String]) -> String {
        localizationStore.value(for: key, replacements: replacements)
    }

    func localizedDueLabel(_ label: String) -> String {
        switch label {
        case "Today":
            return localized("common_today")
        case "Overdue":
            return localized("common_overdue")
        case "This week":
            return localized("common_this_week")
        case "Upcoming":
            return localized("common_upcoming")
        case "—":
            return localized("common_empty_value")
        default:
            return label
        }
    }

    func loadLocalizationLanguages() async throws {
        try await localizationStore.loadAvailableLanguages(force: true)
    }

    func setLocalizationLanguage(prefix: String) {
        localizationStore.setLanguagePrefix(prefix)
    }

    func updateLocalizationLanguage(prefix: String) async throws {
        try await profileCoordinator.updateLocalizationLanguage(prefix: prefix)
    }

    func saveLanguagePreferenceAndRequireLogin(prefix: String) async throws {
        try await profileCoordinator.saveLanguagePreferenceAndRequireLogin(
            prefix: prefix,
            onRequireLogin: logout
        )
    }

    // MARK: - Auto Login

    /// Called on app foreground. If a valid token is stored, silently authenticates
    /// and navigates straight to the dashboard. No-op if already authenticated.
    func performAutoLogin() async {
        await sessionCoordinator.performAutoLogin()
    }

    // MARK: - Authentication Support Flows

    func clearSignupSuccessMessage() {
        sessionCoordinator.clearSignupSuccessMessage()
    }

    func requestPasswordReset(email: String) async throws {
        try await sessionCoordinator.requestPasswordReset(email: email)
    }

    func resetPasswordOrThrow(email: String, code: String, newPassword: String) async throws {
        try await sessionCoordinator.resetPasswordOrThrow(
            email: email,
            code: code,
            newPassword: newPassword
        )
    }

    func sendEmailVerificationCode() async throws {
        try await sessionCoordinator.sendEmailVerificationCode()
    }

    func validateEmail(code: String) async throws {
        try await sessionCoordinator.validateEmail(code: code)
    }

    func showCreateHouseScreen() {
        houseFlowCoordinator.showCreateHouseScreen()
    }
    
    func backToHouseSelection() {
        houseFlowCoordinator.backToHouseSelection()
    }
    
    func showJoinHouseScreen() {
        houseFlowCoordinator.showJoinHouseScreen()
    }

    // MARK: - User Profile Update

    func updateProfile(_ request: UpdateProfileRequest) async throws {
        try await profileCoordinator.updateProfile(request)
    }

    func fetchProfileImages(category: String) async throws -> GetImagesResponse {
        try await profileCoordinator.fetchProfileImages(category: category)
    }

    func completeBirthdaySetup(with birthDate: Date) async throws {
        try await sessionCoordinator.completeBirthdaySetup(with: birthDate)
    }

    // MARK: - House API (Full Flow)

    /// Full create-house flow: shows loading screen → POST → GET details → dashboard.
    /// On any error, navigates back to CreateHouseView and shows a toast.
    func beginCreateHouseFlow(name: String, type: Int, maxMemberCount: Int) async {
        await houseFlowCoordinator.beginCreateHouseFlow(
            name: name,
            type: type,
            maxMemberCount: maxMemberCount
        )
    }

    /// Full join-house flow: shows loading screen → POST → GET details → dashboard.
    /// On any error, navigates back to JoinHouseView and shows a toast.
    func beginJoinHouseFlow(inviteCode: String) async {
        await houseFlowCoordinator.beginJoinHouseFlow(inviteCode: inviteCode)
    }

    // MARK: - Toast

    func showToast(message: String, isError: Bool = true) {
        toastStore.show(message: message, isError: isError)
    }

    func logout() {
        sessionCoordinator.logout { [houseFlowCoordinator, dashboardCoordinator] in
            houseFlowCoordinator.resetSession()
            dashboardCoordinator.clearSession()
        }
    }

    func cancelEmailVerification() {
        logout()
    }

    // MARK: - Announcement API

    @discardableResult
    func createAnnouncement(title: String, description: String) async -> Bool {
        await dashboardCoordinator.createAnnouncement(title: title, description: description)
    }

    // MARK: - Chore API

    /// Creates a chore via the API, then merges the returned chore into dashboard state.
    func createChore(
        assignedToId: String,
        description: String,
        dueDate: Date,
        houseId: String,
        isRecurring: Bool,
        level: ChoreLevel,
        recurringInterval: Int,
        title: String
    ) async {
        await dashboardCoordinator.createChore(
            assignedToId: assignedToId,
            description: description,
            dueDate: dueDate,
            houseId: houseId,
            isRecurring: isRecurring,
            level: level,
            recurringInterval: recurringInterval,
            title: title
        )
    }

    /// Updates the status of a single chore via the API, then merges the returned chore.
    func updateChoreStatus(choreApiId: String, houseId: String, status: ChoreStatus) async -> Bool {
        await dashboardCoordinator.updateChoreStatus(
            choreApiId: choreApiId,
            houseId: houseId,
            status: status
        )
    }

    /// Submits the current user's vote for an in-review chore.
    func reviewChore(choreApiId: String, isApproved: Bool) async -> Bool {
        await dashboardCoordinator.reviewChore(
            choreApiId: choreApiId,
            isApproved: isApproved
        )
    }

}
