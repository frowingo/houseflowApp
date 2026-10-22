import Foundation

/// Which localization key each online state shows. These are the rules of the iOS
/// lobby, flight overlay, connection panel and result views, kept in one place so
/// both platforms present the same message for the same state.
public enum HouseRocketsOnlineCopyKeys {
    public static func lobbyStatus(_ state: HouseRocketsOnlineLobbyState) -> String {
        if state.isLeaving { return "house_rockets_leaving" }
        if state.isTerminal { return "house_rockets_online_ended" }
        if state.connection == .reconnecting { return "house_rockets_reconnecting" }
        if state.connection == .syncing { return "house_rockets_online_syncing_lobby" }
        if state.connection == .failed { return "house_rockets_online_connection_failed" }
        if state.connection == .connected, !state.isSynced { return "house_rockets_online_syncing_lobby" }
        if state.connection != .connected { return "house_rockets_online_connecting" }
        if state.pendingCommand?.message.action == .join { return "house_rockets_online_joining" }
        if state.pendingCommand != nil { return "house_rockets_online_confirming" }
        if state.session?.state == .countdown { return "house_rockets_online_launching" }
        if state.session?.state == .running { return "house_rockets_online_flying" }
        return "house_rockets_online_lobby"
    }

    public static func lobbyDetail(_ state: HouseRocketsOnlineLobbyState) -> String {
        if state.isTerminal { return "house_rockets_online_ended_detail" }
        if state.connection == .reconnecting { return "house_rockets_reconnecting_detail" }
        if state.connection == .syncing { return "house_rockets_online_syncing_lobby" }
        if state.connection == .failed { return "house_rockets_online_connection_failed_detail" }
        if state.connection == .connected, !state.isSynced { return "house_rockets_online_syncing_lobby" }
        if state.connection != .connected { return "house_rockets_online_connecting_detail" }
        if state.session?.state == .running { return "house_rockets_online_syncing_flight" }
        if state.session?.state == .countdown { return "house_rockets_online_launching_detail" }
        return "house_rockets_online_lobby_detail"
    }

    /// The spinner beside the lobby status.
    public static func lobbyShowsProgress(_ state: HouseRocketsOnlineLobbyState) -> Bool {
        !state.isTerminal && state.connection != .failed
            && (state.connection == .connecting || state.connection == .idle || !state.isSynced
                || state.pendingCommand != nil || state.isLeaving)
    }

    public static func issue(_ issue: HouseRocketsOnlineLobbyIssue) -> String {
        switch issue {
        case .timeout, .commandTimeout: return "house_rockets_online_timeout"
        case .rejected(let error):
            switch error.code {
            case "game.error.session_full": return "house_rockets_online_full"
            case "game.error.join_closed", "game.error.ready_closed": return "house_rockets_online_ready_closed"
            case "realtime.error.rate_limited": return "house_rockets_online_rate_limited"
            default: return "house_rockets_online_command_rejected"
            }
        case .connection(.http(let status, _)):
            switch status {
            case 401: return "house_rockets_online_sign_in"
            case 403: return "house_rockets_online_forbidden"
            case 404: return "house_rockets_online_room_unavailable"
            case 409: return "house_rockets_online_ready_closed"
            case 429: return "house_rockets_online_rate_limited"
            case 503: return "house_rockets_online_busy"
            default: return "house_rockets_online_connection_failed_detail"
            }
        case .connection(.protocolFailure(.gameUnavailable)): return "house_rockets_online_game_unavailable"
        case .connection(.protocolFailure(.unsupportedProtocol)), .connection(.protocolFailure(.unsupportedCourse)):
            return "house_rockets_online_update_required"
        case .connection: return "house_rockets_online_connection_failed_detail"
        }
    }

    public static func playerStatus(_ state: GameSessionPlayerState) -> String {
        switch state {
        case .ready: return "house_rockets_ready"
        case .playing: return "house_rockets_online_flying"
        case .finished, .left: return "house_rockets_online_ended"
        case .waiting: return "house_rockets_waiting"
        }
    }

    public static func flightStatus(_ state: HouseRocketsOnlineLobbyState,
                                    _ presentation: HouseRocketsOnlinePresentation) -> String {
        let frame = presentation.frame
        if state.isTerminal { return "house_rockets_online_ended" }
        if state.controlTransferred { return "house_rockets_control_transferred" }
        if state.connection == .reconnecting { return "house_rockets_reconnecting" }
        if presentation.isSyncing { return "house_rockets_online_syncing_flight" }
        if frame.phase == .playing, frame.players.first(where: { $0.role == .human })?.isAlive == false {
            return "house_rockets_spectating_short"
        }
        if frame.phase == .playing, !presentation.canSteer { return "house_rockets_online_waiting_control" }
        switch frame.phase {
        case .countdown: return "house_rockets_online_launching"
        case .recovering: return "house_rockets_online_syncing_flight"
        case .finalizing: return "house_rockets_online_finalizing"
        case .ended, .cancelled: return "house_rockets_online_ended"
        case .playing, .paused: return "house_rockets_online_flying"
        }
    }

    /// The connection panel is shown over the retained course while not live.
    public static func showsConnectionPanel(_ state: HouseRocketsOnlineLobbyState,
                                            _ presentation: HouseRocketsOnlinePresentation) -> Bool {
        state.connection != .connected || !state.isSynced || presentation.frame.phase == .recovering
            || state.controlTransferred
    }

    public static func connectionTitle(_ state: HouseRocketsOnlineLobbyState) -> String {
        if state.connection == .failed { return "house_rockets_flight_connection_failed" }
        if state.controlTransferred { return "house_rockets_control_transferred" }
        return state.connection == .reconnecting ? "house_rockets_reconnecting" : "house_rockets_recovering"
    }

    public static func connectionDetail(_ state: HouseRocketsOnlineLobbyState) -> String {
        if state.connection == .failed {
            if case .connection(.http(403, _)) = state.issue { return "house_rockets_online_forbidden" }
            if state.requiresAuthentication { return "house_rockets_online_sign_in" }
            if case .connection(.protocolFailure) = state.issue { return "house_rockets_online_update_required" }
            return "house_rockets_flight_connection_failed_detail"
        }
        if state.controlTransferred { return "house_rockets_control_transferred_detail" }
        return state.connection == .reconnecting ? "house_rockets_reconnecting_detail" : "house_rockets_recovering_detail"
    }

    public enum ResultTitle: Equatable, Sendable {
        case key(String)
        /// `house_rockets_lost` with `{name}` for this player.
        case lost(winnerID: String)
    }

    public static func resultTitle(_ state: HouseRocketsOnlineResultState, localPlayerID: String?) -> ResultTitle {
        if state.phase == .waiting { return .key("house_rockets_online_finalizing") }
        if state.phase == .failed { return .key("house_rockets_result_unavailable") }
        guard let result = state.result, result.status == .completed else { return .key("house_rockets_result_cancelled") }
        guard let winner = result.winnerId else { return .key("house_rockets_draw") }
        return winner == localPlayerID ? .key("house_rockets_won") : .lost(winnerID: winner)
    }

    public static func resultDetail(_ state: HouseRocketsOnlineResultState) -> String {
        if state.phase == .waiting { return "house_rockets_result_waiting_detail" }
        if state.phase == .failed {
            switch state.failure {
            case .http(401, _): return "house_rockets_online_sign_in"
            case .http(403, _): return "house_rockets_online_forbidden"
            case .invalidPayload, .protocolFailure: return "house_rockets_online_update_required"
            default: return "house_rockets_result_unavailable_detail"
            }
        }
        if state.phase == .cancelledWithoutRecord { return "house_rockets_result_cancelled_before_start" }
        if state.result?.status == .completed {
            return state.result?.winnerId == nil ? "house_rockets_draw_detail" : "house_rockets_result_detail"
        }
        switch state.endReason {
        case .sessionExpired: return "house_rockets_result_expired"
        case .cancelledByUser: return "house_rockets_result_cancelled_by_user"
        case .insufficientPlayers: return "house_rockets_result_insufficient_players"
        default: return "house_rockets_result_technical_cancel"
        }
    }

    /// Persisted ranks first (ties keep server order), unranked players last.
    public static func orderedResultPlayers(_ result: HouseRocketsResultDTO?) -> [HouseRocketsPlayerResultDTO] {
        (result?.players ?? []).enumerated().sorted {
            let lhs = $0.element.rank ?? Int.max, rhs = $1.element.rank ?? Int.max
            return lhs == rhs ? $0.offset < $1.offset : lhs < rhs
        }.map(\.element)
    }
}
