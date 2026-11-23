import Foundation

/// Holds the data of the last tapped push. A cold-start tap can arrive before `AppViewModel`
/// exists, so it waits here until the app takes it.
@MainActor
final class PushInbox {
    static let shared = PushInbox()

    private(set) var pending: [String: String]?
    /// Called after every `offer`, so a live app can take the data right away.
    var onOffer: (() -> Void)?

    func offer(_ data: [String: String]) {
        pending = data
        onOffer?()
    }

    func take() -> [String: String]? {
        defer { pending = nil }
        return pending
    }
}
