import SpriteKit
import SwiftUI

private enum HouseSwitchTheme {
    static let skyTop = Color(hex: "071827")
    static let skyBottom = Color(hex: "123D4B")
    static let mint = Color(hex: "31D7C5")
    static let orange = Color(hex: "F28A3A")
    static let ink = Color.white.opacity(0.96)
    static let secondaryInk = Color.white.opacity(0.72)
    static let panel = Color(hex: "0A1C2D").opacity(0.92)
}

struct HouseSwitchView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var appViewModel: AppViewModel
    @StateObject private var model = HouseSwitchViewModel()
    @AccessibilityFocusState private var isOverlayPrimaryActionFocused: Bool
    @State private var isLandscapeLayout = false
    @State private var isWaitingForLandscape = false
    @State private var orientationRequestFailed = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                HouseSwitchBackdrop(progress: model.progress, reduceMotion: reduceMotion)
                    .ignoresSafeArea()

                SpriteView(scene: model.scene, options: [.allowsTransparency])
                    .ignoresSafeArea()
                    .opacity(model.phase == .briefing ? 0.28 : 1)
                    .allowsHitTesting(model.phase == .playing)
                    .accessibilityElement()
                    .accessibilityAddTraits(.isButton)
                    .accessibilityLabel(copy("house_switch_playfield_accessibility"))
                    .accessibilityHint(copy("house_switch_playfield_hint"))
                    .accessibilityHidden(model.phase != .playing)
                    .accessibilityAction {
                        model.flipGravity()
                    }

                switch model.phase {
                case .briefing:
                    briefingView
                        .transition(.opacity)
                case .playing:
                    playingHUD
                        .transition(.opacity)
                case .paused:
                    playingHUD
                        .accessibilityHidden(true)
                        .allowsHitTesting(false)
                    stateOverlay(
                        title: copy("house_switch_paused"),
                        detail: copy("house_switch_paused_detail"),
                        icon: "pause.fill",
                        accent: HouseSwitchTheme.mint,
                        primaryTitle: copy("house_switch_resume"),
                        primaryIcon: "play.fill",
                        primaryAction: model.resumeRun
                    )
                case .crashed:
                    resultOverlay(finished: false)
                case .finished:
                    resultOverlay(finished: true)
                }
            }
            .onAppear { handleViewportSize(geometry.size) }
            .onChange(of: geometry.size) { _, newSize in
                handleViewportSize(newSize)
            }
        }
        .environment(\.colorScheme, .dark)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(model.phase == .briefing ? .visible : .hidden, for: .navigationBar)
        .onAppear { model.setReduceMotion(reduceMotion) }
        .onChange(of: reduceMotion) { _, enabled in
            model.setReduceMotion(enabled)
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase != .active, model.phase == .playing else { return }
            model.pauseRun()
        }
        .onDisappear {
            model.stopRun()
            GameOrientationController.restoreDefaultOrientations()
        }
    }

    private var briefingView: some View {
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(spacing: AppDesign.Spacing.xxl) {
                    Spacer(minLength: AppDesign.Spacing.xl)

                    HouseSwitchMark()
                        .accessibilityHidden(true)

                    VStack(spacing: AppDesign.Spacing.sm) {
                        Text(copy("house_switch_title"))
                            .font(.largeTitle.weight(.black))
                            .foregroundStyle(HouseSwitchTheme.ink)
                            .multilineTextAlignment(.center)

                        Text(copy("house_switch_subtitle"))
                            .font(.headline)
                            .foregroundStyle(HouseSwitchTheme.secondaryInk)
                            .multilineTextAlignment(.center)
                    }

                    HouseSwitchLandscapeNotice(
                        title: copy("house_switch_landscape_title"),
                        detail: copy(
                            orientationRequestFailed
                                ? "house_switch_landscape_error"
                                : "house_switch_landscape_detail"
                        ),
                        badge: copy("house_switch_landscape_badge"),
                        isError: orientationRequestFailed
                    )

                    VStack(spacing: AppDesign.Spacing.lg) {
                        HouseSwitchRuleRow(
                            icon: "hand.tap.fill",
                            title: copy("house_switch_rule_tap_title"),
                            detail: copy("house_switch_rule_tap_detail"),
                            color: HouseSwitchTheme.mint
                        )
                        HouseSwitchRuleRow(
                            icon: "rectangle.on.rectangle",
                            title: copy("house_switch_rule_solid_title"),
                            detail: copy("house_switch_rule_solid_detail"),
                            color: .cyan
                        )
                        HouseSwitchRuleRow(
                            icon: "square.dashed",
                            title: copy("house_switch_rule_gap_title"),
                            detail: copy("house_switch_rule_gap_detail"),
                            color: HouseSwitchTheme.orange
                        )
                        HouseSwitchRuleRow(
                            icon: "forward.end.fill",
                            title: copy("house_switch_rule_boost_title"),
                            detail: copy("house_switch_rule_boost_detail"),
                            color: HouseSwitchTheme.mint
                        )
                        HouseSwitchRuleRow(
                            icon: "bolt.trianglebadge.exclamationmark.fill",
                            title: copy("house_switch_rule_laser_title"),
                            detail: copy("house_switch_rule_laser_detail"),
                            color: HouseSwitchTheme.orange
                        )
                    }
                    .padding(AppDesign.Spacing.xl)
                    .background(HouseSwitchTheme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))

                    if let bestTime = model.bestTimeLabel {
                        Label("\(copy("house_switch_time")): \(bestTime)s", systemImage: "trophy.fill")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(HouseSwitchTheme.orange)
                    }
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.bottom, AppDesign.Spacing.xxl)
            }

            Button(action: prepareLandscapeRun) {
                Group {
                    if isWaitingForLandscape {
                        HStack(spacing: AppDesign.Spacing.sm) {
                            ProgressView()
                                .tint(Color(hex: "041B22"))
                            Text(copy("house_switch_rotating"))
                        }
                    } else {
                        Label(
                            copy(
                                isLandscapeLayout
                                    ? "house_switch_start"
                                    : "house_switch_start_landscape"
                            ),
                            systemImage: isLandscapeLayout
                                ? "arrow.up.arrow.down"
                                : "rectangle.landscape.rotate"
                        )
                    }
                }
                .font(.headline)
                .foregroundStyle(Color(hex: "041B22"))
                .frame(maxWidth: .infinity)
                .frame(minHeight: AppDesign.Size.buttonHeightLarge)
                .background(HouseSwitchTheme.mint)
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous))
            }
            .buttonStyle(ScaleButtonStyle())
            .disabled(isWaitingForLandscape)
            .padding(.horizontal, AppDesign.Spacing.xl)
            .padding(.bottom, AppDesign.Spacing.xxl)
        }
        .background(Color.black.opacity(0.16))
    }

    private var playingHUD: some View {
        VStack(spacing: 0) {
            HStack(spacing: AppDesign.Spacing.md) {
                Button(action: model.pauseRun) {
                    Image(systemName: "pause.fill")
                        .font(.body.weight(.bold))
                        .foregroundStyle(HouseSwitchTheme.ink)
                        .frame(width: 46, height: 46)
                        .background(HouseSwitchTheme.panel)
                        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
                }
                .accessibilityLabel(copy("house_switch_pause"))

                HouseSwitchProgressBar(
                    progress: model.progress,
                    title: copy("house_switch_progress"),
                    start: copy("house_switch_start_short"),
                    finish: copy("house_switch_finish_short")
                )
                    .frame(maxWidth: .infinity)

                HouseSwitchHUDValue(
                    title: copy("house_switch_flips"),
                    value: "\(model.flipCount)",
                    icon: "arrow.up.arrow.down"
                )
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.top, AppDesign.Spacing.sm)

            Spacer()

            if model.progress < 0.13 {
                Label(copy("house_switch_tap_hint"), systemImage: "hand.tap.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HouseSwitchTheme.ink)
                    .padding(.horizontal, AppDesign.Spacing.lg)
                    .frame(minHeight: 44)
                    .background(HouseSwitchTheme.panel)
                    .clipShape(Capsule())
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                    .padding(.bottom, AppDesign.Spacing.xxl)
                    .allowsHitTesting(false)
            }
        }
    }

    private func resultOverlay(finished: Bool) -> some View {
        let crashTitleKey: String
        let crashDetailKey: String

        switch model.crashReason {
        case .boundary:
            crashTitleKey = "house_switch_crashed_boundary"
            crashDetailKey = "house_switch_crashed_boundary_detail"
        case .leftBehind:
            crashTitleKey = "house_switch_crashed_left_behind"
            crashDetailKey = "house_switch_crashed_left_behind_detail"
        case .laser, .none:
            crashTitleKey = "house_switch_crashed_laser"
            crashDetailKey = "house_switch_crashed_laser_detail"
        }

        return stateOverlay(
            title: copy(finished ? "house_switch_finished" : crashTitleKey),
            detail: copy(finished ? "house_switch_finished_detail" : crashDetailKey),
            icon: finished ? "flag.checkered" : "bolt.trianglebadge.exclamationmark.fill",
            accent: finished ? HouseSwitchTheme.mint : HouseSwitchTheme.orange,
            primaryTitle: copy("house_switch_restart"),
            primaryIcon: "arrow.clockwise",
            primaryAction: model.startRun
        )
    }

    private func stateOverlay(
        title: String,
        detail: String,
        icon: String,
        accent: Color,
        primaryTitle: String,
        primaryIcon: String,
        primaryAction: @escaping () -> Void
    ) -> some View {
        ZStack {
            Color.black.opacity(0.58)
                .ignoresSafeArea()

            GeometryReader { geometry in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppDesign.Spacing.xl) {
                        Image(systemName: icon)
                            .font(.largeTitle.weight(.bold))
                            .foregroundStyle(accent)
                            .frame(width: 76, height: 76)
                            .background(accent.opacity(0.13))
                            .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))

                        VStack(spacing: AppDesign.Spacing.sm) {
                            Text(title)
                                .font(.title.weight(.black))
                                .foregroundStyle(HouseSwitchTheme.ink)
                                .multilineTextAlignment(.center)

                            Text(detail)
                                .font(.body)
                                .foregroundStyle(HouseSwitchTheme.secondaryInk)
                                .multilineTextAlignment(.center)
                                .fixedSize(horizontal: false, vertical: true)
                        }

                        HStack(spacing: AppDesign.Spacing.xl) {
                            HouseSwitchResultStat(
                                title: copy("house_switch_time"),
                                value: "\(model.elapsedLabel)s"
                            )
                            HouseSwitchResultStat(
                                title: copy("house_switch_flips"),
                                value: "\(model.flipCount)"
                            )
                        }

                        VStack(spacing: AppDesign.Spacing.sm) {
                            Button(action: primaryAction) {
                                Label(primaryTitle, systemImage: primaryIcon)
                                    .font(.headline)
                                    .foregroundStyle(Color(hex: "041B22"))
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: AppDesign.Size.buttonHeightLarge)
                                    .background(accent)
                                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous))
                            }
                            .buttonStyle(ScaleButtonStyle())
                            .accessibilityFocused($isOverlayPrimaryActionFocused)

                            Button {
                                model.stopRun()
                                dismiss()
                            } label: {
                                Text(copy("house_switch_exit"))
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(HouseSwitchTheme.secondaryInk)
                                    .frame(maxWidth: .infinity)
                                    .frame(minHeight: 44)
                            }
                        }
                    }
                    .padding(AppDesign.Spacing.xxl)
                    .frame(maxWidth: 430)
                    .background(HouseSwitchTheme.panel)
                    .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xxl, style: .continuous))
                    .padding(AppDesign.Spacing.xl)
                    .frame(maxWidth: .infinity, minHeight: geometry.size.height)
                    .onAppear { isOverlayPrimaryActionFocused = true }
                    .onDisappear { isOverlayPrimaryActionFocused = false }
                }
            }
        }
    }

    private func copy(_ key: String) -> String {
        appViewModel.localized(key, fallback: key)
    }

    private func prepareLandscapeRun() {
        orientationRequestFailed = false
        isWaitingForLandscape = !isLandscapeLayout

        GameOrientationController.lockToLandscape {
            guard model.phase == .briefing else { return }
            isWaitingForLandscape = false
            orientationRequestFailed = true
        }

        if isLandscapeLayout {
            model.startRun()
        }
    }

    private func handleViewportSize(_ size: CGSize) {
        let isLandscape = size.width > size.height
        isLandscapeLayout = isLandscape

        guard isLandscape, isWaitingForLandscape, model.phase == .briefing else { return }
        isWaitingForLandscape = false
        model.startRun()
    }
}

private struct HouseSwitchLandscapeNotice: View {
    let title: String
    let detail: String
    let badge: String
    let isError: Bool

    var body: some View {
        HStack(alignment: .center, spacing: AppDesign.Spacing.md) {
            Image(systemName: "rectangle.landscape.rotate")
                .font(.title2.weight(.bold))
                .foregroundStyle(isError ? HouseSwitchTheme.orange : HouseSwitchTheme.mint)
                .frame(width: 48, height: 48)
                .background(
                    (isError ? HouseSwitchTheme.orange : HouseSwitchTheme.mint)
                        .opacity(0.13)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(HouseSwitchTheme.ink)

                    Text(badge)
                        .font(.caption2.weight(.black))
                        .foregroundStyle(Color(hex: "041B22"))
                        .padding(.horizontal, AppDesign.Spacing.sm)
                        .padding(.vertical, AppDesign.Spacing.xs)
                        .background(isError ? HouseSwitchTheme.orange : HouseSwitchTheme.mint)
                        .clipShape(Capsule())
                }

                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(HouseSwitchTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(AppDesign.Spacing.lg)
        .background(HouseSwitchTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous))
        .accessibilityElement(children: .combine)
    }
}

private struct HouseSwitchBackdrop: View {
    let progress: Double
    let reduceMotion: Bool

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                LinearGradient(
                    colors: [HouseSwitchTheme.skyTop, HouseSwitchTheme.skyBottom],
                    startPoint: .top,
                    endPoint: .bottom
                )

                Circle()
                    .fill(HouseSwitchTheme.mint.opacity(0.11))
                    .frame(width: geometry.size.width * 0.72)
                    .blur(radius: 30)
                    .offset(x: geometry.size.width * 0.32, y: -geometry.size.height * 0.28)

                Canvas { context, size in
                    let heights: [CGFloat] = [0.20, 0.31, 0.24, 0.38, 0.27, 0.34, 0.22, 0.42, 0.30, 0.25, 0.36]
                    let buildingWidth = max(34, size.width / 8)
                    let movement = reduceMotion ? 0 : CGFloat(progress) * buildingWidth * 5

                    for pass in 0..<2 {
                        for index in 0..<heights.count {
                            let x = CGFloat(index) * buildingWidth - movement.truncatingRemainder(dividingBy: buildingWidth * 2)
                            let height = size.height * heights[index]
                            let rect = CGRect(
                                x: x + CGFloat(pass) * buildingWidth * CGFloat(heights.count),
                                y: size.height - height,
                                width: buildingWidth - 9,
                                height: height
                            )
                            context.fill(
                                Path(roundedRect: rect, cornerRadius: 3),
                                with: .color(Color.black.opacity(0.18))
                            )
                        }
                    }
                }
                .allowsHitTesting(false)
            }
        }
    }
}

private struct HouseSwitchMark: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xxl, style: .continuous)
                .fill(HouseSwitchTheme.panel)
                .frame(width: 118, height: 118)

            Image(systemName: "house.fill")
                .font(.largeTitle.weight(.black))
                .foregroundStyle(HouseSwitchTheme.mint)

            Image(systemName: "arrow.up")
                .font(.caption.weight(.black))
                .foregroundStyle(HouseSwitchTheme.orange)
                .offset(x: 39, y: -31)

            Image(systemName: "arrow.down")
                .font(.caption.weight(.black))
                .foregroundStyle(HouseSwitchTheme.orange)
                .offset(x: -39, y: 31)
        }
        .shadow(color: Color.black.opacity(0.28), radius: 18, x: 0, y: 10)
    }
}

private struct HouseSwitchRuleRow: View {
    let icon: String
    let title: String
    let detail: String
    let color: Color

    var body: some View {
        HStack(alignment: .top, spacing: AppDesign.Spacing.md) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.13))
                .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))

            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                Text(title)
                    .font(.headline)
                    .foregroundStyle(HouseSwitchTheme.ink)
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(HouseSwitchTheme.secondaryInk)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}

private struct HouseSwitchProgressBar: View {
    let progress: Double
    let title: String
    let start: String
    let finish: String

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
            HStack {
                Text(start)
                Spacer()
                Text(finish)
            }
            .font(.caption2.weight(.bold))
            .foregroundStyle(HouseSwitchTheme.secondaryInk)

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.16))
                    Capsule()
                        .fill(HouseSwitchTheme.mint)
                        .frame(width: max(8, geometry.size.width * progress))
                }
            }
            .frame(height: 7)
        }
        .padding(.horizontal, AppDesign.Spacing.md)
        .padding(.vertical, AppDesign.Spacing.sm)
        .background(HouseSwitchTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(title)
        .accessibilityValue("%\(Int(progress * 100))")
    }
}

private struct HouseSwitchHUDValue: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: icon)
                .font(.caption.weight(.bold))
                .foregroundStyle(HouseSwitchTheme.mint)
            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(HouseSwitchTheme.ink)
            Text(title)
                .font(.caption2)
                .foregroundStyle(HouseSwitchTheme.secondaryInk)
        }
        .frame(minWidth: 58, minHeight: 54)
        .background(HouseSwitchTheme.panel)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
    }
}

private struct HouseSwitchResultStat: View {
    let title: String
    let value: String

    var body: some View {
        VStack(spacing: AppDesign.Spacing.xs) {
            Text(value)
                .font(.title2.weight(.bold).monospacedDigit())
                .foregroundStyle(HouseSwitchTheme.ink)
            Text(title)
                .font(.caption)
                .foregroundStyle(HouseSwitchTheme.secondaryInk)
        }
        .frame(maxWidth: .infinity)
    }
}
