import SwiftUI
import UIKit

// MARK: - Tab Definition

enum AppTab: Int, CaseIterable, Hashable {
    case profile = 0
    case home    = 1
    case games   = 2

    var icon: String {
        switch self {
        case .profile:  return "person.fill"
        case .home:     return "house.fill"
        case .games:    return "gamecontroller.fill"
        }
    }

    var labelKey: String {
        switch self {
        case .profile:  return "tab_profile"
        case .home:     return "tab_home"
        case .games:    return "tab_games"
        }
    }

    var fallbackLabel: String {
        switch self {
        case .profile: return "Profile"
        case .home:    return "Home"
        case .games:   return "Games"
        }
    }
}

// MARK: - Main Tab Container

struct MainTabView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var selectedTab: AppTab = .home
    @State private var isHouseSwitcherPresented = false

    var body: some View {
        GeometryReader { geo in
            // Page content — no SwiftUI TabView so we control the bar fully
            tabContent
                .overlay(alignment: .bottom) {
                    tabBarOverlay(bottomInset: geo.safeAreaInsets.bottom)
                }
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .dismissKeyboardOnTap()
        .onChange(of: appViewModel.isOverlayPresented) { _, isPresented in
            if isPresented {
                isHouseSwitcherPresented = false
            }
        }
    }

    @ViewBuilder
    private func tabBarOverlay(bottomInset: CGFloat) -> some View {
        ZStack {
            // Floating tab bar — hidden when any overlay/popup is active
            if !appViewModel.isOverlayPresented {
                CustomTabBar(
                    selectedTab: $selectedTab,
                    bottomInset: bottomInset,
                    labels: tabLabels,
                    houses: appViewModel.availableHouses,
                    selectedHouseId: appViewModel.currentHouseDetails?.id,
                    isHouseSwitcherPresented: $isHouseSwitcherPresented,
                    houseSwitcherTitle: appViewModel.localized(
                        "house_switcher_title",
                        fallback: "Your homes"
                    ),
                    currentHouseLabel: appViewModel.localized(
                        "house_switcher_current",
                        fallback: "Current home"
                    ),
                    homeLongPressHint: appViewModel.localized(
                        "house_switcher_accessibility_hint",
                        fallback: "Press and hold to switch homes."
                    ),
                    onHouseSelected: selectHouse
                )
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .animation(AppDesign.Animation.standard, value: appViewModel.isOverlayPresented)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .profile:
            ProfileView()
        case .home:
            HouseDashboardView()
        case .games:
            GamesHubView()
        }
    }

    private var tabLabels: [AppTab: String] {
        Dictionary(uniqueKeysWithValues: AppTab.allCases.map { tab in
            (
                tab,
                appViewModel.localized(tab.labelKey, fallback: tab.fallbackLabel)
            )
        })
    }

    private func selectHouse(_ house: AuthHouseSummary) {
        withAnimation(AppDesign.Animation.standard) {
            isHouseSwitcherPresented = false
        }
        guard house.houseId != appViewModel.currentHouseDetails?.id else { return }

        Task {
            await appViewModel.switchHouse(to: house)
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    var bottomInset: CGFloat = 0
    let labels: [AppTab: String]
    let houses: [AuthHouseSummary]
    let selectedHouseId: String?
    @Binding var isHouseSwitcherPresented: Bool
    let houseSwitcherTitle: String
    let currentHouseLabel: String
    let homeLongPressHint: String
    let onHouseSelected: (AuthHouseSummary) -> Void
    @Namespace private var selectionAnimation

    private let softApricot = Color(red: 0.96, green: 0.62, blue: 0.35)
    private let softOrange = Color(red: 0.93, green: 0.49, blue: 0.25)
    private let softBerry = Color(red: 0.46, green: 0.19, blue: 0.30)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                tabItem(for: tab)
                .zIndex(tab == .home ? 1 : 0)
            }
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, AppDesign.Spacing.sm)
        .background(tabBarBackground)
        .padding(.horizontal, 24)
        .padding(.bottom, bottomInset + 20)
    }

    @ViewBuilder
    private func tabItem(for tab: AppTab) -> some View {
        if tab == .home {
            HomeTabBarItem(
                label: labels[tab] ?? tab.fallbackLabel,
                isSelected: selectedTab == tab,
                namespace: selectionAnimation,
                houses: houses,
                selectedHouseId: selectedHouseId,
                isHouseSwitcherPresented: $isHouseSwitcherPresented,
                houseSwitcherTitle: houseSwitcherTitle,
                currentHouseLabel: currentHouseLabel,
                longPressHint: homeLongPressHint,
                onHouseSelected: onHouseSelected
            ) {
                select(tab)
            }
        } else {
            TabBarItem(
                tab: tab,
                label: labels[tab] ?? tab.fallbackLabel,
                isSelected: selectedTab == tab,
                namespace: selectionAnimation
            ) {
                select(tab)
            }
        }
    }

    private func select(_ tab: AppTab) {
        withAnimation(AppDesign.Animation.spring) {
            selectedTab = tab
        }
    }

    // Avoid private screen-corner APIs here; this view is rebuilt when popups close.
    private var barCornerRadius: CGFloat {
        28
    }

    private var barShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
    }

    private var tabBarBackground: some View {
        ZStack {
            barShape
                .fill(
                    LinearGradient(
                        colors: [softApricot, softOrange, softBerry],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            GeometryReader { geo in
                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 104, height: 104)
                    .offset(x: geo.size.width - 76, y: -46)

                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: 76, height: 76)
                    .offset(x: geo.size.width - 62, y: -32)

                Capsule()
                    .fill(Color.white.opacity(0.07))
                    .frame(width: 112, height: 15)
                    .rotationEffect(.degrees(-24))
                    .offset(x: geo.size.width - 94, y: geo.size.height - 20)

                Capsule()
                    .fill(Color.orange.opacity(0.2))
                    .frame(width: 88, height: 12)
                    .rotationEffect(.degrees(-24))
                    .offset(x: -28, y: -3)
            }

            barShape
                .strokeBorder(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.35),
                            Color.white.opacity(0.10)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .clipShape(barShape)
        .shadow(color: softBerry.opacity(0.3), radius: 20, x: 0, y: 9)
    }
}

// MARK: - Tab Bar Item

struct TabBarItem: View {
    let tab: AppTab
    let label: String
    let isSelected: Bool
    var namespace: Namespace.ID
    let onTap: () -> Void

    @State private var bouncing = false

    var body: some View {
        Button(action: {
            triggerBounce()
            onTap()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        Capsule()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 52, height: 32)
                            .overlay {
                                Capsule()
                                    .strokeBorder(Color.white.opacity(0.24), lineWidth: 1)
                            }
                            .shadow(color: Color.black.opacity(0.12), radius: 7, x: 0, y: 3)
                            .matchedGeometryEffect(id: "tabHighlight", in: namespace)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.55))
                        .scaleEffect(bouncing ? 1.25 : 1.0)
                        .frame(width: 52, height: 32)
                }
                Text(label)
                    .font(AppDesign.Typography.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func triggerBounce() {
        guard !bouncing else { return }
        bouncing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            bouncing = false
        }
    }
}

// MARK: - Home Tab Bar Item

private struct HomeTabBarItem: View {
    @EnvironmentObject private var appViewModel: AppViewModel

    let label: String
    let isSelected: Bool
    var namespace: Namespace.ID
    let houses: [AuthHouseSummary]
    let selectedHouseId: String?
    @Binding var isHouseSwitcherPresented: Bool
    let houseSwitcherTitle: String
    let currentHouseLabel: String
    let longPressHint: String
    let onHouseSelected: (AuthHouseSummary) -> Void
    let onTap: () -> Void

    @GestureState private var isPressing = false
    @State private var bouncing = false

    var body: some View {
        Button(action: {
            triggerBounce()
            onTap()
        }) {
            VStack(spacing: 4) {
                ZStack {
                    if isSelected {
                        selectedHomeCapsule
                            .matchedGeometryEffect(id: "tabHighlight", in: namespace)
                    }

                    VStack(spacing: -1) {
                        Image(systemName: "chevron.up")
                            .font(.system(size: 7, weight: .bold))

                        Image(systemName: AppTab.home.icon)
                            .font(.system(size: 19, weight: isSelected ? .semibold : .medium))
                    }
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.62))
                    .scaleEffect(bouncing ? 1.18 : 1.0)
                }
                .frame(width: 52, height: 32)
                .offset(y: isPressing ? -5 : -3)
                .scaleEffect(isPressing ? 1.05 : 1.0)

                Text(label)
                    .font(AppDesign.Typography.caption2)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.55))
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .simultaneousGesture(houseSwitcherGesture)
        .animation(.easeOut(duration: 0.12), value: isPressing)
        .popover(
            isPresented: $isHouseSwitcherPresented,
            attachmentAnchor: .rect(.bounds),
            arrowEdge: .bottom
        ) {
            HouseSwitcherMenu(
                houses: houses,
                selectedHouseId: selectedHouseId,
                title: houseSwitcherTitle,
                currentHouseLabel: currentHouseLabel,
                onSelect: onHouseSelected
            )
            .presentationCompactAdaptation(.popover)
        }
        .accessibilityHint(longPressHint)
        .accessibilityAction(
            named: Text(
                appViewModel.localized(
                    "main_tab_house_switcher_accessibility_action",
                    fallback: "Choose house"
                )
            )
        ) {
            presentHouseSwitcher()
        }
    }

    private var selectedHomeCapsule: some View {
        Capsule()
            .fill(Color(red: 1.0, green: 0.88, blue: 0.70).opacity(0.30))
            .frame(width: 56, height: 38)
            .overlay {
                Capsule()
                    .strokeBorder(Color.white.opacity(0.30), lineWidth: 1)
            }
            .shadow(
                color: Color.black.opacity(isPressing ? 0.20 : 0.12),
                radius: isPressing ? 10 : 7,
                x: 0,
                y: isPressing ? 5 : 3
            )
    }

    private var houseSwitcherGesture: some Gesture {
        LongPressGesture(minimumDuration: 0.28, maximumDistance: 50)
            .updating($isPressing) { pressing, state, _ in
                state = pressing
            }
            .onEnded { _ in
                presentHouseSwitcher()
            }
    }

    private func presentHouseSwitcher() {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
        isHouseSwitcherPresented = true
    }

    private func triggerBounce() {
        guard !bouncing else { return }
        bouncing = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
            bouncing = false
        }
    }
}

// MARK: - House Switcher

private struct HouseSwitcherMenu: View {
    let houses: [AuthHouseSummary]
    let selectedHouseId: String?
    let title: String
    let currentHouseLabel: String
    let onSelect: (AuthHouseSummary) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppDesign.Spacing.md) {
            Text(title)
                .font(AppDesign.Typography.headline)
                .foregroundStyle(AppDesign.Colors.textPrimary)
                .padding(.horizontal, AppDesign.Spacing.xs)

            ScrollView(showsIndicators: false) {
                LazyVStack(spacing: AppDesign.Spacing.xs) {
                    ForEach(houses) { house in
                        HouseSwitcherRow(
                            house: house,
                            isSelected: house.houseId == selectedHouseId,
                            currentHouseLabel: currentHouseLabel
                        ) {
                            onSelect(house)
                        }
                    }
                }
            }
            .frame(height: menuListHeight)
        }
        .padding(AppDesign.Spacing.md)
        .frame(width: 320)
        .presentationBackground(Color(.secondarySystemBackground))
        .accessibilityElement(children: .contain)
    }

    private var menuListHeight: CGFloat {
        min(CGFloat(max(houses.count, 1)) * 62, 260)
    }
}

private struct HouseSwitcherRow: View {
    @Environment(\.colorScheme) private var colorScheme

    let house: AuthHouseSummary
    let isSelected: Bool
    let currentHouseLabel: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: AppDesign.Spacing.md) {
                HouseSwitcherIcon(imagePath: house.houseProfile)

                VStack(alignment: .leading, spacing: 2) {
                    Text(house.houseName)
                        .font(AppDesign.Typography.bodyBold)
                        .foregroundStyle(AppDesign.Colors.textPrimary)
                        .lineLimit(1)

                    if isSelected {
                        Text(currentHouseLabel)
                            .font(AppDesign.Typography.caption)
                            .foregroundStyle(selectedAccentColor)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: AppDesign.Spacing.sm)

                Image(systemName: trailingIcon)
                    .font(.system(size: isSelected ? 19 : 14, weight: .semibold))
                    .foregroundStyle(trailingIconColor)
            }
            .padding(.horizontal, AppDesign.Spacing.sm)
            .padding(.vertical, AppDesign.Spacing.sm)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous)
                        .fill(HouseJourneyTheme.accentOrange.opacity(0.10))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(house.houseName)
        .accessibilityValue(isSelected ? currentHouseLabel : "")
        .accessibilityAddTraits(isSelected ? .isSelected : AccessibilityTraits())
    }

    private var trailingIcon: String {
        isSelected ? "checkmark.circle.fill" : "chevron.right"
    }

    private var trailingIconColor: Color {
        isSelected ? selectedAccentColor : AppDesign.Colors.textTertiary
    }

    private var selectedAccentColor: Color {
        colorScheme == .dark
            ? Color(red: 1.0, green: 0.72, blue: 0.48)
            : HouseJourneyTheme.accentOrangeInk
    }
}

private struct HouseSwitcherIcon: View {
    let imagePath: String

    var body: some View {
        CachedRemoteImage(url: imageURL) { image in
            image
                .resizable()
                .scaledToFill()
        } placeholder: {
            fallbackIcon
        } failure: {
            fallbackIcon
        }
        .frame(width: 42, height: 42)
        .clipShape(Circle())
    }

    private var imageURL: URL? {
        let trimmedPath = imagePath.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedPath.isEmpty ? nil : URL(string: trimmedPath)
    }

    private var fallbackIcon: some View {
        ZStack {
            Circle()
                .fill(HouseJourneyTheme.indigo.opacity(0.12))
            Image(systemName: "house.fill")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(HouseJourneyTheme.indigo)
        }
    }
}
