import Foundation
import FausCrewCore

typealias FausSwitchOnlineHost = GameOnlineHost<FausSwitchOnlineEngine>

extension FausSwitchOnlineEngine: GameOnlineHostedEngine {
    static var gameKey: String { GameKey.fausSwitch }
    var lobbyIssue: GameOnlineLobbyIssue? { lobby.issue }
}

extension GameOnlineHost where Engine == FausSwitchOnlineEngine {
    /// Whole seconds left on the room's current deadline, on the server clock.
    func roomCountdown() -> Int? {
        isDisposed ? nil : engine.roomCountdown(at: uptime)
    }
}

/// Stores constructors, never an active session: each room visit owns its host.
struct FausSwitchOnlineFactory {
    /// One host (and Core engine) per room visit; `excludingSessionID` is set for a
    /// rematch and `preferredColor` is the robot color asked for in the lobby.
    typealias MakeHost = @MainActor (_ context: GameLaunchContext, _ excludingSessionID: String?,
                                     _ preferredColor: FausSwitchColor?) -> FausSwitchOnlineHost

    var makeHost: MakeHost?
    var loadCatalog: (@MainActor (_ houseID: String) async throws -> GameCatalog)?

    static var unavailable: Self { Self(makeHost: nil, loadCatalog: nil) }

    @MainActor
    static func live(network: any HTTPRequestExecuting, keychain: any KeychainStoring, baseURL: URL) -> Self {
        let sessions = GameSessionService(network: network, keychain: keychain, baseURL: baseURL)
        let io = LiveGameOnlineIO(network: network, keychain: keychain, baseURL: baseURL)
        return Self(makeHost: { context, excluded, color in
            FausSwitchOnlineHost(engine: FausSwitchOnlineEngine(context: context, excludingSessionID: excluded,
                                                                preferredColor: color), io: io)
        }, loadCatalog: { try await sessions.gameCatalog(houseID: $0) })
    }
}
