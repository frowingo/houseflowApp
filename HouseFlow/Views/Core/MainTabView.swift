import SwiftUI

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

    var body: some View {
        GeometryReader { geo in
            // Page content — no SwiftUI TabView so we control the bar fully
            tabContent
                .ignoresSafeArea(.keyboard)
                .overlay(alignment: .bottom) {
                    tabBarOverlay(bottomInset: geo.safeAreaInsets.bottom)
                }
        }
        .ignoresSafeArea(edges: .bottom)
        .ignoresSafeArea(.keyboard)
    }

    @ViewBuilder
    private func tabBarOverlay(bottomInset: CGFloat) -> some View {
        ZStack {
            // Floating tab bar — hidden when any overlay/popup is active
            if !appViewModel.isOverlayPresented {
                CustomTabBar(
                    selectedTab: $selectedTab,
                    bottomInset: bottomInset,
                    labels: tabLabels
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
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    var bottomInset: CGFloat = 0
    let labels: [AppTab: String]
    @Namespace private var selectionAnimation

    private let softApricot = Color(red: 0.96, green: 0.62, blue: 0.35)
    private let softOrange = Color(red: 0.93, green: 0.49, blue: 0.25)
    private let softBerry = Color(red: 0.46, green: 0.19, blue: 0.30)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                TabBarItem(
                    tab: tab,
                    label: labels[tab] ?? tab.fallbackLabel,
                    isSelected: selectedTab == tab,
                    namespace: selectionAnimation
                ) {
                    withAnimation(AppDesign.Animation.spring) {
                        selectedTab = tab
                    }
                }
            }
        }
        .padding(.horizontal, AppDesign.Spacing.lg)
        .padding(.vertical, AppDesign.Spacing.sm)
        .background(tabBarBackground)
        .padding(.horizontal, 24)
        .padding(.bottom, bottomInset + 20)
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
