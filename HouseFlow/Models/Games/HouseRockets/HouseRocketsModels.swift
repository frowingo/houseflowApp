import Foundation

enum HouseRocketsMode: String, CaseIterable, Identifiable, Sendable {
    case localBots
    case housemates

    var id: String { rawValue }
}

/// Captured at screen entry; local play does not require either identifier.
struct HouseRocketsLaunchContext: Equatable, Sendable {
    let houseID: String?
    let localPlayerID: String?
    var houseOwnerID: String? = nil
}

enum HouseRocketsOnlineBlocker: Equatable {
    case signInRequired
    case houseRequired
    case serviceUnavailable
    /// The server catalog does not list House Rockets for this house.
    case gameUnavailable
}

/// What the server catalog says about online House Rockets for the current house.
/// `unknown` never blocks: the server still answers 409 `game.error.unavailable`.
enum HouseRocketsCatalogAvailability: Equatable, Sendable {
    case unknown
    case available(maximumPlayers: Int)
    case unavailable
}
