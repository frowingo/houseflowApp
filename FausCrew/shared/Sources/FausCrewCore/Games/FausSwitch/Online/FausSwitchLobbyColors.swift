import Foundation

/// The robot colors players hold in the online lobby (`GameLobbyColors`).
public typealias FausSwitchLobbyColors = GameLobbyColors<FausSwitchColor>

extension GameOnlineLobbyState where Game == FausSwitchRealtime {
    /// The lobby's robot colors for `localPlayerID`.
    public func lobbyColors(localPlayerID: String?) -> FausSwitchLobbyColors {
        FausSwitchLobbyColors(session: session, localPlayerID: localPlayerID)
    }
}
