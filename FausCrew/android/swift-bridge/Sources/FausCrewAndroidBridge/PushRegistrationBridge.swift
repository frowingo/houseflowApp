import Foundation
import FausCrewCore

// Push token registration decisions behind a handle. FausCrewCore decides when to register and
// unregister; Android supplies the FCM token, performs the HTTP calls and reports back.

final class PushRegistrationRegistry: @unchecked Sendable {
    static let shared = PushRegistrationRegistry()
    private let lock = NSLock()
    private var nextHandle: Int32 = 1
    private var channels: [Int32: PushRegistrationChannel] = [:]

    func create() -> Int32 {
        lock.lock(); defer { lock.unlock() }
        let handle = nextHandle
        nextHandle = nextHandle == Int32.max ? 1 : nextHandle + 1
        channels[handle] = PushRegistrationChannel()
        return handle
    }

    func destroy(_ handle: Int32) -> Bool {
        lock.lock(); defer { lock.unlock() }
        return channels.removeValue(forKey: handle) != nil
    }

    func with<T>(_ handle: Int32, _ body: (PushRegistrationChannel) -> T) -> T? {
        lock.lock(); defer { lock.unlock() }
        return channels[handle].map(body)
    }
}

public func pushRegistrationCreate() -> Int32 { PushRegistrationRegistry.shared.create() }

public func pushRegistrationDestroy(_ handle: Int32) -> Bool { PushRegistrationRegistry.shared.destroy(handle) }

/// `{"type": "setSession"|"setToken"|"signOut"|"unregisterFinished"|
/// "localTokenDeleted", …}`. Returns `{"ok": true, "cleaningUp": …, "effects": [...]}` or
/// `{"ok": false, "message": "…"}` for input it cannot read.
public func pushRegistrationEvent(_ handle: Int32, _ eventJSON: String) -> String {
    let result = PushRegistrationRegistry.shared.with(handle) { channel -> [String: Any] in
        guard let event = (try? JSONSerialization.jsonObject(with: Data(eventJSON.utf8))) as? [String: Any],
              let type = event["type"] as? String else { return ["ok": false, "message": "Unsupported event"] }
        switch type {
        case "setSession": channel.setSession(userID: event["userId"] as? String)
        case "setToken": channel.setToken(event["token"] as? String)
        case "signOut":
            guard let reason = (event["reason"] as? String).flatMap(PushSignOutReason.init(rawValue:)) else {
                return ["ok": false, "message": "Unknown sign-out reason"]
            }
            channel.signOut(reason: reason)
        case "unregisterFinished": channel.unregisterFinished()
        case "localTokenDeleted": channel.localTokenDeleted()
        default: return ["ok": false, "message": "Unsupported event"]
        }
        return ["ok": true, "cleaningUp": channel.isCleaningUp, "effects": channel.drainEffects().map { effect -> [String: Any] in
            switch effect {
            case .register(let token): return ["type": "register", "token": token]
            case .unregister(let token): return ["type": "unregister", "token": token]
            case .deleteLocalToken: return ["type": "deleteLocalToken"]
            }
        }]
    }
    return bridgeJSON(result ?? ["ok": false, "message": "Unknown push registration handle"])
}
