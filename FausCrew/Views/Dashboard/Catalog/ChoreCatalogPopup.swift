import SwiftUI
import UIKit
import FausCrewCore

/// Where the catalog popup opens.
enum ChoreCatalogEntry: Identifiable, Hashable {
    /// The user's Drafts tab.
    case drafts
    /// A category shelf.
    case category(String)
    /// The blank editor, with the catalog behind it.
    case custom

    var id: String {
        switch self {
        case .drafts: return "drafts"
        case .category(let id): return "category.\(id)"
        case .custom: return "custom"
        }
    }
}

/// Summary of a chore created from the catalog, for the confirmation banner.
struct ChoreCatalogCreation: Equatable {
    let templateId: String
    let title: String
    let memberName: String
    let repeatDays: Int
}

/// What the banner at the bottom of the catalog confirms, or the request that failed.
struct ChoreCatalogNotice: Equatable {
    enum Kind: Equatable {
        case created(memberName: String, repeatDays: Int)
        case draftSaved
        case draftUpdated
        /// A draft delete the server refused; `message` is the server's localized text.
        case deleteFailed(message: String?)
    }

    let id = UUID()
    let title: String
    let kind: Kind
}

/// The chore catalog as a large popup on the theme header. Picking a card slides the editor in
/// over the catalog; a created chore (or a saved draft) slides back with a confirmation so
/// several can be handled in a row. The first tab holds the user's drafts. Shelves and drafts
/// come from the server (`ChoreCatalogStore`), fetched each time the popup opens and whenever
/// the app returns to the foreground while it is open.
struct ChoreCatalogPopup: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @Environment(\.fausTheme) private var theme
    @Environment(\.scenePhase) private var scenePhase
    @ObservedObject var catalog: ChoreCatalogStore

    let onDismiss: () -> Void

    private struct EditorRoute: Equatable {
        /// The card's id: a record id, or the blank card's.
        let templateId: String
        let prefillTitle: String?
        /// The card as it was opened, so a refresh behind the editor does not swap it.
        let template: ChoreTemplate
    }

    private static let draftsId = "drafts"
    private static let contentTop = "catalog-content-top"

    @State private var selection: String
    @State private var editor: EditorRoute?
    @State private var query = ""
    @State private var addedCounts: [String: Int] = [:]
    @State private var notice: ChoreCatalogNotice?
    @State private var draftPendingDelete: ChoreTemplate?
    @State private var bannerTask: Task<Void, Never>?
    @State private var appeared = false
    @State private var isClosing = false
    @FocusState private var isSearchFocused: Bool

    /// - Parameter ownerId: the signed-in user; the list is fetched for them.
    init(entry: ChoreCatalogEntry, catalog: ChoreCatalogStore, ownerId: String?, onDismiss: @escaping () -> Void) {
        self.onDismiss = onDismiss
        self.catalog = catalog
        self.ownerId = ownerId
        switch entry {
        case .drafts:
            _selection = State(initialValue: Self.draftsId)
            _editor = State(initialValue: nil)
        case .category(let id):
            _selection = State(initialValue: id)
            _editor = State(initialValue: nil)
        case .custom:
            _selection = State(initialValue: Self.draftsId)
            _editor = State(initialValue: EditorRoute(templateId: ChoreCatalog.blankTemplate.id, prefillTitle: nil,
                                                      template: ChoreCatalog.blankTemplate))
        }
    }

    private let ownerId: String?

    private var systemTemplates: [ChoreTemplate] { catalog.systemRecords.map(ChoreTemplate.init(record:)) }
    private var draftTemplates: [ChoreTemplate] { catalog.userRecords.map(ChoreTemplate.init(record:)) }

    /// Skeleton cards only on the first load; later refreshes keep the list on screen.
    private var isFirstLoad: Bool {
        !catalog.hasLoaded && (catalog.phase == .loading || catalog.phase == .idle)
    }

    private var loadFailure: ChoreCatalogFailure? {
        guard !catalog.hasLoaded, case .failed(let failure) = catalog.phase else { return nil }
        return failure
    }

    private var trimmedQuery: String {
        query.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var selectedCategory: ChoreCategory? {
        ChoreCatalog.categories.first { $0.id == selection }
    }

    /// The home indicator area; the dashboard ignores the bottom container safe area.
    private var bottomInset: CGFloat {
        let window = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }
        return window?.safeAreaInsets.bottom ?? 0
    }

    var body: some View {
        ZStack {
            AppDesign.Colors.scrim
                .ignoresSafeArea()
                .opacity(appeared ? 1 : 0)
                .onTapGesture { close() }

            container
                .padding(.horizontal, 12)
                .padding(.top, AppDesign.Spacing.sm)
                .padding(.bottom, max(bottomInset, AppDesign.Spacing.md) + AppDesign.Spacing.sm)
                .scaleEffect(appeared ? 1 : 0.92)
                .offset(y: appeared ? 0 : 40)
                .opacity(appeared ? 1 : 0)
        }
        .onAppear {
            withAnimation(.spring(response: 0.46, dampingFraction: 0.82)) {
                appeared = true
            }
        }
        .task { await catalog.refresh(ownerId: ownerId) }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await catalog.refresh(ownerId: ownerId) }
        }
        .onDisappear { bannerTask?.cancel() }
        .alert(
            appViewModel.catalogText("chore_catalog_draft_delete_title", tr: "Taslak silinsin mi?", en: "Delete this draft?"),
            isPresented: Binding(
                get: { draftPendingDelete != nil },
                set: { if !$0 { draftPendingDelete = nil } }
            ),
            presenting: draftPendingDelete
        ) { draft in
            Button(appViewModel.catalogText("chore_catalog_draft_delete_confirm", tr: "Sil", en: "Delete"), role: .destructive) {
                UINotificationFeedbackGenerator().notificationOccurred(.warning)
                delete(draft)
            }
            Button(appViewModel.localized("common_cancel", fallback: "Cancel"), role: .cancel) {}
        } message: { draft in
            Text(
                appViewModel.catalogText(
                    "chore_catalog_draft_delete_message",
                    tr: "“{title}” taslaklarından kaldırılacak. Eklediğin işler etkilenmez.",
                    en: "“{title}” will be removed from your drafts. Chores you added stay as they are."
                )
                .replacingOccurrences(of: "{title}", with: draft.title)
            )
        }
    }

    // MARK: - Container

    private var container: some View {
        let shape = RoundedRectangle(cornerRadius: 30, style: .continuous)
        return ZStack {
            catalogPage
                .offset(x: editor == nil ? 0 : -70)
                .opacity(editor == nil ? 1 : 0)
                .allowsHitTesting(editor == nil)

            if let editor {
                editorPage(editor)
                    .transition(.move(edge: .trailing))
                    .zIndex(1)
            }
        }
        .background(MainScreenBackground(surface: .popup))
        .clipShape(shape)
        .overlay(
            shape.strokeBorder(
                LinearGradient(
                    colors: [Color.white.opacity(0.35), Color.white.opacity(0.05)],
                    startPoint: .top,
                    endPoint: .bottom
                ),
                lineWidth: 1
            )
        )
        .shadow(color: AppDesign.Colors.shadow.opacity(0.32), radius: 32, x: 0, y: 18)
    }

    // MARK: - Catalog page

    private var catalogPage: some View {
        VStack(spacing: 0) {
            catalogHeader

            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear.frame(height: 0).id(Self.contentTop)
                        content
                            .animation(.spring(response: 0.36, dampingFraction: 0.86), value: catalog.records)
                            .padding(.horizontal, AppDesign.Spacing.lg)
                            .padding(.top, AppDesign.Spacing.lg)
                            .padding(.bottom, notice == nil ? AppDesign.Spacing.xxl : 104)
                    }
                }
                .scrollDismissesKeyboard(.immediately)
                .onChange(of: selection) { _, _ in
                    withAnimation(.snappy) { proxy.scrollTo(Self.contentTop, anchor: .top) }
                }
            }
        }
        .overlay(alignment: .bottom) {
            if let notice {
                noticeBanner(notice)
                    .padding(.horizontal, AppDesign.Spacing.md)
                    .padding(.bottom, AppDesign.Spacing.md)
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(.spring(response: 0.42, dampingFraction: 0.82), value: notice)
    }

    // MARK: Header

    private var headerSubtitle: String {
        if let category = selectedCategory {
            return appViewModel.catalogTagline(category)
        }
        return appViewModel.catalogText(
            "chore_catalog_drafts_subtitle",
            tr: "Kaydettiğin işler, tek dokunuşla hazır",
            en: "Your saved chores, one tap away"
        )
    }

    private var catalogHeader: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            HStack(alignment: .center, spacing: AppDesign.Spacing.md) {
                Image(systemName: "square.grid.2x2.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                    .frame(width: 46, height: 46)
                    .background(.white.opacity(0.2), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(.white.opacity(0.3), lineWidth: 1)
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(appViewModel.catalogText("chore_catalog_title", tr: "İş Kataloğu", en: "Chore Catalog"))
                        .font(.system(size: 22, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    // Fixed line box: a longer tagline truncates instead of resizing the header.
                    Text(headerSubtitle)
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .lineLimit(1)
                        .truncationMode(.tail)
                        .frame(height: 18, alignment: .leading)
                        .contentTransition(.opacity)
                }

                Spacer(minLength: 0)

                closeButton
            }
            .padding(.horizontal, AppDesign.Spacing.lg)

            searchField
                .padding(.horizontal, AppDesign.Spacing.lg)

            if trimmedQuery.isEmpty {
                chipRail
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.top, AppDesign.Spacing.lg)
        .padding(.bottom, AppDesign.Spacing.md)
        .background { headerBackground }
        .animation(.spring(response: 0.4, dampingFraction: 0.85), value: trimmedQuery.isEmpty)
    }

    /// Always the theme's popup header; shelf colours stay on the cards and chip glyphs.
    private var headerBackground: some View {
        BrandPopupHeaderBackground(topCornerRadius: 30)
            .accessibilityHidden(true)
    }

    private var closeButton: some View {
        Button(action: close) {
            Image(systemName: "xmark")
                .font(.system(size: 13, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 32, height: 32)
                .background(.white.opacity(0.2), in: Circle())
        }
        .buttonStyle(CatalogPressStyle())
        .accessibilityLabel(appViewModel.localized("common_close", fallback: "Close"))
    }

    private var searchField: some View {
        HStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.white.opacity(0.8))
            TextField(
                "",
                text: $query,
                prompt: Text(appViewModel.catalogText("chore_catalog_search_placeholder", tr: "İş ara: bulaşık, köpek, çöp…", en: "Search: dishes, dog, trash…"))
                    .foregroundStyle(.white.opacity(0.62))
            )
            .font(.system(size: 15, weight: .medium))
            .foregroundStyle(.white)
            .tint(.white)
            .focused($isSearchFocused)
            .submitLabel(.search)
            .autocorrectionDisabled()
            if !query.isEmpty {
                Button {
                    withAnimation(AppDesign.Animation.quick) { query = "" }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.8))
                }
                .accessibilityLabel(appViewModel.catalogText("chore_catalog_search_clear", tr: "Aramayı temizle", en: "Clear search"))
            }
        }
        .padding(.horizontal, AppDesign.Spacing.md)
        .frame(height: 42)
        .background(.white.opacity(isSearchFocused ? 0.26 : 0.18), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(.white.opacity(isSearchFocused ? 0.55 : 0.22), lineWidth: 1)
        )
        .animation(AppDesign.Animation.quick, value: isSearchFocused)
    }

    // MARK: Shelf chips

    private var chipRail: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: AppDesign.Spacing.sm) {
                    chip(
                        id: Self.draftsId,
                        icon: "tray.full.fill",
                        title: appViewModel.catalogText("chore_catalog_drafts_chip", tr: "Taslaklar", en: "Drafts"),
                        ink: HouseJourneyTheme.accentOrangeDeep
                    )
                    ForEach(ChoreCatalog.categories) { category in
                        chip(
                            id: category.id,
                            icon: category.icon,
                            title: appViewModel.catalogName(category),
                            ink: category.deep
                        )
                    }
                }
                .padding(.vertical, 2)
            }
            .contentMargins(.horizontal, AppDesign.Spacing.lg, for: .scrollContent)
            .frame(height: 38)
            .onChange(of: selection) { _, id in
                withAnimation(.snappy) { proxy.scrollTo(id, anchor: .center) }
            }
            .onAppear { proxy.scrollTo(selection, anchor: .center) }
        }
    }

    private func chip(id: String, icon: String, title: String, ink: Color) -> some View {
        let isSelected = selection == id
        return Button {
            guard selection != id else { return }
            UISelectionFeedbackGenerator().selectionChanged()
            withAnimation(.spring(response: 0.34, dampingFraction: 0.8)) {
                selection = id
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                Text(title)
                    .font(.system(size: 14, weight: .semibold))
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? ink : .white)
            .padding(.horizontal, 13)
            .frame(height: 34)
            .background {
                Capsule()
                    .fill(isSelected ? Color.white : Color.white.opacity(0.16))
                    .shadow(color: isSelected ? Color.black.opacity(0.18) : .clear, radius: 6, x: 0, y: 3)
            }
            .overlay(Capsule().strokeBorder(.white.opacity(isSelected ? 0 : 0.22), lineWidth: 1))
        }
        .buttonStyle(CatalogPressStyle(scale: 0.95))
        .id(id)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    // MARK: - Content

    @ViewBuilder
    private var content: some View {
        if !trimmedQuery.isEmpty {
            searchResults
                .transition(.opacity)
        } else if let category = selectedCategory {
            categoryShelf(category)
                .id(category.id)
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 16)), removal: .opacity))
        } else {
            draftsShelf
                .transition(.asymmetric(insertion: .opacity.combined(with: .offset(y: 16)), removal: .opacity))
        }
    }

    private let gridColumns = [
        GridItem(.flexible(), spacing: AppDesign.Spacing.md),
        GridItem(.flexible(), spacing: AppDesign.Spacing.md)
    ]

    private var sectionTint: Color {
        theme.decor.accentOnCard ?? HouseJourneyTheme.accentOrangeInk
    }

    /// Catalog templates and drafts share the grid; a draft card also offers delete, and a
    /// system template carries a lock (it is read-only; saving it makes a draft).
    private func templateGrid(_ templates: [ChoreTemplate], showsCategory: Bool) -> some View {
        LazyVGrid(columns: gridColumns, spacing: AppDesign.Spacing.md) {
            ForEach(templates) { template in
                if let category = ChoreCatalog.category(id: template.categoryId) {
                    ChoreTemplateTile(
                        template: template,
                        category: category,
                        showsCategory: showsCategory,
                        addedCount: addedCounts[template.id, default: 0],
                        onTap: { open(template) },
                        onDelete: template.isDraft ? { draftPendingDelete = template } : nil
                    )
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
        }
    }

    /// Placeholder cards while the first list is on its way.
    private var skeletonGrid: some View {
        LazyVGrid(columns: gridColumns, spacing: AppDesign.Spacing.md) {
            ForEach(0..<4, id: \.self) { _ in
                ChoreTemplateSkeletonTile()
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(appViewModel.catalogText("chore_catalog_loading", tr: "Katalog yükleniyor", en: "Loading the catalog"))
    }

    /// The list could not be fetched: the server's message (or a connection hint) and a retry.
    private func loadFailureCard(_ failure: ChoreCatalogFailure) -> some View {
        CatalogStatusCard(
            icon: "wifi.exclamationmark",
            tint: AppDesign.Colors.error,
            title: appViewModel.catalogText("chore_catalog_load_failed", tr: "Katalog yüklenemedi", en: "Couldn't load the catalog"),
            detail: failure.message ?? appViewModel.catalogText(
                "chore_catalog_load_failed_detail",
                tr: "Bağlantını kontrol edip tekrar dene.",
                en: "Check your connection and try again."
            ),
            actionTitle: appViewModel.catalogText("chore_catalog_retry", tr: "Tekrar dene", en: "Try again"),
            isBusy: catalog.phase == .loading
        ) {
            Task { await catalog.refresh(ownerId: ownerId) }
        }
    }

    /// Skeleton, error card or the shelf's cards (with `empty` when the shelf has none).
    @ViewBuilder
    private func loadedGrid<Empty: View>(_ templates: [ChoreTemplate], showsCategory: Bool, @ViewBuilder empty: () -> Empty) -> some View {
        if let failure = loadFailure {
            loadFailureCard(failure)
        } else if isFirstLoad {
            skeletonGrid
        } else if templates.isEmpty {
            empty()
        } else {
            templateGrid(templates, showsCategory: showsCategory)
        }
    }

    // MARK: Drafts

    /// The user's saved chores; empty until they save one.
    private var draftsShelf: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            loadedGrid(draftTemplates, showsCategory: true) { draftsEmptyCard }

            customChoreCard
                .padding(.top, AppDesign.Spacing.xs)
        }
    }

    private var draftsEmptyCard: some View {
        VStack(spacing: AppDesign.Spacing.sm) {
            Image(systemName: "tray")
                .font(.system(size: 26, weight: .semibold))
                .foregroundStyle(sectionTint)
                .frame(width: 60, height: 60)
                .background(sectionTint.opacity(0.12), in: Circle())
            Text(appViewModel.catalogText("chore_catalog_drafts_empty", tr: "Henüz taslağın yok", en: "No drafts yet"))
                .font(AppDesign.Typography.headline)
                .foregroundStyle(AppDesign.Colors.pageText)
            Text(appViewModel.catalogText(
                "chore_catalog_drafts_empty_detail",
                tr: "Kategorilerden bir işi aç ve “Taslak olarak kaydet”e dokun; burada seni bekler.",
                en: "Open a chore from the categories and tap “Save as draft”; it will wait for you here."
            ))
            .font(AppDesign.Typography.subheadline)
            .foregroundStyle(AppDesign.Colors.pageTextSecondary)
            .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, AppDesign.Spacing.xxl)
        .padding(.horizontal, AppDesign.Spacing.lg)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous)
                .fill(AppDesign.Colors.cardBackground.opacity(0.7))
        )
        .accessibilityElement(children: .combine)
    }

    // MARK: Category

    private func categoryShelf(_ category: ChoreCategory) -> some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            loadedGrid(systemTemplates.filter { $0.categoryId == category.id }, showsCategory: false) {
                CatalogStatusCard(
                    icon: category.icon,
                    tint: category.tint,
                    title: appViewModel.catalogText("chore_catalog_shelf_empty", tr: "Bu rafta henüz hazır iş yok", en: "No ready-made chores here yet"),
                    detail: appViewModel.catalogText(
                        "chore_catalog_shelf_empty_detail",
                        tr: "Aşağıdan kendi işini oluşturabilirsin.",
                        en: "You can create your own chore below."
                    )
                )
            }
            customChoreCard
                .padding(.top, AppDesign.Spacing.xs)
        }
    }

    // MARK: Custom chore

    private var customChoreCard: some View {
        let tint = AppDesign.Colors.pageTextSecondary
        return Button {
            openBlank(prefillTitle: nil)
        } label: {
            HStack(spacing: AppDesign.Spacing.md) {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 44, height: 44)
                    .background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                VStack(alignment: .leading, spacing: 2) {
                    Text(appViewModel.catalogText("chore_catalog_custom_title", tr: "Aradığın burada yok mu?", en: "Can't find it here?"))
                        .font(AppDesign.Typography.headline)
                        .foregroundStyle(AppDesign.Colors.pageText)
                    Text(appViewModel.catalogText("chore_catalog_custom_subtitle", tr: "Kendi işini sıfırdan oluştur.", en: "Create your own chore from scratch."))
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(AppDesign.Colors.pageTextSecondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppDesign.Colors.pageTextTertiary)
            }
            .padding(AppDesign.Spacing.lg)
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.lg, style: .continuous)
                    .strokeBorder(tint.opacity(0.35), style: StrokeStyle(lineWidth: 1.2, dash: [6, 5]))
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(CatalogPressStyle(scale: 0.98))
    }

    // MARK: Search

    @ViewBuilder
    private var searchResults: some View {
        let results = ChoreCatalog.search(trimmedQuery, among: draftTemplates + systemTemplates) { template in
            (appViewModel.catalogTitle(template), appViewModel.catalogDetail(template))
        }
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            if results.isEmpty {
                VStack(spacing: AppDesign.Spacing.md) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 40, weight: .semibold))
                        .foregroundStyle(AppDesign.Colors.pageTextTertiary)
                    Text(appViewModel.catalogText("chore_catalog_search_empty", tr: "Katalogda bulamadık", en: "Not in the catalog"))
                        .font(AppDesign.Typography.headline)
                        .foregroundStyle(AppDesign.Colors.pageText)
                    Text(appViewModel.catalogText(
                        "chore_catalog_search_empty_detail",
                        tr: "Sorun değil, bu işi kendin oluşturabilirsin.",
                        en: "No problem, you can create this chore yourself."
                    ))
                    .font(AppDesign.Typography.subheadline)
                    .foregroundStyle(AppDesign.Colors.pageTextSecondary)
                    .multilineTextAlignment(.center)

                    Button {
                        openBlank(prefillTitle: trimmedQuery)
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                            Text(
                                appViewModel.catalogText("chore_catalog_search_create", tr: "“{query}” işini oluştur", en: "Create “{query}”")
                                    .replacingOccurrences(of: "{query}", with: trimmedQuery)
                            )
                            .font(AppDesign.Typography.headline)
                            .lineLimit(1)
                        }
                        .foregroundStyle(AppDesign.Colors.onAccent)
                        .padding(.horizontal, AppDesign.Spacing.xl)
                        .frame(height: AppDesign.Size.buttonHeightSmall)
                        .background(
                            LinearGradient(colors: theme.decor.fabColors, startPoint: .leading, endPoint: .trailing),
                            in: Capsule()
                        )
                    }
                    .buttonStyle(CatalogPressStyle(scale: 0.97))
                    .padding(.top, AppDesign.Spacing.sm)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppDesign.Spacing.huge)
            } else {
                CatalogSectionHeader(
                    title: appViewModel.catalogText("chore_catalog_search_results", tr: "{count} sonuç", en: "{count} results")
                        .replacingOccurrences(of: "{count}", with: "\(results.count)"),
                    tint: sectionTint
                )
                templateGrid(results, showsCategory: true)
                customChoreCard
                    .padding(.top, AppDesign.Spacing.xs)
            }
        }
    }

    // MARK: - Confirmation banner

    private func noticeTitle(_ notice: ChoreCatalogNotice) -> String {
        let template: String
        switch notice.kind {
        case .created:
            template = appViewModel.catalogText("chore_catalog_created_title", tr: "“{title}” eklendi", en: "“{title}” added")
        case .draftSaved:
            template = appViewModel.catalogText("chore_catalog_draft_saved_title", tr: "“{title}” taslak olarak kaydedildi", en: "“{title}” saved as a draft")
        case .draftUpdated:
            template = appViewModel.catalogText("chore_catalog_draft_updated_title", tr: "“{title}” taslağı güncellendi", en: "“{title}” draft updated")
        case .deleteFailed:
            template = appViewModel.catalogText("chore_catalog_draft_delete_failed_title", tr: "“{title}” silinemedi", en: "Couldn't delete “{title}”")
        }
        return template.replacingOccurrences(of: "{title}", with: notice.title)
    }

    private func noticeSubtitle(_ notice: ChoreCatalogNotice) -> String {
        switch notice.kind {
        case let .created(memberName, repeatDays):
            return "\(memberName) · \(appViewModel.catalogRepeatLabel(repeatDays))"
        case .draftSaved, .draftUpdated:
            return appViewModel.catalogText("chore_catalog_draft_saved_detail", tr: "Taslaklar sekmesinde seni bekliyor", en: "Waiting for you in Drafts")
        case .deleteFailed(let message):
            return message ?? appViewModel.catalogText(
                "chore_catalog_request_failed_detail",
                tr: "Bağlantını kontrol edip tekrar dene.",
                en: "Check your connection and try again."
            )
        }
    }

    private func noticeBanner(_ notice: ChoreCatalogNotice) -> some View {
        let isDraft = notice.kind == .draftSaved || notice.kind == .draftUpdated
        let isFailure: Bool = if case .deleteFailed = notice.kind { true } else { false }
        let accent = isFailure ? AppDesign.Colors.error : AppDesign.Colors.success
        return HStack(spacing: AppDesign.Spacing.md) {
            Image(systemName: isFailure ? "exclamationmark" : isDraft ? "tray.and.arrow.down.fill" : "checkmark")
                .font(.system(size: 15, weight: .heavy))
                .foregroundStyle(.white)
                .frame(width: 36, height: 36)
                .background(accent, in: Circle())
                .symbolEffect(.bounce, value: notice.id)

            VStack(alignment: .leading, spacing: 1) {
                Text(noticeTitle(notice))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(AppDesign.Colors.textPrimary)
                    .lineLimit(1)
                Text(noticeSubtitle(notice))
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(AppDesign.Colors.textSecondary)
                    .lineLimit(isFailure ? 2 : 1)
            }

            Spacer(minLength: AppDesign.Spacing.xs)

            Button(action: isFailure ? { self.notice = nil } : close) {
                Text(isFailure
                     ? appViewModel.catalogText("chore_catalog_notice_ok", tr: "Tamam", en: "OK")
                     : appViewModel.catalogText("chore_catalog_created_done", tr: "Bitti", en: "Done"))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(AppDesign.Colors.onAccent)
                    .padding(.horizontal, 14)
                    .frame(height: 34)
                    .background(
                        LinearGradient(colors: theme.decor.fabColors, startPoint: .leading, endPoint: .trailing),
                        in: Capsule()
                    )
            }
            .buttonStyle(CatalogPressStyle())
        }
        .padding(.leading, AppDesign.Spacing.md)
        .padding(.trailing, AppDesign.Spacing.sm)
        .padding(.vertical, AppDesign.Spacing.sm)
        .background(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous)
                .fill(AppDesign.Colors.elevatedSurface)
                .shadow(color: AppDesign.Colors.shadow.opacity(0.22), radius: 18, x: 0, y: 8)
        )
        .overlay(
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl, style: .continuous)
                .strokeBorder(accent.opacity(0.35), lineWidth: 1)
        )
        .accessibilityElement(children: .contain)
    }

    // MARK: - Editor page

    private func editorPage(_ route: EditorRoute) -> some View {
        let template = route.template
        let category = ChoreCatalog.category(id: template.categoryId) ?? ChoreCatalog.categories[0]
        return ChoreTemplateEditorView(
            template: template,
            templateCategory: category,
            prefillTitle: route.prefillTitle,
            onBack: closeEditor,
            onClose: close,
            onCreated: handleCreated,
            onSaveDraft: handleDraftSaved
        )
        .background(MainScreenBackground(surface: .popup))
        .id(route.templateId + (route.prefillTitle ?? ""))
    }

    // MARK: - Actions

    private func open(_ template: ChoreTemplate) {
        isSearchFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            editor = EditorRoute(templateId: template.id, prefillTitle: nil, template: template)
        }
    }

    private func openBlank(prefillTitle: String?) {
        isSearchFocused = false
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            editor = EditorRoute(templateId: ChoreCatalog.blankTemplate.id, prefillTitle: prefillTitle,
                                 template: ChoreCatalog.blankTemplate)
        }
    }

    private func closeEditor() {
        dismissKeyboard()
        withAnimation(.spring(response: 0.42, dampingFraction: 0.88)) {
            editor = nil
        }
    }

    private func handleCreated(_ creation: ChoreCatalogCreation) {
        addedCounts[creation.templateId, default: 0] += 1
        closeEditor()
        show(ChoreCatalogNotice(title: creation.title, kind: .created(memberName: creation.memberName, repeatDays: creation.repeatDays)))
    }

    /// Sends the draft; on success it lands on the Drafts tab, which the catalog shows on the way
    /// back. A failure is returned to the editor, which stays open and shows it.
    private func handleDraftSaved(_ record: ChoreCatalogRecord) async -> ChoreCatalogFailure? {
        let isUpdate = record.id != nil
        if let failure = await catalog.save(record) { return failure }
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        query = ""
        selection = Self.draftsId
        closeEditor()
        show(ChoreCatalogNotice(title: ChoreCatalogRules.normalized(record.title), kind: isUpdate ? .draftUpdated : .draftSaved))
        return nil
    }

    /// The card leaves at once; if the server refuses, it comes back with the reason.
    private func delete(_ template: ChoreTemplate) {
        guard let record = template.record else { return }
        Task { @MainActor in
            let failure = await catalog.delete(record)
            guard let failure, !failure.refreshesList else { return }
            UINotificationFeedbackGenerator().notificationOccurred(.error)
            show(ChoreCatalogNotice(title: template.title, kind: .deleteFailed(message: failure.message)))
        }
    }

    private func show(_ newNotice: ChoreCatalogNotice) {
        notice = newNotice
        bannerTask?.cancel()
        bannerTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(5))
            guard !Task.isCancelled else { return }
            notice = nil
        }
    }

    private func close() {
        guard !isClosing else { return }
        isClosing = true
        dismissKeyboard()
        withAnimation(.easeIn(duration: 0.2)) {
            appeared = false
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(210))
            onDismiss()
        }
    }

    private func dismissKeyboard() {
        isSearchFocused = false
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}
