import Foundation
import Combine

enum NavigationDirection {
    case forward, backward
}

enum AppRoute: Equatable {
    case houseLoading(HouseLoadingPhase)
    case houseError
    case onboarding
    case emailVerification(email: String)
    case birthdaySetup
    case authentication
    case createHouse
    case joinHouse
    case houseSelection
    case dashboard

    var id: String {
        switch self {
        case .houseLoading:
            return "houseLoading"
        case .houseError:
            return "houseError"
        case .onboarding:
            return "onboarding"
        case .emailVerification:
            return "emailVerification"
        case .birthdaySetup:
            return "birthdaySetup"
        case .authentication:
            return "auth"
        case .createHouse:
            return "createHouse"
        case .joinHouse:
            return "joinHouse"
        case .houseSelection:
            return "houseSelection"
        case .dashboard:
            return "mainTab"
        }
    }

    var requiresAuthenticatedSession: Bool {
        switch self {
        case .createHouse, .joinHouse, .houseSelection, .dashboard:
            return true
        default:
            return false
        }
    }
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
    @Published private(set) var route: AppRoute
    @Published private(set) var signupSuccessMessage: String?

    private let keychain = KeychainService.shared
    private let authStore = AuthSessionStore()
    private let toastStore = ToastStore()
    private let overlayStore = OverlayStore()
    private let houseStore = HouseSessionStore()
    private let dashboardStore = DashboardStore()
    private let choreStore = ChoreStore()
    private let localizationStore = LocalizationStore()
    private var storeCancellables = Set<AnyCancellable>()
    private var authenticationFlowID = UUID()

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

    private var pendingEmailVerification: String? {
        authStore.pendingEmailVerification
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

    var houseLoadingPhase: HouseLoadingPhase {
        guard case .houseLoading(let phase) = route else { return .checkingAuth }
        return phase
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
        route = Self.initialRoute()
        bindStoreChanges()
        rebuildDashboardCache()
    }

    private static func initialRoute() -> AppRoute {
        if KeychainService.shared.authToken != nil {
            return .houseLoading(.checkingAuth)
        }
        if !UserDefaults.standard.bool(forKey: "hasSeenOnboarding") {
            return .onboarding
        }
        if let email = KeychainService.shared.pendingEmailVerification {
            return .emailVerification(email: email)
        }
        return .authentication
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
    
    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasSeenOnboarding")
        navigationDirection = .forward

        if let email = pendingEmailVerification {
            route = .emailVerification(email: email)
        } else if let profile = currentUserProfile,
                  !isAuthenticated,
                  needsBirthdaySetup(profile) {
            route = .birthdaySetup
        } else {
            route = .authentication
        }
    }

    private var hasSeenOnboarding: Bool {
        UserDefaults.standard.bool(forKey: "hasSeenOnboarding")
    }

    private func navigate(to destination: AppRoute, respectingOnboarding: Bool = true) {
        guard !destination.requiresAuthenticatedSession || isAuthenticated else {
            navigateToUnauthenticatedEntry()
            return
        }

        if respectingOnboarding, !hasSeenOnboarding {
            route = .onboarding
        } else {
            route = destination
        }
    }

    private func navigateToUnauthenticatedEntry() {
        if !hasSeenOnboarding {
            route = .onboarding
        } else if let email = pendingEmailVerification {
            route = .emailVerification(email: email)
        } else {
            route = .authentication
        }
    }

    private func beginAuthenticationFlow() -> UUID {
        let flowID = UUID()
        authenticationFlowID = flowID
        return flowID
    }

    private func invalidateAuthenticationFlows() {
        authenticationFlowID = UUID()
    }

    private func isCurrentAuthenticationFlow(_ flowID: UUID) -> Bool {
        authenticationFlowID == flowID
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
            invalidateAuthenticationFlows()
            isAuthenticated = false
            navigateToUnauthenticatedEntry()
            return
        }
        if let email = pendingEmailVerification {
            invalidateAuthenticationFlows()
            navigate(to: .emailVerification(email: email))
            return
        }
        // Already in an authenticated session → nothing to do.
        guard !isAuthenticated else {
            return
        }

        let flowID = beginAuthenticationFlow()
        navigationDirection = .forward
        route = .houseLoading(.checkingAuth)

        do {
            route = .houseLoading(.loadingUser)
            let profile = try await authStore.fetchAuthenticatedUser(
                invalidMessage: "Oturumunuz sona ermiş. Lütfen tekrar giriş yapın."
            )
            guard isCurrentAuthenticationFlow(flowID) else { return }
            authStore.applyAuthenticatedUser(profile)

            guard profile.isVerifyEmail else {
                authStore.requireEmailVerification(for: profile.email)
                isAuthenticated = false
                navigate(to: .emailVerification(email: profile.email))
                return
            }
            if needsBirthdaySetup(profile) {
                isAuthenticated = false
                navigate(to: .birthdaySetup)
                return
            }
            if let language = profile.language {
                localizationStore.applyPreferredLanguage(language)
            } else {
                localizationStore.loadLanguagesAndApplyDefault(force: localizationLanguages.isEmpty)
            }
            isAuthenticated = true

            guard !profile.houseIds.isEmpty else {
                navigate(to: .houseSelection)
                return
            }

            route = .houseLoading(.loadingHouse)
            guard let details = try await houseStore.fetchFirstHouseDetails(for: profile) else {
                guard isCurrentAuthenticationFlow(flowID), isAuthenticated else { return }
                navigate(to: .houseSelection)
                return
            }
            guard isCurrentAuthenticationFlow(flowID), isAuthenticated else { return }
            houseStore.applyHouseDetails(details)
            try? await Task.sleep(for: .milliseconds(600))
            guard isCurrentAuthenticationFlow(flowID), isAuthenticated else { return }
            navigate(to: .dashboard)
        } catch {
            guard isCurrentAuthenticationFlow(flowID) else { return }
            isAuthenticated = false
            showToast(message: errorMessage(from: error), isError: true)
            route = .houseError
        }
    }

    // MARK: - Real Auth (API)

    func login(email: String, password: String) async {
        if await authStore.login(email: email, password: password) {
            await didAuthenticateAsync()
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
            let verificationEmail = pendingEmailVerification ?? email.trimmingCharacters(in: .whitespacesAndNewlines)
            navigate(to: .emailVerification(email: verificationEmail))
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
        let flowID = beginAuthenticationFlow()

        do {
            try await authStore.validateEmail(code: code)
            guard isCurrentAuthenticationFlow(flowID) else { return }

            let profile = try await authStore.fetchAuthenticatedUser()
            guard isCurrentAuthenticationFlow(flowID) else { return }
            guard profile.isVerifyEmail else {
                throw NetworkError.serverError("The email address could not be verified.")
            }

            authStore.applyAuthenticatedUser(profile)
            navigationDirection = .forward
            isAuthenticated = false
            authStore.clearPendingEmailVerification()
            navigate(to: .birthdaySetup)
        } catch {
            guard isCurrentAuthenticationFlow(flowID) else { return }
            throw error
        }
    }

    private func didAuthenticateAsync() async {
        let flowID = beginAuthenticationFlow()
        navigationDirection = .forward
        route = .houseLoading(.loadingUser)

        do {
            setCurrentHouseDetails(nil)
            let profile = try await authStore.fetchAuthenticatedUser()
            guard isCurrentAuthenticationFlow(flowID) else { return }
            authStore.applyAuthenticatedUser(profile)

            guard profile.isVerifyEmail else {
                authStore.requireEmailVerification(for: profile.email)
                isAuthenticated = false
                navigate(to: .emailVerification(email: profile.email))
                return
            }
            if needsBirthdaySetup(profile) {
                isAuthenticated = false
                navigate(to: .birthdaySetup)
                return
            }
            if let language = profile.language {
                localizationStore.applyPreferredLanguage(language)
            } else {
                localizationStore.loadLanguagesAndApplyDefault(force: localizationLanguages.isEmpty)
            }
            isAuthenticated = true

            guard !profile.houseIds.isEmpty else {
                navigate(to: .houseSelection)
                return
            }

            route = .houseLoading(.loadingHouse)
            guard let details = try await houseStore.fetchFirstHouseDetails(for: profile) else {
                guard isCurrentAuthenticationFlow(flowID), isAuthenticated else { return }
                navigate(to: .houseSelection)
                return
            }
            guard isCurrentAuthenticationFlow(flowID), isAuthenticated else { return }
            houseStore.applyHouseDetails(details)
            try? await Task.sleep(for: .milliseconds(600))
            guard isCurrentAuthenticationFlow(flowID), isAuthenticated else { return }
            navigate(to: .dashboard)
        } catch {
            guard isCurrentAuthenticationFlow(flowID) else { return }
            isAuthenticated = false
            showToast(message: errorMessage(from: error), isError: true)
            route = .houseError
        }
    }

    func showCreateHouseScreen() {
        navigationDirection = .forward
        navigate(to: .createHouse)
    }
    
    func backToHouseSelection() {
        navigationDirection = .backward
        navigate(to: .houseSelection)
    }
    
    func showJoinHouseScreen() {
        navigationDirection = .forward
        navigate(to: .joinHouse)
    }

    // MARK: - User Profile Update

    func updateProfile(_ request: UpdateProfileRequest) async throws {
        let profile = try await authStore.updateProfile(request)
        authStore.applyAuthenticatedUser(profile)
    }

    func completeBirthdaySetup(with birthDate: Date) async throws {
        let flowID = beginAuthenticationFlow()
        let request = UpdateProfileRequest(
            imageUrl: nil,
            birthDay: HouseFlowDateFormatter.apiString(from: birthDate),
            firstName: nil,
            lastName: nil,
            phoneNumber: nil
        )
        let profile = try await authStore.updateProfile(request)
        guard isCurrentAuthenticationFlow(flowID) else { return }
        authStore.applyAuthenticatedUser(profile)
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
        route = .houseLoading(.creating)
        do {
            try await houseStore.beginCreateHouseFlow(
                name: name,
                type: type,
                maxMemberCount: maxMemberCount,
                onDetailsLoading: { [weak self] in
                    self?.route = .houseLoading(.loadingDetails)
                }
            )
            navigationDirection = .forward
            navigate(to: .dashboard)
        } catch {
            navigationDirection = .backward
            navigate(to: .createHouse)
            showToast(message: error.localizedDescription, isError: true)
        }
    }

    /// Full join-house flow: shows loading screen → POST → GET details → dashboard.
    /// On any error, navigates back to JoinHouseView and shows a toast.
    func beginJoinHouseFlow(inviteCode: String) async {
        navigationDirection = .forward
        route = .houseLoading(.joining)
        do {
            try await houseStore.beginJoinHouseFlow(
                inviteCode: inviteCode,
                onDetailsLoading: { [weak self] in
                    self?.route = .houseLoading(.loadingDetails)
                }
            )
            navigationDirection = .forward
            navigate(to: .dashboard)
        } catch {
            navigationDirection = .backward
            navigate(to: .joinHouse)
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
        invalidateAuthenticationFlows()
        authStore.logout()
        houseStore.resetHouseSession()
        signupSuccessMessage = nil
        navigationDirection = .backward
        choreStore.clear()
        clearToast()
        navigateToUnauthenticatedEntry()
    }

    func cancelEmailVerification() {
        logout()
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
