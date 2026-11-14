import SwiftUI
import FausCrewCore

/// The online room in Faus Tanks' order: the room status, 01 the launch countdown, 02 the
/// rocket color, 03 the crew with ready and cancel under it (How to play follows as 04 in
/// HouseRocketsView). Presentation only; lifecycle commands and deadlines belong to the engine.
struct HouseRocketsOnlineLobbyView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var model: HouseRocketsViewModel
    let memberNames: [String: String]
    let orientationFailed: Bool
    let onReady: () -> Void
    let onCancel: () -> Void
    /// Whether the launch card is on screen; while it is scrolled away the navigation bar
    /// carries a small copy of its seconds.
    let onStartCardVisible: (Bool) -> Void

    private var state: HouseRocketsOnlineLobbyState { model.onlineState }
    private var localPlayerID: String? { model.context.localPlayerID }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            statusCard
            startCard
                .onScrollVisibilityChange(threshold: 0.3) { onStartCardVisible($0) }
                .onDisappear { onStartCardVisible(true) }
            colorPicker
            roster
        }
    }

    // MARK: - Status

    private var statusCard: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(alignment: .top, spacing: AppDesign.Spacing.md) {
                Group {
                    if HouseRocketsOnlineCopyKeys.lobbyShowsProgress(state) {
                        ProgressView().tint(HouseRocketsPreparationTheme.accent)
                    } else {
                        Image(systemName: statusSymbol)
                            .foregroundStyle(state.connection == .failed ? HouseRocketsPreparationTheme.danger
                                             : HouseRocketsPreparationTheme.accent)
                    }
                }
                .font(.title3.weight(.bold))
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                    Text(copy(HouseRocketsOnlineCopyKeys.lobbyStatus(state)))
                        .font(.headline)
                        .foregroundStyle(state.connection == .failed ? HouseRocketsPreparationTheme.danger
                                         : HouseRocketsPreparationTheme.ink)
                    Text(copy(HouseRocketsOnlineCopyKeys.lobbyDetail(state),
                              replacements: ["minimum": "\(state.session?.rules.minimumPlayers ?? 2)"]))
                        .font(.subheadline)
                        .foregroundStyle(HouseRocketsPreparationTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                    if state.connection == .reconnecting {
                        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                            let remaining = max(0, Int(ceil((state.retryNotBefore ?? 0) - ProcessInfo.processInfo.systemUptime)))
                            Text(copy("house_rockets_reconnect_wait", replacements: ["seconds": "\(remaining)"]))
                                .font(.caption).monospacedDigit().foregroundStyle(HouseRocketsPreparationTheme.muted)
                        }
                    }
                    if let issue = state.issue, state.connection != .reconnecting {
                        Text(copy(HouseRocketsOnlineCopyKeys.issue(issue)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(HouseRocketsPreparationTheme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if orientationFailed {
                        Text(copy("house_rockets_landscape_error"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(HouseRocketsPreparationTheme.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)

            if state.connection == .failed, state.canReconnect(at: .infinity) {
                TimelineView(.periodic(from: .now, by: 1)) { _ in
                    let now = ProcessInfo.processInfo.systemUptime
                    let remaining = max(0, Int(ceil((state.retryNotBefore ?? now) - now)))
                    Button(action: model.retryOnline) {
                        Label(copy(remaining > 0 ? "house_rockets_online_retry_after" : "house_rockets_online_retry",
                                   replacements: ["seconds": "\(remaining)"]), systemImage: "arrow.clockwise")
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(HouseRocketsPreparationTheme.surface)
                            .padding(.horizontal, AppDesign.Spacing.lg)
                            .frame(minHeight: AppDesign.Size.buttonHeightSmall)
                            .background(HouseRocketsPreparationTheme.accent,
                                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .disabled(!state.canReconnect(at: now))
                }
            }
        }
        .houseRocketsRoomCard()
    }

    private var statusSymbol: String {
        if state.connection == .failed { return "wifi.exclamationmark" }
        if state.isTerminal { return "flag.checkered" }
        return "dot.radiowaves.left.and.right"
    }

    // MARK: - 01 Launch

    /// The ready window's (then the countdown's) seconds, large; before the window opens,
    /// how many ready players start it.
    private var startCard: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HouseRocketsSectionHeader(code: "01", title: copy("house_rockets_online_start_title"))
            TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                let seconds = model.onlineCountdown()
                VStack(spacing: AppDesign.Spacing.xs) {
                    if let seconds {
                        Text(copy("house_rockets_online_start_until"))
                            .font(HouseRocketsRoomStyle.stencil)
                            .foregroundStyle(HouseRocketsPreparationTheme.muted)
                        HStack(alignment: .firstTextBaseline, spacing: AppDesign.Spacing.xs) {
                            Text(verbatim: "\(seconds)")
                                .font(.system(size: 88, weight: .black, design: .rounded))
                                .monospacedDigit()
                                .contentTransition(.numericText(countsDown: true))
                                .foregroundStyle(seconds <= 5 ? HouseRocketsPreparationTheme.danger
                                                 : HouseRocketsPreparationTheme.ink)
                            Text(copy("house_rockets_online_seconds_unit"))
                                .font(.title3.weight(.heavy))
                                .foregroundStyle(HouseRocketsPreparationTheme.muted)
                        }
                        .animation(.snappy, value: seconds)
                    } else {
                        Image(systemName: "hourglass")
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(HouseRocketsPreparationTheme.accent)
                        Text(copy("house_rockets_online_start_waiting"))
                            .font(.headline)
                            .foregroundStyle(HouseRocketsPreparationTheme.ink)
                        Text(copy("house_rockets_online_start_waiting_detail",
                                  replacements: ["minimum": "\(state.session?.rules.minimumPlayers ?? 2)"]))
                            .font(.caption)
                            .foregroundStyle(HouseRocketsPreparationTheme.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if state.session != nil {
                        Text(copy("house_rockets_ready_count",
                                  replacements: ["ready": "\(state.readyCount)", "total": "\(state.participants.count)"]))
                            .font(HouseRocketsRoomStyle.stencil)
                            .foregroundStyle(HouseRocketsPreparationTheme.accent)
                    }
                }
                .padding(AppDesign.Spacing.md)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .accessibilityElement(children: .combine)
            }
            .aspectRatio(872 / 400, contentMode: .fit)
            .frame(maxWidth: .infinity)
            .background(Color(HouseRocketsPalette.ice).opacity(0.35),
                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous)
                .stroke(HouseRocketsPreparationTheme.ink.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4, 4])))
            .houseRocketsRoomCard()
        }
    }

    // MARK: - 02 Rocket color

    /// Colors other players hold are taken, the selection is the color the server gives this
    /// player, and a ready player's color is locked until they take the ready back (Faus
    /// Switch's and Faus Tanks' rules, from Core).
    private var colorPicker: some View {
        let lobby = model.onlineLobbyColors
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HouseRocketsSectionHeader(code: "02", title: copy("house_rockets_online_color_title"))
            VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppDesign.Spacing.sm), count: 4),
                          spacing: AppDesign.Spacing.sm) {
                    ForEach(HouseRocketsColor.allCases) { color in swatch(color, lobby: lobby) }
                }
                if lobby.isLocked {
                    Label(copy("house_rockets_online_color_locked"), systemImage: "lock.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HouseRocketsPreparationTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)
                } else if lobby.isPreferredTaken(model.onlineColor) {
                    Label(copy("house_rockets_online_color_taken"), systemImage: "person.2.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(HouseRocketsPreparationTheme.danger)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(copy("house_rockets_online_color_note"))
                    .font(.caption)
                    .foregroundStyle(HouseRocketsPreparationTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .houseRocketsRoomCard()
        }
    }

    private func swatch(_ color: HouseRocketsColor, lobby: HouseRocketsLobbyColors) -> some View {
        let selected = model.onlineLocalColor == color
        let isTaken = lobby.isTakenByOthers(color)
        let tint = Color(HouseRocketsPalette.player(color))
        return Button { model.selectOnlineColor(color) } label: {
            VStack(spacing: AppDesign.Spacing.xs) {
                HouseRocketsColorRocket(color: color)
                    .frame(width: 46, height: 46)
                Text(HouseRocketsColorName.copy(color, appViewModel))
                    .font(.caption.weight(selected ? .bold : .semibold))
                    .foregroundStyle(Color(HouseRocketsPalette.cream).opacity(selected ? 1 : 0.8))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            .padding(.vertical, AppDesign.Spacing.sm)
            .padding(.horizontal, 2)
            .frame(maxWidth: .infinity)
            .background(Color(HouseRocketsPalette.navy),
                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous)
                    .stroke(selected ? tint : Color.clear, lineWidth: 2.5)
                    .padding(selected ? -3 : 0)
            }
            .overlay(alignment: .topTrailing) {
                if selected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(Color(HouseRocketsPalette.cream))
                        .padding(5)
                } else if isTaken {
                    Image(systemName: "person.fill")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color(HouseRocketsPalette.navy))
                        .padding(4)
                        .background(Color(HouseRocketsPalette.cream), in: Circle())
                        .padding(4)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isTaken || lobby.isLocked)
        .opacity(isTaken || (lobby.isLocked && !selected) ? 0.45 : 1)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(isTaken ? HouseRocketsColorName.copy(color, appViewModel) + ", " + copy("house_rockets_color_taken")
                            : HouseRocketsColorName.copy(color, appViewModel))
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }

    // MARK: - 03 Crew

    private var roster: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                HouseRocketsSectionHeader(code: "03", title: copy("house_rockets_online_roster"))
                Spacer(minLength: AppDesign.Spacing.sm)
                if state.session != nil {
                    Text(copy("house_rockets_ready_count",
                              replacements: ["ready": "\(state.readyCount)", "total": "\(state.participants.count)"]))
                        .font(HouseRocketsRoomStyle.stencil)
                        .foregroundStyle(HouseRocketsPreparationTheme.muted)
                }
            }
            VStack(spacing: AppDesign.Spacing.md) {
                if members.isEmpty {
                    Text(copy("house_rockets_online_syncing_roster"))
                        .font(.subheadline)
                        .foregroundStyle(HouseRocketsPreparationTheme.muted)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                ForEach(members) { member in
                    HStack(spacing: AppDesign.Spacing.sm) {
                        // The member's rocket in their color, like Faus Switch's robots.
                        Group {
                            if let color = member.color {
                                HouseRocketsColorRocket(color: color).frame(width: 26, height: 26)
                            } else {
                                Circle().fill(Color(HouseRocketsPalette.cream).opacity(0.3)).frame(width: 14, height: 14)
                            }
                        }
                        .frame(width: 34, height: 34)
                        .background(Color(HouseRocketsPalette.navy), in: Circle())
                        Text(verbatim: member.name)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HouseRocketsPreparationTheme.ink)
                            .lineLimit(1)
                        if member.isLocal, member.hasName {
                            Text(copy("house_rockets_you"))
                                .font(.caption)
                                .foregroundStyle(HouseRocketsPreparationTheme.muted)
                        }
                        Spacer(minLength: AppDesign.Spacing.sm)
                        Label(copy(HouseRocketsOnlineCopyKeys.playerStatus(member.state)),
                              systemImage: member.state == .ready ? "checkmark.circle.fill" : "clock")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(member.state == .ready ? HouseRocketsPreparationTheme.accent
                                             : HouseRocketsPreparationTheme.muted)
                    }
                    .accessibilityElement(children: .combine)
                }
                // Ready and the creator's cancel sit right under the crew while the room is a lobby.
                if state.isLobby, state.connection != .failed { actions }
            }
            .houseRocketsRoomCard()
        }
    }

    /// Ready (in the portrait room; the countdown turns the screen) and the creator's cancel.
    private var actions: some View {
        let isReady = state.localPlayer(localPlayerID)?.state == .ready
        let canChange = model.canChangeOnlineReady(playerID: localPlayerID)
        return VStack(spacing: AppDesign.Spacing.sm) {
            Button(action: onReady) {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Image(systemName: isReady ? "xmark.circle" : "checkmark.circle.fill")
                    Text(copy(isReady ? "house_rockets_not_ready_action" : "house_rockets_ready_action"))
                }
                .font(.headline)
                .foregroundStyle(HouseRocketsPreparationTheme.surface)
                .frame(maxWidth: .infinity, minHeight: AppDesign.Size.buttonHeightLarge)
                .background(isReady ? Color(HouseRocketsPalette.navy) : HouseRocketsPreparationTheme.accent,
                            in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canChange)
            .opacity(canChange ? 1 : 0.5)
            Text(copy("house_rockets_online_ready_detail"))
                .font(.caption)
                .foregroundStyle(HouseRocketsPreparationTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if state.canCancel(context: model.context) {
                Button(copy("house_rockets_cancel_flight"), role: .destructive, action: onCancel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HouseRocketsPreparationTheme.danger)
                    .frame(minHeight: 44)
            }
        }
        .padding(.top, AppDesign.Spacing.xs)
    }

    private struct Member: Identifiable {
        let id: String
        let name: String
        let hasName: Bool
        let isLocal: Bool
        let state: GameSessionPlayerState
        let color: HouseRocketsColor?
    }

    /// The session's players, the local one first, named from the house roster and colored
    /// from the lobby claims (the server's rockets once it seats them).
    private var members: [Member] {
        let all = state.participants.map { player -> Member in
            let isLocal = player.playerId == localPlayerID
            let name = memberNames[player.playerId]
            return Member(id: player.playerId,
                          name: name ?? copy(isLocal ? "house_rockets_you" : "house_rockets_member"),
                          hasName: name != nil, isLocal: isLocal, state: player.state,
                          color: model.onlineColor(of: player.playerId))
        }
        return all.filter(\.isLocal) + all.filter { !$0.isLocal }
    }

    private func copy(_ key: String, replacements: [String: String] = [:]) -> String {
        appViewModel.localized(key, replacements: replacements)
    }
}

/// The room's numbered section title ("01 / Launch countdown"), as in Faus Tanks.
struct HouseRocketsSectionHeader: View {
    let code: String?
    let title: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: AppDesign.Spacing.sm) {
            if let code {
                Text(verbatim: "\(code) /")
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    .foregroundStyle(HouseRocketsPreparationTheme.accent)
            }
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(HouseRocketsPreparationTheme.ink)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityAddTraits(.isHeader)
    }
}

enum HouseRocketsRoomStyle {
    static let stencil = Font.system(.caption, design: .monospaced).weight(.heavy)
}

enum HouseRocketsColorName {
    @MainActor
    static func copy(_ color: HouseRocketsColor, _ appViewModel: AppViewModel) -> String {
        appViewModel.localized("house_rockets_color_\(color.rawValue)", fallback: color.rawValue)
    }
}

extension View {
    /// The room's cream card on the light preparation backdrop.
    func houseRocketsRoomCard() -> some View {
        padding(AppDesign.Spacing.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HouseRocketsPreparationTheme.surface,
                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
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
            if HouseRocketsOnlineCopyKeys.showsConnectionPanel(state, presentation) {
                HouseRocketsOnlineConnectionView(state: state, onRetry: onRetry, onReclaimControl: onReclaimControl)
                    .frame(maxWidth: min(430, geometry.size.width - 48), maxHeight: geometry.size.height - 96)
                    .position(x: geometry.size.width / 2, y: geometry.size.height / 2)
            }
        }
    }

    private var statusKey: String { HouseRocketsOnlineCopyKeys.flightStatus(state, presentation) }

    private func copy(_ key: String) -> String { appViewModel.localized(key, fallback: key) }
}
