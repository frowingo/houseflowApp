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
final class AppRouter: ObservableObject {
    @Published private(set) var route: AppRoute
    @Published var navigationDirection: NavigationDirection = .forward

    private let userDefaults: UserDefaults
    private let isAuthenticated: () -> Bool
    private let pendingEmailVerification: () -> String?

    init(
        hasAuthToken: Bool,
        pendingEmailVerification initialPendingEmail: String?,
        userDefaults: UserDefaults = .standard,
        isAuthenticated: @escaping () -> Bool,
        pendingEmailVerification: @escaping () -> String?
    ) {
        self.userDefaults = userDefaults
        self.isAuthenticated = isAuthenticated
        self.pendingEmailVerification = pendingEmailVerification
        route = Self.initialRoute(
            hasAuthToken: hasAuthToken,
            hasSeenOnboarding: userDefaults.bool(forKey: "hasSeenOnboarding"),
            pendingEmailVerification: initialPendingEmail
        )
    }

    var houseLoadingPhase: HouseLoadingPhase {
        guard case .houseLoading(let phase) = route else { return .checkingAuth }
        return phase
    }

    func completeOnboarding(needsBirthdaySetup: Bool) {
        userDefaults.set(true, forKey: "hasSeenOnboarding")
        navigationDirection = .forward

        if let email = pendingEmailVerification() {
            route = .emailVerification(email: email)
        } else if needsBirthdaySetup {
            route = .birthdaySetup
        } else {
            route = .authentication
        }
    }

    func navigate(to destination: AppRoute, respectingOnboarding: Bool = true) {
        guard !destination.requiresAuthenticatedSession || isAuthenticated() else {
            showUnauthenticatedEntry()
            return
        }

        if respectingOnboarding, !hasSeenOnboarding {
            route = .onboarding
        } else {
            route = destination
        }
    }

    func showUnauthenticatedEntry() {
        if !hasSeenOnboarding {
            route = .onboarding
        } else if let email = pendingEmailVerification() {
            route = .emailVerification(email: email)
        } else {
            route = .authentication
        }
    }

    static func initialRoute(
        hasAuthToken: Bool,
        hasSeenOnboarding: Bool,
        pendingEmailVerification: String?
    ) -> AppRoute {
        if hasAuthToken {
            return .houseLoading(.checkingAuth)
        }
        if !hasSeenOnboarding {
            return .onboarding
        }
        if let pendingEmailVerification {
            return .emailVerification(email: pendingEmailVerification)
        }
        return .authentication
    }

    private var hasSeenOnboarding: Bool {
        userDefaults.bool(forKey: "hasSeenOnboarding")
    }
}
