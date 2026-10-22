import Foundation
import FausCrewCore

/// Owns the application's production dependency graph.
/// Services share network/keychain; a separate game URL can be injected for local/staging.
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
    let localizationService: any LocalizationServicing
    let userDefaults: any PreferencesStore
    let localizationCache: any LocalizationCacheStore
    let houseRocketsSessionFactory: HouseRocketsSessionFactory
    /// The `/api/v1/events` refresh channel; nil in tests that do not need it.
    var appEvents: AppEventsService? = nil

    static func live(gameBaseURL: URL? = nil) -> AppDependencies {
        let keychain = KeychainService()
        let network = NetworkService()
        let gameURL = gameBaseURL ?? AppEnvironment.current.baseURL
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
            localizationService: LocalizationService(network: network),
            userDefaults: UserDefaults.standard,
            localizationCache: LocalizationDiskCache(),
            houseRocketsSessionFactory: .live(network: gameNetwork, keychain: keychain, baseURL: gameURL),
            appEvents: AppEventsService(baseURL: AppEnvironment.current.baseURL, keychain: keychain)
        )
    }
}
