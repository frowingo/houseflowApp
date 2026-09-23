import SpriteKit
import SwiftUI

private enum HouseTanksTheme {
    static let navy = Color(hex: "14252C")
    static let deepNavy = Color(hex: "0C171D")
    static let panel = Color(hex: "162A32").opacity(0.97)
    static let cream = Color(hex: "F7F1E5")
    static let secondary = Color(hex: "CAD7D5")
    static let teal = Color(hex: "1FBEA7")
    static let orange = Color(hex: "F26F2D")
    static let blue = Color(hex: "3E7BE0")
    static let amber = Color(hex: "F4BF4F")
}

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

    init(service: (any HouseTanksGameServicing)? = nil) {
        let resolved = service ?? DemoHouseTanksGameSession()
        _model = StateObject(wrappedValue: HouseTanksViewModel(service: resolved))
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if let snapshot = model.snapshot {
                    SpriteView(scene: model.scene, options: [.allowsTransparency])
                        .ignoresSafeArea()
                        .allowsHitTesting(false)

                    gameplayLayer(snapshot: snapshot)
                } else {
                    HouseTanksLobbyBackdrop()
                        .ignoresSafeArea()
                    lobby
                }
            }
            .onAppear { handleViewportSize(geometry.size) }
            .onChange(of: geometry.size) { _, size in
                handleViewportSize(size)
            }
        }
        .environment(\.colorScheme, .dark)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(model.snapshot == nil ? .visible : .hidden, for: .navigationBar)
        .task { await model.observe() }
        .onAppear { model.setReduceMotion(reduceMotion) }
        .onChange(of: reduceMotion) { _, enabled in
            model.setReduceMotion(enabled)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active else { return }
            model.pause()
        }
        .onChange(of: model.snapshot?.phase) { _, phase in
            guard phase != .playing else { return }
            isPlayfieldPressed = false
            model.endPress()
        }
        .onDisappear {
            model.stop()
            GameOrientationController.restoreDefaultOrientations()
        }
    }

    private var lobby: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppDesign.Spacing.xxl) {
                    lobbyHero
                    modeSection
                    setupSection
                    rulesSection
                    landscapeNotice
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.top, AppDesign.Spacing.xl)
                .padding(.bottom, AppDesign.Spacing.xxl)
                .frame(maxWidth: 680)
                .frame(maxWidth: .infinity)
            }

            Button(action: prepareLandscapeMatch) {
                HStack(spacing: AppDesign.Spacing.sm) {
                    if isWaitingForLandscape {
                        ProgressView()
                            .tint(HouseTanksTheme.deepNavy)
                        Text(copy("house_tanks_rotating"))
                    } else {
                        Image(systemName: isLandscapeLayout ? "scope" : "rectangle.landscape.rotate")
                        Text(copy("house_tanks_start"))
                    }
                }
                .font(.headline)
                .foregroundStyle(HouseTanksTheme.deepNavy)
                .frame(maxWidth: .infinity)
                .frame(minHeight: AppDesign.Size.buttonHeightLarge)
                .background(HouseTanksTheme.teal)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isWaitingForLandscape)
            .padding(.horizontal, AppDesign.Spacing.xl)
            .padding(.vertical, AppDesign.Spacing.lg)
            .background(HouseTanksTheme.deepNavy)
        }
    }

    private var lobbyHero: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(HouseTanksTheme.teal.opacity(0.14))
                    .frame(width: 108, height: 88)
                    .rotationEffect(.degrees(-6))

                Image(systemName: "scope")
                    .font(.system(size: 48, weight: .black))
                    .foregroundStyle(HouseTanksTheme.teal)
            }
            .shadow(color: Color.black.opacity(0.26), radius: 18, x: 0, y: 10)
            .accessibilityHidden(true)

            VStack(spacing: AppDesign.Spacing.sm) {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(copy("house_tanks_title"))
                        .font(.largeTitle.weight(.black))
                        .foregroundStyle(HouseTanksTheme.cream)

                    Text(copy("house_tanks_demo_badge"))
                        .font(.caption2.weight(.black))
                        .foregroundStyle(HouseTanksTheme.deepNavy)
                        .padding(.horizontal, AppDesign.Spacing.sm)
                        .padding(.vertical, AppDesign.Spacing.xs)
                        .background(HouseTanksTheme.amber)
                        .clipShape(Capsule())
                }

                Text(copy("house_tanks_subtitle"))
                    .font(.headline)
                    .foregroundStyle(HouseTanksTheme.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, AppDesign.Spacing.md)
    }

    private var modeSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            sectionTitle("house_tanks_mode_title")

            VStack(spacing: 0) {
                modeRow(
                    icon: "cpu.fill",
                    title: "house_tanks_demo_mode",
                    detail: "house_tanks_demo_mode_detail",
                    accent: HouseTanksTheme.teal,
                    selected: true,
                    badge: nil
                )

                Divider().overlay(Color.white.opacity(0.12))
                    .padding(.leading, 64)

                modeRow(
                    icon: "person.3.fill",
                    title: "house_tanks_online_mode",
                    detail: "house_tanks_online_mode_detail",
                    accent: HouseTanksTheme.blue,
                    selected: false,
                    badge: copy("house_tanks_soon")
                )
                .opacity(0.62)
                .accessibilityAddTraits(.isStaticText)
            }
            .background(HouseTanksTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
        }
    }

    private var setupSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            sectionTitle("house_tanks_setup_title")

            VStack(spacing: AppDesign.Spacing.xl) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: AppDesign.Spacing.xl) {
                        colorPicker
                        Spacer(minLength: AppDesign.Spacing.lg)
                        difficultyPicker
                    }

                    VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
                        colorPicker
                        difficultyPicker
                    }
                }

                Divider().overlay(Color.white.opacity(0.12))

                VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
                    Text(copy("house_tanks_roster"))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(HouseTanksTheme.secondary)

                    let botColors = HouseTanksColor.allCases.filter { $0 != model.humanColor }
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: AppDesign.Spacing.sm) {
                            rosterChip(nameKey: "house_tanks_you", roleKey: "house_tanks_human_role", color: model.humanColor)
                            rosterChip(nameKey: "house_tanks_bot_one", roleKey: "house_tanks_bot_role", color: botColors[0])
                            rosterChip(nameKey: "house_tanks_bot_two", roleKey: "house_tanks_bot_role", color: botColors[1])
                        }

                        VStack(spacing: AppDesign.Spacing.sm) {
                            rosterChip(nameKey: "house_tanks_you", roleKey: "house_tanks_human_role", color: model.humanColor)
                            rosterChip(nameKey: "house_tanks_bot_one", roleKey: "house_tanks_bot_role", color: botColors[0])
                            rosterChip(nameKey: "house_tanks_bot_two", roleKey: "house_tanks_bot_role", color: botColors[1])
                        }
                    }
                }
            }
            .padding(AppDesign.Spacing.xl)
            .background(HouseTanksTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
        }
    }

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            sectionTitle("house_tanks_rules_title")

            VStack(spacing: AppDesign.Spacing.lg) {
                ruleRow(icon: "scope", title: "house_tanks_rule_fire", detail: "house_tanks_rule_fire_detail", color: HouseTanksTheme.teal)
                ruleRow(icon: "arrow.up", title: "house_tanks_rule_drive", detail: "house_tanks_rule_drive_detail", color: HouseTanksTheme.blue)
                ruleRow(icon: "shield.lefthalf.filled", title: "house_tanks_rule_survive", detail: "house_tanks_rule_survive_detail", color: HouseTanksTheme.orange)
            }
            .padding(AppDesign.Spacing.xl)
            .background(HouseTanksTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
        }
    }

    private var landscapeNotice: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            Image(systemName: "rectangle.landscape.rotate")
                .font(.title2.weight(.bold))
                .foregroundStyle(orientationRequestFailed ? HouseTanksTheme.orange : HouseTanksTheme.amber)
                .frame(width: 48, height: 48)
                .background((orientationRequestFailed ? HouseTanksTheme.orange : HouseTanksTheme.amber).opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                Text(copy("house_tanks_landscape_title"))
                    .font(.headline)
                    .foregroundStyle(HouseTanksTheme.cream)
                Text(copy(orientationRequestFailed ? "house_tanks_landscape_error" : "house_tanks_landscape_detail"))
                    .font(.subheadline)
                    .foregroundStyle(HouseTanksTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(AppDesign.Spacing.lg)
        .background(HouseTanksTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
        .accessibilityElement(children: .combine)
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
            countdownOverlay(snapshot.countdown)
        case .paused:
            pausedOverlay
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
                        .foregroundStyle(HouseTanksTheme.cream)
                        .frame(width: 46, height: 46)
                        .background(HouseTanksTheme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
                }
                .accessibilityLabel(copy("house_tanks_pause"))

                ForEach(snapshot.players) { player in
                    playerStatus(player)
                }

                VStack(spacing: 1) {
                    Text(copy("house_tanks_time").uppercased())
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(HouseTanksTheme.secondary)
                    Text(model.timeLabel)
                        .font(.title3.monospacedDigit().weight(.black))
                        .foregroundStyle(snapshot.timeRemaining <= 10 ? HouseTanksTheme.orange : HouseTanksTheme.cream)
                }
                .frame(width: 58, height: 46)
                .background(HouseTanksTheme.panel)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
                .accessibilityElement(children: .combine)
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.top, AppDesign.Spacing.sm)

            Spacer()

            if snapshot.phase == .playing, hasShownTapHint {
                Label(copy("house_tanks_tap_hint"), systemImage: "hand.tap.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HouseTanksTheme.cream)
                    .padding(.horizontal, AppDesign.Spacing.lg)
                    .frame(minHeight: 44)
                    .background(HouseTanksTheme.panel)
                    .clipShape(Capsule())
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 5) {
                Circle()
                    .fill(swiftUIColor(for: player.color))
                    .frame(width: 8, height: 8)
                Text(copy(player.nameKey))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HouseTanksTheme.cream)
                    .lineLimit(1)
                Spacer(minLength: 2)
                Text("\(player.roundsWon)/3")
                    .font(.caption2.monospacedDigit().weight(.black))
                    .foregroundStyle(HouseTanksTheme.amber)
            }

            HStack(spacing: 3) {
                ForEach(0..<5, id: \.self) { index in
                    Capsule()
                        .fill(index < player.armor ? swiftUIColor(for: player.color) : Color.white.opacity(0.13))
                        .frame(height: 5)
                }
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 46)
        .background(HouseTanksTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
        .opacity(player.isAlive ? 1 : 0.52)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(copy(player.nameKey)), \(copy("house_tanks_armor")) \(player.armor), \(copy("house_tanks_round_score")) \(player.roundsWon)")
    }

    private func countdownOverlay(_ countdown: Int?) -> some View {
        ZStack {
            Color.black.opacity(0.18).ignoresSafeArea()
            Text(countdown.map(String.init) ?? copy("house_tanks_countdown_go"))
                .font(.system(size: 78, weight: .black, design: .rounded))
                .foregroundStyle(HouseTanksTheme.cream)
                .shadow(color: Color.black.opacity(0.34), radius: 16, x: 0, y: 8)
                .contentTransition(.numericText())
        }
        .allowsHitTesting(false)
    }

    private var pausedOverlay: some View {
        stateOverlay(
            icon: "pause.fill",
            accent: HouseTanksTheme.amber,
            title: copy("house_tanks_paused"),
            detail: copy("house_tanks_paused_detail"),
            primaryTitle: copy("house_tanks_resume"),
            primaryIcon: "play.fill",
            primaryAction: model.resume
        )
    }

    private func roundResultOverlay(snapshot: HouseTanksSnapshot) -> some View {
        let humanWon = snapshot.roundWinnerID == snapshot.humanPlayer?.id
        let title: String
        let detail: String
        let accent: Color

        if snapshot.roundWinnerID == nil {
            title = copy("house_tanks_round_draw")
            detail = copy("house_tanks_round_draw_detail")
            accent = HouseTanksTheme.amber
        } else if humanWon {
            title = copy("house_tanks_round_won")
            detail = copy("house_tanks_round_won_detail")
            accent = HouseTanksTheme.teal
        } else {
            title = copy(
                "house_tanks_round_lost",
                replacements: ["name": copy(snapshot.roundWinner?.nameKey ?? "house_tanks_bot_one")]
            )
            detail = copy("house_tanks_round_lost_detail")
            accent = HouseTanksTheme.orange
        }

        return stateOverlay(
            icon: humanWon ? "shield.fill" : "flag.checkered",
            accent: accent,
            title: title,
            detail: detail,
            primaryTitle: copy("house_tanks_next_round"),
            primaryIcon: "arrow.right",
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
            icon: "trophy.fill",
            accent: humanWon ? HouseTanksTheme.teal : HouseTanksTheme.orange,
            title: title,
            detail: copy("house_tanks_champion_detail"),
            primaryTitle: copy("house_tanks_rematch"),
            primaryIcon: "arrow.clockwise",
            primaryAction: {
                hasShownTapHint = true
                model.restartMatch()
            }
        )
    }

    private func stateOverlay(
        icon: String,
        accent: Color,
        title: String,
        detail: String,
        primaryTitle: String,
        primaryIcon: String,
        primaryAction: @escaping () -> Void
    ) -> some View {
        ZStack {
            Color.black.opacity(0.62).ignoresSafeArea()

            VStack(spacing: AppDesign.Spacing.lg) {
                Image(systemName: icon)
                    .font(.title.weight(.black))
                    .foregroundStyle(accent)
                    .frame(width: 64, height: 58)
                    .background(accent.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous))

                VStack(spacing: AppDesign.Spacing.xs) {
                    Text(title)
                        .font(.title2.weight(.black))
                        .foregroundStyle(HouseTanksTheme.cream)
                        .multilineTextAlignment(.center)
                    Text(detail)
                        .font(.subheadline)
                        .foregroundStyle(HouseTanksTheme.secondary)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack(spacing: AppDesign.Spacing.sm) {
                    Button(action: primaryAction) {
                        Label(primaryTitle, systemImage: primaryIcon)
                            .font(.headline)
                            .foregroundStyle(HouseTanksTheme.deepNavy)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(accent)
                            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous))
                    }
                    .buttonStyle(ScaleButtonStyle())

                    Button(action: exitGame) {
                        Text(copy("house_tanks_exit"))
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HouseTanksTheme.cream)
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 50)
                            .background(Color.white.opacity(0.09))
                            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous))
                    }
                }
            }
            .padding(AppDesign.Spacing.xl)
            .frame(maxWidth: 470)
            .background(HouseTanksTheme.panel)
            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xxl, style: .continuous))
            .padding(AppDesign.Spacing.xl)
        }
    }

    private func modeRow(
        icon: String,
        title: String,
        detail: String,
        accent: Color,
        selected: Bool,
        badge: String?
    ) -> some View {
        HStack(spacing: AppDesign.Spacing.md) {
            Image(systemName: icon)
                .font(.headline.weight(.bold))
                .foregroundStyle(accent)
                .frame(width: 44, height: 44)
                .background(accent.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(copy(title))
                        .font(.headline)
                        .foregroundStyle(HouseTanksTheme.cream)
                    if let badge {
                        Text(badge)
                            .font(.caption2.weight(.black))
                            .foregroundStyle(HouseTanksTheme.deepNavy)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 3)
                            .background(HouseTanksTheme.amber)
                            .clipShape(Capsule())
                    }
                }
                Text(copy(detail))
                    .font(.subheadline)
                    .foregroundStyle(HouseTanksTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: AppDesign.Spacing.sm)

            if selected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(accent)
            }
        }
        .padding(AppDesign.Spacing.lg)
        .accessibilityElement(children: .combine)
    }

    private func rosterChip(nameKey: String, roleKey: String, color: HouseTanksColor) -> some View {
        HStack(spacing: 7) {
            Circle()
                .fill(swiftUIColor(for: color))
                .frame(width: 12, height: 12)
            VStack(alignment: .leading, spacing: 1) {
                Text(copy(nameKey))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(HouseTanksTheme.cream)
                    .lineLimit(1)
                Text(copy(roleKey))
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HouseTanksTheme.secondary)
            }
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background(Color.white.opacity(0.07))
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
        .accessibilityElement(children: .combine)
    }

    private func ruleRow(icon: String, title: String, detail: String, color: Color) -> some View {
        HStack(alignment: .top, spacing: AppDesign.Spacing.md) {
            Image(systemName: icon)
                .font(.body.weight(.bold))
                .foregroundStyle(color)
                .frame(width: 40, height: 40)
                .background(color.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: 3) {
                Text(copy(title))
                    .font(.headline)
                    .foregroundStyle(HouseTanksTheme.cream)
                Text(copy(detail))
                    .font(.subheadline)
                    .foregroundStyle(HouseTanksTheme.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .accessibilityElement(children: .combine)
    }

    private func sectionTitle(_ key: String) -> some View {
        Text(copy(key))
            .font(.title3.weight(.bold))
            .foregroundStyle(HouseTanksTheme.cream)
    }

    private var colorPicker: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            Text(copy("house_tanks_color"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HouseTanksTheme.secondary)

            HStack(spacing: AppDesign.Spacing.sm) {
                ForEach(HouseTanksColor.allCases) { color in
                    Button {
                        model.humanColor = color
                    } label: {
                        Circle()
                            .fill(swiftUIColor(for: color))
                            .frame(width: 34, height: 34)
                            .overlay {
                                Circle()
                                    .stroke(Color.white, lineWidth: model.humanColor == color ? 3 : 0)
                                    .padding(-4)
                            }
                            .frame(width: 48, height: 48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(colorAccessibilityName(color))
                    .accessibilityAddTraits(model.humanColor == color ? .isSelected : [])
                }
            }
        }
    }

    private var difficultyPicker: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            Text(copy("house_tanks_difficulty"))
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HouseTanksTheme.secondary)

            Picker(copy("house_tanks_difficulty"), selection: $model.difficulty) {
                ForEach(HouseTanksDifficulty.allCases) { difficulty in
                    Text(copy(difficulty.titleKey)).tag(difficulty)
                }
            }
            .pickerStyle(.segmented)
            .frame(maxWidth: 310)
        }
    }

    private func prepareLandscapeMatch() {
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
        guard landscape, isWaitingForLandscape, model.snapshot == nil else { return }
        isWaitingForLandscape = false
        Task { await model.startMatch() }
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
        switch color {
        case .teal: HouseTanksTheme.teal
        case .orange: HouseTanksTheme.orange
        case .blue: HouseTanksTheme.blue
        }
    }

    private func colorAccessibilityName(_ color: HouseTanksColor) -> String {
        switch color {
        case .teal: copy("house_tanks_color_teal")
        case .orange: copy("house_tanks_color_orange")
        case .blue: copy("house_tanks_color_blue")
        }
    }
}

private struct HouseTanksLobbyBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [HouseTanksTheme.deepNavy, HouseTanksTheme.navy],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height * 0.28))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.34, y: geometry.size.height * 0.28))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.34, y: geometry.size.height * 0.52))
                    path.move(to: CGPoint(x: geometry.size.width, y: geometry.size.height * 0.72))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.66, y: geometry.size.height * 0.72))
                    path.addLine(to: CGPoint(x: geometry.size.width * 0.66, y: geometry.size.height * 0.48))
                }
                .stroke(HouseTanksTheme.teal.opacity(0.12), style: StrokeStyle(lineWidth: 5, lineCap: .round, lineJoin: .round))
            }
        }
    }
}

#Preview {
    NavigationStack {
        HouseTanksView()
            .environmentObject(AppViewModel())
    }
}
