import Foundation

/// Which localization key each online state shows: the room, the banner over the race
/// and the result. Kept in Core so both platforms say the same thing for the same state.
public enum FausSwitchOnlineCopyKeys {
    public static func roomStatus(_ state: FausSwitchOnlineLobbyState) -> String {
        if state.isLeaving { return "faus_switch_online_leaving" }
        if state.isTerminal { return "faus_switch_online_ended" }
        if state.requiresUpdate { return "faus_switch_online_update_required" }
        switch state.connection {
        case .reconnecting: return "faus_switch_online_reconnecting"
        case .failed: return "faus_switch_online_connection_failed"
        case .connected where !state.isSynced, .syncing: return "faus_switch_online_syncing"
        case .connected: break
        default: return "faus_switch_online_connecting"
        }
        if state.pendingCommand?.message.action == .join { return "faus_switch_online_joining" }
        switch state.session?.state {
        case .readyWindow: return "faus_switch_online_ready_window"
        case .countdown: return "faus_switch_online_starting"
        case .running: return "faus_switch_online_running"
        default: return "faus_switch_online_lobby"
        }
    }

    public static func roomDetail(_ state: FausSwitchOnlineLobbyState) -> String {
        if state.isTerminal { return "faus_switch_online_ended_detail" }
        if state.requiresUpdate { return "faus_switch_online_update_required_detail" }
        switch state.connection {
        case .reconnecting: return "faus_switch_online_reconnecting_detail"
        case .failed: return "faus_switch_online_connection_failed_detail"
        case .connected where !state.isSynced, .syncing: return "faus_switch_online_syncing_detail"
        case .connected: break
        default: return "faus_switch_online_connecting_detail"
        }
        switch state.session?.state {
        case .readyWindow: return "faus_switch_online_ready_window_detail"
        case .countdown: return "faus_switch_online_starting_detail"
        case .running: return "faus_switch_online_running_detail"
        default: return "faus_switch_online_lobby_detail"
        }
    }

    /// The spinner beside the room status.
    public static func showsProgress(_ state: FausSwitchOnlineLobbyState) -> Bool {
        !state.isTerminal && state.connection != .failed && !state.requiresUpdate
            && (state.connection != .connected || !state.isSynced || state.pendingCommand != nil || state.isLeaving)
    }

    public static func issue(_ issue: GameOnlineLobbyIssue) -> String {
        switch issue {
        case .timeout, .commandTimeout: return "faus_switch_online_timeout"
        case .rejected(let error):
            switch error.code {
            case "game.error.session_full": return "faus_switch_online_full"
            case "game.error.join_closed", "game.error.ready_closed": return "faus_switch_online_ready_closed"
            case "realtime.error.rate_limited": return "faus_switch_online_rate_limited"
            default: return "faus_switch_online_command_rejected"
            }
        case .connection(.http(let status, _)):
            switch status {
            case 401: return "faus_switch_online_sign_in"
            case 403: return "faus_switch_online_forbidden"
            case 404: return "faus_switch_online_room_unavailable"
            case 409: return "faus_switch_online_ready_closed"
            case 429: return "faus_switch_online_rate_limited"
            case 503: return "faus_switch_online_busy"
            default: return "faus_switch_online_connection_failed_detail"
            }
        case .connection(.protocolFailure(.gameUnavailable)): return "faus_switch_online_room_unavailable"
        case .connection(.protocolFailure(.unsupportedProtocol)), .connection(.protocolFailure(.unsupportedCourse)):
            return "faus_switch_online_update_required_detail"
        case .connection: return "faus_switch_online_connection_failed_detail"
        }
    }

    public static func playerStatus(_ state: GameSessionPlayerState) -> String {
        switch state {
        case .ready: return "faus_switch_online_player_ready"
        case .playing: return "faus_switch_online_player_running"
        case .finished, .left: return "faus_switch_online_player_done"
        case .waiting: return "faus_switch_online_player_waiting"
        }
    }

    public struct Notice: Equatable, Sendable {
        public let title: String
        public let detail: String
        /// The way out is offered (a failed connection or a lost seat).
        public let isBlocking: Bool
    }

    /// The banner over the race while it is not live for this player; nil when it is.
    public static func matchNotice(_ state: FausSwitchOnlineLobbyState,
                                   _ presentation: FausSwitchOnlinePresentation?) -> Notice? {
        if state.connection == .failed {
            if state.requiresAuthentication {
                return Notice(title: "faus_switch_online_connection_failed", detail: "faus_switch_online_sign_in", isBlocking: true)
            }
            if state.requiresUpdate {
                return Notice(title: "faus_switch_online_update_required",
                              detail: "faus_switch_online_update_required_detail", isBlocking: true)
            }
            return Notice(title: "faus_switch_online_connection_failed",
                          detail: "faus_switch_online_connection_failed_detail", isBlocking: true)
        }
        if state.controlTransferred {
            return Notice(title: "faus_switch_online_control_transferred",
                          detail: "faus_switch_online_control_transferred_detail", isBlocking: true)
        }
        if state.connection == .reconnecting {
            return Notice(title: "faus_switch_online_reconnecting", detail: "faus_switch_online_reconnecting_detail",
                          isBlocking: false)
        }
        if state.game?.phase == .recovering {
            return Notice(title: "faus_switch_online_recovering", detail: "faus_switch_online_recovering_detail",
                          isBlocking: false)
        }
        if state.connection != .connected || !state.isSynced || presentation?.isSyncing == true {
            return Notice(title: "faus_switch_online_syncing", detail: "faus_switch_online_syncing_detail", isBlocking: false)
        }
        if presentation?.isAwaitingResult == true {
            return Notice(title: "faus_switch_online_awaiting_result", detail: "faus_switch_online_awaiting_result_detail",
                          isBlocking: false)
        }
        return nil
    }

    public enum ResultTitle: Equatable, Sendable {
        case key(String)
        /// `faus_switch_online_lost` with `{name}` for the winner.
        case lost(winnerID: String)
    }

    public static func resultTitle(_ state: FausSwitchOnlineResultState, localPlayerID: String?) -> ResultTitle {
        switch state.phase {
        case .idle, .waiting: return .key("faus_switch_online_finalizing")
        case .failed: return .key("faus_switch_online_result_unavailable")
        case .cancelledWithoutRecord: return .key("faus_switch_online_result_cancelled")
        case .available: break
        }
        guard let result = state.result, result.status == .completed else { return .key("faus_switch_online_result_cancelled") }
        guard let winner = result.winnerId else { return .key("faus_switch_online_no_winner") }
        return winner == localPlayerID ? .key("faus_switch_online_won") : .lost(winnerID: winner)
    }

    public static func resultDetail(_ state: FausSwitchOnlineResultState) -> String {
        switch state.phase {
        case .idle, .waiting: return "faus_switch_online_finalizing_detail"
        case .failed:
            switch state.failure {
            case .http(401, _): return "faus_switch_online_sign_in"
            case .http(403, _): return "faus_switch_online_forbidden"
            case .invalidPayload, .protocolFailure: return "faus_switch_online_update_required_detail"
            default: return "faus_switch_online_result_unavailable_detail"
            }
        case .cancelledWithoutRecord: return "faus_switch_online_result_cancelled_before_start"
        case .available: break
        }
        if state.result?.status == .completed {
            return state.result?.winnerId == nil ? "faus_switch_online_no_winner_detail" : "faus_switch_online_result_detail"
        }
        switch state.endReason {
        case .sessionExpired: return "faus_switch_online_result_expired"
        case .cancelledByUser: return "faus_switch_online_result_cancelled_by_user"
        case .insufficientPlayers: return "faus_switch_online_result_insufficient_players"
        default: return "faus_switch_online_result_technical_cancel"
        }
    }

    /// Persisted ranks first (ties keep server order), unranked players last.
    public static func orderedResultPlayers(_ result: FausSwitchResultDTO?) -> [FausSwitchPlayerResultDTO] {
        (result?.players ?? []).enumerated().sorted {
            let lhs = $0.element.rank ?? Int.max, rhs = $1.element.rank ?? Int.max
            return lhs == rhs ? $0.offset < $1.offset : lhs < rhs
        }.map(\.element)
    }

    /// The crash line under a robot that is out of the race.
    public static func crashReason(_ reason: FausSwitchCrashReason?) -> String {
        switch reason {
        case .boundary, nil: return "faus_switch_crashed_boundary"
        case .leftBehind: return "faus_switch_crashed_left_behind"
        case .forfeit, .membershipRevoked: return "faus_switch_crashed_forfeit"
        }
    }

    public static func crashDetail(_ reason: FausSwitchCrashReason?) -> String {
        crashReason(reason) + "_detail"
    }
}
