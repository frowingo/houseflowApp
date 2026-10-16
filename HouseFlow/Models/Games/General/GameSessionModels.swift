import Foundation
import HouseFlowCore

/// HTTP and realtime share this session DTO. These are not game render models.
struct GameSessionDTO: Decodable, Equatable, Sendable {
    let sessionId: String
    let houseId: String
    let gameKey: String
    let protocolVersion: Int
    let mode: String
    let state: GameSessionState
    let rules: GameRulesDTO
    let players: [GameSessionPlayerDTO]
    let createdBy: String
    let createdAt: Date
    let updatedAt: Date
    let readyWindowEndsAt: Date?
    let countdownEndsAt: Date?
    let startedAt: Date?
    let endedAt: Date?
    let endReason: String?
    let version: Int64
}

enum GameSessionState: String, Decodable, Sendable {
    case lobby, readyWindow, countdown, running, finished, cancelled
}

struct GameSessionPlayerDTO: Decodable, Equatable, Sendable {
    let playerId: String
    let state: GameSessionPlayerState
    let joinedAt: Date
    let readyAt: Date?
    let leftAt: Date?
}

enum GameSessionPlayerState: String, Decodable, Sendable {
    case waiting, ready, playing, finished, left
}

struct GameHTTPEnvelope<Value: Decodable>: Decodable {
    let success: Bool
    let data: Value?
    let error: String?
}
