import Foundation

enum GameRealtimeError: Error, Equatable, Sendable {
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
}

struct GameRealtimeRejection: Decodable, Equatable, Sendable {
    let code: String
    let args: [String]
    let retryable: Bool
}

struct GameRealtimePong: Decodable, Equatable, Sendable {
    let pingId: String
    let serverTime: Date
}

struct GameRealtimeEmptyPayload: Codable, Equatable, Sendable {
    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.singleValueContainer().decode([String: String].self)
        guard values.isEmpty else { throw GameRealtimeError.invalidResponse }
    }

    func encode(to encoder: Encoder) throws {
        var values = encoder.singleValueContainer()
        try values.encode([String: String]())
    }
}

/// Intent only. The codec writes the explicit protocol envelope and payload.
enum GameRealtimeClientAction: Equatable, Sendable {
    case join, leave, cancel, resync
    case setReady(Bool)
    case steer(controlGeneration: String, inputSequence: Int64, courseHeading: Double)
    case ping(id: String)
}

struct GameRealtimeClientMessage: Encodable, Equatable, Sendable {
    let messageId: String
    let action: GameRealtimeClientAction

    private enum CodingKeys: String, CodingKey { case protocolVersion, messageId, type, payload }
    private struct Ready: Encodable { let ready: Bool }
    private struct Steer: Encodable {
        let controlGeneration: String
        let inputSequence: Int64
        let heading: Double
    }
    private struct Ping: Encodable { let pingId: String }

    func encode(to encoder: Encoder) throws {
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
}

enum GameRealtimeServerPayload: Equatable, Sendable {
    case welcome(HouseRocketsWelcomeDTO)
    case pong(GameRealtimePong)
    case accepted
    case session(GameSessionDTO)
    case controlGranted(HouseRocketsControlGrantDTO)
    case snapshot(HouseRocketsSnapshotDTO)
    case result(HouseRocketsResultDTO)
    case rejected(GameRealtimeRejection)
}

struct GameRealtimeServerMessage: Decodable, Equatable, Sendable {
    let messageId: String?
    let sequence: Int64?
    let sentAt: Date
    let payload: GameRealtimeServerPayload

    private enum CodingKeys: String, CodingKey {
        case protocolVersion, messageId, sequence, sentAt, type, payload, error
    }

    init(from decoder: Decoder) throws {
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
struct GameRealtimeReceivedMessage: Equatable, Sendable {
    let message: GameRealtimeServerMessage
    let receivedAt: Date
    let receivedUptime: TimeInterval
    let generation: UUID
}
