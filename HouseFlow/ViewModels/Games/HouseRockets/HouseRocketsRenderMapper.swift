import Foundation
import HouseFlowCore

/// The presentation boundary maps DTOs; it does not decide eliminations or outcomes.
enum HouseRocketsRenderMapper {
    static func local(_ snapshot: HouseRocketsSnapshot) -> HouseRocketsRenderFrame {
        .local(snapshot)
    }

    static func online(_ snapshot: HouseRocketsSnapshotDTO, localPlayerID: String) throws -> HouseRocketsRenderFrame {
        try .online(snapshot, localPlayerID: localPlayerID)
    }
}
