import Foundation
import FausCrewCore

typealias HouseRocketsOnlineIO = GameOnlineIO
typealias LiveHouseRocketsOnlineIO = LiveGameOnlineIO
typealias HouseRocketsOnlineHost = GameOnlineHost<HouseRocketsOnlineEngine>

extension HouseRocketsOnlineEngine: GameOnlineHostedEngine {
    static var gameKey: String { GameKey.houseRockets }
    var lobbyIssue: GameOnlineLobbyIssue? { lobby.issue }
    var canRematch: Bool { result.canRematch }
}

extension GameOnlineHost where Engine == HouseRocketsOnlineEngine {
    func presentation() -> HouseRocketsOnlinePresentation? {
        isDisposed ? nil : engine.presentation(at: uptime)
    }
}
