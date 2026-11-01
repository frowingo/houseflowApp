import Foundation

/// The service is the authority; presentation only sends intentions and observes state.
/// A WebSocket implementation should authenticate the local player on the server,
/// acknowledge commands and emit ordered snapshots (including reconnect snapshots).
@MainActor
protocol RPSGameServicing: AnyObject {
    func events() -> AsyncStream<RPSSnapshot>
    func start(players: [RPSPlayer], localPlayerID: UUID) async throws
    func send(_ command: RPSCommand) async throws
    func disconnect()
}
