import SwiftUI
import UIKit

// MARK: - Screen corner radius helper

private extension UIScreen {
    /// Cihazın gerçek ekran köşe yarıçapı (tüm modellerde çalışır, yoksa 0)
    var displayCornerRadius: CGFloat {
        (value(forKey: "_displayCornerRadius") as? CGFloat) ?? 0
    }
}

// MARK: - Tab Definition

enum AppTab: Int, CaseIterable {
    case profile = 0
    case home    = 1
    case discover = 2

    var icon: String {
        switch self {
        case .profile:  return "person.fill"
        case .home:     return "house.fill"
        case .discover: return "sparkles"
        }
    }

    var label: String {
        switch self {
        case .profile:  return "Profile"
        case .home:     return "Home"
        case .discover: return "Discover"
        }
    }
}

// MARK: - Main Tab Container

struct MainTabView: View {
    @EnvironmentObject private var appViewModel: AppViewModel
    @State private var selectedTab: AppTab = .home

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .bottom) {
                // Page content — no SwiftUI TabView so we control the bar fully
                tabContent
                    .ignoresSafeArea(.keyboard)

                // Floating tab bar — hidden when any overlay/popup is active
                if !appViewModel.isOverlayPresented {
                    CustomTabBar(
                        selectedTab: $selectedTab,
                        bottomInset: geo.safeAreaInsets.bottom
                    )
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .ignoresSafeArea(.keyboard)
        .animation(AppDesign.Animation.standard, value: appViewModel.isOverlayPresented)
    }

    @ViewBuilder
    private var tabContent: some View {
        switch selectedTab {
        case .profile:
            ProfileView()
        case .home:
            HouseDashboardView()
        case .discover:
            ComingSoonView()
        }
    }
}

// MARK: - Custom Tab Bar

struct CustomTabBar: View {
    @Binding var selectedTab: AppTab
    var bottomInset: CGFloat = 0
    @Namespace private var selectionAnimation

    // Warm deep orange — the bar's accent colour
    static let tabAccent = Color(red: 0.83, green: 0.31, blue: 0.00)
    // Left blob: warm rose / soft magenta
    private let leftBlob  = Color(hue: 0.93, saturation: 0.62, brightness: 0.96)
    // Right blob: seafoam / teal-green (the tone the user liked)
    private let rightBlob = Color(hue: 0.46, saturation: 0.58, brightness: 0.78)

    var body: some View {
        HStack(spacing: 0) {
            ForEach(AppTab.allCases, id: \.rawValue) { tab in
                TabBarItem(
                    tab: tab,
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

    // Margin between bar edge and screen edge (same on all sides)
    private let edgeMargin: CGFloat = 12

    // Runtime screen corner minus margin → concentric, perfect alignment on any device
    private var barCornerRadius: CGFloat {
        let screenRadius = UIScreen.main.displayCornerRadius
        return max(0, screenRadius - edgeMargin)
    }

    private var barShape: RoundedRectangle {
        RoundedRectangle(cornerRadius: barCornerRadius, style: .continuous)
    }

    private var tabBarBackground: some View {
        ZStack {
            // Base: semi-opaque orange-tinted frosted glass
            barShape
                .fill(Self.tabAccent.opacity(0.72))

            // Frosted glass on top for depth and legibility
            barShape
                .fill(.ultraThinMaterial.opacity(0.55))

            // Left blob (rose / magenta)
            GeometryReader { geo in
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [leftBlob.opacity(0.38), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 52
                        )
                    )
                    .frame(width: 88, height: 52)
                    .offset(x: 6, y: (geo.size.height - 52) / 2)
                    .blur(radius: 4)
            }

            // Right blob (teal-green)
            GeometryReader { geo in
                Ellipse()
                    .fill(
                        RadialGradient(
                            colors: [rightBlob.opacity(0.38), .clear],
                            center: .center,
                            startRadius: 0,
                            endRadius: 52
                        )
                    )
                    .frame(width: 88, height: 52)
                    .offset(x: geo.size.width - 94, y: (geo.size.height - 52) / 2)
                    .blur(radius: 4)
            }

            // Border — white sheen on top only (bottom is flush with screen)
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
        .shadow(color: Self.tabAccent.opacity(0.5), radius: 20, x: 0, y: 8)
    }
}

// MARK: - Tab Bar Item

struct TabBarItem: View {
    let tab: AppTab
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
                            .fill(Color.white.opacity(0.22))
                            .frame(width: 52, height: 32)
                            .matchedGeometryEffect(id: "tabHighlight", in: namespace)
                    }

                    Image(systemName: tab.icon)
                        .font(.system(size: 18, weight: isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? Color.white : Color.white.opacity(0.55))
                        .scaleEffect(bouncing ? 1.25 : 1.0)
                        .frame(width: 52, height: 32)
                }

                Text(tab.label)
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
