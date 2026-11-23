import Foundation

/// What the host knows right now; `nil` collections mean "still loading".
public struct PushRouteContext: Equatable, Sendable {
    public var isSignedIn: Bool
    public var houseIDs: [String]?
    public var selectedHouseID: String?
    public var isSwitchingHouse: Bool
    public var isGameOpen: Bool
    public var isDashboardShown: Bool
    public var loadedChoreIDs: Set<String>?

    public init(
        isSignedIn: Bool, houseIDs: [String]?, selectedHouseID: String?, isSwitchingHouse: Bool,
        isGameOpen: Bool, isDashboardShown: Bool, loadedChoreIDs: Set<String>?
    ) {
        self.isSignedIn = isSignedIn
        self.houseIDs = houseIDs
        self.selectedHouseID = selectedHouseID
        self.isSwitchingHouse = isSwitchingHouse
        self.isGameOpen = isGameOpen
        self.isDashboardShown = isDashboardShown
        self.loadedChoreIDs = loadedChoreIDs
    }
}

/// The next thing the host should do for a tapped push.
public enum PushRouteStep: Equatable, Sendable {
    case wait
    case drop
    case switchHouse(String)
    case showDashboard
    case openChore(String)
    case finished
}

/// Decides, one step at a time, how a tapped push reaches its screen. Both platforms call it
/// whenever their context changes so the order of the rules lives in one place.
public enum PushRouting {
    public static func next(_ target: PushTarget, in context: PushRouteContext) -> PushRouteStep {
        guard context.isSignedIn, let houseIDs = context.houseIDs else { return .wait }
        guard houseIDs.contains(target.houseID) else { return .drop }
        // A running game is never closed for a push.
        if context.isGameOpen || context.isSwitchingHouse { return .wait }
        if context.selectedHouseID != target.houseID { return .switchHouse(target.houseID) }
        if !context.isDashboardShown { return .showDashboard }
        guard let loaded = context.loadedChoreIDs else { return .wait }
        if let choreID = target.choreID, loaded.contains(choreID) { return .openChore(choreID) }
        return .finished
    }
}
