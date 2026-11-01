import Foundation

/// Which localization key each online room state shows, kept in one place so iOS
/// and Android present the same message for the same state. Values live in
/// `HouseTanksLocalization`.
public enum HouseTanksOnlineCopyKeys {
    public static func roomStatus(_ state: HouseTanksOnlineLobbyState) -> String {
        if state.isLeaving { return "house_tanks_online_leaving" }
        if state.requiresUpdate { return "house_tanks_online_update_title" }
        if state.isTerminal { return "house_tanks_online_ended" }
        if state.connection == .reconnecting { return "house_tanks_online_reconnecting" }
        if state.connection == .failed { return "house_tanks_online_connection_failed" }
        if state.connection == .syncing || (state.connection == .connected && !state.isSynced) {
            return "house_tanks_online_syncing"
        }
        if state.connection != .connected { return "house_tanks_online_connecting" }
        if state.pendingCommand?.message.action == .join { return "house_tanks_online_joining" }
        if state.pendingCommand != nil { return "house_tanks_online_confirming" }
        if let game = state.game { return game.phase == .countdown ? "house_tanks_online_countdown" : "house_tanks_online_running" }
        switch state.session?.state {
        case .readyWindow: return "house_tanks_online_ready_window"
        case .countdown: return "house_tanks_online_countdown"
        case .running: return "house_tanks_online_running"
        default: return "house_tanks_online_lobby"
        }
    }

    /// `house_tanks_online_lobby_detail` takes `{minimum}`.
    public static func roomDetail(_ state: HouseTanksOnlineLobbyState) -> String {
        if state.requiresUpdate { return "house_tanks_online_update_required" }
        if state.isTerminal { return "house_tanks_online_ended_detail" }
        if state.connection == .reconnecting { return "house_tanks_online_reconnecting_detail" }
        if state.connection == .failed { return state.issue.map(issue) ?? "house_tanks_online_connection_failed_detail" }
        if state.connection != .connected || !state.isSynced { return "house_tanks_online_connecting_detail" }
        if let game = state.game {
            return game.phase == .countdown ? "house_tanks_online_countdown_detail" : "house_tanks_online_running_detail"
        }
        switch state.session?.state {
        case .readyWindow: return "house_tanks_online_ready_window_detail"
        case .countdown: return "house_tanks_online_countdown_detail"
        case .running: return "house_tanks_online_running_detail"
        default: return "house_tanks_online_lobby_detail"
        }
    }

    /// The banner over the arena during a match, or nil when play needs no words. The
    /// round countdown, the round panel (`roundReady`) and the result panel are drawn
    /// separately; the result panel replaces every banner once it is visible.
    public static func matchNotice(_ state: HouseTanksOnlineLobbyState,
                                   _ presentation: HouseTanksOnlinePresentation?) -> (title: String, detail: String)? {
        if state.isLeaving { return ("house_tanks_online_leaving", "house_tanks_online_connecting_detail") }
        if state.requiresUpdate { return ("house_tanks_online_update_title", "house_tanks_online_update_required") }
        let phase = presentation?.phase ?? state.game?.phase
        if phase == .finalizing { return ("house_tanks_online_finalizing", "house_tanks_online_finalizing_detail") }
        if state.isTerminal || phase == .ended || phase == .cancelled {
            return ("house_tanks_online_ended", "house_tanks_online_ended_detail")
        }
        if state.connection == .reconnecting { return ("house_tanks_online_reconnecting", "house_tanks_online_reconnecting_detail") }
        if state.connection == .failed {
            return ("house_tanks_online_connection_failed", state.issue.map(issue) ?? "house_tanks_online_connection_failed_detail")
        }
        if state.controlTransferred { return ("house_tanks_online_control_moved", "house_tanks_online_control_moved_detail") }
        if phase == .recovering { return ("house_tanks_online_recovering", "house_tanks_online_recovering_detail") }
        if presentation?.isSyncing ?? true { return ("house_tanks_online_syncing", "house_tanks_online_connecting_detail") }
        // Between rounds the round panel shows everyone, a watcher too, who took the round.
        let roundOver = presentation?.phase == .playing && presentation?.roundPhase == .roundReady
        if presentation?.isSpectating == true, !roundOver {
            return ("house_tanks_online_spectating", "house_tanks_online_spectating_detail")
        }
        if presentation?.isLocalTankDestroyed == true { return ("house_tanks_online_died_round", "house_tanks_online_died_round_detail") }
        if presentation?.isAwaitingControl == true {
            return ("house_tanks_online_awaiting_control", "house_tanks_online_awaiting_control_detail")
        }
        return nil
    }

    /// The round panel's title in `roundReady`; `house_tanks_online_round_winner` takes `{name}`.
    public static func roundTitle(_ presentation: HouseTanksOnlinePresentation, localPlayerID: String?) -> String {
        guard let winner = presentation.roundWinnerID else { return "house_tanks_online_round_draw" }
        return winner == localPlayerID ? "house_tanks_online_round_won" : "house_tanks_online_round_winner"
    }

    /// Below the title: the open window (`{seconds}`), else what starts the next round.
    public static func roundDetail(_ presentation: HouseTanksOnlinePresentation, windowSeconds: Int?) -> String {
        if windowSeconds != nil { return "house_tanks_online_round_window" }
        if !presentation.canVote { return "house_tanks_online_round_no_vote" }
        return "house_tanks_online_round_over_detail"
    }

    public enum ResultTitle: Equatable, Sendable {
        case key(String)
        /// `house_tanks_online_champion` with this player's name.
        case champion(playerID: String)
    }

    public static func resultTitle(_ state: HouseTanksOnlineResultState, localPlayerID: String?) -> ResultTitle {
        // The end menu opens with the match's end, before the lookup starts.
        if state.phase == .waiting || state.phase == .idle { return .key("house_tanks_online_finalizing") }
        if state.phase == .failed { return .key("house_tanks_online_result_unavailable") }
        guard let result = state.result, result.status == .completed, let champion = result.championId else {
            return .key("house_tanks_online_result_cancelled")
        }
        return champion == localPlayerID ? .key("house_tanks_champion_you") : .champion(playerID: champion)
    }

    public static func resultDetail(_ state: HouseTanksOnlineResultState) -> String {
        if state.phase == .waiting || state.phase == .idle { return "house_tanks_online_finalizing_detail" }
        if state.phase == .failed {
            switch state.failure {
            case .http(401, _): return "house_tanks_online_sign_in"
            case .http(403, _): return "house_tanks_online_forbidden"
            case .invalidPayload, .protocolFailure: return "house_tanks_online_update_required"
            default: return "house_tanks_online_result_unavailable_detail"
            }
        }
        if state.phase == .cancelledWithoutRecord { return "house_tanks_online_result_cancelled_before_start" }
        if state.result?.status == .completed { return "house_tanks_champion_detail" }
        switch state.endReason {
        case .sessionExpired: return "house_tanks_online_result_expired"
        case .cancelledByUser: return "house_tanks_online_result_cancelled_by_user"
        case .insufficientPlayers: return "house_tanks_online_result_insufficient_players"
        default: return "house_tanks_online_result_technical_cancel"
        }
    }

    /// Persisted ranks first (ties keep server order); a cancelled match has none and
    /// lists players by round wins.
    public static func orderedResultPlayers(_ result: HouseTanksResultDTO?) -> [HouseTanksPlayerResultDTO] {
        (result?.players ?? []).enumerated().sorted {
            let lhs = $0.element.finalRank ?? Int.max, rhs = $1.element.finalRank ?? Int.max
            if lhs != rhs { return lhs < rhs }
            if $0.element.roundsWon != $1.element.roundsWon { return $0.element.roundsWon > $1.element.roundsWon }
            return $0.offset < $1.offset
        }.map(\.element)
    }

    /// The match is over for this device: the end menu replaces the banners, the round
    /// panel and the top-left controls, whether or not the result has arrived.
    public static func isMatchOver(_ state: HouseTanksOnlineLobbyState,
                                   _ presentation: HouseTanksOnlinePresentation?) -> Bool {
        let phase = presentation?.phase ?? state.game?.phase
        return state.isTerminal || presentation?.roundPhase == .matchEnded
            || [.finalizing, .ended, .cancelled].contains(phase)
    }

    /// The end menu's table: the stored ranks once the result is in, before that the last
    /// seats by round wins (provisional, unranked), so nobody leaves without the standings.
    public static func standings(_ result: HouseTanksOnlineResultState,
                                 seats: [HouseTanksOnlineSeat]) -> [HouseTanksOnlineStanding] {
        let bySeat = Dictionary(seats.map { ($0.playerID, $0) }, uniquingKeysWith: { first, _ in first })
        if let stored = result.result {
            return orderedResultPlayers(stored).map { player in
                let identity = result.identities[player.playerId]
                return HouseTanksOnlineStanding(playerID: player.playerId, rank: player.finalRank,
                                                roundsWon: player.roundsWon,
                                                displayName: identity?.displayName ?? bySeat[player.playerId]?.displayName,
                                                color: identity?.color ?? bySeat[player.playerId]?.color,
                                                isProvisional: false)
            }
        }
        return seats.enumerated().sorted {
            if $0.element.roundsWon != $1.element.roundsWon { return $0.element.roundsWon > $1.element.roundsWon }
            return $0.offset < $1.offset
        }.map { HouseTanksOnlineStanding(playerID: $0.element.playerID, rank: nil, roundsWon: $0.element.roundsWon,
                                         displayName: $0.element.displayName, color: $0.element.color,
                                         isProvisional: true) }
    }

    /// The spinner beside the room status.
    public static func showsProgress(_ state: HouseTanksOnlineLobbyState) -> Bool {
        !state.isTerminal && state.connection != .failed
            && (state.connection == .connecting || state.connection == .idle || !state.isSynced
                || state.pendingCommand != nil || state.isLeaving)
    }

    public static func issue(_ issue: GameOnlineLobbyIssue) -> String {
        switch issue {
        case .timeout, .commandTimeout: return "house_tanks_online_timeout"
        case .rejected(let error):
            switch error.code {
            case "game.error.session_full": return "house_tanks_online_full"
            case "game.error.join_closed", "game.error.ready_closed": return "house_tanks_online_ready_closed"
            case "realtime.error.rate_limited": return "house_tanks_online_rate_limited"
            default: return "house_tanks_online_command_rejected"
            }
        case .connection(.http(let status, _)):
            switch status {
            case 401: return "house_tanks_online_sign_in"
            case 403: return "house_tanks_online_forbidden"
            case 404: return "house_tanks_online_room_unavailable"
            case 409: return "house_tanks_online_ready_closed"
            case 429: return "house_tanks_online_rate_limited"
            case 503: return "house_tanks_online_busy"
            default: return "house_tanks_online_connection_failed_detail"
            }
        case .connection(.protocolFailure(.gameUnavailable)): return "house_tanks_online_closed_detail"
        case .connection(.protocolFailure(.authenticationRequired)): return "house_tanks_online_sign_in"
        case .connection(.protocolFailure(.unsupportedProtocol)), .connection(.protocolFailure(.unsupportedCourse)),
             .connection(.protocolFailure(.unsupportedContract)), .connection(.protocolFailure(.unsupportedMap)):
            return "house_tanks_online_update_required"
        case .connection: return "house_tanks_online_connection_failed_detail"
        }
    }

    public static func playerStatus(_ state: GameSessionPlayerState) -> String {
        switch state {
        case .waiting: return "house_tanks_online_waiting"
        case .ready: return "house_tanks_online_ready_badge"
        case .playing: return "house_tanks_online_playing_badge"
        case .finished, .left: return "house_tanks_online_left_badge"
        }
    }
}

/// One row of the end menu's table; `rank` is nil while provisional and in a cancelled match.
public struct HouseTanksOnlineStanding: Equatable, Sendable {
    public let playerID: String
    public let rank: Int?
    public let roundsWon: Int
    public let displayName: String?
    public let color: HouseTanksColor?
    /// From the last snapshot, before the stored result.
    public let isProvisional: Bool
}
