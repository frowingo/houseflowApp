import SwiftUI
import FausCrewCore

/// The selected house's notifications as a full-screen popup, like `NewAnnouncementPopup`.
/// Opening it moves the "seen" marker; the rows newer than the old marker keep their accent bar.
struct NotificationsPopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @ObservedObject var store: NotificationStore
    let onSelect: (HouseNotification) -> Void
    let onDismiss: () -> Void

    var body: some View {
        ZStack {
            AppDesign.Colors.scrim
                .ignoresSafeArea()
                .onTapGesture(perform: onDismiss)

            FausPopupShell(
                watermark: Image(systemName: "bell.fill"),
                watermarkOffset: 84,
                title: appViewModel.localized("notifications_title", tr: "Bildirimler", en: "Notifications"),
                subtitle: appViewModel.currentHouseDetails?.name ?? appViewModel.houseName,
                onClose: onDismiss,
                badge: Image(systemName: "bell.fill").font(.system(size: 15, weight: .semibold))
            ) {
                ScrollView(showsIndicators: false) {
                    LazyVStack(spacing: AppDesign.Spacing.md) {
                        panelContent
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
        }
        .task { await store.openPanel() }
        .onDisappear { store.closePanel() }
    }

    private var retryText: String {
        appViewModel.localized(
            "notifications_error_retry",
            tr: "Bildirimler yüklenemedi. Tekrar dene",
            en: "Couldn't load notifications. Try again"
        )
    }

    @ViewBuilder
    private var panelContent: some View {
        switch store.phase {
        case .idle, .loading:
            ForEach(0..<4, id: \.self) { _ in NotificationSkeletonRow() }
        case .failed:
            NotificationStatusCard(
                icon: "wifi.exclamationmark",
                tint: AppDesign.Colors.error,
                text: retryText,
                action: { Task { await store.refresh() } }
            )
        case .loaded where store.items.isEmpty:
            NotificationStatusCard(
                icon: "bell.slash",
                tint: HouseJourneyTheme.accentOrangeInk,
                text: appViewModel.localized(
                    "notifications_empty",
                    tr: "Son 30 günde bildirim yok",
                    en: "No notifications in the last 30 days"
                )
            )
        case .loaded:
            ForEach(store.items) { item in
                Button { onSelect(item) } label: { row(item) }
                    .buttonStyle(.plain)
                    .onAppear {
                        if item.id == store.items.last?.id { Task { await store.loadMore() } }
                    }
            }
            pagingFooter
        }
    }

    private func row(_ item: HouseNotification) -> some View {
        NotificationRow(
            item: item,
            sender: appViewModel.dashboardMembers.first { $0.apiId == item.senderUserID },
            formerMemberLabel: appViewModel.localized(
                "notifications_former_member",
                tr: "Eski üye",
                en: "Former member"
            ),
            isUnread: store.isUnread(item),
            timeText: item.createdDate.map { NotificationTimeText.relative($0) } ?? ""
        )
    }

    @ViewBuilder
    private var pagingFooter: some View {
        if store.isLoadingMore {
            ProgressView().padding(.vertical, AppDesign.Spacing.md)
        } else if store.loadMoreFailed {
            Button { Task { await store.loadMore() } } label: {
                Label(
                    retryText,
                    systemImage: "arrow.clockwise"
                )
                .font(AppDesign.Typography.caption.weight(.semibold))
                .foregroundStyle(HouseJourneyTheme.accentOrangeInk)
                .padding(.vertical, AppDesign.Spacing.md)
            }
            .buttonStyle(.plain)
        }
    }
}

#if DEBUG
#Preview {
    NotificationsPopup(
        store: AppViewModel.preview.notificationStore,
        onSelect: { _ in },
        onDismiss: {}
    )
    .environmentObject(AppViewModel.preview)
}
#endif
