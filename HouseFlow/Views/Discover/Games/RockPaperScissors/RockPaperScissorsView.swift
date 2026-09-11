import SwiftUI

struct RockPaperScissorsView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @StateObject private var model: RockPaperScissorsViewModel
    @State private var observationID = UUID()
    @State private var rulesExpanded = false
    @State private var bracketExpanded = false

    init(service: (any RPSGameServicing)? = nil) {
        _model = StateObject(wrappedValue: RockPaperScissorsViewModel(service: service ?? DemoRPSGameService()))
    }

    var body: some View {
        ZStack {
            RPSBackground()
            ScrollViewReader { proxy in
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        Color.clear.frame(height: 0).id("top")
                        if let state = model.snapshot {
                            tournament(state)
                        } else {
                            lobby
                        }
                    }
                    .padding(.horizontal, AppDesign.Spacing.xl)
                    .padding(.bottom, 24)
                    .frame(maxWidth: 600)
                    .frame(maxWidth: .infinity)
                }
                .onChange(of: model.snapshot?.phase) { _, _ in
                    bracketExpanded = model.snapshot?.phase == .draw
                    withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.25)) { proxy.scrollTo("top") }
                }
            }
        }
        .foregroundStyle(.white)
        .environment(\.colorScheme, .dark)
        .safeAreaInset(edge: .top, spacing: 0) { navigationHeader }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.snapshot?.phase != .choosing || model.snapshot?.localPlayerIsPlaying != true {
                footer
            }
        }
        .navigationBarHidden(true)
        .sensoryFeedback(.success, trigger: model.snapshot?.activeMatch?.winnerID) { _, winnerID in
            winnerID != nil
        }
        .task(id: observationID) { await model.observe() }
        .onAppear {
            appViewModel.isOverlayPresented = true
            if let first = model.players.indices.first { model.players[first].name = appViewModel.localized("rps_you") }
        }
        .onDisappear {
            model.stop()
            appViewModel.isOverlayPresented = false
        }
        .alert(appViewModel.localized("rps_error"), isPresented: Binding(
            get: { model.errorKey != nil }, set: { if !$0 { model.errorKey = nil } }
        )) {
            Button(appViewModel.localized("rps_ok"), role: .cancel) { model.errorKey = nil }
            Button(appViewModel.localized("rps_edit_players")) { returnToLobby() }
        }
    }

    private var navigationHeader: some View {
        HStack {
            LocalizedText("rps_demo")
                .font(.system(.caption, design: .rounded, weight: .semibold))
                .foregroundStyle(RPSTheme.secondary)
            Spacer()
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.subheadline.weight(.semibold))
                    .frame(width: 44, height: 44)
                    .background(.white.opacity(0.06), in: Circle())
            }
            .accessibilityLabel(appViewModel.localized("rps_close"))
            .foregroundStyle(.white)
        }
        .padding(.horizontal, 20).padding(.vertical, 6)
        .background(RPSTheme.ink.opacity(0.96))
    }

    private var lobby: some View {
        VStack(spacing: 24) {
            VStack(spacing: 12) {
                Text(RPSMove.allCases.map(\.emoji).joined(separator: "  "))
                    .font(.largeTitle)
                    .accessibilityHidden(true)
                LocalizedText("rps_hero")
                    .font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityAddTraits(.isHeader)
                LocalizedText("rps_intro").font(.subheadline).lineSpacing(4)
                    .foregroundStyle(RPSTheme.secondary).multilineTextAlignment(.center)
            }
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    sectionTitle("rps_players")
                    Spacer()
                    LocalizedText("rps_count", replacements: ["count": "\(model.players.count)"])
                        .font(.caption.monospacedDigit()).foregroundStyle(RPSTheme.mint)
                }
                ForEach(model.players) { player in
                    HStack(spacing: 12) {
                        RPSAvatar(player: player)
                        Text(player.name).font(.system(.body, design: .rounded, weight: .semibold)).lineLimit(1)
                        Spacer(minLength: 4)
                        LocalizedText(player.id == model.players.first?.id ? "rps_local" : "rps_bot")
                            .font(.system(.caption2, design: .rounded, weight: .semibold))
                            .foregroundStyle(player.id == model.players.first?.id ? RPSTheme.mint : RPSTheme.secondary)
                        if player.id != model.players.first?.id {
                            Button { model.removePlayer(player) } label: {
                                Image(systemName: "minus.circle").frame(width: 44, height: 44)
                            }
                            .foregroundStyle(RPSTheme.secondary)
                            .disabled(model.players.count <= 2)
                            .opacity(model.players.count <= 2 ? 0.3 : 1)
                            .accessibilityLabel(appViewModel.localized("rps_remove", replacements: ["name": player.name]))
                        }
                    }
                }
                if model.players.count < 8 {
                    HStack {
                        TextField(appViewModel.localized("rps_name"), text: $model.newPlayerName)
                            .font(.subheadline).autocorrectionDisabled()
                            .submitLabel(.done).onSubmit { model.addPlayer() }
                            .onChange(of: model.newPlayerName) { _, value in
                                if value.count > 24 { model.newPlayerName = String(value.prefix(24)) }
                            }
                        Button { model.addPlayer() } label: {
                            Image(systemName: "plus").font(.headline).frame(width: 44, height: 44)
                                .background(RPSTheme.mint.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                        }
                        .foregroundStyle(RPSTheme.mint).disabled(!model.canAddPlayer)
                        .opacity(model.canAddPlayer ? 1 : 0.35)
                        .accessibilityLabel(appViewModel.localized("rps_add"))
                    }
                    .padding(.leading, 12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(RPSTheme.secondary.opacity(0.4)))
                }
                LocalizedText("rps_name_hint").font(.caption2).foregroundStyle(RPSTheme.secondary)
            }
            DisclosureGroup(isExpanded: $rulesExpanded) {
                VStack(alignment: .leading, spacing: 16) {
                    rule(title: "rps_rule_duel", detail: "rps_rule_duel_detail")
                    rule(title: "rps_rule_bye", detail: "rps_rule_bye_detail")
                    LocalizedText("rps_cycle").font(.caption).lineSpacing(3).foregroundStyle(RPSTheme.secondary)
                }
                .padding(.top, 8)
            } label: {
                sectionTitle("rps_rules").frame(minHeight: 44)
            }
            .tint(RPSTheme.mint)
        }
        .padding(.top, 12)
    }

    @ViewBuilder
    private func tournament(_ state: RPSSnapshot) -> some View {
        VStack(spacing: 24) {
            if state.phase == .finished, let champion = state.champion {
                championView(champion, count: state.players.count)
            } else {
                HStack {
                    LocalizedText(state.currentRound?.matches.count == 1 && state.currentRound?.bye == nil ? "rps_final" : "rps_round",
                                  replacements: ["number": "\(state.currentRound?.number ?? 1)"])
                        .font(.system(.caption, design: .rounded, weight: .semibold))
                        .foregroundStyle(RPSTheme.mint)
                    Spacer()
                    if let match = state.activeMatch {
                        LocalizedText("rps_attempt", replacements: ["number": "\(match.attempt)"])
                            .font(.caption.monospacedDigit()).foregroundStyle(RPSTheme.secondary)
                    }
                }
                if state.phase == .draw { drawView(state) }
                else if state.phase == .roundComplete { roundComplete(state) }
                else if let match = state.activeMatch { duel(state, match: match) }
            }
            DisclosureGroup(isExpanded: $bracketExpanded) {
                RPSBracket(snapshot: state).padding(.top, 8)
            } label: {
                sectionTitle("rps_bracket").frame(minHeight: 44)
            }
            .tint(RPSTheme.mint)
        }
        .padding(.top, 12)
    }

    private func drawView(_ state: RPSSnapshot) -> some View {
        VStack(spacing: 20) {
            heading("rps_draw_title", detail: "rps_draw_detail")
            if let bye = state.currentRound?.bye {
                VStack(spacing: 14) {
                    RPSAvatar(player: bye, size: 56)
                    Text(bye.name).font(.system(.title, design: .rounded, weight: .bold))
                    LocalizedText("rps_bye_detail").font(.subheadline).foregroundStyle(RPSTheme.secondary)
                        .multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity)
            } else {
                Label { LocalizedText("rps_no_bye") } icon: { Image(systemName: "person.2.fill") }
                    .font(.subheadline).foregroundStyle(RPSTheme.secondary)
            }
        }
    }

    private func duel(_ state: RPSSnapshot, match: RPSMatch) -> some View {
        VStack(spacing: 24) {
            duelHeading(state, match: match)
            HStack(alignment: .top, spacing: 8) {
                fighter(match.first, move: match.firstMove, state: state, winner: match.winnerID == match.first.id)
                VStack {
                    Text(state.countdown.map(String.init) ?? "VS")
                        .font(.system(size: state.countdown == nil ? 17 : 32, weight: .black, design: .rounded))
                        .foregroundStyle(state.countdown == nil ? RPSTheme.secondary : RPSTheme.mint)
                        .contentTransition(.numericText())
                        .animation(reduceMotion ? nil : .spring(response: 0.25), value: state.countdown)
                        .frame(width: 42, height: 130)
                }
                fighter(match.second, move: match.secondMove, state: state, winner: match.winnerID == match.second.id, mirrored: true)
            }
            if state.phase == .choosing && state.localPlayerIsPlaying {
                HStack(spacing: 10) {
                    ForEach(RPSMove.allCases, id: \.self) { move in
                        Button { Task { await model.play(move) } } label: {
                            VStack(spacing: 12) {
                                Text(move.emoji).font(.system(size: 40)).accessibilityHidden(true)
                                LocalizedText(move.titleKey).font(.system(.subheadline, design: .rounded, weight: .bold))
                            }
                            .frame(maxWidth: .infinity).padding(.vertical, 22)
                            .background(RPSTheme.mint.opacity(0.1), in: RoundedRectangle(cornerRadius: 16))
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(RPSTheme.mint.opacity(0.4)))
                        }
                        .buttonStyle(ScaleButtonStyle()).disabled(model.isSending)
                    }
                }
            }
            if state.phase == .choosing && state.localPlayerIsPlaying {
                LocalizedText("rps_cycle").font(.caption).foregroundStyle(RPSTheme.secondary)
                    .multilineTextAlignment(.center).lineSpacing(4)
            }
        }
    }

    @ViewBuilder
    private func duelHeading(_ state: RPSSnapshot, match: RPSMatch) -> some View {
        switch state.phase {
        case .choosing:
            heading(state.localPlayerIsPlaying ? "rps_choose" : "rps_spectator",
                    detail: state.localPlayerIsPlaying ? "rps_choice_detail" : "rps_spectator_detail")
        case .countdown: heading("rps_locked", detail: "rps_countdown_detail")
        default:
            if let winner = match.winner {
                heading(winner.id == state.localPlayerID ? "rps_you_won" : "rps_winner",
                        detail: "rps_win_detail", replacements: ["name": winner.name])
            } else { heading("rps_tie", detail: "rps_tie_detail") }
        }
    }

    private func fighter(_ player: RPSPlayer, move: RPSMove?, state: RPSSnapshot, winner: Bool, mirrored: Bool = false) -> some View {
        VStack(spacing: 12) {
            RPSHand(move: move, color: RPSTheme.color(player), countdown: state.countdown, mirrored: mirrored, winner: winner)
            Text(player.name).font(.system(.headline, design: .rounded)).multilineTextAlignment(.center)
            LocalizedText(move?.titleKey ?? "rps_hidden").font(.caption).foregroundStyle(RPSTheme.secondary)
            if winner {
                Image(systemName: "crown.fill").foregroundStyle(RPSTheme.mint)
                    .accessibilityLabel(appViewModel.localized("rps_winner", replacements: ["name": player.name]))
            }
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func roundComplete(_ state: RPSSnapshot) -> some View {
        VStack(spacing: 20) {
            heading("rps_round_done", detail: "rps_advancing")
            ForEach(state.currentRound?.advancingPlayers ?? []) { player in
                HStack {
                    RPSAvatar(player: player)
                    Text(player.name).font(.system(.headline, design: .rounded))
                    Spacer()
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func championView(_ player: RPSPlayer, count: Int) -> some View {
        VStack(spacing: 20) {
            VStack(spacing: 12) {
                Image(systemName: "crown.fill").font(.largeTitle).foregroundStyle(RPSTheme.mint)
                    .accessibilityHidden(true)
                RPSAvatar(player: player, size: 80)
            }
            VStack(spacing: 8) {
                Text(player.name).font(.system(.largeTitle, design: .rounded, weight: .bold))
                    .accessibilityAddTraits(.isHeader)
                LocalizedText("rps_champion").font(.subheadline).foregroundStyle(RPSTheme.mint)
            }
            .multilineTextAlignment(.center)
            LocalizedText("rps_champion_detail", replacements: ["count": "\(count)"])
                .font(.subheadline).foregroundStyle(RPSTheme.secondary).multilineTextAlignment(.center)
            Button { returnToLobby() } label: {
                LocalizedText("rps_edit_players").font(.subheadline.weight(.semibold))
                    .padding(12).foregroundStyle(RPSTheme.mint)
            }
        }
    }

    @ViewBuilder
    private var footer: some View {
        VStack(spacing: 10) {
            if let state = model.snapshot {
                switch state.phase {
                case .draw: advanceButton("rps_enter")
                case .choosing:
                    if !state.localPlayerIsPlaying {
                        RPSPrimaryButton(key: "rps_watch", icon: "play.fill", enabled: !model.isSending) {
                            Task { await model.play(nil) }
                        }
                    }
                case .countdown:
                    HStack(spacing: 10) {
                        ProgressView().tint(RPSTheme.mint)
                        LocalizedText("rps_locked").font(.subheadline).foregroundStyle(RPSTheme.secondary)
                    }.padding(12)
                case .reveal: advanceButton(state.activeMatch?.winnerID == nil ? "rps_retry" : "rps_continue")
                case .roundComplete:
                    advanceButton(state.currentRound?.advancingPlayers.count == 1 ? "rps_show_champion" : "rps_next_round")
                case .finished:
                    RPSPrimaryButton(key: "rps_replay", icon: "arrow.clockwise", enabled: !model.isSending) {
                        Task { await model.start() }
                    }
                }
            } else {
                LocalizedText("rps_demo_detail").font(.caption2).foregroundStyle(RPSTheme.secondary)
                    .multilineTextAlignment(.center)
                RPSPrimaryButton(key: "rps_start", icon: "shuffle", enabled: !model.isSending) {
                    Task { await model.start() }
                }
            }
        }
        .frame(maxWidth: 560)
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 10)
        .frame(maxWidth: .infinity)
        .background(RPSTheme.ink)
    }

    private func advanceButton(_ key: String) -> some View {
        RPSPrimaryButton(key: key, enabled: !model.isSending) { Task { await model.advance() } }
    }

    private func returnToLobby() {
        model.stop()
        observationID = UUID()
    }

    private func heading(_ key: String, detail: String, replacements: [String: String] = [:]) -> some View {
        VStack(spacing: 10) {
            LocalizedText(key, replacements: replacements).font(.system(.title, design: .rounded, weight: .bold))
                .accessibilityAddTraits(.isHeader)
            LocalizedText(detail).font(.subheadline).foregroundStyle(RPSTheme.secondary).lineSpacing(3)
        }
        .multilineTextAlignment(.center).frame(maxWidth: .infinity)
    }

    private func sectionTitle(_ key: String) -> some View {
        LocalizedText(key).font(.system(.subheadline, design: .rounded, weight: .semibold))
            .foregroundStyle(RPSTheme.secondary)
            .accessibilityAddTraits(.isHeader)
    }

    private func rule(title: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            LocalizedText(title).font(.subheadline.weight(.semibold))
            LocalizedText(detail).font(.caption).foregroundStyle(RPSTheme.secondary).lineSpacing(3)
        }
    }
}

#Preview {
    NavigationStack { RockPaperScissorsView().environmentObject(AppViewModel()) }
}
