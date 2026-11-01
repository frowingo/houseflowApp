import SpriteKit
import SwiftUI
import FausCrewCore

struct HouseTanksView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var model: HouseTanksViewModel
    @State private var isLandscapeLayout = false
    @State private var isWaitingForLandscape = false
    @State private var orientationRequestFailed = false
    @State private var hasShownTapHint = true
    @State private var isPlayfieldPressed = false
    /// Stopping a match closes the service stream; a new id subscribes again.
    @State private var observationID = UUID()

    init(service: (any HouseTanksGameServicing)? = nil, onlineFactory: HouseTanksOnlineFactory = .unavailable) {
        let resolved = service ?? DemoHouseTanksGameSession()
        _model = StateObject(wrappedValue: HouseTanksViewModel(service: resolved, onlineFactory: onlineFactory))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if model.isOnlineMatchVisible {
                    HouseTanksOnlineMatchView(model: model, onExit: exitOnlineMatch)
                } else if let snapshot = model.snapshot {
                    HouseTanksMapBackdrop()
                        .ignoresSafeArea()
                    SpriteView(scene: model.scene, options: [.allowsTransparency])
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    gameplayLayer(snapshot: snapshot)
                } else {
                    HouseTanksMapBackdrop()
                        .ignoresSafeArea()
                    HouseTanksLobbyView(
                        model: model,
                        isLandscapeLayout: isLandscapeLayout,
                        isWaitingForLandscape: isWaitingForLandscape,
                        orientationRequestFailed: orientationRequestFailed,
                        onStart: prepareLandscapeMatch
                    )
                }
            }
            .onAppear { handleViewportSize(geometry.size) }
            .onChange(of: geometry.size) { _, size in
                handleViewportSize(size)
            }
        }
        .environment(\.colorScheme, .light)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(model.snapshot == nil && !model.isOnlineMatchVisible ? .visible : .hidden, for: .navigationBar)
        .task(id: observationID) { await model.observe() }
        .onAppear { model.setReduceMotion(reduceMotion) }
        .onChange(of: reduceMotion) { _, enabled in
            model.setReduceMotion(enabled)
        }
        .onChange(of: scenePhase) { _, phase in
            model.setOnlineForeground(phase == .active)
            guard phase != .active else { return }
            model.pause()
        }
        .onChange(of: model.isOnlineMatchVisible) { _, visible in
            // The room is portrait; the server's first round countdown turns the screen.
            if visible {
                GameOrientationController.lockToLandscape { orientationRequestFailed = true }
            } else {
                GameOrientationController.returnToPortrait()
            }
        }
        .onChange(of: model.snapshot?.phase) { _, phase in
            guard phase != .playing else { return }
            isPlayfieldPressed = false
            model.endPress()
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
    }

    @ViewBuilder
    private func gameplayLayer(snapshot: HouseTanksSnapshot) -> some View {
        if snapshot.phase == .playing {
            Color.clear
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in
                            guard !isPlayfieldPressed else { return }
                            isPlayfieldPressed = true
                            model.beginPress()
                        }
                        .onEnded { _ in
                            isPlayfieldPressed = false
                            model.endPress()
                        }
                )
                .accessibilityElement()
                .accessibilityAddTraits(.isButton)
                .accessibilityLabel(copy("house_tanks_playfield_accessibility"))
                .accessibilityHint(copy("house_tanks_playfield_hint"))
                .accessibilityAction { model.performAccessiblePress() }
        }

        gameplayHUD(snapshot: snapshot)

        switch snapshot.phase {
        case .countdown:
            countdownOverlay(snapshot.countdown, round: snapshot.roundNumber)
        case .paused:
            pausedOverlay(snapshot: snapshot)
        case .roundEnded:
            roundResultOverlay(snapshot: snapshot)
        case .matchEnded:
            matchResultOverlay(snapshot: snapshot)
        case .playing:
            EmptyView()
        }
    }

    private func gameplayHUD(snapshot: HouseTanksSnapshot) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: AppDesign.Spacing.sm) {
                Button(action: model.pause) {
                    Image(systemName: "pause.fill")
                        .font(.body.weight(.black))
                        .foregroundStyle(HouseTanksFieldTheme.ink)
                        .frame(width: 44, height: 44)
                        .hudPanel()
                }
                .accessibilityLabel(copy("house_tanks_pause"))

                ForEach(snapshot.players) { player in
                    playerStatus(player)
                }
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.top, AppDesign.Spacing.sm)

            Spacer()

            if snapshot.phase == .playing, hasShownTapHint {
                Label(copy("house_tanks_tap_hint"), systemImage: "hand.tap.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HouseTanksFieldTheme.ink)
                    .padding(.horizontal, AppDesign.Spacing.lg)
                    .frame(minHeight: 44)
                    .hudPanel()
                    .allowsHitTesting(false)
                    .padding(.bottom, AppDesign.Spacing.xl)
                    .task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        withAnimation(.easeOut(duration: 0.2)) {
                            hasShownTapHint = false
                        }
                    }
            }
        }
    }

    private func playerStatus(_ player: HouseTanksPlayer) -> some View {
        let tint = swiftUIColor(for: player.color)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 4) {
                Text(copy(player.nameKey))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HouseTanksFieldTheme.ink)
                    .strikethrough(!player.isAlive)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text("\(player.roundsWon)/3")
                    .font(HouseTanksFieldTheme.stencil)
                    .foregroundStyle(HouseTanksMapPalette.umber)
            }

            HStack(spacing: 2) {
                ForEach(0..<5, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index < player.armor ? tint : HouseTanksMapPalette.slate.opacity(0.2))
                        .frame(height: 5)
                }
            }
        }
        .padding(.leading, 11)
        .padding(.trailing, 8)
        .frame(maxWidth: .infinity, minHeight: 44)
        .hudPanel()
        .overlay(alignment: .leading) {
            Rectangle().fill(tint).frame(width: 3).padding(.vertical, 7).padding(.leading, 3)
        }
        .overlay {
            if player.role == .human {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous)
                    .stroke(tint, lineWidth: 1.5)
            }
        }
        .opacity(player.isAlive ? 1 : 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(copy(player.nameKey)), \(copy("house_tanks_armor")) \(player.armor), \(copy("house_tanks_round_score")) \(player.roundsWon)")
    }

    private func countdownOverlay(_ countdown: Int?, round: Int) -> some View {
        VStack(spacing: AppDesign.Spacing.xs) {
            Text(copy("house_tanks_round", replacements: ["number": "\(round)"]).uppercased())
                .font(.system(.subheadline, design: .monospaced).weight(.bold))
                .tracking(2)
                .foregroundStyle(HouseTanksMapPalette.umber)
            Text(countdown.map(String.init) ?? copy("house_tanks_countdown_go"))
                .font(.system(size: 84, weight: .black))
                .fontWidth(.condensed)
                .foregroundStyle(HouseTanksMapPalette.steel)
                .shadow(color: HouseTanksMapPalette.paper, radius: 0, x: 3, y: 3)
                .contentTransition(.numericText())
        }
        .padding(.horizontal, AppDesign.Spacing.xxl)
        .padding(.vertical, AppDesign.Spacing.md)
        .background(HouseTanksMapPalette.paper.opacity(0.78),
                    in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
        .overlay {
            HouseTanksCornerMarks(length: 10)
                .stroke(HouseTanksMapPalette.steel.opacity(0.6), lineWidth: 1.5)
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    private func pausedOverlay(snapshot: HouseTanksSnapshot) -> some View {
        stateOverlay(
            kicker: copy("house_tanks_report_paused"),
            icon: "pause.fill",
            accent: HouseTanksMapPalette.slate,
            title: copy("house_tanks_paused"),
            detail: copy("house_tanks_paused_detail"),
            players: nil,
            primaryTitle: copy("house_tanks_resume"),
            primaryIcon: "play.fill",
            primaryColor: HouseTanksMapPalette.steel,
            showsDrillSetup: true,
            primaryAction: model.resume
        )
    }

    private func roundResultOverlay(snapshot: HouseTanksSnapshot) -> some View {
        let humanWon = snapshot.roundWinnerID == snapshot.humanPlayer?.id
        let title: String
        let detail: String
        let accent: Color
        let action: Color

        if snapshot.roundWinnerID == nil {
            title = copy("house_tanks_round_draw")
            detail = copy("house_tanks_round_draw_detail")
            accent = HouseTanksMapPalette.khaki
            action = HouseTanksMapPalette.umber
        } else if humanWon {
            title = copy("house_tanks_round_won")
            detail = copy("house_tanks_round_won_detail")
            accent = HouseTanksMapPalette.steel
            action = HouseTanksMapPalette.steel
        } else {
            title = copy(
                "house_tanks_round_lost",
                replacements: ["name": copy(snapshot.roundWinner?.nameKey ?? "house_tanks_bot_one")]
            )
            detail = copy("house_tanks_round_lost_detail")
            accent = HouseTanksMapPalette.rust
            action = HouseTanksMapPalette.rust
        }

        return stateOverlay(
            kicker: copy("house_tanks_report_round", replacements: ["number": "\(snapshot.roundNumber)"]),
            icon: humanWon ? "shield.fill" : "flag.checkered",
            accent: accent,
            title: title,
            detail: detail,
            players: snapshot.players,
            primaryTitle: copy("house_tanks_next_round"),
            primaryIcon: "arrow.right",
            primaryColor: action,
            showsDrillSetup: true,
            primaryAction: {
                hasShownTapHint = false
                model.nextRound()
            }
        )
    }

    private func matchResultOverlay(snapshot: HouseTanksSnapshot) -> some View {
        let humanWon = snapshot.championID == snapshot.humanPlayer?.id
        let title = humanWon
            ? copy("house_tanks_champion_you")
            : copy(
                "house_tanks_champion_bot",
                replacements: ["name": copy(snapshot.champion?.nameKey ?? "house_tanks_bot_one")]
            )

        return stateOverlay(
            kicker: copy("house_tanks_report_match"),
            icon: "trophy.fill",
            accent: humanWon ? HouseTanksMapPalette.steel : HouseTanksMapPalette.rust,
            title: title,
            detail: copy("house_tanks_champion_detail"),
            players: snapshot.players,
            primaryTitle: copy("house_tanks_rematch"),
            primaryIcon: "arrow.clockwise",
            primaryColor: humanWon ? HouseTanksMapPalette.steel : HouseTanksMapPalette.rust,
            showsDrillSetup: true,
            primaryAction: {
                hasShownTapHint = true
                model.restartMatch()
            }
        )
    }

    /// A field report on paper: kicker, verdict, the round tally and the next order.
    private func stateOverlay(
        kicker: String,
        icon: String,
        accent: Color,
        title: String,
        detail: String,
        players: [HouseTanksPlayer]?,
        primaryTitle: String,
        primaryIcon: String,
        primaryColor: Color,
        showsDrillSetup: Bool,
        primaryAction: @escaping () -> Void
    ) -> some View {
        ZStack {
            HouseTanksFieldTheme.ink.opacity(0.34).ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                    HStack(spacing: AppDesign.Spacing.md) {
                        Image(systemName: icon)
                            .font(.title3.weight(.black))
                            .foregroundStyle(HouseTanksMapPalette.paper)
                            .frame(width: 48, height: 48)
                            .background(accent, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
                        VStack(alignment: .leading, spacing: 2) {
                            Text(kicker.uppercased())
                                .font(HouseTanksFieldTheme.stencil)
                                .tracking(1.4)
                                .foregroundStyle(HouseTanksMapPalette.umber)
                            Text(title)
                                .font(.title2.weight(.black))
                                .fontWidth(.condensed)
                                .foregroundStyle(HouseTanksFieldTheme.ink)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    .accessibilityElement(children: .combine)

                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(HouseTanksFieldTheme.muted)
                        .fixedSize(horizontal: false, vertical: true)

                    if let players {
                        scoreboard(players)
                    }

                    let primary = Button(action: primaryAction) {
                        Label(primaryTitle, systemImage: primaryIcon)
                            .font(.headline)
                            .foregroundStyle(HouseTanksMapPalette.paper)
                            .lineLimit(1)
                            .padding(.horizontal, AppDesign.Spacing.sm)
                            .frame(maxWidth: .infinity, minHeight: 48)
                            .background(primaryColor,
                                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
                    }
                    .buttonStyle(HouseTanksRaisedButtonStyle(depth: primaryColor, offset: 3))

                    let secondary = Group {
                        overlayButton(copy("house_tanks_exit"), action: exitGame)
                        if showsDrillSetup {
                            overlayButton(copy("house_tanks_back_to_drill"), icon: "slider.horizontal.3",
                                          action: returnToDrillSetup)
                        }
                    }

                    // Three orders share a row when they fit; otherwise the main one gets its own.
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: AppDesign.Spacing.sm) {
                            secondary
                            primary
                        }
                        VStack(spacing: AppDesign.Spacing.sm) {
                            primary
                            HStack(spacing: AppDesign.Spacing.sm) { secondary }
                        }
                    }
                    .padding(.top, AppDesign.Spacing.xs)
                }
                .houseTanksFieldCard(padding: AppDesign.Spacing.xl)
                .background(HouseTanksMapPalette.paper,
                            in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
                .frame(maxWidth: 470)
                .padding(AppDesign.Spacing.lg)
                .frame(maxWidth: .infinity)
            }
            .scrollBounceBehavior(.basedOnSize)
            .defaultScrollAnchor(.center)
        }
    }

    private func overlayButton(_ title: String, icon: String? = nil, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon) }
                Text(title)
            }
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(HouseTanksFieldTheme.ink)
            .lineLimit(1)
            .padding(.horizontal, AppDesign.Spacing.sm)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(HouseTanksMapPalette.paper,
                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous)
                    .stroke(HouseTanksMapPalette.slate.opacity(0.5), lineWidth: 1)
            }
        }
        .buttonStyle(ScaleButtonStyle())
    }

    /// Round wins per tank, leader first.
    private func scoreboard(_ players: [HouseTanksPlayer]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: AppDesign.Spacing.sm),
                            GridItem(.flexible(), spacing: AppDesign.Spacing.sm)],
                  spacing: AppDesign.Spacing.xs) {
            ForEach(players.sorted { $0.roundsWon > $1.roundsWon }) { player in
                HStack(spacing: 6) {
                    Circle()
                        .fill(swiftUIColor(for: player.color))
                        .frame(width: 9, height: 9)
                    Text(copy(player.nameKey))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(HouseTanksFieldTheme.ink)
                        .lineLimit(1)
                    Spacer(minLength: 2)
                    HStack(spacing: 2) {
                        ForEach(0..<3, id: \.self) { index in
                            Rectangle()
                                .fill(index < player.roundsWon ? HouseTanksMapPalette.umber : HouseTanksMapPalette.slate.opacity(0.2))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
                .padding(.horizontal, AppDesign.Spacing.sm)
                .frame(minHeight: 30)
                .background(HouseTanksMapPalette.sand.opacity(0.45),
                            in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(copy(player.nameKey)), \(copy("house_tanks_round_score")) \(player.roundsWon)")
            }
        }
    }

    private func prepareLandscapeMatch() {
        guard model.pendingSetupStep == nil else { return }
        orientationRequestFailed = false
        isWaitingForLandscape = !isLandscapeLayout

        GameOrientationController.lockToLandscape {
            guard model.snapshot == nil else { return }
            isWaitingForLandscape = false
            orientationRequestFailed = true
        }

        if isLandscapeLayout {
            isWaitingForLandscape = false
            Task { await model.startMatch() }
        }
    }

    private func handleViewportSize(_ size: CGSize) {
        let landscape = size.width > size.height
        isLandscapeLayout = landscape
        model.setOnlineLandscape(landscape)
        guard landscape, isWaitingForLandscape, model.snapshot == nil else { return }
        isWaitingForLandscape = false
        Task { await model.startMatch() }
    }

    private func returnToDrillSetup() {
        isPlayfieldPressed = false
        isWaitingForLandscape = false
        orientationRequestFailed = false
        hasShownTapHint = true
        model.returnToDemoSetup()
        observationID = UUID()
        GameOrientationController.returnToPortrait()
    }

    private func exitOnlineMatch() {
        model.leaveOnlineMatch()
        GameOrientationController.returnToPortrait()
    }

    private func exitGame() {
        model.stop()
        dismiss()
    }

    private func copy(_ key: String) -> String {
        appViewModel.localized(key, fallback: key)
    }

    private func copy(_ key: String, replacements: [String: String]) -> String {
        appViewModel.localized(key, replacements: replacements)
    }

    private func swiftUIColor(for color: HouseTanksColor) -> Color {
        Color(uiColor: color.uiColor)
    }
}

#Preview {
    NavigationStack {
        HouseTanksView()
            .environmentObject(AppViewModel())
    }
}
