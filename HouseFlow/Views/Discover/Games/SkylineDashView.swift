import SwiftUI

// MARK: - Phase
private enum SkylineDashPhase: Equatable {
    case briefing
    case playing
    case crashed
    case gameOver
}

// MARK: - Player Emblem
private enum SkylinePlayerEmblem: String, CaseIterable, Identifiable {
    case paperplane
    case bolt
    case sparkles
    case flame
    case star

    var id: String { rawValue }

    var title: String {
        switch self {
        case .paperplane: return "Glider"
        case .bolt:       return "Bolt"
        case .sparkles:   return "Spark"
        case .flame:      return "Flare"
        case .star:       return "Star"
        }
    }

    var symbol: String {
        switch self {
        case .paperplane: return "paperplane.fill"
        case .bolt:       return "bolt.fill"
        case .sparkles:   return "sparkles"
        case .flame:      return "flame.fill"
        case .star:       return "star.fill"
        }
    }

    var tint: Color {
        switch self {
        case .paperplane: return .indigo
        case .bolt:       return .yellow
        case .sparkles:   return .purple
        case .flame:      return .orange
        case .star:       return .pink
        }
    }

    var rotation: Angle {
        self == .paperplane ? .degrees(-10) : .zero
    }
}

// MARK: - Obstacle
private struct SkyGate: Identifiable, Equatable {
    let id = UUID()
    var x: CGFloat
    var gapCenterY: CGFloat
    var gapHeight: CGFloat
    var scored = false
}

// MARK: - Score Row Model
private struct SkylineScoreEntry: Identifiable {
    let id = UUID()
    let rank: Int
    let name: String
    let score: Int
    let status: String
    let isCurrentPlayer: Bool
}

// MARK: - Skyline Dash View
struct SkylineDashView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var phase: SkylineDashPhase = .briefing
    @State private var playfieldSize: CGSize = .zero
    @State private var playerY: CGFloat = 240
    @State private var velocity: CGFloat = 0
    @State private var gates: [SkyGate] = []
    @State private var score = 0
    @State private var bestScore = 0
    @State private var elapsedTime: TimeInterval = 0
    @State private var resultAppeared = false
    @State private var crashNoticeAppeared = false
    @State private var selectedEmblem: SkylinePlayerEmblem = .paperplane
    @State private var gameTask: Task<Void, Never>?

    private let playerName = "You"
    private let gravity: CGFloat = 1180
    private let flapImpulse: CGFloat = -390
    private let gateSpeed: CGFloat = 156
    private let gateWidth: CGFloat = 66
    private let playerRadius: CGFloat = 18
    private let gateSpacing: CGFloat = 220
    private let minimumGap: CGFloat = 138

    private var playerX: CGFloat {
        max(86, playfieldSize.width * 0.28)
    }

    private var scoreboardEntries: [SkylineScoreEntry] {
        [
            SkylineScoreEntry(
                rank: 1,
                name: playerName,
                score: score,
                status: "Eliminated",
                isCurrentPlayer: true
            ),
        ]
    }

    var body: some View {
        ZStack {
            SkylineBackground()
                .ignoresSafeArea()

            switch phase {
            case .briefing:
                briefingView.transition(.opacity)
            case .playing:
                playingView.transition(.opacity)
            case .crashed:
                crashedView.transition(.opacity)
            case .gameOver:
                gameOverView.transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity))
            }
        }
        .navigationBarBackButtonHidden(phase == .playing || phase == .crashed)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear { stopLoop() }
    }

    // MARK: - Briefing
    private var briefingView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppDesign.Spacing.xl) {
                    VStack(spacing: AppDesign.Spacing.md) {
                        SkylineBadge(size: 104, emblem: selectedEmblem)

                        VStack(spacing: AppDesign.Spacing.xs) {
                            Text("Skyline Dash")
                                .font(AppDesign.Typography.title2)
                                .foregroundStyle(.white)
                            Text("Tap through shared gates. Hit one and your run is over.")
                                .font(AppDesign.Typography.subheadline)
                                .foregroundStyle(Color.white.opacity(0.72))
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    demoRoomPanel
                    emblemPickerPanel
                    rulesPanel
                }
                .padding(.horizontal, AppDesign.Spacing.lg)
                .padding(.top, AppDesign.Spacing.xxl)
                .padding(.bottom, AppDesign.Spacing.xxl)
            }

            Button { startGame() } label: {
                Label("Start Demo Run", systemImage: "paperplane.fill")
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDesign.Size.buttonHeightLarge)
                    .background(
                        LinearGradient(
                            colors: [Color.cyan, Color.indigo],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
                    .shadow(color: Color.cyan.opacity(0.28), radius: 14, x: 0, y: 6)
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.bottom, AppDesign.Spacing.xxxl)
        }
    }

    private var demoRoomPanel: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack {
                Label("Demo Room SD-001", systemImage: "person.wave.2.fill")
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("Solo")
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(Color.cyan)
                    .padding(.horizontal, AppDesign.Spacing.sm)
                    .padding(.vertical, AppDesign.Spacing.xs)
                    .background(Color.cyan.opacity(0.14))
                    .clipShape(Capsule())
            }

            HStack(spacing: AppDesign.Spacing.md) {
                SkylinePilotChip(name: playerName, color: .cyan, isActive: true)
                SkylinePilotChip(name: "Shared gates", color: .indigo, isActive: false)
            }
        }
        .padding(AppDesign.Spacing.lg)
        .background(SkylineTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .stroke(SkylineTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
    }

    private var emblemPickerPanel: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack {
                Label("Choose Your Icon", systemImage: "circle.hexagongrid.fill")
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text(selectedEmblem.title)
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(selectedEmblem.tint)
                    .padding(.horizontal, AppDesign.Spacing.sm)
                    .padding(.vertical, AppDesign.Spacing.xs)
                    .background(selectedEmblem.tint.opacity(0.14))
                    .clipShape(Capsule())
            }

            LazyVGrid(
                columns: [
                    GridItem(.flexible(), spacing: AppDesign.Spacing.sm),
                    GridItem(.flexible(), spacing: AppDesign.Spacing.sm),
                    GridItem(.flexible(), spacing: AppDesign.Spacing.sm),
                ],
                spacing: AppDesign.Spacing.sm
            ) {
                ForEach(SkylinePlayerEmblem.allCases) { emblem in
                    Button {
                        withAnimation(AppDesign.Animation.spring) {
                            selectedEmblem = emblem
                        }
                    } label: {
                        VStack(spacing: AppDesign.Spacing.xs) {
                            ZStack {
                                Circle()
                                    .fill(
                                        LinearGradient(
                                            colors: [Color.white, Color.cyan.opacity(0.92)],
                                            startPoint: .topLeading,
                                            endPoint: .bottomTrailing
                                        )
                                    )
                                    .frame(width: 48, height: 48)
                                    .shadow(
                                        color: emblem == selectedEmblem ? emblem.tint.opacity(0.42) : Color.black.opacity(0.16),
                                        radius: emblem == selectedEmblem ? 10 : 4,
                                        x: 0,
                                        y: 4
                                    )

                                Image(systemName: emblem.symbol)
                                    .font(.system(size: 20, weight: .black))
                                    .foregroundStyle(emblem.tint)
                                    .rotationEffect(emblem.rotation)
                            }

                            Text(emblem.title)
                                .font(AppDesign.Typography.caption2)
                                .foregroundStyle(emblem == selectedEmblem ? .white : Color.white.opacity(0.58))
                                .lineLimit(1)
                                .minimumScaleFactor(0.72)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, AppDesign.Spacing.sm)
                        .background(emblem == selectedEmblem ? emblem.tint.opacity(0.16) : Color.white.opacity(0.06))
                        .overlay(
                            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                                .stroke(emblem == selectedEmblem ? emblem.tint.opacity(0.48) : Color.white.opacity(0.1), lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(AppDesign.Spacing.lg)
        .background(SkylineTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .stroke(SkylineTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
    }

    private var rulesPanel: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Label("Run Rules", systemImage: "list.bullet.rectangle.fill")
                .font(AppDesign.Typography.headline)
                .foregroundStyle(.white)

            VStack(spacing: AppDesign.Spacing.sm) {
                SkylineRuleRow(icon: "hand.tap.fill", color: .cyan, title: "Tap to Climb", detail: "Gravity pulls you down between taps.")
                SkylineRuleRow(icon: "rectangle.split.3x1.fill", color: .indigo, title: "Pass Gates", detail: "Each cleared gate adds one score.")
                SkylineRuleRow(icon: "flag.checkered", color: .orange, title: "Last Survivor Wins", detail: "Demo shows your solo score first.")
            }
        }
        .padding(AppDesign.Spacing.lg)
        .background(SkylineTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .stroke(SkylineTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
    }

    // MARK: - Playing
    private var playingView: some View {
        GeometryReader { geometry in
            ZStack {
                SkylineGameField(
                    size: geometry.size,
                    gates: gates,
                    gateWidth: gateWidth,
                    playerX: playerX,
                    playerY: playerY,
                    playerRadius: playerRadius,
                    velocity: velocity,
                    emblem: selectedEmblem
                )

                playingHUD
            }
            .contentShape(Rectangle())
            .onTapGesture { flap() }
            .onAppear {
                updatePlayfieldSize(geometry.size)
            }
            .onChange(of: geometry.size) { _, newSize in
                updatePlayfieldSize(newSize)
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var crashedView: some View {
        GeometryReader { geometry in
            ZStack {
                SkylineGameField(
                    size: geometry.size,
                    gates: gates,
                    gateWidth: gateWidth,
                    playerX: playerX,
                    playerY: playerY,
                    playerRadius: playerRadius,
                    velocity: velocity,
                    emblem: selectedEmblem
                )
                .saturation(0.82)
                .brightness(-0.06)

                SkylineCrashNotice()
                    .scaleEffect(crashNoticeAppeared ? 1 : 0.82)
                    .opacity(crashNoticeAppeared ? 1 : 0)
                    .animation(.spring(response: 0.36, dampingFraction: 0.68), value: crashNoticeAppeared)
            }
            .onAppear {
                updatePlayfieldSize(geometry.size)
                crashNoticeAppeared = true
            }
            .onChange(of: geometry.size) { _, newSize in
                updatePlayfieldSize(newSize)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                showGameOverFromCrash()
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var playingHUD: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppDesign.Spacing.md) {
                SkylineHUDPill(icon: "number", title: "Score", value: "\(score)", color: .cyan)
                SkylineHUDPill(icon: "timer", title: "Time", value: elapsedLabel, color: .orange)
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.top, AppDesign.Spacing.lg)

            Spacer()

            Text("Tap anywhere")
                .font(AppDesign.Typography.caption)
                .foregroundStyle(Color.white.opacity(0.66))
                .padding(.horizontal, AppDesign.Spacing.md)
                .padding(.vertical, AppDesign.Spacing.sm)
                .background(Color.black.opacity(0.22))
                .clipShape(Capsule())
                .padding(.bottom, AppDesign.Spacing.xxl)
        }
    }

    private var elapsedLabel: String {
        String(format: "%.1fs", elapsedTime)
    }

    // MARK: - Game Over
    private var gameOverView: some View {
        VStack(spacing: AppDesign.Spacing.xxl) {
            Spacer()

            VStack(spacing: AppDesign.Spacing.md) {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.18))
                        .frame(width: 112, height: 112)
                    Image(systemName: selectedEmblem.symbol)
                        .font(.system(size: 48, weight: .bold))
                        .foregroundStyle(selectedEmblem.tint)
                        .rotationEffect(selectedEmblem.rotation)
                }
                .scaleEffect(resultAppeared ? 1 : 0.35)
                .animation(.spring(response: 0.55, dampingFraction: 0.48), value: resultAppeared)

                VStack(spacing: AppDesign.Spacing.xs) {
                    Text("Run Over")
                        .font(.system(size: 34, weight: .black))
                        .foregroundStyle(.white)
                    Text("You cleared \(score) gates")
                        .font(AppDesign.Typography.headline)
                        .foregroundStyle(Color.cyan)
                    Text("Best demo score: \(bestScore)")
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(Color.white.opacity(0.6))
                }
            }
            .opacity(resultAppeared ? 1 : 0)
            .offset(y: resultAppeared ? 0 : 18)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.12), value: resultAppeared)

            scoreboardPanel

            Spacer(minLength: AppDesign.Spacing.md)

            VStack(spacing: AppDesign.Spacing.md) {
                Button { startGame() } label: {
                    Label("Play Again", systemImage: "arrow.clockwise")
                        .font(AppDesign.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeightLarge)
                        .background(
                            LinearGradient(
                                colors: [Color.cyan, Color.indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
                }
                .buttonStyle(ScaleButtonStyle())

                Button { dismiss() } label: {
                    Text("Main Menu")
                        .font(AppDesign.Typography.bodyBold)
                        .foregroundStyle(Color.white.opacity(0.68))
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeight)
                }
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
            .padding(.bottom, AppDesign.Spacing.lg)
            .opacity(resultAppeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.28), value: resultAppeared)
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .onAppear { resultAppeared = true }
    }

    private var scoreboardPanel: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack {
                Label("Scoreboard", systemImage: "list.number")
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("Demo")
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(Color.cyan)
            }

            VStack(spacing: AppDesign.Spacing.sm) {
                ForEach(scoreboardEntries) { entry in
                    SkylineScoreRow(entry: entry)
                }
            }
        }
        .padding(AppDesign.Spacing.lg)
        .background(SkylineTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .stroke(SkylineTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
        .opacity(resultAppeared ? 1 : 0)
        .animation(.spring(response: 0.5, dampingFraction: 0.75).delay(0.2), value: resultAppeared)
    }

    // MARK: - Logic
    private func startGame() {
        let size = playableSize()
        gameTask?.cancel()

        phase = .playing
        score = 0
        elapsedTime = 0
        resultAppeared = false
        crashNoticeAppeared = false
        velocity = 0
        playerY = max(120, size.height * 0.44)
        gates = [
            makeGate(x: size.width + 130, size: size),
            makeGate(x: size.width + 130 + gateSpacing, size: size),
        ]

        gameTask = Task {
            var lastDate = Date()
            while !Task.isCancelled {
                let now = Date()
                let delta = min(now.timeIntervalSince(lastDate), 0.034)
                lastDate = now

                await MainActor.run {
                    tick(delta)
                }

                try? await Task.sleep(nanoseconds: 16_000_000)
            }
        }
    }

    private func stopLoop() {
        gameTask?.cancel()
        gameTask = nil
    }

    private func flap() {
        guard phase == .playing else { return }
        velocity = flapImpulse
    }

    private func tick(_ delta: TimeInterval) {
        guard phase == .playing else { return }
        let size = playableSize()
        let dt = CGFloat(delta)

        elapsedTime += delta
        velocity += gravity * dt
        playerY += velocity * dt

        for index in gates.indices {
            gates[index].x -= gateSpeed * dt
        }

        if let lastGate = gates.last, lastGate.x < size.width - gateSpacing {
            gates.append(makeGate(x: size.width + 40, size: size))
        }

        gates.removeAll { $0.x + gateWidth < -20 }

        for index in gates.indices {
            if !gates[index].scored && gates[index].x + gateWidth < playerX - playerRadius {
                gates[index].scored = true
                score += 1
            }
        }

        if hasCollision(in: size) {
            showCrashNotice()
        }
    }

    private func showCrashNotice() {
        guard phase == .playing else { return }
        bestScore = max(bestScore, score)
        stopLoop()
        resultAppeared = false
        crashNoticeAppeared = false

        withAnimation(.spring(response: 0.45, dampingFraction: 0.76)) {
            phase = .crashed
        }
    }

    private func showGameOverFromCrash() {
        guard phase == .crashed else { return }
        crashNoticeAppeared = false
        withAnimation(.spring(response: 0.45, dampingFraction: 0.76)) {
            phase = .gameOver
        }
    }

    private func updatePlayfieldSize(_ size: CGSize) {
        guard size.width > 0, size.height > 0 else { return }
        let wasWaitingForSize = playfieldSize == .zero
        playfieldSize = size

        if wasWaitingForSize, phase == .playing, score == 0 {
            playerY = max(120, size.height * 0.44)
            gates = [
                makeGate(x: size.width + 130, size: size),
                makeGate(x: size.width + 130 + gateSpacing, size: size),
            ]
        }
    }

    private func playableSize() -> CGSize {
        if playfieldSize.width > 0, playfieldSize.height > 0 {
            return playfieldSize
        }

        return CGSize(width: 390, height: 720)
    }

    private func makeGate(x: CGFloat, size: CGSize) -> SkyGate {
        let safeTop: CGFloat = 120
        let safeBottom = max(safeTop + minimumGap, size.height - 150)
        let gapCenter = CGFloat.random(in: safeTop...safeBottom)
        let gap = CGFloat.random(in: minimumGap...(minimumGap + 34))

        return SkyGate(x: x, gapCenterY: gapCenter, gapHeight: gap)
    }

    private func hasCollision(in size: CGSize) -> Bool {
        if playerY - playerRadius < 0 || playerY + playerRadius > size.height {
            return true
        }

        for gate in gates {
            let gateLeft = gate.x
            let gateRight = gate.x + gateWidth
            let overlapsX = playerX + playerRadius > gateLeft && playerX - playerRadius < gateRight

            guard overlapsX else { continue }

            let gapTop = gate.gapCenterY - gate.gapHeight / 2
            let gapBottom = gate.gapCenterY + gate.gapHeight / 2
            let hitsPipe = playerY - playerRadius < gapTop || playerY + playerRadius > gapBottom

            if hitsPipe {
                return true
            }
        }

        return false
    }
}

// MARK: - Theme
private enum SkylineTheme {
    static let surface = Color.black.opacity(0.24)
    static let border = Color.white.opacity(0.16)
}

// MARK: - Background
private struct SkylineBackground: View {
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(hex: "07111F"),
                    Color(hex: "123D61"),
                    Color(hex: "1F7A8C"),
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            Circle()
                .fill(Color.cyan.opacity(0.18))
                .frame(width: 240, height: 240)
                .blur(radius: 18)
                .offset(x: 130, y: -260)

            Circle()
                .fill(Color.orange.opacity(0.14))
                .frame(width: 220, height: 220)
                .blur(radius: 24)
                .offset(x: -150, y: 280)
        }
    }
}

// MARK: - Game Field
private struct SkylineGameField: View {
    let size: CGSize
    let gates: [SkyGate]
    let gateWidth: CGFloat
    let playerX: CGFloat
    let playerY: CGFloat
    let playerRadius: CGFloat
    let velocity: CGFloat
    let emblem: SkylinePlayerEmblem

    var body: some View {
        ZStack {
            SkylineBackground()
            skylineSilhouette

            ForEach(gates) { gate in
                SkylineGateView(gate: gate, gateWidth: gateWidth, fieldHeight: size.height)
            }

            SkylinePlayerView(radius: playerRadius, velocity: velocity, emblem: emblem)
                .position(x: playerX, y: playerY)
        }
        .clipped()
    }

    private var skylineSilhouette: some View {
        VStack {
            Spacer()
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(0..<9, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.black.opacity(0.26))
                        .frame(width: 32, height: CGFloat([88, 120, 74, 138, 104, 158, 96, 130, 82][index]))
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, -12)
        }
        .allowsHitTesting(false)
    }
}

// MARK: - Gate View
private struct SkylineGateView: View {
    let gate: SkyGate
    let gateWidth: CGFloat
    let fieldHeight: CGFloat

    private var gapTop: CGFloat {
        max(0, gate.gapCenterY - gate.gapHeight / 2)
    }

    private var gapBottom: CGFloat {
        min(fieldHeight, gate.gapCenterY + gate.gapHeight / 2)
    }

    var body: some View {
        ZStack(alignment: .topLeading) {
            pipe(height: gapTop)
                .position(x: gate.x + gateWidth / 2, y: gapTop / 2)

            pipe(height: max(0, fieldHeight - gapBottom))
                .position(x: gate.x + gateWidth / 2, y: gapBottom + max(0, fieldHeight - gapBottom) / 2)
        }
    }

    private func pipe(height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 14)
            .fill(
                LinearGradient(
                    colors: [Color.green.opacity(0.9), Color.teal.opacity(0.92)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .frame(width: gateWidth, height: height)
            .shadow(color: Color.black.opacity(0.22), radius: 8, x: 0, y: 4)
    }
}

// MARK: - Player View
private struct SkylinePlayerView: View {
    let radius: CGFloat
    let velocity: CGFloat
    let emblem: SkylinePlayerEmblem

    private var rotation: Double {
        Double(max(-28, min(34, velocity / 18)))
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(
                    LinearGradient(
                        colors: [Color.white, Color.cyan.opacity(0.92)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: radius * 2, height: radius * 2)
                .shadow(color: Color.cyan.opacity(0.45), radius: 10, x: 0, y: 4)

            Image(systemName: emblem.symbol)
                .font(.system(size: radius * 0.92, weight: .black))
                .foregroundStyle(emblem.tint)
                .rotationEffect(emblem.rotation)
                .offset(x: 1)
        }
        .rotationEffect(.degrees(rotation))
    }
}

// MARK: - Badge
private struct SkylineBadge: View {
    let size: CGFloat
    let emblem: SkylinePlayerEmblem

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [Color.cyan, Color.indigo],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color.cyan.opacity(0.3), radius: 14, x: 0, y: 6)

            Image(systemName: emblem.symbol)
                .font(.system(size: size * 0.42, weight: .black))
                .foregroundStyle(.white)
                .rotationEffect(emblem.rotation)
        }
    }
}

// MARK: - Crash Notice
private struct SkylineCrashNotice: View {
    var body: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: "xmark.octagon.fill")
                    .font(.system(size: 26, weight: .black))
                    .foregroundStyle(Color.red)
            }

            VStack(spacing: 3) {
                Text("You Crashed!")
                    .font(.system(size: 22, weight: .black))
                    .foregroundStyle(Color.red)
            }

            Text("Tap anywhere")
                .font(AppDesign.Typography.caption2)
                .foregroundStyle(Color.white.opacity(0.52))
                .padding(.top, AppDesign.Spacing.xs)
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.vertical, AppDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .fill(Color.black.opacity(0.72))
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                        .stroke(Color.red.opacity(0.38), lineWidth: 1)
                )
                .shadow(color: Color.red.opacity(0.24), radius: 18, x: 0, y: 8)
        )
    }
}

// MARK: - HUD Pill
private struct SkylineHUDPill: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(color)

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(AppDesign.Typography.caption2)
                    .foregroundStyle(Color.white.opacity(0.56))
                Text(value)
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundStyle(.white)
            }
        }
        .padding(.horizontal, AppDesign.Spacing.md)
        .padding(.vertical, AppDesign.Spacing.sm)
        .background(Color.black.opacity(0.28))
        .overlay(
            Capsule()
                .stroke(Color.white.opacity(0.14), lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

// MARK: - Pilot Chip
private struct SkylinePilotChip: View {
    let name: String
    let color: Color
    let isActive: Bool

    var body: some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)
            Text(name)
                .font(AppDesign.Typography.caption)
                .foregroundStyle(isActive ? Color.white : Color.white.opacity(0.62))
        }
        .padding(.horizontal, AppDesign.Spacing.sm)
        .padding(.vertical, AppDesign.Spacing.xs)
        .background(isActive ? color.opacity(0.16) : Color.white.opacity(0.08))
        .clipShape(Capsule())
    }
}

// MARK: - Rule Row
private struct SkylineRuleRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.16))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundStyle(.white)
                Text(detail)
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(Color.white.opacity(0.66))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

// MARK: - Score Row
private struct SkylineScoreRow: View {
    let entry: SkylineScoreEntry

    var body: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            Text("#\(entry.rank)")
                .font(AppDesign.Typography.caption)
                .foregroundStyle(Color.white.opacity(0.56))
                .frame(width: 34, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(entry.name)
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundStyle(.white)
                Text(entry.status)
                    .font(AppDesign.Typography.caption2)
                    .foregroundStyle(Color.white.opacity(0.58))
            }

            Spacer()

            Text("\(entry.score)")
                .font(AppDesign.Typography.headline)
                .foregroundStyle(Color.cyan)
        }
        .padding(AppDesign.Spacing.md)
        .background(entry.isCurrentPlayer ? Color.cyan.opacity(0.14) : Color.white.opacity(0.08))
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                .stroke(entry.isCurrentPlayer ? Color.cyan.opacity(0.32) : Color.white.opacity(0.1), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
    }
}
