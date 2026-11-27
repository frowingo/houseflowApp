import Foundation
import FausCrewCore

/// Owns the application's production dependency graph.
/// Services share network/keychain; a separate game URL can be injected for tests.
struct AppDependencies {
    let keychain: any KeychainStoring
    let authService: any AuthServicing
    let sessionRestorer: (any SessionRestoring)?
    var socialAuthService: (any SocialAuthServicing)? = nil
    var socialCredentials: (any SocialCredentialProviding)? = nil
    var socialConfig = SocialAuthConfig(enabledProviders: [])
    let userService: any UserServicing
    let houseService: any HouseServicing
    let choreService: any ChoreServicing
    /// `chore/catalog`; nil in tests that do not need it (the catalog then shows its error state).
    var choreCatalogService: (any ChoreCatalogServicing)? = nil
    let localizationService: any LocalizationServicing
    let userDefaults: any PreferencesStore
    let localizationCache: any LocalizationCacheStore
    let houseRocketsSessionFactory: HouseRocketsSessionFactory
    var houseTanksOnlineFactory = HouseTanksOnlineFactory.unavailable
    var fausSwitchOnlineFactory = FausSwitchOnlineFactory.unavailable
    /// The `/api/v1/events` refresh channel; nil in tests that do not need it.
    var appEvents: AppEventsService? = nil
    /// The shared decoded REST client; nil in tests that do not need it.
    var network: NetworkService? = nil
    /// FCM token registration with the backend; nil in tests that do not need it.
    var pushRegistration: PushRegistrationService? = nil
    /// The house notification panel and chore reminders; nil in tests that do not need them.
    var notificationService: (any NotificationServicing)? = nil
    /// The chore archive's paged history; nil in tests that do not need it.
    var choreArchiveService: (any ChoreArchiveServicing)? = nil
    /// The dashboard's game standings; nil in tests that do not need them.
    var gameStatsService: (any GameStatsServicing)? = nil
    /// Where a tapped push waits for the app, and where foreground pushes arrive; nil in tests.
    var pushInbox: PushInbox? = nil
    var pushCenter: PushNotificationCenter? = nil

    static func live(gameBaseURL: URL? = nil) -> AppDependencies {
        let keychain = KeychainService()
        let network = NetworkService()
        let gameURL = gameBaseURL ?? AppEnvironment.baseURL
        let gameNetwork = gameBaseURL == nil ? network : NetworkService(baseURL: gameURL)

        let credentials = SocialCredentialRouter(adapters: [
            .google: GoogleCredentialProvider(),
            .apple: AppleCredentialProvider(),
            .facebook: FacebookCredentialProvider(),
            .snapchat: SnapchatCredentialProvider(),
        ])

        return AppDependencies(
            keychain: keychain,
            authService: AuthService(network: network, keychain: keychain),
            sessionRestorer: SessionRestoreAdapter(
                useCase: RestoreSessionUseCase(httpClient: network, secureStore: keychain)
            ),
            socialAuthService: SocialAuthService(http: network, keychain: keychain),
            socialCredentials: credentials,
            socialConfig: SocialAuthConfig.load(),
            userService: UserService(network: network, keychain: keychain),
            houseService: HouseService(network: network, keychain: keychain),
            choreService: ChoreService(network: network, keychain: keychain),
            choreCatalogService: ChoreCatalogService(http: network, keychain: keychain),
            localizationService: LocalizationService(network: network),
            userDefaults: UserDefaults.standard,
            localizationCache: LocalizationDiskCache(),
            houseRocketsSessionFactory: .live(network: gameNetwork, keychain: keychain, baseURL: gameURL),
            houseTanksOnlineFactory: .live(network: gameNetwork, keychain: keychain, baseURL: gameURL),
            fausSwitchOnlineFactory: .live(network: gameNetwork, keychain: keychain, baseURL: gameURL),
            appEvents: AppEventsService(baseURL: AppEnvironment.baseURL, keychain: keychain),
            network: network,
            pushRegistration: PushRegistrationService(http: network, keychain: keychain, tokens: FirebasePushTokenProvider()),
            notificationService: NotificationService(
                http: network,
                keychain: keychain,
                onUnauthorized: { [weak network] token in network?.onUnauthorized?(token) }
            ),
            choreArchiveService: ChoreArchiveService(
                http: network,
                keychain: keychain,
                onUnauthorized: { [weak network] token in network?.onUnauthorized?(token) }
            ),
            gameStatsService: GameStatsService(
                http: network,
                keychain: keychain,
                onUnauthorized: { [weak network] token in network?.onUnauthorized?(token) }
            ),
            pushInbox: .shared,
            pushCenter: .shared
        )
    }
}
