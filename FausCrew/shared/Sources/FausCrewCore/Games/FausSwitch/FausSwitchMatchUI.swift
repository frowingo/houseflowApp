import Foundation

/// One line of the result table.
public struct FausSwitchStanding: Equatable, Identifiable, Sendable {
    public enum Status: Equatable, Sendable {
        case running
        case finished
        case crashed(FausSwitchCrashReason?)
    }

    public let id: String
    /// A localization key for bots, the server's display name for people.
    public let nameKey: String?
    public let displayName: String?
    public let color: FausSwitchColor
    public let rank: Int?
    public let status: Status
    public let isLocal: Bool
    public var isConnected: Bool
    /// Seconds from the start for finishers.
    public var time: Double?

    public init(id: String, nameKey: String?, displayName: String?, color: FausSwitchColor, rank: Int?,
                status: Status, isLocal: Bool, isConnected: Bool = true, time: Double? = nil) {
        self.id = id
        self.nameKey = nameKey
        self.displayName = displayName
        self.color = color
        self.rank = rank
        self.status = status
        self.isLocal = isLocal
        self.isConnected = isConnected
        self.time = time
    }

    /// Out of the race (crashed or left).
    public var isOut: Bool {
        if case .crashed = status { return true }
        return false
    }

    /// The status column's copy key when it shows no time: a finisher without a time,
    /// a running robot, or the short elimination reason.
    public var statusKey: String {
        switch status {
        case .finished: "faus_switch_status_finished"
        case .running: "faus_switch_status_running"
        case .crashed(let reason): FausSwitchOnlineCopyKeys.crashReason(reason) + "_short"
        }
    }
}

/// A robot's name beside it on the start platform, shown until the countdown ends.
public struct FausSwitchNameTag: Equatable, Identifiable, Sendable {
    public let id: String
    public let nameKey: String?
    public let displayName: String?
    public let color: FausSwitchColor
    public let isLocal: Bool
    /// The robot's center in track coordinates.
    public let x: Double
    public let y: Double
    /// The frame's camera focus (`FausSwitchRenderFrame.cameraFocus`).
    public let cameraFocus: Double

    public init(id: String, nameKey: String?, displayName: String?, color: FausSwitchColor, isLocal: Bool,
                x: Double, y: Double, cameraFocus: Double) {
        self.id = id
        self.nameKey = nameKey
        self.displayName = displayName
        self.color = color
        self.isLocal = isLocal
        self.x = x
        self.y = y
        self.cameraFocus = cameraFocus
    }

    /// The tag's leading edge on screen (y up): just past the robot's front, at its height.
    public func anchor(track: FausSwitchTrack, viewport: FausSwitchViewport) -> (x: Double, y: Double) {
        let camera = FausSwitchCamera.view(focus: cameraFocus, track: track, viewport: viewport)
        let pose = track.pose(x: x + FausSwitchMetrics.runnerWidth / 2 + 6, y: y)
        return camera.screenPoint(worldX: pose.x, worldY: pose.y)
    }
}

/// What the overlays above the race show, for demo and online alike; equal values skip
/// a redraw. iOS and Android draw it; the rules that fill it live here.
public struct FausSwitchMatchUI: Equatable, Sendable {
    public var phase: FausSwitchMatchPhase = .countdown
    public var countdown: Int?
    public var standings: [FausSwitchStanding] = []
    /// Only during the countdown (robots stand still then).
    public var nameTags: [FausSwitchNameTag] = []
    public var localStatus: FausSwitchStanding.Status?
    public var localRank: Int?
    public var localTime: Double?
    public var runnerCount = 0
    public var canFlip = false
    /// Online: a banner key pair while the race is not live for this player.
    public var noticeTitleKey: String?
    public var noticeDetailKey: String?
    public var noticeIsBlocking = false
    public var canRetry = false
    public var canReclaim = false
    /// Online: the persisted result replaces the race panel.
    public var showsResult = false
    public var showsRematchRoom = false

    public init() {}

    /// A demo frame's overlays; `canFlip` while the human is running in a live race.
    public static func demo(_ frame: FausSwitchRenderFrame, canFlip: Bool) -> FausSwitchMatchUI {
        var ui = FausSwitchMatchUI()
        ui.phase = frame.phase
        ui.countdown = frame.countdown
        ui.standings = standings(from: frame)
        ui.nameTags = nameTags(from: frame)
        ui.runnerCount = frame.runners.count
        ui.canFlip = canFlip
        if let local = frame.localRunner {
            ui.localStatus = status(of: local.state)
            ui.localRank = local.rank
            ui.localTime = local.state.finishedAtTick.map { FausSwitchMetrics.seconds($0) }
        }
        return ui
    }

    /// An online frame's overlays: the race (`presentation`, else the last drawn frame),
    /// the room's banner, and the result once the race is over. A rematch room shows its
    /// own panel until the new race's first snapshot.
    public static func online(state: FausSwitchOnlineLobbyState, presentation: FausSwitchOnlinePresentation?,
                              lastFrame: FausSwitchRenderFrame?, result: FausSwitchOnlineResultState,
                              isRematchRoom: Bool, now: TimeInterval) -> FausSwitchMatchUI {
        var ui = FausSwitchMatchUI()
        if let frame = presentation?.frame ?? lastFrame {
            ui = demo(frame, canFlip: presentation?.canFlip ?? false)
        }
        if let notice = FausSwitchOnlineCopyKeys.matchNotice(state, presentation) {
            ui.noticeTitleKey = notice.title
            ui.noticeDetailKey = notice.detail
            ui.noticeIsBlocking = notice.isBlocking
        }
        let raceOver = presentation?.frame.phase == .ended || state.isTerminal
            || [.ended, .cancelled, .finalizing].contains(state.game?.phase)
        ui.showsResult = result.isVisible || (raceOver && !isRematchRoom)
        if ui.showsResult {
            ui.noticeTitleKey = nil
            ui.noticeDetailKey = nil
        }
        ui.showsRematchRoom = isRematchRoom && !ui.showsResult
        ui.canRetry = state.connection == .failed && state.canReconnect(at: now)
        ui.canReclaim = state.controlTransferred && state.connection == .connected
        return ui
    }

    public static func standings(from frame: FausSwitchRenderFrame) -> [FausSwitchStanding] {
        frame.runners
            .map { runner in
                FausSwitchStanding(
                    id: runner.id, nameKey: runner.nameKey, displayName: runner.displayName, color: runner.color,
                    rank: runner.rank, status: status(of: runner.state), isLocal: runner.isLocal,
                    isConnected: runner.isConnected,
                    time: runner.state.finishedAtTick.map { FausSwitchMetrics.seconds($0) })
            }
            .sorted { ($0.rank ?? .max, $0.id) < ($1.rank ?? .max, $1.id) }
    }

    /// The online result table: the persisted ranks once available, the race's last
    /// standings (`live`) until then. Names and colors come from the result's identities,
    /// else from the race.
    public static func resultStandings(_ state: FausSwitchOnlineResultState, live: [FausSwitchStanding],
                                       localPlayerID: String?) -> [FausSwitchStanding] {
        guard let result = state.result, !result.players.isEmpty else { return live }
        let race = Dictionary(live.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return FausSwitchOnlineCopyKeys.orderedResultPlayers(result).map { player in
            let identity = state.identities[player.playerId]
            let status: FausSwitchStanding.Status = player.finishedAtTick != nil ? .finished
                : player.eliminatedAtTick != nil ? .crashed(player.eliminationReason) : .running
            return FausSwitchStanding(
                id: player.playerId, nameKey: nil,
                displayName: identity?.displayName ?? race[player.playerId]?.displayName,
                color: identity?.color ?? race[player.playerId]?.color ?? .graphite,
                rank: player.rank, status: status, isLocal: player.playerId == localPlayerID,
                time: player.finishedAtTick.map { FausSwitchMetrics.seconds($0) })
        }
    }

    public static func nameTags(from frame: FausSwitchRenderFrame) -> [FausSwitchNameTag] {
        guard frame.phase == .countdown else { return [] }
        return frame.runners.map {
            FausSwitchNameTag(id: $0.id, nameKey: $0.nameKey, displayName: $0.displayName, color: $0.color,
                              isLocal: $0.isLocal, x: $0.state.x, y: $0.state.y, cameraFocus: frame.cameraFocus)
        }
    }

    public static func status(of state: FausSwitchRunnerState) -> FausSwitchStanding.Status {
        switch state.status {
        case .running: .running
        case .finished: .finished
        case .crashed: .crashed(state.crashReason)
        }
    }

    /// The demo result panel's header.
    public enum DemoOutcome: String, Sendable {
        case won, finished, crashed, timeUp
    }

    public var demoOutcome: DemoOutcome {
        switch localStatus {
        case .finished: localRank == 1 ? .won : .finished
        case .crashed: .crashed
        case .running, nil: .timeUp
        }
    }

    /// Title and detail keys of the demo result header; the finish detail takes `{rank}`
    /// and `{time}`.
    public var demoResultKeys: (title: String, detail: String) {
        switch localStatus {
        case .finished: (localRank == 1 ? "faus_switch_won" : "faus_switch_finished", "faus_switch_finished_detail")
        case .crashed(let reason): (FausSwitchOnlineCopyKeys.crashReason(reason), FausSwitchOnlineCopyKeys.crashDetail(reason))
        case .running, nil: ("faus_switch_time_up", "faus_switch_time_up_detail")
        }
    }
}

extension FausSwitchCourse {
    /// Group number by block id: blocks closer than 200 along the course share a group,
    /// so a group is drawn in one color and neighboring groups differ.
    public func blockGroups() -> [Int: Int] {
        var groups: [Int: Int] = [:]
        var group = -1
        var groupEnd = -Double.infinity
        for block in solids.filter({ $0.kind == .block }).sorted(by: { $0.rect.minX < $1.rect.minX }) {
            if block.rect.minX - groupEnd >= 200 { group += 1 }
            groupEnd = max(groupEnd, block.rect.maxX)
            groups[block.id] = group
        }
        return groups
    }
}
