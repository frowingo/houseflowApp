import Foundation
import Combine

enum NavigationDirection {
    case forward, backward
}

enum HouseLoadingPhase: Equatable {
    case creating
    case joining
    case loadingDetails
    case checkingAuth
    case loadingUser
    case loadingHouse

    var titleKey: String {
        switch self {
        case .creating:       return "house_loading_creating_title"
        case .joining:        return "house_loading_joining_title"
        case .loadingDetails: return "house_loading_details_title"
        case .checkingAuth:   return "house_loading_auth_title"
        case .loadingUser:    return "house_loading_user_title"
        case .loadingHouse:   return "house_loading_house_title"
        }
    }

    var subtitleKey: String {
        switch self {
        case .creating:       return "house_loading_creating_subtitle"
        case .joining:        return "house_loading_joining_subtitle"
        case .loadingDetails: return "house_loading_details_subtitle"
        case .checkingAuth:   return "house_loading_auth_subtitle"
        case .loadingUser:    return "house_loading_user_subtitle"
        case .loadingHouse:   return "house_loading_house_subtitle"
        }
    }
}

@MainActor
class AppViewModel: ObservableObject {
    @Published var navigationDirection: NavigationDirection = .forward
    @Published private(set) var showBirthdaySetup = false
    @Published private(set) var signupSuccessMessage: String?

    private let keychain = KeychainService.shared
    private let authStore = AuthSessionStore()
    private let toastStore = ToastStore()
    private let overlayStore = OverlayStore()
    private let houseStore = HouseSessionStore(isInitializing: KeychainService.shared.authToken != nil)
    private let dashboardStore = DashboardStore()
    private let choreStore = ChoreStore()
    private let localizationStore = LocalizationStore()
    private var storeCancellables = Set<AnyCancellable>()

    /// The server-assigned ID of the logged-in user (used to gate chore status edits).
    var currentUserId: String? { authStore.currentUserId }

    /// Full server profile of the logged-in user (used for profile display & edit).
    var currentUserProfile: IsAuthUserData? { authStore.currentUserProfile }

    var dashboardMembers: [User] { dashboardStore.members }
    var dashboardChores: [Chore] { dashboardStore.chores }
    var currentLanguagePrefix: String? {
        currentUserProfile?.language ?? localizationStore.languagePrefix
    }
    var localizationLanguages: [LocalizationLanguage] { localizationStore.availableLanguages }
    var isLoadingLocalizationLanguages: Bool { localizationStore.isLoadingLanguages }

    var chores: [Chore] {
        get { choreStore.chores }
        set {
            choreStore.setChores(newValue)
            if currentHouseDetails == nil {
                setDashboardChores(newValue)
            }
        }
    }

    var isAuthenticated: Bool {
        get { authStore.isAuthenticated }
        set { authStore.isAuthenticated = newValue }
    }

    var showAuth: Bool {
        get { authStore.showAuth }
        set { authStore.showAuth = newValue }
    }

    var currentUser: User? {
        get { authStore.currentUser }
        set { authStore.currentUser = newValue }
    }

    var isLoading: Bool {
        get { authStore.isLoading }
        set { authStore.isLoading = newValue }
    }

    var authError: String? {
        get { authStore.authError }
        set { authStore.authError = newValue }
    }

    var successToast: String? {
        get { authStore.successToast }
        set { authStore.successToast = newValue }
    }

    var pendingEmailVerification: String? {
        authStore.pendingEmailVerification
    }

    var hasSelectedHouse: Bool {
        get { houseStore.hasSelectedHouse }
        set { houseStore.hasSelectedHouse = newValue }
    }

    var showCreateHouse: Bool {
        get { houseStore.showCreateHouse }
        set { houseStore.showCreateHouse = newValue }
    }

    var showJoinHouse: Bool {
        get { houseStore.showJoinHouse }
        set { houseStore.showJoinHouse = newValue }
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

    var isInitializing: Bool {
        get { houseStore.isInitializing }
        set { houseStore.isInitializing = newValue }
    }

    var showHouseLoading: Bool {
        get { houseStore.showHouseLoading }
        set { houseStore.showHouseLoading = newValue }
    }

    var houseLoadingPhase: HouseLoadingPhase {
        get { houseStore.houseLoadingPhase }
        set { houseStore.houseLoadingPhase = newValue }
    }

    var showHouseError: Bool {
        get { houseStore.showHouseError }
        set { houseStore.showHouseError = newValue }
    }

    var toastMessage: String? { toastStore.message }
    var toastIsError: Bool { toastStore.isError }

    /// Set to true whenever a modal / popup is covering the screen so the tab bar hides.
    var isOverlayPresented: Bool {
        get { overlayStore.isPresented }
        set { overlayStore.isPresented = newValue }
    }

    // MARK: - Background Session Tracking
    /// Timestamp of when the app last entered the background.
    private var backgroundedAt: Date? = nil
    /// How long the app must be in the background before re-running the auth check on foreground.
    private let backgroundRefreshThreshold: TimeInterval = 15 * 60 // 15 minutes
    
    // Sample data for demo
    var sampleUsers: [User] {
        [
            User(
                firstName: localized("demo_user_mahmut_first_name"),
                lastName: localized("demo_user_mahmut_last_name"),
                points: 12
            ),
            User(
                firstName: localized("demo_user_jane_first_name"),
                lastName: localized("demo_user_jane_last_name"),
                points: 8
            ),
            User(
                firstName: localized("demo_user_abdullatif_first_name"),
                lastName: localized("demo_user_abdullatif_last_name"),
                points: 10
            ),
            User(
                firstName: localized("demo_user_katya_first_name"),
                lastName: localized("demo_user_katya_last_name"),
                points: 6
            )
        ]
    }
    
    var sampleChores: [Chore] {
        [
            Chore(id: "sample-take-trash", title: localized("demo_chore_take_trash_title"), description: localized("demo_chore_take_trash_description"), assignedTo: sampleUsers[0], dueLabel: "Today"),
            Chore(id: "sample-kitchen-counter", title: localized("demo_chore_kitchen_counter_title"), description: localized("demo_chore_kitchen_counter_description"), assignedTo: sampleUsers[1], dueLabel: "Today"),
            Chore(id: "sample-vacuum-living-room", title: localized("demo_chore_vacuum_living_room_title"), description: localized("demo_chore_vacuum_living_room_description"), assignedTo: sampleUsers[2], dueLabel: "Overdue"),
            Chore(id: "sample-clean-bathroom", title: localized("demo_chore_clean_bathroom_title"), description: localized("demo_chore_clean_bathroom_description"), assignedTo: sampleUsers[3], dueLabel: "This week"),
            Chore(id: "sample-laundry", title: localized("demo_chore_laundry_title"), description: localized("demo_chore_laundry_description"), assignedTo: sampleUsers[0], dueLabel: "Today", isDone: true)
        ]
    }

    init() {
        bindStoreChanges()
        rebuildDashboardCache()
    }

    private func bindStoreChanges() {
        authStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &storeCancellables)

        authStore.$currentUserProfile
            .dropFirst()
            .sink { [weak self] profile in
                guard let self else { return }
                if let language = profile?.language {
                    self.localizationStore.applyPreferredLanguage(language)
                }
                self.rebuildDashboardCache(details: self.currentHouseDetails, currentUserProfile: profile)
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

        houseStore.$currentHouseDetails
            .dropFirst()
            .sink { [weak self] details in
                guard let self else { return }
                self.rebuildDashboardCache(details: details, currentUserProfile: self.currentUserProfile)
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

        choreStore.$chores
            .dropFirst()
            .sink { [weak self] chores in
                guard let self, self.currentHouseDetails == nil else { return }
                self.setDashboardChores(chores)
            }
            .store(in: &storeCancellables)

        localizationStore.objectWillChange
            .sink { [weak self] _ in
                guard let self else { return }
                if self.currentHouseDetails == nil {
                    self.rebuildDashboardCache()
                }
                self.objectWillChange.send()
            }
            .store(in: &storeCancellables)
    }

    private func setCurrentHouseDetails(_ details: HouseDetailsResponse?) {
        houseStore.setCurrentHouseDetails(details)
    }

    private func setDashboardChores(_ mappedChores: [Chore]) {
        dashboardStore.setChores(mappedChores)
    }

    var weeklyLeader: User {
        sampleUsers.max(by: { $0.points < $1.points }) ?? sampleUsers[0]
    }
    
    func showAuthScreen() {
        navigationDirection = .forward
        showAuth = true
    }

    // MARK: - Scene Phase Handlers

    /// Call when the app moves to the background.
    func handleBackground() {
        backgroundedAt = Date()
    }

    /// Call when the app returns to the foreground.
    /// Only triggers the auth/data refresh if the app was backgrounded long enough.
    /// Cold-start auth is handled separately by `performAutoLogin()` via `.task`.
    func handleForeground() async {
        localizationStore.refreshIfNeeded()

        guard let backgroundedAt else {
            // No recorded background time means this is part of the cold-start sequence;
            // `performAutoLogin()` via .task already handles that case.
            return
        }
        let elapsed = Date().timeIntervalSince(backgroundedAt)
        self.backgroundedAt = nil
        if elapsed >= backgroundRefreshThreshold {
            await performAutoLogin()
        }
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

    func saveLanguagePreferenceAndRequireLogin(prefix: String) async throws {
        try await updateLocalizationLanguage(prefix: prefix)
        logout()
        showToast(message: localized("language_settings_relogin_message"), isError: false)
    }

    // MARK: - Auto Login

    /// Called on app foreground. If a valid token is stored, silently authenticates
    /// and navigates straight to the dashboard. No-op if already authenticated.
    func performAutoLogin() async {
        // Fast-path: no token in keychain → nothing to verify, go straight to auth.
        guard keychain.authToken != nil else {
            isInitializing = false
            return
        }
        guard pendingEmailVerification == nil else {
            isInitializing = false
            showHouseLoading = false
            return
        }
        // Already in an authenticated session → nothing to do.
        guard !isAuthenticated else {
            isInitializing = false
            return
        }

        houseLoadingPhase = .checkingAuth
        navigationDirection = .forward
        showHouseLoading = true
        showHouseError = false
        isInitializing = false

        do {
            houseLoadingPhase = .loadingUser
            let profile = try await authStore.resolveAuthenticatedUser(
                invalidMessage: "Oturumunuz sona ermiş. Lütfen tekrar giriş yapın."
            )
            guard profile.isVerifyEmail else {
                authStore.requireEmailVerification(for: profile.email)
                isAuthenticated = false
                showAuth = false
                showHouseLoading = false
                return
            }
            if needsBirthdaySetup(profile) {
                showBirthdaySetup = true
                isAuthenticated = false
                showAuth = false
                showHouseLoading = false
                return
            }
            showBirthdaySetup = false
            if let language = profile.language {
                localizationStore.applyPreferredLanguage(language)
            } else {
                localizationStore.loadLanguagesAndApplyDefault(force: localizationLanguages.isEmpty)
            }
            isAuthenticated = true
            _ = try await houseStore.loadFirstHouseIfPresent(for: profile)
        } catch {
            isAuthenticated = false
            showAuth = true
            showHouseLoading = false
            showToast(message: errorMessage(from: error), isError: true)
            showHouseError = true
        }
    }

    // MARK: - Real Auth (API)

    func login(email: String, password: String) async {
        if await authStore.login(email: email, password: password) {
            didAuthenticate()
        }
    }

    @discardableResult
    func signup(email: String, password: String, firstName: String, lastName: String) async -> Bool {
        navigationDirection = .forward
        signupSuccessMessage = nil
        let didSignup = await authStore.signup(
            email: email,
            password: password,
            firstName: firstName,
            lastName: lastName
        )
        if didSignup {
            signupSuccessMessage = localized(
                "signup_success_message",
                fallback: "Your account was created successfully. Verify your email to continue."
            )
        }
        return didSignup
    }

    func clearSignupSuccessMessage() {
        signupSuccessMessage = nil
    }

    func forgotPassword(email: String) async -> Bool {
        await authStore.forgotPassword(email: email)
    }

    func resetPassword(email: String, code: String, newPassword: String) async -> Bool {
        await authStore.resetPassword(email: email, code: code, newPassword: newPassword)
    }

    func sendEmailVerificationCode() async throws {
        try await authStore.sendEmailVerificationCode()
    }

    func validateEmail(code: String) async throws {
        try await authStore.validateEmail(code: code)
        let profile = try await authStore.resolveAuthenticatedUser()
        guard profile.isVerifyEmail else {
            throw NetworkError.serverError("The email address could not be verified.")
        }

        navigationDirection = .forward
        showAuth = false
        showHouseError = false
        showHouseLoading = false
        isAuthenticated = false
        showBirthdaySetup = true
        authStore.clearPendingEmailVerification()
    }

    private func didAuthenticate() {
        Task { await didAuthenticateAsync() }
    }

    private func didAuthenticateAsync() async {
        navigationDirection = .forward
        showAuth = false
        showHouseError = false
        houseLoadingPhase = .loadingUser
        showHouseLoading = true

        do {
            setCurrentHouseDetails(nil)
            let profile = try await authStore.resolveAuthenticatedUser()
            guard profile.isVerifyEmail else {
                authStore.requireEmailVerification(for: profile.email)
                isAuthenticated = false
                showAuth = false
                showHouseLoading = false
                return
            }
            if needsBirthdaySetup(profile) {
                showBirthdaySetup = true
                isAuthenticated = false
                showAuth = false
                showHouseLoading = false
                return
            }
            showBirthdaySetup = false
            if let language = profile.language {
                localizationStore.applyPreferredLanguage(language)
            } else {
                localizationStore.loadLanguagesAndApplyDefault(force: localizationLanguages.isEmpty)
            }
            isAuthenticated = true
            _ = try await houseStore.loadFirstHouseIfPresent(for: profile)
        } catch {
            isAuthenticated = false
            showToast(message: errorMessage(from: error), isError: true)
            showHouseLoading = false
            showHouseError = true
        }
    }

    func showCreateHouseScreen() {
        navigationDirection = .forward
        showCreateHouse = true
    }
    
    func backToHouseSelection() {
        navigationDirection = .backward
        showCreateHouse = false
        showJoinHouse = false
    }
    
    func showJoinHouseScreen() {
        navigationDirection = .forward
        showJoinHouse = true
    }

    // MARK: - User Profile Update

    func updateProfile(_ request: UpdateProfileRequest) async throws {
        try await authStore.updateProfile(request)
    }

    func completeBirthdaySetup(with birthDate: Date) async throws {
        let request = UpdateProfileRequest(
            imageUrl: nil,
            birthDay: HouseFlowDateFormatter.apiString(from: birthDate),
            firstName: nil,
            lastName: nil,
            phoneNumber: nil
        )
        try await updateProfile(request)
        showBirthdaySetup = false
        await didAuthenticateAsync()
    }

    private func needsBirthdaySetup(_ profile: IsAuthUserData) -> Bool {
        guard let birthDate = profile.birthDate else { return true }
        return birthDate.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - House API (Full Flow)

    /// Full create-house flow: shows loading screen → POST → GET details → dashboard.
    /// On any error, navigates back to CreateHouseView and shows a toast.
    func beginCreateHouseFlow(name: String, type: Int, maxMemberCount: Int) async {
        navigationDirection = .forward
        do {
            try await houseStore.beginCreateHouseFlow(name: name, type: type, maxMemberCount: maxMemberCount)
            navigationDirection = .forward
        } catch {
            navigationDirection = .backward
            showToast(message: error.localizedDescription, isError: true)
        }
    }

    /// Full join-house flow: shows loading screen → POST → GET details → dashboard.
    /// On any error, navigates back to JoinHouseView and shows a toast.
    func beginJoinHouseFlow(inviteCode: String) async {
        navigationDirection = .forward
        do {
            try await houseStore.beginJoinHouseFlow(inviteCode: inviteCode)
            navigationDirection = .forward
        } catch {
            navigationDirection = .backward
            showToast(message: error.localizedDescription, isError: true)
        }
    }

    // MARK: - Toast

    func showToast(message: String, isError: Bool = true) {
        toastStore.show(message: message, isError: isError)
    }

    private func clearToast() {
        toastStore.clear()
    }

    func logout() {
        authStore.logout()
        houseStore.resetHouseSession()
        showBirthdaySetup = false
        signupSuccessMessage = nil
        navigationDirection = .backward
        choreStore.clear()
        clearToast()
    }

    func cancelEmailVerification() {
        logout()
        showAuth = true
    }

    // MARK: - Dashboard Data (mapped from API details)

    private func rebuildDashboardCache() {
        rebuildDashboardCache(details: currentHouseDetails, currentUserProfile: currentUserProfile)
    }

    private func rebuildDashboardCache(details: HouseDetailsResponse?, currentUserProfile: IsAuthUserData?) {
        dashboardStore.rebuild(
            details: details,
            fallbackMembers: sampleUsers,
            fallbackChores: chores.isEmpty ? sampleChores : chores,
            fallbackUnassignedName: localized("common_unassigned"),
            currentUserId: currentUserId,
            currentUserProfile: currentUserProfile
        )
    }

    // MARK: - Announcement API

    @discardableResult
    func createAnnouncement(title: String, description: String) async -> Bool {
        do {
            _ = try await houseStore.createAnnouncement(title: title, description: description)
            showToast(
                message: localized("announcement_created_toast", fallback: "Announcement published."),
                isError: false
            )
            return true
        } catch {
            showToast(message: error.localizedDescription, isError: true)
            return false
        }
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
        do {
            applyHouseDetailsIfNeeded(try await choreStore.createChore(
                assignedToId: assignedToId,
                description: description,
                dueDate: dueDate,
                houseId: houseId,
                isRecurring: isRecurring,
                level: level,
                recurringInterval: recurringInterval,
                title: title,
                currentHouseDetails: currentHouseDetails,
                dashboardMembers: dashboardMembers
            ))
            showToast(message: localized("chore_created_toast"), isError: false)
        } catch {
            showToast(message: error.localizedDescription, isError: true)
        }
    }

    /// Updates the status of a single chore via the API, then merges the returned chore.
    func updateChoreStatus(choreApiId: String, houseId: String, status: ChoreStatus) async -> Bool {
        do {
            let result = try await choreStore.updateStatus(
                choreApiId: choreApiId,
                houseId: houseId,
                status: status,
                currentHouseDetails: currentHouseDetails,
                dashboardMembers: dashboardMembers
            )
            guard result.didUpdate else {
                showToast(message: localized("chore_status_update_failed_toast"), isError: true)
                return false
            }
            applyHouseDetailsIfNeeded(result.updatedDetails)
            showToast(message: localized("chore_status_updated_toast"), isError: false)
            return true
        } catch {
            showToast(message: error.localizedDescription, isError: true)
            return false
        }
    }

    /// Submits the current user's vote for an in-review chore.
    func reviewChore(choreApiId: String, isApproved: Bool) async -> Bool {
        do {
            applyHouseDetailsIfNeeded(try await choreStore.review(
                choreApiId: choreApiId,
                isApproved: isApproved,
                currentHouseDetails: currentHouseDetails,
                dashboardMembers: dashboardMembers
            ))
            showToast(
                message: localized(isApproved ? "chore_approved_toast" : "chore_sent_back_toast"),
                isError: false
            )
            return true
        } catch {
            showToast(message: error.localizedDescription, isError: true)
            return false
        }
    }

    private func applyHouseDetailsIfNeeded(_ details: HouseDetailsResponse?) {
        guard let details else { return }
        setCurrentHouseDetails(details)
    }

    private func errorMessage(from error: Error) -> String {
        if case NetworkError.serverError(let message) = error {
            return message
        }
        return error.localizedDescription
    }
}
