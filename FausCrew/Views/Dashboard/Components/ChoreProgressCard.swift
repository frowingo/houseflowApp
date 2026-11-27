import SwiftUI
import FausCrewCore

/// The dashboard's playful progress metric: what share of the listed chores is completed.
/// A tap squishes the card, spins the ring, pops the percentage, waves the chore dots and
/// throws a burst of sparks; every fifth tap (and any tap at 100%) throws a bigger one.
struct ChoreProgressCard: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The chores the Active Chores card lists (active and history alike).
    let chores: [Chore]

    @State private var taps = 0
    @State private var ringSpin: Double = 0
    @State private var shownProgress: Double = 0
    @State private var sparks: [ProgressSpark] = []

    /// Above this many chores the dots get too thin; a plain bar takes their place.
    private let maxDots = 12

    /// The dashboard header's content height (66pt house image in a 3pt frame); with the same
    /// vertical padding the two cards stand equally tall.
    static let contentHeight: CGFloat = 72

    private var total: Int { chores.count }
    private var completed: Int { chores.filter { $0.choreStatus == .completed }.count }
    private var progress: Double { total == 0 ? 0 : Double(completed) / Double(total) }

    /// Floored so 199 of 200 never reads as 100%.
    private var percent: Int {
        if total > 0 && completed == total { return 100 }
        return Int(progress * 100)
    }

    var body: some View {
        Button(action: celebrate) {
            HStack(spacing: AppDesign.Spacing.lg) {
                ring
                details
            }
            .frame(height: Self.contentHeight)
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.vertical, AppDesign.Spacing.xl)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground)
            .overlay(cardBorder)
            .shadow(color: HouseJourneyTheme.deepIndigo.opacity(0.09), radius: 14, x: 0, y: 6)
        }
        .buttonStyle(CatalogPressStyle(scale: 0.965))
        .onAppear {
            withAnimation(.spring(response: 0.9, dampingFraction: 0.8).delay(0.35)) {
                shownProgress = progress
            }
        }
        .onChange(of: progress) { _, newValue in
            withAnimation(.spring(response: 0.7, dampingFraction: 0.75)) {
                shownProgress = newValue
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(tier.message(appViewModel))")
        .accessibilityValue(percentText)
    }

    // MARK: - Ring

    private var ring: some View {
        ZStack {
            Circle()
                .stroke(HouseJourneyTheme.indigo.opacity(0.12), lineWidth: 7)

            if shownProgress > 0 {
                Circle()
                    .trim(from: 0, to: shownProgress)
                    .stroke(
                        LinearGradient(
                            colors: [HouseJourneyTheme.teal, HouseJourneyTheme.indigo],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 7, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90 + ringSpin))
            }

            Text(percentText)
                .font(.system(size: 17, weight: .heavy, design: .rounded))
                .foregroundStyle(HouseJourneyTheme.deepIndigo)
                .contentTransition(.numericText(value: Double(percent)))
                .animation(.snappy, value: percent)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .keyframeAnimator(initialValue: 1.0, trigger: motionTaps) { content, scale in
                    content.scaleEffect(scale)
                } keyframes: { _ in
                    KeyframeTrack {
                        SpringKeyframe(1.28, duration: 0.14)
                        SpringKeyframe(0.9, duration: 0.14)
                        SpringKeyframe(1.0, duration: 0.32, spring: .bouncy)
                    }
                }

            ForEach(sparks) { spark in
                ProgressSparkView(spark: spark)
            }
            .allowsHitTesting(false)
        }
        .frame(width: Self.contentHeight, height: Self.contentHeight)
    }

    // MARK: - Details

    private var details: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(alignment: .center) {
                Text(title)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(AppDesign.Colors.textTertiary)
                    .textCase(.uppercase)
                    .tracking(0.6)
                    .lineLimit(1)

                Spacer(minLength: AppDesign.Spacing.sm)

                tierBadge
            }

            Spacer(minLength: 0)

            Text(tier.message(appViewModel))
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundStyle(AppDesign.Colors.textPrimary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Text(subtitle)
                .font(.system(size: 12))
                .foregroundStyle(AppDesign.Colors.textSecondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 0)

            if total > 0 {
                if total <= maxDots { choreDots } else { progressBar }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
    }

    private var tierBadge: some View {
        Image(systemName: tier.symbol)
            .font(.system(size: 11, weight: .bold))
            .foregroundStyle(.white)
            .symbolEffect(.bounce, value: motionTaps)
            .frame(width: 22, height: 22)
            .background(
                LinearGradient(
                    colors: [HouseJourneyTheme.accentOrange, HouseJourneyTheme.accentOrangeDeep],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                in: Circle()
            )
            .keyframeAnimator(initialValue: 0.0, trigger: motionTaps) { content, angle in
                content.rotationEffect(.degrees(angle))
            } keyframes: { _ in
                KeyframeTrack {
                    LinearKeyframe(-18, duration: 0.07)
                    LinearKeyframe(16, duration: 0.09)
                    LinearKeyframe(-10, duration: 0.09)
                    LinearKeyframe(6, duration: 0.08)
                    SpringKeyframe(0, duration: 0.2)
                }
            }
    }

    /// One dot per chore, completed ones first; they wave left to right on a tap.
    private var choreDots: some View {
        HStack(spacing: 5) {
            ForEach(0..<total, id: \.self) { index in
                Capsule()
                    .fill(
                        index < completed
                            ? AnyShapeStyle(LinearGradient(
                                colors: [HouseJourneyTheme.teal, HouseJourneyTheme.indigo],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            : AnyShapeStyle(HouseJourneyTheme.indigo.opacity(0.14))
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: 6)
                    .keyframeAnimator(initialValue: 0.0, trigger: motionTaps) { content, lift in
                        content.offset(y: lift)
                    } keyframes: { _ in
                        KeyframeTrack {
                            LinearKeyframe(0, duration: 0.001 + Double(index) * 0.045)
                            SpringKeyframe(-6, duration: 0.13)
                            SpringKeyframe(0, duration: 0.35, spring: .bouncy)
                        }
                    }
            }
        }
        .animation(.spring(response: 0.5, dampingFraction: 0.8), value: completed)
    }

    private var progressBar: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                Capsule().fill(HouseJourneyTheme.indigo.opacity(0.14))
                Capsule()
                    .fill(LinearGradient(
                        colors: [HouseJourneyTheme.teal, HouseJourneyTheme.indigo],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                    .frame(width: geometry.size.width * shownProgress)
            }
        }
        .frame(height: 6)
    }

    // MARK: - Card chrome

    private var cardBackground: some View {
        ZStack {
            HouseJourneyTheme.surface
            FausCardSheen()

            LinearGradient(
                colors: [
                    HouseJourneyTheme.teal.opacity(0.07),
                    HouseJourneyTheme.indigo.opacity(0.04),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

        }
        // An overlay, not a ZStack child: the 140pt glow is taller than the 112pt card and
        // would otherwise stretch the background past the border.
        .overlay {
            Circle()
                .fill(HouseJourneyTheme.accentOrange.opacity(0.06))
                .frame(width: 140, height: 140)
                .offset(x: 150, y: 50)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
    }

    private var cardBorder: some View {
        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
            .strokeBorder(
                LinearGradient(
                    colors: [HouseJourneyTheme.teal.opacity(0.22), HouseJourneyTheme.indigo.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
    }

    // MARK: - Copy

    private var title: String {
        appViewModel.localized("chore_progress_title", tr: "İlerleme", en: "Progress")
    }

    private var percentText: String {
        appViewModel.localized("progress_percent_template", replacements: ["percent": "\(percent)"])
    }

    private var subtitle: String {
        if total == 0 {
            return appViewModel.localized(
                "chore_progress_empty_subtitle",
                tr: "Görev eklenince ilerleme burada görünecek",
                en: "Progress shows up here once chores are added"
            )
        }
        return appViewModel.localized(
            "todays_tasks_completed_template",
            replacements: ["completed": "\(completed)", "total": "\(total)"]
        )
    }

    private var tier: ProgressTier {
        if total == 0 { return .empty }
        if completed == total { return .done }
        if completed == 0 { return .start }
        return progress < 0.5 ? .warming : .closing
    }

    // MARK: - Tap fun

    /// Motion keyframes run off this; it stays put under Reduce Motion so only haptics remain.
    private var motionTaps: Int { reduceMotion ? 0 : taps }

    private func celebrate() {
        taps += 1
        let big = tier == .done || taps % 5 == 0
        if big {
            UINotificationFeedbackGenerator().notificationOccurred(.success)
        } else {
            UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        }
        guard !reduceMotion else { return }

        withAnimation(.spring(response: 0.75, dampingFraction: 0.6)) {
            ringSpin += 360
        }
        launchSparks(count: big ? 18 : 10)
    }

    private func launchSparks(count: Int) {
        let palette = [
            HouseJourneyTheme.indigo, HouseJourneyTheme.teal, HouseJourneyTheme.accentOrange,
            HouseJourneyTheme.purple, HouseJourneyTheme.blue
        ]
        let symbols = ["star.fill", "sparkle", "circle.fill", "heart.fill", "triangle.fill"]
        let start = Double.random(in: 0..<360)
        let batch = (0..<count).map { index in
            ProgressSpark(
                angle: start + Double(index) * 360 / Double(count) + .random(in: -12...12),
                distance: .random(in: 42...74),
                symbol: symbols.randomElement() ?? "star.fill",
                color: palette.randomElement() ?? HouseJourneyTheme.indigo,
                size: .random(in: 6...11),
                spin: .random(in: -240...240)
            )
        }
        sparks.append(contentsOf: batch)

        let ids = Set(batch.map(\.id))
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(950))
            sparks.removeAll { ids.contains($0.id) }
        }
    }
}

// MARK: - Tier

private enum ProgressTier {
    case empty, start, warming, closing, done

    var symbol: String {
        switch self {
        case .empty: return "sparkles"
        case .start: return "checklist.unchecked"
        case .warming: return "flame.fill"
        case .closing: return "bolt.fill"
        case .done: return "trophy.fill"
        }
    }

    @MainActor
    func message(_ appViewModel: AppViewModel) -> String {
        switch self {
        case .empty:
            return appViewModel.localized("chore_progress_tier_empty", tr: "Liste boş, sahne senin!", en: "The list is empty, the stage is yours!")
        case .start:
            return appViewModel.localized("chore_progress_tier_start", tr: "Hadi ilk görevi kapatalım!", en: "Let's knock out the first one!")
        case .warming:
            return appViewModel.localized("chore_progress_tier_warming", tr: "Isınıyoruz, devam!", en: "Warming up, keep going!")
        case .closing:
            return appViewModel.localized("chore_progress_tier_closing", tr: "Yarıyı geçtik, az kaldı!", en: "Past halfway, almost there!")
        case .done:
            return appViewModel.localized("chore_progress_tier_done", tr: "Hepsi tamam, harikasınız!", en: "All done, you rock!")
        }
    }
}

// MARK: - Sparks

private struct ProgressSpark: Identifiable {
    let id = UUID()
    let angle: Double
    let distance: CGFloat
    let symbol: String
    let color: Color
    let size: CGFloat
    let spin: Double
}

/// One spark flying out of the ring's centre: it travels and spins first, then fades.
private struct ProgressSparkView: View {
    let spark: ProgressSpark
    @State private var launched = false
    @State private var faded = false

    var body: some View {
        let radians = spark.angle * .pi / 180
        Image(systemName: spark.symbol)
            .font(.system(size: spark.size, weight: .bold))
            .foregroundStyle(spark.color)
            .rotationEffect(.degrees(launched ? spark.spin : 0))
            .scaleEffect(launched ? 0.55 : 1.1)
            .offset(
                x: launched ? cos(radians) * spark.distance : 0,
                y: launched ? sin(radians) * spark.distance : 0
            )
            .opacity(faded ? 0 : 1)
            .onAppear {
                withAnimation(.easeOut(duration: 0.7)) { launched = true }
                withAnimation(.easeIn(duration: 0.4).delay(0.35)) { faded = true }
            }
    }
}

#if DEBUG
#Preview("Halfway") {
    let viewModel = AppViewModel.preview
    let user = User(name: "John", points: 10)
    return ChoreProgressCard(chores: [
        Chore(title: "Clean kitchen", description: "", assignedTo: user, dueLabel: "Today"),
        Chore(title: "Take out trash", description: "", assignedTo: user, dueLabel: "Today"),
        Chore(title: "Vacuum", description: "", assignedTo: user, dueLabel: "Today")
    ])
    .padding()
    .environmentObject(viewModel)
}

#Preview("Empty") {
    ChoreProgressCard(chores: [])
        .padding()
        .environmentObject(AppViewModel.preview)
}
#endif
