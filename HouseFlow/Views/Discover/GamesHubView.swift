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
        GameInfo(id: 6, titleKey: "games_house_tanks_title",
                 descriptionKey: "games_house_tanks_card_description",
                 icon: "scope", color: .orange, badgeKey: "games_house_tanks_badge"),
        GameInfo(id: 5, titleKey: "games_house_switch_title",
                 descriptionKey: "games_house_switch_card_description",
                 icon: "arrow.up.arrow.down.circle.fill", color: .teal, badgeKey: "games_house_switch_badge"),
        GameInfo(id: 3, titleKey: "games_skyline_dash_title",
                 descriptionKey: "games_skyline_dash_card_description",
                 icon: "paperplane.fill", color: .cyan, badgeKey: "games_skyline_dash_badge"),
        GameInfo(id: 4, titleKey: "games_rps_title",
                 descriptionKey: "games_rps_card_description",
                 icon: "hand.draw.fill", color: .mint, badgeKey: "games_rps_badge"),
        GameInfo(id: 2, titleKey: "games_vault_rush_title",
                 descriptionKey: "games_vault_rush_card_description",
                 icon: "building.columns.fill", color: Color(hex: "0F172A"), badgeKey: "games_vault_rush_badge"),
        GameInfo(id: 0, titleKey: "games_lucky_spin_title",
                 descriptionKey: "games_lucky_spin_card_description",
                 icon: "arrow.2.circlepath", color: .orange, badgeKey: "games_lucky_spin_badge"),
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
            ForEach(Array(games.enumerated()), id: \.element.id) { index, game in
                NavigationLink(destination: destinationView(for: game.id)) {
                    HubGameCard(game: game)
                }
                .buttonStyle(ScaleButtonStyle())
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 24)
                .animation(
                    .spring(response: 0.6, dampingFraction: 0.75).delay(0.1 + Double(index) * 0.08),
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
        case 4: RockPaperScissorsView()
        case 5: HouseSwitchView()
        case 6: HouseTanksView()
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

                HubGameCoverBackdrop(gameID: game.id)

                VStack(spacing: AppDesign.Spacing.sm) {
                    coverSymbol

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

    @ViewBuilder
    private var coverSymbol: some View {
        if game.id == 4 {
            HStack(spacing: 6) {
                CoverToken(symbol: "circle.fill", rotation: -10)
                CoverToken(symbol: "hand.raised.fill", rotation: 4)
                CoverToken(symbol: "scissors", rotation: -5)
            }
            .accessibilityHidden(true)
        } else {
            Image(systemName: game.icon)
                .font(.system(size: 40, weight: .medium))
                .foregroundStyle(Color.white)
                .accessibilityHidden(true)
        }
    }

    private var bannerColors: [Color] {
        if game.id == 4 {
            return [Color(hex: "113B46"), Color(hex: "12243D"), Color(hex: "29204A")]
        }
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
        if game.id == 5 {
            return [
                Color(hex: "071827"),
                Color(hex: "0E5B63"),
                Color(hex: "F28A3A"),
            ]
        }
        if game.id == 6 {
            return [
                Color(hex: "14252C"),
                Color(hex: "1FBEA7"),
                Color(hex: "F26F2D"),
            ]
        }
        if game.id == 0 {
            return [
                Color(hex: "7C2D12"),
                Color(hex: "EA580C"),
                Color(hex: "F4BF4F"),
            ]
        }

        return [
            game.color.opacity(0.85),
            game.color.opacity(0.55),
        ]
    }
}

private struct HubGameCoverBackdrop: View {
    let gameID: Int

    var body: some View {
        ZStack {
            switch gameID {
            case 0:
                luckySpinArtwork
            case 2:
                vaultArtwork
            case 3:
                skylineArtwork
            case 4:
                rpsArtwork
            case 5:
                houseSwitchArtwork
            case 6:
                houseTanksArtwork
            default:
                EmptyView()
            }
        }
        .accessibilityHidden(true)
        .allowsHitTesting(false)
    }

    private var luckySpinArtwork: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 98, height: 98)
                .offset(x: 54, y: -10)

            Circle()
                .stroke(Color.white.opacity(0.26), lineWidth: 3)
                .frame(width: 76, height: 76)
                .offset(x: 54, y: -10)

            ForEach(0..<8, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(index.isMultiple(of: 2) ? 0.30 : 0.16))
                    .frame(width: 3, height: 13)
                    .offset(y: -31)
                    .rotationEffect(.degrees(Double(index) * 45))
                    .offset(x: 54, y: -10)
            }

            Image(systemName: "arrowtriangle.down.fill")
                .font(.system(size: 17, weight: .black))
                .foregroundStyle(Color.white.opacity(0.72))
                .offset(x: 54, y: -57)

            Image(systemName: "sparkles")
                .font(.system(size: 34, weight: .bold))
                .foregroundStyle(Color.white.opacity(0.13))
                .offset(x: -62, y: 32)
        }
    }

    private var vaultArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.07))
                .frame(width: 122, height: 82)
                .rotationEffect(.degrees(7))
                .offset(x: 52, y: 24)

            Circle()
                .stroke(Color.teal.opacity(0.36), lineWidth: 7)
                .frame(width: 74, height: 74)
                .offset(x: -54, y: -8)

            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(Color.white.opacity(0.24))
                    .frame(width: 4, height: 29)
                    .offset(y: -18)
                    .rotationEffect(.degrees(Double(index) * 60))
                    .offset(x: -54, y: -8)
            }

            Image(systemName: "dollarsign.circle.fill")
                .font(.system(size: 42, weight: .black))
                .foregroundStyle(Color.white.opacity(0.10))
                .offset(x: 62, y: -35)
        }
    }

    private var skylineArtwork: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.14))
                .frame(width: 78, height: 78)
                .offset(x: -64, y: -34)

            HStack(alignment: .bottom, spacing: 5) {
                skylineBuilding(width: 22, height: 36)
                skylineBuilding(width: 28, height: 58)
                skylineBuilding(width: 20, height: 45)
                skylineBuilding(width: 34, height: 78)
                skylineBuilding(width: 24, height: 50)
            }
            .offset(x: 35, y: 38)

            Capsule()
                .fill(Color.white.opacity(0.24))
                .frame(width: 102, height: 5)
                .rotationEffect(.degrees(-17))
                .offset(x: -42, y: 12)
        }
    }

    private var rpsArtwork: some View {
        ZStack {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(Color.white.opacity(index == 1 ? 0.12 : 0.07))
                    .frame(width: index == 1 ? 92 : 72, height: index == 1 ? 92 : 72)
                    .offset(x: CGFloat(index - 1) * 68, y: index == 1 ? -28 : 28)
            }

            Capsule()
                .fill(Color.white.opacity(0.13))
                .frame(width: 132, height: 5)
                .rotationEffect(.degrees(14))
                .offset(x: -44, y: -38)
        }
    }

    private var houseSwitchArtwork: some View {
        ZStack {
            Image(systemName: "house.fill")
                .font(.system(size: 76, weight: .black))
                .foregroundStyle(Color.white.opacity(0.09))
                .offset(x: 52, y: 28)

            VStack(spacing: 34) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 128, height: 8)
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 128, height: 8)
            }
            .rotationEffect(.degrees(-8))
            .offset(x: -48, y: -2)
        }
    }

    private var houseTanksArtwork: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.white.opacity(0.10))
                .frame(width: 116, height: 72)
                .rotationEffect(.degrees(9))
                .offset(x: 54, y: 24)

            HStack(spacing: 26) {
                Capsule()
                    .fill(Color.white.opacity(0.15))
                    .frame(width: 74, height: 12)
                Capsule()
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 54, height: 12)
            }
            .rotationEffect(.degrees(-16))
            .offset(x: -38, y: -28)
        }
    }

    private func skylineBuilding(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: 5, style: .continuous)
            .fill(Color.white.opacity(0.15))
            .frame(width: width, height: height)
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color.white.opacity(0.20))
                    .frame(width: max(6, width * 0.42), height: 4)
                    .padding(.top, 8)
            }
    }
}

private struct CoverToken: View {
    let symbol: String
    let rotation: Double

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(Color.white)
            .frame(width: 34, height: 34)
            .background(Color.white.opacity(0.16))
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .rotationEffect(.degrees(rotation))
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
