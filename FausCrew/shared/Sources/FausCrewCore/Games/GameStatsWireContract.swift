import Foundation

/// One member's completed matches in one game. The backend counts; clients never recount.
public struct PlayerGameStats: Decodable, Equatable, Sendable {
    public let userId: String
    public let wins: Int
    public let matchesPlayed: Int

    public init(userId: String, wins: Int, matchesPlayed: Int) {
        self.userId = userId
        self.wins = wins
        self.matchesPlayed = matchesPlayed
    }
}

/// One game's standings, already sorted by the backend: wins, then matches, then membership order.
public struct HouseGameStats: Decodable, Equatable, Sendable {
    public let gameKey: String
    public let players: [PlayerGameStats]

    public init(gameKey: String, players: [PlayerGameStats]) {
        self.gameKey = gameKey
        self.players = players
    }
}

/// A failed stats request, with the server's localized message when it sent one. Clients branch
/// on `kind` only; the message is free text.
public struct GameStatsFailure: Error, Equatable, Sendable {
    public enum Kind: String, Equatable, Sendable {
        /// 400, or a house id refused before sending.
        case invalidRequest
        /// 401: the session flow takes over.
        case unauthorized
        /// 403 (not a member) or 404 (house gone): the house context must be refreshed.
        case accessLost
        /// 429: the per-user rate limit.
        case rateLimited
        /// Any other status.
        case server
        /// A 2xx body that does not match the contract.
        case invalidResponse
    }

    public let kind: Kind
    public let message: String?

    public init(kind: Kind, message: String?) {
        self.kind = kind
        self.message = message.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }

    public init(status: HTTPStatusFailure) {
        let kind: Kind = switch status.statusCode {
        case 400: .invalidRequest
        case 401: .unauthorized
        case 403, 404: .accessLost
        case 429: .rateLimited
        default: .server
        }
        self.init(kind: kind, message: status.message)
    }
}

/// `GET game/stats?houseId=…`. Paths are relative to `/api/v1`; both platforms' HTTP adapters add
/// `Accept-Language`.
public enum GameStatsWireContract {
    public static func request(houseID: String, jwt: String) throws(GameStatsFailure) -> HTTPRequest {
        do {
            try GameWireContract.validateIdentifier(houseID)
        } catch {
            throw GameStatsFailure(kind: .invalidRequest, message: nil)
        }
        let route = GameRoute.stats(houseId: houseID)
        return HTTPRequest(
            path: route.path,
            method: route.method,
            queryItems: route.queryItems,
            headers: ["Authorization": "Bearer \(jwt)"]
        )
    }

    /// Games are decoded one by one, so a malformed or future entry never hides the others.
    /// `data` must be an array; an empty one means the house has no completed match yet.
    public static func decode(
        _ response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()
    ) throws(GameStatsFailure) -> [HouseGameStats] {
        guard (200...299).contains(response.statusCode) else {
            throw GameStatsFailure(status: HTTPStatusFailure(response: response, decoder: decoder))
        }
        guard let envelope = try? decoder.decode(Envelope.self, from: response.body),
              envelope.success != false, let data = envelope.data else {
            throw GameStatsFailure(kind: .invalidResponse, message: nil)
        }
        return data.compactMap(\.value)
    }

    private struct Envelope: Decodable {
        let success: Bool?
        let data: [Lossy<HouseGameStats>]?
    }

    private struct Lossy<Value: Decodable>: Decodable {
        let value: Value?
        init(from decoder: Decoder) throws { value = try? Value(from: decoder) }
    }
}

/// What the stats card draws: the games this client knows, each with its members in the
/// backend's order, plus an overall ranking when there are two games or more.
public struct GameStatsBoard: Equatable, Sendable {
    public struct Standing: Equatable, Sendable {
        public let userId: String
        public let wins: Int
        public let matchesPlayed: Int
        /// The first standing of a section, and only when it has a win.
        public let isLeader: Bool

        public var hasPlayed: Bool { matchesPlayed > 0 }

        public init(userId: String, wins: Int, matchesPlayed: Int, isLeader: Bool) {
            self.userId = userId
            self.wins = wins
            self.matchesPlayed = matchesPlayed
            self.isLeader = isLeader
        }
    }

    public struct Section: Equatable, Sendable {
        /// The server's game key; `nil` for the overall ranking.
        public let gameKey: String?
        public let standings: [Standing]

        public init(gameKey: String?, standings: [Standing]) {
            self.gameKey = gameKey
            self.standings = standings
        }
    }

    public let games: [Section]
    /// The sum over `games`, present only when there are at least two of them.
    public let overall: Section?

    public var isEmpty: Bool { games.isEmpty }

    public init(games: [Section], overall: Section?) {
        self.games = games
        self.overall = overall
    }

    /// - Parameters:
    ///   - memberIDs: the house's current members in membership order. A player missing from it
    ///     (stale house data) is left out; nobody is added.
    ///   - knownGameKeys: games this client can name and draw. Others are skipped, also in the sum.
    public static func make(stats: [HouseGameStats], memberIDs: [String], knownGameKeys: Set<String>) -> GameStatsBoard {
        let members = Set(memberIDs)
        var seenGames = Set<String>()
        var games: [Section] = []
        for game in stats where knownGameKeys.contains(game.gameKey) && seenGames.insert(game.gameKey).inserted {
            var seenPlayers = Set<String>()
            let players = game.players.filter { members.contains($0.userId) && seenPlayers.insert($0.userId).inserted }
            guard !players.isEmpty else { continue }
            games.append(Section(gameKey: game.gameKey, standings: standings(players)))
        }
        return GameStatsBoard(games: games, overall: games.count >= 2 ? overall(games, memberIDs: memberIDs) : nil)
    }

    /// Wins and matches added up per member, sorted by the backend's rule: wins, then matches,
    /// then membership order.
    private static func overall(_ games: [Section], memberIDs: [String]) -> Section {
        var totals: [String: (wins: Int, matches: Int)] = [:]
        for standing in games.flatMap(\.standings) {
            let total = totals[standing.userId] ?? (0, 0)
            totals[standing.userId] = (total.wins + standing.wins, total.matches + standing.matchesPlayed)
        }
        let order = Dictionary(memberIDs.enumerated().map { ($1, $0) }, uniquingKeysWith: { first, _ in first })
        let sorted = totals
            .map { PlayerGameStats(userId: $0.key, wins: $0.value.wins, matchesPlayed: $0.value.matches) }
            .sorted { lhs, rhs in
                if lhs.wins != rhs.wins { return lhs.wins > rhs.wins }
                if lhs.matchesPlayed != rhs.matchesPlayed { return lhs.matchesPlayed > rhs.matchesPlayed }
                return order[lhs.userId, default: .max] < order[rhs.userId, default: .max]
            }
        return Section(gameKey: nil, standings: standings(sorted))
    }

    private static func standings(_ players: [PlayerGameStats]) -> [Standing] {
        players.enumerated().map { index, player in
            Standing(userId: player.userId, wins: player.wins, matchesPlayed: player.matchesPlayed,
                     isLeader: index == 0 && player.wins > 0)
        }
    }
}
