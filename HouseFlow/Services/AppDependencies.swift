import Foundation

/// Owns the application's production dependency graph.
/// All services in one graph share the same network transport and keychain.
struct AppDependencies {
    let keychain: any KeychainStoring
    let authService: any AuthServicing
    let userService: any UserServicing
    let houseService: any HouseServicing
    let choreService: any ChoreServicing
    let localizationService: any LocalizationServicing
    let userDefaults: UserDefaults
    let localizationCache: LocalizationDiskCache

    static func live() -> AppDependencies {
        let keychain = KeychainService()
        let network = NetworkService()

        return AppDependencies(
            keychain: keychain,
            authService: AuthService(network: network, keychain: keychain),
            userService: UserService(network: network, keychain: keychain),
            houseService: HouseService(network: network, keychain: keychain),
            choreService: ChoreService(network: network, keychain: keychain),
            localizationService: LocalizationService(network: network),
            userDefaults: .standard,
            localizationCache: LocalizationDiskCache()
        )
    }
}
