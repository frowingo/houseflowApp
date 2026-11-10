import Foundation

/// The rocket colors players hold in the online lobby (`GameLobbyColors`).
public typealias HouseRocketsLobbyColors = GameLobbyColors<HouseRocketsColor>

extension GameOnlineLobbyState where Game == HouseRocketsRealtime {
    /// The lobby's rocket colors for `localPlayerID`.
    public func lobbyColors(localPlayerID: String?) -> HouseRocketsLobbyColors {
        HouseRocketsLobbyColors(session: session, localPlayerID: localPlayerID)
    }

    /// The color the room shows for a participant: the server's rocket once the flight
    /// seats them, before that the lobby claim (the local player's pick while it is free).
    public func memberColor(of playerID: String, localPlayerID: String?,
                            preferred: HouseRocketsColor?) -> HouseRocketsColor? {
        if let seated = game?.players.first(where: { $0.playerId == playerID }) { return seated.color }
        let colors = lobbyColors(localPlayerID: localPlayerID)
        return playerID == localPlayerID ? colors.localColor(preferred: preferred) : colors.color(of: playerID)
    }
}
