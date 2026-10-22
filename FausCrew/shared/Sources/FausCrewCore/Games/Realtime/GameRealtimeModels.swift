import Foundation

public enum GameRealtimeError: Error, Equatable, Sendable {
    case accessRevoked
    case unsupportedProtocol(Int)
    case unsupportedCourse(Int)
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

public struct GameRealtimeRejection: Decodable, Equatable, Sendable {
    public let code: String
    public let args: [String]
    public let retryable: Bool

    public init(code: String, args: [String], retryable: Bool) {
        self.code = code
        self.args = args
        self.retryable = retryable
    }
}

public struct GameRealtimePong: Decodable, Equatable, Sendable {
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
public enum GameRealtimeClientAction: Equatable, Sendable {
    case join, leave, cancel, resync
    case setReady(Bool)
    case steer(controlGeneration: String, inputSequence: Int64, courseHeading: Double)
    case ping(id: String)
}

public struct GameRealtimeClientMessage: Encodable, Equatable, Sendable {
    public let messageId: String
    public let action: GameRealtimeClientAction

    private enum CodingKeys: String, CodingKey { case protocolVersion, messageId, type, payload }
    private struct Ready: Encodable { let ready: Bool }
    private struct Steer: Encodable {
        public let controlGeneration: String
        public let inputSequence: Int64
        public let heading: Double

        public init(controlGeneration: String, inputSequence: Int64, heading: Double) {
            self.controlGeneration = controlGeneration
            self.inputSequence = inputSequence
            self.heading = heading
        }
    }
    private struct Ping: Encodable { let pingId: String }

    public func encode(to encoder: Encoder) throws {
        try GameRealtimeCodec.validateIdentifier(messageId)
        var values = encoder.container(keyedBy: CodingKeys.self)
        try values.encode(2, forKey: .protocolVersion)
        try values.encode(messageId, forKey: .messageId)
        let type: String
        switch action {
        case .join: type = "gameSession.join"
        case .leave: type = "gameSession.leave"
        case .cancel: type = "gameSession.cancel"
        case .resync: type = "houseRockets.resync"
        case .setReady: type = "gameSession.setReady"
        case .steer: type = "houseRockets.steer"
        case .ping: type = "realtime.ping"
        }
        try values.encode(type, forKey: .type)
        switch action {
        case .join, .leave, .cancel, .resync:
            try values.encode(GameRealtimeEmptyPayload(), forKey: .payload)
        case .setReady(let ready):
            try values.encode(Ready(ready: ready), forKey: .payload)
        case .steer(let generation, let sequence, let heading):
            try GameRealtimeCodec.validateIdentifier(generation)
            guard sequence > 0, heading.isFinite else { throw GameRealtimeError.invalidInput }
            try values.encode(Steer(controlGeneration: generation, inputSequence: sequence,
                                   heading: atan2(sin(heading), cos(heading))), forKey: .payload)
        case .ping(let id):
            try GameRealtimeCodec.validateIdentifier(id)
            try values.encode(Ping(pingId: id), forKey: .payload)
        }
    }

    public init(messageId: String, action: GameRealtimeClientAction) {
        self.messageId = messageId
        self.action = action
    }
}

public enum GameRealtimeServerPayload: Equatable, Sendable {
    case welcome(HouseRocketsWelcomeDTO)
    case pong(GameRealtimePong)
    case accepted
    case session(GameSessionDTO)
    case controlGranted(HouseRocketsControlGrantDTO)
    case snapshot(HouseRocketsSnapshotDTO)
    case result(HouseRocketsResultDTO)
    case rejected(GameRealtimeRejection)
}

public struct GameRealtimeServerMessage: Decodable, Equatable, Sendable {
    public let messageId: String?
    public let sequence: Int64?
    public let sentAt: Date
    public let payload: GameRealtimeServerPayload

    private enum CodingKeys: String, CodingKey {
        case protocolVersion, messageId, sequence, sentAt, type, payload, error
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let version = try values.decode(Int.self, forKey: .protocolVersion)
        guard version == 2 else { throw GameRealtimeError.unsupportedProtocol(version) }
        messageId = try values.decodeIfPresent(String.self, forKey: .messageId)
        sequence = try values.decodeIfPresent(Int64.self, forKey: .sequence)
        sentAt = try values.decode(Date.self, forKey: .sentAt)
        let type = try values.decode(String.self, forKey: .type)
        switch type {
        case "realtime.welcome":
            let welcome = try values.decode(HouseRocketsWelcomeDTO.self, forKey: .payload)
            try GameRealtimeCodec.validateCompatibility(protocolVersion: welcome.protocolVersion,
                courseVersion: welcome.courseVersion, gameKey: welcome.gameKey)
            payload = .welcome(welcome)
        case "realtime.pong":
            payload = .pong(try values.decode(GameRealtimePong.self, forKey: .payload))
        case "gameSession.commandAccepted":
            _ = try values.decode(GameRealtimeEmptyPayload.self, forKey: .payload)
            payload = .accepted
        case "gameSession.snapshot":
            let session = try values.decode(GameSessionDTO.self, forKey: .payload)
            try GameRealtimeCodec.validateCompatibility(protocolVersion: session.protocolVersion,
                                                        gameKey: session.gameKey)
            payload = .session(session)
        case "houseRockets.controlGranted":
            payload = .controlGranted(try values.decode(HouseRocketsControlGrantDTO.self, forKey: .payload))
        case "houseRockets.snapshot":
            let snapshot = try values.decode(HouseRocketsSnapshotDTO.self, forKey: .payload)
            try GameRealtimeCodec.validateCompatibility(courseVersion: snapshot.courseVersion,
                                                        gameKey: snapshot.gameKey)
            payload = .snapshot(snapshot)
        case "houseRockets.result":
            let result = try values.decode(HouseRocketsResultDTO.self, forKey: .payload)
            try GameRealtimeCodec.validateCompatibility(protocolVersion: result.protocolVersion,
                courseVersion: result.courseVersion, gameKey: result.gameKey)
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
public struct GameRealtimeReceivedMessage: Equatable, Sendable {
    public let message: GameRealtimeServerMessage
    public let receivedAt: Date
    public let receivedUptime: TimeInterval
    public let generation: UUID

    public init(message: GameRealtimeServerMessage, receivedAt: Date, receivedUptime: TimeInterval, generation: UUID) {
        self.message = message
        self.receivedAt = receivedAt
        self.receivedUptime = receivedUptime
        self.generation = generation
    }
}

