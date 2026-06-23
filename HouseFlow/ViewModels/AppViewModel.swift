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
    @Published var isAuthenticated: Bool = false
    @Published var hasSelectedHouse: Bool = false
    @Published var showCreateHouse: Bool = false
    @Published var showJoinHouse: Bool = false
    @Published var showAuth: Bool = false
    @Published var currentUser: User?
    @Published var houseName: String = ""
    @Published var chores: [Chore] = []
    @Published var navigationDirection: NavigationDirection = .forward

    // MARK: - Auth State
    @Published var isLoading: Bool = false
    @Published var authError: String?
    @Published var successToast: String?

    // MARK: - House State
    @Published var currentHouse: HouseResponse?
    @Published var currentHouseDetails: HouseDetailsResponse?
    @Published var houseIsLoading: Bool = false
    @Published var houseError: String?

    // MARK: - House Loading Screen State
    // Start in loading state only if a token exists — avoids a flash of the
    // loading screen when there is nothing to verify.
    @Published var isInitializing: Bool = KeychainService.shared.authToken != nil
    @Published var showHouseLoading: Bool = false
    @Published var houseLoadingPhase: HouseLoadingPhase = .checkingAuth
    @Published var showHouseError: Bool = false

    // MARK: - Toast State
    @Published var toastMessage: String? = nil
    @Published var toastIsError: Bool = true

    private let authService = AuthService.shared
    private let houseService = HouseService.shared
    private let choreService = ChoreService.shared
    private let keychain = KeychainService.shared

    /// The server-assigned ID of the logged-in user (used to gate chore status edits).
    @Published var currentUserId: String?

    /// Full server profile of the logged-in user (used for profile display & edit).
    @Published var currentUserProfile: IsAuthUserData?

    /// Set to true whenever a modal / popup is covering the screen so the tab bar hides.
    @Published var isOverlayPresented: Bool = false

    // MARK: - Background Session Tracking
    /// Timestamp of when the app last entered the background.
    private var backgroundedAt: Date? = nil
    /// How long the app must be in the background before re-running the auth check on foreground.
    private let backgroundRefreshThreshold: TimeInterval = 15 * 60 // 15 minutes
    
    // Sample data for demo
    let sampleUsers = [
        User(firstName: "Mahmut", lastName: "Yılmaz", points: 12),
        User(firstName: "Jane", lastName: "Doe", points: 8),
        User(firstName: "Abdüllatif", lastName: "Kaya", points: 10),
        User(firstName: "Katya", lastName: "Ivanova", points: 6)
    ]
    
    var sampleChores: [Chore] {
        [
            Chore(title: "Take out the trash", description: "Empty all trash bins and take bags to the dumpster", assignedTo: sampleUsers[0], dueLabel: "Today"),
            Chore(title: "Clean kitchen counter", description: "Wipe down all surfaces, clean sink and organize items", assignedTo: sampleUsers[1], dueLabel: "Today"),
            Chore(title: "Vacuum living room", description: "Vacuum carpet and clean under furniture", assignedTo: sampleUsers[2], dueLabel: "Overdue"),
            Chore(title: "Clean bathroom", description: "Clean toilet, shower, sink and mirror", assignedTo: sampleUsers[3], dueLabel: "This week"),
            Chore(title: "Do laundry", description: "Wash, dry and fold clothes", assignedTo: sampleUsers[0], dueLabel: "Today", isDone: true)
        ]
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
        isInitializing = false

        // Step 1: Verify token
        let profile: IsAuthUserData
        do {
            let result = try await authService.isAuth()
            guard result.success, let userData = result.data else {
                failAutoLogin(message: "Oturumunuz sona ermiş. Lütfen tekrar giriş yapın.")
                return
            }
            profile = userData
        } catch {
            failAutoLogin(message: error.localizedDescription)
            return
        }

        // Step 2: Update local cache and in-memory user state
        houseLoadingPhase = .loadingUser
        applyAuthenticatedUser(profile)

        // Step 3: Load house details (first house in houseIds)
        guard let firstHouseId = profile.houseIds.first else {
            // Authenticated but no house yet → house selection screen
            isAuthenticated = true
            showHouseLoading = false
            return
        }

        houseLoadingPhase = .loadingHouse
        do {
            let details = try await houseService.fetchDetails(houseId: firstHouseId)
            currentHouseDetails = details
            houseName = details.name
            try? await Task.sleep(for: .milliseconds(600))
            showHouseLoading = false
            isAuthenticated = true
            hasSelectedHouse = true
        } catch {
            showHouseLoading = false
            let message: String
            if case NetworkError.serverError(let msg) = error {
                message = msg
            } else {
                message = error.localizedDescription
            }
            showToast(message: message, isError: true)
            showHouseError = true
        }
    }

    private func failAutoLogin(message: String) {
        showHouseLoading = false
        isInitializing = false
        showAuth = true
        showToast(message: message, isError: true)
    }

    // MARK: - Real Auth (API)

    func login(email: String, password: String) async {
        isLoading = true
        authError = nil
        do {
            _ = try await authService.login(email: email, password: password)
            isLoading = false
            didAuthenticate()
        } catch {
            authError = error.localizedDescription
            isLoading = false
        }
    }

    func signup(email: String, password: String, firstName: String, lastName: String) async {
        isLoading = true
        authError = nil
        do {
            _ = try await authService.signup(
                email: email,
                password: password,
                firstName: firstName,
                lastName: lastName
            )
            isLoading = false
            didAuthenticate()
        } catch {
            authError = error.localizedDescription
            isLoading = false
        }
    }

    func forgotPassword(email: String) async -> Bool {
        isLoading = true
        authError = nil
        do {
            let response = try await authService.forgotPassword(email: email)
            isLoading = false
            return response.success
        } catch {
            authError = error.localizedDescription
            isLoading = false
            return false
        }
    }

    func resetPassword(email: String, code: String, newPassword: String) async -> Bool {
        isLoading = true
        authError = nil
        do {
            _ = try await authService.resetPassword(email: email, code: code, newPassword: newPassword)
            isLoading = false
            return true
        } catch {
            authError = error.localizedDescription
            isLoading = false
            return false
        }
    }

    private func didAuthenticate() {
        Task { await didAuthenticateAsync() }
    }

    private func didAuthenticateAsync() async {
        navigationDirection = .forward
        showAuth = false
        houseLoadingPhase = .loadingUser
        showHouseLoading = true

        // Fetch authenticated user from auth/isAuth response
        do {
            let result = try await authService.isAuth()
            guard result.success, let profile = result.data else {
                throw NetworkError.serverError("Authenticated user could not be resolved.")
            }

            currentHouseDetails = nil
            applyAuthenticatedUser(profile)

            guard let firstHouseId = profile.houseIds.first else {
                // No house yet → house selection
                isAuthenticated = true
                showHouseLoading = false
                return
            }

            // Has a house → fetch details
            houseLoadingPhase = .loadingHouse
            let details = try await houseService.fetchDetails(houseId: firstHouseId)
            currentHouseDetails = details
            houseName = details.name
            try? await Task.sleep(for: .milliseconds(600))

            isAuthenticated = true
            hasSelectedHouse = true
            showHouseLoading = false

        } catch {
            let message: String
            if case NetworkError.serverError(let msg) = error {
                message = msg
            } else {
                message = error.localizedDescription
            }
            showToast(message: message, isError: true)
            showHouseLoading = false
            showHouseError = true
        }
    }

    private func applyAuthenticatedUser(_ profile: IsAuthUserData) {
        keychain.userEmail = profile.email
        keychain.userFirstName = profile.firstName
        keychain.userLastName = profile.lastName
        currentUserId = profile.id
        currentUserProfile = profile
        currentUser = User(firstName: profile.firstName, lastName: profile.lastName, apiId: profile.id, points: 0, imageUrl: profile.imageUrl.isEmpty ? nil : profile.imageUrl)
    }
    
    func selectHouse(name: String) {
        navigationDirection = .forward
        houseName = name
        hasSelectedHouse = true
        showCreateHouse = false
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
        guard let userId = currentUserId else {
            throw NetworkError.serverError("User not authenticated.")
        }
        let response = try await UserService.shared.updateProfile(userId: userId, request: request)
        guard response.success, let data = response.data else {
            throw NetworkError.serverError(response.error ?? "Update failed.")
        }
        await MainActor.run {
            // Merge updated fields back into the cached IsAuthUserData profile
            if var profile = currentUserProfile {
                profile = IsAuthUserData(
                    birthDate: data.birthDate,
                    createdOn: data.createdOn,
                    email: data.email,
                    firstName: data.firstName,
                    houseIds: data.houseIds,
                    id: data.id,
                    imageUrl: data.imageUrl,
                    isActive: data.isActive,
                    isVerifyEmail: data.isVerifyEmail,
                    isVerifyPhone: data.isVerifyPhone,
                    lastLogin: data.lastLogin,
                    lastName: data.lastName,
                    phoneNumber: data.phoneNumber,
                    updatedOn: data.updatedOn
                )
                applyAuthenticatedUser(profile)
            }
        }
    }

    // MARK: - House API (Full Flow)

    /// Full create-house flow: shows loading screen → POST → GET details → dashboard.
    /// On any error, navigates back to CreateHouseView and shows a toast.
    func beginCreateHouseFlow(name: String, type: Int, maxMemberCount: Int) async {
        houseLoadingPhase = .creating
        navigationDirection = .forward
        showCreateHouse = false
        showHouseLoading = true
        houseError = nil

        do {
            let house = try await houseService.createHouse(name: name, type: type, maxMemberCount: maxMemberCount)
            currentHouse = house

            houseLoadingPhase = .loadingDetails

            let details = try await houseService.fetchDetails(houseId: house.id)
            currentHouseDetails = details
            houseName = house.name

            // Brief pause so the user can read the "Almost There!" phase
            try? await Task.sleep(for: .milliseconds(700))

            navigationDirection = .forward
            hasSelectedHouse = true
            showHouseLoading = false

        } catch {
            navigationDirection = .backward
            showHouseLoading = false
            showCreateHouse = true
            showToast(message: error.localizedDescription, isError: true)
        }
    }

    /// Full join-house flow: shows loading screen → POST → GET details → dashboard.
    /// On any error, navigates back to JoinHouseView and shows a toast.
    func beginJoinHouseFlow(inviteCode: String) async {
        houseLoadingPhase = .joining
        navigationDirection = .forward
        showJoinHouse = false
        showHouseLoading = true
        houseError = nil

        do {
            let house = try await houseService.joinHouse(inviteCode: inviteCode)
            currentHouse = house

            houseLoadingPhase = .loadingDetails

            let details = try await houseService.fetchDetails(houseId: house.id)
            currentHouseDetails = details
            houseName = house.name

            try? await Task.sleep(for: .milliseconds(700))

            navigationDirection = .forward
            hasSelectedHouse = true
            showHouseLoading = false

        } catch {
            navigationDirection = .backward
            showHouseLoading = false
            showJoinHouse = true
            showToast(message: error.localizedDescription, isError: true)
        }
    }

    // MARK: - Toast

    func showToast(message: String, isError: Bool = true) {
        toastMessage = message
        toastIsError = isError
        Task {
            try? await Task.sleep(for: .seconds(4))
            toastMessage = nil
        }
    }

    // MARK: - House API (Legacy helpers)

    /// Calls POST house/create. Returns the created house on success, nil on failure (sets houseError).
    func createHouseAPI(name: String, type: Int, maxMemberCount: Int) async -> HouseResponse? {
        houseIsLoading = true
        houseError = nil
        do {
            let house = try await houseService.createHouse(name: name, type: type, maxMemberCount: maxMemberCount)
            currentHouse = house
            houseIsLoading = false
            return house
        } catch {
            houseError = error.localizedDescription
            houseIsLoading = false
            return nil
        }
    }

    /// Calls POST house/join. Returns the joined house on success, nil on failure (sets houseError).
    func joinHouseAPI(inviteCode: String) async -> HouseResponse? {
        houseIsLoading = true
        houseError = nil
        do {
            let house = try await houseService.joinHouse(inviteCode: inviteCode)
            currentHouse = house
            houseIsLoading = false
            return house
        } catch {
            houseError = error.localizedDescription
            houseIsLoading = false
            return nil
        }
    }

    /// Calls GET house/details. Stores result in currentHouseDetails.
    func fetchHouseDetails(houseId: String) async {
        do {
            currentHouseDetails = try await houseService.fetchDetails(houseId: houseId)
        } catch {
            print("[HouseDetails] fetch failed: \(error.localizedDescription)")
        }
    }

    /// Finalizes navigation after a successful create or join (legacy path).
    func finalizeHouseSelection(house: HouseResponse) {
        currentHouse = house
        houseName = house.name
        navigationDirection = .forward
        hasSelectedHouse = true
        showCreateHouse = false
        showJoinHouse = false
        Task { await fetchHouseDetails(houseId: house.id) }
    }
    
    func logout() {
        authService.logout()
        navigationDirection = .backward
        isAuthenticated = false
        hasSelectedHouse = false
        showCreateHouse = false
        showJoinHouse = false
        showHouseLoading = false
        showHouseError = false
        isInitializing = false
        showAuth = false
        currentUser = nil
        currentUserId = nil
        currentHouse = nil
        currentHouseDetails = nil
        houseName = ""
        chores = []
        toastMessage = nil
    }

    // MARK: - Dashboard Data (mapped from API details)

    /// House members mapped from `currentHouseDetails`, falls back to sample data.
    var dashboardMembers: [User] {
        guard let details = currentHouseDetails else { return sampleUsers }
        return details.members.map { member in
            // Use fresh profile data for the current user so updates reflect immediately
            if member.id == currentUserId, let profile = currentUserProfile {
                return User(firstName: profile.firstName, lastName: profile.lastName, apiId: member.id, points: 0, imageUrl: profile.imageUrl.isEmpty ? nil : profile.imageUrl)
            }
            return User(firstName: member.firstName, lastName: member.lastName, apiId: member.id, points: 0, imageUrl: member.imageUrl.isEmpty ? nil : member.imageUrl)
        }
    }

    /// Chores mapped from `currentHouseDetails`, falls back to in-memory chores.
    var dashboardChores: [Chore] {
        guard let details = currentHouseDetails else { return chores }
        return details.chores.map { dto in
            let matchedMember = details.members.first(where: { $0.id == dto.assignedTo })
            let assignedUser: User
            if let matched = matchedMember {
                // Use fresh profile for the current user
                if matched.id == currentUserId, let profile = currentUserProfile {
                    assignedUser = User(firstName: profile.firstName, lastName: profile.lastName, apiId: matched.id, points: 0, imageUrl: profile.imageUrl.isEmpty ? nil : profile.imageUrl)
                } else {
                    assignedUser = User(firstName: matched.firstName, lastName: matched.lastName, apiId: matched.id, points: 0, imageUrl: matched.imageUrl.isEmpty ? nil : matched.imageUrl)
                }
            } else {
                assignedUser = User(name: dto.assignedTo.isEmpty ? "Unassigned" : dto.assignedTo)
            }
            let label = dto.dueLabelString
            return Chore(
                choreApiId: dto.id,
                houseId: dto.houseId,
                assignedToId: dto.assignedTo,
                title: dto.title,
                description: dto.description,
                assignedTo: assignedUser,
                dueLabel: label,
                dueDate: dto.dueDate,
                isDone: dto.isCompleted,
                status: dto.status,
                level: dto.level
            )
        }
    }
    
    private func initializeChores() {
        chores = [
            Chore(title: "Take out the trash", description: "Empty all trash bins and take bags to the dumpster", assignedTo: sampleUsers[0], dueLabel: "Today"),
            Chore(title: "Clean kitchen counter", description: "Wipe down all surfaces, clean sink and organize items", assignedTo: sampleUsers[1], dueLabel: "Today"),
            Chore(title: "Vacuum living room", description: "Vacuum carpet and clean under furniture", assignedTo: sampleUsers[2], dueLabel: "Overdue"),
            Chore(title: "Clean bathroom", description: "Clean toilet, shower, sink and mirror", assignedTo: sampleUsers[3], dueLabel: "This week"),
            Chore(title: "Do laundry", description: "Wash, dry and fold clothes", assignedTo: sampleUsers[0], dueLabel: "Today", isDone: true)
        ]
    }
    
    func toggleChoreCompletion(_ choreId: UUID) {
        if let index = chores.firstIndex(where: { $0.id == choreId }) {
            let c = chores[index]
            chores[index] = Chore(
                choreApiId: c.choreApiId,
                houseId: c.houseId,
                assignedToId: c.assignedToId,
                title: c.title,
                description: c.description,
                assignedTo: c.assignedTo,
                dueLabel: c.dueLabel,
                isDone: !c.isDone,
                status: c.isDone ? 0 : 3,
                level: c.level
            )
        }
    }

    // MARK: - Chore API

    /// Refreshes house details after any chore mutation.
    func refreshHouseDetails() async {
        guard let houseId = currentHouseDetails?.id ?? currentHouse?.id else { return }
        do {
            let details = try await houseService.fetchDetails(houseId: houseId)
            currentHouseDetails = details
            houseName = details.name
        } catch {
            showToast(message: error.localizedDescription, isError: true)
        }
    }

    /// Creates a chore via the API, then refreshes house details.
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
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        let dueDateStr = formatter.string(from: dueDate)
        do {
            _ = try await choreService.createChore(
                assignedTo: assignedToId,
                description: description,
                dueDate: dueDateStr,
                houseId: houseId,
                isRecurring: isRecurring,
                level: level,
                recurringInterval: recurringInterval,
                title: title
            )
            await refreshHouseDetails()
            showToast(message: "Chore created!", isError: false)
        } catch {
            showToast(message: error.localizedDescription, isError: true)
        }
    }

    /// Updates the status of a single chore via the API, then refreshes.
    func updateChoreStatus(choreApiId: String, houseId: String, status: ChoreStatus) async {
        do {
            try await choreService.updateChoreStatus(
                houseId: houseId,
                chores: [ChoreStatusUpdateItem(choreId: choreApiId, status: status.rawValue)]
            )
            await refreshHouseDetails()
            showToast(message: "Status updated!", isError: false)
        } catch {
            showToast(message: error.localizedDescription, isError: true)
        }
    }
}
