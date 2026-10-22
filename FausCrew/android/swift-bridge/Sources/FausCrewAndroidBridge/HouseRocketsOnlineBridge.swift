import Foundation
import FausCrewCore

// Online House Rockets behind a handle. The engine (FausCrewCore) decides every
// lobby, reconnect, control and result rule; Android only performs the returned
// effects with OkHttp and reports their outcome. Calls are coarse (one per socket
// message, user intent or 25 ms tick) except `houseRocketsOnlineFrame`, which samples
// the interpolated flight once per rendered frame. Lobby/result models are included
// only when they changed since the previous call.

final class OnlineMatchRegistry: @unchecked Sendable {
    static let shared = OnlineMatchRegistry()
    private let lock = NSLock()
    private var nextHandle: Int32 = 1
    private var entries: [Int32: Entry] = [:]

    final class Entry {
        let engine: HouseRocketsOnlineEngine
        var viewport = BotMatchRegistry.Viewport()
        var courseKey = ""
        var frameRevision = 0
        var lastLobby: HouseRocketsOnlineLobbyState?
        var lastResult: HouseRocketsOnlineResultState?
        init(engine: HouseRocketsOnlineEngine) { self.engine = engine }
    }

    func create(_ engine: HouseRocketsOnlineEngine) -> Int32 {
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
public func houseRocketsOnlineCreate(
    _ houseId: String, _ playerId: String, _ houseOwnerId: String, _ excludingSessionId: String
) -> Int32 {
    let context = HouseRocketsLaunchContext(houseID: houseId.isEmpty ? nil : houseId,
                                            localPlayerID: playerId.isEmpty ? nil : playerId,
                                            houseOwnerID: houseOwnerId.isEmpty ? nil : houseOwnerId)
    return OnlineMatchRegistry.shared.create(HouseRocketsOnlineEngine(
        context: context, excludingSessionID: excludingSessionId.isEmpty ? nil : excludingSessionId))
}

public func houseRocketsOnlineDestroy(_ handle: Int32) -> Bool {
    OnlineMatchRegistry.shared.destroy(handle)
}

/// One user intent or host outcome as JSON `{"type": …, "now": uptimeSeconds, …}`.
/// Socket text frames go through `houseRocketsOnlineReceive` to avoid re-escaping.
public func houseRocketsOnlineEvent(_ handle: Int32, _ eventJSON: String) -> String {
    onlineOutput(handle) { entry in
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
            engine.sessionResponse(response(event), retryAfter: event["retryAfter"] as? Double,
                                   connection: connection, now: now)
        case "socketOpened": engine.socketOpened(connection: connection, now: now)
        case "connectionFailed": engine.connectionFailed(failure(event), connection: connection, now: now)
        case "sendFailed": engine.sendFailed(failure(event), connection: connection, now: now)
        case "resultResponse":
            engine.resultResponse(response(event), retryAfter: event["retryAfter"] as? Double,
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
        case "leave": engine.leave(now: now)
        case "steer": engine.steer(screenHeading: event["heading"] as? Double ?? .nan, now: now)
        case "endSteering": engine.endSteering()
        case "adjust": engine.adjustHeading(by: event["amount"] as? Double ?? 0, now: now)
        case "reduceMotion": engine.setReduceMotion(event["enabled"] as? Bool ?? false)
        case "disconnect": engine.disconnect()
        default: return false
        }
        return true
    }
}

public func houseRocketsOnlineReceive(_ handle: Int32, _ text: String, _ connection: Int32, _ now: Double) -> String {
    onlineOutput(handle) { entry in
        entry.engine.received(text: text, connection: Int(connection), now: now)
        return true
    }
}

/// Canvas and HUD safe-area sizes in dp; the next frame carries the course again.
public func houseRocketsOnlineViewport(
    _ handle: Int32, _ width: Double, _ height: Double, _ hudWidth: Double, _ hudHeight: Double
) -> Bool {
    OnlineMatchRegistry.shared.with(handle) { entry in
        entry.viewport = .init(width: width, height: height, hudWidth: hudWidth, hudHeight: hudHeight)
        entry.courseKey = ""
        return true
    } ?? false
}

/// The interpolated flight at `now`, in the bot frame format plus online fields.
public func houseRocketsOnlineFrame(_ handle: Int32, _ now: Double) -> String {
    let result = OnlineMatchRegistry.shared.with(handle) { entry -> [String: Any] in
        guard let presentation = entry.engine.presentation(at: now) else { return ["ok": true] }
        let frame = presentation.frame
        let courseKey = frame.gates.map(\.id).joined(separator: ",")
        var object = HouseRocketsFrameJSON.render(frame: frame, viewport: entry.viewport,
                                                  includeGates: courseKey != entry.courseKey)
        entry.courseKey = courseKey
        entry.frameRevision += 1
        let lobby = entry.engine.lobby
        object["revision"] = entry.frameRevision
        object["winnerId"] = lobby.game?.winnerId ?? NSNull()
        object["canSteer"] = presentation.canSteer
        object["isSyncing"] = presentation.isSyncing
        object["statusKey"] = HouseRocketsOnlineCopyKeys.flightStatus(lobby, presentation)
        object["showsConnectionPanel"] = HouseRocketsOnlineCopyKeys.showsConnectionPanel(lobby, presentation)
        object["eliminations"] = presentation.eliminations.map(\.displayName)
        object["ok"] = true
        return object
    }
    return bridgeJSON(result ?? ["ok": false, "message": "Unknown match handle"])
}

private func onlineOutput(_ handle: Int32, _ action: (OnlineMatchRegistry.Entry) -> Bool) -> String {
    let result = OnlineMatchRegistry.shared.with(handle) { entry -> [String: Any] in
        guard action(entry) else { return ["ok": false, "message": "Unsupported event"] }
        let engine = entry.engine
        var object: [String: Any] = ["ok": true, "effects": engine.drainEffects().map(effectObject)]
        // Deadlines are sent as host uptimes, so countdown labels need no refresh here.
        if engine.lobby != entry.lastLobby {
            entry.lastLobby = engine.lobby
            object["lobby"] = HouseRocketsOnlineJSON.lobby(engine.lobby, context: engine.context)
        }
        if engine.result != entry.lastResult {
            entry.lastResult = engine.result
            object["result"] = HouseRocketsOnlineJSON.result(engine.result, localPlayerID: engine.context.localPlayerID)
        }
        object["closed"] = engine.isClosed
        object["rematchExcludedSessionId"] = engine.rematchExcludedSessionID ?? NSNull()
        return object
    }
    return bridgeJSON(result ?? ["ok": false, "message": "Unknown match handle"])
}

private func response(_ event: [String: Any]) -> HTTPResponse {
    HTTPResponse(statusCode: event["status"] as? Int ?? 0, headers: [:],
                 body: Data((event["body"] as? String ?? "").utf8))
}

/// `{"failure": "transport" | "forbidden" | "http" | "authenticationRequired", "status": Int, "retryAfter": Double}`.
private func failure(_ event: [String: Any]) -> GameRealtimeSessionFailure {
    switch event["failure"] as? String {
    case "http": return .http(statusCode: event["status"] as? Int ?? 0, retryAfterSeconds: event["retryAfter"] as? Double)
    case "forbidden": return .http(statusCode: 403, retryAfterSeconds: nil)
    case "notConnected": return .protocolFailure(.notConnected)
    case "authenticationRequired": return .protocolFailure(.authenticationRequired)
    case "tooLarge": return .protocolFailure(.messageTooLarge)
    default: return .transport
    }
}

private func effectObject(_ effect: HouseRocketsOnlineEffect) -> [String: Any] {
    switch effect {
    case .ensureSession(let houseID, let connection):
        let route = GameRoute.ensureSession(gameKey: GameKey.houseRockets)
        return ["type": "ensureSession", "connection": connection, "path": route.path, "method": route.method,
                "body": (try? GameWireContract.ensureSessionBody(houseId: houseID))
                    .map { String(decoding: $0, as: UTF8.self) } ?? "{}"]
    case .openSocket(let sessionID, let connection):
        let route = GameRoute.realtime(sessionId: sessionID)
        return ["type": "openSocket", "connection": connection, "path": route.path,
                "query": route.queryItems.map { "\($0.name)=\($0.value ?? "")" }.joined(separator: "&")]
    case .closeSocket:
        return ["type": "closeSocket"]
    case .send(let text, let connection):
        return ["type": "send", "connection": connection, "text": text]
    case .fetchResult(let sessionID, let request):
        let route = GameRoute.result(sessionId: sessionID)
        return ["type": "fetchResult", "request": request, "path": route.path, "method": route.method]
    case .haptic(let haptic):
        return ["type": "haptic", "haptic": haptic.rawValue]
    }
}

/// Screen-ready lobby and result models; the copy rules come from Core.
enum HouseRocketsOnlineJSON {
    static func lobby(_ state: HouseRocketsOnlineLobbyState, context: HouseRocketsLaunchContext) -> [String: Any] {
        let local = context.localPlayerID
        let session = state.session
        func uptime(_ date: Date?) -> Any {
            guard let date, let clock = state.serverClock else { return NSNull() }
            return clock.localUptime + date.timeIntervalSince(clock.serverTime)
        }
        let deadline: Date? = session?.state == .countdown ? session?.countdownEndsAt
            : session?.state == .readyWindow ? session?.readyWindowEndsAt : nil
        return [
            "connection": "\(state.connection)",
            "isSynced": state.isSynced,
            "isLobby": state.isLobby,
            "isTerminal": state.isTerminal,
            "isLeaving": state.isLeaving,
            "isForeground": state.isForeground,
            "controlTransferred": state.controlTransferred,
            "hasGame": state.game != nil,
            "sessionState": session.map { $0.state.rawValue } ?? NSNull(),
            "statusKey": HouseRocketsOnlineCopyKeys.lobbyStatus(state),
            "detailKey": HouseRocketsOnlineCopyKeys.lobbyDetail(state),
            "showsProgress": HouseRocketsOnlineCopyKeys.lobbyShowsProgress(state),
            "issueKey": state.issue.map(HouseRocketsOnlineCopyKeys.issue) ?? NSNull(),
            "connectionTitleKey": HouseRocketsOnlineCopyKeys.connectionTitle(state),
            "connectionDetailKey": HouseRocketsOnlineCopyKeys.connectionDetail(state),
            "minimumPlayers": session?.rules.minimumPlayers ?? 2,
            "retryNotBefore": state.retryNotBefore ?? NSNull(),
            "canRetry": state.canReconnect(at: .infinity),
            "requiresAuthentication": state.requiresAuthentication,
            "canChangeReady": state.canChangeReady(playerID: local),
            "canCancel": state.canCancel(context: context),
            "localReady": state.localPlayer(local)?.state == .ready,
            "readyCount": state.readyCount,
            "participants": state.participants.map { [
                "playerId": $0.playerId,
                "statusKey": HouseRocketsOnlineCopyKeys.playerStatus($0.state),
                "ready": $0.state == .ready,
                "isLocal": $0.playerId == local,
            ] as [String: Any] },
            "deadlineKind": (session?.state == .countdown ? "countdown" : session?.state == .readyWindow ? "ready" : nil)
                ?? NSNull() as Any,
            "deadlineUptime": uptime(deadline),
            "flightCountdownUptime": uptime(state.game?.countdownEndsAt ?? session?.countdownEndsAt),
        ]
    }

    static func result(_ state: HouseRocketsOnlineResultState, localPlayerID: String?) -> [String: Any] {
        var object: [String: Any] = [
            "phase": "\(state.phase)",
            "visible": state.isVisible,
            "detailKey": HouseRocketsOnlineCopyKeys.resultDetail(state),
            "canRematch": state.canRematch,
            "canRetry": state.canRetry(at: state.retryNotBefore),
            "retryNotBefore": state.retryNotBefore,
            "sessionId": state.sessionID ?? NSNull(),
        ]
        switch HouseRocketsOnlineCopyKeys.resultTitle(state, localPlayerID: localPlayerID) {
        case .key(let key): object["titleKey"] = key
        case .lost(let winner): object["titleKey"] = "house_rockets_lost"; object["winnerId"] = winner
        }
        if let result = state.result {
            object["durationSeconds"] = result.startedAt != nil ? result.durationSeconds : NSNull()
            object["players"] = HouseRocketsOnlineCopyKeys.orderedResultPlayers(result).map { player in [
                "playerId": player.playerId,
                "rank": player.rank ?? NSNull(),
                "distance": player.distance,
                "name": state.identities[player.playerId]?.displayName ?? NSNull(),
                "color": state.identities[player.playerId]?.color.rawValue ?? NSNull(),
                "isLocal": player.playerId == localPlayerID,
            ] as [String: Any] }
        }
        return object
    }
}

/// `GET /game/catalog` for one house, reduced to what the House Rockets screen needs.
/// `available` is null when the catalog could not be read (the server still guards).
public func gameCatalogResponse(_ houseId: String, _ status: Int32, _ body: String) -> String {
    do {
        let catalog = try GameWireContract.decodeCatalog(
            houseId: houseId, response: HTTPResponse(statusCode: Int(status), headers: [:], body: Data(body.utf8)))
        guard let entry = catalog.houseRockets else { return bridgeJSON(["ok": true, "available": false]) }
        return bridgeJSON(["ok": true, "available": true, "maximumPlayers": entry.rules.maximumPlayers])
    } catch {
        return bridgeJSON(["ok": true, "available": NSNull()])
    }
}
