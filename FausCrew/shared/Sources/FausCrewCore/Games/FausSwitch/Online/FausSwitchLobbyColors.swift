import Foundation

/// The robot colors players hold in the online lobby (`sessionSnapshot.lobbyState`,
/// ADR-030), as every platform shows them. The server owns the picks: the first claim
/// of a color wins and a claim of a held color changes nothing, so a player's color is
/// always read from here, never from the request they sent.
public struct FausSwitchLobbyColors: Equatable, Sendable {
    /// Player id → claimed color, for players still in the session only (a leaver's
    /// stale claim may stay in the field until the next pick; its color is free).
    public let claims: [String: FausSwitchColor]
    public let localPlayerID: String?
    /// The local player is ready: their color is fixed until they take the ready back.
    public let isLocked: Bool

    public init(session: GameSessionDTO?, localPlayerID: String?) {
        self.localPlayerID = localPlayerID
        let raw = session?.lobbyState?.colors ?? [:]
        var claims: [String: FausSwitchColor] = [:]
        var held = Set<FausSwitchColor>()
        // Seat (join) order, like the server's race colors: the earlier seat keeps a color
        // two claims share; unknown colors are no claim.
        for player in session?.players ?? [] where player.state != .left {
            guard let color = raw[player.playerId].flatMap(FausSwitchColor.init(rawValue:)), !held.contains(color) else {
                continue
            }
            claims[player.playerId] = color
            held.insert(color)
        }
        self.claims = claims
        isLocked = session?.players.contains { $0.playerId == localPlayerID && $0.state == .ready } ?? false
    }

    public func color(of playerID: String) -> FausSwitchColor? { claims[playerID] }

    /// The local player's claimed color.
    public var localClaim: FausSwitchColor? { localPlayerID.flatMap { claims[$0] } }

    /// Colors other players hold; the local player cannot take them.
    public var takenByOthers: Set<FausSwitchColor> {
        Set(claims.filter { $0.key != localPlayerID }.values)
    }

    public func isTakenByOthers(_ color: FausSwitchColor) -> Bool { takenByOthers.contains(color) }

    /// The color the lobby shows as the local player's. `preferred` is what they picked:
    /// while nobody else holds it the engine claims it (it may still be on its way), so it
    /// shows; once another player holds it, the server kept the local claim (or none, and
    /// the race gives the first free color).
    public func localColor(preferred: FausSwitchColor?) -> FausSwitchColor? {
        if let preferred, !isTakenByOthers(preferred) { return preferred }
        return localClaim
    }

    /// True when the local player's pick is held by someone else, so they should pick again.
    public func isPreferredTaken(_ preferred: FausSwitchColor?) -> Bool {
        preferred.map(isTakenByOthers) ?? false
    }
}

extension GameOnlineLobbyState where Game == FausSwitchRealtime {
    /// The lobby's robot colors for `localPlayerID`.
    public func lobbyColors(localPlayerID: String?) -> FausSwitchLobbyColors {
        FausSwitchLobbyColors(session: session, localPlayerID: localPlayerID)
    }
}
