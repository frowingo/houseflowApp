import Foundation
import FausCrewCore

// FauseTanks demo match. Rules, physics, bots and jokers stay in FausCrewCore;
// Android owns timers, input and drawing. Gameplay is one JNI call per rendered
// frame: each step returns the moving state, and the static arena (furniture and
// crate shapes) is resent only when a round starts. The arena is the fixed 872×400
// of contract houseTanks.v2; Android fits it to its canvas.

final class TanksMatchRegistry: @unchecked Sendable {
    static let shared = TanksMatchRegistry()
    private let lock = NSLock()
    private var nextHandle: Int32 = 1
    private var entries: [Int32: Entry] = [:]

    struct Entry {
        var match = HouseTanksBotMatch()
        var arenaRoundKey = ""
        var pressSequence = 0
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

public func houseTanksBotCreate() -> Int32 {
    TanksMatchRegistry.shared.create()
}

public func houseTanksBotDestroy(_ handle: Int32) -> Bool {
    TanksMatchRegistry.shared.destroy(handle)
}

/// Starts (or replaces) a match; the countdown starts at 3. Unknown values are rejected and
/// `playerCount` (the human included) is clamped to the map's demo player range.
public func houseTanksBotStart(_ handle: Int32, _ difficulty: String, _ color: String, _ map: String,
                               _ playerCount: Int32) -> String {
    guard let difficulty = HouseTanksDifficulty(rawValue: difficulty),
          let color = HouseTanksColor(rawValue: color),
          let map = HouseTanksMapID(rawValue: map) else {
        return bridgeJSON(["ok": false, "message": "Unknown FauseTanks setup"])
    }
    return tanksFrame(handle) { entry in
        entry.match.start(configuration: HouseTanksMatchConfiguration(difficulty: difficulty, humanColor: color, mapID: map,
                                                                      playerCount: Int(playerCount)))
        entry.arenaRoundKey = ""
        entry.pressSequence = 0
        return [:]
    }
}

/// One countdown step; Android calls it every `countdownStepMillis`.
public func houseTanksBotCountdown(_ handle: Int32) -> String {
    tanksFrame(handle) { entry in ["started": entry.match.advanceCountdown()] }
}

/// Advances the arena by `delta` seconds. One call per rendered frame while playing.
public func houseTanksBotStep(_ handle: Int32, _ delta: Double) -> String {
    tanksFrame(handle) { entry in
        entry.match.advance(by: delta)
        return [:]
    }
}

/// The human's press (`true`) or release (`false`) on the playfield.
public func houseTanksBotPress(_ handle: Int32, _ pressed: Bool) -> String {
    tanksFrame(handle) { entry in
        guard let snapshot = entry.match.snapshot, let human = snapshot.humanPlayer else { return ["changed": false] }
        entry.pressSequence += 1
        let changed = entry.match.send(HouseTanksCommand(
            matchID: snapshot.matchID, playerID: human.id, sequence: entry.pressSequence,
            action: pressed ? .pressStarted : .pressEnded
        ))
        return ["changed": changed]
    }
}

public func houseTanksBotNextRound(_ handle: Int32) -> String {
    tanksFrame(handle) { entry in ["changed": entry.match.sendSystem(.nextRound)] }
}

public func houseTanksBotRestart(_ handle: Int32) -> String {
    tanksFrame(handle) { entry in ["changed": entry.match.sendSystem(.restartMatch)] }
}

public func houseTanksBotPause(_ handle: Int32) -> String {
    tanksFrame(handle) { entry in ["changed": entry.match.pause()] }
}

public func houseTanksBotResume(_ handle: Int32) -> String {
    tanksFrame(handle) { entry in ["changed": entry.match.resume()] }
}

/// Bundled TR/EN FauseTanks copy for one language; remote plaintext still overrides it.
public func houseTanksCopy(_ language: String) -> String {
    bridgeJSON(HouseTanksLocalization.table(language: language))
}

/// The catalog maps, normalized (y up), for lobby previews. `minPlayers`/`maxPlayers` and
/// `spawns` are the demo's seats: four on standard maps, the full range on crowded ones.
public func houseTanksMaps() -> String {
    bridgeJSON([
        "obstacleScale": HouseTanksMapCatalog.obstacleBaseScale * HouseTanksMapCatalog.gameplayScale,
        "maps": HouseTanksMapID.allCases.map { id -> [String: Any] in
            let map = HouseTanksMapCatalog.definition(for: id)
            let seats = map.demoPlayerCounts
            return [
                "id": id.rawValue,
                "scale": map.scale,
                "minPlayers": seats.lowerBound,
                "maxPlayers": seats.upperBound,
                "spawns": map.spawnPoints.prefix(seats.upperBound).map { [$0.x, $0.y] },
                "obstacles": map.obstacles.map { obstacle -> [String: Any] in [
                    "x": obstacle.center.x, "y": obstacle.center.y,
                    "width": obstacle.size.width, "height": obstacle.size.height,
                    "rotation": obstacle.rotation, "style": obstacle.style.rawValue, "tone": obstacle.tone.rawValue,
                ] },
                "lines": map.floorLines.map { [$0.start.x, $0.start.y, $0.end.x, $0.end.y] },
                "markers": map.floorMarkers.map { [$0.x, $0.y] },
            ]
        },
    ])
}

/// Static match constants Android needs for scheduling and drawing.
public func houseTanksConstants() -> String {
    bridgeJSON([
        "countdownStepMillis": Int(HouseTanksBotMatch.countdownStepSeconds * 1_000),
        "jokerDuration": HouseTanksPowerUpRules.duration,
        "tokenLifetime": HouseTanksPowerUpRules.tokenLifetime,
        "tankLength": HouseTanksWorld.tankLength,
        "botNameKeys": HouseTanksMatchConfiguration.botNameKeys,
        "humanNameKey": HouseTanksMatchConfiguration.humanNameKey,
        "colors": HouseTanksColor.allCases.map(\.rawValue),
        "jokers": HouseTanksPowerUp.allCases.map(\.rawValue),
        "maps": HouseTanksMapID.allCases.map(\.rawValue),
        "difficulties": HouseTanksDifficulty.allCases.map(\.rawValue),
    ])
}

extension HouseTanksBotMatch {
    /// Host commands that need no player.
    mutating func sendSystem(_ action: HouseTanksAction) -> Bool {
        guard let snapshot else { return false }
        return send(HouseTanksCommand(matchID: snapshot.matchID, playerID: nil, sequence: 0, action: action))
    }
}

private func tanksFrame(_ handle: Int32, _ action: (inout TanksMatchRegistry.Entry) -> [String: Any]) -> String {
    let result = TanksMatchRegistry.shared.with(handle) { entry -> [String: Any] in
        var object = action(&entry)
        guard let snapshot = entry.match.snapshot, let world = entry.match.world else {
            object["ok"] = true
            return object
        }
        let roundKey = "\(snapshot.matchID.uuidString)-\(snapshot.roundNumber)"
        object.merge(HouseTanksFrameJSON.object(snapshot: snapshot, world: world, roundKey: roundKey,
                                                events: entry.match.drainEvents(),
                                                includeArena: roundKey != entry.arenaRoundKey)) { current, _ in current }
        entry.arenaRoundKey = roundKey
        object["ok"] = true
        return object
    }
    return bridgeJSON(result ?? ["ok": false, "message": "Unknown match handle"])
}

/// The Android render contract. Positions are arena points of the fixed 872×400 arena with
/// SpriteKit's y-up origin; the canvas scales them to fit and flips y exactly once.
enum HouseTanksFrameJSON {
    static func object(snapshot: HouseTanksSnapshot, world: HouseTanksWorld, roundKey: String,
                       events: [HouseTanksWorld.Event], includeArena: Bool) -> [String: Any] {
        let roles = Dictionary(uniqueKeysWithValues: snapshot.players.map { (HouseTanksBotMatch.tankID($0.id), $0.role) })
        var object: [String: Any] = [
            "matchId": snapshot.matchID.uuidString,
            "roundKey": roundKey,
            "revision": snapshot.revision,
            "phase": snapshot.phase.rawValue,
            "countdown": snapshot.countdown ?? NSNull(),
            "roundNumber": snapshot.roundNumber,
            "roundWinnerId": snapshot.roundWinnerID?.uuidString ?? NSNull(),
            "championId": snapshot.championID?.uuidString ?? NSNull(),
            "players": snapshot.players.map { player -> [String: Any] in [
                "id": player.id.uuidString, "nameKey": player.nameKey, "role": player.role.rawValue,
                "color": player.color.rawValue, "armor": player.armor, "roundsWon": player.roundsWon,
                "alive": player.isAlive,
            ] },
            "width": world.size.width,
            "height": world.size.height,
            "time": world.time,
            "tanks": world.tanks.map { tank -> [String: Any] in
                let power = world.powerUpStatus(for: tank.id)
                return [
                    "id": tank.id, "color": tank.color.rawValue, "role": (roles[tank.id] ?? .bot).rawValue,
                    "x": tank.position.x, "y": tank.position.y, "rotation": tank.rotation, "active": tank.isActive,
                    "power": power?.kind.rawValue ?? NSNull(),
                    "powerFraction": power.map { $0.remaining / HouseTanksPowerUpRules.duration } ?? 0,
                    "aimLength": world.aimLength(for: tank.id) ?? NSNull(),
                ]
            },
            "crates": world.obstacles.filter(\.isMovable).map { crate -> [String: Any] in [
                "index": crate.index, "x": crate.position.x, "y": crate.position.y, "destroyed": crate.isDestroyed,
            ] },
            "projectiles": world.projectiles.map { shot -> [String: Any] in [
                "id": shot.id, "x": shot.position.x, "y": shot.position.y, "rotation": shot.rotation,
                "rocket": shot.isRocket, "color": shot.color.rawValue,
            ] },
            "token": world.token.map { token -> [String: Any] in [
                "kind": token.kind.rawValue, "x": token.position.x, "y": token.position.y,
                "fraction": world.tokenFraction,
            ] } ?? NSNull(),
            "events": events.compactMap(eventObject),
        ]
        if includeArena {
            let frame = world.arenaFrame
            object["arena"] = [
                "mapId": world.map.id.rawValue,
                "scale": world.scale,
                "frame": [frame.x, frame.y, frame.width, frame.height],
                "obstacles": world.obstacles.map { obstacle -> [String: Any] in [
                    "index": obstacle.index, "style": obstacle.definition.style.rawValue,
                    "tone": obstacle.definition.tone.rawValue, "x": obstacle.position.x, "y": obstacle.position.y,
                    "width": obstacle.size.width, "height": obstacle.size.height, "rotation": obstacle.rotation,
                    "movable": obstacle.isMovable, "destroyed": obstacle.isDestroyed,
                ] },
                "lines": world.map.floorLines.map { line -> [Double] in
                    let start = line.start.point()
                    let end = line.end.point()
                    return [start.x, start.y, end.x, end.y]
                },
                "markers": world.map.floorMarkers.map { marker -> [Double] in
                    let point = marker.point()
                    return [point.x, point.y]
                },
            ] as [String: Any]
        }
        return object
    }

    /// Effects the canvas animates; armor changes reach it through the players instead.
    private static func eventObject(_ event: HouseTanksWorld.Event) -> [String: Any]? {
        let position = event.position ?? .zero
        switch event.kind {
        case .fired:
            return ["type": "fired", "playerId": event.playerID ?? "", "angle": event.angle ?? 0]
        case .shielded:
            return ["type": "shielded", "playerId": event.playerID ?? ""]
        case .crateBroken:
            return ["type": "crateBroken", "index": event.crateIndex ?? 0, "x": position.x, "y": position.y]
        case .explosion:
            return ["type": "explosion", "x": position.x, "y": position.y]
        case .eliminated:
            return ["type": "eliminated", "playerId": event.playerID ?? "", "x": position.x, "y": position.y]
        case .jokerCollected:
            return ["type": "jokerCollected", "playerId": event.playerID ?? "", "kind": event.powerUp?.rawValue ?? ""]
        case .hit:
            return nil
        }
    }
}
