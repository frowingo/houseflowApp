import Foundation

/// Stores constructors, never an active session. Each screen owns its session.
struct HouseRocketsSessionFactory {
    let makeBotSession: @MainActor () -> any HouseRocketsGameServicing

    /// Online transport is added after the shared protocol and fixtures are fixed.
    static var localOnly: Self {
        Self(makeBotSession: { DemoHouseRocketsSession() })
    }
}
