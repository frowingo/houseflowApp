import Foundation

enum AppEnvironment {
    // The application's only backend is production.
    static let baseURL = URL(string: "https://houseflowapi.fly.dev/api/v1")!
}
