import Foundation
import Combine
import FausCrewCore
import os

/// The selected house's game standings for the dashboard stats card, kept per (user, house).
/// There is no live update: the card refreshes when it appears and when the user comes back to it.
@MainActor
final class GameStatsStore: ObservableObject {
    enum Phase: Equatable {
        case idle, loading, loaded, failed
    }

    @Published private(set) var phase: Phase = .idle
    /// The backend's standings as sent; the card builds its `GameStatsBoard` from them.
    @Published private(set) var stats: [HouseGameStats] = []
    /// The server's localized text for the failure that put the card in `.failed`, when it sent one.
    @Published private(set) var failureMessage: String?

    /// 403 or 404: the user left the house or it is gone, so the profile and house list must be
    /// refreshed. Reported once per context, so an unchanged context cannot loop.
    var onAccessLost: (() -> Void)?

    private let service: (any GameStatsServicing)?
    private let rateLimitDelay: Duration
    private let sleep: (Duration) async throws -> Void
    private var userID: String?
    private var houseID: String?
    /// Bumped whenever the context changes, so answers for the old house are dropped.
    private var epoch = 0
    private var request = 0
    private var reportedAccessLost = false

    private static let log = Logger(subsystem: "com.fauscrew", category: "GameStats")

    init(
        service: (any GameStatsServicing)?,
        rateLimitDelay: Duration = .seconds(2),
        sleep: @escaping (Duration) async throws -> Void = { try await Task.sleep(for: $0) }
    ) {
        self.service = service
        self.rateLimitDelay = rateLimitDelay
        self.sleep = sleep
    }

    /// The signed-in user and selected house, or nil. A change clears everything; loading waits for `refresh()`.
    func setContext(userID: String?, houseID: String?) {
        guard userID != self.userID || houseID != self.houseID else { return }
        self.userID = userID
        self.houseID = houseID
        epoch += 1
        phase = .idle
        stats = []
        failureMessage = nil
        reportedAccessLost = false
    }

    /// Loads the standings again. A refresh keeps the shown standings until the answer arrives.
    /// A 429 with nothing on screen is retried once after a short wait; with standings on screen
    /// it is ignored and they stay.
    func refresh() async {
        guard let service, userID != nil, let houseID else { return }
        let epoch = self.epoch
        request += 1
        let request = self.request
        func isCurrent() -> Bool { epoch == self.epoch && request == self.request }
        if phase != .loaded { phase = .loading }
        var retried = false
        while true {
            do {
                let stats = try await service.stats(houseID: houseID)
                guard isCurrent() else { return }
                self.stats = stats
                failureMessage = nil
                phase = .loaded
                return
            } catch {
                guard isCurrent() else { return }
                if Self.isCancellation(error) {
                    if phase == .loading { phase = .idle }
                    return
                }
                let failure = error as? GameStatsFailure
                if failure?.kind == .rateLimited, phase == .loading, !retried {
                    retried = true
                    do { try await sleep(rateLimitDelay) } catch {
                        if isCurrent(), phase == .loading { phase = .idle }
                        return
                    }
                    guard isCurrent() else { return }
                    continue
                }
                Self.log.error("Game stats failed: \(failure?.kind.rawValue ?? "transport", privacy: .public)")
                // A failed refresh keeps the standings on screen.
                if phase == .loading {
                    failureMessage = failure?.message
                    phase = .failed
                }
                if failure?.kind == .accessLost, !reportedAccessLost {
                    reportedAccessLost = true
                    onAccessLost?()
                }
                return
            }
        }
    }

    private static func isCancellation(_ error: any Error) -> Bool {
        error is CancellationError || (error as? URLError)?.code == .cancelled
    }
}
