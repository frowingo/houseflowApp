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

    var title: String {
        switch self {
        case .creating:       return "Creating Your House"
        case .joining:        return "Joining House"
        case .loadingDetails: return "Almost There!"
        case .checkingAuth:   return "Welcome Back!"
        case .loadingUser:    return "Loading Profile"
        case .loadingHouse:   return "Loading Your Home"
        }
    }

    var subtitle: String {
        switch self {
        case .creating:       return "Setting up your new home..."
        case .joining:        return "Connecting you to the house..."
        case .loadingDetails: return "Loading your house details..."
        case .checkingAuth:   return "Verifying your session..."
        case .loadingUser:    return "Fetching your account details..."
        case .loadingHouse:   return "Almost ready, hang on..."
        }
    }
}

@MainActor
class AppViewModel: ObservableObject {
    @Published var navigationDirection: NavigationDirection = .forward

    private let keychain = KeychainService.shared
    private let authStore = AuthSessionStore()
    private let toastStore = ToastStore()
    private let overlayStore = OverlayStore()
    private let houseStore = HouseSessionStore(isInitializing: KeychainService.shared.authToken != nil)
    private let dashboardStore = DashboardStore()
    private let choreStore = ChoreStore()
    private var storeCancellables = Set<AnyCancellable>()

    /// The server-assigned ID of the logged-in user (used to gate chore status edits).
    var currentUserId: String? { authStore.currentUserId }

    /// Full server profile of the logged-in user (used for profile display & edit).
    var currentUserProfile: IsAuthUserData? { authStore.currentUserProfile }

    var dashboardMembers: [User] { dashboardStore.members }
    var dashboardChores: [Chore] { dashboardStore.chores }

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
        dashboardStore.sampleUsers
    }
    
    var sampleChores: [Chore] {
        [
            Chore(id: "sample-take-trash", title: "Take out the trash", description: "Empty all trash bins and take bags to the dumpster", assignedTo: sampleUsers[0], dueLabel: "Today"),
            Chore(id: "sample-kitchen-counter", title: "Clean kitchen counter", description: "Wipe down all surfaces, clean sink and organize items", assignedTo: sampleUsers[1], dueLabel: "Today"),
            Chore(id: "sample-vacuum-living-room", title: "Vacuum living room", description: "Vacuum carpet and clean under furniture", assignedTo: sampleUsers[2], dueLabel: "Overdue"),
            Chore(id: "sample-clean-bathroom", title: "Clean bathroom", description: "Clean toilet, shower, sink and mirror", assignedTo: sampleUsers[3], dueLabel: "This week"),
            Chore(id: "sample-laundry", title: "Do laundry", description: "Wash, dry and fold clothes", assignedTo: sampleUsers[0], dueLabel: "Today", isDone: true)
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

    // MARK: - Auto Login

    /// Called on app foreground. If a valid token is stored, silently authenticates
    /// and navigates straight to the dashboard. No-op if already authenticated.
    func performAutoLogin() async {
        // Fast-path: no token in keychain → nothing to verify, go straight to auth.
        guard keychain.authToken != nil else {
            isInitializing = false
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

    func signup(email: String, password: String, firstName: String, lastName: String) async {
        if await authStore.signup(email: email, password: password, firstName: firstName, lastName: lastName) {
            didAuthenticate()
        }
    }

    func forgotPassword(email: String) async -> Bool {
        await authStore.forgotPassword(email: email)
    }

    func resetPassword(email: String, code: String, newPassword: String) async -> Bool {
        await authStore.resetPassword(email: email, code: code, newPassword: newPassword)
    }

    private func didAuthenticate() {
        Task { await didAuthenticateAsync() }
    }

    private func didAuthenticateAsync() async {
        navigationDirection = .forward
        showAuth = false
        houseLoadingPhase = .loadingUser
        showHouseLoading = true

        do {
            setCurrentHouseDetails(nil)
            let profile = try await authStore.resolveAuthenticatedUser()
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
        navigationDirection = .backward
        choreStore.clear()
        clearToast()
    }

    // MARK: - Dashboard Data (mapped from API details)

    private func rebuildDashboardCache() {
        rebuildDashboardCache(details: currentHouseDetails, currentUserProfile: currentUserProfile)
    }

    private func rebuildDashboardCache(details: HouseDetailsResponse?, currentUserProfile: IsAuthUserData?) {
        dashboardStore.rebuild(
            details: details,
            fallbackChores: chores,
            currentUserId: currentUserId,
            currentUserProfile: currentUserProfile
        )
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
            showToast(message: "Chore created!", isError: false)
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
                showToast(message: "Status could not be updated.", isError: true)
                return false
            }
            applyHouseDetailsIfNeeded(result.updatedDetails)
            showToast(message: "Status updated!", isError: false)
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
                message: isApproved ? "Chore approved!" : "Chore sent back to progress.",
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
