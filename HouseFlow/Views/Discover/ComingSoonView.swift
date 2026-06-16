import SwiftUI

// MARK: - Game Info Model
private struct GameInfo: Identifiable {
    let id: Int
    let title: String
    let description: String
    let icon: String
    let color: Color
    let badge: String
}

// MARK: - Games Hub View
struct GamesHubView: View {
    @State private var appeared = false

    private let games: [GameInfo] = [
        GameInfo(id: 0, title: "Lucky Spin",
                 description: "Spin the wheel — fate picks who does the chore.",
                 icon: "arrow.2.circlepath", color: .orange, badge: "Group"),
        GameInfo(id: 1, title: "Hot Potato",
                 description: "Pass the bomb! Whoever holds it when it explodes does the chore.",
                 icon: "flame.fill", color: .red, badge: "Group"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: AppDesign.Spacing.md),
        GridItem(.flexible(), spacing: AppDesign.Spacing.md),
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppDesign.Spacing.xl) {
                        headerSection
                        gridSection
                    }
                    .padding(.horizontal, AppDesign.Spacing.lg)
                    .padding(.bottom, 120)
                }
            }
            .navigationBarHidden(true)
        }
        .onAppear {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.05)) {
                appeared = true
            }
        }
    }

    // MARK: - Header
    private var headerSection: some View {
        ZStack(alignment: .bottomLeading) {
            // Orange gradient banner
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(hue: 0.08, saturation: 0.85, brightness: 0.95),
                            Color(hue: 0.05, saturation: 0.75, brightness: 0.80),
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(maxWidth: .infinity)
                .frame(height: 160)

            // Decorative circle
            Circle()
                .fill(Color.white.opacity(0.12))
                .frame(width: 160, height: 160)
                .offset(x: 120, y: -30)

            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 100, height: 100)
                .offset(x: 200, y: 30)

            // Icon
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 44, weight: .medium))
                .foregroundStyle(Color.white.opacity(0.18))
                .offset(x: 230, y: -20)

            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                Text("Mini Games")
                    .font(AppDesign.Typography.title2)
                    .foregroundStyle(.white)
                Text("Settle chore duties by playing a game")
                    .font(AppDesign.Typography.subheadline)
                    .foregroundStyle(Color.white.opacity(0.82))
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
            .padding(.bottom, AppDesign.Spacing.xl)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
        .shadow(color: Color.orange.opacity(0.35), radius: 16, x: 0, y: 6)
        .padding(.top, AppDesign.Spacing.xl)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 12)
    }

    // MARK: - Grid
    private var gridSection: some View {
        LazyVGrid(columns: columns, spacing: AppDesign.Spacing.md) {
            ForEach(games) { game in
                NavigationLink(destination: destinationView(for: game.id)) {
                    HubGameCard(game: game)
                }
                .buttonStyle(ScaleButtonStyle())
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.75).delay(0.1 + Double(game.id) * 0.12),
                    value: appeared
                )
            }
        }
    }

    @ViewBuilder
    private func destinationView(for id: Int) -> some View {
        switch id {
        case 0: LuckySpinView()
        case 1: HotPotatoView()
        default: EmptyView()
        }
    }
}

// MARK: - Hub Game Card (square grid card)
private struct HubGameCard: View {
    let game: GameInfo

    var body: some View {
        VStack(spacing: 0) {
            // Icon area — solid color fill
            ZStack {
                LinearGradient(
                    colors: [
                        game.color.opacity(0.85),
                        game.color.opacity(0.55),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(maxWidth: .infinity)
                .frame(height: 120)

                VStack(spacing: AppDesign.Spacing.sm) {
                    Image(systemName: game.icon)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(Color.white)

                    Text(game.badge)
                        .font(AppDesign.Typography.caption)
                        .foregroundStyle(Color.white.opacity(0.9))
                        .padding(.horizontal, AppDesign.Spacing.sm)
                        .padding(.vertical, 3)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
            }

            // Text area
            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                Text(game.title)
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(AppDesign.Colors.textPrimary)

                Text(game.description)
                    .font(AppDesign.Typography.caption)
                    .foregroundStyle(AppDesign.Colors.textSecondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
            }
            .padding(AppDesign.Spacing.md)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .background(AppDesign.Colors.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
        .shadow(color: Color.black.opacity(0.06), radius: 8, x: 0, y: 2)
        .frame(maxHeight: .infinity, alignment: .top)
    }
}

// MARK: - Scale Button Style (shared across game views)
struct ScaleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Legacy alias (keeps MainTabView reference working)
typealias ComingSoonView = GamesHubView
