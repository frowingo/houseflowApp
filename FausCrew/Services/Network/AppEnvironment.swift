import Foundation

enum AppEnvironment {
    case development
    case production

    var baseURL: URL {
        switch self {
        case .development:
            // Demo API — active for testing
            return URL(string: "https://houseflowapi.fly.dev/api/v1")!
        case .production:
            // Production URL — to be configured
            return URL(string: "https://api.houseflow.app/api/v1")!
        }
    }

    // Default environment. Switch to .production when ready.
    static let current: AppEnvironment = .development
}
