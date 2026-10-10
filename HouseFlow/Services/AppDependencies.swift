import Foundation
import HouseFlowCore

/// Owns the application's production dependency graph.
/// Services share network/keychain; a separate game URL can be injected for local/staging.
struct AppDependencies {
    let keychain: any KeychainStoring
    let authService: any AuthServicing
    let userService: any UserServicing
    let houseService: any HouseServicing
    let choreService: any ChoreServicing
    let localizationService: any LocalizationServicing
    let userDefaults: any PreferencesStore
    let localizationCache: any LocalizationCacheStore
    let houseRocketsSessionFactory: HouseRocketsSessionFactory

    static func live(gameBaseURL: URL? = nil) -> AppDependencies {
        let keychain = KeychainService()
        let network = NetworkService()
        let gameURL = gameBaseURL ?? AppEnvironment.current.baseURL
        let gameNetwork = gameBaseURL == nil ? network : NetworkService(baseURL: gameURL)

        return AppDependencies(
            keychain: keychain,
            authService: AuthService(network: network, keychain: keychain),
            userService: UserService(network: network, keychain: keychain),
            houseService: HouseService(network: network, keychain: keychain),
            choreService: ChoreService(network: network, keychain: keychain),
            localizationService: LocalizationService(network: network),
            userDefaults: UserDefaults.standard,
            localizationCache: LocalizationDiskCache(),
            houseRocketsSessionFactory: .live(network: gameNetwork, keychain: keychain, baseURL: gameURL)
        )
    }
}
