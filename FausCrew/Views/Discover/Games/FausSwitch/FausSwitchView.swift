import FausCrewCore
import SpriteKit
import SwiftUI

struct FausSwitchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var model: FausSwitchViewModel
    @AccessibilityFocusState private var isPanelActionFocused: Bool
    @State private var isLandscapeLayout = false
    @State private var isWaitingForLandscape = false
    @State private var orientationRequestFailed = false
    @State private var showsTapHint = true
    @State private var confirmsLeave = false

    init(onlineFactory: FausSwitchOnlineFactory = .unavailable) {
        _model = StateObject(wrappedValue: FausSwitchViewModel(onlineFactory: onlineFactory))
    }

    private var isRaceVisible: Bool { model.isDemoVisible || model.isOnlineMatchVisible }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if isRaceVisible {
                    raceLayer
                } else {
                    FausSwitchTextureBackdrop()
                        .ignoresSafeArea()
                    FausSwitchLobbyView(
                        model: model,
                        isLandscapeLayout: isLandscapeLayout,
                        isWaitingForLandscape: isWaitingForLandscape,
                        orientationRequestFailed: orientationRequestFailed,
                        onStartDemo: prepareDemo
                    )
                }
            }
            .onAppear { handleViewportSize(geometry.size) }
            .onChange(of: geometry.size) { _, size in handleViewportSize(size) }
        }
        .environment(\.colorScheme, .light)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(isRaceVisible ? .hidden : .visible, for: .navigationBar)
        .onAppear { model.setReduceMotion(reduceMotion) }
        .onChange(of: reduceMotion) { _, enabled in model.setReduceMotion(enabled) }
        .onChange(of: scenePhase) { _, phase in
            model.setOnlineForeground(phase == .active)
            if phase != .active { model.pauseDemo() }
            model.setAppActive(phase == .active)
        }
        .onChange(of: model.isOnlineMatchVisible) { _, visible in
            // The room is portrait; the race countdown turns the screen.
            if visible {
                showsTapHint = true
                GameOrientationController.lockToLandscape { orientationRequestFailed = true }
            } else if !model.isDemoVisible {
                GameOrientationController.returnToPortrait()
            }
        }
        .onChange(of: appViewModel.currentHouseDetails?.id) { _, houseID in
            model.onlineIdentityChanged(houseID: houseID, userID: appViewModel.currentUserId)
        }
        .onChange(of: appViewModel.currentUserId) { _, userID in
            model.onlineIdentityChanged(houseID: appViewModel.currentHouseDetails?.id, userID: userID)
        }
        .onChange(of: appViewModel.isAuthenticated) { _, authenticated in
            if !authenticated { model.stop(); GameOrientationController.returnToPortrait() }
        }
        .onChange(of: model.requiresOnlineSignIn) { _, required in
            if required { model.stop(); appViewModel.logout(); GameOrientationController.returnToPortrait() }
        }
        .onDisappear {
            model.stop()
            GameOrientationController.returnToPortrait()
        }
        .confirmationDialog(copy("faus_switch_online_leave_title"), isPresented: $confirmsLeave, titleVisibility: .visible) {
            Button(copy("faus_switch_online_leave"), role: .destructive, action: leaveOnlineRace)
        } message: {
            Text(copy("faus_switch_online_leave_detail"))
        }
    }

    // MARK: - Race

    @ViewBuilder
    private var raceLayer: some View {
        SpriteView(scene: model.scene, preferredFramesPerSecond: 60)
            .ignoresSafeArea()
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(copy("faus_switch_playfield_accessibility"))
            .accessibilityHint(copy("faus_switch_playfield_hint"))
            .accessibilityAction { model.flip() }

        if let match = model.match {
            if !match.nameTags.isEmpty { nameTags(match.nameTags) }
            hud(match)
            if match.phase == .countdown, let count = match.countdown {
                countdown(count)
            }
            if model.isOnlineReplayRoom {
                replayRoomPanel
            } else if model.isOnlineMatchVisible {
                onlineOverlays(match)
            } else {
                demoOverlays(match)
            }
        }
    }

    private func hud(_ match: FausSwitchMatchUI) -> some View {
        VStack(spacing: 0) {
            HStack(alignment: .top, spacing: AppDesign.Spacing.sm) {
                if model.isOnlineMatchVisible {
                    let hidesLeave = match.showsResult || model.isOnlineReplayRoom
                    hudButton("xmark", label: "faus_switch_online_leave") { confirmsLeave = true }
                        .disabled(hidesLeave)
                        .opacity(hidesLeave ? 0 : 1)
                } else {
                    hudButton("pause.fill", label: "faus_switch_pause", action: model.pauseDemo)
                        .disabled(match.phase == .ended || model.showsDemoResult)
                }
                Spacer(minLength: 0)
                hudButton(model.isMusicEnabled ? "music.note" : "music.note.slash",
                          label: model.isMusicEnabled ? "faus_switch_music_off" : "faus_switch_music_on",
                          action: model.toggleMusic)
                hudButton(model.isSoundEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill",
                          label: model.isSoundEnabled ? "faus_switch_sound_off" : "faus_switch_sound_on",
                          action: model.toggleSound)
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.top, AppDesign.Spacing.sm)

            Spacer()

            if match.phase == .playing, match.canFlip, showsTapHint {
                Label(copy("faus_switch_tap_hint"), systemImage: "hand.tap.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(FausSwitchPalette.ink)
                    .padding(.horizontal, AppDesign.Spacing.lg)
                    .frame(minHeight: 40)
                    .background(FausSwitchPalette.panel, in: Capsule())
                    .allowsHitTesting(false)
                    .padding(.bottom, AppDesign.Spacing.xl)
                    .task {
                        try? await Task.sleep(nanoseconds: 3_500_000_000)
                        withAnimation(.easeOut(duration: 0.2)) { showsTapHint = false }
                    }
            }
        }
    }

    private func hudButton(_ symbol: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.body.weight(.black))
                .foregroundStyle(FausSwitchPalette.lightSand)
                .frame(width: 44, height: 44)
                .background(FausSwitchPalette.deepWine.opacity(0.92),
                            in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
        }
        .accessibilityLabel(copy(label))
    }

    /// Each robot's player name beside it on its start platform, until the run starts.
    /// The scene fills the whole screen, so the same camera maps the course to the screen.
    private func nameTags(_ tags: [FausSwitchNameTag]) -> some View {
        GeometryReader { geometry in
            let viewport = FausSwitchViewport(screenWidth: geometry.size.width, screenHeight: geometry.size.height)
            let track = FausSwitchCourse.standard.track
            let width: CGFloat = 150
            ForEach(tags) { tag in
                let point = tag.anchor(track: track, viewport: viewport)
                let leading = point.x
                let centerY = geometry.size.height - point.y
                Text(verbatim: name(of: tag))
                    .font(.caption.weight(.heavy))
                    .foregroundStyle(tag.isLocal ? FausSwitchPalette.ink : FausSwitchPalette.mint)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 22)
                    .background(tag.isLocal ? FausSwitchPalette.lavender : tag.color.color.opacity(0.92), in: Capsule())
                    .frame(width: width, alignment: .leading)
                    .position(x: CGFloat(leading) + width / 2, y: CGFloat(centerY))
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .transition(.opacity)
    }

    private func countdown(_ value: Int) -> some View {
        Text(verbatim: "\(value)")
            .font(.system(size: 92, weight: .black, design: .rounded))
            .monospacedDigit()
            .foregroundStyle(FausSwitchPalette.lightSand)
            .frame(width: 150, height: 150)
            .background(FausSwitchPalette.plum.opacity(0.82), in: Circle())
            .contentTransition(.numericText(countsDown: true))
            .animation(.snappy, value: value)
            // Off to the right, so the robots and their name tags on the start line stay visible.
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .trailing)
            .padding(.trailing, 56)
            .allowsHitTesting(false)
            .accessibilityLabel(copy("faus_switch_online_seconds", replacements: ["seconds": "\(value)"]))
    }

    // MARK: - Demo panels

    @ViewBuilder
    private func demoOverlays(_ match: FausSwitchMatchUI) -> some View {
        if model.isPaused {
            panel {
                panelHeader(symbol: "pause.fill", tint: FausSwitchPalette.wine,
                            title: copy("faus_switch_paused"), detail: copy("faus_switch_paused_detail"))
            } actions: {
                panelButton("faus_switch_resume", symbol: "play.fill", action: model.resumeDemo)
                    .accessibilityFocused($isPanelActionFocused)
                secondaryButton("faus_switch_restart", action: restartDemo)
                secondaryButton("faus_switch_change_setup", action: exitDemoToSetup)
            }
        } else if model.showsDemoResult {
            panel {
                demoResultHeader(match)
                standingsTable(match.standings)
            } actions: {
                panelButton("faus_switch_restart", symbol: "arrow.clockwise", action: restartDemo)
                    .accessibilityFocused($isPanelActionFocused)
                if match.phase != .ended {
                    secondaryButton("faus_switch_watch", action: model.watchDemo)
                }
                secondaryButton("faus_switch_change_setup", action: exitDemoToSetup)
                secondaryButton("faus_switch_exit") {
                    model.stop()
                    dismiss()
                }
            }
        }
    }

    private func demoResultHeader(_ match: FausSwitchMatchUI) -> some View {
        let keys = match.demoResultKeys
        let symbol: String
        let tint: Color
        switch match.demoOutcome {
        case .won, .finished: (symbol, tint) = ("flag.checkered", FausSwitchPalette.green)
        case .crashed: (symbol, tint) = ("exclamationmark.triangle.fill", FausSwitchPalette.berry)
        case .timeUp: (symbol, tint) = ("timer", FausSwitchPalette.deepWine)
        }
        return panelHeader(symbol: symbol, tint: tint, title: copy(keys.title),
                           detail: copy(keys.detail, replacements: [
                               "rank": "\(match.localRank ?? 0)",
                               "time": String(format: "%.1f", match.localTime ?? 0),
                           ]))
    }

    // MARK: - Online panels

    @ViewBuilder
    private func onlineOverlays(_ match: FausSwitchMatchUI) -> some View {
        if match.showsResult {
            onlineResultPanel
        } else if let title = match.noticeTitleKey, let detail = match.noticeDetailKey {
            VStack {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                    Label(copy(title), systemImage: match.noticeIsBlocking ? "wifi.exclamationmark" : "arrow.triangle.2.circlepath")
                        .font(.headline)
                        .foregroundStyle(FausSwitchPalette.ink)
                    Text(copy(detail))
                        .font(.subheadline)
                        .foregroundStyle(FausSwitchPalette.secondaryInk)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: AppDesign.Spacing.sm) {
                        if match.canRetry {
                            smallButton("faus_switch_online_retry", action: model.retryOnline)
                        }
                        if match.canReclaim {
                            smallButton("faus_switch_online_reclaim", action: model.reclaimOnlineControl)
                        }
                        if match.noticeIsBlocking {
                            smallButton("faus_switch_online_leave", action: leaveOnlineRace)
                        }
                    }
                }
                .frame(maxWidth: 420, alignment: .leading)
                .switchCard()
                .padding(.top, 64)
                Spacer()
            }
        } else if case .crashed(let reason) = match.localStatus {
            VStack {
                Spacer()
                HStack(spacing: AppDesign.Spacing.md) {
                    Image(systemName: "eye.fill")
                        .foregroundStyle(FausSwitchPalette.berry)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(copy(FausSwitchOnlineCopyKeys.crashReason(reason)))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(FausSwitchPalette.ink)
                        Text(copy("faus_switch_online_spectating"))
                            .font(.caption)
                            .foregroundStyle(FausSwitchPalette.secondaryInk)
                    }
                    smallButton("faus_switch_online_leave", action: leaveOnlineRace)
                }
                .switchCard()
                .padding(.bottom, AppDesign.Spacing.lg)
            }
        }
    }

    private var onlineResultPanel: some View {
        let state = model.onlineResult
        let localID = appViewModel.currentUserId
        let title: String
        switch FausSwitchOnlineCopyKeys.resultTitle(state, localPlayerID: localID) {
        case .key(let key): title = copy(key)
        case .lost(let winner):
            title = copy("faus_switch_online_lost",
                         replacements: ["name": state.identities[winner]?.displayName ?? copy("faus_switch_online_player")])
        }
        let isWaiting = state.phase == .waiting || state.phase == .idle
        return panel {
            panelHeader(symbol: isWaiting ? "hourglass" : "flag.checkered",
                        tint: state.phase == .failed ? FausSwitchPalette.berry : FausSwitchPalette.green,
                        title: title, detail: copy(FausSwitchOnlineCopyKeys.resultDetail(state)))
            if isWaiting { ProgressView().tint(FausSwitchPalette.wine).frame(maxWidth: .infinity) }
            standingsTable(onlineResultStandings)
        } actions: {
            // Play Again stays on this screen with the room; Back to Lobby is the portrait room.
            if state.canRematch {
                panelButton("faus_switch_online_play_again", symbol: "arrow.clockwise", action: model.playOnlineAgain)
                    .accessibilityFocused($isPanelActionFocused)
                secondaryButton("faus_switch_online_back_to_lobby", action: model.returnToOnlineLobby)
            } else {
                if state.phase == .failed, state.canRetry(at: ProcessInfo.processInfo.systemUptime) {
                    panelButton("faus_switch_online_retry", symbol: "arrow.clockwise", action: model.retryOnlineResult)
                }
                secondaryButton("faus_switch_online_back_to_modes", action: leaveOnlineRace)
            }
        }
    }

    /// Play Again's new room over the finished race's frozen last frame, until the new race's
    /// countdown: who is in and ready (the player is made ready on joining), the room's
    /// deadline, the ready toggle and Back to Lobby.
    private var replayRoomPanel: some View {
        let state = model.onlineState
        let localID = appViewModel.currentUserId
        let isReady = state.localPlayer(localID)?.state == .ready
        let inRoom = state.isLobby && state.connection == .connected && state.isSynced
        let detail = inRoom ? (isReady ? "faus_switch_online_replay_detail" : "faus_switch_online_replay_not_ready")
            : FausSwitchOnlineCopyKeys.roomDetail(state)
        let names = Dictionary((appViewModel.currentHouseDetails?.members ?? []).map { ($0.id, $0.fullName) },
                               uniquingKeysWith: { first, _ in first })
        let colors = model.onlineLobbyColors
        let players = state.participants.sorted { ($0.playerId == localID ? 0 : 1) < ($1.playerId == localID ? 0 : 1) }
        return panel {
            panelHeader(symbol: "arrow.clockwise", tint: FausSwitchPalette.wine,
                        title: copy("faus_switch_online_replay_title"),
                        detail: copy(detail, replacements: ["minimum": "\(state.session?.rules.minimumPlayers ?? 2)"]))
            HStack(spacing: AppDesign.Spacing.sm) {
                Text(copy(FausSwitchOnlineCopyKeys.roomStatus(state)))
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(state.connection == .failed ? FausSwitchPalette.danger : FausSwitchPalette.ink)
                Spacer(minLength: 0)
                TimelineView(.periodic(from: .now, by: 0.25)) { _ in
                    if let seconds = model.onlineCountdown() {
                        Label(copy("faus_switch_online_seconds", replacements: ["seconds": "\(seconds)"]), systemImage: "timer")
                            .font(.caption.weight(.heavy).monospacedDigit())
                            .foregroundStyle(FausSwitchPalette.ink)
                    }
                }
                if state.session != nil {
                    Text(copy("faus_switch_online_ready_count",
                              replacements: ["ready": "\(state.readyCount)", "total": "\(state.participants.count)"]))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(FausSwitchPalette.secondaryInk)
                }
            }
            let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: players.count > 4 ? 2 : 1)
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(players, id: \.playerId) { player in
                    let isLocal = player.playerId == localID
                    let ready = player.state == .ready
                    HStack(spacing: AppDesign.Spacing.sm) {
                        FausSwitchRobot(color: (isLocal ? model.onlineLocalColor : colors.color(of: player.playerId)) ?? .ocean)
                            .frame(width: 22, height: 22)
                        Text(verbatim: isLocal ? copy("faus_switch_you") : (names[player.playerId] ?? copy("faus_switch_online_player")))
                            .font(.subheadline.weight(isLocal ? .bold : .semibold))
                            .foregroundStyle(FausSwitchPalette.ink)
                            .lineLimit(1)
                        Spacer(minLength: 0)
                        Image(systemName: ready ? "checkmark.seal.fill" : "clock")
                            .foregroundStyle(ready ? FausSwitchPalette.green : FausSwitchPalette.secondaryInk)
                            .accessibilityLabel(copy(FausSwitchOnlineCopyKeys.playerStatus(player.state)))
                    }
                    .padding(.horizontal, AppDesign.Spacing.sm)
                    .frame(minHeight: 32)
                    .background(isLocal ? FausSwitchPalette.lavender.opacity(0.55) : FausSwitchPalette.lightSand.opacity(0.8),
                                in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
                    .accessibilityElement(children: .combine)
                }
            }
        } actions: {
            if state.connection == .failed, state.canReconnect(at: .infinity) {
                panelButton("faus_switch_online_retry", symbol: "arrow.clockwise", action: model.retryOnline)
            } else {
                panelButton(isReady ? "faus_switch_online_not_ready" : "faus_switch_online_ready",
                            symbol: isReady ? "xmark.circle" : "checkmark.circle.fill") { model.setOnlineReady(!isReady) }
                    .disabled(!model.canChangeOnlineReady(playerID: localID))
                    .opacity(model.canChangeOnlineReady(playerID: localID) ? 1 : 0.5)
                    .accessibilityFocused($isPanelActionFocused)
            }
            secondaryButton("faus_switch_online_back_to_lobby", action: model.returnToOnlineLobby)
                .disabled(state.isLeaving)
        }
    }

    /// The persisted ranks once available; the race's last frame until then.
    private var onlineResultStandings: [FausSwitchStanding] {
        FausSwitchMatchUI.resultStandings(model.onlineResult, live: model.lastOnlineStandings,
                                          localPlayerID: appViewModel.currentUserId)
    }

    // MARK: - Panel pieces

    /// A race panel laid out for the landscape screen: what happened on the left, every
    /// action on the right, so the whole panel fits the screen height without scrolling.
    /// Only very large text sizes, which cannot fit, fall back to a scrolling panel.
    private func panel<Info: View, Actions: View>(
        @ViewBuilder _ info: @escaping () -> Info,
        @ViewBuilder actions: @escaping () -> Actions
    ) -> some View {
        ZStack {
            FausSwitchPalette.plum.opacity(0.38)
                .ignoresSafeArea()
            ViewThatFits(in: .vertical) {
                panelCard(info, actions: actions)
                ScrollView(showsIndicators: false) {
                    panelCard(info, actions: actions)
                }
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.vertical, AppDesign.Spacing.sm)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func panelCard<Info: View, Actions: View>(
        _ info: () -> Info,
        actions: () -> Actions
    ) -> some View {
        HStack(alignment: .center, spacing: AppDesign.Spacing.xl) {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                info()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            VStack(spacing: AppDesign.Spacing.xs) {
                actions()
            }
            .frame(width: 210)
        }
        .padding(AppDesign.Spacing.lg)
        .frame(maxWidth: 660)
        .background(FausSwitchPalette.cardFill, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous)
            .stroke(FausSwitchPalette.wine.opacity(0.3), lineWidth: 1))
        .onAppear { isPanelActionFocused = true }
        .onDisappear { isPanelActionFocused = false }
    }

    private func panelHeader(symbol: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: AppDesign.Spacing.md) {
            Image(systemName: symbol)
                .font(.title3.weight(.bold))
                .foregroundStyle(FausSwitchPalette.lightSand)
                .frame(width: 44, height: 44)
                .background(tint, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                Text(title)
                    .font(.title3.weight(.black))
                    .foregroundStyle(FausSwitchPalette.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(FausSwitchPalette.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    /// Up to four robots in one column; more in two, so eight robots take four rows.
    private func standingsTable(_ standings: [FausSwitchStanding]) -> some View {
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: standings.count > 4 ? 2 : 1)
        return LazyVGrid(columns: columns, spacing: 4) {
            ForEach(standings) { standing in
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(verbatim: standing.rank.map { "\($0)." } ?? "–")
                        .font(.subheadline.weight(.black).monospacedDigit())
                        .foregroundStyle(FausSwitchPalette.ink)
                        .frame(width: 24, alignment: .leading)
                    FausSwitchRobot(color: standing.color).frame(width: 22, height: 22)
                    Text(verbatim: name(of: standing))
                        .font(.subheadline.weight(standing.isLocal ? .bold : .semibold))
                        .foregroundStyle(FausSwitchPalette.ink)
                        .lineLimit(1)
                        .layoutPriority(1)
                    Spacer(minLength: AppDesign.Spacing.xs)
                    Text(statusLine(standing))
                        .font(.caption.weight(.bold).monospacedDigit())
                        .foregroundStyle(isOut(standing) ? FausSwitchPalette.berry : FausSwitchPalette.green)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, AppDesign.Spacing.sm)
                .frame(minHeight: 32)
                .background(standing.isLocal ? FausSwitchPalette.lavender.opacity(0.55) : FausSwitchPalette.lightSand.opacity(0.8),
                            in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
                .accessibilityElement(children: .combine)
            }
        }
    }

    private func panelButton(_ key: String, symbol: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(copy(key), systemImage: symbol).primarySwitchButton(height: 48)
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func secondaryButton(_ key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(copy(key))
                .font(.body.weight(.semibold))
                .foregroundStyle(FausSwitchPalette.accent)
                .frame(maxWidth: .infinity, minHeight: 44)
        }
    }

    private func smallButton(_ key: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(copy(key))
                .font(.subheadline.weight(.bold))
                .foregroundStyle(FausSwitchPalette.lightSand)
                .padding(.horizontal, AppDesign.Spacing.md)
                .frame(minHeight: 40)
                .background(FausSwitchPalette.wine, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
        }
        .buttonStyle(ScaleButtonStyle())
    }

    private func name(of tag: FausSwitchNameTag) -> String {
        if tag.isLocal { return copy("faus_switch_you") }
        if let key = tag.nameKey { return copy(key) }
        return tag.displayName ?? copy("faus_switch_online_player")
    }

    private func name(of standing: FausSwitchStanding) -> String {
        if standing.isLocal { return copy("faus_switch_you") }
        if let key = standing.nameKey { return copy(key) }
        return standing.displayName ?? copy("faus_switch_online_player")
    }

    private func isOut(_ standing: FausSwitchStanding) -> Bool { standing.isOut }

    private func statusLine(_ standing: FausSwitchStanding) -> String {
        if case .finished = standing.status, let time = standing.time { return String(format: "%.1fs", time) }
        return copy(standing.statusKey)
    }

    // MARK: - Flow

    private func prepareDemo() {
        orientationRequestFailed = false
        isWaitingForLandscape = !isLandscapeLayout
        GameOrientationController.lockToLandscape {
            guard !model.isDemoVisible else { return }
            isWaitingForLandscape = false
            orientationRequestFailed = true
        }
        if isLandscapeLayout { startDemo() }
    }

    private func startDemo() {
        showsTapHint = true
        model.startDemo()
    }

    private func restartDemo() {
        showsTapHint = true
        model.restartDemo()
    }

    private func exitDemoToSetup() {
        model.exitDemo()
        GameOrientationController.returnToPortrait()
    }

    private func leaveOnlineRace() {
        model.leaveOnlineMatch()
        GameOrientationController.returnToPortrait()
    }

    private func handleViewportSize(_ size: CGSize) {
        let isLandscape = size.width > size.height
        isLandscapeLayout = isLandscape
        model.setOnlineLandscape(isLandscape)
        guard isLandscape, isWaitingForLandscape, !model.isDemoVisible else { return }
        isWaitingForLandscape = false
        startDemo()
    }

    private func copy(_ key: String) -> String {
        appViewModel.localized(key, fallback: key)
    }

    private func copy(_ key: String, replacements: [String: String]) -> String {
        replacements.reduce(copy(key)) { $0.replacingOccurrences(of: "{\($1.key)}", with: $1.value) }
    }
}
