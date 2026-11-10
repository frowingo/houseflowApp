import Foundation

/// The tank colors players hold in the online lobby (`GameLobbyColors`).
public typealias HouseTanksLobbyColors = GameLobbyColors<HouseTanksColor>

extension GameOnlineLobbyState where Game == HouseTanksRealtime {
    /// The lobby's tank colors for `localPlayerID`.
    public func lobbyColors(localPlayerID: String?) -> HouseTanksLobbyColors {
        HouseTanksLobbyColors(session: session, localPlayerID: localPlayerID)
    }

    /// The color the room shows for a participant: the server's tank once the match seats
    /// them, before that the lobby claim (the local player's pick while it is free).
    public func memberColor(of playerID: String, localPlayerID: String?,
                            preferred: HouseTanksColor?) -> HouseTanksColor? {
        if let seated = game?.players.first(where: { $0.playerId == playerID }) { return seated.color }
        let colors = lobbyColors(localPlayerID: localPlayerID)
        return playerID == localPlayerID ? colors.localColor(preferred: preferred) : colors.color(of: playerID)
    }
}
