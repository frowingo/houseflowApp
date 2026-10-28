import Foundation
import FausCrewCore

// The FauseTanks online room behind a handle, in House Rockets' shape: the engine
// (FausCrewCore) decides every lobby, reconnect and control rule; Android performs the
// returned effects with OkHttp and reports their outcome. The output is the one
// `OnlineOutputParser` reads, plus `preview` (the server's seated arena) whenever it
// changed. Lobby and preview are included only when they changed since the last call.
// The match is drawn from `houseTanksOnlineFrame`, once per rendered frame.

final class TanksOnlineRegistry: @unchecked Sendable {
    static let shared = TanksOnlineRegistry()
    private let lock = NSLock()
    private var nextHandle: Int32 = 1
    private var entries: [Int32: Entry] = [:]

    final class Entry {
        let engine: HouseTanksOnlineEngine
        var lastLobby: HouseTanksOnlineLobbyState?
        var lastPreview: [String: Any]?
        var sentPreview = false
        var arenaRoundKey = ""
        /// The seat bar stays after the match's last presentation, under the result panel.
        var lastSeats: [HouseTanksOnlineSeat] = []
        init(engine: HouseTanksOnlineEngine) { self.engine = engine }
    }

    func create(_ engine: HouseTanksOnlineEngine) -> Int32 {
        lock.lock(); defer { lock.unlock() }
        let handle = nextHandle
        nextHandle = nextHandle == Int32.max ? 1 : nextHandle + 1
        entries[handle] = Entry(engine: engine)
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

/// Empty ids mean "none". `excludingSessionId` is set for a rematch.
public func houseTanksOnlineCreate(
    _ houseId: String, _ playerId: String, _ houseOwnerId: String, _ excludingSessionId: String
) -> Int32 {
    let context = GameLaunchContext(houseID: houseId.isEmpty ? nil : houseId,
                                    localPlayerID: playerId.isEmpty ? nil : playerId,
                                    houseOwnerID: houseOwnerId.isEmpty ? nil : houseOwnerId)
    return TanksOnlineRegistry.shared.create(HouseTanksOnlineEngine(
        context: context, excludingSessionID: excludingSessionId.isEmpty ? nil : excludingSessionId))
}

public func houseTanksOnlineDestroy(_ handle: Int32) -> Bool {
    TanksOnlineRegistry.shared.destroy(handle)
}

/// One user intent or host outcome as JSON `{"type": …, "now": uptimeSeconds, …}`.
/// Socket text frames go through `houseTanksOnlineReceive` to avoid re-escaping.
public func houseTanksOnlineEvent(_ handle: Int32, _ eventJSON: String) -> String {
    tanksOnlineOutput(handle) { entry in
        guard let event = (try? JSONSerialization.jsonObject(with: Data(eventJSON.utf8))) as? [String: Any],
              let type = event["type"] as? String else { return false }
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
        case "setLandscape": engine.setLandscape(event["landscape"] as? Bool ?? false, now: now)
        case "setForeground": engine.setForeground(event["foreground"] as? Bool ?? false, now: now)
        case "retry": engine.retry(now: now)
        case "retryResult": engine.retryResult(now: now)
        case "cancel": engine.cancelMatch(now: now)
        case "reclaim": engine.reclaimControl(now: now)
        case "press": engine.press(now: now)
        case "release": engine.release(now: now)
        case "setRoundReady": engine.setRoundReady(event["ready"] as? Bool ?? false, now: now)
        case "setReduceMotion": engine.setReduceMotion(event["enabled"] as? Bool ?? false)
        case "leave": engine.leave(now: now)
        case "disconnect": engine.disconnect()
        default: return false
        }
        return true
    }
}

public func houseTanksOnlineReceive(_ handle: Int32, _ text: String, _ connection: Int32, _ now: Double) -> String {
    tanksOnlineOutput(handle) { entry in
        entry.engine.received(text: text, connection: Int(connection), now: now)
        return true
    }
}

/// One drawn frame of the match: `frame` in the demo's render contract (`TanksFrameParser`)
/// when there is an arena, and always `match`, the bars and banners over it. Each server
/// event is in exactly one frame, so Android calls this once per rendered frame.
public func houseTanksOnlineFrame(_ handle: Int32, _ now: Double) -> String {
    let result = TanksOnlineRegistry.shared.with(handle) { entry -> [String: Any] in
        let engine = entry.engine
        let presentation = engine.presentation(at: now)
        if let presentation { entry.lastSeats = presentation.seats }
        let countdown = engine.roomCountdown(at: now)
        var match = HouseTanksOnlineJSON.match(engine.lobby, presentation, result: engine.result,
                                               localPlayerID: engine.context.localPlayerID, seats: entry.lastSeats,
                                               countdown: countdown, now: now)
        match["countdown"] = countdown ?? NSNull()
        var object: [String: Any] = ["ok": true, "match": match]
        object["fps"] = engine.displayFramesPerSecond(at: now)
        if let presentation, let game = engine.lobby.game {
            object["frame"] = HouseTanksOnlineJSON.frame(presentation, game: game, localPlayerID: engine.context.localPlayerID,
                                                         includeArena: presentation.roundKey != entry.arenaRoundKey)
            entry.arenaRoundKey = presentation.roundKey
        }
        return object
    }
    return bridgeJSON(result ?? ["ok": false, "message": "Unknown match handle"])
}

/// `GET /game/catalog` for one house, reduced to what the FauseTanks room needs.
/// `available` is null when the catalog could not be read (the server still guards).
public func houseTanksCatalogResponse(_ houseId: String, _ status: Int32, _ body: String) -> String {
    do {
        let catalog = try GameWireContract.decodeCatalog(
            houseId: houseId, response: HTTPResponse(statusCode: Int(status), headers: [:], body: Data(body.utf8)))
        guard let entry = catalog.houseTanks else { return bridgeJSON(["ok": true, "available": false]) }
        return bridgeJSON(["ok": true, "available": true, "maximumPlayers": entry.rules.maximumPlayers])
    } catch {
        return bridgeJSON(["ok": true, "available": NSNull()])
    }
}

private func tanksOnlineOutput(_ handle: Int32, _ action: (TanksOnlineRegistry.Entry) -> Bool) -> String {
    let result = TanksOnlineRegistry.shared.with(handle) { entry -> [String: Any] in
        guard action(entry) else { return ["ok": false, "message": "Unsupported event"] }
        let engine = entry.engine
        var object: [String: Any] = [
            "ok": true,
            "effects": engine.drainEffects().map { onlineEffectObject($0, gameKey: GameKey.houseTanks) },
        ]
        if engine.lobby != entry.lastLobby {
            entry.lastLobby = engine.lobby
            object["lobby"] = HouseTanksOnlineJSON.lobby(engine.lobby, context: engine.context)
        }
        let preview = engine.arena.map(HouseTanksOnlineJSON.preview)
        if !entry.sentPreview || !NSDictionary(dictionary: preview ?? [:]).isEqual(to: entry.lastPreview ?? [:])
            || (preview == nil) != (entry.lastPreview == nil) {
            entry.sentPreview = true
            entry.lastPreview = preview
            object["preview"] = preview ?? NSNull()
        }
        object["closed"] = engine.isClosed
        object["rematchExcludedSessionId"] = engine.rematchExcludedSessionID ?? NSNull()
        return object
    }
    return bridgeJSON(result ?? ["ok": false, "message": "Unknown match handle"])
}

/// Screen-ready room models; the copy rules come from Core.
enum HouseTanksOnlineJSON {
    /// House Rockets' lobby keys (one Kotlin parser reads both) plus the update flag and
    /// each seated player's name and color.
    static func lobby(_ state: HouseTanksOnlineLobbyState, context: GameLaunchContext) -> [String: Any] {
        let local = context.localPlayerID
        let session = state.session
        func uptime(_ date: Date?) -> Any {
            guard let date, let clock = state.serverClock else { return NSNull() }
            return clock.localUptime + date.timeIntervalSince(clock.serverTime)
        }
        let deadline: Date? = session?.state == .countdown ? session?.countdownEndsAt
            : session?.state == .readyWindow ? session?.readyWindowEndsAt : nil
        let seated = Dictionary((state.game?.players ?? []).map { ($0.playerId, $0) }, uniquingKeysWith: { first, _ in first })
        let status = HouseTanksOnlineCopyKeys.roomStatus(state)
        let detail = HouseTanksOnlineCopyKeys.roomDetail(state)
        return [
            "connection": "\(state.connection)",
            "isSynced": state.isSynced,
            "isLobby": state.isLobby,
            "isTerminal": state.isTerminal,
            "isLeaving": state.isLeaving,
            "isForeground": state.isForeground,
            "controlTransferred": state.controlTransferred,
            "hasGame": state.game != nil,
            // The match screen opens from the first round countdown (`phase = playing`) on.
            "gamePhase": state.game?.phase.rawValue ?? NSNull(),
            "sessionState": session.map { $0.state.rawValue } ?? NSNull(),
            "statusKey": status,
            "detailKey": detail,
            "showsProgress": HouseTanksOnlineCopyKeys.showsProgress(state),
            "issueKey": state.issue.map(HouseTanksOnlineCopyKeys.issue) ?? NSNull(),
            "connectionTitleKey": status,
            "connectionDetailKey": detail,
            "minimumPlayers": session?.rules.minimumPlayers ?? 2,
            "retryNotBefore": state.retryNotBefore ?? NSNull(),
            "canRetry": state.canReconnect(at: .infinity),
            "requiresAuthentication": state.requiresAuthentication,
            "requiresUpdate": state.requiresUpdate,
            "canChangeReady": state.canChangeReady(playerID: local),
            "canCancel": state.canCancel(context: context),
            "localReady": state.localPlayer(local)?.state == .ready,
            "readyCount": state.readyCount,
            "participants": state.participants.map { player -> [String: Any] in [
                "playerId": player.playerId,
                "statusKey": HouseTanksOnlineCopyKeys.playerStatus(player.state),
                "ready": player.state == .ready,
                "isLocal": player.playerId == local,
                "name": seated[player.playerId]?.displayName ?? NSNull(),
                "color": seated[player.playerId]?.color.rawValue ?? NSNull(),
            ] },
            "deadlineKind": (session?.state == .countdown ? "countdown" : session?.state == .readyWindow ? "ready" : nil)
                ?? NSNull() as Any,
            "deadlineUptime": uptime(deadline),
            // The match countdown of the drawn arena (`phase = countdown`, `roundPhase = null`).
            "flightCountdownUptime": uptime(state.game?.phase == .countdown ? state.game?.countdownEndsAt
                                            : session?.countdownEndsAt),
        ]
    }

    /// The demo's frame shape: seats as players (`nameKey` carries the server's display
    /// name), the own tank as the human. Phase and countdown live in `match` instead.
    static func frame(_ presentation: HouseTanksOnlinePresentation, game: HouseTanksSnapshotDTO, localPlayerID: String?,
                      includeArena: Bool) -> [String: Any] {
        let roles = Dictionary(presentation.seats.map { ($0.playerID, $0.isLocal ? HouseTanksPlayerRole.human : .bot) },
                               uniquingKeysWith: { first, _ in first })
        var object = HouseTanksFrameJSON.arenaObject(world: presentation.world, roles: roles, events: presentation.events,
                                                     includeArena: includeArena, offline: presentation.offlinePlayerIDs,
                                                     includeHits: true)
        object.merge([
            "matchId": game.sessionId,
            "roundKey": presentation.roundKey,
            "revision": game.stateSequence,
            "phase": "playing",
            "countdown": NSNull(),
            "roundNumber": presentation.roundNumber,
            "roundWinnerId": presentation.roundWinnerID ?? NSNull(),
            "championId": NSNull(),
            "players": presentation.seats.map { seat -> [String: Any] in [
                "id": seat.playerID, "nameKey": seat.displayName, "role": (seat.isLocal ? "human" : "bot"),
                "color": seat.color.rawValue, "armor": seat.armor, "roundsWon": seat.roundsWon, "alive": seat.isAlive,
            ] },
        ]) { _, new in new }
        return object
    }

    /// What Android shows over the arena (`HouseTanksOnlineMatchUI` on iOS); the copy rules
    /// are `HouseTanksOnlineCopyKeys`. The result, once visible, replaces every banner.
    static func match(_ state: HouseTanksOnlineLobbyState, _ presentation: HouseTanksOnlinePresentation?,
                      result: HouseTanksOnlineResultState = .init(), localPlayerID: String? = nil,
                      seats lastSeats: [HouseTanksOnlineSeat] = [], countdown: Int? = nil,
                      now: Double) -> [String: Any] {
        // The end menu opens with the match's end, before the stored result.
        let showsResult = result.isVisible || HouseTanksOnlineCopyKeys.isMatchOver(state, presentation)
        let notice = showsResult ? nil : HouseTanksOnlineCopyKeys.matchNotice(state, presentation)
        let phase = presentation?.phase ?? state.game?.phase
        let winner = presentation.flatMap { p in p.seats.first { $0.playerID == p.roundWinnerID }?.displayName }
        var round: [String: Any] = ["showsRoundPanel": false]
        if let presentation, presentation.roundPhase == .roundReady, presentation.phase == .playing, !showsResult, notice == nil {
            let window = countdown
            round = [
                "showsRoundPanel": true,
                "roundTitleKey": HouseTanksOnlineCopyKeys.roundTitle(presentation, localPlayerID: localPlayerID),
                "roundDetailKey": HouseTanksOnlineCopyKeys.roundDetail(presentation, windowSeconds: window),
                "roundWindowSeconds": window ?? NSNull(),
            ]
        }
        var object: [String: Any] = [
            "phase": phase?.rawValue ?? NSNull(),
            "roundPhase": presentation?.roundPhase?.rawValue ?? NSNull(),
            "roundNumber": presentation?.roundNumber ?? 0,
            "canPress": presentation?.canPress ?? false,
            "isPressed": presentation?.isPressed ?? false,
            "isLocalTankDestroyed": presentation?.isLocalTankDestroyed ?? false,
            "isSpectating": presentation?.isSpectating ?? false,
            "noticeTitleKey": notice?.title ?? NSNull(),
            "noticeDetailKey": notice?.detail ?? NSNull(),
            "noticeName": winner ?? NSNull(),
            "canRetry": state.canReconnect(at: now),
            "canReclaim": state.controlTransferred && state.connection == .connected,
            "isFinished": showsResult || state.isTerminal || phase == .ended || phase == .cancelled,
            "canVote": presentation?.canVote ?? false,
            "isLocalReady": presentation?.isLocalReady ?? false,
            "isVotePending": presentation?.isVotePending ?? false,
            "readyCount": presentation?.readyCount ?? 0,
            "voterCount": presentation?.voterCount ?? 0,
            "showsResult": showsResult,
            "seats": (presentation?.seats ?? lastSeats).map { seat -> [String: Any] in [
                "playerId": seat.playerID, "name": seat.displayName, "color": seat.color.rawValue,
                "armor": seat.armor, "roundsWon": seat.roundsWon, "alive": seat.isAlive,
                "connected": seat.isConnected, "left": seat.hasLeft, "local": seat.isLocal,
                "roundReady": seat.roundReady,
            ] },
        ]
        object.merge(round) { _, new in new }
        if showsResult {
            object["result"] = self.result(result, localPlayerID: localPlayerID, seats: presentation?.seats ?? lastSeats)
        }
        return object
    }

    /// The end menu: copy keys, the standings (the last seats until the stored ranks) and the rematch gate.
    static func result(_ state: HouseTanksOnlineResultState, localPlayerID: String?,
                       seats: [HouseTanksOnlineSeat] = []) -> [String: Any] {
        var object: [String: Any] = [
            "phase": "\(state.phase)",
            "detailKey": HouseTanksOnlineCopyKeys.resultDetail(state),
            "canRematch": state.canRematch,
            "canRetry": state.canRetry(at: state.retryNotBefore),
            "retryNotBefore": state.retryNotBefore,
            "sessionId": state.sessionID ?? NSNull(),
            "completed": state.result?.status == .completed,
            "championId": NSNull(),
        ]
        switch HouseTanksOnlineCopyKeys.resultTitle(state, localPlayerID: localPlayerID) {
        case .key(let key): object["titleKey"] = key
        case .champion(let id): object["titleKey"] = "house_tanks_online_champion"; object["championId"] = id
        }
        object["players"] = HouseTanksOnlineCopyKeys.standings(state, seats: seats).map { player -> [String: Any] in [
            "playerId": player.playerID,
            "rank": player.rank ?? NSNull(),
            "roundsWon": player.roundsWon,
            "name": player.displayName ?? NSNull(),
            "color": player.color?.rawValue ?? NSNull(),
            "isLocal": player.playerID == localPlayerID,
            "provisional": player.isProvisional,
        ] }
        return object
    }

    /// The drawn map and its seated tanks, normalized (y up) like `houseTanksMaps()`.
    static func preview(_ world: HouseTanksWorld) -> [String: Any] {
        [
            "mapId": world.map.id.rawValue,
            "seats": world.tanks.map { tank -> [String: Any] in [
                "playerId": tank.id,
                "x": tank.position.x / HouseTanksWorld.arenaSize.width,
                "y": tank.position.y / HouseTanksWorld.arenaSize.height,
                "rotation": tank.rotation,
                "color": tank.color.rawValue,
            ] },
        ]
    }
}
