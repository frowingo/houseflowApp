import SpriteKit
import SwiftUI

struct HouseRocketsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var model: HouseRocketsViewModel
    @State private var isLandscapeLayout = false
    @State private var isWaitingForLandscape = false
    @State private var orientationRequestFailed = false
    @State private var orientationRequestID: UUID?
    @State private var eliminationNotice: String?
    @State private var noticeID: UUID?

    init(sessionFactory: HouseRocketsSessionFactory, context: HouseRocketsLaunchContext) {
        _model = StateObject(wrappedValue: HouseRocketsViewModel(
            sessionFactory: sessionFactory, context: context
        ))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                HouseRocketsTheme.background.ignoresSafeArea()
                if model.snapshot == nil && model.onlineFrame == nil { HouseRocketsTopography().ignoresSafeArea() }

                if let snapshot = model.snapshot {
                    SpriteView(scene: model.scene)
                        .ignoresSafeArea(edges: HouseRocketsCourse.angle(at: snapshot.elapsedTime) > .pi / 4
                                         ? .vertical : .horizontal)
                        .allowsHitTesting(false)
                    gameLayer(snapshot: snapshot)
                } else if let frame = model.onlineFrame {
                    SpriteView(scene: model.scene)
                        .ignoresSafeArea(edges: frame.courseAngle > .pi / 4 ? .vertical : .horizontal)
                        .allowsHitTesting(false)
                    if model.onlinePresentation?.canSteer == true, scenePhase == .active {
                        HouseRocketsFloatingJoystick(
                            heading: (frame.players.first(where: { $0.role == .human })?.courseHeading ?? 0) + frame.courseAngle,
                            label: copy("house_rockets_joystick"), hint: copy("house_rockets_joystick_hint"),
                            onSteer: model.steer, onEnd: model.endSteering, onAdjust: model.adjustHeading
                        )
                        .id(geometry.size)
                    }
                    if let presentation = model.onlinePresentation {
                        HouseRocketsOnlineFlightOverlay(state: model.onlineState, presentation: presentation, onExit: exitGame)
                    }
                } else {
                    lobby
                }
            }
            .onAppear { handleViewportSize(geometry.size) }
            .onChange(of: geometry.size) { _, size in handleViewportSize(size) }
        }
        .environment(\.colorScheme, .dark)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(model.snapshot == nil && model.onlineFrame == nil ? .visible : .hidden, for: .navigationBar)
        .navigationBarBackButtonHidden(model.selectedMode == .housemates)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if model.selectedMode == .housemates {
                    Button(action: exitGame) { Image(systemName: "chevron.left") }
                        .accessibilityLabel(copy("house_rockets_exit"))
                        .disabled(model.onlineState.isLeaving)
                }
            }
        }
        .onAppear {
            model.setReduceMotion(reduceMotion)
            model.setForeground(scenePhase == .active)
        }
        .onChange(of: reduceMotion) { _, enabled in model.setReduceMotion(enabled) }
        .onChange(of: scenePhase) { _, phase in
            model.setForeground(phase == .active)
            if phase == .active { prepareOnlineFlightLandscape() }
            guard phase != .active else { return }
            if isWaitingForLandscape {
                isWaitingForLandscape = false
                orientationRequestID = nil
                GameOrientationController.returnToPortrait()
            }
            model.pause()
        }
        .onChange(of: model.onlineFrame?.sessionID) { _, id in
            if id != nil { prepareOnlineFlightLandscape() }
        }
        .onChange(of: model.onlineState.session?.state) { _, state in
            if orientationRequestFailed, state == .countdown || state == .running {
                Task { await model.leaveOnline() }
            }
        }
        .onChange(of: appViewModel.currentHouseDetails?.id) { _, _ in refreshContext() }
        .onChange(of: appViewModel.currentUserId) { _, _ in refreshContext() }
        .onChange(of: model.snapshot?.matchID) { _, _ in
            eliminationNotice = nil
            noticeID = nil
        }
        .onChange(of: model.snapshot?.lastEliminatedID) { _, id in
            guard let id, let player = model.snapshot?.players.first(where: { $0.id == id }) else { return }
            noticeID = id
            eliminationNotice = player.role == .human
                ? copy("house_rockets_eliminated")
                : copy("house_rockets_bot_eliminated", replacements: ["name": copy(player.nameKey)])
            Task {
                try? await Task.sleep(nanoseconds: 1_800_000_000)
                guard noticeID == id else { return }
                eliminationNotice = nil
            }
        }
        .onDisappear {
            isWaitingForLandscape = false
            orientationRequestID = nil
            eliminationNotice = nil
            noticeID = nil
            model.stop()
            GameOrientationController.returnToPortrait()
        }
    }

    private var lobby: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.xxl) {
                    HStack(alignment: .center, spacing: AppDesign.Spacing.lg) {
                        HouseRocketsRocketMark()
                            .frame(width: 76, height: 76)

                        VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                            Text(copy("house_rockets_title"))
                                .font(.largeTitle.weight(.black))
                                .foregroundStyle(HouseRocketsTheme.ink)
                            Text(copy(model.selectedMode == .localBots
                                      ? "house_rockets_subtitle" : "house_rockets_mode_prompt"))
                                .font(.subheadline)
                                .foregroundStyle(HouseRocketsTheme.muted)
                        }
                    }

                    if let mode = model.selectedMode {
                        HStack {
                            Label(copy(mode == .localBots ? "house_rockets_mode_bots" : "house_rockets_mode_housemates"),
                                  systemImage: mode == .localBots ? "gamecontroller" : "person.2")
                                .font(.headline)
                            Spacer()
                            Button(copy("house_rockets_change_mode"), action: changeMode)
                                .font(.subheadline.weight(.semibold))
                                .frame(minHeight: 44)
                                .disabled(isWaitingForLandscape || model.onlineState.isLeaving)
                        }
                        .foregroundStyle(HouseRocketsTheme.accent)

                        if mode == .localBots {
                            botLobby
                        } else {
                            onlineLobby
                        }
                    } else {
                        modeSelection
                    }

                    VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
                        rule("house_rockets_rule_aim", symbol: "move.3d")
                        rule("house_rockets_rule_drive", symbol: "arrow.right")
                        rule("house_rockets_rule_fields", symbol: "bolt.horizontal.fill")
                        rule("house_rockets_rule_survive", symbol: "shield.fill")
                    }
                    .padding(AppDesign.Spacing.xl)
                    .background(HouseRocketsTheme.panel,
                                in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))

                    if model.selectedMode == .localBots || (orientationRequestFailed && model.selectedMode == nil) {
                        Label(copy(orientationRequestFailed
                                   ? "house_rockets_landscape_error"
                                   : "house_rockets_landscape"),
                              systemImage: "rectangle.landscape.rotate")
                            .font(.subheadline)
                            .foregroundStyle(orientationRequestFailed
                                             ? HouseRocketsTheme.danger : HouseRocketsTheme.muted)
                    }
                }
                .padding(AppDesign.Spacing.xl)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }

            if model.selectedMode == .localBots {
                Button(action: prepareLandscapeMatch) {
                    HStack(spacing: AppDesign.Spacing.sm) {
                        if isWaitingForLandscape { ProgressView().tint(HouseRocketsTheme.background) }
                        Image(systemName: "arrow.up.right")
                        Text(copy(isWaitingForLandscape ? "house_rockets_rotating" : "house_rockets_start"))
                    }
                    .font(.headline)
                    .foregroundStyle(HouseRocketsTheme.background)
                    .frame(maxWidth: .infinity, minHeight: AppDesign.Size.buttonHeightLarge)
                    .background(HouseRocketsTheme.accent,
                                in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
                }
                .buttonStyle(ScaleButtonStyle())
                .disabled(isWaitingForLandscape)
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.vertical, AppDesign.Spacing.lg)
            }
        }
    }

    private var modeSelection: some View {
        VStack(spacing: 0) {
            ForEach(HouseRocketsMode.allCases) { mode in
                Button { model.selectMode(mode) } label: {
                    HStack(spacing: AppDesign.Spacing.lg) {
                        Image(systemName: mode == .localBots ? "gamecontroller" : "person.2")
                            .font(.title2)
                            .frame(width: 32)
                            .foregroundStyle(HouseRocketsTheme.accent)
                        VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                            Text(copy(mode == .localBots ? "house_rockets_mode_bots" : "house_rockets_mode_housemates"))
                                .font(.headline)
                                .foregroundStyle(HouseRocketsTheme.ink)
                            Text(copy(mode == .localBots ? "house_rockets_mode_bots_detail" : "house_rockets_mode_housemates_detail"))
                                .font(.subheadline)
                                .foregroundStyle(HouseRocketsTheme.muted)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                        Image(systemName: "chevron.right")
                            .foregroundStyle(HouseRocketsTheme.muted)
                    }
                    .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                    .padding(AppDesign.Spacing.xl)
                    .contentShape(Rectangle())
                }
                .buttonStyle(ScaleButtonStyle())
                if mode == .localBots {
                    Divider().overlay(HouseRocketsTheme.ink.opacity(0.14))
                        .padding(.horizontal, AppDesign.Spacing.xl)
                }
            }
        }
        .background(HouseRocketsTheme.panel,
                    in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
    }

    private var botLobby: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
            Label(copy("house_rockets_offline"), systemImage: "iphone")
                .font(.subheadline)
                .foregroundStyle(HouseRocketsTheme.muted)
            HStack(spacing: AppDesign.Spacing.sm) {
                ForEach(0..<(min(3, max(1, model.botCount)) + 1), id: \.self) { index in
                    Circle()
                        .fill(color(for: HouseRocketsColor.allCases[index]))
                        .frame(width: 24, height: 24)
                        .overlay(Circle().stroke(HouseRocketsTheme.ink.opacity(0.8), lineWidth: index == 0 ? 2 : 0))
                        .accessibilityLabel(index == 0 ? copy("house_rockets_you") : copy(botNameKey(index)))
                }
            }
            Text(copy("house_rockets_bot_count"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HouseRocketsTheme.muted)
            Picker(copy("house_rockets_bot_count"), selection: $model.botCount) {
                ForEach(1...3, id: \.self) { count in Text("\(count)").tag(count) }
            }
            .pickerStyle(.segmented)
            .disabled(isWaitingForLandscape)
        }
        .padding(AppDesign.Spacing.xl)
        .background(HouseRocketsTheme.panel,
                    in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
    }

    @ViewBuilder
    private var onlineLobby: some View {
        if let blocker = model.onlineBlocker {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                Label(copy("house_rockets_online_unavailable"), systemImage: "wifi.exclamationmark")
                    .font(.headline)
                    .foregroundStyle(HouseRocketsTheme.ink)
                Text(copy(blockerKey(blocker)))
                    .font(.subheadline)
                    .foregroundStyle(HouseRocketsTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(AppDesign.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HouseRocketsTheme.panel,
                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
        } else {
            HouseRocketsOnlineLobbyView(
                state: model.onlineState, localPlayerID: model.context.localPlayerID,
                memberNames: (appViewModel.currentHouseDetails?.members ?? []).reduce(into: [:]) { names, member in
                    names[member.id] = member.fullName
                },
                isWaitingForLandscape: isWaitingForLandscape, orientationFailed: orientationRequestFailed,
                onReady: {
                    if model.onlineState.localPlayer(model.context.localPlayerID)?.state == .ready {
                        model.setOnlineReady(false)
                    } else {
                        prepareLandscapeMatch()
                    }
                }, onRetry: model.retryOnline, onExit: exitGame
            )
        }
    }

    private func blockerKey(_ blocker: HouseRocketsOnlineBlocker) -> String {
        switch blocker {
        case .signInRequired: return "house_rockets_online_sign_in"
        case .houseRequired: return "house_rockets_online_house_required"
        case .serviceUnavailable: return "house_rockets_online_unavailable_detail"
        }
    }

    private func rule(_ key: String, symbol: String) -> some View {
        Label(copy(key), systemImage: symbol)
            .font(.subheadline.weight(.medium))
            .foregroundStyle(HouseRocketsTheme.ink)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func gameLayer(snapshot: HouseRocketsSnapshot) -> some View {
        ZStack {
            if snapshot.phase == .playing, snapshot.humanPlayer?.isAlive == true,
               scenePhase == .active {
                GeometryReader { geometry in
                    HouseRocketsFloatingJoystick(
                        heading: snapshot.humanPlayer?.heading ?? 0,
                        label: copy("house_rockets_joystick"),
                        hint: copy("house_rockets_joystick_hint"),
                        onSteer: model.steer,
                        onEnd: model.endSteering,
                        onAdjust: model.adjustHeading
                    )
                    .id(geometry.size)
                }
            }

            if snapshot.phase == .playing || snapshot.phase == .countdown {
                informationLayer(snapshot: snapshot)
            }

            switch snapshot.phase {
            case .countdown:
                EmptyView()
            case .paused:
                stateOverlay(
                    title: copy("house_rockets_paused"),
                    detail: nil,
                    primary: copy("house_rockets_resume"),
                    primaryAction: model.resume
                )
            case .ended:
                let title: String = {
                    guard let winner = snapshot.winner else { return copy("house_rockets_draw") }
                    return winner.role == .human
                        ? copy("house_rockets_won")
                        : copy("house_rockets_lost", replacements: ["name": copy(winner.nameKey)])
                }()
                stateOverlay(
                    title: title,
                    detail: copy(snapshot.winnerID == nil
                                 ? "house_rockets_draw_detail" : "house_rockets_result_detail"),
                    primary: copy("house_rockets_rematch"),
                    primaryAction: model.restart
                )
            case .playing:
                EmptyView()
            }
        }
    }

    private func informationLayer(snapshot: HouseRocketsSnapshot) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: snapshot.phase != .playing)) { _ in
            GeometryReader { geometry in
                let projection = HouseRocketsProjection(elapsedTime: snapshot.elapsedTime,
                                                       cameraX: snapshot.cameraX,
                                                       width: Double(geometry.size.width),
                                                       height: Double(geometry.size.height))
                let regions = projection.informationRegions(width: Double(geometry.size.width),
                                                            height: Double(geometry.size.height))
                // Pause remains available while informational labels are hidden.
                if regions.isEmpty, snapshot.phase == .playing {
                    Button(action: model.pause) {
                        Image(systemName: "pause.fill")
                            .foregroundStyle(HouseRocketsTheme.ink)
                            .frame(width: 44, height: 44)
                            .background(HouseRocketsTheme.panel, in: Circle())
                    }
                    .accessibilityLabel(copy("house_rockets_pause"))
                    .position(x: 30, y: 30)
                }
                ForEach(regions.indices, id: \.self) { index in
                    let region = regions[index]
                    let compact = region.width < 340
                    Group {
                        if index == 0 {
                            HStack(spacing: AppDesign.Spacing.sm) {
                                if snapshot.phase == .playing {
                                    Button(action: model.pause) {
                                        Image(systemName: "pause.fill")
                                            .frame(width: 44, height: 44)
                                            .background(HouseRocketsTheme.panel, in: Circle())
                                    }
                                    .accessibilityLabel(copy("house_rockets_pause"))
                                }
                                let layout = compact ? AnyLayout(VStackLayout(spacing: AppDesign.Spacing.xs))
                                    : AnyLayout(HStackLayout(spacing: AppDesign.Spacing.md))
                                layout {
                                    HStack(spacing: AppDesign.Spacing.sm) {
                                        Label("\(Int(snapshot.elapsedTime))", systemImage: "timer")
                                            .monospacedDigit()
                                            .accessibilityLabel(copy("house_rockets_time") + " \(Int(snapshot.elapsedTime))")
                                        Label("\(snapshot.aliveCount)", systemImage: "person.2.fill")
                                            .accessibilityLabel(copy("house_rockets_alive", replacements: ["count": "\(snapshot.aliveCount)"]))
                                    }
                                    if snapshot.humanPlayer?.isAlive == true, let effect = snapshot.humanPlayer?.speedEffect {
                                        Label(copy(effect == .boost ? "house_rockets_boost_active" : "house_rockets_slow_active"),
                                              systemImage: effect == .boost ? "chevron.right.2" : "pause.fill")
                                            .foregroundStyle(effect == .boost ? HouseRocketsTheme.accent : HouseRocketsTheme.accent)
                                    }
                                    directionCue(snapshot: snapshot)
                                }
                                .allowsHitTesting(false)
                            }
                        } else {
                            VStack(spacing: AppDesign.Spacing.xs) {
                                let layout = compact ? AnyLayout(VStackLayout(spacing: AppDesign.Spacing.xs))
                                    : AnyLayout(HStackLayout(spacing: AppDesign.Spacing.sm))
                                layout {
                                    if compact {
                                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())],
                                                  alignment: .leading, spacing: AppDesign.Spacing.xs) {
                                            playerLabels(snapshot: snapshot)
                                        }
                                    } else {
                                        HStack(spacing: AppDesign.Spacing.sm) { playerLabels(snapshot: snapshot) }
                                    }
                                    if let eliminationNotice {
                                        Text(eliminationNotice)
                                            .foregroundStyle(HouseRocketsTheme.danger)
                                            .accessibilityAddTraits(.updatesFrequently)
                                    } else if snapshot.humanPlayer?.isAlive == false {
                                        Label(copy("house_rockets_spectating_short"), systemImage: "eye")
                                            .foregroundStyle(HouseRocketsTheme.muted)
                                    }
                                }
                                directionCue(snapshot: snapshot).accessibilityHidden(true)
                            }
                            .allowsHitTesting(false)
                        }
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(HouseRocketsTheme.ink)
                    .lineLimit(1)
                    .frame(width: region.width, height: region.height, alignment: .top)
                    .position(x: region.midX, y: region.midY)
                }
            }
        }
    }


    private func playerLabels(snapshot: HouseRocketsSnapshot) -> some View {
        ForEach(snapshot.players) { player in
            HStack(spacing: AppDesign.Spacing.xs) {
                Circle().fill(color(for: player.color)).frame(width: 7, height: 7)
                    .overlay(Circle().stroke(HouseRocketsTheme.ink, lineWidth: 0.75))
                Text(copy(player.nameKey))
                    .strikethrough(!player.isAlive)
                    .foregroundStyle(player.isAlive ? HouseRocketsTheme.ink : HouseRocketsTheme.muted)
            }
        }
    }

    @ViewBuilder
    private func directionCue(snapshot: HouseRocketsSnapshot) -> some View {
        if snapshot.phase == .countdown {
            Text(snapshot.countdown.map { String($0) } ?? copy("house_rockets_countdown_go"))
                .font(.title3.weight(.black))
                .foregroundStyle(HouseRocketsTheme.accent)
                .accessibilityAddTraits(.updatesFrequently)
        } else if let vertical = HouseRocketsCourse.transitionTargetIsVertical(at: snapshot.elapsedTime) {
            Label(copy("house_rockets_turn"), systemImage: vertical ? "arrow.up" : "arrow.right")
                .foregroundStyle(HouseRocketsTheme.accent)
                .accessibilityLabel(copy(vertical ? "house_rockets_vertical_transition" : "house_rockets_horizontal_transition"))
        }
    }

    private func stateOverlay(
        title: String,
        detail: String?,
        primary: String,
        primaryAction: @escaping () -> Void
    ) -> some View {
        ZStack {
            HouseRocketsTheme.background.opacity(0.88).ignoresSafeArea()
            VStack(spacing: AppDesign.Spacing.lg) {
                HouseRocketsRocketMark().frame(width: 64, height: 64)
                Text(title)
                    .font(.title.weight(.bold))
                    .multilineTextAlignment(.center)
                if let detail {
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(HouseRocketsTheme.muted)
                        .multilineTextAlignment(.center)
                }
                HStack(spacing: AppDesign.Spacing.md) {
                    Button(action: exitGame) {
                        Text(copy("house_rockets_exit"))
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.bordered)
                    Button(action: primaryAction) {
                        Text(primary)
                            .frame(maxWidth: .infinity, minHeight: 48)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(HouseRocketsTheme.accent)
                    .foregroundStyle(HouseRocketsTheme.background)
                }
            }
            .foregroundStyle(HouseRocketsTheme.ink)
            .padding(AppDesign.Spacing.xl)
            .frame(maxWidth: 430)
            .background(HouseRocketsTheme.panel,
                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
            .padding(AppDesign.Spacing.xl)
        }
    }

    private func prepareLandscapeMatch() {
        guard model.selectedMode != nil, scenePhase == .active else { return }
        if model.selectedMode == .housemates {
            guard model.onlineState.canChangeReady(playerID: model.context.localPlayerID) else { return }
        }
        requestLandscape()
    }

    private func prepareOnlineFlightLandscape() {
        guard model.selectedMode == .housemates, model.onlineFrame != nil, scenePhase == .active,
              orientationRequestID == nil, !orientationRequestFailed, !model.onlineState.isLeaving else { return }
        requestLandscape()
    }

    private func requestLandscape() {
        orientationRequestFailed = false
        isWaitingForLandscape = !isLandscapeLayout
        let requestID = UUID()
        orientationRequestID = requestID
        GameOrientationController.lockToLandscape {
            guard orientationRequestID == requestID else { return }
            isWaitingForLandscape = false
            orientationRequestID = nil
            orientationRequestFailed = true
            model.setLandscape(false)
            if model.selectedMode == .housemates,
               model.onlineState.session?.state == .countdown || model.onlineState.session?.state == .running {
                Task { await model.leaveOnline() }
            }
            GameOrientationController.returnToPortrait()
        }
        if isLandscapeLayout, !orientationRequestFailed { finishLandscapePreparation() }
    }

    private func handleViewportSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        model.scene.size = size
        isLandscapeLayout = size.width > size.height
        model.setLandscape(isLandscapeLayout)
        guard isLandscapeLayout, isWaitingForLandscape, model.snapshot == nil,
              model.selectedMode != nil, scenePhase == .active,
              !orientationRequestFailed else { return }
        finishLandscapePreparation()
    }

    private func finishLandscapePreparation() {
        isWaitingForLandscape = false
        if model.selectedMode == .housemates {
            // Keep the request identity to handle a late system rotation failure.
            model.setOnlineReady(true)
        } else {
            orientationRequestID = nil
            Task { await model.startMatch() }
        }
    }

    private func changeMode() {
        isWaitingForLandscape = false
        orientationRequestID = nil
        orientationRequestFailed = false
        eliminationNotice = nil
        noticeID = nil
        if model.selectedMode == .housemates {
            Task {
                if await model.leaveOnline() { GameOrientationController.returnToPortrait() }
            }
        } else {
            model.returnToModeSelection()
            GameOrientationController.returnToPortrait()
        }
    }

    private func refreshContext() {
        let context = HouseRocketsLaunchContext(
            houseID: appViewModel.currentHouseDetails?.id,
            localPlayerID: appViewModel.currentUserId
        )
        guard model.context != context else { return }
        isWaitingForLandscape = false
        orientationRequestID = nil
        orientationRequestFailed = false
        eliminationNotice = nil
        noticeID = nil
        model.updateContext(context)
        GameOrientationController.returnToPortrait()
    }

    private func exitGame() {
        if model.selectedMode == .housemates {
            guard !model.onlineState.isLeaving else { return }
            Task {
                if await model.leaveOnline() { dismiss() }
            }
        } else {
            model.stop()
            dismiss()
        }
    }

    private func botNameKey(_ index: Int) -> String {
        ["house_rockets_bot_one", "house_rockets_bot_two", "house_rockets_bot_three"][index - 1]
    }

    private func color(for color: HouseRocketsColor) -> Color {
        Color(HouseRocketsPalette.player(color))
    }

    private func copy(_ key: String) -> String { appViewModel.localized(key, fallback: key) }
    private func copy(_ key: String, replacements: [String: String]) -> String {
        appViewModel.localized(key, replacements: replacements)
    }
}

/// One gesture recognizer serves both edges; a drag keeps its original touch center.
private struct HouseRocketsFloatingJoystick: View {
    let heading: Double
    let label: String
    let hint: String
    let onSteer: (Double) -> Void
    let onEnd: () -> Void
    let onAdjust: (Double) -> Void
    @GestureState private var drag: DragGesture.Value?

    var body: some View {
        Color.clear
            .contentShape(EdgeZones())
            .gesture(
                DragGesture(minimumDistance: 5)
                    .updating($drag) { value, state, _ in state = value }
                    .onChanged { value in
                        let dx = value.translation.width
                        let dy = value.translation.height
                        guard hypot(dx, dy) > 5 else { return }
                        onSteer(atan2(-Double(dy), Double(dx)))
                    }
            )
            .overlay(alignment: .topLeading) {
                if let drag, hypot(drag.translation.width, drag.translation.height) > 5 {
                    artwork(translation: drag.translation)
                        .position(drag.startLocation)
                        .allowsHitTesting(false)
                }
            }
            // GestureState resets on release and cancellation, including interruptions.
            .onChange(of: drag != nil) { _, active in
                if !active { onEnd() }
            }
            .onDisappear(perform: onEnd)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(label)
            .accessibilityHint(hint)
            .accessibilityValue("\(Int(heading * 180 / .pi))°")
            .accessibilityAdjustableAction { direction in
                switch direction {
                case .increment: onAdjust(.pi / 12)
                case .decrement: onAdjust(-.pi / 12)
                @unknown default: break
                }
            }
    }

    private func artwork(translation: CGSize) -> some View {
        let distance = hypot(translation.width, translation.height)
        let scale = min(1, 34 / max(distance, 1))
        let angle = atan2(Double(translation.height), Double(translation.width))
        return ZStack {
            Circle().fill(HouseRocketsTheme.panel)
            Circle().stroke(HouseRocketsTheme.accent, lineWidth: 2)
            Circle()
                .fill(HouseRocketsTheme.accent)
                .frame(width: 44, height: 44)
                .overlay {
                    Image(systemName: "arrow.right")
                        .font(.title3.weight(.bold))
                        .rotationEffect(.radians(angle))
                        .foregroundStyle(HouseRocketsTheme.background)
                }
                .offset(x: translation.width * scale, y: translation.height * scale)
        }
        .frame(width: 116, height: 116)
        .opacity(0.55)
    }

    private struct EdgeZones: Shape {
        func path(in rect: CGRect) -> Path {
            var path = Path()
            let width = rect.width * 0.3
            path.addRect(CGRect(x: rect.minX, y: rect.minY, width: width, height: rect.height))
            path.addRect(CGRect(x: rect.maxX - width, y: rect.minY, width: width, height: rect.height))
            return path
        }
    }
}
