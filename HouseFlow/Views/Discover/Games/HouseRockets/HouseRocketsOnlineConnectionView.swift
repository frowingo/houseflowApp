import SwiftUI

/// Connection/control feedback over the retained course; no lifecycle decisions.
struct HouseRocketsOnlineConnectionView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    let state: HouseRocketsOnlineLobbyState
    let onRetry: () -> Void
    let onReclaimControl: () -> Void

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.25)) { _ in
            let now = ProcessInfo.processInfo.systemUptime
            ViewThatFits(in: .vertical) {
                content(at: now).fixedSize(horizontal: false, vertical: true)
                ScrollView { content(at: now) }.scrollBounceBehavior(.basedOnSize)
            }
            .foregroundStyle(HouseRocketsTheme.ink)
            .background(HouseRocketsTheme.panel, in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg))
        }
    }

    private func content(at now: TimeInterval) -> some View {
        VStack(spacing: AppDesign.Spacing.md) {
            if state.connection != .failed, !state.controlTransferred {
                ProgressView().tint(HouseRocketsTheme.accent)
            }
            Text(copy(titleKey)).font(.headline).multilineTextAlignment(.center)
                .accessibilityAddTraits(.isHeader)
            Text(copy(detailKey)).font(.subheadline).multilineTextAlignment(.center)
                .foregroundStyle(HouseRocketsTheme.muted)
                .fixedSize(horizontal: false, vertical: true)
            if state.connection == .reconnecting {
                let remaining = max(0, Int(ceil((state.retryNotBefore ?? now) - now)))
                Text(copy("house_rockets_reconnect_wait", replacements: ["seconds": "\(remaining)"]))
                    .font(.caption).monospacedDigit().foregroundStyle(HouseRocketsTheme.muted)
            }
            if state.controlTransferred, state.connection == .connected {
                Button(copy("house_rockets_reclaim_control"), action: onReclaimControl)
                    .disabled(!state.isForeground || !state.isSynced)
                    .buttonStyle(.borderedProminent).tint(HouseRocketsTheme.accent)
                    .foregroundStyle(HouseRocketsTheme.background).frame(minHeight: 44)
            } else if state.connection == .failed, state.canReconnect(at: .infinity) {
                Button(copy("house_rockets_online_retry"), action: onRetry)
                    .disabled(!state.canReconnect(at: now) || !state.isForeground)
                    .buttonStyle(.borderedProminent).tint(HouseRocketsTheme.accent)
                    .foregroundStyle(HouseRocketsTheme.background).frame(minHeight: 44)
            }
        }
        .frame(maxWidth: .infinity).padding(AppDesign.Spacing.lg)
    }

    private var titleKey: String {
        if state.connection == .failed { return "house_rockets_flight_connection_failed" }
        if state.controlTransferred { return "house_rockets_control_transferred" }
        return state.connection == .reconnecting ? "house_rockets_reconnecting" : "house_rockets_recovering"
    }

    private var detailKey: String {
        if state.connection == .failed {
            if case .connection(.http(403, _)) = state.issue { return "house_rockets_online_forbidden" }
            if state.requiresAuthentication { return "house_rockets_online_sign_in" }
            if case .connection(.protocolFailure) = state.issue { return "house_rockets_online_update_required" }
            return "house_rockets_flight_connection_failed_detail"
        }
        if state.controlTransferred { return "house_rockets_control_transferred_detail" }
        return state.connection == .reconnecting ? "house_rockets_reconnecting_detail" : "house_rockets_recovering_detail"
    }

    private func copy(_ key: String, replacements: [String: String] = [:]) -> String {
        appViewModel.localized(key, replacements: replacements)
    }
}
