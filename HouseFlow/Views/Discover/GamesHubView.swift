import SwiftUI

// MARK: - Game Info Model
private struct GameInfo: Identifiable {
    let id: Int
    let titleKey: String
    let descriptionKey: String
    let icon: String
    let color: Color
    let badgeKey: String
}

// MARK: - Games Hub View
struct GamesHubView: View {
    @State private var appeared = false

    private let games: [GameInfo] = [
        GameInfo(id: 0, titleKey: "games_lucky_spin_title",
                 descriptionKey: "games_lucky_spin_card_description",
                 icon: "arrow.2.circlepath", color: .orange, badgeKey: "games_lucky_spin_badge"),
        GameInfo(id: 2, titleKey: "games_vault_rush_title",
                 descriptionKey: "games_vault_rush_card_description",
                 icon: "building.columns.fill", color: Color(hex: "0F172A"), badgeKey: "games_vault_rush_badge"),
        GameInfo(id: 3, titleKey: "games_skyline_dash_title",
                 descriptionKey: "games_skyline_dash_card_description",
                 icon: "paperplane.fill", color: .cyan, badgeKey: "games_skyline_dash_badge"),
    ]

    private let columns = [
        GridItem(.flexible(), spacing: AppDesign.Spacing.md),
        GridItem(.flexible(), spacing: AppDesign.Spacing.md),
    ]

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                MainScreenBackground()

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
            BrandHeroCardBackground()

            // Icon
            Image(systemName: "gamecontroller.fill")
                .font(.system(size: 48, weight: .semibold))
                .foregroundStyle(Color.white.opacity(0.16))
                .rotationEffect(.degrees(-8))
                .offset(x: 230, y: -28)

            VStack(alignment: .leading, spacing: AppDesign.Spacing.xs) {
                LocalizedText("games_hub_title")
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                LocalizedText("games_hub_subtitle")
                    .font(AppDesign.Typography.subheadline)
                    .foregroundStyle(Color.white.opacity(0.82))
            }
            .padding(.horizontal, AppDesign.Spacing.xl)
            .padding(.bottom, AppDesign.Spacing.xl)
        }
        .frame(height: 138)
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
        case 2: VaultRushView()
        case 3: SkylineDashView()
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
                    colors: bannerColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .frame(maxWidth: .infinity)
                .frame(height: 120)

                if game.id == 2 {
                    Circle()
                        .fill(Color.teal.opacity(0.18))
                        .frame(width: 92, height: 92)
                        .offset(x: 58, y: -38)

                    Image(systemName: "dollarsign.circle.fill")
                        .font(.system(size: 54, weight: .black))
                        .foregroundStyle(Color.white.opacity(0.08))
                        .offset(x: -54, y: 34)
                } else if game.id == 3 {
                    Circle()
                        .fill(Color.white.opacity(0.16))
                        .frame(width: 86, height: 86)
                        .offset(x: -58, y: -34)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.white.opacity(0.14))
                        .frame(width: 46, height: 118)
                        .offset(x: 62, y: 0)
                }

                VStack(spacing: AppDesign.Spacing.sm) {
                    Image(systemName: game.icon)
                        .font(.system(size: 40, weight: .medium))
                        .foregroundStyle(Color.white)

                    LocalizedText(game.badgeKey)
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
                LocalizedText(game.titleKey)
                    .font(AppDesign.Typography.headline)
                    .foregroundStyle(AppDesign.Colors.textPrimary)

                LocalizedText(game.descriptionKey)
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

    private var bannerColors: [Color] {
        if game.id == 2 {
            return [
                Color(hex: "05070C"),
                Color(hex: "111827"),
                Color(hex: "134E4A"),
            ]
        }

        if game.id == 3 {
            return [
                Color(hex: "0EA5E9"),
                Color(hex: "2563EB"),
                Color(hex: "312E81"),
            ]
        }

        return [
            game.color.opacity(0.85),
            game.color.opacity(0.55),
        ]
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
