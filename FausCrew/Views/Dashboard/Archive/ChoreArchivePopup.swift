import SwiftUI
import FausCrewCore

/// Chores closed before the dashboard's 48-hour window, one month at a time, as a full-screen
/// popup like `NotificationsPopup`. A tapped row opens its read-only detail on top of this popup,
/// so closing the detail returns to the list.
struct ChoreArchivePopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var store: ChoreArchiveStore
    let onDismiss: () -> Void

    @State private var selectedChore: Chore?

    var body: some View {
        ZStack {
            AppDesign.Colors.scrim
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            FausPopupShell(
                watermark: Image(systemName: "archivebox.fill"),
                watermarkOffset: 84,
                title: appViewModel.localized("chore_archive_title", tr: "Arşiv", en: "Archive"),
                subtitle: appViewModel.currentHouseDetails?.name ?? appViewModel.houseName,
                onClose: onDismiss,
                badge: Image(systemName: "archivebox.fill").font(.system(size: 15, weight: .semibold))
            ) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: AppDesign.Spacing.md) {
                        monthHeader
                        archiveContent
                    }
                    .padding(AppDesign.Spacing.xl)
                }
                .refreshable { await store.refresh() }
                .frame(maxHeight: 500)
                .clipped()
            } footer: {
                EmptyView()
            }
            .padding(.horizontal, AppDesign.Spacing.xl)

            if let chore = selectedChore {
                ChoreDetailPopup(chore: chore, onDismiss: { selectedChore = nil })
            }
        }
        .task { await store.open() }
    }

    // MARK: - Month

    private var monthHeader: some View {
        HStack {
            monthButton(systemImage: "chevron.left", isEnabled: true) { await store.showPreviousMonth() }
            Spacer()
            Text(monthTitle)
                .font(AppDesign.Typography.headline)
                .foregroundStyle(AppDesign.Colors.textPrimary)
            Spacer()
            monthButton(systemImage: "chevron.right", isEnabled: store.canShowNextMonth) { await store.showNextMonth() }
        }
    }

    private func monthButton(systemImage: String, isEnabled: Bool, action: @escaping () async -> Void) -> some View {
        Button { Task { await action() } } label: {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(HouseJourneyTheme.accentOrangeInk)
                .frame(width: 36, height: 36)
                .background(HouseJourneyTheme.accentOrange.opacity(0.12), in: Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.35)
    }

    private var monthTitle: String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: APILanguage.code)
        formatter.calendar = store.calendar
        formatter.timeZone = store.calendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("LLLL yyyy")
        return formatter.string(from: store.monthStart).localizedCapitalized
    }

    // MARK: - Content

    private var errorText: String {
        let message = store.failureMessage
            ?? appViewModel.localized("chore_archive_error", tr: "Arşiv yüklenemedi", en: "Couldn't load the archive")
        return message + "\n" + appViewModel.localized("chore_archive_retry", tr: "Tekrar dene", en: "Try again")
    }

    @ViewBuilder
    private var archiveContent: some View {
        switch store.phase {
        case .idle, .loading:
            ForEach(0..<4, id: \.self) { _ in NotificationSkeletonRow() }
        case .failed:
            NotificationStatusCard(
                icon: "wifi.exclamationmark",
                tint: AppDesign.Colors.error,
                text: errorText,
                action: { Task { await store.refresh() } }
            )
        case .loaded where store.chores.isEmpty:
            NotificationStatusCard(
                icon: "archivebox",
                tint: HouseJourneyTheme.accentOrangeInk,
                text: appViewModel.localized(
                    "chore_archive_empty",
                    tr: "Bu ayda kapanmış görev yok",
                    en: "No chores closed this month"
                )
            )
        case .loaded:
            ForEach(store.chores) { chore in
                ModernChoreRow(chore: chore, onTap: { selectedChore = chore }, detail: detail(for: chore))
            }
            pagingFooter
        }
    }

    @ViewBuilder
    private var pagingFooter: some View {
        if store.isLoadingMore {
            ProgressView().padding(.vertical, AppDesign.Spacing.md)
        } else if store.loadMoreFailed {
            Button { Task { await store.loadMore() } } label: {
                Label(errorText.replacingOccurrences(of: "\n", with: ". "), systemImage: "arrow.clockwise")
                    .font(AppDesign.Typography.caption.weight(.semibold))
                    .foregroundStyle(HouseJourneyTheme.accentOrangeInk)
                    .padding(.vertical, AppDesign.Spacing.md)
            }
            .buttonStyle(.plain)
        } else if store.canLoadMore {
            Button { Task { await store.loadMore() } } label: {
                Text(appViewModel.localized("chore_archive_load_more", tr: "Daha fazla göster", en: "Show more"))
                    .font(AppDesign.Typography.subheadline.weight(.semibold))
                    .foregroundStyle(HouseJourneyTheme.accentOrangeInk)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppDesign.Spacing.md)
                    .background(HouseJourneyTheme.accentOrange.opacity(0.12), in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Row detail

    /// "Closed <date> · Completed by <name>", or the failure reason for a Failed chore. `completedBy`
    /// is looked up as a member only for Completed chores: for Failed ones it is the backend's
    /// "system" marker, never a user.
    private func detail(for chore: Chore) -> String? {
        let outcome: String? = switch chore.choreStatus {
        case .completed: completedBy(chore)
        case .failed: appViewModel.failureMessage(chore.failureReason)
        case .draft, .progress, .inTest, .unknown: nil
        }
        // No readable date: leave the "Closed" part out instead of printing a placeholder.
        let closed = chore.completedAt.flatMap(FausCrewDateFormatter.parseAPIDate).map { _ in
            appViewModel
                .localized("chore_archive_closed_at", tr: "Kapandı: {date}", en: "Closed {date}")
                .replacingOccurrences(of: "{date}", with: FausCrewDateFormatter.displayDate(from: chore.completedAt))
        }
        let text = [closed, outcome].compactMap { $0 }.joined(separator: " · ")
        return text.isEmpty ? nil : text
    }

    private func completedBy(_ chore: Chore) -> String {
        guard let id = chore.completedBy, !id.isEmpty,
              let member = appViewModel.dashboardMembers.first(where: { $0.apiId == id }) else {
            return appViewModel.localized("chore_archive_former_member", tr: "Eski üye", en: "Former member")
        }
        return appViewModel
            .localized("chore_archive_completed_by", tr: "Tamamlayan: {name}", en: "Completed by {name}")
            .replacingOccurrences(of: "{name}", with: member.name)
    }
}

#if DEBUG
#Preview {
    ChoreArchivePopup(store: AppViewModel.preview.choreArchiveStore, onDismiss: {})
        .environmentObject(AppViewModel.preview)
}
#endif
