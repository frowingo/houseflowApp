import Foundation

/// The colors players hold in an online lobby (`sessionSnapshot.lobbyState`, ADR-030), as
/// every platform shows them: Faus Switch's robots and Faus Tanks' tanks. The server owns
/// the picks: the first claim of a color wins and a claim of a held color changes nothing,
/// so a player's color is always read from here, never from the request they sent.
public struct GameLobbyColors<Color: RawRepresentable & Hashable & Sendable>: Equatable, Sendable
where Color.RawValue == String {
    /// Player id → claimed color, for players still in the session only (a leaver's
    /// stale claim may stay in the field until the next pick; its color is free).
    public let claims: [String: Color]
    public let localPlayerID: String?
    /// The local player is ready: their color is fixed until they take the ready back.
    public let isLocked: Bool

    public init(session: GameSessionDTO?, localPlayerID: String?) {
        self.localPlayerID = localPlayerID
        let raw = session?.lobbyState?.colors ?? [:]
        var claims: [String: Color] = [:]
        var held = Set<Color>()
        // Seat (join) order, like the server's match colors: the earlier seat keeps a color
        // two claims share; unknown colors are no claim.
        for player in session?.players ?? [] where player.state != .left {
            guard let color = raw[player.playerId].flatMap(Color.init(rawValue:)), !held.contains(color) else {
                continue
            }
            claims[player.playerId] = color
            held.insert(color)
        }
        self.claims = claims
        isLocked = session?.players.contains { $0.playerId == localPlayerID && $0.state == .ready } ?? false
    }

    public func color(of playerID: String) -> Color? { claims[playerID] }

    /// Ready needs a color the server holds for the local player (never ready without one);
    /// a ready player can always take it back.
    public var allowsReady: Bool { isLocked || localClaim != nil }

    /// The local player's claimed color.
    public var localClaim: Color? { localPlayerID.flatMap { claims[$0] } }

    /// Colors other players hold; the local player cannot take them.
    public var takenByOthers: Set<Color> {
        Set(claims.filter { $0.key != localPlayerID }.values)
    }

    public func isTakenByOthers(_ color: Color) -> Bool { takenByOthers.contains(color) }

    /// The color the lobby shows as the local player's. `preferred` is what they picked:
    /// while nobody else holds it the engine claims it (it may still be on its way), so it
    /// shows; once another player holds it, the server kept the local claim (or none, and
    /// the match gives the first free color).
    public func localColor(preferred: Color?) -> Color? {
        if let preferred, !isTakenByOthers(preferred) { return preferred }
        return localClaim
    }

    /// True when the local player's pick is held by someone else, so they should pick again.
    public func isPreferredTaken(_ preferred: Color?) -> Bool {
        preferred.map(isTakenByOthers) ?? false
    }
}

/// Claims a lobby color for the local player through a game's lobby intent, at most once
/// per session, color and connection; the engine calls `update` on every lobby change.
struct GameLobbyColorClaim<Color: RawRepresentable & Hashable & Sendable> where Color.RawValue == String {
    /// The color this player asked for; resent after a reconnect while still in the lobby.
    private(set) var preferred: Color?
    private var sent: (session: String, color: Color, connection: UUID?)?

    init(preferred: Color?) { self.preferred = preferred }

    /// A ready player's color is locked: the pick is ignored.
    mutating func select(_ color: Color, colors: GameLobbyColors<Color>) -> Bool {
        guard !colors.isLocked else { return false }
        preferred = color
        return true
    }

    /// Sends the pick when it can change something: the player sits in the synced lobby,
    /// is not ready, does not hold it yet and nobody else does (it is sent once the holder
    /// leaves and the color is free again). `send` reports whether the message went out.
    mutating func update<Game: GameRealtimeGame>(lobby: GameOnlineLobbyState<Game>, localPlayerID: String?,
                                                 colors: GameLobbyColors<Color>, send: (Color) -> Bool) {
        guard let color = preferred, let sessionID = lobby.session?.sessionId,
              lobby.connection == .connected, lobby.isSynced, lobby.isLobby,
              lobby.localPlayer(localPlayerID) != nil else { return }
        if colors.isLocked || colors.localClaim == color || colors.isTakenByOthers(color) { return }
        if let sent, sent.session == sessionID, sent.color == color, sent.connection == lobby.connectionGeneration { return }
        if send(color) { sent = (sessionID, color, lobby.connectionGeneration) }
    }
}
