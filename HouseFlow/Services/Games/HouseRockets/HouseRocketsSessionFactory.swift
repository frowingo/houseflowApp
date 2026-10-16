import Foundation
import HouseFlowCore

/// Stores constructors, never an active session. Each screen owns its session.
struct HouseRocketsSessionFactory {
    let makeBotSession: @MainActor () -> any HouseRocketsGameServicing
    var makeOnlineSession: (@MainActor () -> OnlineHouseRocketsSession)? = nil
    var loadCatalog: (@MainActor (_ houseID: String) async throws -> GameCatalog)? = nil

    static var localOnly: Self {
        Self(makeBotSession: { DemoHouseRocketsSession() })
    }

    @MainActor
    static func live(network: any HTTPRequestExecuting, keychain: any KeychainStoring,
                     baseURL: URL) -> Self {
        let sessions = GameSessionService(network: network, keychain: keychain, baseURL: baseURL)
        return Self(makeBotSession: { DemoHouseRocketsSession() }, makeOnlineSession: {
            OnlineHouseRocketsSession(sessions: sessions, transport: GameRealtimeTransport())
        }, loadCatalog: { try await sessions.gameCatalog(houseID: $0) })
    }
}
