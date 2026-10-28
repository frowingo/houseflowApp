import Foundation

/// Presentation budgets of online FauseTanks, not wire rules or gameplay authority.
/// The delay starts at 100 ms and is meant to be tuned from device measurements.
public struct HouseTanksPlayConfiguration: Sendable {
    /// Other tanks, crates and shots are drawn this far behind the server.
    public var interpolationDelay = 0.10
    /// How far past the newest frame bodies are extrapolated before they hold still.
    public var maximumExtrapolation = 0.15
    /// The own tank is predicted at most this far past the newest frame.
    public var maximumPrediction = 0.20
    public var snapshotCapacity = 8
    /// Without a new frame for this long the button closes and the arena shows "syncing";
    /// twice as long asks the server for a resync.
    public var staleFrameAge = 0.35
    /// Press messages per second this client allows itself, below the server's limits.
    public var preferredPressRateHz = 30.0
    /// A playing seat without a grant for this long asks for a resync.
    public var controlWait = 1.0
    /// A playing seat without a grant for this long says so ("tankın bağlanıyor"); shorter
    /// waits (a round start, a rebind) pass without words.
    public var controlNoticeDelay = 0.5
    /// After `stale_control` the next frames decide: another device took the tank (no resync,
    /// that would take it back) or the grant still stands (resync after this long).
    public var staleControlSettle = 0.5
    /// The server drops a press queued for longer than a second; so does the prediction.
    public var inputLifetime = 1.0

    public init() {}
}

/// One seat of the match for the in-game bar (up to eight), in seat order.
public struct HouseTanksOnlineSeat: Equatable, Identifiable, Sendable {
    public let playerID: String
    public let displayName: String
    public let color: HouseTanksColor
    public let armor: Int
    public let roundsWon: Int
    /// The tank in this round; a dead tank is a wreck until the next round.
    public let isAlive: Bool
    /// False while the player has no control (a stationary target), including after leaving.
    public let isConnected: Bool
    public let hasLeft: Bool
    public let roundReady: Bool
    public let isLocal: Bool
    public let powerUp: HouseTanksPowerUpStatus?
    public var id: String { playerID }

    public init(playerID: String, displayName: String, color: HouseTanksColor, armor: Int, roundsWon: Int,
                isAlive: Bool, isConnected: Bool, hasLeft: Bool, roundReady: Bool, isLocal: Bool,
                powerUp: HouseTanksPowerUpStatus?) {
        self.playerID = playerID
        self.displayName = displayName
        self.color = color
        self.armor = armor
        self.roundsWon = roundsWon
        self.isAlive = isAlive
        self.isConnected = isConnected
        self.hasLeft = hasLeft
        self.roundReady = roundReady
        self.isLocal = isLocal
        self.powerUp = powerUp
    }
}

/// What the game screen draws at one display time. `world` is a draw-only copy: other
/// bodies interpolated, shots advanced, the own tank predicted. Hits, deaths, crates and
/// the round winner are always the server's.
public struct HouseTanksOnlinePresentation: Sendable {
    public let world: HouseTanksWorld
    /// Changes with every round and runtime epoch; the renderer rebuilds the arena then.
    public let roundKey: String
    /// Server events whose tick the display reached since the last presentation; each
    /// event of a match is in exactly one presentation.
    public let events: [HouseTanksWorld.Event]
    public let phase: GameRuntimePhase
    public let roundPhase: HouseTanksWireRoundPhase?
    public let roundNumber: Int
    public let roundWinnerID: String?
    public let seats: [HouseTanksOnlineSeat]
    /// Live tanks without control: drawn faded with a connection mark.
    public let offlinePlayerIDs: Set<String>
    /// The button works: grant, matching epoch and own generation, a playing round and a live tank.
    public let canPress: Bool
    /// The button is held down on this device.
    public let isPressed: Bool
    /// `roundReady`: this device may vote for the next round (a dead tank's player too).
    public let canVote: Bool
    /// The local vote as shown: the one just sent, else the snapshot's.
    public let isLocalReady: Bool
    /// A vote is on its way and no snapshot has shown it yet.
    public let isVotePending: Bool
    /// Players with control who voted, of all players with control.
    public let readyCount: Int
    public let voterCount: Int
    /// Set only in `phase = ended` with a decided champion.
    public let championID: String?
    /// The own tank is a wreck this round ("bu turda öldün"); the player stays in the match.
    public let isLocalTankDestroyed: Bool
    /// The server is not drawing this arena live right now (reconnecting, recovering, late frames).
    public let isSyncing: Bool
    /// A live seat of this device waits for its grant past `controlNoticeDelay`: after a
    /// reconnect or a new runtime epoch the tank is a stationary target until it arrives.
    public let isAwaitingControl: Bool
    /// This device watches a match it has no tank in (`control_unavailable`, not seated, left).
    public let isSpectating: Bool

    public init(world: HouseTanksWorld, roundKey: String, events: [HouseTanksWorld.Event], phase: GameRuntimePhase,
                roundPhase: HouseTanksWireRoundPhase?, roundNumber: Int, roundWinnerID: String?,
                seats: [HouseTanksOnlineSeat], offlinePlayerIDs: Set<String>, canPress: Bool, isPressed: Bool,
                canVote: Bool = false, isLocalReady: Bool = false, isVotePending: Bool = false,
                readyCount: Int = 0, voterCount: Int = 0, championID: String? = nil,
                isLocalTankDestroyed: Bool, isSyncing: Bool, isAwaitingControl: Bool = false,
                isSpectating: Bool = false) {
        self.world = world
        self.roundKey = roundKey
        self.events = events
        self.phase = phase
        self.roundPhase = roundPhase
        self.roundNumber = roundNumber
        self.roundWinnerID = roundWinnerID
        self.seats = seats
        self.offlinePlayerIDs = offlinePlayerIDs
        self.canPress = canPress
        self.isPressed = isPressed
        self.canVote = canVote
        self.isLocalReady = isLocalReady
        self.isVotePending = isVotePending
        self.readyCount = readyCount
        self.voterCount = voterCount
        self.championID = championID
        self.isLocalTankDestroyed = isLocalTankDestroyed
        self.isSyncing = isSyncing
        self.isAwaitingControl = isAwaitingControl
        self.isSpectating = isSpectating
    }
}

/// Display math of online frames. Never moves authority: positions only.
enum HouseTanksPlayMath {
    static func lerp(_ a: HouseTanksVector, _ b: HouseTanksVector, _ t: Double) -> HouseTanksVector {
        HouseTanksVector(x: a.x + (b.x - a.x) * t, y: a.y + (b.y - a.y) * t)
    }

    /// `rotation` is not normalized on the wire; the shorter way between the two is taken.
    static func lerpAngle(_ a: Double, _ b: Double, _ t: Double) -> Double {
        a + HouseTanksMath.normalizedAngle(b - a) * t
    }

    /// The wire event as the renderer's event; `roundEnded` is read from the round phase instead.
    static func event(_ event: HouseTanksEventDTO) -> HouseTanksWorld.Event? {
        guard let tick = Int(exactly: event.tick) else { return nil }
        let kind: HouseTanksWorld.EventKind
        switch event.kind {
        case .fired: kind = .fired
        case .hit: kind = .hit
        case .shielded: kind = .shielded
        case .crateBroken: kind = .crateBroken
        case .explosion: kind = .explosion
        case .eliminated: kind = .eliminated
        case .jokerCollected: kind = .jokerCollected
        case .roundEnded: return nil
        }
        let position = event.x.flatMap { x in event.y.map { HouseTanksVector(x: x, y: $0) } }
        return HouseTanksWorld.Event(tick: tick, kind: kind, playerID: event.playerId, sourceID: event.sourceId,
                                     position: position, angle: event.angle, armor: event.armor,
                                     lethal: event.lethal ?? false, crateIndex: event.crateIndex, powerUp: event.powerUp)
    }
}
