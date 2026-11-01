import Foundation
import FausCrewCore

// `/api/v1/events` refresh channel behind a handle. FausCrewCore decides when to open,
// back off, coalesce and refresh; Android only runs the socket and the HTTP refreshes.

final class AppEventsRegistry: @unchecked Sendable {
    static let shared = AppEventsRegistry()
    private let lock = NSLock()
    private var nextHandle: Int32 = 1
    private var channels: [Int32: AppEventsChannel] = [:]

    func create() -> Int32 {
        lock.lock(); defer { lock.unlock() }
        let handle = nextHandle
        nextHandle = nextHandle == Int32.max ? 1 : nextHandle + 1
        channels[handle] = AppEventsChannel()
        return handle
    }

    func destroy(_ handle: Int32) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return channels.removeValue(forKey: handle) != nil
    }

    func with<T>(_ handle: Int32, _ body: (AppEventsChannel) -> T) -> T? {
        lock.lock(); defer { lock.unlock() }
        return channels[handle].map(body)
    }
}

public func appEventsCreate() -> Int32 { AppEventsRegistry.shared.create() }

public func appEventsDestroy(_ handle: Int32) -> Bool { AppEventsRegistry.shared.destroy(handle) }

/// `{"type": "setActive"|"setSelectedHouse"|"socketOpened"|"received"|"connectionFailed"|"tick", "now": …}`.
/// Returns `{"ok": true, "effects": [...], "path": "events"}`.
public func appEventsEvent(_ handle: Int32, _ eventJSON: String) -> String {
    let result = AppEventsRegistry.shared.with(handle) { channel -> [String: Any] in
        guard let event = (try? JSONSerialization.jsonObject(with: Data(eventJSON.utf8))) as? [String: Any],
              let type = event["type"] as? String else { return ["ok": false, "message": "Unsupported event"] }
        let now = event["now"] as? Double ?? 0
        let connection = event["connection"] as? Int ?? -1
        switch type {
        case "setActive":
            channel.setActive(foreground: event["foreground"] as? Bool ?? false,
                              authenticated: event["authenticated"] as? Bool ?? false, now: now)
        case "setSelectedHouse": channel.setSelectedHouse((event["houseId"] as? String).flatMap { $0.isEmpty ? nil : $0 })
        case "socketOpened": channel.socketOpened(connection: connection, now: now)
        case "received": channel.received(text: event["text"] as? String ?? "", connection: connection, now: now)
        case "connectionFailed": channel.connectionFailed(status: event["status"] as? Int, connection: connection, now: now)
        case "tick": channel.tick(now: now)
        default: return ["ok": false, "message": "Unsupported event"]
        }
        return ["ok": true, "path": AppEventsWire.path, "effects": channel.drainEffects().map { effect -> [String: Any] in
            switch effect {
            case .openSocket(let connection): return ["type": "openSocket", "connection": connection]
            case .closeSocket: return ["type": "closeSocket"]
            case .refresh(let profile, let houseID):
                return ["type": "refresh", "profile": profile, "houseId": houseID ?? NSNull()]
            case .signedOut: return ["type": "signedOut"]
            }
        }]
    }
    return bridgeJSON(result ?? ["ok": false, "message": "Unknown events handle"])
}
