import SwiftUI
import FausCrewCore

/// The dashboard's playful progress metric: what share of the listed chores is completed. It
/// takes a third of the row beside the game stats card. A tap squishes the card, spins the ring,
/// pops the percentage and throws a burst of sparks; every fifth tap (and any tap at 100%) throws
/// a bigger one.
struct ChoreProgressCard: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// The chores the Active Chores card lists (active and history alike).
    let chores: [Chore]

    @State private var taps = 0
    @State private var ringSpin: Double = 0
    @State private var shownProgress: Double = 0
    @State private var sparks: [ProgressSpark] = []

    /// The ring's size; the card stands as tall as the game stats card beside it.
    static let ringSize: CGFloat = 72

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
            VStack(spacing: AppDesign.Spacing.sm) {
                ring
                VStack(spacing: 2) {
                    Text(title)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(AppDesign.Colors.textTertiary)
                        .textCase(.uppercase)
                        .tracking(0.6)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(subtitle)
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(AppDesign.Colors.textSecondary)
                        .multilineTextAlignment(.center)
                        // The whole text, never cut short; a long one shrinks instead.
                        .lineLimit(nil)
                        .minimumScaleFactor(0.6)
                }
            }
            .padding(.horizontal, AppDesign.Spacing.sm)
            .padding(.vertical, AppDesign.Spacing.md)
            // Ring and text together always sit in the middle of the card, however long the text.
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .dashboardMetricCard(glowOffset: CGSize(width: 45, height: 70))
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
        .accessibilityLabel("\(title), \(tier.message(appViewModel)), \(subtitle)")
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
        .frame(width: Self.ringSize, height: Self.ringSize)
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

// MARK: - Card chrome

extension View {
    /// The surface, sheen, tint, orange glow and border shared by the dashboard's metric cards
    /// (progress and game stats), so the two cards in one row read as a pair.
    func dashboardMetricCard(glowOffset: CGSize) -> some View {
        let shape = RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
        return background {
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
            // An overlay, not a ZStack child: the glow is larger than a narrow card and would
            // otherwise stretch the background past the border.
            .overlay {
                Circle()
                    .fill(HouseJourneyTheme.accentOrange.opacity(0.06))
                    .frame(width: 140, height: 140)
                    .offset(glowOffset)
            }
            .clipShape(shape)
        }
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [HouseJourneyTheme.teal.opacity(0.22), HouseJourneyTheme.indigo.opacity(0.12)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        )
        .shadow(color: HouseJourneyTheme.deepIndigo.opacity(0.09), radius: 14, x: 0, y: 6)
    }
}

// MARK: - Tier

private enum ProgressTier {
    case empty, start, warming, closing, done

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
