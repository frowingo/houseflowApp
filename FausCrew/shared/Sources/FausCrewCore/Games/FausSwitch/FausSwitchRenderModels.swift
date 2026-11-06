import Foundation

/// One robot as drawn. Demo and online matches produce the same frame.
public struct FausSwitchRenderRunner: Equatable, Identifiable, Sendable {
    public let id: String
    public let nameKey: String?
    public let displayName: String?
    public let color: FausSwitchColor
    public var state: FausSwitchRunnerState
    public let isLocal: Bool
    public let isConnected: Bool
    public var isBoosted: Bool
    public var rank: Int?

    public init(id: String, nameKey: String?, displayName: String?, color: FausSwitchColor,
                state: FausSwitchRunnerState, isLocal: Bool, isConnected: Bool, isBoosted: Bool, rank: Int?) {
        self.id = id
        self.nameKey = nameKey
        self.displayName = displayName
        self.color = color
        self.state = state
        self.isLocal = isLocal
        self.isConnected = isConnected
        self.isBoosted = isBoosted
        self.rank = rank
    }
}

public struct FausSwitchRenderFrame: Equatable, Sendable {
    public let matchID: String
    public var tick: Int64
    public var phase: FausSwitchMatchPhase
    /// Whole seconds left before the run while counting down.
    public var countdown: Int?
    /// Track x the camera follows (`FausSwitchCamera.focus`).
    public var cameraFocus: Double
    /// Track x of the view's trailing edge; robots fully behind it are lost.
    public var cameraTrail: Double
    public var runners: [FausSwitchRenderRunner]

    public init(matchID: String, tick: Int64, phase: FausSwitchMatchPhase, countdown: Int?,
                cameraFocus: Double, cameraTrail: Double, runners: [FausSwitchRenderRunner]) {
        self.matchID = matchID
        self.tick = tick
        self.phase = phase
        self.countdown = countdown
        self.cameraFocus = cameraFocus
        self.cameraTrail = cameraTrail
        self.runners = runners
    }

    public var elapsedSeconds: Double { FausSwitchMetrics.seconds(tick) }
    public var localRunner: FausSwitchRenderRunner? { runners.first(where: \.isLocal) }
    public var runningCount: Int { runners.filter { $0.state.isRunning }.count }
}

/// Fits the fixed world into a screen: the whole band is always visible on a
/// horizontal stretch. A wider screen shows more course ahead; a narrower one
/// letterboxes the playfield vertically. `FausSwitchCamera` adds the per-section zoom.
public struct FausSwitchViewport: Equatable, Sendable {
    public let scale: Double
    /// Screen offset of world (cameraX, 0), in screen points with y up.
    public let originX: Double
    public let originY: Double
    public let screenWidth: Double
    public let screenHeight: Double

    public init(screenWidth: Double, screenHeight: Double) {
        let width = max(1, screenWidth)
        let height = max(1, screenHeight)
        scale = min(height / FausSwitchMetrics.worldHeight, width / FausSwitchMetrics.viewportWidth)
        originX = 0
        originY = (height - FausSwitchMetrics.worldHeight * scale) / 2
        self.screenWidth = width
        self.screenHeight = height
    }

    /// World units visible to the right of the camera's left edge.
    public var visibleWorldWidth: Double { screenWidth / scale }
}
