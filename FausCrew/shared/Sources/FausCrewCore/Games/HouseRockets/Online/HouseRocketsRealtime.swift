import Foundation

public typealias HouseRocketsLaunchContext = GameLaunchContext
public typealias HouseRocketsReconnectPolicy = GameReconnectPolicy
public typealias GameRealtimeClientAction = GameRealtimeClientActionOf<HouseRocketsRealtime>
public typealias GameRealtimeClientMessage = GameRealtimeClientMessageOf<HouseRocketsRealtime>
public typealias GameRealtimeServerPayload = GameRealtimeServerPayloadOf<HouseRocketsRealtime>
public typealias GameRealtimeServerMessage = GameRealtimeServerMessageOf<HouseRocketsRealtime>
public typealias GameRealtimeReceivedMessage = GameRealtimeReceivedMessageOf<HouseRocketsRealtime>

/// House Rockets on the shared realtime protocol: course 1, steer intents.
public enum HouseRocketsRealtime: GameRealtimeGame {
    public enum Intent: Equatable, Sendable {
        case steer(controlGeneration: String, inputSequence: Int64, courseHeading: Double)
    }

    public static let gameKey = GameKey.houseRockets

    public static let readyRequiresLandscape = true

    public static func checkCompatibility(_ welcome: HouseRocketsWelcomeDTO) throws {
        try GameRealtimeCodec.validateCompatibility(protocolVersion: welcome.protocolVersion,
            courseVersion: welcome.courseVersion, gameKey: welcome.gameKey)
    }

    public static func checkCompatibility(_ snapshot: HouseRocketsSnapshotDTO) throws {
        try GameRealtimeCodec.validateCompatibility(courseVersion: snapshot.courseVersion, gameKey: snapshot.gameKey)
    }

    public static func checkCompatibility(_ result: HouseRocketsResultDTO) throws {
        try GameRealtimeCodec.validateCompatibility(protocolVersion: result.protocolVersion,
            courseVersion: result.courseVersion, gameKey: result.gameKey)
    }

    public static func type(of intent: Intent) -> String { "houseRockets.steer" }

    public static func payload(of intent: Intent) throws -> any Encodable {
        switch intent {
        case .steer(let generation, let sequence, let heading):
            try GameRealtimeCodec.validateIdentifier(generation)
            guard sequence > 0, heading.isFinite else { throw GameRealtimeError.invalidInput }
            return Steer(controlGeneration: generation, inputSequence: sequence, heading: atan2(sin(heading), cos(heading)))
        }
    }

    public static func controlGeneration(of intent: Intent) -> String? {
        switch intent {
        case .steer(let generation, _, _): return generation
        }
    }

    /// An eliminated rocket never comes back.
    public static func isValidSuccessor(_ next: HouseRocketsSnapshotDTO, of current: HouseRocketsSnapshotDTO) -> Bool {
        let eliminated = Set(current.players.filter { !$0.isAlive }.map(\.playerId))
        return !next.players.contains { $0.isAlive && eliminated.contains($0.playerId) }
    }

    public static func identities(in snapshot: HouseRocketsSnapshotDTO) -> [String: HouseRocketsResultPlayerIdentity] {
        var identities: [String: HouseRocketsResultPlayerIdentity] = [:]
        for player in snapshot.players where identities[player.playerId] == nil {
            identities[player.playerId] = .init(displayName: player.displayName, color: player.color)
        }
        return identities
    }

    private struct Steer: Encodable {
        let controlGeneration: String
        let inputSequence: Int64
        let heading: Double
    }
}

extension GameRealtimeClientActionOf where Game == HouseRocketsRealtime {
    public static func steer(controlGeneration: String, inputSequence: Int64, courseHeading: Double) -> Self {
        .gameplay(.steer(controlGeneration: controlGeneration, inputSequence: inputSequence, courseHeading: courseHeading))
    }
}

extension HouseRocketsRuntimeSettingsDTO: GameRealtimeSettings {}
extension HouseRocketsWelcomeDTO: GameRealtimeWelcome {}
extension HouseRocketsResultDTO: GameRealtimeResult {}

extension HouseRocketsSnapshotDTO: GameRealtimeSnapshot {
    public var isBeforeStart: Bool { phase == .countdown || elapsedSeconds == 0 }

    public func controlSeat(of playerID: String) -> GameRealtimeControlSeat? {
        players.first { $0.playerId == playerID }.map {
            .init(controlGeneration: $0.controlGeneration, canHoldControl: $0.isAlive, connected: $0.connected)
        }
    }
}

/// HTTP/wire decoding shared by the engine and its hosts.
public enum HouseRocketsOnlineWire {
    public static func session(from response: HTTPResponse, houseID: String) throws -> GameSessionDTO {
        try GameOnlineWire.session(from: response, houseID: houseID, gameKey: GameKey.houseRockets)
    }

    public static func result(from response: HTTPResponse, sessionID: String, houseID: String) throws -> HouseRocketsResultDTO {
        try GameOnlineWire.result(from: response, sessionID: sessionID, houseID: houseID, as: HouseRocketsRealtime.self)
    }

    public static func failure(from error: Error, retryAfter: TimeInterval?) -> GameRealtimeSessionFailure {
        GameOnlineWire.failure(from: error, retryAfter: retryAfter)
    }
}
