import SwiftUI
import FausCrewCore

/// The online games by their server key: the hub title and the in-game artwork that stands for
/// each game. The Games hub and the dashboard stats card read names from here, so a game is named
/// the same everywhere. Keys the server sends that are not listed here are not shown.
enum OnlineGameVisual: CaseIterable {
    case fausSwitch, houseRockets, houseTanks

    init?(gameKey: String) {
        guard let visual = Self.allCases.first(where: { $0.gameKey == gameKey }) else { return nil }
        self = visual
    }

    static let knownGameKeys = Set(allCases.map(\.gameKey))

    var gameKey: String {
        switch self {
        case .fausSwitch: GameKey.fausSwitch
        case .houseRockets: GameKey.houseRockets
        case .houseTanks: GameKey.houseTanks
        }
    }

    var titleKey: String {
        switch self {
        case .fausSwitch: "games_faus_switch_title"
        case .houseRockets: "games_house_rockets_title"
        case .houseTanks: "games_house_tanks_title"
        }
    }

    /// The figure the game itself draws: the olive robot, the rocket mark and the olive arena tank.
    @ViewBuilder var artwork: some View {
        switch self {
        case .fausSwitch: FausSwitchRobot(color: .olive)
        case .houseRockets: HouseRocketsRocketMark()
        case .houseTanks: HouseTanksArenaTank(color: .olive)
        }
    }
}
