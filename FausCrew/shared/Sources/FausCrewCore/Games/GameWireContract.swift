import Foundation

/// Server keys for games that have a client. Unknown keys from the catalog are
/// kept as plain strings so a newer server never breaks an older client.
public enum GameKey {
    public static let houseRockets = "houseRockets"
}

/// Release 1 (backend v38) game routes, relative to `/api/v1`. The legacy
/// `/game/{sessionId}/…` aliases still work on the server; clients use the
/// `/game/sessions/{sessionId}/…` names from now on.
public enum GameRoute: Equatable, Sendable {
    case catalog(houseId: String)
    case ensureSession(gameKey: String)
    case discoverSession(gameKey: String, houseId: String)
    case result(sessionId: String)
    case realtime(sessionId: String)

    public static let realtimeProtocolVersion = 2

    public var method: String {
        switch self {
        case .ensureSession: return "PUT"
        case .catalog, .discoverSession, .result, .realtime: return "GET"
        }
    }

    /// Each component is validated with `GameWireContract.validateIdentifier`
    /// by the platform adapter before it is appended to a URL.
    public var pathComponents: [String] {
        switch self {
        case .catalog: return ["game", "catalog"]
        case .ensureSession(let gameKey), .discoverSession(let gameKey, _): return ["game", gameKey, "session"]
        case .result(let sessionId): return ["game", "sessions", sessionId, "result"]
        case .realtime(let sessionId): return ["game", "sessions", sessionId, "realtime"]
        }
    }

    public var path: String { pathComponents.joined(separator: "/") }

    public var queryItems: [HTTPQueryItem] {
        switch self {
        case .catalog(let houseId), .discoverSession(_, let houseId):
            return [HTTPQueryItem(name: "houseId", value: houseId)]
        case .realtime:
            return [HTTPQueryItem(name: "protocolVersion", value: String(Self.realtimeProtocolVersion))]
        case .ensureSession, .result:
            return []
        }
    }

    /// `true` for the WebSocket upgrade; the adapter swaps http(s) for ws(s).
    public var isRealtime: Bool {
        if case .realtime = self { return true }
        return false
    }
}

/// Stable error codes from the game module. Turkish and English copy lives in
/// the server localization table under the same keys.
public enum GameErrorCode {
    /// HTTP 409: the game is switched off or not opened for this house. An
    /// already active session stays reachable and the same request returns it.
    public static let unavailable = "game.error.unavailable"
    /// HTTP 409, turn-based games only.
    public static let notYourTurn = "game.error.not_your_turn"
    /// HTTP 400, turn-based games only.
    public static let invalidMove = "game.error.invalid_move"
}

/// A non-2xx game response reduced to what the clients branch on. It never
/// keeps the request, headers or the raw body.
public struct GameHTTPError: Error, Equatable, Sendable {
    public let statusCode: Int
    public let code: String?

    public init(statusCode: Int, code: String?) {
        self.statusCode = statusCode
        self.code = code
    }

    public init(statusCode: Int, body: Data) {
        self.init(statusCode: statusCode, code: GameWireContract.errorCode(from: body))
    }

    public var isGameUnavailable: Bool {
        statusCode == 409 && code == GameErrorCode.unavailable
    }
}

public struct GameRulesDTO: Codable, Equatable, Sendable {
    public let minimumPlayers: Int
    public let maximumPlayers: Int
    public let readyWindowMilliseconds: Int64
    public let countdownMilliseconds: Int64

    public init(minimumPlayers: Int, maximumPlayers: Int,
                readyWindowMilliseconds: Int64, countdownMilliseconds: Int64) {
        self.minimumPlayers = minimumPlayers
        self.maximumPlayers = maximumPlayers
        self.readyWindowMilliseconds = readyWindowMilliseconds
        self.countdownMilliseconds = countdownMilliseconds
    }
}

/// One game the house can start right now. `settings` is game specific; only
/// House Rockets settings are decoded today. Catalog values describe the
/// *next* session — a running match always follows its own `welcome.settings`.
public struct GameCatalogEntryDTO: Decodable, Equatable, Sendable {
    public let gameKey: String
    public let protocolVersion: Int
    public let mode: String
    public let configVersion: Int
    public let rules: GameRulesDTO
    public let houseRocketsSettings: HouseRocketsRuntimeSettingsDTO?

    public init(gameKey: String, protocolVersion: Int, mode: String, configVersion: Int,
                rules: GameRulesDTO, houseRocketsSettings: HouseRocketsRuntimeSettingsDTO?) {
        self.gameKey = gameKey
        self.protocolVersion = protocolVersion
        self.mode = mode
        self.configVersion = configVersion
        self.rules = rules
        self.houseRocketsSettings = houseRocketsSettings
    }

    private enum CodingKeys: String, CodingKey {
        case gameKey, protocolVersion, mode, configVersion, rules, settings
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        gameKey = try values.decode(String.self, forKey: .gameKey)
        protocolVersion = try values.decode(Int.self, forKey: .protocolVersion)
        mode = try values.decode(String.self, forKey: .mode)
        configVersion = try values.decodeIfPresent(Int.self, forKey: .configVersion) ?? 0
        rules = try values.decode(GameRulesDTO.self, forKey: .rules)
        houseRocketsSettings = gameKey == GameKey.houseRockets
            ? try values.decodeIfPresent(HouseRocketsRuntimeSettingsDTO.self, forKey: .settings)
            : nil
    }
}

/// Games the server allows for one house. A game missing from the list is
/// switched off or not opened for that house.
public struct GameCatalog: Equatable, Sendable {
    public let houseId: String
    public let entries: [GameCatalogEntryDTO]

    public init(houseId: String, entries: [GameCatalogEntryDTO]) {
        self.houseId = houseId
        self.entries = entries
    }

    public func entry(for gameKey: String) -> GameCatalogEntryDTO? {
        entries.first { $0.gameKey == gameKey }
    }

    /// The client can only offer a game it speaks the protocol of.
    public var houseRockets: GameCatalogEntryDTO? {
        guard let entry = entry(for: GameKey.houseRockets),
              entry.protocolVersion == GameRoute.realtimeProtocolVersion,
              entry.mode == "realtime" else { return nil }
        return entry
    }
}

public enum GameWireError: Error, Equatable, Sendable {
    case invalidIdentifier
    case rejected(String?)
}

public enum GameWireContract {
    public static func validateIdentifier(_ value: String) throws {
        guard !value.isEmpty, value.utf8.count <= 128,
              value.trimmingCharacters(in: .whitespacesAndNewlines) == value,
              value != ".", value != "..",
              !value.contains(where: { "/\\?#".contains($0) }) else {
            throw GameWireError.invalidIdentifier
        }
    }

    public static func ensureSessionBody(houseId: String) throws -> Data {
        try validateIdentifier(houseId)
        return try JSONEncoder().encode(EnsureSessionBody(houseId: houseId))
    }

    /// Entries are decoded one by one: a malformed or future game never hides
    /// the games this client understands.
    public static func decodeCatalog(houseId: String, response: HTTPResponse) throws -> GameCatalog {
        guard (200..<300).contains(response.statusCode) else {
            throw GameHTTPError(statusCode: response.statusCode, body: response.body)
        }
        let envelope = try JSONDecoder().decode(CatalogEnvelope.self, from: response.body)
        guard envelope.success, let data = envelope.data else { throw GameWireError.rejected(envelope.error?.value) }
        return GameCatalog(houseId: houseId, entries: data.compactMap(\.value))
    }

    /// Reads the machine code from the error bodies the backend uses:
    /// `{"code": …}`, `{"errorCode": …}`, `{"error": {"code": …}}` and
    /// `{"error": "game.error.…"}`. Free text is never treated as a code.
    public static func errorCode(from body: Data) -> String? {
        guard let object = (try? JSONSerialization.jsonObject(with: body)) as? [String: Any] else { return nil }
        let candidates: [Any?] = [
            object["code"], object["errorCode"],
            (object["error"] as? [String: Any])?["code"], object["error"], object["message"],
        ]
        return candidates.lazy.compactMap { $0 as? String }.first(where: isErrorCode)
    }

    static func isErrorCode(_ value: String) -> Bool {
        let parts = value.split(separator: ".", omittingEmptySubsequences: false)
        guard parts.count >= 3, parts[1] == "error" else { return false }
        return parts.allSatisfy { part in
            !part.isEmpty && part.unicodeScalars.allSatisfy {
                CharacterSet.alphanumerics.contains($0) || $0 == "_"
            }
        }
    }

    private struct EnsureSessionBody: Encodable {
        let houseId: String
    }

    private struct CatalogEnvelope: Decodable {
        let success: Bool
        let data: [Lossy<GameCatalogEntryDTO>]?
        let error: Lossy<String>?
    }

    private struct Lossy<Value: Decodable>: Decodable {
        let value: Value?
        init(from decoder: Decoder) throws { value = try? Value(from: decoder) }
    }
}
