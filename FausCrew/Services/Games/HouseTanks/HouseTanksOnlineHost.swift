import Foundation
import FausCrewCore

typealias HouseTanksOnlineHost = GameOnlineHost<HouseTanksOnlineEngine>

extension HouseTanksOnlineEngine: GameOnlineHostedEngine {
    static var gameKey: String { GameKey.houseTanks }
    var lobbyIssue: GameOnlineLobbyIssue? { lobby.issue }
}

extension GameOnlineHost where Engine == HouseTanksOnlineEngine {
    /// Whole seconds left on the room's current deadline, on the server clock.
    func roomCountdown() -> Int? {
        isDisposed ? nil : engine.roomCountdown(at: uptime)
    }
}

/// Stores constructors, never an active session: each room visit owns its host.
struct HouseTanksOnlineFactory {
    /// One host (and Core engine) per room visit; `excludingSessionID` is set for a rematch.
    var makeHost: (@MainActor (_ context: GameLaunchContext, _ excludingSessionID: String?) -> HouseTanksOnlineHost)?
    var loadCatalog: (@MainActor (_ houseID: String) async throws -> GameCatalog)?

    static var unavailable: Self { Self(makeHost: nil, loadCatalog: nil) }

    @MainActor
    static func live(network: any HTTPRequestExecuting, keychain: any KeychainStoring, baseURL: URL) -> Self {
        let sessions = GameSessionService(network: network, keychain: keychain, baseURL: baseURL)
        let io = LiveGameOnlineIO(network: network, keychain: keychain, baseURL: baseURL)
        return Self(makeHost: { context, excluded in
            HouseTanksOnlineHost(engine: HouseTanksOnlineEngine(context: context, excludingSessionID: excluded), io: io)
        }, loadCatalog: { try await sessions.gameCatalog(houseID: $0) })
    }
}
