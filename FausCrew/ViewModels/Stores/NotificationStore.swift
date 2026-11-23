import Foundation
import Combine
import FausCrewCore
import os

/// The selected house's notification list and its unread badge, kept per (user, house). The
/// badge comes from page 1 and the stored "seen" marker; opening the panel moves the marker.
@MainActor
final class NotificationStore: ObservableObject {
    enum Phase: Equatable {
        case idle, loading, loaded, failed
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var items: [HouseNotification] = []
    @Published private(set) var unreadCount = 0
    @Published private(set) var isPanelOpen = false
    @Published private(set) var isLoadingMore = false
    @Published private(set) var loadMoreFailed = false
    /// The marker stored before the panel opened: newer items get the accent bar.
    @Published private(set) var seenBeforeOpen: NotificationSeenMarker?

    /// The list answered 403/404: the user is no longer in the house, so the profile and house
    /// list must be refreshed and the existing removed-house flow takes over.
    var onAccessLost: (() -> Void)?

    private let service: (any NotificationServicing)?
    private let preferences: any PreferencesStore
    private var userID: String?
    private var houseID: String?
    private var nextCursor: String?
    /// Bumped whenever the context changes, so answers for the old (user, house) are dropped.
    private var epoch = 0
    private var firstPageRequest = 0

    private static let log = Logger(subsystem: "com.fauscrew", category: "Notifications")

    init(service: (any NotificationServicing)?, preferences: any PreferencesStore) {
        self.service = service
        self.preferences = preferences
    }

    /// The signed-in user and selected house, or nil. A change clears everything and refetches the badge.
    func setContext(userID: String?, houseID: String?) {
        guard userID != self.userID || houseID != self.houseID else { return }
        epoch += 1
        self.userID = userID
        self.houseID = houseID
        phase = .idle
        items = []
        unreadCount = 0
        isPanelOpen = false
        isLoadingMore = false
        loadMoreFailed = false
        seenBeforeOpen = nil
        nextCursor = nil
        guard userID != nil, houseID != nil else { return }
        Task { await loadFirstPage(silently: true) }
    }

    /// A socket signal or a foreground push for `houseID`; other houses are not shown.
    func notificationsChanged(houseID: String?) {
        guard houseID == self.houseID else { return }
        Task { await loadFirstPage(silently: true) }
    }

    func openPanel() async {
        guard userID != nil, houseID != nil else { return }
        isPanelOpen = true
        seenBeforeOpen = storedMarker()
        if phase == .loaded { markSeen() }
        await loadFirstPage(silently: false)
    }

    func closePanel() {
        isPanelOpen = false
        seenBeforeOpen = nil
        // The badge was not computed while the panel was open; make sure it is not stuck at 0.
        if phase != .loaded, userID != nil, houseID != nil {
            Task { await loadFirstPage(silently: true) }
        }
    }

    /// Pull to refresh and the error card's retry.
    func refresh() async {
        await loadFirstPage(silently: false)
    }

    func loadMore() async {
        guard let service, let houseID, phase == .loaded, !isLoadingMore, let cursor = nextCursor else { return }
        let epoch = self.epoch
        isLoadingMore = true
        loadMoreFailed = false
        do {
            let page = try await service.list(houseID: houseID, before: cursor)
            guard epoch == self.epoch else { return }
            isLoadingMore = false
            // A refresh that replaced the list meanwhile has its own cursor.
            guard nextCursor == cursor else { return }
            let known = Set(items.map(\.id))
            items += page.items.filter { !known.contains($0.id) }
            nextCursor = page.nextCursor
        } catch {
            guard epoch == self.epoch else { return }
            isLoadingMore = false
            if !Self.isCancellation(error), !handleAccessLost(error) { loadMoreFailed = true }
        }
    }

    /// Whether this item is newer than what the user had seen when the panel opened.
    func isUnread(_ item: HouseNotification) -> Bool {
        NotificationSeen.unreadCount(items: [item], seen: seenBeforeOpen) == 1
    }

    // MARK: - Loading

    /// Page 1. `silently` keeps the skeleton and error states out of it (badge refreshes).
    private func loadFirstPage(silently: Bool) async {
        guard let service, let userID, let houseID else { return }
        let epoch = self.epoch
        firstPageRequest += 1
        let request = firstPageRequest
        let wasLoaded = phase == .loaded
        if !silently, !wasLoaded { phase = .loading }
        do {
            let page = try await service.list(houseID: houseID, before: nil)
            guard epoch == self.epoch, request == firstPageRequest else { return }
            if silently, wasLoaded, isPanelOpen {
                // A background refresh must not throw away the pages the user scrolled in.
                let fresh = Set(page.items.map(\.id))
                items = page.items + items.filter { !fresh.contains($0.id) }
            } else {
                items = page.items
                nextCursor = page.nextCursor
            }
            loadMoreFailed = false
            phase = .loaded
            if isPanelOpen {
                markSeen()
            } else {
                unreadCount = NotificationSeen.unreadCount(
                    items: page.items,
                    seen: NotificationSeen.load(from: preferences, userID: userID, houseID: houseID)
                )
            }
        } catch {
            guard epoch == self.epoch, request == firstPageRequest else { return }
            if Self.isCancellation(error) {
                if phase == .loading { phase = .idle }
                return
            }
            Self.log.error("Notification list failed: \((error as? NotificationFailure)?.kind.rawValue ?? "transport", privacy: .public)")
            // Badge refreshes never close the panel or show an error; only the panel's own loads do.
            if phase == .loading { phase = .failed }
            if !silently { _ = handleAccessLost(error) }
        }
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    private func handleAccessLost(_ error: any Error) -> Bool {
        guard let failure = error as? NotificationFailure, failure.kind == .notMember || failure.kind == .notFound else {
            return false
        }
        closePanel()
        onAccessLost?()
        return true
    }

    /// The newest item of the list becomes the seen marker and the badge clears.
    private func markSeen() {
        unreadCount = 0
        guard let userID, let houseID, let marker = NotificationSeen.marker(newestOf: items) else { return }
        NotificationSeen.save(marker, to: preferences, userID: userID, houseID: houseID)
    }

    private func storedMarker() -> NotificationSeenMarker? {
        guard let userID, let houseID else { return nil }
        return NotificationSeen.load(from: preferences, userID: userID, houseID: houseID)
    }
}
