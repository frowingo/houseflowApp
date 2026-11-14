import SwiftUI
import FausCrewCore

/// The end menu over the frozen course, like Faus Tanks' and Faus Switch's: the result
/// (persisted ranks as supplied, ties and unranked cancellations included), then Back to
/// Lobby (the portrait online room) and Play Again (a new flight with the crew that stays).
/// The card fits the landscape screen; only the standings scroll when they do not.
struct HouseRocketsOnlineResultView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let state: HouseRocketsOnlineResultState
    let localPlayerID: String?
    let memberNames: [String: String]
    let canReturnToLobby: Bool
    let onRetry: () -> Void
    let onBackToLobby: () -> Void
    let onPlayAgain: () -> Void

    var body: some View {
        HouseRocketsArenaCard {
            ViewThatFits(in: .vertical) {
                summary
                ScrollView { summary }
            }
            if state.phase == .failed {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let now = ProcessInfo.processInfo.systemUptime
                    if allowsRetry {
                        let remaining = max(0, Int(ceil(state.retryNotBefore - now)))
                        Button(copy(remaining > 0 ? "house_rockets_result_retry_after" : "house_rockets_result_retry",
                                    replacements: ["seconds": "\(remaining)"]), action: onRetry)
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(HouseRocketsPreparationTheme.accent)
                            .frame(minHeight: 44)
                            .disabled(!state.canRetry(at: now))
                    }
                }
            }
            HouseRocketsArenaActions {
                HouseRocketsArenaButton(title: copy("house_rockets_back_to_lobby"), icon: "list.bullet.rectangle",
                                        isPrimary: false, action: onBackToLobby)
                    .disabled(!canReturnToLobby)
                HouseRocketsArenaButton(title: copy("house_rockets_rematch"), icon: "arrow.triangle.2.circlepath",
                                        isPrimary: true, action: onPlayAgain)
                    .disabled(!state.canRematch)
            }
        }
    }

    /// Title, detail and the standings: the part that scrolls when it does not fit.
    private var summary: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            HouseRocketsRocketMark().frame(width: 34, height: 34)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.black))
                .foregroundStyle(HouseRocketsPreparationTheme.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(copy(HouseRocketsOnlineCopyKeys.resultDetail(state)))
                .font(.subheadline)
                .foregroundStyle(HouseRocketsPreparationTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if state.phase == .waiting || state.phase == .idle {
                ProgressView().tint(HouseRocketsPreparationTheme.accent)
                    .accessibilityLabel(copy("house_rockets_online_finalizing"))
            }
            if let result = state.result {
                if result.startedAt != nil {
                    Label(copy("house_rockets_result_duration", replacements: [
                        "seconds": result.durationSeconds.formatted(.number.precision(.fractionLength(1)))
                    ]), systemImage: "timer")
                    .font(.caption.weight(.semibold)).monospacedDigit()
                    .foregroundStyle(HouseRocketsPreparationTheme.muted)
                }
                VStack(spacing: AppDesign.Spacing.xs) {
                    ForEach(orderedPlayers, id: \.playerId) { row($0) }
                }
                .padding(.top, AppDesign.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ player: HouseRocketsPlayerResultDTO) -> some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            Text(player.rank.map { "\($0)." } ?? "—")
                .font(.subheadline.weight(.black)).monospacedDigit()
                .frame(width: 28, alignment: .leading)
                .accessibilityLabel(player.rank.map {
                    copy("house_rockets_result_rank", replacements: ["rank": "\($0)"])
                } ?? copy("house_rockets_result_unranked"))
            if let identity = state.identities[player.playerId] {
                HouseRocketsColorRocket(color: identity.color)
                    .frame(width: 22, height: 22)
                    .background(Color(HouseRocketsPalette.navy), in: Circle())
                    .accessibilityHidden(true)
            }
            Text(verbatim: name(player.playerId))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HouseRocketsPreparationTheme.ink)
                .lineLimit(1)
            if player.playerId == localPlayerID {
                Text(copy("house_rockets_you")).font(.caption).foregroundStyle(HouseRocketsPreparationTheme.muted)
            }
            Spacer(minLength: AppDesign.Spacing.sm)
            Text(copy("house_rockets_result_distance", replacements: [
                "distance": player.distance.formatted(.number.precision(.fractionLength(0)))
            ]))
            .font(.caption.weight(.semibold)).monospacedDigit()
            .foregroundStyle(HouseRocketsPreparationTheme.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private var orderedPlayers: [HouseRocketsPlayerResultDTO] {
        HouseRocketsOnlineCopyKeys.orderedResultPlayers(state.result)
    }

    private var title: String {
        switch HouseRocketsOnlineCopyKeys.resultTitle(state, localPlayerID: localPlayerID) {
        case .key(let key): return copy(key)
        case .lost(let winner): return copy("house_rockets_lost", replacements: ["name": name(winner)])
        }
    }

    private var allowsRetry: Bool { state.canRetry(at: max(ProcessInfo.processInfo.systemUptime, state.retryNotBefore)) }
    private func name(_ id: String) -> String {
        state.identities[id]?.displayName ?? memberNames[id] ?? copy(id == localPlayerID ? "house_rockets_you" : "house_rockets_member")
    }
    private func copy(_ key: String, replacements: [String: String] = [:]) -> String {
        appViewModel.localized(key, replacements: replacements)
    }
}

/// Play Again's new room over the last flight's frozen course, until the new flight's
/// countdown: who is in and ready (the player is made ready on joining), the room's
/// deadline, the ready toggle and Back to Lobby.
struct HouseRocketsOnlineReplayRoom: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var model: HouseRocketsViewModel
    let memberNames: [String: String]
    let onBackToLobby: () -> Void

    private var state: HouseRocketsOnlineLobbyState { model.onlineState }
    private var localPlayerID: String? { model.context.localPlayerID }

    var body: some View {
        HouseRocketsArenaCard {
            header
            // As tall as its rows; scrolls only when the crew does not fit.
            ViewThatFits(in: .vertical) {
                roster
                ScrollView { roster }
            }
            HouseRocketsArenaActions {
                HouseRocketsArenaButton(title: copy("house_rockets_back_to_lobby"), icon: "list.bullet.rectangle",
                                        isPrimary: false, action: onBackToLobby)
                    .disabled(state.isLeaving)
                if state.connection == .failed, state.canReconnect(at: .infinity) {
                    HouseRocketsArenaButton(title: copy("house_rockets_online_retry"), icon: "arrow.clockwise",
                                            isPrimary: true, action: model.retryOnline)
                } else {
                    let isReady = state.localPlayer(localPlayerID)?.state == .ready
                    HouseRocketsArenaButton(title: copy(isReady ? "house_rockets_not_ready_action" : "house_rockets_ready_action"),
                                            icon: isReady ? "xmark.circle" : "checkmark.circle.fill",
                                            isPrimary: !isReady, action: { model.setOnlineReady(!isReady) })
                        .disabled(!model.canChangeOnlineReady(playerID: localPlayerID))
                }
            }
        }
    }

    private var header: some View {
        let isLocalReady = state.localPlayer(localPlayerID)?.state == .ready
        let inRoom = state.isLobby && state.connection == .connected && state.isSynced
        let detail = inRoom ? (isLocalReady ? "house_rockets_online_replay_detail" : "house_rockets_online_replay_not_ready")
            : HouseRocketsOnlineCopyKeys.lobbyDetail(state)
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(copy("house_rockets_online_replay_title").uppercased())
                    .font(HouseRocketsRoomStyle.stencil)
                    .tracking(2)
                    .foregroundStyle(HouseRocketsPreparationTheme.accent)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: AppDesign.Spacing.sm)
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    if let seconds = model.onlineCountdown() {
                        Label(copy("house_rockets_online_seconds", replacements: ["seconds": "\(seconds)"]), systemImage: "timer")
                            .font(HouseRocketsRoomStyle.stencil).monospacedDigit()
                            .foregroundStyle(HouseRocketsPreparationTheme.ink)
                    }
                }
            }
            HStack(spacing: AppDesign.Spacing.sm) {
                if HouseRocketsOnlineCopyKeys.lobbyShowsProgress(state) {
                    ProgressView().tint(HouseRocketsPreparationTheme.accent)
                }
                Text(copy(HouseRocketsOnlineCopyKeys.lobbyStatus(state)))
                    .font(.headline)
                    .foregroundStyle(state.connection == .failed ? HouseRocketsPreparationTheme.danger
                                     : HouseRocketsPreparationTheme.ink)
                Spacer(minLength: 0)
                if state.session != nil {
                    Text(copy("house_rockets_ready_count",
                              replacements: ["ready": "\(state.readyCount)", "total": "\(state.participants.count)"]))
                        .font(.caption.weight(.semibold)).monospacedDigit()
                        .foregroundStyle(HouseRocketsPreparationTheme.muted)
                }
            }
            Text(copy(detail, replacements: ["minimum": "\(state.session?.rules.minimumPlayers ?? 2)"]))
                .font(.subheadline)
                .foregroundStyle(HouseRocketsPreparationTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if let issue = state.issue, state.connection != .reconnecting {
                Text(copy(HouseRocketsOnlineCopyKeys.issue(issue)))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HouseRocketsPreparationTheme.danger)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var roster: some View {
        let players = state.participants.filter { $0.playerId == localPlayerID }
            + state.participants.filter { $0.playerId != localPlayerID }
        return VStack(spacing: AppDesign.Spacing.xs) {
            ForEach(players, id: \.playerId) { player in
                let ready = player.state == .ready
                HStack(spacing: AppDesign.Spacing.sm) {
                    Group {
                        if let color = model.onlineColor(of: player.playerId) {
                            HouseRocketsColorRocket(color: color)
                        } else {
                            Circle().fill(HouseRocketsPreparationTheme.surface.opacity(0.3)).padding(6)
                        }
                    }
                    .frame(width: 22, height: 22)
                    .background(Color(HouseRocketsPalette.navy), in: Circle())
                    .accessibilityHidden(true)
                    Text(verbatim: memberNames[player.playerId]
                         ?? appViewModel.localized(player.playerId == localPlayerID ? "house_rockets_you" : "house_rockets_member"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(HouseRocketsPreparationTheme.ink)
                        .lineLimit(1)
                    if player.playerId == localPlayerID, memberNames[player.playerId] != nil {
                        Text(copy("house_rockets_you")).font(.caption).foregroundStyle(HouseRocketsPreparationTheme.muted)
                    }
                    Spacer(minLength: AppDesign.Spacing.sm)
                    Label(copy(HouseRocketsOnlineCopyKeys.playerStatus(player.state)),
                          systemImage: ready ? "checkmark.circle.fill" : "clock")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(ready ? HouseRocketsPreparationTheme.accent : HouseRocketsPreparationTheme.muted)
                }
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func copy(_ key: String, replacements: [String: String] = [:]) -> String {
        appViewModel.localized(key, replacements: replacements)
    }
}

/// A cream card centered over the dimmed course, sized to the screen it is offered:
/// at most 460 points wide and the screen's height less the margins.
private struct HouseRocketsArenaCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ZStack {
            Color(HouseRocketsPalette.navy).opacity(0.45).ignoresSafeArea()
            VStack(spacing: AppDesign.Spacing.md) { content }
                .padding(AppDesign.Spacing.lg)
                .background(HouseRocketsPreparationTheme.surface.opacity(0.97),
                            in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous)
                    .stroke(HouseRocketsPreparationTheme.hairline, lineWidth: 1))
                .frame(maxWidth: 460)
                .padding(AppDesign.Spacing.lg)
        }
    }
}

/// Side by side when they fit, stacked for large text.
private struct HouseRocketsArenaActions<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: AppDesign.Spacing.md) { content }
            VStack(spacing: AppDesign.Spacing.sm) { content }
        }
    }
}

private struct HouseRocketsArenaButton: View {
    @Environment(\.isEnabled) private var isEnabled
    let title: String
    let icon: String
    let isPrimary: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .lineLimit(1)
                .foregroundStyle(isPrimary ? HouseRocketsPreparationTheme.surface : HouseRocketsPreparationTheme.ink)
                .padding(.horizontal, AppDesign.Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(isPrimary ? HouseRocketsPreparationTheme.accent : Color(HouseRocketsPalette.navy).opacity(0.08),
                            in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
                .opacity(isEnabled ? 1 : 0.45)
        }
        .buttonStyle(ScaleButtonStyle())
    }
}
