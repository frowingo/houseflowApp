import SwiftUI
import FausCrewCore

/// Entry flow: choose demo or online, then set up the match on a field-map sheet.
/// Orientation and match start stay with HouseTanksView.
struct HouseTanksLobbyView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var model: HouseTanksViewModel
    let isLandscapeLayout: Bool
    let isWaitingForLandscape: Bool
    let orientationRequestFailed: Bool
    let onStart: () -> Void
    /// Briefly marks the step the start button sent the player to.
    @State private var highlightedStep: HouseTanksSetupStep?
    /// The start card (countdown, then the drawn map) is on screen; while it is scrolled away
    /// the navigation bar carries a small copy of its seconds.
    @State private var isStartCardVisible = true

    private var copy: HouseTanksCopy { HouseTanksCopy(appViewModel) }

    var body: some View {
        ScrollViewReader { proxy in
        VStack(spacing: 0) {
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 28) {
                    header

                    if let mode = model.selectedMode {
                        modeBar(mode)
                        if mode == .demo {
                            HouseTanksDemoSetupView(model: model,
                                                    isWaitingForLandscape: isWaitingForLandscape,
                                                    highlightedStep: highlightedStep)
                        } else {
                            HouseTanksOnlineRoomView(model: model, isStartCardVisible: $isStartCardVisible)
                        }
                    } else {
                        modeSelection
                    }

                    fieldManual

                    if model.selectedMode == .demo || orientationRequestFailed {
                        Label(copy(orientationRequestFailed ? "house_tanks_landscape_error" : "house_tanks_landscape_detail"),
                              systemImage: "rectangle.landscape.rotate")
                            .font(.subheadline)
                            .foregroundStyle(orientationRequestFailed ? HouseTanksFieldTheme.danger : HouseTanksFieldTheme.muted)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
                .padding(.horizontal, AppDesign.Spacing.xl)
                .padding(.top, AppDesign.Spacing.xl)
                .padding(.bottom, AppDesign.Spacing.xxl)
                .frame(maxWidth: 620)
                .frame(maxWidth: .infinity)
            }

            if model.selectedMode == .demo {
                HouseTanksDemoStartBar(model: model,
                                       isLandscapeLayout: isLandscapeLayout,
                                       isWaitingForLandscape: isWaitingForLandscape,
                                       highlightedStep: $highlightedStep,
                                       proxy: proxy,
                                       onStart: onStart)
            }
        }
        }
        .toolbar {
            // Only while it has seconds to show: an empty item still draws its glass circle.
            if showsCompactCountdown {
                ToolbarItem(placement: .topBarTrailing) { compactCountdown }
            }
        }
    }

    /// The start card is scrolled away while the room counts down (ready window or start).
    private var showsCompactCountdown: Bool {
        let phase = model.onlineState.session?.state
        return model.selectedMode == .online && !isStartCardVisible && !model.onlineState.isTerminal
            && (phase == .readyWindow || phase == .countdown)
    }

    /// The room's countdown in the navigation bar, only while the start card is off screen.
    private var compactCountdown: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            if let seconds = model.onlineCountdown() {
                Label {
                    Text(verbatim: "\(seconds)")
                        .monospacedDigit()
                        .contentTransition(.numericText(countsDown: true))
                } icon: {
                    Image(systemName: "timer")
                }
                .font(.subheadline.weight(.heavy))
                .foregroundStyle(seconds <= 5 ? HouseTanksFieldTheme.danger : HouseTanksFieldTheme.ink)
                .animation(.snappy, value: seconds)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(copy("house_tanks_online_seconds", replacements: ["seconds": "\(seconds)"]))
            }
        }
    }

    // MARK: - Header and mode

    private var header: some View {
        HStack(alignment: .center, spacing: AppDesign.Spacing.lg) {
            HouseTanksArenaTank(tint: .white)
                .frame(width: 70, height: 70)
                .frame(width: 88, height: 88)
                .background(HouseTanksMapPalette.steel,
                            in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
                .overlay {
                    HouseTanksCornerMarks(length: 7)
                        .stroke(HouseTanksMapPalette.paper.opacity(0.7), lineWidth: 1.2)
                        .padding(6)
                }

            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                Text(copy("house_tanks_kicker"))
                    .font(HouseTanksFieldTheme.stencil)
                    .tracking(1.4)
                    .foregroundStyle(HouseTanksMapPalette.umber)
                Text(copy("house_tanks_title"))
                    .font(.largeTitle.weight(.black))
                    .fontWidth(.condensed)
                    .foregroundStyle(HouseTanksFieldTheme.ink)
                Text(copy(subtitleKey))
                    .font(.subheadline)
                    .foregroundStyle(HouseTanksFieldTheme.muted)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var subtitleKey: String {
        switch model.selectedMode {
        case .demo: "house_tanks_subtitle"
        case .online: "house_tanks_online_subtitle"
        case nil: "house_tanks_mode_prompt"
        }
    }

    private var modeSelection: some View {
        VStack(spacing: AppDesign.Spacing.md) {
            ForEach(HouseTanksMode.allCases) { mode in modeCard(mode) }
        }
    }

    private func modeCard(_ mode: HouseTanksMode) -> some View {
        let isDemo = mode == .demo
        let tint = isDemo ? HouseTanksMapPalette.steel : HouseTanksMapPalette.khaki
        let tintInk = isDemo ? HouseTanksMapPalette.steel : HouseTanksMapPalette.umber
        return Button { model.selectMode(mode) } label: {
            VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
                HStack(spacing: AppDesign.Spacing.md) {
                    Image(systemName: isDemo ? "scope" : "person.2.fill")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(HouseTanksMapPalette.paper)
                        .frame(width: 44, height: 44)
                        .background(tint, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: isDemo ? "OP-01" : "OP-02")
                            .font(HouseTanksFieldTheme.stencil)
                            .tracking(1.4)
                            .foregroundStyle(HouseTanksFieldTheme.muted)
                        Text(copy(isDemo ? "house_tanks_mode_demo_title" : "house_tanks_mode_online_title"))
                            .font(.headline.weight(.bold))
                            .foregroundStyle(HouseTanksFieldTheme.ink)
                    }
                    Spacer(minLength: 0)
                    Label(copy(isDemo ? "house_tanks_mode_demo_map" : "house_tanks_mode_online_map"),
                          systemImage: isDemo ? "map" : "dice")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(tintInk)
                        .padding(.horizontal, AppDesign.Spacing.sm)
                        .padding(.vertical, AppDesign.Spacing.xs)
                        .background(tint.opacity(0.14), in: Capsule())
                }
                Text(copy(isDemo ? "house_tanks_mode_demo_detail" : "house_tanks_mode_online_detail"))
                    .font(.subheadline)
                    .foregroundStyle(HouseTanksFieldTheme.muted)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
                // A filled action strip makes the whole card read as a control.
                HStack(spacing: AppDesign.Spacing.sm) {
                    Text(copy(isDemo ? "house_tanks_mode_demo_action" : "house_tanks_mode_online_action"))
                    Spacer(minLength: 0)
                    Image(systemName: "arrow.right")
                }
                .font(.subheadline.weight(.bold))
                .foregroundStyle(HouseTanksMapPalette.paper)
                .padding(.horizontal, AppDesign.Spacing.md)
                .frame(maxWidth: .infinity, minHeight: 44)
                .background(tintInk, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
            }
            .houseTanksFieldCard()
            .overlay(alignment: .leading) {
                Rectangle().fill(tint).frame(width: 3).padding(.vertical, AppDesign.Spacing.lg)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(HouseTanksRaisedButtonStyle(depth: tint))
    }

    private func modeBar(_ mode: HouseTanksMode) -> some View {
        HStack(spacing: AppDesign.Spacing.md) {
            Label(copy(mode == .demo ? "house_tanks_mode_demo_title" : "house_tanks_mode_online_title"),
                  systemImage: mode == .demo ? "scope" : "person.2")
                .font(.title3.weight(.bold))
            Spacer()
            Button(copy("house_tanks_change_mode"), action: model.returnToModeSelection)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(HouseTanksFieldTheme.accent)
                .frame(minHeight: 44)
                .disabled(isWaitingForLandscape)
        }
        .foregroundStyle(HouseTanksFieldTheme.ink)
        .padding(.bottom, AppDesign.Spacing.sm)
        .overlay(alignment: .bottom) {
            HouseTanksFieldTheme.hairline.frame(height: 1)
        }
    }

    // MARK: - Field manual

    /// How to play as tiny looping clips with a few words each (two jokers stand in for all
    /// of them; the rest is learned in play). The full sentence stays for VoiceOver.
    private var fieldManual: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.lg) {
            HouseTanksSectionHeader(code: fieldManualCode, key: "house_tanks_rules_title")
            LazyVGrid(columns: [GridItem(.flexible(), spacing: AppDesign.Spacing.md, alignment: .top),
                                GridItem(.flexible(), spacing: AppDesign.Spacing.md, alignment: .top)],
                      alignment: .leading, spacing: AppDesign.Spacing.lg) {
                ForEach(HouseTanksRuleClipKind.allCases, id: \.self) { kind in
                    VStack(alignment: .leading, spacing: 6) {
                        HouseTanksRuleClip(kind: kind)
                        Text(copy(kind.titleKey))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(HouseTanksFieldTheme.ink)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel(copy(kind.titleKey))
                    .accessibilityHint(copy(kind.detailKey))
                }
            }
            .houseTanksFieldCard()
        }
    }

    // MARK: - Helpers

    private var fieldManualCode: String {
        switch model.selectedMode {
        case .demo: String(format: "%02d", model.setupSteps.count + 1)
        case .online: "04"
        case nil: "01"
        }
    }
}
