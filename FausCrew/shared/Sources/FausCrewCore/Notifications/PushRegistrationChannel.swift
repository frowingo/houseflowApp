import Foundation

public enum PushSignOutReason: String, Sendable {
    /// User logout, language-change re-login, leaving email verification: the JWT is still valid.
    case userInitiated
    /// 401 / rejected token: the JWT is no longer valid.
    case sessionRejected
    /// The backend already deleted every device token with the account.
    case accountDeleted
}

public enum PushRegistrationEffect: Equatable, Sendable {
    /// `POST notification/devices` with the current JWT.
    case register(token: String)
    /// `DELETE notification/devices`. The platform reads the JWT while handling this effect,
    /// before it clears the session.
    case unregister(token: String)
    /// Delete the FCM token, then report `localTokenDeleted()`.
    case deleteLocalToken
}

/// Decides when this device's FCM token is registered with the backend and when it is dropped
/// (sans-IO, like `AppEventsChannel`). The platforms only supply the token and perform the effects.
/// The effects of one `signOut` must run in order: `.unregister` (the DELETE) finishes before
/// `.deleteLocalToken` starts.
///
/// - A `register` is emitted when a user and a token are known, no sign-out cleanup is running,
///   and that (user, token) pair has not been emitted in this process. That covers a launch with a
///   stored session, every login and every token change, once per pair even while a request is
///   in flight.
/// - A failed registration is not retried in this process, so the platforms do not report results:
///   the pair stays attempted. A new token, a new login or the next launch tries again.
/// - `signOut` clears the user, the token and the attempted pair. A user-initiated sign-out
///   unregisters the token first (the JWT is still valid) whenever one is known, even if the user
///   was transiently cleared (an error screen): a DELETE for a token that was never registered is
///   harmless. A rejected session or a deleted account only deletes the local token. Nothing is
///   emitted when no user or token was ever known.
/// - While cleanup runs, tokens are ignored (they may be the one being deleted) and a new user is
///   only remembered. When the local token is deleted the token is unknown: the platform fetches a
///   fresh one, and `setToken` registers it if a user is set.
public final class PushRegistrationChannel {
    private struct Pair: Equatable {
        let userID: String
        let token: String
    }

    private var effects: [PushRegistrationEffect] = []
    private var userID: String?
    private var token: String?
    private var attempted: Pair?
    private var awaitingUnregister = false
    private var awaitingLocalDelete = false

    public init() {}

    public var isCleaningUp: Bool { awaitingUnregister || awaitingLocalDelete }

    public func drainEffects() -> [PushRegistrationEffect] {
        defer { effects.removeAll() }
        return effects
    }

    /// The signed-in user (fully authenticated, JWT stored), or `nil`. Clearing it without
    /// `signOut` (authentication not finished yet) emits nothing.
    public func setSession(userID: String?) {
        self.userID = Self.nonBlank(userID)
        registerIfNeeded()
    }

    /// The current FCM token, first fetched or refreshed. `nil` or blank clears it.
    public func setToken(_ token: String?) {
        guard !isCleaningUp else { return }
        self.token = Self.nonBlank(token)
        registerIfNeeded()
    }

    /// Call BEFORE the platform clears the stored JWT, and handle the drained effects right away.
    public func signOut(reason: PushSignOutReason) {
        if !isCleaningUp {
            if reason == .userInitiated, let token {
                effects.append(.unregister(token: token))
                awaitingUnregister = true
            }
            if userID != nil || token != nil {
                effects.append(.deleteLocalToken)
                awaitingLocalDelete = true
            }
        }
        userID = nil
        token = nil
        attempted = nil
    }

    /// After the DELETE completed or failed.
    public func unregisterFinished() {
        awaitingUnregister = false
    }

    /// After the FCM token was deleted, or the deletion failed.
    public func localTokenDeleted() {
        awaitingLocalDelete = false
    }

    private func registerIfNeeded() {
        guard !isCleaningUp, let userID, let token else { return }
        let pair = Pair(userID: userID, token: token)
        guard pair != attempted else { return }
        attempted = pair
        effects.append(.register(token: token))
    }

    private static func nonBlank(_ value: String?) -> String? {
        value.flatMap { $0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : $0 }
    }
}

public enum PushTokenLog {
    /// The only form of an FCM token that may reach a log.
    public static func redacted(_ token: String) -> String {
        String(token.prefix(8)) + "…"
    }
}
