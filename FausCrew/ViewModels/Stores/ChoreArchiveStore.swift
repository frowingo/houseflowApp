import Foundation
import Combine
import FausCrewCore
import os

/// The chore archive for one month of the selected house, kept per (user, house). Nothing loads
/// until the popup opens; every month change starts again from page 1 without a cursor.
@MainActor
final class ChoreArchiveStore: ObservableObject {
    enum Phase: Equatable {
        case idle, loading, loaded, failed
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var chores: [Chore] = []
    /// The first instant of the shown month, in the store's calendar.
    @Published private(set) var monthStart: Date
    @Published private(set) var isLoadingMore = false
    @Published private(set) var loadMoreFailed = false
    /// The server's localized text for the failure that put the list in `.failed`, when it sent one.
    @Published private(set) var failureMessage: String?

    /// The archive answered 403: the user is no longer in the house, so the profile and house
    /// list must be refreshed and the existing removed-house flow takes over.
    var onAccessLost: (() -> Void)?

    var canLoadMore: Bool { nextURL != nil && phase == .loaded && !isLoadingMore }
    var canShowNextMonth: Bool { monthStart < currentMonthStart }

    private let service: (any ChoreArchiveServicing)?
    let calendar: Calendar
    private let now: () -> Date
    private let mapChore: (HouseChoreDTO) -> Chore
    private var userID: String?
    private var houseID: String?
    /// The server's `nextUrl`, passed back untouched.
    private var nextURL: String?
    /// Bumped whenever the context or the month changes, so answers for the old list are dropped.
    private var epoch = 0
    private var firstPageRequest = 0

    private static let log = Logger(subsystem: "com.fauscrew", category: "ChoreArchive")

    init(
        service: (any ChoreArchiveServicing)?,
        calendar: Calendar = .autoupdatingCurrent,
        now: @escaping () -> Date = Date.init,
        chore: @escaping (HouseChoreDTO) -> Chore
    ) {
        self.service = service
        self.calendar = calendar
        self.now = now
        mapChore = chore
        monthStart = Self.monthStart(of: now(), in: calendar)
    }

    /// The signed-in user and selected house, or nil. A change clears everything; loading waits for `open()`.
    func setContext(userID: String?, houseID: String?) {
        guard userID != self.userID || houseID != self.houseID else { return }
        self.userID = userID
        self.houseID = houseID
        reset(to: currentMonthStart)
    }

    /// The popup opened: back to the current month, page 1.
    func open() async {
        reset(to: currentMonthStart)
        await loadFirstPage()
    }

    func showPreviousMonth() async {
        guard let previous = calendar.date(byAdding: .month, value: -1, to: monthStart) else { return }
        reset(to: previous)
        await loadFirstPage()
    }

    func showNextMonth() async {
        guard canShowNextMonth, let next = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return }
        reset(to: next)
        await loadFirstPage()
    }

    /// Pull to refresh and the error card's retry: page 1 of the shown month.
    func refresh() async {
        await loadFirstPage()
    }

    func loadMore() async {
        guard let service, phase == .loaded, !isLoadingMore, let url = nextURL else { return }
        let epoch = self.epoch
        isLoadingMore = true
        loadMoreFailed = false
        do {
            let page = try await service.nextPage(nextURL: url)
            guard epoch == self.epoch else { return }
            isLoadingMore = false
            // A refresh that replaced the list meanwhile has its own `nextUrl`.
            guard nextURL == url else { return }
            let known = Set(chores.map(\.id))
            chores += unique(page.chores.map(mapChore)).filter { !known.contains($0.id) }
            nextURL = page.nextURL
        } catch {
            guard epoch == self.epoch else { return }
            isLoadingMore = false
            if !Self.isCancellation(error), !handleAccessLost(error) { loadMoreFailed = true }
        }
    }

    // MARK: - Loading

    private func loadFirstPage() async {
        guard let service, userID != nil, let houseID, let end = calendar.date(byAdding: .month, value: 1, to: monthStart) else { return }
        let epoch = self.epoch
        firstPageRequest += 1
        let request = firstPageRequest
        let wasLoaded = phase == .loaded
        if !wasLoaded { phase = .loading }
        do {
            let page = try await service.firstPage(houseID: houseID, from: monthStart, to: end)
            guard epoch == self.epoch, request == firstPageRequest else { return }
            chores = unique(page.chores.map(mapChore))
            nextURL = page.nextURL
            loadMoreFailed = false
            failureMessage = nil
            phase = .loaded
        } catch {
            guard epoch == self.epoch, request == firstPageRequest else { return }
            if Self.isCancellation(error) {
                if phase == .loading { phase = .idle }
                return
            }
            Self.log.error("Chore archive failed: \((error as? ChoreArchiveFailure)?.kind.rawValue ?? "transport", privacy: .public)")
            // A failed refresh keeps the list on screen.
            if phase == .loading {
                failureMessage = (error as? ChoreArchiveFailure)?.message
                phase = .failed
            }
            _ = handleAccessLost(error)
        }
    }

    /// Keeps the first chore of each id, since a repeated id would break the list's identity.
    private func unique(_ chores: [Chore]) -> [Chore] {
        var seen = Set<String>()
        return chores.filter { seen.insert($0.id).inserted }
    }

    /// Drops everything shown and every answer still on its way.
    private func reset(to month: Date) {
        epoch += 1
        monthStart = month
        phase = .idle
        chores = []
        nextURL = nil
        isLoadingMore = false
        loadMoreFailed = false
        failureMessage = nil
    }

    private var currentMonthStart: Date { Self.monthStart(of: now(), in: calendar) }

    private static func monthStart(of date: Date, in calendar: Calendar) -> Date {
        calendar.dateInterval(of: .month, for: date)?.start ?? date
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    private func handleAccessLost(_ error: any Error) -> Bool {
        guard (error as? ChoreArchiveFailure)?.kind == .notMember else { return false }
        onAccessLost?()
        return true
    }
}
