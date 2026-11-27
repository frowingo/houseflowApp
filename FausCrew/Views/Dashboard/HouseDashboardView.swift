import SwiftUI
import FausCrewCore

/// Ana dashboard view - ev görevlerini ve üyelerini gösterir
/// Refactored: Component'lere bölündü, Design System kullanıyor
struct HouseDashboardView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    /// Observed directly: its changes do not go through `AppViewModel`.
    @ObservedObject var routeHandler: PushRouteHandler
    @Environment(\.fausTheme) private var theme
    @State private var selectedChore: Chore? = nil
    @State private var showChoreDetail = false
    @State private var showNewAnnouncement = false
    @State private var showNotifications = false
    @State private var showArchive = false
    @State private var catalogEntry: ChoreCatalogEntry?
    @State private var appeared = false
    @Environment(\.fausSplashActive) private var splashActive
    
    var body: some View {
        ZStack {
            MainScreenBackground()

            ScrollView {
                VStack(spacing: AppDesign.Spacing.lg) {
                    headerSection

                    ChoreProgressCard(chores: appViewModel.dashboardChores)
                        .padding(.horizontal, AppDesign.Spacing.xxl)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 22)
                        .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.14), value: appeared)

                    TodaysChoresCard(
                        chores: appViewModel.dashboardChores,
                        onChoreDetailTap: { chore in
                            selectedChore = chore
                            showChoreDetail = true
                        },
                        onAddChore: {
                            catalogEntry = .drafts
                        },
                        onOpenArchive: {
                            withAnimation(AppDesign.Animation.standard) {
                                showArchive = true
                            }
                        }
                    )
                    .padding(.horizontal, AppDesign.Spacing.xxl)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 26)
                    .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.22), value: appeared)

                    HouseMembersCard(members: appViewModel.dashboardMembers)
                        .padding(.horizontal, AppDesign.Spacing.xxl)
                        .opacity(appeared ? 1 : 0)
                        .offset(y: appeared ? 0 : 26)
                        .animation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.32), value: appeared)

                    // Tab bar clearance
                    Spacer(minLength: 120)
                }
            }
            .overlay(popupsOverlay)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.78).delay(0.05)) {
                appeared = true
            }
        }
        // First sight of the dashboard, once the splash and entrance animations are done: the
        // system prompt appears only while the permission is still undetermined.
        .task(id: splashActive) {
            guard !splashActive else { return }
            try? await Task.sleep(for: .seconds(1))
            guard !Task.isCancelled else { return }
            _ = await PushPermission.requestIfUndetermined()
        }
        // A tapped push asks for a chore's detail, or for the dashboard to be cleared of popups.
        .onChange(of: routeHandler.choreToOpen, initial: true) { _, choreID in
            guard let choreID else { return }
            openChoreFromPush(choreID)
        }
        .onChange(of: routeHandler.dashboardResetCount) { _, _ in
            closeAllPopups()
        }
        // The flag is shared; a dashboard destroyed with a popup open (house switch) must not leave it set.
        .onDisappear { appViewModel.isOverlayPresented = false }
    }
    
    // MARK: - Header Section

    private var headerSection: some View {
        ZStack(alignment: .leading) {
            BrandHeroCardBackground()

            // House image + greeting/name + announcement action
            HStack(alignment: .center, spacing: AppDesign.Spacing.md) {
                houseImage

                VStack(alignment: .leading, spacing: 2) {
                    Text(appViewModel.localized(
                        "dashboard_greeting_template",
                        replacements: [
                            "first_name": appViewModel.currentUser?.firstName
                                ?? appViewModel.localized("common_user_fallback")
                        ]
                    ))
                        .font(.system(size: 14, weight: .medium, design: .rounded))
                        .foregroundStyle(theme.decor.heroAccentText)
                        .lineLimit(1)
                    Text(appViewModel.currentHouseDetails?.name ?? appViewModel.houseName)
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(AppDesign.Colors.onHero)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                NotificationBellButton(store: appViewModel.notificationStore) {
                    withAnimation(AppDesign.Animation.standard) {
                        showNotifications = true
                    }
                }

                Button {
                    withAnimation(AppDesign.Animation.standard) {
                        showNewAnnouncement = true
                    }
                } label: {
                    Image(systemName: "megaphone.fill")
                        .font(.system(size: AppDesign.Size.iconMedium))
                        .foregroundStyle(AppDesign.Colors.onHero.opacity(0.9))
                        .frame(width: 40, height: 40)
                        .background(theme.decor.heroOrnament.opacity(0.18))
                        .clipShape(Circle())
                }
                .accessibilityLabel(appViewModel.localized(
                    "new_announcement_action_accessibility_label",
                    fallback: "Create announcement"
                ))
            }
            .padding(.horizontal, AppDesign.Spacing.lg)
            .padding(.vertical, AppDesign.Spacing.xl)
        }
        .padding(.horizontal, AppDesign.Spacing.xl)
        .padding(.top, AppDesign.Spacing.xl)
        .padding(.bottom, AppDesign.Spacing.sm)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    private var houseImageURL: URL? {
        let value = (appViewModel.currentHouseDetails?.profileImage
            ?? appViewModel.currentHouse?.profileImage
            ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : URL(string: value)
    }

    private var houseImage: some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        return CachedRemoteImage(url: houseImageURL) { image in
            image.resizable().scaledToFill()
        } placeholder: {
            houseImagePlaceholder
        } failure: {
            houseImagePlaceholder
        }
        .frame(width: 66, height: 66)
        .clipShape(shape)
        .padding(3)
        .background(shape.fill(LinearGradient(colors: theme.decor.heroFrame, startPoint: .topLeading, endPoint: .bottomTrailing)))
        .shadow(color: Color(red: 0.23, green: 0.04, blue: 0.12).opacity(0.3), radius: 7, x: 0, y: 5)
        .accessibilityHidden(true)
    }

    private var houseImagePlaceholder: some View {
        ZStack {
            theme.decor.heroTile
            FausHouseIcon(size: 32)
        }
    }

    // MARK: - Popups Overlay
    
    private var popupsOverlay: some View {
        Group {
            if showChoreDetail, let chore = selectedChore {
                ChoreDetailPopup(
                    chore: chore,
                    onDismiss: {
                        dismissChoreDetail()
                    }
                )
            }

            if let catalogEntry {
                ChoreCatalogPopup(
                    entry: catalogEntry,
                    catalog: appViewModel.choreCatalogStore,
                    ownerId: appViewModel.currentUserId,
                    onDismiss: {
                        dismissCatalog()
                    }
                )
                .environmentObject(appViewModel)
            }

            if showNotifications {
                NotificationsPopup(
                    store: appViewModel.notificationStore,
                    onSelect: { notification in
                        dismissNotifications()
                        openChore(notification.choreID)
                    },
                    onDismiss: {
                        dismissNotifications()
                    }
                )
            }

            if showArchive {
                ChoreArchivePopup(
                    store: appViewModel.choreArchiveStore,
                    onDismiss: {
                        dismissArchive()
                    }
                )
            }

            if showNewAnnouncement {
                NewAnnouncementPopup(
                    onPublish: { title, message in
                        await appViewModel.createAnnouncement(
                            title: title,
                            description: message
                        )
                    },
                    onDismiss: {
                        dismissNewAnnouncement()
                    }
                )
            }
        }
        .onChange(of: showChoreDetail) { _, _ in syncOverlayPresentation() }
        .onChange(of: showNewAnnouncement) { _, _ in syncOverlayPresentation() }
        .onChange(of: showNotifications) { _, _ in syncOverlayPresentation() }
        .onChange(of: showArchive) { _, _ in syncOverlayPresentation() }
        .onChange(of: catalogEntry) { _, _ in syncOverlayPresentation() }
    }

    private func syncOverlayPresentation() {
        appViewModel.isOverlayPresented = showChoreDetail || showNewAnnouncement || showNotifications || showArchive || catalogEntry != nil
    }

    /// Shows a chore's detail when it is in the loaded house; any popup in the way closes first.
    private func openChore(_ choreID: String?) {
        guard let choreID,
              let chore = appViewModel.dashboardChores.first(where: { $0.choreApiId == choreID }) else { return }
        closeAllPopups()
        selectedChore = chore
        showChoreDetail = true
    }

    private func openChoreFromPush(_ choreID: String) {
        openChore(choreID)
        routeHandler.consumeChoreToOpen()
    }

    private func closeAllPopups() {
        hideKeyboard()
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showChoreDetail = false
            selectedChore = nil
            showNewAnnouncement = false
            showNotifications = false
            showArchive = false
            catalogEntry = nil
        }
        syncOverlayPresentation()
    }

    private func dismissChoreDetail() {
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showChoreDetail = false
                selectedChore = nil
            }
        }
    }

    private func dismissCatalog() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            catalogEntry = nil
        }
    }

    private func dismissNotifications() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showNotifications = false
        }
    }

    private func dismissArchive() {
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            showArchive = false
        }
    }

    private func dismissNewAnnouncement() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        DispatchQueue.main.async {
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                showNewAnnouncement = false
            }
        }
    }
}

#if DEBUG
#Preview {
    let model = AppViewModel.preview
    return HouseDashboardView(routeHandler: model.pushRouteHandler)
        .environmentObject(model)
}
#endif
