import Foundation
import Combine
import FausCrewCore

@MainActor
class AppViewModel: ObservableObject {
    private let authStore: AuthSessionStore
    let toastStore: ToastStore
    let overlayStore: OverlayStore
    private let houseStore: HouseSessionStore
    private let dashboardStore: DashboardStore
    private let choreStore: ChoreStore
    private let localizationStore: LocalizationStore
    /// System templates and the user's drafts for the chore catalog popup.
    let choreCatalogStore: ChoreCatalogStore
    let router: AppRouter
    let authenticationViewModel: AuthenticationViewModel
    let houseRocketsSessionFactory: HouseRocketsSessionFactory
    let houseTanksOnlineFactory: HouseTanksOnlineFactory
    let fausSwitchOnlineFactory: FausSwitchOnlineFactory
    private let sessionCoordinator: AppSessionCoordinator
    private let fausCrewCoordinator: FausCrewCoordinator
    private let dashboardCoordinator: DashboardCoordinator
    private let profileCoordinator: ProfileCoordinator
    private var storeCancellables = Set<AnyCancellable>()
    private let appEvents: AppEventsService?
    private let network: NetworkService?
    private let pushRegistration: PushRegistrationService?
    /// The selected house's notification panel and unread badge.
    let notificationStore: NotificationStore
    /// The chore archive popup's month list. The view observes it directly, so it is not forwarded
    /// into this object's `objectWillChange`.
    let choreArchiveStore: ChoreArchiveStore
    /// The dashboard stats card's standings. Observed directly by the card, like the archive.
    let gameStatsStore: GameStatsStore
    private let choreReminderStore: ChoreReminderStore
    /// Walks a tapped push to its screen; also owns the selected tab and the open-game flag.
    let pushRouteHandler: PushRouteHandler

    var signupSuccessMessage: String? { sessionCoordinator.signupSuccessMessage }

    /// The server-assigned ID of the logged-in user (used to gate chore status edits).
    var currentUserId: String? { authStore.currentUserId }

    /// Full server profile of the logged-in user (used for profile display & edit).
    var currentUserProfile: IsAuthUserData? { authStore.currentUserProfile }

    var availableHouses: [AuthHouseSummary] {
        authStore.currentUserProfile?.houseList ?? []
    }

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

    var houseError: String? {
        get { houseStore.houseError }
        set { houseStore.houseError = newValue }
    }

    var toastMessage: String? { toastStore.message }
    var toastIsError: Bool { toastStore.isError }

    /// Set to true whenever a modal / popup is covering the screen so the tab bar hides.
    var isOverlayPresented: Bool {
        get { overlayStore.isPresented }
        set { overlayStore.setPresented(newValue) }
    }

    convenience init() {
        self.init(dependencies: .live())
    }

    convenience init(dependencies: AppDependencies) {
        self.init(
            keychain: dependencies.keychain,
            authStore: AuthSessionStore(
                keychain: dependencies.keychain,
                authService: dependencies.authService,
                userService: dependencies.userService,
                sessionRestorer: dependencies.sessionRestorer,
                socialAuthService: dependencies.socialAuthService,
                socialCredentials: dependencies.socialCredentials,
                socialConfig: dependencies.socialConfig
            ),
            toastStore: ToastStore(),
            overlayStore: OverlayStore(),
            houseStore: HouseSessionStore(
                houseService: dependencies.houseService,
                userDefaults: dependencies.userDefaults
            ),
            dashboardStore: DashboardStore(),
            choreStore: ChoreStore(choreService: dependencies.choreService),
            localizationStore: LocalizationStore(
                service: dependencies.localizationService,
                cache: dependencies.localizationCache
            ),
            userDefaults: dependencies.userDefaults,
            choreCatalogStore: ChoreCatalogStore(service: dependencies.choreCatalogService),
            houseRocketsSessionFactory: dependencies.houseRocketsSessionFactory,
            houseTanksOnlineFactory: dependencies.houseTanksOnlineFactory,
            fausSwitchOnlineFactory: dependencies.fausSwitchOnlineFactory,
            appEvents: dependencies.appEvents,
            network: dependencies.network,
            pushRegistration: dependencies.pushRegistration,
            notificationService: dependencies.notificationService,
            choreArchiveService: dependencies.choreArchiveService,
            gameStatsService: dependencies.gameStatsService,
            pushInbox: dependencies.pushInbox,
            pushCenter: dependencies.pushCenter
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
        userDefaults: any PreferencesStore,
        choreCatalogStore: ChoreCatalogStore? = nil,
        houseRocketsSessionFactory: HouseRocketsSessionFactory? = nil,
        houseTanksOnlineFactory: HouseTanksOnlineFactory = .unavailable,
        fausSwitchOnlineFactory: FausSwitchOnlineFactory = .unavailable,
        appEvents: AppEventsService? = nil,
        network: NetworkService? = nil,
        pushRegistration: PushRegistrationService? = nil,
        notificationService: (any NotificationServicing)? = nil,
        choreArchiveService: (any ChoreArchiveServicing)? = nil,
        gameStatsService: (any GameStatsServicing)? = nil,
        pushInbox: PushInbox? = nil,
        pushCenter: PushNotificationCenter? = nil
    ) {
        self.appEvents = appEvents
        self.network = network
        self.pushRegistration = pushRegistration
        self.authStore = authStore
        self.toastStore = toastStore
        self.overlayStore = overlayStore
        self.houseStore = houseStore
        self.dashboardStore = dashboardStore
        self.choreStore = choreStore
        self.localizationStore = localizationStore
        self.choreCatalogStore = choreCatalogStore ?? ChoreCatalogStore(service: nil)
        self.houseRocketsSessionFactory = houseRocketsSessionFactory ?? .localOnly
        self.houseTanksOnlineFactory = houseTanksOnlineFactory
        self.fausSwitchOnlineFactory = fausSwitchOnlineFactory
        notificationStore = NotificationStore(service: notificationService, preferences: userDefaults)
        choreArchiveStore = ChoreArchiveStore(service: choreArchiveService) { [dashboardStore, localizationStore] dto in
            dashboardStore.chore(from: dto, unassignedName: localizationStore.value(for: "common_unassigned"))
        }
        gameStatsStore = GameStatsStore(service: gameStatsService)
        choreReminderStore = ChoreReminderStore(
            service: notificationService,
            toastStore: toastStore,
            localizationStore: localizationStore,
            currentUserID: { authStore.currentUserId }
        )

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
            },
            socialSignInAction: { provider in
                await sessionCoordinator.socialSignIn(provider)
            }
        )
        let fausCrewCoordinator = FausCrewCoordinator(
            authStore: authStore,
            houseStore: houseStore,
            localizationStore: localizationStore,
            toastStore: toastStore,
            router: router
        )
        self.fausCrewCoordinator = fausCrewCoordinator
        pushRouteHandler = PushRouteHandler(
            snapshot: { Self.routeSnapshot(authStore: authStore, houseStore: houseStore, router: router, overlayStore: overlayStore) },
            switchHouse: { houseID in
                guard let house = authStore.currentUserProfile?.houseList.first(where: { $0.houseId == houseID }) else { return }
                Task { await fausCrewCoordinator.switchHouse(to: house) }
            },
            inbox: pushInbox
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
            houseStore: houseStore,
            localizationStore: localizationStore,
            toastStore: toastStore
        )

        bindStoreChanges()
        bindAppEvents()
        bindPushRegistration()
        bindNotifications(pushCenter: pushCenter)
        bindPushRouting()
    }

    /// Binds session rejection and keeps the events socket tied to app state.
    private func bindAppEvents() {
        sessionCoordinator.onSessionRejected = { [weak self] in self?.logout(reason: .sessionRejected) }
        network?.onUnauthorized = { [weak sessionCoordinator] token in
            sessionCoordinator?.handleRejectedToken(token)
        }
        guard let appEvents else { return }
        appEvents.onRefresh = { [weak self] profile, houseID in
            await self?.sessionCoordinator.refreshForAppEvent(profile: profile, houseID: houseID)
        }
        appEvents.onSignedOut = { [weak self] in self?.logout(reason: .sessionRejected) }
        authStore.$isAuthenticated
            .removeDuplicates()
            .sink { appEvents.setAuthenticated($0) }
            .store(in: &storeCancellables)
        houseStore.$currentHouseDetails
            .map { $0?.id }
            .removeDuplicates()
            .sink { appEvents.setSelectedHouse($0) }
            .store(in: &storeCancellables)
    }

    /// Starts push registration and tells it who is fully signed in (the user id, else nil).
    private func bindPushRegistration() {
        guard let pushRegistration else { return }
        pushRegistration.start()
        Publishers.CombineLatest(authStore.$isAuthenticated, authStore.$currentUserId)
            .map { $0 ? $1 : nil }
            .removeDuplicates()
            .sink { pushRegistration.setSession(userID: $0) }
            .store(in: &storeCancellables)
    }

    /// Keeps the notification badge on the signed-in user's selected house and refreshes it when
    /// the events socket or a foreground push says something new arrived.
    private func bindNotifications(pushCenter: PushNotificationCenter?) {
        notificationStore.onAccessLost = { [weak self] in
            Task { await self?.sessionCoordinator.refreshForAppEvent(profile: true, houseID: nil) }
        }
        choreArchiveStore.onAccessLost = { [weak self] in
            Task { await self?.sessionCoordinator.refreshForAppEvent(profile: true, houseID: nil) }
        }
        gameStatsStore.onAccessLost = { [weak self] in
            Task { await self?.sessionCoordinator.refreshForAppEvent(profile: true, houseID: nil) }
        }
        choreReminderStore.onChoreNotFound = { [weak self] in
            guard let self, let houseID = self.houseStore.currentHouseDetails?.id else { return }
            Task { await self.sessionCoordinator.refreshForAppEvent(profile: false, houseID: houseID) }
        }
        appEvents?.onNotificationsChanged = { [weak self] houseID in
            self?.notificationStore.notificationsChanged(houseID: houseID)
        }
        pushCenter?.onForegroundNotification = { [weak self] data in
            self?.notificationStore.notificationsChanged(houseID: data["houseId"])
        }
        Publishers.CombineLatest3(
            authStore.$isAuthenticated,
            authStore.$currentUserId,
            houseStore.$currentHouseDetails.map { $0?.id }.removeDuplicates()
        )
        .sink { [weak self] authenticated, userID, houseID in
            self?.notificationStore.setContext(userID: authenticated ? userID : nil, houseID: authenticated ? houseID : nil)
            self?.choreArchiveStore.setContext(userID: authenticated ? userID : nil, houseID: authenticated ? houseID : nil)
            self?.gameStatsStore.setContext(userID: authenticated ? userID : nil, houseID: authenticated ? houseID : nil)
        }
        .store(in: &storeCancellables)
    }

    /// Re-evaluates the pending push whenever anything it depends on changes: app state, the
    /// router, an overlay, or the handler's own tab/game state.
    private func bindPushRouting() {
        Publishers.MergeMany(
            objectWillChange.eraseToAnyPublisher(),
            router.objectWillChange.map { _ in }.eraseToAnyPublisher(),
            overlayStore.objectWillChange.map { _ in }.eraseToAnyPublisher(),
            pushRouteHandler.objectWillChange.eraseToAnyPublisher()
        )
        .sink { [weak self] _ in
            // `objectWillChange` fires before the change lands; evaluate once it has.
            Task { self?.pushRouteHandler.evaluate() }
        }
        .store(in: &storeCancellables)
        pushRouteHandler.start()
    }

    private static func routeSnapshot(
        authStore: AuthSessionStore,
        houseStore: HouseSessionStore,
        router: AppRouter,
        overlayStore: OverlayStore
    ) -> PushRouteHandler.Snapshot {
        var isLoading = false
        if case .houseLoading = router.route { isLoading = true }
        return PushRouteHandler.Snapshot(
            isSignedIn: authStore.isAuthenticated && authStore.currentUserId != nil,
            houseIDs: authStore.currentUserProfile?.houseList.map(\.houseId),
            selectedHouseID: houseStore.currentHouseDetails?.id,
            isSwitchingHouse: isLoading,
            isDashboardRoute: router.route == .dashboard,
            isOverlayPresented: overlayStore.isPresented,
            loadedChoreIDs: houseStore.currentHouseDetails.map { Set($0.chores.map(\.id)) }
        )
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

        choreReminderStore.objectWillChange
            .sink { [weak self] _ in
                self?.objectWillChange.send()
            }
            .store(in: &storeCancellables)
    }

    func completeOnboarding() {
        sessionCoordinator.completeOnboarding()
    }

    // MARK: - Scene Phase Handlers

    /// Call when the app moves to the background.
    func handleBackground() {
        appEvents?.setForeground(false)
        sessionCoordinator.handleBackground()
    }

    /// Call when the app returns to the foreground.
    /// Only triggers the auth/data refresh if the app was backgrounded long enough.
    /// Cold-start auth is handled separately by `performAutoLogin()` via `.task`.
    func handleForeground() async {
        appEvents?.setForeground(true)
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

    func localized(_ key: String, tr: String, en: String) -> String {
        localizationStore.value(for: key, tr: tr, en: en)
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

    func saveLanguagePreferenceAndRequireLogin(prefix: String) async throws {
        try await profileCoordinator.saveLanguagePreferenceAndRequireLogin(
            prefix: prefix,
            onRequireLogin: { [weak self] in self?.logout(reason: .userInitiated) }
        )
    }

    // MARK: - Auto Login

    /// Called on app foreground. If a valid token is stored, silently authenticates
    /// and navigates straight to the dashboard. No-op if already authenticated.
    func performAutoLogin() async {
        await sessionCoordinator.performAutoLogin()
    }

    func retryHouseLoading() async {
        if isAuthenticated {
            await fausCrewCoordinator.reloadPreferredHouse()
        } else {
            await sessionCoordinator.performAutoLogin()
        }
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
        fausCrewCoordinator.showCreateHouseScreen()
    }
    
    func backToHouseSelection() {
        fausCrewCoordinator.backToHouseSelection()
    }
    
    func showJoinHouseScreen() {
        fausCrewCoordinator.showJoinHouseScreen()
    }

    // MARK: - User Profile Update

    func updateProfile(_ request: UpdateProfileRequest) async throws {
        try await profileCoordinator.updateProfile(request)
    }

    func fetchProfileImages(category: String) async throws -> GetImagesResponse {
        try await profileCoordinator.fetchProfileImages(category: category)
    }

    func fetchHouseInfo(houseId: String) async throws -> HouseInfoData {
        try await profileCoordinator.fetchHouseInfo(houseId: houseId)
    }

    func fetchHouseProfileImages() async throws -> GetImagesResponse {
        try await profileCoordinator.fetchHouseProfileImages()
    }

    func createHouseInviteCode(houseId: String) async throws -> HouseInviteCodeData {
        try await profileCoordinator.createHouseInviteCode(houseId: houseId)
    }

    func joinHouseFromProfile(inviteCode: String) async throws -> HouseResponse {
        try await profileCoordinator.joinHouse(inviteCode: inviteCode)
    }

    func createHouseFromProfile(name: String, type: Int, maxMemberCount: Int) async throws -> HouseResponse {
        try await profileCoordinator.createHouse(name: name, type: type, maxMemberCount: maxMemberCount)
    }

    var canAddHouse: Bool {
        HouseCreationRules.canAddHouse(currentHouseCount: availableHouses.count)
    }

    func updateHouseProfile(
        houseId: String,
        name: String,
        memberCountLimit: Int,
        profileImage: String,
        houseType: Int,
        isChoreReviewPhotoRequired: Bool? = nil
    ) async throws -> HouseInfoData {
        try await profileCoordinator.updateHouseProfile(
            houseId: houseId,
            name: name,
            memberCountLimit: memberCountLimit,
            profileImage: profileImage,
            houseType: houseType,
            isChoreReviewPhotoRequired: isChoreReviewPhotoRequired
        )
    }

    func removeHouseMember(houseId: String, userId: String) async throws {
        try await profileCoordinator.removeHouseMember(houseId: houseId, userId: userId)
    }

    func leaveHouse(houseId: String) async throws {
        try await fausCrewCoordinator.leaveHouse(houseId: houseId)
    }

    func completeBirthdaySetup(with birthDate: Date) async throws {
        try await sessionCoordinator.completeBirthdaySetup(with: birthDate)
    }

    // MARK: - House API (Full Flow)

    /// Full create-house flow: shows loading screen → POST → GET details → dashboard.
    /// On any error, navigates back to CreateHouseView and shows a toast.
    func beginCreateFausCrew(name: String, type: Int, maxMemberCount: Int) async {
        await fausCrewCoordinator.beginCreateFausCrew(
            name: name,
            type: type,
            maxMemberCount: maxMemberCount
        )
    }

    /// Full join-house flow: shows loading screen → POST → GET details → dashboard.
    /// On any error, navigates back to JoinHouseView and shows a toast.
    func beginJoinFausCrew(inviteCode: String) async {
        await fausCrewCoordinator.beginJoinFausCrew(inviteCode: inviteCode)
    }

    func switchHouse(to house: AuthHouseSummary) async {
        await fausCrewCoordinator.switchHouse(to: house)
    }

    // MARK: - Toast

    func showToast(message: String, isError: Bool = true) {
        toastStore.show(message: message, isError: isError)
    }

    /// Push cleanup runs first: a user-initiated sign-out still needs the stored JWT.
    func logout(reason: PushSignOutReason) {
        pushRegistration?.signOut(reason: reason)
        pushRouteHandler.clear()
        choreReminderStore.clear()
        notificationStore.setContext(userID: nil, houseID: nil)
        choreArchiveStore.setContext(userID: nil, houseID: nil)
        sessionCoordinator.logout { [fausCrewCoordinator, dashboardCoordinator] in
            fausCrewCoordinator.resetSession()
            dashboardCoordinator.clearSession()
        }
    }

    // MARK: - Social sign-in

    var socialAuthStore: AuthSessionStore { authStore }

    func completeSocialSignUp(email: String, code: String, firstName: String, lastName: String) async throws(SocialStepError) {
        try await sessionCoordinator.completeSocialSignUp(
            email: email, code: code, firstName: firstName, lastName: lastName
        )
    }

    /// Deletes the account on the backend, then wipes local state and returns to sign-in.
    func deleteAccount() async throws(SocialStepError) {
        try await authStore.deleteAccount()
        logout(reason: .accountDeleted)
    }

    func cancelEmailVerification() {
        logout(reason: .userInitiated)
    }

    // MARK: - Announcement API

    @discardableResult
    func createAnnouncement(title: String, description: String) async -> Bool {
        await dashboardCoordinator.createAnnouncement(title: title, description: description)
    }

    // MARK: - Chore API

    /// Creates a chore via the API, then merges the returned chore into dashboard state.
    /// Returns whether the backend accepted it (failures are also surfaced as a toast).
    @discardableResult
    func createChore(
        assignedToId: String,
        description: String,
        dueDate: Date,
        houseId: String,
        isRecurring: Bool,
        level: ChoreLevel,
        recurringInterval: Int,
        title: String,
        category: ChoreCategoryKind
    ) async -> Bool {
        await dashboardCoordinator.createChore(
            assignedToId: assignedToId,
            description: description,
            dueDate: dueDate,
            houseId: houseId,
            isRecurring: isRecurring,
            level: level,
            recurringInterval: recurringInterval,
            title: title,
            category: category
        )
    }

    /// Updates the status of a single chore via the API, then merges the returned chore.
    /// `reviewPhoto` is sent (multipart) only for InTest while the house requires it.
    func updateChoreStatus(
        choreApiId: String,
        houseId: String,
        status: ChoreStatus,
        reviewPhoto: Data? = nil
    ) async -> Bool {
        await dashboardCoordinator.updateChoreStatus(
            choreApiId: choreApiId,
            houseId: houseId,
            status: status,
            reviewPhoto: reviewPhoto
        )
    }

    func isChoreReminded(choreApiId: String) -> Bool {
        choreReminderStore.isReminded(choreApiId)
    }

    func isRemindingChore(choreApiId: String) -> Bool {
        choreReminderStore.isSending(choreApiId)
    }

    /// Sends the reminder; the outcome shows as a toast and in `isChoreReminded`.
    func remindChore(choreApiId: String) async {
        await choreReminderStore.remind(choreID: choreApiId)
    }

    func isChoreReviewPhotoRequired(houseId: String?) -> Bool {
        dashboardCoordinator.isChoreReviewPhotoRequired(houseId: houseId)
    }

    /// Lazily loads one round's review photo; nil after an error toast.
    func loadChoreReviewPhoto(choreApiId: String, round: Int) async -> Data? {
        await dashboardCoordinator.loadReviewPhoto(choreApiId: choreApiId, round: round)
    }

    /// Submits the current user's vote for an in-review chore.
    func reviewChore(choreApiId: String, isApproved: Bool) async -> Bool {
        await dashboardCoordinator.reviewChore(
            choreApiId: choreApiId,
            isApproved: isApproved
        )
    }

}
