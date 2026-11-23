import Foundation
import Combine
import FausCrewCore

/// Takes a tapped push from `PushInbox` and walks it to its screen one `PushRouting` step at a
/// time. It also owns the navigation state a push has to read or change: the selected tab,
/// whether a game is open, and the request for the dashboard to open a chore.
@MainActor
final class PushRouteHandler: ObservableObject {
    /// What the app knows; the handler adds its own tab and game state to build Core's context.
    struct Snapshot {
        var isSignedIn: Bool
        var houseIDs: [String]?
        var selectedHouseID: String?
        var isSwitchingHouse: Bool
        /// The route is the main screen (not loading, house selection, sign-in...).
        var isDashboardRoute: Bool
        /// A popup or sheet covers the screen.
        var isOverlayPresented: Bool
        var loadedChoreIDs: Set<String>?
    }

    @Published var selectedTab: AppTab = .home {
        didSet { if selectedTab != .games { isGameOpen = false } }
    }
    /// Reported by the Games tab while one of its games is on screen.
    @Published var isGameOpen = false
    /// The chore the dashboard should open now; the dashboard answers with `consumeChoreToOpen()`.
    @Published private(set) var choreToOpen: String?
    /// Bumped to make the dashboard close its popups.
    @Published private(set) var dashboardResetCount = 0

    private let snapshot: () -> Snapshot
    private let switchHouse: (String) -> Void
    private let inbox: PushInbox?
    /// At most one: a newer tap replaces it.
    private var target: PushTarget?
    /// The last switch/show step started for `target`, so an unchanged context never repeats it.
    private var lastPerformed: PushRouteStep?
    /// Whether the switch started for `lastPerformed` has been seen running (route left the dashboard).
    private var switchStarted = false

    init(snapshot: @escaping () -> Snapshot, switchHouse: @escaping (String) -> Void, inbox: PushInbox?) {
        self.snapshot = snapshot
        self.switchHouse = switchHouse
        self.inbox = inbox
    }

    /// Takes a tap that arrived before the app was ready, and every later one.
    func start() {
        inbox?.onOffer = { [weak self] in self?.takeFromInbox() }
        takeFromInbox()
    }

    /// Sign-out: nothing a previous account was sent to may happen.
    func clear() {
        _ = inbox?.take()
        target = nil
        lastPerformed = nil
        switchStarted = false
        choreToOpen = nil
    }

    func consumeChoreToOpen() {
        choreToOpen = nil
    }

    /// Call whenever anything in the snapshot, the tab or the game flag may have changed.
    func evaluate() {
        // Nothing pending and nothing to reset: skip building the snapshot.
        if target == nil, selectedTab == .home, !isGameOpen { return }
        let state = snapshot()
        // MainTabView is rebuilt for every visit of the dashboard, so its tab starts at Home.
        if !state.isDashboardRoute {
            if selectedTab != .home { selectedTab = .home }
            if isGameOpen { isGameOpen = false }
        }
        guard let target else { return }
        if state.isSwitchingHouse { switchStarted = true }
        // The switch ran and ended on another house (it failed): the tap must not fire later,
        // when the user happens to open that house by hand.
        if case .switchHouse(let houseID)? = lastPerformed, switchStarted, !state.isSwitchingHouse,
           state.isDashboardRoute, state.selectedHouseID != houseID {
            finish()
            return
        }
        let context = PushRouteContext(
            isSignedIn: state.isSignedIn,
            houseIDs: state.houseIDs,
            selectedHouseID: state.selectedHouseID,
            isSwitchingHouse: state.isSwitchingHouse,
            isGameOpen: isGameOpen,
            isDashboardShown: state.isDashboardRoute && selectedTab == .home && !state.isOverlayPresented,
            loadedChoreIDs: state.loadedChoreIDs
        )
        let step = PushRouting.next(target, in: context)
        switch step {
        case .wait:
            return
        case .drop, .finished:
            finish()
        case .openChore(let choreID):
            choreToOpen = choreID
            finish()
        case .switchHouse(let houseID):
            guard lastPerformed != step else { return }
            lastPerformed = step
            switchStarted = false
            switchHouse(houseID)
        case .showDashboard:
            guard lastPerformed != step else { return }
            lastPerformed = step
            selectedTab = .home
            dashboardResetCount += 1
        }
    }

    private func takeFromInbox() {
        guard let data = inbox?.take(), let newTarget = PushTarget(data: data) else { return }
        target = newTarget
        lastPerformed = nil
        evaluate()
    }

    private func finish() {
        target = nil
        lastPerformed = nil
        switchStarted = false
    }
}
