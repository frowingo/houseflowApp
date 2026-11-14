import Foundation


/// HTTP and realtime share this session DTO. These are not game render models.
public struct GameSessionDTO: Decodable, Equatable, Sendable {
    public let sessionId: String
    public let houseId: String
    public let gameKey: String
    public let protocolVersion: Int
    public let mode: String
    public let state: GameSessionState
    public let rules: GameRulesDTO
    public let players: [GameSessionPlayerDTO]
    public let createdBy: String
    public let createdAt: Date
    public let updatedAt: Date
    public let readyWindowEndsAt: Date?
    public let countdownEndsAt: Date?
    public let startedAt: Date?
    public let endedAt: Date?
    public let endReason: String?
    public let version: Int64
    /// The game's lobby picks (ADR-030); the server writes the field only while it holds any.
    public let lobbyState: GameLobbyStateDTO?

    public init(sessionId: String, houseId: String, gameKey: String, protocolVersion: Int, mode: String, state: GameSessionState, rules: GameRulesDTO, players: [GameSessionPlayerDTO], createdBy: String, createdAt: Date, updatedAt: Date, readyWindowEndsAt: Date?, countdownEndsAt: Date?, startedAt: Date?, endedAt: Date?, endReason: String?, version: Int64, lobbyState: GameLobbyStateDTO? = nil) {
        self.sessionId = sessionId
        self.houseId = houseId
        self.gameKey = gameKey
        self.protocolVersion = protocolVersion
        self.mode = mode
        self.state = state
        self.rules = rules
        self.players = players
        self.createdBy = createdBy
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.readyWindowEndsAt = readyWindowEndsAt
        self.countdownEndsAt = countdownEndsAt
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.endReason = endReason
        self.version = version
        self.lobbyState = lobbyState
    }
}

/// A session's lobby picks: today only `colors` (player id → color raw value, Faus Switch).
/// Read leniently, like the server: anything unreadable is no pick, so a malformed field
/// never fails the session. Each game interprets the raw values.
public struct GameLobbyStateDTO: Decodable, Equatable, Sendable {
    public let colors: [String: String]

    public init(colors: [String: String] = [:]) {
        self.colors = colors
    }

    private enum CodingKeys: String, CodingKey { case colors }

    public init(from decoder: Decoder) throws {
        let values = try? decoder.container(keyedBy: CodingKeys.self)
        colors = (try? values?.decodeIfPresent([String: String].self, forKey: .colors)) ?? [:]
    }
}

public enum GameSessionState: String, Decodable, Sendable {
    case lobby, readyWindow, countdown, running, finished, cancelled
}

public struct GameSessionPlayerDTO: Decodable, Equatable, Sendable {
    public let playerId: String
    public let state: GameSessionPlayerState
    public let joinedAt: Date
    public let readyAt: Date?
    public let leftAt: Date?

    public init(playerId: String, state: GameSessionPlayerState, joinedAt: Date, readyAt: Date?, leftAt: Date?) {
        self.playerId = playerId
        self.state = state
        self.joinedAt = joinedAt
        self.readyAt = readyAt
        self.leftAt = leftAt
    }
}

public enum GameSessionPlayerState: String, Decodable, Sendable {
    case waiting, ready, playing, finished, left
}

public struct GameHTTPEnvelope<Value: Decodable>: Decodable {
    public let success: Bool
    public let data: Value?
    public let error: String?

    public init(success: Bool, data: Value?, error: String?) {
        self.success = success
        self.data = data
        self.error = error
    }
}

