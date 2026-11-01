import SwiftUI
import FausCrewCore

/// The end menu over the frozen arena, centered from the match's end: finalizing, the
/// champion or the cancellation, the standings (the last seats until the stored ranks
/// arrive: ties shared, a cancelled match unranked), the exit and the rematch. The copy
/// rules are `HouseTanksOnlineCopyKeys`.
struct HouseTanksOnlineResultPanel: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let state: HouseTanksOnlineResultState
    let standings: [HouseTanksOnlineStanding]
    let localPlayerID: String?
    let memberNames: [String: String]
    let onRetry: () -> Void
    let onRematch: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            HouseTanksMapPalette.ink.opacity(0.34).ignoresSafeArea()
            VStack(spacing: AppDesign.Spacing.md) {
                // As tall as its rows; scrolls only when eight do not fit.
                ViewThatFits(in: .vertical) {
                    summary
                    ScrollView { summary }
                }
                if state.phase == .failed {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let now = ProcessInfo.processInfo.systemUptime
                        if allowsRetry {
                            let remaining = max(0, Int(ceil(state.retryNotBefore - now)))
                            Button(copy(remaining > 0 ? "house_tanks_online_result_retry_after" : "house_tanks_online_result_retry",
                                        replacements: ["seconds": "\(remaining)"]), action: onRetry)
                                .font(.subheadline.weight(.bold))
                                .frame(minHeight: 44)
                                .disabled(!state.canRetry(at: now))
                        }
                    }
                }
                HStack(spacing: AppDesign.Spacing.md) {
                    actionButton(copy("house_tanks_exit"), icon: "rectangle.portrait.and.arrow.right",
                                 tint: HouseTanksMapPalette.umber, action: onExit)
                    if state.canRematch {
                        actionButton(copy("house_tanks_rematch"), icon: "arrow.triangle.2.circlepath",
                                     tint: HouseTanksMapPalette.steel, action: onRematch)
                    }
                }
            }
            .padding(AppDesign.Spacing.lg)
            .houseTanksFieldCard(padding: 0)
            .background(HouseTanksMapPalette.paper.opacity(0.96),
                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
            // After the card, which spans whatever it is offered: centered on screen.
            .frame(maxWidth: 460, maxHeight: 360)
            .padding(AppDesign.Spacing.lg)
        }
    }

    /// Title, detail and the standings: the part that scrolls when it does not fit.
    private var summary: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: state.result?.status == .completed ? "trophy.fill" : "flag.fill")
                .font(.title2.weight(.black))
                .foregroundStyle(HouseTanksMapPalette.steel)
                .accessibilityHidden(true)
            Text(title)
                .font(.title3.weight(.black))
                .fontWidth(.condensed)
                .foregroundStyle(HouseTanksFieldTheme.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(copy(HouseTanksOnlineCopyKeys.resultDetail(state)))
                .font(.subheadline)
                .foregroundStyle(HouseTanksFieldTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            if state.phase == .waiting || state.phase == .idle {
                ProgressView().tint(HouseTanksMapPalette.steel)
                    .accessibilityLabel(copy("house_tanks_online_finalizing"))
            }
            if !standings.isEmpty {
                VStack(spacing: AppDesign.Spacing.xs) {
                    ForEach(standings, id: \.playerID) { standing in
                        row(standing)
                    }
                    if standings.first?.isProvisional == true {
                        Text(copy("house_tanks_online_standings_provisional"))
                            .font(.caption)
                            .foregroundStyle(HouseTanksFieldTheme.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.top, AppDesign.Spacing.xs)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func row(_ player: HouseTanksOnlineStanding) -> some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            Text(player.rank.map { "\($0)." } ?? "—")
                .font(.subheadline.weight(.black))
                .monospacedDigit()
                .frame(width: 28, alignment: .leading)
                .accessibilityLabel(player.rank.map {
                    copy("house_tanks_online_result_rank", replacements: ["rank": "\($0)"])
                } ?? copy("house_tanks_online_result_unranked"))
            if let color = player.color {
                Circle().fill(Color(uiColor: color.uiColor))
                    .frame(width: 10, height: 10)
                    .accessibilityHidden(true)
            }
            Text(verbatim: player.displayName ?? name(player.playerID))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HouseTanksFieldTheme.ink)
                .lineLimit(1)
            if player.playerID == localPlayerID {
                Text(copy("house_tanks_online_you"))
                    .font(.caption)
                    .foregroundStyle(HouseTanksFieldTheme.muted)
            }
            Spacer(minLength: AppDesign.Spacing.sm)
            Text(copy("house_tanks_online_round_score", replacements: ["wins": "\(player.roundsWon)"]))
                .font(HouseTanksFieldTheme.stencil)
                .foregroundStyle(HouseTanksMapPalette.umber)
        }
        .accessibilityElement(children: .combine)
    }

    private func actionButton(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(HouseTanksMapPalette.paper)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(tint, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
        }
        .buttonStyle(HouseTanksRaisedButtonStyle(depth: tint, offset: 3))
    }

    private var title: String {
        switch HouseTanksOnlineCopyKeys.resultTitle(state, localPlayerID: localPlayerID) {
        case .key(let key): return copy(key)
        case .champion(let id): return copy("house_tanks_online_champion", replacements: ["name": name(id)])
        }
    }

    private var allowsRetry: Bool { state.canRetry(at: max(ProcessInfo.processInfo.systemUptime, state.retryNotBefore)) }

    private func name(_ id: String) -> String {
        state.identities[id]?.displayName ?? memberNames[id] ?? copy("house_tanks_online_player")
    }

    private func copy(_ key: String, replacements: [String: String] = [:]) -> String {
        replacements.isEmpty ? appViewModel.localized(key, fallback: key) : appViewModel.localized(key, replacements: replacements)
    }
}

/// A rematch's new session on the match screen, until its first snapshot: the room's
/// status, who is in and ready, the ready toggle and window, and the creator's cancel.
struct HouseTanksOnlineRematchRoom: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var model: HouseTanksViewModel
    let memberNames: [String: String]
    let onExit: () -> Void

    var body: some View {
        ZStack {
            HouseTanksMapPalette.ink.opacity(0.34).ignoresSafeArea()
            VStack(spacing: AppDesign.Spacing.sm) {
                header
                roster
                windowCountdown
                actions
            }
            .padding(AppDesign.Spacing.lg)
            .houseTanksFieldCard(padding: 0)
            .background(HouseTanksMapPalette.paper.opacity(0.96),
                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
            // After the card, which spans whatever it is offered: centered on screen.
            .frame(maxWidth: 460, maxHeight: 360)
            .padding(AppDesign.Spacing.lg)
        }
    }

    private var header: some View {
        let state = model.onlineState
        let detail = state.isLobby && state.connection == .connected
            ? "house_tanks_online_rematch_hint" : HouseTanksOnlineCopyKeys.roomDetail(state)
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
            HStack(alignment: .firstTextBaseline) {
                Text(copy("house_tanks_online_rematch_room").uppercased())
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    .tracking(2)
                    .foregroundStyle(HouseTanksMapPalette.umber)
                    .accessibilityAddTraits(.isHeader)
                Spacer(minLength: AppDesign.Spacing.sm)
                if state.session != nil {
                    Text(copy("house_tanks_online_ready_count",
                              replacements: ["ready": "\(state.readyCount)", "total": "\(state.participants.count)"]))
                        .font(HouseTanksFieldTheme.stencil)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                }
            }
            Text(copy(HouseTanksOnlineCopyKeys.roomStatus(state)))
                .font(.headline.weight(.black))
                .fontWidth(.condensed)
                .foregroundStyle(HouseTanksFieldTheme.ink)
            Text(copy(detail, replacements: ["minimum": "\(state.session?.rules.minimumPlayers ?? 2)"]))
                .font(.subheadline)
                .foregroundStyle(HouseTanksFieldTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var roster: some View {
        ScrollView {
            VStack(spacing: AppDesign.Spacing.xs) {
                ForEach(members, id: \.id) { member in
                    memberRow(member)
                }
            }
        }
    }

    private func memberRow(_ member: Member) -> some View {
        let ready = member.state == .ready
        return HStack(spacing: AppDesign.Spacing.sm) {
            Text(verbatim: member.name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HouseTanksFieldTheme.ink)
                .lineLimit(1)
            if member.isLocal {
                Text(copy("house_tanks_online_you")).font(.caption).foregroundStyle(HouseTanksFieldTheme.muted)
            }
            Spacer(minLength: AppDesign.Spacing.sm)
            Label(copy(HouseTanksOnlineCopyKeys.playerStatus(member.state)),
                  systemImage: ready ? "checkmark.seal.fill" : "clock")
                .font(HouseTanksFieldTheme.stencil)
                .foregroundStyle(ready ? HouseTanksMapPalette.steel : HouseTanksFieldTheme.muted)
        }
        .accessibilityElement(children: .combine)
    }

    private var windowCountdown: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let session = model.onlineState.session?.state
            if session == .readyWindow || session == .countdown, let seconds = model.onlineCountdown() {
                Label(copy("house_tanks_online_seconds", replacements: ["seconds": "\(seconds)"]), systemImage: "timer")
                    .font(HouseTanksFieldTheme.stencil)
                    .foregroundStyle(HouseTanksMapPalette.umber)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var actions: some View {
        let state = model.onlineState
        let localID = appViewModel.currentUserId
        let isReady = state.localPlayer(localID)?.state == .ready
        let canChange = state.canChangeReady(playerID: localID)
        let canRetry = state.connection == .failed && state.canReconnect(at: .infinity)
        return VStack(spacing: AppDesign.Spacing.xs) {
            HStack(spacing: AppDesign.Spacing.md) {
                button(copy("house_tanks_online_leave"), icon: "rectangle.portrait.and.arrow.right",
                       tint: HouseTanksMapPalette.umber, action: onExit)
                if canRetry {
                    button(copy("house_tanks_online_retry"), icon: "arrow.clockwise",
                           tint: HouseTanksMapPalette.steel, action: model.retryOnline)
                } else {
                    button(copy(isReady ? "house_tanks_online_not_ready" : "house_tanks_online_ready"),
                           icon: isReady ? "xmark.circle" : "checkmark.circle.fill",
                           tint: isReady ? HouseTanksMapPalette.umber : HouseTanksMapPalette.steel) {
                        model.setOnlineReady(!isReady)
                    }
                    .disabled(!canChange)
                    .opacity(canChange ? 1 : 0.5)
                }
            }
            if let context = roomContext, state.canCancel(context: context) {
                Button(copy("house_tanks_online_cancel"), role: .destructive, action: model.cancelOnlineMatch)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HouseTanksFieldTheme.danger)
                    .frame(minHeight: 44)
            }
        }
    }

    private struct Member {
        let id: String
        let name: String
        let isLocal: Bool
        let state: GameSessionPlayerState
    }

    private var roomContext: GameLaunchContext? {
        appViewModel.currentUserId.map {
            GameLaunchContext(houseID: appViewModel.currentHouseDetails?.id, localPlayerID: $0,
                              houseOwnerID: appViewModel.currentHouseDetails?.ownerId)
        }
    }

    private var members: [Member] {
        let localID = appViewModel.currentUserId
        let rows = model.onlineState.participants.map { player in
            Member(id: player.playerId, name: memberNames[player.playerId] ?? copy("house_tanks_online_player"),
                   isLocal: player.playerId == localID, state: player.state)
        }
        return rows.filter(\.isLocal) + rows.filter { !$0.isLocal }
    }

    private func button(_ title: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(HouseTanksMapPalette.paper)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(tint, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
        }
        .buttonStyle(HouseTanksRaisedButtonStyle(depth: tint, offset: 3))
    }

    private func copy(_ key: String, replacements: [String: String] = [:]) -> String {
        replacements.isEmpty ? appViewModel.localized(key, fallback: key) : appViewModel.localized(key, replacements: replacements)
    }
}
