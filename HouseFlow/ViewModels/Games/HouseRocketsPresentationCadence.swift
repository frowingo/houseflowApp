import Foundation

/// The scene samples every render frame; SwiftUI receives bounded HUD updates.
struct HouseRocketsPresentationCadence {
    private var previous: HouseRocketsOnlinePresentation?
    private var lastPublishedAt = -TimeInterval.infinity
    var interval: TimeInterval = 1.0 / 20.0

    mutating func shouldPublish(_ incoming: HouseRocketsOnlinePresentation?, at uptime: TimeInterval) -> Bool {
        guard incoming != previous else { return false }
        let urgent: Bool
        if let incoming, let previous {
            urgent = incoming.frame.sessionID != previous.frame.sessionID
                || incoming.frame.phase != previous.frame.phase
                || incoming.canSteer != previous.canSteer || incoming.isSyncing != previous.isSyncing
                || incoming.eliminations != previous.eliminations
                || incoming.frame.players.count != previous.frame.players.count
                || zip(incoming.frame.players, previous.frame.players).contains {
                    $0.id != $1.id || $0.isAlive != $1.isAlive || $0.speedEffect != $1.speedEffect
                }
        } else { urgent = true }
        guard urgent || uptime - lastPublishedAt >= interval - 0.000_001 else { return false }
        previous = incoming
        lastPublishedAt = uptime
        return true
    }
}
