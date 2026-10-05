import SwiftUI

/// Displays persisted ranks as supplied, including ties and unranked cancellations.
struct HouseRocketsOnlineResultView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let state: HouseRocketsOnlineResultState
    let localPlayerID: String?
    let memberNames: [String: String]
    let onRetry: () -> Void
    let onRematch: () -> Void
    let onExit: () -> Void

    var body: some View {
        ZStack {
            HouseRocketsTheme.background.opacity(0.92).ignoresSafeArea()
            VStack(spacing: AppDesign.Spacing.lg) {
                ScrollView {
                    VStack(spacing: AppDesign.Spacing.lg) {
                        HouseRocketsRocketMark().frame(width: 56, height: 56)
                            .accessibilityHidden(true)
                        Text(title).font(.title.weight(.bold)).multilineTextAlignment(.center)
                            .accessibilityAddTraits(.isHeader)
                        Text(copy(detailKey)).font(.subheadline)
                            .foregroundStyle(HouseRocketsTheme.muted)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                        if state.phase == .waiting {
                            ProgressView().tint(HouseRocketsTheme.accent)
                                .accessibilityLabel(copy("house_rockets_online_finalizing"))
                        }
                        if let result = state.result {
                            if result.startedAt != nil {
                                Label(copy("house_rockets_result_duration", replacements: [
                                    "seconds": result.durationSeconds.formatted(.number.precision(.fractionLength(1)))
                                ]), systemImage: "timer")
                                .font(.subheadline).monospacedDigit()
                            }
                            VStack(spacing: AppDesign.Spacing.md) {
                                ForEach(orderedPlayers, id: \.playerId) { player in
                                    HStack(spacing: AppDesign.Spacing.md) {
                                        Text(player.rank.map { "\($0)." } ?? "—")
                                            .font(.headline).monospacedDigit().frame(width: 32, alignment: .leading)
                                            .accessibilityLabel(player.rank.map {
                                                copy("house_rockets_result_rank", replacements: ["rank": "\($0)"])
                                            } ?? copy("house_rockets_result_unranked"))
                                        if let identity = state.identities[player.playerId] {
                                            Circle().fill(Color(HouseRocketsPalette.player(identity.color)))
                                                .frame(width: 10, height: 10).accessibilityHidden(true)
                                        }
                                        VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                                            Text(verbatim: name(player.playerId)).font(.subheadline.weight(.semibold))
                                            if player.playerId == localPlayerID {
                                                Text(copy("house_rockets_you")).font(.caption)
                                                    .foregroundStyle(HouseRocketsTheme.muted)
                                            }
                                        }
                                        Spacer(minLength: 8)
                                        Text(copy("house_rockets_result_distance", replacements: [
                                            "distance": player.distance.formatted(.number.precision(.fractionLength(0)))
                                        ]))
                                        .font(.subheadline).monospacedDigit().foregroundStyle(HouseRocketsTheme.muted)
                                    }
                                    .accessibilityElement(children: .combine)
                                }
                            }
                            .padding(.vertical, AppDesign.Spacing.sm)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                if state.phase == .failed {
                    TimelineView(.periodic(from: .now, by: 1)) { _ in
                        let now = ProcessInfo.processInfo.systemUptime
                        if allowsRetry {
                            let remaining = max(0, Int(ceil(state.retryNotBefore - now)))
                            Button(copy(remaining > 0 ? "house_rockets_result_retry_after" : "house_rockets_result_retry",
                                        replacements: ["seconds": "\(remaining)"]), action: onRetry)
                                .font(.headline).frame(minHeight: 44)
                                .disabled(!state.canRetry(at: now))
                        }
                    }
                }
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: AppDesign.Spacing.md) { actions }
                    VStack(spacing: AppDesign.Spacing.sm) { actions }
                }
            }
            .foregroundStyle(HouseRocketsTheme.ink)
            .padding(AppDesign.Spacing.xl)
            .frame(maxWidth: 620)
            .background(HouseRocketsTheme.panel, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
            .padding(AppDesign.Spacing.lg)
        }
    }

    @ViewBuilder private var actions: some View {
        Button(copy("house_rockets_exit"), action: onExit)
            .frame(maxWidth: .infinity, minHeight: 48).buttonStyle(.bordered)
        if state.canRematch {
            Button(copy("house_rockets_rematch"), action: onRematch)
                .frame(maxWidth: .infinity, minHeight: 48).buttonStyle(.borderedProminent)
                .tint(HouseRocketsTheme.accent).foregroundStyle(HouseRocketsTheme.background)
        }
    }

    private var orderedPlayers: [HouseRocketsPlayerResultDTO] {
        (state.result?.players ?? []).enumerated().sorted {
            let lhs = $0.element.rank ?? Int.max, rhs = $1.element.rank ?? Int.max
            return lhs == rhs ? $0.offset < $1.offset : lhs < rhs
        }.map(\.element)
    }

    private var title: String {
        if state.phase == .waiting { return copy("house_rockets_online_finalizing") }
        if state.phase == .failed { return copy("house_rockets_result_unavailable") }
        guard let result = state.result, result.status == .completed else { return copy("house_rockets_result_cancelled") }
        guard let winner = result.winnerId else { return copy("house_rockets_draw") }
        return winner == localPlayerID ? copy("house_rockets_won") : copy("house_rockets_lost", replacements: ["name": name(winner)])
    }

    private var detailKey: String {
        if state.phase == .waiting { return "house_rockets_result_waiting_detail" }
        if state.phase == .failed {
            switch state.failure {
            case .http(401, _): return "house_rockets_online_sign_in"
            case .http(403, _): return "house_rockets_online_forbidden"
            case .invalidPayload, .protocolFailure: return "house_rockets_online_update_required"
            default: return "house_rockets_result_unavailable_detail"
            }
        }
        if state.phase == .cancelledWithoutRecord { return "house_rockets_result_cancelled_before_start" }
        if state.result?.status == .completed {
            return state.result?.winnerId == nil ? "house_rockets_draw_detail" : "house_rockets_result_detail"
        }
        switch state.endReason {
        case .sessionExpired: return "house_rockets_result_expired"
        case .cancelledByUser: return "house_rockets_result_cancelled_by_user"
        case .insufficientPlayers: return "house_rockets_result_insufficient_players"
        default: return "house_rockets_result_technical_cancel"
        }
    }

    private var allowsRetry: Bool { state.canRetry(at: max(ProcessInfo.processInfo.systemUptime, state.retryNotBefore)) }
    private func name(_ id: String) -> String {
        state.identities[id]?.displayName ?? memberNames[id] ?? copy(id == localPlayerID ? "house_rockets_you" : "house_rockets_member")
    }
    private func copy(_ key: String, replacements: [String: String] = [:]) -> String {
        appViewModel.localized(key, replacements: replacements)
    }
}
