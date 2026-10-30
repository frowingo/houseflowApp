import SwiftUI

/// Shared brand treatment for the prominent cards shown at the top of main tabs.
struct BrandHeroCardBackground: View {
    @Environment(\.fausTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                    .fill(
                        LinearGradient(
                            stops: theme.decor.heroStops,
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                FausHeroGlow(color: theme.decor.heroGlow)

                decorativeGeometry
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .strokeBorder(
                    LinearGradient(
                        colors: theme.decor.heroBorder,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: theme.decor.heroShadow, radius: 18, x: 0, y: 8)
        .allowsHitTesting(false)
    }

    private var decorativeGeometry: some View {
        ZStack {
            Circle()
                .fill(theme.decor.heroOrnament.opacity(0.08))
                .frame(width: 158, height: 158)
                .offset(x: 145, y: -62)

            Circle()
                .stroke(theme.decor.heroOrnament.opacity(0.16), lineWidth: 1)
                .frame(width: 118, height: 118)
                .offset(x: 136, y: -54)

            Circle()
                .stroke(theme.decor.heroOrnament.opacity(0.10), lineWidth: 1)
                .frame(width: 82, height: 82)
                .offset(x: 130, y: -48)

            Capsule()
                .fill(theme.decor.heroOrnament.opacity(0.08))
                .frame(width: 180, height: 24)
                .rotationEffect(.degrees(-28))
                .offset(x: 130, y: 58)

            Capsule()
                .fill(Color.orange.opacity(0.22))
                .frame(width: 126, height: 18)
                .rotationEffect(.degrees(-28))
                .offset(x: -145, y: -58)
        }
    }
}

/// Compact version of the brand treatment for popup title bars.
/// The popup container owns the corner clipping, so this background stays edge-to-edge.
struct BrandPopupHeaderBackground: View {
    @Environment(\.fausTheme) private var theme
    let topCornerRadius: CGFloat

    init(topCornerRadius: CGFloat = AppDesign.CornerRadius.xl) {
        self.topCornerRadius = topCornerRadius
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    stops: theme.decor.heroStops,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                FausHeroGlow(color: theme.decor.heroGlow, reach: 0.9)

                Circle()
                    .fill(theme.decor.heroOrnament.opacity(0.08))
                    .frame(width: 112, height: 112)
                    .offset(x: proxy.size.width * 0.34, y: -42)

                Circle()
                    .stroke(theme.decor.heroOrnament.opacity(0.15), lineWidth: 1)
                    .frame(width: 78, height: 78)
                    .offset(x: proxy.size.width * 0.32, y: -34)

                Capsule()
                    .fill(theme.decor.heroOrnament.opacity(0.07))
                    .frame(width: 132, height: 16)
                    .rotationEffect(.degrees(-24))
                    .offset(x: proxy.size.width * 0.31, y: 28)

                Capsule()
                    .fill(Color.orange.opacity(0.20))
                    .frame(width: 94, height: 12)
                    .rotationEffect(.degrees(-24))
                    .offset(x: -proxy.size.width * 0.39, y: -24)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(
            UnevenRoundedRectangle(
                topLeadingRadius: topCornerRadius,
                bottomLeadingRadius: 0,
                bottomTrailingRadius: 0,
                topTrailingRadius: topCornerRadius,
                style: .continuous
            )
        )
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(theme.decor.heroOrnament.opacity(theme.colorScheme == .dark ? 0.26 : 0.14))
                .frame(height: 0.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Top-trailing bloom over a hero gradient; draws nothing when the theme's glow is clear.
struct FausHeroGlow: View {
    let color: Color
    /// Radius as a fraction of the larger side.
    var reach: CGFloat = 0.62

    var body: some View {
        GeometryReader { proxy in
            RadialGradient(
                colors: [color, color.opacity(0)],
                center: .topTrailing,
                startRadius: 0,
                endRadius: max(proxy.size.width, proxy.size.height) * reach
            )
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
