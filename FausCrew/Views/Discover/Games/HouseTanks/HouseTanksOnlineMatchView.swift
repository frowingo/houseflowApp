import SpriteKit
import SwiftUI
import FausCrewCore

/// The online match in landscape: the server's arena drawn by `onlineScene`, the seat bar
/// for up to eight tanks, the one button over the whole field, the round countdown, a
/// banner for every state that needs words, the vote between rounds, the result and a
/// rematch room. The engine decides when the button works and who may vote.
struct HouseTanksOnlineMatchView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var model: HouseTanksViewModel
    let onExit: () -> Void
    /// True from finger down to up; a cancelled gesture (system edge swipe, interruption)
    /// resets it too, so the release is never lost.
    @GestureState private var isFieldPressed = false
    @State private var isConfirmingLeave = false
    @State private var showsPressHint = true

    var body: some View {
        let match = model.onlineMatch
        ZStack {
            HouseTanksMapBackdrop()
                .ignoresSafeArea()
            SpriteView(scene: model.onlineScene, options: [.allowsTransparency])
                .ignoresSafeArea()
                .allowsHitTesting(false)

            pressField(match)
            hud(match)

            if let match, match.noticeTitleKey == nil, !match.showsResult, !match.showsRematchRoom,
               match.roundPhase == .roundCountdown || match.phase == .countdown {
                roundCountdown(round: match.phase == .countdown ? nil : match.roundNumber)
            }
            if let match, let title = match.noticeTitleKey {
                VStack {
                    Spacer()
                    notice(match, title: title)
                }
                .padding(.bottom, AppDesign.Spacing.lg)
            }
            if let match, match.showsRoundPanel {
                ZStack {
                    HouseTanksMapPalette.ink.opacity(0.18).ignoresSafeArea()
                    roundPanel(match)
                        .padding(AppDesign.Spacing.lg)
                }
            }
            if let match, match.showsResult {
                HouseTanksOnlineResultPanel(state: model.onlineResult, standings: match.standings,
                                            localPlayerID: localPlayerID,
                                            memberNames: memberNames, onRetry: model.retryOnlineResult,
                                            onRematch: model.rematchOnline, onExit: onExit)
            } else if match?.showsRematchRoom == true || (model.isOnlineRematchRoom && match == nil) {
                HouseTanksOnlineRematchRoom(model: model, memberNames: memberNames, onExit: onExit)
            }
        }
        .confirmationDialog(copy("house_tanks_online_leave_confirm_title"), isPresented: $isConfirmingLeave,
                            titleVisibility: .visible) {
            Button(copy("house_tanks_online_leave"), role: .destructive, action: onExit)
        } message: {
            Text(copy("house_tanks_online_leave_confirm_detail"))
        }
        // Down presses, up releases. A finger held across a round boundary or a sync pause
        // is the engine's: it never presses again until the finger lifts and comes back.
        .onChange(of: isFieldPressed) { _, pressed in
            if pressed { model.onlinePress() } else { model.onlineRelease() }
        }
    }

    /// The whole field is the button: down presses, up releases. The engine ignores a
    /// press it may not send, so the gesture is always there while the match runs.
    private func pressField(_ match: HouseTanksOnlineMatchUI?) -> some View {
        Color.clear
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 0)
                    .updating($isFieldPressed) { _, pressed, _ in pressed = true }
            )
            .accessibilityElement()
            .accessibilityAddTraits(.isButton)
            .accessibilityLabel(copy("house_tanks_playfield_accessibility"))
            .accessibilityHint(copy("house_tanks_playfield_hint"))
            .accessibilityAction {
                model.onlinePress()
                Task {
                    try? await Task.sleep(nanoseconds: 420_000_000)
                    model.onlineRelease()
                }
            }
            .disabled(match?.isFinished == true || match?.showsRematchRoom == true)
    }

    private func hud(_ match: HouseTanksOnlineMatchUI?) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: AppDesign.Spacing.xs) {
                // The top-left exit is for a live round only: the round panel, the end menu
                // and the rematch room carry their own way out.
                if match?.showsResult != true, match?.showsRematchRoom != true, !model.isOnlineRematchRoom {
                    if match?.showsRoundPanel != true {
                        Button { isConfirmingLeave = true } label: {
                            Image(systemName: "xmark")
                                .font(.body.weight(.black))
                                .foregroundStyle(HouseTanksFieldTheme.ink)
                                .frame(width: 44, height: 44)
                                .hudPanel()
                        }
                        .accessibilityLabel(copy("house_tanks_online_leave"))
                    }

                    if let fps = model.onlineFramesPerSecond {
                        framesPerSecond(fps)
                    }
                }

                ForEach(match?.seats ?? []) { seat in
                    seatStatus(seat, showsVote: match?.showsRoundPanel == true)
                }
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.top, AppDesign.Spacing.sm)

            Spacer()

            if showsPressHint, match?.roundPhase == .roundPlaying, match?.canPress == true {
                Label(copy("house_tanks_online_press_hint"), systemImage: "hand.tap.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(HouseTanksFieldTheme.ink)
                    .padding(.horizontal, AppDesign.Spacing.lg)
                    .frame(minHeight: 44)
                    .hudPanel()
                    .allowsHitTesting(false)
                    .padding(.bottom, AppDesign.Spacing.xl)
                    .task {
                        try? await Task.sleep(nanoseconds: 4_000_000_000)
                        withAnimation(.easeOut(duration: 0.2)) { showsPressHint = false }
                    }
            }
        }
    }

    /// Frames drawn in the last second, green at a smooth rate through to red at a choppy one.
    private func framesPerSecond(_ fps: Int) -> some View {
        let tint = Color(hue: 0.33 * HouseTanksFrameRate.quality(fps), saturation: 0.8, brightness: 0.62)
        return HStack(spacing: 5) {
            Circle().fill(tint).frame(width: 8, height: 8)
            Text(copy("house_tanks_online_fps", replacements: ["fps": "\(fps)"]))
                .font(.system(.caption, design: .monospaced).weight(.heavy))
                .monospacedDigit()
                .foregroundStyle(tint)
        }
        .padding(.horizontal, AppDesign.Spacing.sm)
        .frame(minWidth: 72, minHeight: 44)
        .hudPanel()
        .allowsHitTesting(false)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(copy("house_tanks_online_fps_accessibility", replacements: ["fps": "\(fps)"]))
    }

    /// One tank of up to eight: name, round wins, armor, and a mark for a lost connection.
    private func seatStatus(_ seat: HouseTanksOnlineSeat, showsVote: Bool) -> some View {
        let tint = Color(uiColor: seat.color.uiColor)
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 3) {
                if showsVote, seat.roundReady {
                    Image(systemName: "checkmark.seal.fill")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(HouseTanksMapPalette.steel)
                } else if !seat.isConnected {
                    Image(systemName: "wifi.slash")
                        .font(.caption2.weight(.black))
                        .foregroundStyle(HouseTanksMapPalette.rust)
                }
                Text(seat.displayName)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(HouseTanksFieldTheme.ink)
                    .strikethrough(seat.hasLeft)
                    .lineLimit(1)
                Spacer(minLength: 1)
                Text("\(seat.roundsWon)/\(HouseTanksMatchRules.roundWinsNeeded)")
                    .font(HouseTanksFieldTheme.stencil)
                    .foregroundStyle(HouseTanksMapPalette.umber)
            }
            HStack(spacing: 2) {
                ForEach(0..<HouseTanksWorld.armorPerRound, id: \.self) { index in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(index < seat.armor && seat.isAlive ? tint : HouseTanksMapPalette.slate.opacity(0.2))
                        .frame(height: 5)
                }
            }
        }
        .padding(.leading, 9)
        .padding(.trailing, 6)
        .frame(maxWidth: .infinity, minHeight: 44)
        .hudPanel()
        .overlay(alignment: .leading) {
            Rectangle().fill(tint).frame(width: 3).padding(.vertical, 7).padding(.leading, 3)
        }
        .overlay {
            if seat.isLocal {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous)
                    .stroke(tint, lineWidth: 1.5)
            }
        }
        .opacity(seat.isAlive && seat.isConnected ? 1 : 0.5)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(seatLabel(seat, showsVote: showsVote))
    }

    private func seatLabel(_ seat: HouseTanksOnlineSeat, showsVote: Bool) -> String {
        var parts = [seat.displayName, "\(copy("house_tanks_armor")) \(seat.armor)",
                     "\(copy("house_tanks_round_score")) \(seat.roundsWon)"]
        if showsVote, seat.roundReady { parts.append(copy("house_tanks_online_ready_badge")) }
        if !seat.isConnected { parts.append(copy("house_tanks_online_offline")) }
        if seat.hasLeft { parts.append(copy("house_tanks_online_left_badge")) }
        return parts.joined(separator: ", ")
    }

    /// The server's round countdown (or a rematch's match countdown, `round` nil), read
    /// from its deadline on every tick of the timeline.
    private func roundCountdown(round: Int?) -> some View {
        TimelineView(.periodic(from: .now, by: 0.2)) { _ in
            VStack(spacing: AppDesign.Spacing.xs) {
                Text((round.map { copy("house_tanks_round", replacements: ["number": "\($0)"]) }
                      ?? copy("house_tanks_online_countdown")).uppercased())
                    .font(.system(.subheadline, design: .monospaced).weight(.bold))
                    .tracking(2)
                    .foregroundStyle(HouseTanksMapPalette.umber)
                Text(model.onlineCountdown().map { $0 > 0 ? String($0) : copy("house_tanks_countdown_go") }
                     ?? copy("house_tanks_countdown_go"))
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
        }
        .allowsHitTesting(false)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.updatesFrequently)
    }

    /// Reconnecting, recovering, control moved, round death, round over or match over.
    private func notice(_ match: HouseTanksOnlineMatchUI, title: String) -> some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            Text(copy(title, replacements: ["name": match.noticeName ?? ""]))
                .font(.headline.weight(.black))
                .fontWidth(.condensed)
                .foregroundStyle(HouseTanksFieldTheme.ink)
                .multilineTextAlignment(.center)
            if let detail = match.noticeDetailKey {
                Text(copy(detail))
                    .font(.subheadline)
                    .foregroundStyle(HouseTanksFieldTheme.muted)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if match.canRetry {
                noticeButton(copy("house_tanks_online_retry"), icon: "arrow.clockwise", action: model.retryOnline)
            } else if match.canReclaim {
                noticeButton(copy("house_tanks_online_reclaim"), icon: "hand.point.up.left.fill",
                             action: model.reclaimOnlineControl)
            } else if match.isFinished || match.isSpectating {
                noticeButton(copy("house_tanks_exit"), icon: "rectangle.portrait.and.arrow.right", action: onExit)
            }
        }
        .padding(AppDesign.Spacing.lg)
        .frame(maxWidth: 360)
        .houseTanksFieldCard(padding: 0)
        .background(HouseTanksMapPalette.paper.opacity(0.92),
                    in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
        .accessibilityElement(children: .contain)
    }

    /// `roundReady`, centered for every device: who took the round, the vote window, and the
    /// way out beside this device's vote (the top-left exit is hidden between rounds).
    private func roundPanel(_ match: HouseTanksOnlineMatchUI) -> some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: match.noticeName == nil ? "flag.fill" : "trophy.fill")
                .font(.title2.weight(.black))
                .foregroundStyle(HouseTanksMapPalette.umber)
                .accessibilityHidden(true)
            Text(copy(match.roundTitleKey, replacements: ["name": match.noticeName ?? ""]))
                .font(.title3.weight(.black))
                .fontWidth(.condensed)
                .foregroundStyle(HouseTanksFieldTheme.ink)
                .multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(copy(match.roundDetailKey, replacements: ["seconds": "\(match.roundWindowSeconds ?? 0)"]))
                .font(.subheadline)
                .foregroundStyle(HouseTanksFieldTheme.muted)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.numericText())
            Label(copy("house_tanks_online_round_ready_count",
                       replacements: ["ready": "\(match.readyCount)", "total": "\(match.voterCount)"]),
                  systemImage: "person.2.fill")
                .font(HouseTanksFieldTheme.stencil)
                .foregroundStyle(HouseTanksMapPalette.umber)
            HStack(spacing: AppDesign.Spacing.md) {
                panelButton(copy("house_tanks_online_leave_match"), icon: "rectangle.portrait.and.arrow.right",
                            tint: HouseTanksMapPalette.umber) { isConfirmingLeave = true }
                if match.canVote {
                    let ready = match.isLocalReady
                    panelButton(copy(ready ? "house_tanks_online_round_unready" : "house_tanks_online_round_ready"),
                                icon: ready ? "xmark.circle" : "checkmark.circle.fill",
                                tint: ready ? HouseTanksMapPalette.slate : HouseTanksMapPalette.steel,
                                isBusy: match.isVotePending) {
                        model.setOnlineRoundReady(!ready)
                    }
                }
            }
            .padding(.top, AppDesign.Spacing.xs)
        }
        .frame(maxWidth: .infinity)
        .padding(AppDesign.Spacing.lg)
        .houseTanksFieldCard(padding: 0)
        .background(HouseTanksMapPalette.paper.opacity(0.96),
                    in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
        .frame(maxWidth: 460)
        .accessibilityElement(children: .contain)
    }

    private func panelButton(_ title: String, icon: String, tint: Color, isBusy: Bool = false,
                             action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: AppDesign.Spacing.xs) {
                if isBusy {
                    ProgressView().controlSize(.small).tint(HouseTanksMapPalette.paper)
                } else {
                    Image(systemName: icon)
                }
                Text(title).lineLimit(1).minimumScaleFactor(0.8)
            }
            .font(.subheadline.weight(.bold))
            .foregroundStyle(HouseTanksMapPalette.paper)
            .frame(maxWidth: .infinity, minHeight: 44)
            .background(tint, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
        }
        .buttonStyle(HouseTanksRaisedButtonStyle(depth: tint, offset: 3))
    }

    private var localPlayerID: String? { appViewModel.currentUserId }

    private var memberNames: [String: String] {
        Dictionary((appViewModel.currentHouseDetails?.members ?? []).map { ($0.id, $0.fullName) },
                   uniquingKeysWith: { first, _ in first })
    }

    private func noticeButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(HouseTanksMapPalette.paper)
                .padding(.horizontal, AppDesign.Spacing.md)
                .frame(minHeight: 44)
                .background(HouseTanksMapPalette.steel,
                            in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
        }
        .buttonStyle(HouseTanksRaisedButtonStyle(depth: HouseTanksMapPalette.steel, offset: 3))
    }

    private func copy(_ key: String) -> String {
        appViewModel.localized(key, fallback: key)
    }

    private func copy(_ key: String, replacements: [String: String]) -> String {
        appViewModel.localized(key, replacements: replacements)
    }
}
