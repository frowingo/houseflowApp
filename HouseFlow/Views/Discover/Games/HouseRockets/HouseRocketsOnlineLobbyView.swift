import SwiftUI

/// Presentation only; lifecycle commands and deadlines belong to the lobby service.
struct HouseRocketsOnlineLobbyView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let state: HouseRocketsOnlineLobbyState
    let localPlayerID: String?
    let memberNames: [String: String]
    let isWaitingForLandscape: Bool
    let orientationFailed: Bool
    let onReady: () -> Void
    let onRetry: () -> Void
    let canCancel: Bool
    let onCancel: () -> Void
    let onExit: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
            HStack(spacing: AppDesign.Spacing.sm) {
                if !state.isTerminal && state.connection != .failed && (state.connection == .connecting || state.connection == .idle || !state.isSynced || state.pendingCommand != nil || state.isLeaving) {
                    ProgressView().tint(HouseRocketsTheme.accent)
                }
                Label(copy(statusKey), systemImage: state.connection == .failed ? "wifi.exclamationmark" : "person.2")
                    .font(.headline)
                    .foregroundStyle(HouseRocketsTheme.ink)
            }
            Text(copy(detailKey, replacements: ["minimum": "\(state.session?.rules.minimumPlayers ?? 2)"]))
                .font(.subheadline)
                .foregroundStyle(HouseRocketsTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if state.connection == .reconnecting {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    let remaining = max(0, Int(ceil((state.retryNotBefore ?? 0) - ProcessInfo.processInfo.systemUptime)))
                    Text(copy("house_rockets_reconnect_wait", replacements: ["seconds": "\(remaining)"]))
                        .font(.subheadline).monospacedDigit().foregroundStyle(HouseRocketsTheme.muted)
                }
            }

            if !state.participants.isEmpty {
                VStack(spacing: AppDesign.Spacing.md) {
                    ForEach(Array(state.participants.enumerated()), id: \.element.playerId) { index, player in
                        HStack(spacing: AppDesign.Spacing.sm) {
                            Circle()
                                .fill(Color(HouseRocketsPalette.player(HouseRocketsColor.allCases[index % 8])))
                                .frame(width: 10, height: 10)
                            Text(verbatim: memberNames[player.playerId] ?? copy(player.playerId == localPlayerID
                                                                               ? "house_rockets_you" : "house_rockets_member"))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(HouseRocketsTheme.ink)
                            if player.playerId == localPlayerID, memberNames[player.playerId] != nil {
                                Text(copy("house_rockets_you"))
                                    .font(.caption)
                                    .foregroundStyle(HouseRocketsTheme.muted)
                            }
                            Spacer(minLength: 8)
                            Label(copy(playerStatusKey(player.state)),
                                  systemImage: player.state == .ready ? "checkmark.circle.fill" : "clock")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(player.state == .ready ? HouseRocketsTheme.accent : HouseRocketsTheme.muted)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                Text(copy("house_rockets_ready_count", replacements: ["ready": "\(state.readyCount)",
                                                                        "total": "\(state.participants.count)"]))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HouseRocketsTheme.accent)
            }

            if state.session?.state == .readyWindow || state.session?.state == .countdown {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    let deadline = state.session?.state == .countdown ? state.session?.countdownEndsAt : state.session?.readyWindowEndsAt
                    if let seconds = state.remainingSeconds(until: deadline, uptime: ProcessInfo.processInfo.systemUptime) {
                        Text(copy(state.session?.state == .countdown ? "house_rockets_online_countdown" : "house_rockets_ready_deadline",
                                  replacements: ["seconds": "\(seconds)"]))
                            .font(.subheadline.weight(.semibold))
                            .monospacedDigit()
                            .foregroundStyle(HouseRocketsTheme.ink)
                            .accessibilityAddTraits(.updatesFrequently)
                    }
                }
            }

            if let issue = state.issue, state.connection != .reconnecting {
                Text(copy(issueKey(issue)))
                    .font(.subheadline)
                    .foregroundStyle(HouseRocketsTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if orientationFailed {
                Text(copy("house_rockets_landscape_error"))
                    .font(.subheadline)
                    .foregroundStyle(HouseRocketsTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if state.connection == .failed {
                if canRetry {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let now = ProcessInfo.processInfo.systemUptime
                        let remaining = max(0, Int(ceil((state.retryNotBefore ?? now) - now)))
                        Button(copy(remaining > 0 ? "house_rockets_online_retry_after" : "house_rockets_online_retry",
                                    replacements: ["seconds": "\(remaining)"]), action: onRetry)
                            .buttonStyle(.borderedProminent)
                            .tint(HouseRocketsTheme.accent)
                            .foregroundStyle(HouseRocketsTheme.background)
                            .frame(minHeight: 44)
                            .disabled(!state.canReconnect(at: now))
                    }
                }
            } else if state.isLobby {
                Button(action: onReady) {
                    Label(copy(isWaitingForLandscape ? "house_rockets_rotating"
                               : state.localPlayer(localPlayerID)?.state == .ready ? "house_rockets_not_ready_action"
                               : "house_rockets_ready_action"), systemImage: "rectangle.landscape.rotate")
                        .font(.headline)
                        .foregroundStyle(HouseRocketsTheme.background)
                        .frame(maxWidth: .infinity, minHeight: AppDesign.Size.buttonHeightLarge)
                        .background(HouseRocketsTheme.accent,
                                    in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isWaitingForLandscape || !state.canChangeReady(playerID: localPlayerID))
                Text(copy("house_rockets_online_ready_detail"))
                    .font(.caption)
                    .foregroundStyle(HouseRocketsTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if canCancel {
                Button(copy("house_rockets_cancel_flight"), action: onCancel)
                    .foregroundStyle(HouseRocketsTheme.danger).frame(minHeight: 44)
            }
            Button(copy(state.isLeaving ? "house_rockets_leaving" : "house_rockets_exit"), action: onExit)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HouseRocketsTheme.ink)
                .frame(minHeight: 44)
                .disabled(state.isLeaving)
        }
        .padding(AppDesign.Spacing.xl)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(HouseRocketsTheme.panel, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
    }

    private func playerStatusKey(_ state: GameSessionPlayerState) -> String {
        switch state {
        case .ready: return "house_rockets_ready"
        case .playing: return "house_rockets_online_flying"
        case .finished, .left: return "house_rockets_online_ended"
        case .waiting: return "house_rockets_waiting"
        }
    }

    private var statusKey: String {
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

    private var detailKey: String {
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

    private var canRetry: Bool {
        state.canReconnect(at: .infinity)
    }

    private func issueKey(_ issue: HouseRocketsOnlineLobbyIssue) -> String {
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
        case .connection(.protocolFailure(.unsupportedProtocol)), .connection(.protocolFailure(.unsupportedCourse)):
            return "house_rockets_online_update_required"
        case .connection: return "house_rockets_online_connection_failed_detail"
        }
    }

    private func copy(_ key: String, replacements: [String: String] = [:]) -> String {
        appViewModel.localized(key, replacements: replacements)
    }
}

/// Shares the sampled frame with the scene; never computes physics or control authority.
struct HouseRocketsOnlineFlightOverlay: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let state: HouseRocketsOnlineLobbyState
    let presentation: HouseRocketsOnlinePresentation
    let canCancel: Bool
    let onRetry: () -> Void
    let onReclaimControl: () -> Void
    let onCancel: () -> Void
    private var frame: HouseRocketsRenderFrame { presentation.frame }
    let onExit: () -> Void

    var body: some View {
        GeometryReader { geometry in
            let projection = HouseRocketsProjection(elapsedTime: frame.elapsedTime, cameraX: frame.cameraX,
                                                   width: Double(geometry.size.width), height: Double(geometry.size.height),
                                                   courseAngle: frame.courseAngle)
            let regions = projection.informationRegions(width: Double(geometry.size.width), height: Double(geometry.size.height))
            Menu {
                Button(copy("house_rockets_exit"), action: onExit)
                if canCancel {
                    Button(copy("house_rockets_cancel_flight"), role: .destructive, action: onCancel)
                }
            } label: {
                Image(systemName: "ellipsis")
                    .foregroundStyle(HouseRocketsTheme.ink)
                    .frame(width: 44, height: 44)
                    .background(HouseRocketsTheme.panel, in: Circle())
            }
            .accessibilityLabel(copy("house_rockets_flight_actions"))
            .disabled(state.isLeaving)
            .position(x: geometry.size.width - 30, y: geometry.size.height - 30)

            ForEach(regions.indices, id: \.self) { index in
                let region = regions[index]
                VStack(spacing: AppDesign.Spacing.xs) {
                    if index == 0 {
                        HStack(spacing: AppDesign.Spacing.sm) {
                            Label(copy(statusKey), systemImage: presentation.isSyncing ? "arrow.triangle.2.circlepath" : "antenna.radiowaves.left.and.right")
                            if frame.phase == .playing {
                                Label("\(Int(frame.elapsedTime))", systemImage: "timer")
                                    .monospacedDigit()
                                    .accessibilityLabel(copy("house_rockets_time") + " \(Int(frame.elapsedTime))")
                                Label("\(frame.players.filter(\.isAlive).count)", systemImage: "person.2.fill")
                                    .accessibilityLabel(appViewModel.localized("house_rockets_alive", replacements: [
                                        "count": "\(frame.players.filter(\.isAlive).count)"
                                    ]))
                            }
                        }
                        if let effect = frame.players.first(where: { $0.role == .human })?.speedEffect {
                            Text(copy(effect == .boost ? "house_rockets_boost_active" : "house_rockets_slow_active"))
                                .foregroundStyle(HouseRocketsTheme.accent)
                        }
                    } else {
                        if presentation.eliminations.isEmpty {
                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), alignment: .leading),
                                                     count: region.width < 340 ? 2 : 4),
                                      alignment: .leading, spacing: AppDesign.Spacing.xs) {
                                ForEach(frame.players) { player in
                                    HStack(spacing: 4) {
                                        Circle().fill(Color(HouseRocketsPalette.player(player.color))).frame(width: 7, height: 7)
                                        if case .displayName(let name) = player.name {
                                            Text(verbatim: name).strikethrough(!player.isAlive)
                                        }
                                    }
                                    .foregroundStyle(player.isAlive ? HouseRocketsTheme.ink : HouseRocketsTheme.muted)
                                }
                            }
                        } else {
                            Text(appViewModel.localized("house_rockets_online_eliminated", replacements: [
                                "names": presentation.eliminations.map(\.displayName).joined(separator: ", ")
                            ]))
                            .foregroundStyle(HouseRocketsTheme.danger)
                            .lineLimit(region.width < 340 ? 4 : 2)
                            .accessibilityAddTraits(.updatesFrequently)
                        }
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(HouseRocketsTheme.ink)
                .lineLimit(1)
                .frame(width: region.width, height: region.height, alignment: .top)
                .position(x: region.midX, y: region.midY)
                .allowsHitTesting(false)
            }
            if frame.phase == .countdown, !state.isTerminal {
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    let seconds = state.remainingSeconds(until: state.game?.countdownEndsAt ?? state.session?.countdownEndsAt,
                                                         uptime: ProcessInfo.processInfo.systemUptime)
                    VStack(spacing: AppDesign.Spacing.sm) {
                        Text(seconds.map { $0 > 0 ? "\($0)" : copy("house_rockets_online_waiting_start") }
                             ?? copy("house_rockets_online_launching"))
                            .font(seconds.map { $0 > 0 } == true ? .system(size: 64, weight: .black, design: .rounded) : .headline)
                            .monospacedDigit()
                        Text(copy("house_rockets_online_launching_detail")).font(.subheadline)
                    }
                    .foregroundStyle(HouseRocketsTheme.ink)
                    .multilineTextAlignment(.center)
                    .padding(AppDesign.Spacing.xl)
                    .background(HouseRocketsTheme.panel, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
                    .accessibilityAddTraits(.updatesFrequently)
                }
            }
            if state.connection != .connected || !state.isSynced || frame.phase == .recovering || state.controlTransferred {
                HouseRocketsOnlineConnectionView(state: state, onRetry: onRetry, onReclaimControl: onReclaimControl)
                    .frame(maxWidth: min(430, geometry.size.width - 48), maxHeight: geometry.size.height - 96)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }

    private var statusKey: String {
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

    private func copy(_ key: String) -> String { appViewModel.localized(key, fallback: key) }
}
