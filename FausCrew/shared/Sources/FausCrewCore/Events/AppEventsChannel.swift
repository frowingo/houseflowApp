import Foundation

/// A refresh signal from `/api/v1/events`. Messages never carry data; the HTTP
/// endpoints stay the source of truth.
public enum AppEvent: Equatable, Sendable {
    case ready
    case houseChanged(houseID: String)
    case userChanged
}

public enum AppEventsWire {
    /// Relative to `/api/v1`; opened with `Authorization: Bearer <token>` only.
    public static let path = "events"

    /// Unknown types and malformed frames are ignored so the server can add signals.
    public static func event(from text: String) -> AppEvent? {
        guard let object = (try? JSONSerialization.jsonObject(with: Data(text.utf8))) as? [String: Any],
              let type = object["type"] as? String else { return nil }
        switch type {
        case "ready": return .ready
        case "user.changed": return .userChanged
        case "house.changed":
            guard let id = object["houseId"] as? String, !id.isEmpty else { return nil }
            return .houseChanged(houseID: id)
        default: return nil
        }
    }
}

public enum AppEventsEffect: Equatable, Sendable {
    /// Open the events socket; report outcomes with the same `connection`.
    case openSocket(connection: Int)
    case closeSocket
    /// Forced HTTP refresh (bypassing caches): the profile/house list via `auth/isAuth`,
    /// and/or `house/details` of `houseID`, which was selected when the refresh was decided.
    case refresh(profile: Bool, houseID: String?)
    /// The socket was refused with 401: run the existing sign-out flow.
    case signedOut
}

/// The app-data refresh channel for one signed-in user (sans-IO, like the game engine).
/// One socket while the app is in the foreground; closed in the background and on sign
/// out. Nearby signals coalesce into one refresh; a `ready` (every (re)connect) and each
/// return to the foreground force a full refresh so missed events are caught up.
public final class AppEventsChannel {
    public static let coalesceWindow: TimeInterval = 0.75
    public static let maximumBackoff: TimeInterval = 30

    private let jitter: () -> Double
    private var effects: [AppEventsEffect] = []
    private var isForeground = false
    private var isAuthenticated = false
    private var selectedHouseID: String?
    private var connection = 0
    private var socketOpen = false
    private var retryAt: TimeInterval?
    private var attempt = 0
    private var pendingProfile = false
    private var pendingHouses: Set<String> = []
    private var pendingSelected = false
    private var flushAt: TimeInterval?

    public init(jitter: @escaping () -> Double = { Double.random(in: 0.8...1.2) }) {
        self.jitter = jitter
    }

    public var isConnected: Bool { socketOpen }

    public func drainEffects() -> [AppEventsEffect] {
        defer { effects.removeAll() }
        return effects
    }

    /// Foreground and signed-in state from the platform. Becoming active again forces a
    /// refresh even before the socket's `ready` arrives.
    public func setActive(foreground: Bool, authenticated: Bool, now: TimeInterval) {
        let wasActive = isForeground && isAuthenticated
        let returnedToForeground = foreground && !isForeground && authenticated && isAuthenticated
        isForeground = foreground
        isAuthenticated = authenticated
        let active = foreground && authenticated
        if active, !wasActive {
            attempt = 0
            open()
            if returnedToForeground { requestFull(now: now) }
        } else if !active, wasActive {
            close()
            if !authenticated { selectedHouseID = nil }
        }
    }

    /// The house whose details are on screen; `house.changed` for other houses is ignored.
    public func setSelectedHouse(_ houseID: String?) {
        if houseID != selectedHouseID { pendingHouses.removeAll() }
        selectedHouseID = houseID
    }

    public func socketOpened(connection tag: Int, now: TimeInterval) {
        guard tag == connection else { return }
        socketOpen = true
    }

    public func received(text: String, connection tag: Int, now: TimeInterval) {
        guard tag == connection, let event = AppEventsWire.event(from: text) else { return }
        socketOpen = true
        switch event {
        case .ready:
            attempt = 0
            requestFull(now: now)
        case .userChanged:
            pendingProfile = true
            schedule(now: now)
        case .houseChanged(let id):
            pendingHouses.insert(id)
            schedule(now: now)
        }
    }

    /// `status` is the HTTP status of a refused upgrade, `nil` for a dropped socket.
    public func connectionFailed(status: Int?, connection tag: Int, now: TimeInterval) {
        guard tag == connection else { return }
        socketOpen = false
        effects.append(.closeSocket)
        if status == 401 {
            isAuthenticated = false
            retryAt = nil
            effects.append(.signedOut)
            return
        }
        guard isForeground, isAuthenticated else { return }
        attempt += 1
        let base = min(Self.maximumBackoff, pow(2, Double(attempt - 1)))
        retryAt = now + min(Self.maximumBackoff, base * min(1.2, max(0.8, jitter())))
    }

    public func tick(now: TimeInterval) {
        if let at = retryAt, now >= at, isForeground, isAuthenticated {
            retryAt = nil
            open()
        }
        if let at = flushAt, now >= at { flush() }
    }

    private func open() {
        connection += 1
        socketOpen = false
        retryAt = nil
        effects.append(.openSocket(connection: connection))
    }

    private func close() {
        connection += 1
        socketOpen = false
        retryAt = nil
        flushAt = nil
        pendingProfile = false
        pendingSelected = false
        pendingHouses.removeAll()
        effects.append(.closeSocket)
    }

    private func requestFull(now: TimeInterval) {
        pendingProfile = true
        pendingSelected = true
        schedule(now: now)
    }

    private func schedule(now: TimeInterval) {
        if flushAt == nil { flushAt = now + Self.coalesceWindow }
    }

    private func flush() {
        flushAt = nil
        let house = selectedHouseID.flatMap { id in (pendingSelected || pendingHouses.contains(id)) ? id : nil }
        let profile = pendingProfile
        pendingProfile = false
        pendingSelected = false
        pendingHouses.removeAll()
        guard isAuthenticated, profile || house != nil else { return }
        effects.append(.refresh(profile: profile, houseID: house))
    }
}
