import FausCrewCore
import SwiftUI

/// Entry flow in portrait: pick demo or online, then the robot color and either the
/// bots (demo) or the house room (online). Orientation and the race stay with
/// `FausSwitchView`.
struct FausSwitchLobbyView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var model: FausSwitchViewModel
    let isLandscapeLayout: Bool
    let isWaitingForLandscape: Bool
    let orientationRequestFailed: Bool
    let onStartDemo: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 24) {
                    header
                    if let mode = model.selectedMode {
                        modeBar(mode)
                        if mode == .demo { demoSetup } else { onlineRoom }
                    } else {
                        VStack(spacing: AppDesign.Spacing.md) {
                            ForEach(FausSwitchMode.allCases) { modeCard($0) }
                        }
                    }
                    rules
                    if model.selectedMode == .demo || orientationRequestFailed {
                        Label(copy(orientationRequestFailed ? "faus_switch_landscape_error" : "faus_switch_landscape_detail"),
                              systemImage: "rectangle.landscape.rotate")
                            .font(.subheadline)
                            .foregroundStyle(orientationRequestFailed ? FausSwitchPalette.danger : FausSwitchPalette.secondaryInk)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.top, AppDesign.Spacing.lg)
                .padding(.bottom, AppDesign.Spacing.xxl)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }

            if model.selectedMode == .demo {
                bottomBar { startButton }
            } else if showsOnlineActionBar {
                bottomBar { onlineActions }
            }
        }
    }

    // MARK: - Header and modes

    private var header: some View {
        HStack(spacing: AppDesign.Spacing.lg) {
            FausSwitchRobot(color: model.robotColor)
                .frame(width: 64, height: 64)
                .frame(width: 86, height: 86)
                .background(FausSwitchPalette.cardFill, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous)
                    .stroke(FausSwitchPalette.lavender, lineWidth: 1.5))

            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                Text(copy("faus_switch_kicker"))
                    .font(.caption.weight(.heavy))
                    .tracking(1.4)
                    .foregroundStyle(FausSwitchPalette.accent)
                Text(copy("faus_switch_title"))
                    .font(.largeTitle.weight(.black))
                    .foregroundStyle(FausSwitchPalette.ink)
                Text(copy(subtitleKey))
                    .font(.subheadline)
                    .foregroundStyle(FausSwitchPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var subtitleKey: String {
        switch model.selectedMode {
        case .demo: "faus_switch_subtitle"
        case .online: "faus_switch_online_subtitle"
        case nil: "faus_switch_mode_prompt"
        }
    }

    private func modeCard(_ mode: FausSwitchMode) -> some View {
        let isDemo = mode == .demo
        return Button { model.selectMode(mode) } label: {
            HStack(spacing: AppDesign.Spacing.lg) {
                Image(systemName: isDemo ? "cpu" : "person.2.wave.2.fill")
                    .font(.title2.weight(.bold))
                    .foregroundStyle(isDemo ? FausSwitchPalette.plum : FausSwitchPalette.lightSand)
                    .frame(width: 54, height: 54)
                    .background(isDemo ? FausSwitchPalette.lavender : FausSwitchPalette.wine,
                                in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
                VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                    Text(copy(isDemo ? "faus_switch_mode_demo" : "faus_switch_mode_online"))
                        .font(.headline)
                        .foregroundStyle(FausSwitchPalette.ink)
                    Text(copy(isDemo ? "faus_switch_mode_demo_detail" : "faus_switch_mode_online_detail"))
                        .font(.subheadline)
                        .foregroundStyle(FausSwitchPalette.secondaryInk)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(FausSwitchPalette.accent)
            }
            .switchCard()
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func modeBar(_ mode: FausSwitchMode) -> some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            Label(copy(mode == .demo ? "faus_switch_mode_demo" : "faus_switch_mode_online"),
                  systemImage: mode == .demo ? "cpu" : "person.2.wave.2.fill")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(FausSwitchPalette.ink)
            Spacer(minLength: 0)
            Button(copy("faus_switch_mode_change"), action: model.returnToModeSelection)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FausSwitchPalette.accent)
                .frame(minHeight: 44)
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .background(FausSwitchPalette.cardFill, in: Capsule())
        .overlay(Capsule().stroke(FausSwitchPalette.panelStroke, lineWidth: 1))
    }

    // MARK: - Robot color

    private func colorPicker(footnoteKey: String?) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            sectionTitle("faus_switch_color_title")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: AppDesign.Spacing.sm), count: 4),
                      spacing: AppDesign.Spacing.sm) {
                ForEach(FausSwitchColor.allCases) { color in
                    let isSelected = model.robotColor == color
                    Button { model.robotColor = color } label: {
                        VStack(spacing: 4) {
                            FausSwitchRobot(color: color)
                                .frame(width: 44, height: 44)
                            Text(copy(color.titleKey))
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(FausSwitchPalette.ink)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity, minHeight: 74)
                        .background(isSelected ? FausSwitchPalette.lavender.opacity(0.6) : FausSwitchPalette.lightSand.opacity(0.75),
                                    in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous)
                            .stroke(isSelected ? FausSwitchPalette.deepWine : FausSwitchPalette.panelStroke,
                                    lineWidth: isSelected ? 2 : 1))
                    }
                    .buttonStyle(ScaleButtonStyle())
                    .accessibilityLabel(copy(color.titleKey))
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            }
            if let footnoteKey {
                Text(copy(footnoteKey))
                    .font(.caption)
                    .foregroundStyle(FausSwitchPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .switchCard()
    }

    // MARK: - Demo

    private var demoSetup: some View {
        VStack(alignment: .leading, spacing: 24) {
            colorPicker(footnoteKey: nil)

            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                sectionTitle("faus_switch_bots_title")
                Picker(copy("faus_switch_bots_title"), selection: $model.botCount) {
                    ForEach(Array(FausSwitchMatchConfiguration.botRange), id: \.self) { count in
                        Text(verbatim: "\(count)").tag(count)
                    }
                }
                .pickerStyle(.segmented)
                VStack(spacing: AppDesign.Spacing.sm) {
                    rosterRow(name: copy("faus_switch_you"), color: model.robotColor, trailing: nil)
                    ForEach(Array(model.demoBotColors.enumerated()), id: \.offset) { index, color in
                        rosterRow(name: copy(FausSwitchBotMatch.botNameKeys[index % FausSwitchBotMatch.botNameKeys.count]),
                                  color: color, trailing: copy("faus_switch_bot_role"))
                    }
                }
                if let best = model.bestTime {
                    Label(copy("faus_switch_best_time", replacements: ["time": String(format: "%.1f", best)]),
                          systemImage: "trophy.fill")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FausSwitchPalette.green)
                }
            }
            .switchCard()
        }
    }

    private func rosterRow(name: String, color: FausSwitchColor?, trailing: String?,
                           trailingSymbol: String? = nil, highlightsTrailing: Bool = false) -> some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            if let color {
                FausSwitchRobot(color: color).frame(width: 28, height: 28)
            } else {
                Circle().fill(FausSwitchPalette.lavender.opacity(0.45)).frame(width: 22, height: 22).frame(width: 28)
            }
            Text(verbatim: name)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(FausSwitchPalette.ink)
                .lineLimit(1)
            Spacer(minLength: AppDesign.Spacing.sm)
            if let trailing {
                Label {
                    Text(trailing)
                } icon: {
                    if let trailingSymbol { Image(systemName: trailingSymbol) }
                }
                .font(.caption.weight(.bold))
                .foregroundStyle(highlightsTrailing ? FausSwitchPalette.green : FausSwitchPalette.secondaryInk)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private var startButton: some View {
        Button(action: onStartDemo) {
            HStack(spacing: AppDesign.Spacing.sm) {
                if isWaitingForLandscape {
                    ProgressView().tint(FausSwitchPalette.lightSand)
                    Text(copy("faus_switch_rotating"))
                } else {
                    Image(systemName: isLandscapeLayout ? "arrow.up.arrow.down" : "rectangle.landscape.rotate")
                    Text(copy(isLandscapeLayout ? "faus_switch_start" : "faus_switch_start_landscape"))
                }
            }
            .primarySwitchButton()
        }
        .buttonStyle(ScaleButtonStyle())
        .disabled(isWaitingForLandscape)
    }

    // MARK: - Online

    @ViewBuilder
    private var onlineRoom: some View {
        if let blocker = onlineBlockerKey {
            notice(title: "faus_switch_online_unavailable", detail: blocker, symbol: "wifi.exclamationmark")
        } else if model.onlineCatalog == .unavailable {
            notice(title: "faus_switch_online_closed", detail: "faus_switch_online_closed_detail", symbol: "lock.fill")
        } else {
            VStack(alignment: .leading, spacing: 24) {
                onlineStatus
                colorPicker(footnoteKey: "faus_switch_online_color_note")
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

    private var roomContext: GameLaunchContext? {
        guard let userID = appViewModel.currentUserId, let house = appViewModel.currentHouseDetails else { return nil }
        return GameLaunchContext(houseID: house.id, localPlayerID: userID, houseOwnerID: house.ownerId)
    }

    private var onlineBlockerKey: String? {
        guard let userID = appViewModel.currentUserId, !userID.isEmpty else { return "faus_switch_online_sign_in" }
        guard appViewModel.currentHouseDetails != nil else { return "faus_switch_online_house_required" }
        guard model.isOnlineServiceAvailable else { return "faus_switch_online_soon_detail" }
        return nil
    }

    private func notice(title: String, detail: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Label(copy(title), systemImage: symbol)
                .font(.headline)
                .foregroundStyle(FausSwitchPalette.ink)
            Text(copy(detail))
                .font(.subheadline)
                .foregroundStyle(FausSwitchPalette.secondaryInk)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .switchCard()
    }

    private var onlineStatus: some View {
        let state = model.onlineState
        let warns = state.requiresUpdate || state.connection == .failed
        let minimum = state.session?.rules.minimumPlayers ?? 2
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(alignment: .top, spacing: AppDesign.Spacing.md) {
                Group {
                    if FausSwitchOnlineCopyKeys.showsProgress(state) {
                        ProgressView().tint(FausSwitchPalette.wine)
                    } else {
                        Image(systemName: warns ? "wifi.exclamationmark" : "dot.radiowaves.left.and.right")
                            .foregroundStyle(warns ? FausSwitchPalette.danger : FausSwitchPalette.green)
                    }
                }
                .font(.title3.weight(.bold))
                .frame(width: 28, height: 28)

                VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                    Text(copy(model.isOnlineRematchRoom ? "faus_switch_online_rematch_room"
                                                        : FausSwitchOnlineCopyKeys.roomStatus(state)))
                        .font(.headline)
                        .foregroundStyle(warns ? FausSwitchPalette.danger : FausSwitchPalette.ink)
                    Text(copy(FausSwitchOnlineCopyKeys.roomDetail(state), replacements: ["minimum": "\(minimum)"]))
                        .font(.subheadline)
                        .foregroundStyle(FausSwitchPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    if state.connection == .connected, let issue = state.issue {
                        Text(copy(FausSwitchOnlineCopyKeys.issue(issue)))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(FausSwitchPalette.danger)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                Spacer(minLength: 0)
                countdownBadge
            }
            .accessibilityElement(children: .combine)

            if state.connection == .failed, state.canReconnect(at: .infinity) {
                Button(action: model.retryOnline) {
                    Label(copy("faus_switch_online_retry"), systemImage: "arrow.clockwise")
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(FausSwitchPalette.lightSand)
                        .padding(.horizontal, AppDesign.Spacing.lg)
                        .frame(minHeight: 44)
                        .background(FausSwitchPalette.wine,
                                    in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
                }
                .buttonStyle(ScaleButtonStyle())
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .switchCard()
    }

    /// The ready window or start countdown, from the server's deadline.
    private var countdownBadge: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let phase = model.onlineState.session?.state
            if phase == .readyWindow || phase == .countdown, let seconds = model.onlineCountdown() {
                Text(verbatim: "\(seconds)")
                    .font(.system(size: 30, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(seconds <= 5 ? FausSwitchPalette.danger : FausSwitchPalette.ink)
                    .frame(minWidth: 52, minHeight: 52)
                    .background(FausSwitchPalette.lavender, in: Circle())
                    .accessibilityLabel(copy("faus_switch_online_seconds", replacements: ["seconds": "\(seconds)"]))
            }
        }
    }

    private var onlineRoster: some View {
        let state = model.onlineState
        let localID = appViewModel.currentUserId
        let names = Dictionary((appViewModel.currentHouseDetails?.members ?? []).map { ($0.id, $0.fullName) },
                               uniquingKeysWith: { first, _ in first })
        let players = state.participants.sorted { lhs, rhs in
            (lhs.playerId == localID ? 0 : 1) < (rhs.playerId == localID ? 0 : 1)
        }
        return VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(alignment: .firstTextBaseline) {
                sectionTitle("faus_switch_online_roster")
                Spacer(minLength: AppDesign.Spacing.sm)
                if state.session != nil {
                    Text(copy("faus_switch_online_ready_count",
                              replacements: ["ready": "\(state.readyCount)", "total": "\(state.participants.count)"]))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(FausSwitchPalette.secondaryInk)
                }
            }
            if players.isEmpty {
                Text(copy("faus_switch_online_syncing"))
                    .font(.subheadline)
                    .foregroundStyle(FausSwitchPalette.secondaryInk)
            }
            ForEach(players, id: \.playerId) { player in
                let isLocal = player.playerId == localID
                rosterRow(name: (names[player.playerId] ?? copy("faus_switch_online_player"))
                                + (isLocal ? " · " + copy("faus_switch_you") : ""),
                          color: isLocal ? model.robotColor : nil,
                          trailing: copy(FausSwitchOnlineCopyKeys.playerStatus(player.state)),
                          trailingSymbol: player.state == .ready ? "checkmark.seal.fill" : "clock",
                          highlightsTrailing: player.state == .ready)
            }
        }
        .switchCard()
    }

    private var showsOnlineActionBar: Bool {
        model.selectedMode == .online && onlineBlockerKey == nil && model.onlineCatalog != .unavailable
            && model.onlineState.session != nil && model.onlineState.isLobby && !model.onlineState.isTerminal
    }

    private var onlineActions: some View {
        let state = model.onlineState
        let localID = appViewModel.currentUserId
        let isReady = state.localPlayer(localID)?.state == .ready
        let canChange = state.canChangeReady(playerID: localID)
        return VStack(spacing: AppDesign.Spacing.sm) {
            Button { model.setOnlineReady(!isReady) } label: {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Image(systemName: isReady ? "xmark.circle" : "checkmark.circle.fill")
                    Text(copy(isReady ? "faus_switch_online_not_ready" : "faus_switch_online_ready"))
                }
                .primarySwitchButton(fill: isReady ? FausSwitchPalette.plum : FausSwitchPalette.wine)
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(!canChange)
            .opacity(canChange ? 1 : 0.5)

            if model.canCancelOnline(context: roomContext) {
                Button(copy("faus_switch_online_cancel"), role: .destructive, action: model.cancelOnlineMatch)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FausSwitchPalette.danger)
                    .frame(minHeight: 44)
            }
        }
    }

    // MARK: - Rules

    /// Each rule is a tiny looping clip with a few words under it; the full sentence is
    /// kept for VoiceOver.
    private var rules: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            sectionTitle("faus_switch_rules_title")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: AppDesign.Spacing.md, alignment: .top),
                                GridItem(.flexible(), spacing: AppDesign.Spacing.md, alignment: .top)],
                      alignment: .leading, spacing: AppDesign.Spacing.md) {
                rule(.tap, "faus_switch_rule_tap_title", "faus_switch_rule_tap_detail")
                rule(.solid, "faus_switch_rule_solid_title", "faus_switch_rule_solid_detail")
                rule(.robots, "faus_switch_rule_robots_title", "faus_switch_rule_robots_detail")
                rule(.gap, "faus_switch_rule_gap_title", "faus_switch_rule_gap_detail")
                rule(.boost, "faus_switch_rule_boost_title", "faus_switch_rule_boost_detail")
                rule(.slow, "faus_switch_rule_slow_title", "faus_switch_rule_slow_detail")
                rule(.portal, "faus_switch_rule_portal_title", "faus_switch_rule_portal_detail")
            }
        }
        .switchCard()
    }

    private func rule(_ clip: FausSwitchRuleClipKind, _ title: String, _ detail: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            FausSwitchRuleClip(kind: clip, playerColor: model.robotColor)
            Text(copy(title))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(FausSwitchPalette.ink)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copy(title))
        .accessibilityHint(copy(detail))
    }

    // MARK: - Pieces

    private func bottomBar<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        content()
            .padding(.horizontal, AppDesign.Spacing.xl)
            .padding(.vertical, AppDesign.Spacing.lg)
            .frame(maxWidth: 620)
            .frame(maxWidth: .infinity)
            .background(FausSwitchPalette.lightSand.opacity(0.96))
            .overlay(alignment: .top) { FausSwitchPalette.wine.opacity(0.2).frame(height: 1) }
    }

    private func sectionTitle(_ key: String) -> some View {
        Text(copy(key))
            .font(.caption.weight(.heavy))
            .tracking(1.2)
            .textCase(.uppercase)
            .foregroundStyle(FausSwitchPalette.accent)
            .accessibilityAddTraits(.isHeader)
    }

    private func copy(_ key: String) -> String {
        appViewModel.localized(key, fallback: key)
    }

    private func copy(_ key: String, replacements: [String: String]) -> String {
        replacements.reduce(copy(key)) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
    }
}

extension View {
    /// The sand panel every Faus Switch section sits on (light sand fading to sand).
    func switchCard() -> some View {
        padding(AppDesign.Spacing.lg)
            .background(FausSwitchPalette.cardFill, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous)
                .stroke(FausSwitchPalette.panelStroke, lineWidth: 1))
    }

    func primarySwitchButton(fill: Color = FausSwitchPalette.wine,
                             height: CGFloat = AppDesign.Size.buttonHeightLarge) -> some View {
        font(.headline)
            .foregroundStyle(FausSwitchPalette.lightSand)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(fill, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
    }
}
