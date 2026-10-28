import Foundation

/// What one realtime game adds to the shared v2 protocol. The envelope, lobby
/// commands, heartbeat, reconnect and result lookup are shared; a game supplies
/// its welcome, snapshot and result payloads, its gameplay intents and the
/// checks that decide whether this client can play what the server sends.
/// Its server messages are `<gameKey>.controlGranted/.snapshot/.result`.
public protocol GameRealtimeGame {
    associatedtype Settings: GameRealtimeSettings
    associatedtype Welcome: GameRealtimeWelcome where Welcome.Settings == Settings
    associatedtype Snapshot: GameRealtimeSnapshot
    associatedtype Result: GameRealtimeResult
    associatedtype Intent: Equatable & Sendable
    associatedtype ResultIdentity: Equatable & Sendable

    static var gameKey: String { get }
    /// Ready only counts in landscape when the match screen opens with the countdown
    /// (House Rockets); FauseTanks' room is portrait and rotates at match start.
    static var readyRequiresLandscape: Bool { get }

    /// Throw `GameRealtimeError` for a contract, version or map this client
    /// cannot play: the lobby then asks for an update instead of reconnecting.
    static func checkCompatibility(_ welcome: Welcome) throws
    static func checkCompatibility(_ snapshot: Snapshot) throws
    static func checkCompatibility(_ result: Result) throws

    /// Wire type and payload of a gameplay intent. `payload` throws for input
    /// the server would reject, so the client never produces it.
    static func type(of intent: Intent) -> String
    static func payload(of intent: Intent) throws -> any Encodable
    /// The control generation an intent is bound to; nil for none.
    static func controlGeneration(of intent: Intent) -> String?

    /// Whether `next` may replace `current` (already ordered after it).
    static func isValidSuccessor(_ next: Snapshot, of current: Snapshot) -> Bool
    /// Names and colors kept for the result panel while snapshots still arrive.
    static func identities(in snapshot: Snapshot) -> [String: ResultIdentity]
}

extension GameRealtimeGame {
    public static var resyncType: String { gameKey + ".resync" }
    public static var controlGrantedType: String { gameKey + ".controlGranted" }
    public static var snapshotType: String { gameKey + ".snapshot" }
    public static var resultType: String { gameKey + ".result" }
    public static var staleControlCode: String { gameKey + ".error.stale_control" }
}

/// Settings frozen into a session; `welcome.settings` is the authority.
public protocol GameRealtimeSettings: Equatable, Sendable {
    var heartbeatInterval: Double { get }
    var heartbeatTimeout: Double { get }
    var reconnectGrace: Double { get }
    /// Rejects settings a client could not run safely.
    var isUsable: Bool { get }
    /// Used only before a welcome arrives.
    static var releaseDefaults: Self { get }
}

public protocol GameRealtimeWelcome: Decodable, Equatable, Sendable {
    associatedtype Settings: GameRealtimeSettings
    var sessionId: String { get }
    var settings: Settings { get }
}

/// Core runtime phase, the same for every tick game.
public enum GameRuntimePhase: String, Codable, Sendable {
    case countdown, playing, recovering, finalizing, ended, cancelled
}

/// The part of a player's state that control decisions read.
public struct GameRealtimeControlSeat: Equatable, Sendable {
    /// Present only on the watching connection's own player while it holds control.
    public let controlGeneration: String?
    /// Whether this player may hold a grant at all (alive rocket, tank that has not left).
    public let canHoldControl: Bool
    public let connected: Bool

    public init(controlGeneration: String?, canHoldControl: Bool, connected: Bool) {
        self.controlGeneration = controlGeneration
        self.canHoldControl = canHoldControl
        self.connected = connected
    }
}

public protocol GameRealtimeSnapshot: Decodable, Equatable, Sendable {
    var sessionId: String { get }
    var runtimeEpoch: Int64 { get }
    var stateSequence: Int64 { get }
    var phase: GameRuntimePhase { get }
    /// True while no match tick has run: a cancellation then has no stored result.
    var isBeforeStart: Bool { get }
    func controlSeat(of playerID: String) -> GameRealtimeControlSeat?
}

public protocol GameRealtimeResult: Decodable, Equatable, Sendable {
    associatedtype EndReason: RawRepresentable & Equatable & Sendable where EndReason.RawValue == String
    var sessionId: String { get }
    var houseId: String { get }
    var endReason: EndReason { get }
    /// A final snapshot never substitutes for this contract.
    func validate(sessionID: String, houseID: String) throws
}

/// `<gameKey>.controlGranted`: the gateway bound this connection to the player.
public struct GameRealtimeControlGrantDTO: Codable, Equatable, Sendable {
    public let sessionId: String
    public let playerId: String
    public let runtimeEpoch: Int64
    public let controlGeneration: String

    public init(sessionId: String, playerId: String, runtimeEpoch: Int64, controlGeneration: String) {
        self.sessionId = sessionId
        self.playerId = playerId
        self.runtimeEpoch = runtimeEpoch
        self.controlGeneration = controlGeneration
    }
}
