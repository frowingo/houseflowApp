import Foundation

/// House Rockets settings frozen into a session. `welcome.settings` is the
/// authority for a running match; the catalog copy only previews the next one.
/// Rates and timings can change on the server without a deploy, so clients
/// derive every realtime cadence from here instead of hard-coding it.
public struct HouseRocketsRuntimeSettingsDTO: Codable, Equatable, Sendable {
    public let physicsRateHz: Int
    public let schedulingRateHz: Int
    public let snapshotRateHz: Int
    public let maximumInputRateHz: Int
    public let maximumSteerMessagesPerSecond: Int
    public let controlHeartbeatMilliseconds: Int64
    public let controlTimeoutMilliseconds: Int64
    public let reconnectGraceMilliseconds: Int64
    public let maximumMatchMilliseconds: Int64

    public init(physicsRateHz: Int, schedulingRateHz: Int, snapshotRateHz: Int,
                maximumInputRateHz: Int, maximumSteerMessagesPerSecond: Int,
                controlHeartbeatMilliseconds: Int64, controlTimeoutMilliseconds: Int64,
                reconnectGraceMilliseconds: Int64, maximumMatchMilliseconds: Int64) {
        self.physicsRateHz = physicsRateHz
        self.schedulingRateHz = schedulingRateHz
        self.snapshotRateHz = snapshotRateHz
        self.maximumInputRateHz = maximumInputRateHz
        self.maximumSteerMessagesPerSecond = maximumSteerMessagesPerSecond
        self.controlHeartbeatMilliseconds = controlHeartbeatMilliseconds
        self.controlTimeoutMilliseconds = controlTimeoutMilliseconds
        self.reconnectGraceMilliseconds = reconnectGraceMilliseconds
        self.maximumMatchMilliseconds = maximumMatchMilliseconds
    }

    /// Live defaults at Release 1; used only before a welcome arrives.
    public static let releaseDefaults = HouseRocketsRuntimeSettingsDTO(
        physicsRateHz: 120, schedulingRateHz: 60, snapshotRateHz: 20,
        maximumInputRateHz: 20, maximumSteerMessagesPerSecond: 30,
        controlHeartbeatMilliseconds: 2_000, controlTimeoutMilliseconds: 6_000,
        reconnectGraceMilliseconds: 10_000, maximumMatchMilliseconds: 300_000
    )

    public var heartbeatInterval: Double { Double(controlHeartbeatMilliseconds) / 1_000 }
    public var heartbeatTimeout: Double { Double(controlTimeoutMilliseconds) / 1_000 }
    public var reconnectGrace: Double { Double(reconnectGraceMilliseconds) / 1_000 }

    /// Rejects a welcome a client could not run safely (a ping storm, a
    /// timeout shorter than the ping, or a socket kept silent for minutes).
    public var isUsable: Bool {
        heartbeatInterval >= 0.25 && heartbeatTimeout > heartbeatInterval && heartbeatTimeout <= 60
            && maximumInputRateHz >= 1 && maximumSteerMessagesPerSecond >= 1
            && reconnectGraceMilliseconds >= 0
    }

    /// Steer cadence: the client's own preference, never above either server
    /// limit (retransmits are steer messages too), and at least 1 Hz.
    public func steerRate(preferredHz: Double) -> Double {
        let ceiling = Double(min(maximumInputRateHz, maximumSteerMessagesPerSecond))
        return max(1, min(preferredHz, ceiling))
    }
}
