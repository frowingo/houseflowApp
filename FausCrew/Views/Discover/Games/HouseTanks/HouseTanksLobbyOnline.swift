import SwiftUI
import FausCrewCore

/// Online flow of the lobby: the house's room with its drawn map, color claims and ready state.
struct HouseTanksOnlineRoomView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var model: HouseTanksViewModel
    /// The start card (countdown, then the drawn map) is on screen. The lobby owns the flag
    /// because its navigation bar shows a small countdown while the card is scrolled away.
    @Binding var isStartCardVisible: Bool

    private var copy: HouseTanksCopy { HouseTanksCopy(appViewModel) }

    @ViewBuilder
    var body: some View {
        if let blockerKey = onlineBlockerKey {
            onlineNotice(title: "house_tanks_online_unavailable", detail: blockerKey, symbol: "wifi.exclamationmark")
        } else if model.onlineCatalog == .unavailable {
            onlineNotice(title: "house_tanks_online_closed", detail: "house_tanks_online_closed_detail", symbol: "lock.fill")
        } else {
            VStack(alignment: .leading, spacing: 28) {
                onlineStatus
                drawnMap
                    .onScrollVisibilityChange(threshold: 0.3) { isStartCardVisible = $0 }
                    .onDisappear { isStartCardVisible = true }
                onlineColorPicker
                onlineRoster
            }
            .task(id: roomContext) {
                guard let context = roomContext, let houseID = context.houseID else { return }
                await model.refreshOnlineCatalog(houseID: houseID)
                guard !Task.isCancelled else { return }
                model.enterOnlineRoom(context: context)
            }
        }
    }

    /// The house and player the room belongs to; a change reopens it.
    private var roomContext: GameLaunchContext? {
        guard let userID = appViewModel.currentUserId, let house = appViewModel.currentHouseDetails else { return nil }
        return GameLaunchContext(houseID: house.id, localPlayerID: userID, houseOwnerID: house.ownerId)
    }

    private var onlineBlockerKey: String? {
        guard let userID = appViewModel.currentUserId, !userID.isEmpty else { return "house_tanks_online_sign_in" }
        guard appViewModel.currentHouseDetails != nil else { return "house_tanks_online_house_required" }
        guard model.isOnlineServiceAvailable else { return "house_tanks_online_soon_detail" }
        return nil
    }

    private func onlineNotice(title: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Label(copy(title), systemImage: symbol)
                .font(.headline)
                .foregroundStyle(HouseTanksFieldTheme.ink)
            Text(copy(detail))
                .font(.subheadline)
                .foregroundStyle(HouseTanksFieldTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
        }
        .houseTanksFieldCard(padding: AppDesign.Spacing.xl)
    }

    private var onlineStatus: some View {
        let state = model.onlineState
        let minimum = state.session?.rules.minimumPlayers ?? 2
        let warns = state.requiresUpdate || state.connection == .failed
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(alignment: .top, spacing: AppDesign.Spacing.md) {
                Group {
                    if HouseTanksOnlineCopyKeys.showsProgress(state) {
                        ProgressView().tint(HouseTanksMapPalette.steel)
                    } else {
                        Image(systemName: onlineStatusSymbol(state))
                            .foregroundStyle(warns ? HouseTanksFieldTheme.danger : HouseTanksMapPalette.steel)
                    }
                }
                .font(.title3.weight(.bold))
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                    Text(copy(HouseTanksOnlineCopyKeys.roomStatus(state)))
                        .font(.headline)
                        .foregroundStyle(warns ? HouseTanksFieldTheme.danger : HouseTanksFieldTheme.ink)
                    Text(copy(HouseTanksOnlineCopyKeys.roomDetail(state), replacements: ["minimum": "\(minimum)"]))
                        .font(.subheadline)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    // A rejected command or timeout while the room stays connected.
                    if state.connection == .connected, let issue = state.issue {
                        Text(copy(HouseTanksOnlineCopyKeys.issue(issue)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(HouseTanksFieldTheme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            if state.connection == .failed, state.canReconnect(at: .infinity) {
                Button(action: model.retryOnline) {
                    Label(copy("house_tanks_online_retry"), systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(HouseTanksMapPalette.paper)
                        .padding(.horizontal, AppDesign.Spacing.lg)
                        .frame(minHeight: AppDesign.Size.buttonHeightSmall)
                        .background(HouseTanksMapPalette.steel,
                                    in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .houseTanksFieldCard()
    }

    private func onlineStatusSymbol(_ state: HouseTanksOnlineLobbyState) -> String {
        if state.requiresUpdate { return "arrow.down.app.fill" }
        if state.connection == .failed { return "wifi.exclamationmark" }
        if state.isTerminal { return "flag.checkered" }
        return "dot.radiowaves.left.and.right"
    }

    /// Before the draw the card counts down to the match; once the server draws the arena
    /// it shows the map (with the match countdown over it).
    @ViewBuilder
    private var drawnMap: some View {
        if let arena = model.onlineArena {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                HouseTanksSectionHeader(code: "01", key: "house_tanks_online_map_title")
                VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                    HouseTanksMapPreview(mapID: arena.map.id, isSelected: true, seats: arena.tanks.map {
                        .init(x: $0.position.x / HouseTanksWorld.arenaSize.width,
                              y: $0.position.y / HouseTanksWorld.arenaSize.height,
                              rotation: $0.rotation, color: $0.color)
                    })
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
                    .overlay { countdownStamp }
                    .overlay(alignment: .topTrailing) { randomStamp }
                    HStack(alignment: .firstTextBaseline, spacing: AppDesign.Spacing.sm) {
                        Image(systemName: "dice.fill")
                            .foregroundStyle(HouseTanksMapPalette.umber)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(copy(arena.map.id.titleKey))
                                .font(.headline)
                                .foregroundStyle(HouseTanksFieldTheme.ink)
                            Text(copy(arena.map.id.detailKey))
                                .font(.caption)
                                .foregroundStyle(HouseTanksFieldTheme.muted)
                        }
                    }
                    .accessibilityElement(children: .combine)
                    Text(copy("house_tanks_online_map_detail"))
                        .font(.caption)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .houseTanksFieldCard()
            }
        } else {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                HouseTanksSectionHeader(code: "01", key: "house_tanks_online_start_title")
                VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                    startCountdown
                    Text(copy("house_tanks_online_map_pending"))
                        .font(.caption)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .houseTanksFieldCard()
            }
        }
    }

    /// The ready window's seconds as large as the map that replaces them; before the window
    /// opens, how many ready players start it.
    private var startCountdown: some View {
        let state = model.onlineState
        return TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let seconds = state.session?.state == .readyWindow || state.session?.state == .countdown
                ? model.onlineCountdown() : nil
            VStack(spacing: AppDesign.Spacing.xs) {
                if let seconds {
                    Text(copy("house_tanks_online_start_until"))
                        .font(HouseTanksFieldTheme.stencil)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                    HStack(alignment: .firstTextBaseline, spacing: AppDesign.Spacing.xs) {
                        Text(verbatim: "\(seconds)")
                            .font(.system(size: 88, weight: .black, design: .rounded))
                            .monospacedDigit()
                            .contentTransition(.numericText(countsDown: true))
                            .foregroundStyle(seconds <= 5 ? HouseTanksFieldTheme.danger : HouseTanksFieldTheme.ink)
                        Text(copy("house_tanks_online_seconds_unit"))
                            .font(.title3.weight(.heavy))
                            .foregroundStyle(HouseTanksFieldTheme.muted)
                    }
                    .animation(.snappy, value: seconds)
                } else {
                    Image(systemName: "hourglass")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(HouseTanksMapPalette.umber)
                    Text(copy("house_tanks_online_start_waiting"))
                        .font(.headline)
                        .foregroundStyle(HouseTanksFieldTheme.ink)
                    Text(copy("house_tanks_online_start_waiting_detail",
                              replacements: ["minimum": "\(state.session?.rules.minimumPlayers ?? 2)"]))
                        .font(.caption)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                if state.session != nil {
                    Text(copy("house_tanks_online_ready_count",
                              replacements: ["ready": "\(state.readyCount)", "total": "\(state.participants.count)"]))
                        .font(HouseTanksFieldTheme.stencil)
                        .foregroundStyle(HouseTanksMapPalette.steel)
                }
            }
            .padding(AppDesign.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .accessibilityElement(children: .combine)
        }
        .aspectRatio(872 / 400, contentMode: .fit)
        .frame(maxWidth: .infinity)
        .background(HouseTanksMapPalette.sand.opacity(0.45),
                    in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous)
            .stroke(HouseTanksMapPalette.slate.opacity(0.4), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
    }

    private var randomStamp: some View {
        Text(copy("house_tanks_random_stamp"))
            .font(.system(.caption, design: .monospaced).weight(.heavy))
            .tracking(1.6)
            .foregroundStyle(HouseTanksMapPalette.umber)
            .padding(.horizontal, AppDesign.Spacing.sm)
            .padding(.vertical, 3)
            .overlay(Rectangle().stroke(HouseTanksMapPalette.umber, lineWidth: 1.5))
            .background(HouseTanksMapPalette.paper.opacity(0.8))
            .rotationEffect(.degrees(-8))
            .padding(AppDesign.Spacing.md)
    }

    /// The match countdown over the drawn map, from the server's deadline.
    private var countdownStamp: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            if model.onlineState.game?.phase == .countdown, let seconds = model.onlineCountdown() {
                Text(verbatim: "\(max(1, seconds))")
                    .font(.system(size: 56, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(HouseTanksMapPalette.paper)
                    .frame(width: 92, height: 92)
                    .background(HouseTanksMapPalette.ink.opacity(0.72), in: Circle())
                    .accessibilityLabel(copy("house_tanks_online_seconds", replacements: ["seconds": "\(seconds)"]))
            }
        }
    }

    /// The online room's tank color: colors other players hold are taken, the selection is
    /// the color the server gives this player, and a ready player's color is locked until
    /// they take the ready back (Faus Switch's rules, from Core).
    private var onlineColorPicker: some View {
        let lobby = model.onlineLobbyColors
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HouseTanksSectionHeader(code: "02", key: "house_tanks_online_color_title")
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                LazyVGrid(columns: HouseTanksColorSwatch.gridColumns, spacing: AppDesign.Spacing.sm) {
                    ForEach(HouseTanksColor.allCases) { color in
                        HouseTanksColorSwatch(color: color,
                                              isSelected: model.onlineLocalColor == color,
                                              isTaken: lobby.isTakenByOthers(color),
                                              isLocked: lobby.isLocked) {
                            model.humanColor = color
                        }
                    }
                }
                if lobby.isLocked {
                    Label(copy("house_tanks_online_color_locked"), systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else if lobby.isPreferredTaken(model.humanColor) {
                    Label(copy("house_tanks_online_color_taken"), systemImage: "person.2.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HouseTanksFieldTheme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(copy("house_tanks_online_color_note"))
                    .font(.caption)
                    .foregroundStyle(HouseTanksFieldTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .houseTanksFieldCard()
        }
    }

    private var onlineRoster: some View {
        let state = model.onlineState
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                HouseTanksSectionHeader(code: "03", key: "house_tanks_online_roster")
                Spacer(minLength: AppDesign.Spacing.sm)
                if state.session != nil {
                    Text(copy("house_tanks_online_ready_count",
                              replacements: ["ready": "\(state.readyCount)", "total": "\(state.participants.count)"]))
                        .font(HouseTanksFieldTheme.stencil)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                }
            }
            VStack(spacing: AppDesign.Spacing.md) {
                if onlineMembers.isEmpty {
                    Text(copy("house_tanks_online_syncing"))
                        .font(.subheadline)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(onlineMembers) { member in
                    HStack(spacing: AppDesign.Spacing.sm) {
                        // The member's tank in their color, like Faus Switch's robots.
                        if let color = member.color {
                            HouseTanksArenaTank(color: color)
                                .frame(width: 30, height: 30)
                        } else {
                            Circle()
                                .fill(HouseTanksMapPalette.slate.opacity(0.35))
                                .frame(width: 20, height: 20)
                                .frame(width: 30, height: 30)
                        }
                        Text(verbatim: member.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HouseTanksFieldTheme.ink)
                            .lineLimit(1)
                        if member.isLocal {
                            Text(copy("house_tanks_you"))
                                .font(.caption)
                                .foregroundStyle(HouseTanksFieldTheme.muted)
                        }
                        Spacer(minLength: AppDesign.Spacing.sm)
                        Label(copy(HouseTanksOnlineCopyKeys.playerStatus(member.state)),
                              systemImage: member.state == .ready ? "checkmark.seal.fill" : "clock")
                            .font(HouseTanksFieldTheme.stencil)
                            .foregroundStyle(member.state == .ready ? HouseTanksMapPalette.steel : HouseTanksFieldTheme.muted)
                    }
                    .accessibilityElement(children: .combine)
                }
                // Ready and the creator's cancel sit right under the players while the room is a lobby.
                if showsOnlineActions { onlineActions }
            }
            .houseTanksFieldCard()
        }
    }

    /// Ready toggle and the creator's cancel; the window counts down in the start card.
    private var onlineActions: some View {
        let state = model.onlineState
        let localID = appViewModel.currentUserId
        let isReady = state.localPlayer(localID)?.state == .ready
        return VStack(spacing: AppDesign.Spacing.sm) {
            Button { model.setOnlineReady(!isReady) } label: {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Image(systemName: isReady ? "xmark.circle" : "checkmark.circle.fill")
                    Text(copy(isReady ? "house_tanks_online_not_ready" : "house_tanks_online_ready"))
                }
                .font(.headline)
                .foregroundStyle(HouseTanksMapPalette.paper)
                .frame(maxWidth: .infinity, minHeight: AppDesign.Size.buttonHeightLarge)
                .background(isReady ? HouseTanksMapPalette.umber : HouseTanksMapPalette.steel,
                            in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!model.canChangeOnlineReady(playerID: localID))
            .opacity(model.canChangeOnlineReady(playerID: localID) ? 1 : 0.5)

            if model.onlineState.canCancel(context: roomContext ?? GameLaunchContext(houseID: nil, localPlayerID: nil)) {
                Button(copy("house_tanks_online_cancel"), role: .destructive, action: model.cancelOnlineMatch)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HouseTanksFieldTheme.danger)
                    .frame(minHeight: 44)
            }
        }
        .padding(.top, AppDesign.Spacing.xs)
    }

    private var showsOnlineActions: Bool {
        model.selectedMode == .online && onlineBlockerKey == nil && model.onlineCatalog != .unavailable
            && model.onlineState.session != nil && model.onlineState.isLobby && !model.onlineState.isTerminal
    }

    private struct OnlineMember: Identifiable {
        let id: String
        let name: String
        let isLocal: Bool
        let state: GameSessionPlayerState
        let color: HouseTanksColor?
    }

    /// The session's players, the local one first, named from the house roster and colored
    /// from the lobby claims (the server's tanks once it seats them).
    private var onlineMembers: [OnlineMember] {
        let localID = appViewModel.currentUserId
        let names = Dictionary((appViewModel.currentHouseDetails?.members ?? []).map { ($0.id, $0.fullName) },
                               uniquingKeysWith: { first, _ in first })
        let seated = Dictionary((model.onlineState.game?.players ?? []).map { ($0.playerId, $0) },
                                uniquingKeysWith: { first, _ in first })
        let members = model.onlineState.participants.map { player in
            OnlineMember(id: player.playerId,
                         name: seated[player.playerId]?.displayName ?? names[player.playerId] ?? copy("house_tanks_online_player"),
                         isLocal: player.playerId == localID, state: player.state,
                         color: model.onlineColor(of: player.playerId))
        }
        return members.filter(\.isLocal) + members.filter { !$0.isLocal }
    }
}
