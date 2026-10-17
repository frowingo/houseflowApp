import Foundation
import HouseFlowCore

// House Rockets local bot match. Rules, physics, bots and the projection stay in
// HouseFlowCore; Android owns timers, input and drawing. Gameplay is the one
// deliberate per-frame JNI call: each step returns only the moving state, and
// gate geometry is resent only when the course changes.

final class BotMatchRegistry: @unchecked Sendable {
    static let shared = BotMatchRegistry()
    private let lock = NSLock()
    private var nextHandle: Int32 = 1
    private var entries: [Int32: Entry] = [:]

    struct Entry {
        var match = HouseRocketsBotMatch()
        var courseKey = ""
        var viewport = Viewport()
    }

    /// Canvas size (the course, edge to edge) and the safe-area size the HUD
    /// lays out in, both in dp — iOS's SpriteView and information layer.
    struct Viewport {
        var width = 0.0
        var height = 0.0
        var hudWidth = 0.0
        var hudHeight = 0.0
    }

    func create() -> Int32 {
        lock.lock(); defer { lock.unlock() }
        let handle = nextHandle
        nextHandle = nextHandle == Int32.max ? 1 : nextHandle + 1
        entries[handle] = Entry()
        return handle
    }

    func destroy(_ handle: Int32) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return entries.removeValue(forKey: handle) != nil
    }

    func with<T>(_ handle: Int32, _ body: (inout Entry) -> T) -> T? {
        lock.lock(); defer { lock.unlock() }
        guard var entry = entries[handle] else { return nil }
        let result = body(&entry)
        entries[handle] = entry
        return result
    }
}

public func houseRocketsBotCreate() -> Int32 {
    BotMatchRegistry.shared.create()
}

public func houseRocketsBotDestroy(_ handle: Int32) -> Bool {
    BotMatchRegistry.shared.destroy(handle)
}

/// Stores the viewport and re-projects the current state without advancing it.
/// The next frame carries the course again.
public func houseRocketsBotViewport(
    _ handle: Int32, _ width: Double, _ height: Double, _ hudWidth: Double, _ hudHeight: Double
) -> String {
    botFrame(handle) { entry in
        entry.viewport = .init(width: width, height: height, hudWidth: hudWidth, hudHeight: hudHeight)
        entry.courseKey = ""
        return [:]
    }
}

/// Starts (or replaces) the match with 1–3 bots; the countdown starts at 3.
public func houseRocketsBotStart(_ handle: Int32, _ botCount: Int32) -> String {
    botFrame(handle) { entry in
        entry.match.start(configuration: HouseRocketsConfiguration(botCount: Int(botCount)))
        entry.courseKey = ""
        return [:]
    }
}

/// One countdown step; Android calls it every `countdownStepMillis`.
public func houseRocketsBotCountdown(_ handle: Int32) -> String {
    botFrame(handle) { entry in
        ["started": entry.match.advanceCountdown()]
    }
}

/// Applies the latest human heading (when `hasSteer`) and advances physics by
/// `delta` seconds. One call per rendered frame while playing.
public func houseRocketsBotStep(
    _ handle: Int32, _ delta: Double, _ hasSteer: Bool, _ heading: Double, _ sequence: Int32
) -> String {
    botFrame(handle) { entry in
        var steered = false
        if hasSteer, let snapshot = entry.match.snapshot, let human = snapshot.humanPlayer {
            steered = entry.match.send(HouseRocketsCommand(
                matchID: snapshot.matchID, playerID: human.id, sequence: Int(sequence),
                action: .steer(heading: heading)
            ))
        }
        let eliminated = entry.match.advance(by: delta)
        return ["steered": steered, "eliminated": eliminated.map(\.uuidString)]
    }
}

public func houseRocketsBotPause(_ handle: Int32) -> String {
    botFrame(handle) { entry in ["changed": entry.match.pause()] }
}

/// `resumed` is the phase to restart a timer for: "countdown" or "playing".
public func houseRocketsBotResume(_ handle: Int32) -> String {
    botFrame(handle) { entry in
        ["resumed": entry.match.resume()?.rawValue ?? NSNull()]
    }
}

/// Accepted only after the match ended; keeps the bot count.
public func houseRocketsBotRestart(_ handle: Int32) -> String {
    botFrame(handle) { entry in
        guard let snapshot = entry.match.snapshot else { return ["changed": false] }
        let changed = entry.match.send(HouseRocketsCommand(
            matchID: snapshot.matchID, playerID: nil, sequence: 0, action: .restart
        ))
        if changed { entry.courseKey = "" }
        return ["changed": changed]
    }
}

/// Bundled TR/EN game copy for one language; remote plaintext still overrides it.
public func houseRocketsCopy(_ language: String) -> String {
    bridgeJSON(HouseRocketsLocalization.table(language: language))
}

/// Static match constants Android needs for scheduling and layout.
public func houseRocketsConstants() -> String {
    bridgeJSON([
        "countdownStepMillis": Int(HouseRocketsBotMatch.countdownStepSeconds * 1_000),
        "trackHeight": HouseRocketsSimulation.trackHeight,
        "viewportWidth": HouseRocketsSimulation.viewportWidth,
        "fieldRadius": HouseRocketsSpeedField.radius,
        "fieldArtworkScale": HouseRocketsSpeedField.artworkScale,
        "botNameKeys": HouseRocketsBotMatch.botNameKeys,
        "humanNameKey": HouseRocketsBotMatch.humanNameKey,
        "colors": HouseRocketsColor.allCases.map(\.rawValue),
    ])
}

private func botFrame(
    _ handle: Int32, _ action: (inout BotMatchRegistry.Entry) -> [String: Any]
) -> String {
    let result = BotMatchRegistry.shared.with(handle) { entry -> [String: Any] in
        var object = action(&entry)
        guard let snapshot = entry.match.snapshot else {
            object["ok"] = true
            return object
        }
        let frame = HouseRocketsRenderFrame.local(snapshot)
        let courseKey = frame.gates.map(\.id).joined(separator: ",")
        object.merge(HouseRocketsFrameJSON.object(
            snapshot: snapshot, frame: frame, viewport: entry.viewport,
            includeGates: courseKey != entry.courseKey
        )) { current, _ in current }
        entry.courseKey = courseKey
        object["ok"] = true
        return object
    }
    return bridgeJSON(result ?? ["ok": false, "message": "Unknown match handle"])
}

/// The Android render contract. Coordinates are course units; the projection
/// maps them to the viewport (in dp, y down) exactly as SpriteKit does on iOS.
enum HouseRocketsFrameJSON {
    /// A local bot frame: the shared render keys plus the match's own bookkeeping.
    static func object(snapshot: HouseRocketsSnapshot, frame: HouseRocketsRenderFrame,
                       viewport: BotMatchRegistry.Viewport, includeGates: Bool) -> [String: Any] {
        var object = render(frame: frame, viewport: viewport, includeGates: includeGates)
        object.merge([
            "matchId": snapshot.matchID.uuidString,
            "revision": snapshot.revision,
            "phase": snapshot.phase.rawValue,
            "countdown": snapshot.countdown ?? NSNull(),
            "aliveCount": snapshot.aliveCount,
            "winnerId": snapshot.winnerID?.uuidString ?? NSNull(),
            "lastEliminatedId": snapshot.lastEliminatedID?.uuidString ?? NSNull(),
            "players": zip(snapshot.players, frame.players).map { player, rendered in
                var object = playerObject(rendered, courseAngle: frame.courseAngle)
                object["nameKey"] = player.nameKey
                object["heading"] = player.heading
                return object
            },
        ]) { _, new in new }
        return object
    }

    /// Keys every frame carries, local or online.
    static func render(frame: HouseRocketsRenderFrame, viewport: BotMatchRegistry.Viewport,
                       includeGates: Bool) -> [String: Any] {
        var object: [String: Any] = [
            "matchId": frame.sessionID,
            "phase": frame.phase.rawValue,
            "countdown": NSNull(),
            "elapsed": frame.elapsedTime,
            "cameraX": frame.cameraX,
            "courseAngle": frame.courseAngle,
            "aliveCount": frame.players.filter(\.isAlive).count,
            "winnerId": NSNull(),
            "lastEliminatedId": NSNull(),
            "direction": HouseRocketsCourse.transitionTargetIsVertical(at: frame.elapsedTime)
                .map { $0 ? "vertical" : "horizontal" } ?? NSNull(),
            "players": frame.players.map { playerObject($0, courseAngle: frame.courseAngle) },
            "fields": frame.speedFields.map { [
                "id": $0.id, "x": $0.worldX, "y": $0.worldY(at: frame.elapsedTime), "effect": $0.effect.rawValue,
            ] as [String: Any] },
        ]
        if includeGates {
            object["gates"] = frame.gates.map { gate in [
                "id": gate.id,
                "x": gate.worldX,
                "width": gate.width,
                "polygons": gate.solidPolygons.map { polygon in polygon.flatMap { [$0.x - gate.worldX, $0.y] } },
            ] as [String: Any] }
        }
        if isUsable(viewport.width, viewport.height) {
            let projection = HouseRocketsProjection(
                elapsedTime: frame.elapsedTime, cameraX: frame.cameraX,
                width: viewport.width, height: viewport.height, courseAngle: frame.courseAngle
            )
            object["projection"] = [
                "angle": projection.angle, "scale": projection.scale,
                "originX": projection.origin.x, "originY": projection.origin.y,
                "visibleLength": projection.visibleLength, "turning": projection.isTurning,
            ]
        }
        if isUsable(viewport.hudWidth, viewport.hudHeight) {
            // The HUD measures its own safe area, exactly like iOS's information layer.
            let hud = HouseRocketsProjection(
                elapsedTime: frame.elapsedTime, cameraX: frame.cameraX,
                width: viewport.hudWidth, height: viewport.hudHeight, courseAngle: frame.courseAngle
            )
            object["regions"] = hud.informationRegions(width: viewport.hudWidth, height: viewport.hudHeight)
                .map { [$0.x, $0.y, $0.width, $0.height] }
        }
        return object
    }

    private static func playerObject(_ player: HouseRocketsRenderPlayer, courseAngle: Double) -> [String: Any] {
        let name: (key: String, display: String)
        switch player.name {
        case .localizationKey(let key): name = (key, "")
        case .displayName(let value): name = ("", value)
        }
        let heading = player.courseHeading + courseAngle
        return [
            "id": player.id,
            "nameKey": name.key,
            "name": name.display,
            "role": player.role.rawValue,
            "color": player.color.rawValue,
            "alive": player.isAlive,
            "x": player.worldX,
            "y": player.worldY,
            "courseHeading": player.courseHeading,
            "heading": atan2(sin(heading), cos(heading)),
            "effect": player.speedEffect?.rawValue ?? NSNull(),
            "effectRemaining": player.effectRemaining,
        ]
    }
}

func isUsable(_ width: Double, _ height: Double) -> Bool {
    width > 0 && height > 0 && width.isFinite && height.isFinite
}

func bridgeJSON(_ object: Any) -> String {
    guard let data = try? JSONSerialization.data(withJSONObject: object, options: [.sortedKeys]),
          let string = String(data: data, encoding: .utf8) else { return "{\"ok\":false}" }
    return string
}
