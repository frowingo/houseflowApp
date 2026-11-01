import Foundation

public enum GameRealtimeError: Error, Equatable, Sendable {
    case accessRevoked
    case unsupportedProtocol(Int)
    case unsupportedCourse(Int)
    /// The welcome's contract revision or map catalog differs from this client's.
    case unsupportedContract(String)
    /// A snapshot names a map (`id`, `version`) this client's catalog lacks.
    case unsupportedMap(String, Int)
    case unsupportedMessage(String)
    case invalidIdentifier
    case invalidInput
    case invalidResponse
    case invalidContext
    case authenticationRequired
    case unexpectedSession
    case notConnected
    case messageTooLarge
    case slowConsumer
    /// HTTP 409 `game.error.unavailable`: switched off or not opened for this house.
    case gameUnavailable
}

public struct GameRealtimeRejection: Codable, Equatable, Sendable {
    public let code: String
    public let args: [String]
    public let retryable: Bool

    public init(code: String, args: [String], retryable: Bool) {
        self.code = code
        self.args = args
        self.retryable = retryable
    }
}

public struct GameRealtimePong: Codable, Equatable, Sendable {
    public let pingId: String
    public let serverTime: Date

    public init(pingId: String, serverTime: Date) {
        self.pingId = pingId
        self.serverTime = serverTime
    }
}

public struct GameRealtimeEmptyPayload: Codable, Equatable, Sendable {
    public init() {}

    public init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer().decode([String: String].self)
        guard values.isEmpty else { throw GameRealtimeError.invalidResponse }
    }

    public func encode(to encoder: Encoder) throws {
        var values = encoder.singleValueContainer()
        try values.encode([String: String]())
    }
}

/// Intent only. The codec writes the explicit protocol envelope and payload.
public enum GameRealtimeClientActionOf<Game: GameRealtimeGame>: Equatable, Sendable {
    case join, leave, cancel, resync
    case setReady(Bool)
    case ping(id: String)
    case gameplay(Game.Intent)
}

public struct GameRealtimeClientMessageOf<Game: GameRealtimeGame>: Encodable, Equatable, Sendable {
    public let messageId: String
    public let action: GameRealtimeClientActionOf<Game>

    private enum CodingKeys: String, CodingKey { case protocolVersion, messageId, type, payload }
    private struct Ready: Encodable { let ready: Bool }
    private struct Ping: Encodable { let pingId: String }

    public func encode(to encoder: Encoder) throws {
        try GameRealtimeCodec.validateIdentifier(messageId)
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(GameRoute.realtimeProtocolVersion, forKey: .protocolVersion)
        try values.encode(messageId, forKey: .messageId)
        let type: String
        switch action {
        case .join: type = "gameSession.join"
        case .leave: type = "gameSession.leave"
        case .cancel: type = "gameSession.cancel"
        case .resync: type = Game.resyncType
        case .setReady: type = "gameSession.setReady"
        case .ping: type = "realtime.ping"
        case .gameplay(let intent): type = Game.type(of: intent)
        }
        try values.encode(type, forKey: .type)
        switch action {
        case .join, .leave, .cancel, .resync:
            try values.encode(GameRealtimeEmptyPayload(), forKey: .payload)
        case .setReady(let ready):
            try values.encode(Ready(ready: ready), forKey: .payload)
        case .ping(let id):
            try GameRealtimeCodec.validateIdentifier(id)
            try values.encode(Ping(pingId: id), forKey: .payload)
        case .gameplay(let intent):
            try values.encode(try Game.payload(of: intent), forKey: .payload)
        }
    }

    public init(messageId: String, action: GameRealtimeClientActionOf<Game>) {
        self.messageId = messageId
        self.action = action
    }
}

public enum GameRealtimeServerPayloadOf<Game: GameRealtimeGame>: Equatable, Sendable {
    case welcome(Game.Welcome)
    case pong(GameRealtimePong)
    case accepted
    case session(GameSessionDTO)
    case controlGranted(GameRealtimeControlGrantDTO)
    case snapshot(Game.Snapshot)
    case result(Game.Result)
    case rejected(GameRealtimeRejection)
}

/// The v2 envelope. Shared messages are decoded here; the game's own payloads
/// go through its `GameRealtimeGame` types and compatibility checks.
public struct GameRealtimeServerMessageOf<Game: GameRealtimeGame>: Decodable, Equatable, Sendable {
    public let messageId: String?
    public let sequence: Int64?
    public let sentAt: Date
    public let payload: GameRealtimeServerPayloadOf<Game>

    private enum CodingKeys: String, CodingKey {
        case protocolVersion, messageId, sequence, sentAt, type, payload, error
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let version = try values.decode(Int.self, forKey: .protocolVersion)
        guard version == GameRoute.realtimeProtocolVersion else { throw GameRealtimeError.unsupportedProtocol(version) }
        messageId = try values.decodeIfPresent(String.self, forKey: .messageId)
        sequence = try values.decodeIfPresent(Int64.self, forKey: .sequence)
        sentAt = try values.decode(Date.self, forKey: .sentAt)
        let type = try values.decode(String.self, forKey: .type)
        switch type {
        case "realtime.welcome":
            let welcome = try values.decode(Game.Welcome.self, forKey: .payload)
            try Game.checkCompatibility(welcome)
            payload = .welcome(welcome)
        case "realtime.pong":
            payload = .pong(try values.decode(GameRealtimePong.self, forKey: .payload))
        case "gameSession.commandAccepted":
            _ = try values.decode(GameRealtimeEmptyPayload.self, forKey: .payload)
            payload = .accepted
        case "gameSession.snapshot":
            let session = try values.decode(GameSessionDTO.self, forKey: .payload)
            try GameRealtimeCodec.validateSession(session, gameKey: Game.gameKey)
            payload = .session(session)
        case Game.controlGrantedType:
            payload = .controlGranted(try values.decode(GameRealtimeControlGrantDTO.self, forKey: .payload))
        case Game.snapshotType:
            let snapshot = try values.decode(Game.Snapshot.self, forKey: .payload)
            try Game.checkCompatibility(snapshot)
            payload = .snapshot(snapshot)
        case Game.resultType:
            let result = try values.decode(Game.Result.self, forKey: .payload)
            try Game.checkCompatibility(result)
            payload = .result(result)
        case "gameSession.commandRejected":
            guard !values.contains(.payload) else { throw GameRealtimeError.invalidResponse }
            payload = .rejected(try values.decode(GameRealtimeRejection.self, forKey: .error))
        default:
            throw GameRealtimeError.unsupportedMessage(type)
        }
    }
}

/// Received timestamps share an injectable clock with later heartbeat/interpolation work.
public struct GameRealtimeReceivedMessageOf<Game: GameRealtimeGame>: Equatable, Sendable {
    public let message: GameRealtimeServerMessageOf<Game>
    public let receivedAt: Date
    public let receivedUptime: TimeInterval
    public let generation: UUID

    public init(message: GameRealtimeServerMessageOf<Game>, receivedAt: Date, receivedUptime: TimeInterval, generation: UUID) {
        self.message = message
        self.receivedAt = receivedAt
        self.receivedUptime = receivedUptime
        self.generation = generation
    }
}
