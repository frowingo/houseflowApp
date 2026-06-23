import SwiftUI

// MARK: - Vault Theme
private enum VaultTheme {
    static let background = Color(hex: "070A0F")
    static let surface = Color(hex: "111827")
    static let elevated = Color(hex: "172033")
    static let border = Color.white.opacity(0.08)
    static let textPrimary = Color.white.opacity(0.96)
    static let textSecondary = Color.white.opacity(0.68)
    static let textTertiary = Color.white.opacity(0.46)
}

// MARK: - Phase
private enum VaultRushPhase: Equatable {
    case setup
    case planning
    case reveal
    case result(CleanupOutcome)
}

// MARK: - Outcome
private enum CleanupOutcome: Equatable {
    case cleaned
    case alarm
    case timeUp

    var title: String {
        switch self {
        case .cleaned: return "Vault Cleared"
        case .alarm: return "Alarm Blown"
        case .timeUp: return "Getaway Time"
        }
    }

    var icon: String {
        switch self {
        case .cleaned: return "dollarsign.circle.fill"
        case .alarm: return "bell.fill"
        case .timeUp: return "timer"
        }
    }

    var color: Color {
        switch self {
        case .cleaned: return .teal
        case .alarm: return .red
        case .timeUp: return .indigo
        }
    }

    var verdict: String {
        switch self {
        case .cleaned:
            return "The crew filled the bag. Lowest loot contribution gets the chore."
        case .alarm:
            return "The alarm blew. Highest heat becomes the fall guy."
        case .timeUp:
            return "The van is leaving. Lowest loot contribution gets the chore."
        }
    }
}

// MARK: - Move
private enum CleanupMove: String, CaseIterable, Identifiable {
    case quietSweep
    case turboScrub
    case fridgeRaid
    case alibi

    var id: String { rawValue }

    var title: String {
        switch self {
        case .quietSweep: return "Silent Grab"
        case .turboScrub: return "Vault Drill"
        case .fridgeRaid: return "Pocket Bonus"
        case .alibi: return "Lookout"
        }
    }

    var systemImage: String {
        switch self {
        case .quietSweep: return "bag.fill"
        case .turboScrub: return "lock.open.fill"
        case .fridgeRaid: return "dollarsign.circle.fill"
        case .alibi: return "eye.fill"
        }
    }

    var clean: Int {
        switch self {
        case .quietSweep: return 3
        case .turboScrub: return 5
        case .fridgeRaid: return 1
        case .alibi: return 0
        }
    }

    var noise: Int {
        switch self {
        case .quietSweep: return 1
        case .turboScrub: return 3
        case .fridgeRaid: return 3
        case .alibi: return -2
        }
    }

    var suspicion: Int {
        switch self {
        case .quietSweep: return 0
        case .turboScrub: return 1
        case .fridgeRaid: return 4
        case .alibi: return -1
        }
    }

    var color: Color {
        switch self {
        case .quietSweep: return .teal
        case .turboScrub: return .orange
        case .fridgeRaid: return .pink
        case .alibi: return .indigo
        }
    }

    var summary: String {
        switch self {
        case .quietSweep: return "+3 loot, +1 alarm"
        case .turboScrub: return "+5 loot, +3 alarm"
        case .fridgeRaid: return "+1 loot, +4 heat"
        case .alibi: return "-2 alarm, lower heat"
        }
    }

    static func mockChoice(round: Int, noiseLevel: Int, maxNoise: Int) -> CleanupMove {
        if noiseLevel >= maxNoise - 3 {
            return Bool.random() ? .quietSweep : .alibi
        }

        if round == 1 {
            return [.quietSweep, .quietSweep, .turboScrub, .fridgeRaid].randomElement() ?? .quietSweep
        }

        return CleanupMove.allCases.randomElement() ?? .quietSweep
    }
}

// MARK: - Player
private struct CleanupPlayer: Identifiable, Equatable {
    let id = UUID()
    let name: String
    var cleanScore = 0
    var noiseScore = 0
    var suspicion = 0
    var hasAlibi = false
}

// MARK: - Reveal
private struct CleanupReveal: Identifiable, Equatable {
    let id = UUID()
    let playerName: String
    let move: CleanupMove
    let clean: Int
    let noise: Int
    let suspicion: Int
}

// MARK: - Vault Rush View
struct VaultRushView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var members: [String] = ["Ali", "Ayşe", "Mehmet", "Fatma"]
    @State private var readyMembers: Set<String> = ["Ali"]
    @State private var newMemberName = ""
    @State private var showAddField = false
    @State private var phase: VaultRushPhase = .setup
    @State private var players: [CleanupPlayer] = []
    @State private var selectedMove: CleanupMove = .quietSweep
    @State private var revealEntries: [CleanupReveal] = []
    @State private var pendingOutcome: CleanupOutcome?
    @State private var round = 1
    @State private var cleanMeter = 0
    @State private var noiseMeter = 0
    @State private var resultAppeared = false

    private let targetClean = 24
    private let maxNoise = 12
    private let maxRounds = 4

    private var allReady: Bool {
        members.count >= 2 && members.allSatisfy { readyMembers.contains($0) }
    }

    private var currentPlayerName: String {
        players.first?.name ?? members.first ?? "You"
    }

    var body: some View {
        ZStack {
            VaultTheme.background.ignoresSafeArea()

            switch phase {
            case .setup:
                setupView.transition(.opacity)
            case .planning:
                planningView.transition(.opacity)
            case .reveal:
                revealView.transition(.asymmetric(insertion: .move(edge: .trailing).combined(with: .opacity), removal: .opacity))
            case .result(let outcome):
                resultView(for: outcome).transition(.asymmetric(insertion: .scale(scale: 0.92).combined(with: .opacity), removal: .opacity))
            }
        }
        .environment(\.colorScheme, .dark)
        .navigationBarBackButtonHidden(phase != .setup)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Setup
    private var setupView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppDesign.Spacing.xl) {
                    setupHeader
                    missionBriefPanel
                    CleanupMemberList(
                        members: $members,
                        readyMembers: $readyMembers,
                        newMemberName: $newMemberName,
                        showAddField: $showAddField,
                        onAddMember: addMember
                    )
                    readyRoomPanel
                }
                .padding(.horizontal, AppDesign.Spacing.lg)
                .padding(.top, AppDesign.Spacing.xxl)
                .padding(.bottom, AppDesign.Spacing.xxl)
            }

            startRoomButton
        }
    }

    private var setupHeader: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            VaultDoorIcon(size: 104)

            VStack(spacing: AppDesign.Spacing.xs) {
                Text("Vault Rush")
                    .font(AppDesign.Typography.title2)
                    .foregroundStyle(VaultTheme.textPrimary)
                Text("Crack the bank vault, fill the loot bag, and keep the alarm from pinning the job on you.")
                    .font(AppDesign.Typography.subheadline)
                    .foregroundStyle(VaultTheme.textSecondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var missionBriefPanel: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Label("The Job", systemImage: "building.columns.fill")
                .font(AppDesign.Typography.headline)
                .foregroundStyle(VaultTheme.textPrimary)

            VStack(spacing: AppDesign.Spacing.sm) {
                HeistRuleRow(
                    icon: "bag.fill",
                    color: .teal,
                    title: "Fill the Loot Bag",
                    detail: "Reach \(targetClean) loot before the getaway."
                )
                HeistRuleRow(
                    icon: "bell.fill",
                    color: .orange,
                    title: "Avoid Alarm",
                    detail: "If alarm hits \(maxNoise), highest heat loses."
                )
                HeistRuleRow(
                    icon: "flame.fill",
                    color: .red,
                    title: "Watch Heat",
                    detail: "Greedy or noisy moves put the fall-guy mark on you."
                )
            }
        }
        .padding(AppDesign.Spacing.lg)
        .background(VaultTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .stroke(VaultTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
    }

    private var readyRoomPanel: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack {
                Label("Masked Crew HF-042", systemImage: "person.3.fill")
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(VaultTheme.textPrimary)
                Spacer()
                Text("\(readyMembers.count)/\(members.count)")
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(allReady ? Color.teal : VaultTheme.textSecondary)
                    .padding(.horizontal, AppDesign.Spacing.sm)
                    .padding(.vertical, AppDesign.Spacing.xs)
                    .background((allReady ? Color.teal : Color.gray).opacity(0.16))
                    .clipShape(Capsule())
            }

            VStack(spacing: AppDesign.Spacing.sm) {
                ForEach(members.indices, id: \.self) { index in
                    let member = members[index]
                    HStack(spacing: AppDesign.Spacing.sm) {
                        Image(systemName: readyMembers.contains(member) ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(readyMembers.contains(member) ? Color.teal : VaultTheme.textTertiary)
                        Text(member)
                            .font(AppDesign.Typography.bodyBold)
                            .foregroundStyle(VaultTheme.textPrimary)
                        Spacer()
                        Text(readyMembers.contains(member) ? "Ready" : "Waiting")
                            .font(AppDesign.Typography.caption)
                            .foregroundStyle(readyMembers.contains(member) ? Color.teal : VaultTheme.textSecondary)
                    }
                    .padding(AppDesign.Spacing.md)
                    .background(VaultTheme.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                            .stroke(VaultTheme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
                }
            }

            Button { mockReadyVote() } label: {
                Label(readyMembers.count == members.count ? "Reset Crew Votes" : "Mock Crew Ready", systemImage: "checkmark.seal.fill")
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundStyle(Color.teal)
                    .frame(maxWidth: .infinity)
                    .padding(AppDesign.Spacing.md)
                    .background(Color.teal.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
            }
            .buttonStyle(ScaleButtonStyle())
        }
        .padding(AppDesign.Spacing.lg)
        .background(VaultTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .stroke(VaultTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
    }

    private var startRoomButton: some View {
        Button { startGame() } label: {
            Label("Start Vault Rush", systemImage: "play.fill")
                .font(AppDesign.Typography.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .frame(height: AppDesign.Size.buttonHeightLarge)
                .background(allReady ? Color.teal : Color.gray.opacity(0.4))
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
        }
        .disabled(!allReady)
        .buttonStyle(ScaleButtonStyle())
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.bottom, AppDesign.Spacing.xxxl)
    }

    // MARK: - Planning
    private var planningView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppDesign.Spacing.xl) {
                    gameHeader
                    meterPanel
                    movePicker
                    rosterPanel
                }
                .padding(.horizontal, AppDesign.Spacing.lg)
                .padding(.top, AppDesign.Spacing.xxl)
                .padding(.bottom, AppDesign.Spacing.xxl)
            }

            Button { resolveRound() } label: {
                Label("Lock \(currentPlayerName)'s Move", systemImage: "lock.fill")
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDesign.Size.buttonHeightLarge)
                    .background(selectedMove.color)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.bottom, AppDesign.Spacing.xxxl)
        }
    }

    private var gameHeader: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.12))
                    .frame(width: 52, height: 52)
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 24, weight: .semibold))
                    .foregroundStyle(Color.teal)
            }

            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                Text("Round \(round) of \(maxRounds)")
                    .font(AppDesign.Typography.title3)
                    .foregroundStyle(VaultTheme.textPrimary)
                Text("You lock \(currentPlayerName)'s move. The rest of the crew is mocked.")
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(VaultTheme.textSecondary)
            }

            Spacer()
        }
    }

    private var meterPanel: some View {
        VStack(spacing: AppDesign.Spacing.lg) {
            CleanupMeterRow(
                title: "Loot",
                value: cleanMeter,
                total: targetClean,
                color: .teal,
                icon: "bag.fill"
            )
            CleanupMeterRow(
                title: "Alarm",
                value: noiseMeter,
                total: maxNoise,
                color: noiseMeter >= maxNoise - 3 ? .red : .orange,
                icon: "waveform"
            )
        }
        .padding(AppDesign.Spacing.lg)
        .background(VaultTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .stroke(VaultTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
    }

    private var movePicker: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Text("Heist Move")
                .font(AppDesign.Typography.headline)
                .foregroundStyle(VaultTheme.textPrimary)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppDesign.Spacing.md) {
                ForEach(CleanupMove.allCases) { move in
                    Button { selectedMove = move } label: {
                        CleanupMoveCard(move: move, isSelected: selectedMove == move)
                    }
                    .buttonStyle(ScaleButtonStyle())
                }
            }
        }
    }

    private var rosterPanel: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Text("Heat Board")
                .font(AppDesign.Typography.headline)
                .foregroundStyle(VaultTheme.textPrimary)

            VStack(spacing: AppDesign.Spacing.sm) {
                ForEach(players) { player in
                    CleanupPlayerScoreRow(player: player, risk: riskScore(for: player))
                }
            }
        }
    }

    // MARK: - Reveal
    private var revealView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppDesign.Spacing.xl) {
                    revealHeader
                    meterPanel
                    revealList
                }
                .padding(.horizontal, AppDesign.Spacing.lg)
                .padding(.top, AppDesign.Spacing.xxl)
                .padding(.bottom, AppDesign.Spacing.xxl)
            }

            Button { continueAfterReveal() } label: {
                Label(pendingOutcome == nil ? "Next Round" : "Reveal Result", systemImage: pendingOutcome == nil ? "arrow.right" : "flag.checkered")
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: AppDesign.Size.buttonHeightLarge)
                    .background(pendingOutcome?.color ?? Color.teal)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
            }
            .buttonStyle(ScaleButtonStyle())
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.bottom, AppDesign.Spacing.xxxl)
        }
    }

    private var revealHeader: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.12))
                    .frame(width: 76, height: 76)
                Image(systemName: pendingOutcome?.icon ?? "rectangle.stack.fill")
                    .font(.system(size: 34, weight: .semibold))
                    .foregroundStyle(pendingOutcome?.color ?? Color.teal)
            }

            Text(pendingOutcome?.title ?? "Moves Revealed")
                .font(AppDesign.Typography.title2)
                .foregroundStyle(VaultTheme.textPrimary)
            Text(pendingOutcome?.verdict ?? "The crew slipped past this checkpoint. Keep loot ahead of the alarm.")
                .font(AppDesign.Typography.subheadline)
                .foregroundStyle(VaultTheme.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private var revealList: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            ForEach(revealEntries) { entry in
                HStack(spacing: AppDesign.Spacing.md) {
                    ZStack {
                        Circle()
                            .fill(entry.move.color.opacity(0.12))
                            .frame(width: 44, height: 44)
                        Image(systemName: entry.move.systemImage)
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(entry.move.color)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.playerName)
                            .font(AppDesign.Typography.bodyBold)
                            .foregroundStyle(VaultTheme.textPrimary)
                        Text(entry.move.title)
                            .font(AppDesign.Typography.caption)
                            .foregroundStyle(VaultTheme.textSecondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text("+\(entry.clean) loot")
                            .font(AppDesign.Typography.caption)
                            .foregroundStyle(Color.teal)
                        Text(deltaText(entry.noise, label: "alarm"))
                            .font(AppDesign.Typography.caption)
                            .foregroundStyle(entry.noise > 0 ? Color.orange : Color.indigo)
                    }
                }
                .padding(AppDesign.Spacing.md)
                .background(VaultTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                        .stroke(VaultTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
            }
        }
    }

    // MARK: - Result
    private func resultView(for outcome: CleanupOutcome) -> some View {
        let loser = losingPlayer(for: outcome)
        let reason = resultReason(for: outcome, loser: loser)

        return VStack(spacing: AppDesign.Spacing.xxxl) {
            Spacer()

            ZStack {
                Circle()
                    .fill(outcome.color.opacity(0.13))
                    .frame(width: 118, height: 118)
                Image(systemName: outcome.icon)
                    .font(.system(size: 54, weight: .bold))
                    .foregroundStyle(outcome.color)
            }
            .scaleEffect(resultAppeared ? 1 : 0.35)
            .animation(.spring(response: 0.55, dampingFraction: 0.48), value: resultAppeared)

            VStack(spacing: AppDesign.Spacing.sm) {
                Text(outcome.title)
                    .font(.system(size: 34, weight: .black))
                    .foregroundStyle(outcome.color)
                    .multilineTextAlignment(.center)
                Text("\(loser.name) gets the chore")
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(VaultTheme.textPrimary)
                    .multilineTextAlignment(.center)
                Text(outcome.verdict)
                    .font(AppDesign.Typography.subheadline)
                    .foregroundStyle(VaultTheme.textSecondary)
                    .multilineTextAlignment(.center)
                Text(reason)
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(VaultTheme.textTertiary)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppDesign.Spacing.xs)
            }
            .opacity(resultAppeared ? 1 : 0)
            .offset(y: resultAppeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.2), value: resultAppeared)

            finalScoreboard(highlightedID: loser.id)

            Spacer()

            VStack(spacing: AppDesign.Spacing.md) {
                Button { resetGame() } label: {
                    Label("Run It Back", systemImage: "arrow.clockwise")
                        .font(AppDesign.Typography.headline)
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeightLarge)
                        .background(outcome.color)
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
                }
                .buttonStyle(ScaleButtonStyle())

                Button { dismiss() } label: {
                    Text("Main Menu")
                        .font(AppDesign.Typography.bodyBold)
                        .foregroundStyle(VaultTheme.textSecondary)
                        .frame(maxWidth: .infinity)
                        .frame(height: AppDesign.Size.buttonHeight)
                }
            }
            .opacity(resultAppeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.38), value: resultAppeared)
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.bottom, AppDesign.Spacing.xxxl)
        .onAppear { resultAppeared = true }
    }

    private func finalScoreboard(highlightedID: UUID) -> some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            ForEach(players.sorted { riskScore(for: $0) > riskScore(for: $1) }) { player in
                HStack(spacing: AppDesign.Spacing.sm) {
                    Image(systemName: player.id == highlightedID ? "target" : "circle.fill")
                        .font(.system(size: player.id == highlightedID ? 18 : 8, weight: .semibold))
                        .foregroundStyle(player.id == highlightedID ? Color.red : VaultTheme.textTertiary)
                        .frame(width: 22)
                    Text(player.name)
                        .font(AppDesign.Typography.bodyBold)
                        .foregroundStyle(VaultTheme.textPrimary)
                    Spacer()
                    Text("\(player.cleanScore) loot")
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(Color.teal)
                    Text("\(riskScore(for: player)) heat")
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(Color.orange)
                }
                .padding(AppDesign.Spacing.md)
                .background(player.id == highlightedID ? Color.red.opacity(0.16) : VaultTheme.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                        .stroke(player.id == highlightedID ? Color.red.opacity(0.35) : VaultTheme.border, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
            }
        }
    }

    // MARK: - Logic
    private func addMember() {
        let trimmed = newMemberName.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        guard !members.contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) else { return }

        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            members.append(trimmed)
            newMemberName = ""
            showAddField = false
        }
    }

    private func mockReadyVote() {
        withAnimation(.spring(response: 0.35, dampingFraction: 0.75)) {
            if readyMembers.count == members.count {
                readyMembers.removeAll()
                return
            }

            if let nextMember = members.first(where: { !readyMembers.contains($0) }) {
                readyMembers.insert(nextMember)
            }
        }
    }

    private func startGame() {
        guard allReady else { return }

        players = members.map { CleanupPlayer(name: $0) }
        selectedMove = .quietSweep
        revealEntries = []
        pendingOutcome = nil
        round = 1
        cleanMeter = 0
        noiseMeter = 0
        resultAppeared = false

        withAnimation(.easeInOut(duration: 0.25)) {
            phase = .planning
        }
    }

    private func resolveRound() {
        guard !players.isEmpty else { return }

        var newEntries: [CleanupReveal] = []
        var cleanGain = 0
        var noiseGain = 0

        for index in players.indices {
            let move = index == 0 ? selectedMove : CleanupMove.mockChoice(round: round, noiseLevel: noiseMeter, maxNoise: maxNoise)
            let playerName = players[index].name

            players[index].cleanScore += move.clean
            players[index].noiseScore += max(move.noise, 0)
            players[index].suspicion = max(0, players[index].suspicion + move.suspicion)
            players[index].hasAlibi = move == .alibi

            cleanGain += move.clean
            noiseGain += move.noise

            newEntries.append(
                CleanupReveal(
                    playerName: playerName,
                    move: move,
                    clean: move.clean,
                    noise: move.noise,
                    suspicion: move.suspicion
                )
            )
        }

        cleanMeter = min(targetClean, cleanMeter + cleanGain)
        noiseMeter = max(0, min(maxNoise, noiseMeter + noiseGain))
        revealEntries = newEntries
        pendingOutcome = nextOutcome()

        withAnimation(.spring(response: 0.45, dampingFraction: 0.76)) {
            phase = .reveal
        }
    }

    private func continueAfterReveal() {
        if let outcome = pendingOutcome {
            resultAppeared = false
            withAnimation(.spring(response: 0.45, dampingFraction: 0.72)) {
                phase = .result(outcome)
            }
            return
        }

        round += 1
        selectedMove = suggestedMove()

        withAnimation(.easeInOut(duration: 0.25)) {
            phase = .planning
        }
    }

    private func nextOutcome() -> CleanupOutcome? {
        if cleanMeter >= targetClean {
            return .cleaned
        }

        if noiseMeter >= maxNoise {
            return .alarm
        }

        if round >= maxRounds {
            return .timeUp
        }

        return nil
    }

    private func suggestedMove() -> CleanupMove {
        if noiseMeter >= maxNoise - 3 {
            return .alibi
        }

        if targetClean - cleanMeter <= 6 {
            return .turboScrub
        }

        return .quietSweep
    }

    private func resetGame() {
        readyMembers.removeAll()
        players = []
        revealEntries = []
        pendingOutcome = nil
        round = 1
        cleanMeter = 0
        noiseMeter = 0
        resultAppeared = false

        withAnimation(.easeInOut(duration: 0.25)) {
            phase = .setup
        }
    }

    private func losingPlayer(for outcome: CleanupOutcome) -> CleanupPlayer {
        switch outcome {
        case .cleaned, .timeUp:
            return players.min { lhs, rhs in
                if lhs.cleanScore == rhs.cleanScore {
                    return riskScore(for: lhs) > riskScore(for: rhs)
                }
                return lhs.cleanScore < rhs.cleanScore
            } ?? CleanupPlayer(name: "Someone")
        case .alarm:
            return players.max { riskScore(for: $0) < riskScore(for: $1) } ?? CleanupPlayer(name: "Someone")
        }
    }

    private func resultReason(for outcome: CleanupOutcome, loser: CleanupPlayer) -> String {
        switch outcome {
        case .cleaned:
            return "\(loser.name) brought in the least loot: \(loser.cleanScore)."
        case .alarm:
            return "\(loser.name) had the highest heat score: \(riskScore(for: loser))."
        case .timeUp:
            return "\(loser.name) had the least loot when the van left: \(loser.cleanScore)."
        }
    }

    private func riskScore(for player: CleanupPlayer) -> Int {
        max(0, player.suspicion + player.noiseScore - (player.hasAlibi ? 2 : 0))
    }

    private func deltaText(_ value: Int, label: String) -> String {
        value >= 0 ? "+\(value) \(label)" : "\(value) \(label)"
    }
}

// MARK: - Vault Door Icon
private struct VaultDoorIcon: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hex: "05070C"),
                            Color(hex: "111827"),
                            Color(hex: "134E4A"),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: size, height: size)
                .shadow(color: Color.teal.opacity(0.28), radius: 12, x: 0, y: 6)

            Image(systemName: "building.columns.fill")
                .font(.system(size: size * 0.18, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.24))
                .offset(y: -size * 0.31)

            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: size * 0.64, height: size * 0.64)

            Circle()
                .stroke(Color.white.opacity(0.85), lineWidth: 4)
                .frame(width: size * 0.52, height: size * 0.52)

            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.88))
                    .frame(width: size * 0.2, height: 4)
                    .offset(x: size * 0.17)
                    .rotationEffect(.degrees(Double(index) * 60))
            }

            Circle()
                .fill(Color.white)
                .frame(width: size * 0.2, height: size * 0.2)

            Image(systemName: "dollarsign")
                .font(.system(size: size * 0.13, weight: .black))
                .foregroundStyle(Color.teal)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Rule Row
private struct HeistRuleRow: View {
    let icon: String
    let color: Color
    let title: String
    let detail: String

    var body: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(color.opacity(0.12))
                    .frame(width: 36, height: 36)
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(color)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundStyle(VaultTheme.textPrimary)
                Text(detail)
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(VaultTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer()
        }
    }
}

// MARK: - Member List
private struct CleanupMemberList: View {
    @Binding var members: [String]
    @Binding var readyMembers: Set<String>
    @Binding var newMemberName: String
    @Binding var showAddField: Bool
    let onAddMember: () -> Void

    var body: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            ForEach(members.indices, id: \.self) { index in
                VaultCrewRow(name: members[index], canDelete: members.count > 2) {
                    deleteMember(at: index)
                }
            }
            addMemberControl
        }
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: showAddField)
    }

    private func deleteMember(at index: Int) {
        let member = members[index]
        withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
            members.remove(at: index)
            readyMembers.remove(member)
        }
    }

    @ViewBuilder
    private var addMemberControl: some View {
        if showAddField {
            HStack(spacing: AppDesign.Spacing.md) {
                TextField("Enter name...", text: $newMemberName)
                    .font(AppDesign.Typography.body)
                    .foregroundStyle(VaultTheme.textPrimary)
                    .padding(AppDesign.Spacing.md)
                    .background(VaultTheme.elevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                            .stroke(VaultTheme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
                    .onSubmit { onAddMember() }

                Button { onAddMember() } label: {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.teal)
                }
            }
            .transition(.move(edge: .top).combined(with: .opacity))
        } else {
            Button {
                withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                    showAddField = true
                }
            } label: {
                Label("Add Member", systemImage: "plus.circle")
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundStyle(Color.teal)
                    .frame(maxWidth: .infinity)
                    .padding(AppDesign.Spacing.md)
                    .background(Color.teal.opacity(0.14))
                    .overlay(
                        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                            .stroke(VaultTheme.border, lineWidth: 1)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
            }
            .transition(.opacity)
        }
    }
}

// MARK: - Crew Row
private struct VaultCrewRow: View {
    let name: String
    let canDelete: Bool
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.14))
                    .frame(width: 36, height: 36)
                Image(systemName: "person.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Color.teal)
            }

            Text(name)
                .font(AppDesign.Typography.bodyBold)
                .foregroundStyle(VaultTheme.textPrimary)

            Spacer()

            if canDelete {
                Button(action: onDelete) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.red.opacity(0.85))
                }
            }
        }
        .padding(AppDesign.Spacing.md)
        .background(VaultTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                .stroke(VaultTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
    }
}

// MARK: - Meter Row
private struct CleanupMeterRow: View {
    let title: String
    let value: Int
    let total: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            HStack {
                Label(title, systemImage: icon)
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundStyle(VaultTheme.textPrimary)
                Spacer()
                Text("\(value)/\(total)")
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(VaultTheme.textSecondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                    Capsule()
                        .fill(color)
                        .frame(width: geometry.size.width * min(CGFloat(value) / CGFloat(total), 1))
                }
            }
            .frame(height: 10)
        }
    }
}

// MARK: - Move Card
private struct CleanupMoveCard: View {
    let move: CleanupMove
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.sm) {
            HStack {
                ZStack {
                    Circle()
                        .fill(move.color.opacity(0.14))
                        .frame(width: 38, height: 38)
                    Image(systemName: move.systemImage)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(move.color)
                }
                Spacer()
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(isSelected ? move.color : VaultTheme.textTertiary)
            }

            Text(move.title)
                .font(AppDesign.Typography.bodyBold)
                .foregroundStyle(VaultTheme.textPrimary)
                .multilineTextAlignment(.leading)

            Text(move.summary)
                .font(AppDesign.Typography.caption)
                .foregroundStyle(VaultTheme.textSecondary)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(AppDesign.Spacing.md)
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .background(isSelected ? move.color.opacity(0.13) : VaultTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                .stroke(isSelected ? move.color : VaultTheme.border, lineWidth: isSelected ? 2 : 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
    }
}

// MARK: - Player Score Row
private struct CleanupPlayerScoreRow: View {
    let player: CleanupPlayer
    let risk: Int

    var body: some View {
        HStack(spacing: AppDesign.Spacing.md) {
            ZStack {
                Circle()
                    .fill(Color.teal.opacity(0.14))
                    .frame(width: 38, height: 38)
                Text(String(player.name.prefix(2)).uppercased())
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(Color.teal)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(player.name)
                    .font(AppDesign.Typography.bodyBold)
                    .foregroundStyle(VaultTheme.textPrimary)
                Text(player.hasAlibi ? "On lookout" : "No cover")
                    .font(AppDesign.Typography.caption2)
                    .foregroundStyle(VaultTheme.textSecondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(player.cleanScore) loot")
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(Color.teal)
                Text("\(risk) heat")
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(risk >= 6 ? Color.red : Color.orange)
            }
        }
        .padding(AppDesign.Spacing.md)
        .background(VaultTheme.surface)
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                .stroke(VaultTheme.border, lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md))
    }
}
