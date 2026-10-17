import Foundation

/// Captured at screen entry; local play does not require either identifier.
public struct HouseRocketsLaunchContext: Equatable, Sendable {
    public let houseID: String?
    public let localPlayerID: String?
    public var houseOwnerID: String? = nil

    public init(houseID: String?, localPlayerID: String?, houseOwnerID: String? = nil) {
        self.houseID = houseID
        self.localPlayerID = localPlayerID
        self.houseOwnerID = houseOwnerID
    }
}

