import SwiftUI
import FausCrewCore

/// The dashboard's game standings, two thirds of the row beside the progress card. The title
/// names the selected game (or "Overall"); a peak line joins the members in the backend's order,
/// each node as high as their wins; small tiles with each game's own figure switch the game.
/// It loads when it appears, so finishing a match and coming back to the dashboard refreshes it.
struct GameStatsCard: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ObservedObject var store: GameStatsStore
    let members: [User]
    let currentUserID: String?
    let houseID: String?

    @State private var selectedTab: GameStatsTab?
    @State private var focusedUser: String?

    var body: some View {
        let board = GameStatsBoard.make(
            stats: store.stats,
            memberIDs: members.compactMap(\.apiId),
            knownGameKeys: OnlineGameVisual.knownGameKeys
        )
        let tabs = Self.tabs(of: board)
        let tab = selectedTab.flatMap { tabs.contains($0) ? $0 : nil } ?? tabs.first
        let section = tab.flatMap { Self.section(for: $0, in: board) }

        VStack(alignment: .leading, spacing: 5) {
            header(tab: tab)
            content(board: board, section: section, tab: tab)
                .frame(height: 82)
            caption(section: section)
            if !tabs.isEmpty {
                HStack(spacing: 7) {
                    ForEach(tabs, id: \.self) { item in
                        GameStatsTabTile(tab: item, isSelected: item == tab, title: title(of: item)) {
                            withAnimation(reduceMotion ? nil : .spring(response: 0.4, dampingFraction: 0.7)) {
                                selectedTab = item
                            }
                        }
                    }
                }
                .padding(.leading, 2)
            }
        }
        .padding(AppDesign.Spacing.md)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .dashboardMetricCard(glowOffset: CGSize(width: 120, height: 90))
        .onChange(of: tab) { _, _ in focusedUser = nil }
        .task(id: houseID) { await store.refresh() }
    }

    // MARK: - Header and caption

    /// A small "Game stats:" label, the selected game's name (or "Overall") beside it.
    private func header(tab: GameStatsTab?) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text(text("game_stats_title", tr: "Oyun istatistikleri", en: "Game stats") + ":")
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(AppDesign.Colors.textTertiary)
                .textCase(.uppercase)
                .tracking(0.4)
                .lineLimit(1)
                .fixedSize()

            if let tab {
                Text(title(of: tab))
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundStyle(AppDesign.Colors.textPrimary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .id(tab)
                    .transition(.opacity)
            }

            Spacer(minLength: 0)
        }
        .frame(height: 18)
    }

    /// The focused member's record (or "Ranking"), with the leader in small type on the right.
    private func caption(section: GameStatsBoard.Section?) -> some View {
        HStack(spacing: AppDesign.Spacing.xs) {
            Group {
                if let id = focusedUser, let standing = section?.standings.first(where: { $0.userId == id }),
                   let user = member(id) {
                    Text("\(user.firstName) · \(record(standing))")
                } else if section != nil {
                    Text(text("game_stats_ranking", tr: "Sıralama", en: "Ranking"))
                } else {
                    Text(" ")
                }
            }
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .foregroundStyle(AppDesign.Colors.textSecondary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)

            Spacer(minLength: 0)

            if let leader = section?.standings.first(where: \.isLeader), let user = member(leader.userId) {
                HStack(spacing: 2) {
                    Image(systemName: "crown.fill").font(.system(size: 8, weight: .bold))
                    Text(user.firstName).font(.system(size: 10, weight: .semibold, design: .rounded))
                }
                .foregroundStyle(HouseJourneyTheme.accentOrangeDeep)
                .lineLimit(1)
                .fixedSize()
            }
        }
        .frame(height: 13)
    }

    // MARK: - Content

    @ViewBuilder
    private func content(board: GameStatsBoard, section: GameStatsBoard.Section?, tab: GameStatsTab?) -> some View {
        if let section {
            PeakLineChart(
                standings: section.standings.filter { member($0.userId) != nil },
                members: membersByID,
                currentUserID: currentUserID,
                focusedUser: $focusedUser,
                resetKey: tab
            )
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(summary(section))
        } else if store.phase == .loaded {
            message(text("game_stats_empty", tr: "Henüz tamamlanmış oyun yok", en: "No finished games yet"),
                    symbol: "gamecontroller")
        } else if store.phase == .failed {
            VStack(spacing: AppDesign.Spacing.xs) {
                message(store.failureMessage ?? text("game_stats_error", tr: "İstatistikler yüklenemedi", en: "Couldn't load the stats"),
                        symbol: "exclamationmark.triangle")
                Button(text("game_stats_retry", tr: "Tekrar dene", en: "Try again")) {
                    Task { await store.refresh() }
                }
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(HouseJourneyTheme.teal)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ProgressView()
                .controlSize(.small)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func message(_ message: String, symbol: String) -> some View {
        VStack(spacing: AppDesign.Spacing.xs) {
            Image(systemName: symbol)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HouseJourneyTheme.teal.opacity(0.7))
            Text(message)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(AppDesign.Colors.textSecondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Data

    /// "Overall" first, then the games in the backend's order.
    private static func tabs(of board: GameStatsBoard) -> [GameStatsTab] {
        (board.overall == nil ? [] : [.overall])
            + board.games.compactMap { $0.gameKey.flatMap(OnlineGameVisual.init(gameKey:)).map(GameStatsTab.game) }
    }

    private static func section(for tab: GameStatsTab, in board: GameStatsBoard) -> GameStatsBoard.Section? {
        switch tab {
        case .game(let visual): board.games.first { $0.gameKey == visual.gameKey }
        case .overall: board.overall
        }
    }

    private var membersByID: [String: User] {
        Dictionary(members.compactMap { user in user.apiId.map { ($0, user) } }, uniquingKeysWith: { first, _ in first })
    }

    private func member(_ id: String) -> User? { members.first { $0.apiId == id } }

    private func title(of tab: GameStatsTab) -> String {
        switch tab {
        case .game(let visual): appViewModel.localized(visual.titleKey)
        case .overall: text("game_stats_overall_title", tr: "Genel", en: "Overall")
        }
    }

    private func record(_ standing: GameStatsBoard.Standing) -> String {
        guard standing.hasPlayed else { return text("game_stats_not_played", tr: "oynamadı", en: "didn't play") }
        return text("game_stats_record", tr: "{wins} galibiyet / {matches} maç", en: "{wins} wins / {matches} matches")
            .replacingOccurrences(of: "{wins}", with: "\(standing.wins)")
            .replacingOccurrences(of: "{matches}", with: "\(standing.matchesPlayed)")
    }

    /// The whole ranking as one sentence, since VoiceOver does not scroll the chart.
    private func summary(_ section: GameStatsBoard.Section) -> String {
        section.standings.enumerated().compactMap { index, standing in
            member(standing.userId).map { "\(index + 1). \($0.name), \(record(standing))" }
        }
        .joined(separator: "; ")
    }

    private func text(_ key: String, tr: String, en: String) -> String {
        appViewModel.localized(key, tr: tr, en: en)
    }
}

enum GameStatsTab: Hashable {
    case game(OnlineGameVisual)
    case overall
}

// MARK: - Tiles

/// A small square with the game's own figure; no text. The selected one is teal and the figure
/// does its move: the robot jumps, the rocket lifts off, the tank turns, the bars grow.
private struct GameStatsTabTile: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let tab: GameStatsTab
    let isSelected: Bool
    let title: String
    let action: () -> Void

    @State private var moves = 0
    private static let size: CGFloat = 32

    var body: some View {
        Button {
            guard !isSelected else { return }
            action()
            moves += 1
        } label: {
            figure
                .frame(width: 22, height: 22)
                .opacity(isSelected ? 1 : 0.5)
                .keyframeAnimator(initialValue: TileMove(), trigger: reduceMotion ? 0 : moves) { content, move in
                    content
                        .offset(x: move.x, y: move.y)
                        .rotationEffect(.degrees(move.angle))
                        .scaleEffect(move.scale)
                } keyframes: { _ in
                    let peak = TileMove.peak(for: tab)
                    KeyframeTrack(\.y) {
                        SpringKeyframe(peak.y, duration: 0.18)
                        SpringKeyframe(0, duration: 0.32, spring: .bouncy)
                    }
                    KeyframeTrack(\.x) {
                        SpringKeyframe(peak.x, duration: 0.18)
                        SpringKeyframe(0, duration: 0.32, spring: .bouncy)
                    }
                    KeyframeTrack(\.angle) {
                        SpringKeyframe(peak.angle, duration: 0.18)
                        SpringKeyframe(0, duration: 0.32, spring: .bouncy)
                    }
                    KeyframeTrack(\.scale) {
                        SpringKeyframe(peak.scale, duration: 0.15)
                        SpringKeyframe(1, duration: 0.3, spring: .bouncy)
                    }
                }
                .frame(width: Self.size, height: Self.size)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(isSelected ? HouseJourneyTheme.teal.opacity(0.14) : AppDesign.Colors.controlFill)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .strokeBorder(isSelected ? HouseJourneyTheme.teal : AppDesign.Colors.hairline,
                                      lineWidth: isSelected ? 1.5 : 1)
                )
                .scaleEffect(isSelected ? 1.08 : 1)
                // A finger-sized target around the small square.
                .contentShape(Rectangle().inset(by: -6))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder private var figure: some View {
        switch tab {
        case .game(let visual):
            visual.artwork
        case .overall:
            Image(systemName: "chart.bar.fill")
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(HouseJourneyTheme.teal)
        }
    }
}

private struct TileMove {
    var x: CGFloat = 0
    var y: CGFloat = 0
    var angle: Double = 0
    var scale: CGFloat = 1

    /// The top of each figure's move: the robot jumps, the rocket lifts off up and right, the
    /// tank turns its barrel, the bars grow.
    static func peak(for tab: GameStatsTab) -> TileMove {
        switch tab {
        case .game(.fausSwitch): TileMove(y: -6)
        case .game(.houseRockets): TileMove(x: 4, y: -6)
        case .game(.houseTanks): TileMove(angle: 18)
        case .overall: TileMove(scale: 1.25)
        }
    }
}

// MARK: - Peak line

/// Members left to right in ranking order, each node as high as their wins, joined by one line.
/// Up to four members share the width; more scroll sideways inside the same area at a fixed step.
private struct PeakLineChart: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    let standings: [GameStatsBoard.Standing]
    let members: [String: User]
    let currentUserID: String?
    @Binding var focusedUser: String?
    /// The selected tab: a change scrolls back to the leader, then to the user's own node.
    let resetKey: GameStatsTab?

    @State private var drawn: CGFloat = 0
    @State private var atStart = true
    @State private var atEnd = false

    private static let fittingCount = 4
    private static let step: CGFloat = 48
    private static let nodeSize: CGFloat = 22
    private static let leaderSize: CGFloat = 26
    private static let fade: CGFloat = 18

    var body: some View {
        GeometryReader { geometry in
            if standings.count > Self.fittingCount {
                let width = CGFloat(standings.count) * Self.step
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        canvas(width: width, height: geometry.size.height)
                    }
                    .onScrollGeometryChange(for: [Bool].self) { scroll in
                        [scroll.contentOffset.x <= 1,
                         scroll.contentOffset.x + scroll.containerSize.width >= scroll.contentSize.width - 1]
                    } action: { _, edges in
                        atStart = edges[0]
                        atEnd = edges[1]
                    }
                    .mask(edgeMask)
                    .task(id: resetKey) { await scrollToOwnNode(proxy) }
                }
            } else {
                canvas(width: geometry.size.width, height: geometry.size.height)
            }
        }
        .onAppear {
            if reduceMotion { drawn = 1 } else {
                withAnimation(.easeOut(duration: 0.8).delay(0.25)) { drawn = 1 }
            }
        }
    }

    private var edgeMask: some View {
        HStack(spacing: 0) {
            LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                .frame(width: atStart ? 0 : Self.fade)
            Color.black
            LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                .frame(width: atEnd ? 0 : Self.fade)
        }
        .animation(.easeOut(duration: 0.2), value: atStart)
        .animation(.easeOut(duration: 0.2), value: atEnd)
    }

    /// Back to the leader, and on to the user's own node when it is out of sight.
    private func scrollToOwnNode(_ proxy: ScrollViewProxy) async {
        guard let first = standings.first?.userId else { return }
        proxy.scrollTo(first, anchor: .leading)
        guard let own = currentUserID, let index = standings.firstIndex(where: { $0.userId == own }),
              index >= Self.fittingCount else { return }
        try? await Task.sleep(for: .milliseconds(450))
        guard !Task.isCancelled else { return }
        if reduceMotion {
            proxy.scrollTo(own, anchor: .center)
        } else {
            withAnimation(.easeInOut(duration: 0.5)) { proxy.scrollTo(own, anchor: .center) }
        }
    }

    private func canvas(width: CGFloat, height: CGFloat) -> some View {
        let points = points(width: width, height: height)
        let baseline = height - 3
        return ZStack(alignment: .topLeading) {
            // Scroll anchors, one column per member.
            HStack(spacing: 0) {
                ForEach(standings, id: \.userId) { standing in
                    Color.clear.frame(width: width / CGFloat(max(standings.count, 1)), height: 1).id(standing.userId)
                }
            }

            Path { path in
                path.move(to: CGPoint(x: 2, y: baseline))
                path.addLine(to: CGPoint(x: width - 2, y: baseline))
            }
            .stroke(AppDesign.Colors.hairline, lineWidth: 1)

            PeakShape(values: AnimatableVector(points), baseline: baseline, drops: true)
                .stroke(AppDesign.Colors.textTertiary.opacity(0.45), style: StrokeStyle(lineWidth: 1, dash: [2, 3]))

            PeakShape(values: AnimatableVector(points), baseline: baseline, drops: false)
                .trim(from: 0, to: drawn)
                .stroke(
                    LinearGradient(colors: [HouseJourneyTheme.teal, HouseJourneyTheme.indigo],
                                   startPoint: .leading, endPoint: .trailing),
                    style: StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round)
                )

            ForEach(Array(zip(standings, points)), id: \.0.userId) { standing, point in
                node(standing)
                    .position(point)
            }
        }
        .frame(width: width, height: height)
        .animation(reduceMotion ? nil : .spring(response: 0.55, dampingFraction: 0.72), value: standings)
    }

    private func points(width: CGFloat, height: CGFloat) -> [CGPoint] {
        let count = max(standings.count, 1)
        let column = width / CGFloat(count)
        let maxWins = max(standings.map(\.wins).max() ?? 0, 1)
        // Room above the highest node for its count, below the lowest for the "Sen" label.
        let top: CGFloat = 20 + Self.leaderSize / 2
        let bottom = height - 8 - Self.nodeSize / 2
        return standings.enumerated().map { index, standing in
            let share = CGFloat(standing.wins) / CGFloat(maxWins)
            return CGPoint(x: column * (CGFloat(index) + 0.5), y: bottom - share * (bottom - top))
        }
    }

    private func node(_ standing: GameStatsBoard.Standing) -> some View {
        let size = standing.isLeader ? Self.leaderSize : Self.nodeSize
        let isMe = standing.userId == currentUserID
        let dimmed = !standing.hasPlayed || (focusedUser != nil && focusedUser != standing.userId)
        return ZStack {
            if let user = members[standing.userId] {
                UserAvatar(user: user, size: size)
                    .opacity(dimmed ? 0.35 : 1)
            }
        }
        .frame(width: size, height: size)
        .overlay {
            if standing.isLeader {
                Circle().strokeBorder(HouseJourneyTheme.accentOrange, lineWidth: 2).padding(-3)
            }
        }
        .overlay {
            if isMe {
                Circle().strokeBorder(HouseJourneyTheme.teal, lineWidth: 2).padding(standing.isLeader ? -6 : -3)
            }
        }
        .overlay(alignment: .top) {
            // Just above the outermost ring.
            let reach: CGFloat = standing.isLeader && isMe ? 6 : (standing.isLeader || isMe ? 3 : 0)
            Text(standing.hasPlayed ? "\(standing.wins)" : "—")
                .font(.system(size: 11, weight: .bold, design: .rounded))
                .foregroundStyle(AppDesign.Colors.textSecondary)
                .fixedSize()
                .alignmentGuide(.top) { $0[.bottom] + reach + 1 }
        }
        .overlay(alignment: .bottom) {
            if isMe {
                Text(appViewModel.localized("game_stats_you", tr: "Sen", en: "You"))
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 1)
                    .background(HouseJourneyTheme.teal, in: Capsule())
                    .fixedSize()
                    .offset(y: 7)
            }
        }
        .scaleEffect(focusedUser == standing.userId ? 1.15 : 1)
        .contentShape(Circle().inset(by: -8))
        .onTapGesture {
            withAnimation(reduceMotion ? nil : .spring(response: 0.3, dampingFraction: 0.7)) {
                focusedUser = focusedUser == standing.userId ? nil : standing.userId
            }
        }
    }
}

/// The peak line, or the dashed drops from each node to the baseline. The points animate, so a
/// game switch slides the nodes and bends the line along with them.
private struct PeakShape: Shape {
    var values: AnimatableVector
    let baseline: CGFloat
    let drops: Bool

    var animatableData: AnimatableVector {
        get { values }
        set { values = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let points = values.points
        var path = Path()
        if drops {
            for point in points {
                path.move(to: CGPoint(x: point.x, y: point.y + 12))
                path.addLine(to: CGPoint(x: point.x, y: baseline))
            }
        } else if let first = points.first {
            path.move(to: first)
            for point in points.dropFirst() { path.addLine(to: point) }
        }
        return path
    }
}

/// Points as a flat list of coordinates that SwiftUI can interpolate. Lists of different
/// lengths are padded with zeros, which only happens when the member list itself changes.
private struct AnimatableVector: VectorArithmetic {
    var values: [Double]

    init(_ points: [CGPoint]) { values = points.flatMap { [Double($0.x), Double($0.y)] } }
    private init(values: [Double]) { self.values = values }

    var points: [CGPoint] {
        stride(from: 0, to: values.count - 1, by: 2).map { CGPoint(x: values[$0], y: values[$0 + 1]) }
    }

    static var zero: AnimatableVector { AnimatableVector(values: []) }

    static func + (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
        combine(lhs, rhs, +)
    }

    static func - (lhs: AnimatableVector, rhs: AnimatableVector) -> AnimatableVector {
        combine(lhs, rhs, -)
    }

    mutating func scale(by rhs: Double) { values = values.map { $0 * rhs } }

    var magnitudeSquared: Double { values.reduce(0) { $0 + $1 * $1 } }

    private static func combine(_ lhs: AnimatableVector, _ rhs: AnimatableVector,
                                _ operation: (Double, Double) -> Double) -> AnimatableVector {
        let count = max(lhs.values.count, rhs.values.count)
        return AnimatableVector(values: (0..<count).map { index in
            operation(index < lhs.values.count ? lhs.values[index] : 0, index < rhs.values.count ? rhs.values[index] : 0)
        })
    }
}
