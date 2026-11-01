import Foundation
import FausCrewCore

/// Stores constructors, never an active session. Each screen owns its session.
struct HouseRocketsSessionFactory {
    let makeBotSession: @MainActor () -> any HouseRocketsGameServicing
    /// One host (and Core engine) per online match; `excludingSessionID` is set for a rematch.
    var makeOnlineHost: (@MainActor (_ context: HouseRocketsLaunchContext, _ excludingSessionID: String?)
        -> HouseRocketsOnlineHost)? = nil
    var loadCatalog: (@MainActor (_ houseID: String) async throws -> GameCatalog)? = nil

    static var localOnly: Self {
        Self(makeBotSession: { DemoHouseRocketsSession() })
    }

    @MainActor
    static func live(network: any HTTPRequestExecuting, keychain: any KeychainStoring,
                     baseURL: URL) -> Self {
        let sessions = GameSessionService(network: network, keychain: keychain, baseURL: baseURL)
        let io = LiveHouseRocketsOnlineIO(network: network, keychain: keychain, baseURL: baseURL)
        return Self(makeBotSession: { DemoHouseRocketsSession() }, makeOnlineHost: { context, excluded in
            HouseRocketsOnlineHost(engine: HouseRocketsOnlineEngine(context: context, excludingSessionID: excluded), io: io)
        }, loadCatalog: { try await sessions.gameCatalog(houseID: $0) })
    }
}
