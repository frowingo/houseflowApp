import Foundation

public enum GameRealtimeConnectionState: Equatable, Sendable {
    case idle, connecting, reconnecting, syncing, connected, failed
}

public enum GameRealtimeSessionFailure: Equatable, Sendable {
    case http(statusCode: Int, retryAfterSeconds: TimeInterval?)
    case protocolFailure(GameRealtimeError)
    case invalidPayload
    case transport
}

