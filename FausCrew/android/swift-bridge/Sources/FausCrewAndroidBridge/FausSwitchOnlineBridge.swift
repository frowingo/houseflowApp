import Foundation
import FausCrewCore

// The Faus Switch online room behind a handle, in House Tanks' shape: the engine
// (FausCrewCore) decides every lobby, color, reconnect, control and result rule; Android
// performs the returned effects with OkHttp and reports their outcome. The output is the
// one `OnlineOutputParser` reads, plus Faus Switch's lobby colors. The race is drawn from
// `fausSwitchOnlineFrame` once per rendered frame, in the demo's render contract
// (`FausSwitchFrameJSON`).

final class SwitchOnlineRegistry: @unchecked Sendable {
    static let shared = SwitchOnlineRegistry()
    private let lock = NSLock()
    private var nextHandle: Int32 = 1
    private var entries: [Int32: Entry] = [:]

    final class Entry {
        let engine: FausSwitchOnlineEngine
        var lastLobby: FausSwitchOnlineLobbyState?
        var lastPreferred: FausSwitchColor?
        var viewport = FausSwitchViewport(screenWidth: FausSwitchMetrics.viewportWidth,
                                          screenHeight: FausSwitchMetrics.worldHeight)
        var render = FausSwitchFrameJSON.RenderState()
        /// The race stays drawn after its last presentation, under the result panel.
        var lastFrame: FausSwitchRenderFrame?
        /// A rematch shows its own room until the new race's first snapshot.
        var isRematchRoom: Bool
        init(engine: FausSwitchOnlineEngine, isRematchRoom: Bool) {
            self.engine = engine
            self.isRematchRoom = isRematchRoom
        }
    }

    func create(_ engine: FausSwitchOnlineEngine, isRematchRoom: Bool) -> Int32 {
        lock.lock(); defer { lock.unlock() }
        let handle = nextHandle
        nextHandle = nextHandle == Int32.max ? 1 : nextHandle + 1
        entries[handle] = Entry(engine: engine, isRematchRoom: isRematchRoom)
        return handle
    }

    func destroy(_ handle: Int32) -> Bool {
        lock.lock(); defer { lock.unlock() }
        guard let entry = entries.removeValue(forKey: handle) else { return false }
        entry.engine.disconnect()
        return true
    }

    func with<T>(_ handle: Int32, _ body: (Entry) -> T) -> T? {
        lock.lock(); defer { lock.unlock() }
        guard let entry = entries[handle] else { return nil }
        return body(entry)
    }
}

/// Empty ids mean "none". `excludingSessionId` is set for a rematch; `preferredColor` is
/// the remembered robot color ("" for none), asked for as soon as the player is seated.
public func fausSwitchOnlineCreate(
    _ houseId: String, _ playerId: String, _ houseOwnerId: String, _ excludingSessionId: String, _ preferredColor: String
) -> Int32 {
    let context = GameLaunchContext(houseID: houseId.isEmpty ? nil : houseId,
                                    localPlayerID: playerId.isEmpty ? nil : playerId,
                                    houseOwnerID: houseOwnerId.isEmpty ? nil : houseOwnerId)
    let engine = FausSwitchOnlineEngine(context: context,
                                        excludingSessionID: excludingSessionId.isEmpty ? nil : excludingSessionId,
                                        preferredColor: FausSwitchColor(rawValue: preferredColor))
    return SwitchOnlineRegistry.shared.create(engine, isRematchRoom: !excludingSessionId.isEmpty)
}

public func fausSwitchOnlineDestroy(_ handle: Int32) -> Bool {
    SwitchOnlineRegistry.shared.destroy(handle)
}

/// One user intent or host outcome as JSON `{"type": …, "now": uptimeSeconds, …}`.
/// Socket text frames go through `fausSwitchOnlineReceive` to avoid re-escaping.
/// A `flip` answers `flip`: "flipped", "unsupported" or "ignored".
public func fausSwitchOnlineEvent(_ handle: Int32, _ eventJSON: String) -> String {
    switchOnlineOutput(handle) { entry in
        guard let event = (try? JSONSerialization.jsonObject(with: Data(eventJSON.utf8))) as? [String: Any],
              let type = event["type"] as? String else { return nil }
        let now = event["now"] as? Double ?? 0
        let engine = entry.engine
        let connection = event["connection"] as? Int ?? -1
        let request = event["request"] as? Int ?? -1
        switch type {
        case "start":
            engine.start(isForeground: event["foreground"] as? Bool ?? true,
                         isLandscape: event["landscape"] as? Bool ?? false, now: now)
        case "sessionResponse":
            engine.sessionResponse(onlineHTTPResponse(event), retryAfter: event["retryAfter"] as? Double,
                                   connection: connection, now: now)
        case "socketOpened": engine.socketOpened(connection: connection, now: now)
        case "connectionFailed": engine.connectionFailed(onlineFailure(event), connection: connection, now: now)
        case "sendFailed": engine.sendFailed(onlineFailure(event), connection: connection, now: now)
        case "resultResponse":
            engine.resultResponse(onlineHTTPResponse(event), retryAfter: event["retryAfter"] as? Double,
                                  request: request, now: now)
        case "resultFailed": engine.resultFailed(request: request, now: now)
        case "tick": engine.tick(now: now)
        case "setReady": engine.setReady(event["ready"] as? Bool ?? false, now: now)
        case "readyOnJoin": engine.readyOnJoin(now: now)
        case "setLandscape": engine.setLandscape(event["landscape"] as? Bool ?? false, now: now)
        case "setForeground": engine.setForeground(event["foreground"] as? Bool ?? false, now: now)
        case "retry": engine.retry(now: now)
        case "retryResult": engine.retryResult(now: now)
        case "cancel": engine.cancelMatch(now: now)
        case "reclaim": engine.reclaimControl(now: now)
        case "selectColor":
            guard let color = (event["color"] as? String).flatMap(FausSwitchColor.init(rawValue:)) else { return nil }
            engine.selectColor(color, now: now)
        case "flip":
            return ["flip": FausSwitchOnlineJSON.feedback(engine.flip(now: now))]
        case "setReduceMotion": engine.setReduceMotion(event["enabled"] as? Bool ?? false)
        case "leave": engine.leave(now: now)
        case "disconnect": engine.disconnect()
        default: return nil
        }
        return [:]
    }
}

public func fausSwitchOnlineReceive(_ handle: Int32, _ text: String, _ connection: Int32, _ now: Double) -> String {
    switchOnlineOutput(handle) { entry in
        entry.engine.received(text: text, connection: Int(connection), now: now)
        return [:]
    }
}

/// The playfield's size in screen points; the next frame resends platforms and the lost zone.
public func fausSwitchOnlineViewport(_ handle: Int32, _ width: Double, _ height: Double) -> String {
    let result = SwitchOnlineRegistry.shared.with(handle) { entry -> [String: Any] in
        guard isUsable(width, height) else { return ["ok": true, "changed": false] }
        entry.viewport = FausSwitchViewport(screenWidth: width, screenHeight: height)
        entry.render = .init()
        return ["ok": true, "changed": true]
    }
    return bridgeJSON(result ?? ["ok": false, "message": "Unknown match handle"])
}

/// One drawn frame of the race: `frame` (the demo's render contract) once there is a
/// race, `events` for the local robot (its portal throw), and always `match`, the bars
/// and panels over it, with `result` while the result panel shows. Each event is in
/// exactly one frame, so Android calls this once per rendered frame.
public func fausSwitchOnlineFrame(_ handle: Int32, _ now: Double) -> String {
    let result = SwitchOnlineRegistry.shared.with(handle) { entry -> [String: Any] in
        let engine = entry.engine
        if entry.isRematchRoom, engine.lobby.game != nil { entry.isRematchRoom = false }
        let presentation = engine.presentation(at: now)
        if let frame = presentation?.frame { entry.lastFrame = frame }
        let ui = FausSwitchMatchUI.online(state: engine.lobby, presentation: presentation, lastFrame: entry.lastFrame,
                                          result: engine.result, isRematchRoom: entry.isRematchRoom, now: now)
        var match = FausSwitchFrameJSON.ui(ui, viewport: entry.viewport)
        match["countdown"] = (ui.phase == .countdown ? ui.countdown : nil) ?? NSNull()
        match["roomCountdown"] = engine.roomCountdown(at: now) ?? NSNull()
        if ui.showsResult {
            let live = entry.lastFrame.map(FausSwitchMatchUI.standings(from:)) ?? []
            match["result"] = FausSwitchOnlineJSON.result(engine.result, live: live,
                                                          localPlayerID: engine.context.localPlayerID, now: now)
        }
        var object: [String: Any] = [
            "ok": true,
            "match": match,
            "events": (presentation?.events ?? []).map(FausSwitchFrameJSON.event),
        ]
        if let frame = presentation?.frame ?? entry.lastFrame {
            object["frame"] = FausSwitchFrameJSON.world(frame, viewport: entry.viewport, state: &entry.render)
        }
        return object
    }
    return bridgeJSON(result ?? ["ok": false, "message": "Unknown match handle"])
}

/// `GET /game/catalog` for one house, reduced to what the Faus Switch room needs.
/// `available` is null when the catalog could not be read (the server still guards).
public func fausSwitchCatalogResponse(_ houseId: String, _ status: Int32, _ body: String) -> String {
    do {
        let catalog = try GameWireContract.decodeCatalog(
            houseId: houseId, response: HTTPResponse(statusCode: Int(status), headers: [:], body: Data(body.utf8)))
        guard let entry = catalog.fausSwitch else { return bridgeJSON(["ok": true, "available": false]) }
        return bridgeJSON(["ok": true, "available": true, "maximumPlayers": entry.rules.maximumPlayers])
    } catch {
        return bridgeJSON(["ok": true, "available": NSNull()])
    }
}

/// `action` returns extra output keys, or nil for an unsupported event.
private func switchOnlineOutput(_ handle: Int32, _ action: (SwitchOnlineRegistry.Entry) -> [String: Any]?) -> String {
    let result = SwitchOnlineRegistry.shared.with(handle) { entry -> [String: Any] in
        guard let extra = action(entry) else { return ["ok": false, "message": "Unsupported event"] }
        let engine = entry.engine
        if entry.isRematchRoom, engine.lobby.game != nil { entry.isRematchRoom = false }
        var object: [String: Any] = [
            "ok": true,
            "effects": engine.drainEffects().map { onlineEffectObject($0, gameKey: GameKey.fausSwitch) },
        ]
        object.merge(extra) { _, new in new }
        if engine.lobby != entry.lastLobby || engine.preferredColor != entry.lastPreferred {
            entry.lastLobby = engine.lobby
            entry.lastPreferred = engine.preferredColor
            object["lobby"] = FausSwitchOnlineJSON.lobby(engine.lobby, context: engine.context,
                                                         preferredColor: engine.preferredColor,
                                                         isRematchRoom: entry.isRematchRoom)
        }
        object["closed"] = engine.isClosed
        object["rematchExcludedSessionId"] = engine.rematchExcludedSessionID ?? NSNull()
        return object
    }
    return bridgeJSON(result ?? ["ok": false, "message": "Unknown match handle"])
}

/// Screen-ready room models; the copy and color rules come from Core.
enum FausSwitchOnlineJSON {
    /// House Rockets' lobby keys (one Kotlin parser reads both), the update flag and the
    /// robot colors: each participant's claim, the colors held by others and the local
    /// robot's color (the pick while it is free, else the server's claim).
    static func lobby(_ state: FausSwitchOnlineLobbyState, context: GameLaunchContext,
                      preferredColor: FausSwitchColor?, isRematchRoom: Bool) -> [String: Any] {
        let local = context.localPlayerID
        let session = state.session
        func uptime(_ date: Date?) -> Any {
            guard let date, let clock = state.serverClock else { return NSNull() }
            return clock.localUptime + date.timeIntervalSince(clock.serverTime)
        }
        let deadline: Date? = session?.state == .countdown ? session?.countdownEndsAt
            : session?.state == .readyWindow ? session?.readyWindowEndsAt : nil
        let colors = state.lobbyColors(localPlayerID: local)
        let status = isRematchRoom ? "faus_switch_online_rematch_room" : FausSwitchOnlineCopyKeys.roomStatus(state)
        let detail = FausSwitchOnlineCopyKeys.roomDetail(state)
        return [
            "connection": "\(state.connection)",
            "isSynced": state.isSynced,
            "isLobby": state.isLobby,
            "isTerminal": state.isTerminal,
            "isLeaving": state.isLeaving,
            "isForeground": state.isForeground,
            "controlTransferred": state.controlTransferred,
            "hasGame": state.game != nil,
            // The race screen opens from the race's first snapshot (its countdown) on.
            "gamePhase": state.game?.phase.rawValue ?? NSNull(),
            "sessionState": session.map { $0.state.rawValue } ?? NSNull(),
            "statusKey": status,
            "detailKey": detail,
            "showsProgress": FausSwitchOnlineCopyKeys.showsProgress(state),
            "issueKey": state.issue.map(FausSwitchOnlineCopyKeys.issue) ?? NSNull(),
            "connectionTitleKey": status,
            "connectionDetailKey": detail,
            "minimumPlayers": session?.rules.minimumPlayers ?? 2,
            "retryNotBefore": state.retryNotBefore ?? NSNull(),
            "canRetry": state.canReconnect(at: .infinity),
            "requiresAuthentication": state.requiresAuthentication,
            "requiresUpdate": state.requiresUpdate,
            "canChangeReady": state.canChangeReady(playerID: local) && colors.allowsReady,
            "canCancel": state.canCancel(context: context),
            "localReady": state.localPlayer(local)?.state == .ready,
            "readyCount": state.readyCount,
            "isRematchRoom": isRematchRoom,
            "participants": state.participants.map { player -> [String: Any] in
                let isLocal = player.playerId == local
                let color = isLocal ? colors.localColor(preferred: preferredColor) : colors.color(of: player.playerId)
                return [
                    "playerId": player.playerId,
                    "statusKey": FausSwitchOnlineCopyKeys.playerStatus(player.state),
                    "ready": player.state == .ready,
                    "isLocal": isLocal,
                    "color": color?.rawValue ?? NSNull(),
                ]
            },
            "colors": [
                "preferred": preferredColor?.rawValue ?? NSNull(),
                "local": colors.localColor(preferred: preferredColor)?.rawValue ?? NSNull(),
                "localClaim": colors.localClaim?.rawValue ?? NSNull(),
                "takenByOthers": FausSwitchColor.allCases.filter(colors.isTakenByOthers).map(\.rawValue),
                "isPreferredTaken": colors.isPreferredTaken(preferredColor),
                "isLocked": colors.isLocked,
            ] as [String: Any],
            "deadlineKind": (session?.state == .countdown ? "countdown" : session?.state == .readyWindow ? "ready" : nil)
                ?? NSNull() as Any,
            "deadlineUptime": uptime(deadline),
            "raceCountdownUptime": uptime(state.game?.phase == .countdown ? state.game?.countdownEndsAt
                                          : session?.countdownEndsAt),
        ]
    }

    /// The result panel: copy keys, the standings (the race's last standings until the
    /// persisted ranks) and the rematch gate.
    static func result(_ state: FausSwitchOnlineResultState, live: [FausSwitchStanding], localPlayerID: String?,
                       now: Double) -> [String: Any] {
        var object: [String: Any] = [
            "phase": "\(state.phase)",
            "isWaiting": state.phase == .waiting || state.phase == .idle,
            "isFailed": state.phase == .failed,
            "detailKey": FausSwitchOnlineCopyKeys.resultDetail(state),
            "canRematch": state.canRematch,
            "canRetry": state.phase == .failed && state.canRetry(at: now),
            "retryNotBefore": state.retryNotBefore,
            "sessionId": state.sessionID ?? NSNull(),
            "winnerId": NSNull(),
            "winnerName": NSNull(),
        ]
        switch FausSwitchOnlineCopyKeys.resultTitle(state, localPlayerID: localPlayerID) {
        case .key(let key):
            object["titleKey"] = key
        case .lost(let winner):
            object["titleKey"] = "faus_switch_online_lost"
            object["winnerId"] = winner
            object["winnerName"] = state.identities[winner]?.displayName ?? NSNull()
        }
        object["standings"] = FausSwitchMatchUI.resultStandings(state, live: live, localPlayerID: localPlayerID)
            .map(FausSwitchFrameJSON.standing)
        return object
    }

    static func feedback(_ feedback: FausSwitchFlipFeedback) -> String {
        switch feedback {
        case .flipped: "flipped"
        case .unsupported: "unsupported"
        case .ignored: "ignored"
        }
    }
}
