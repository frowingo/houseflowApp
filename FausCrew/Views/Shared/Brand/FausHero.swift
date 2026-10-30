import SwiftUI

/// Orange → berry hero surface with the `BrandHeroCardBackground` decorative geometry:
/// layered circles top-right and two tilted capsules. Used behind auth-flow headers.
struct FausHeroBackground: View {
    @Environment(\.fausTheme) private var theme

    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                LinearGradient(stops: theme.decor.headerStops, startPoint: .topLeading, endPoint: .bottomTrailing)
                FausHeroGlow(color: theme.decor.heroGlow.opacity(0.85), reach: 0.75)
                RadialGradient(
                    colors: [theme.decor.headerGlow, theme.decor.headerGlow.opacity(0)],
                    center: UnitPoint(x: 0.5, y: 0.48),
                    startRadius: 0,
                    endRadius: width * 0.42
                )

                Circle()
                    .fill(theme.decor.heroOrnament.opacity(0.08))
                    .frame(width: 158, height: 158)
                    .position(x: width - 6, y: 60)
                Circle()
                    .stroke(theme.decor.heroOrnament.opacity(0.16), lineWidth: 1)
                    .frame(width: 118, height: 118)
                    .position(x: width - 15, y: 68)
                Circle()
                    .stroke(theme.decor.heroOrnament.opacity(0.10), lineWidth: 1)
                    .frame(width: 82, height: 82)
                    .position(x: width - 21, y: 74)
                Capsule()
                    .fill(theme.decor.heroOrnament.opacity(0.08))
                    .frame(width: 180, height: 24)
                    .rotationEffect(.degrees(-28))
                    .position(x: width - 20, y: proxy.size.height - 70)
                Capsule()
                    .fill(Color.orange.opacity(0.22))
                    .frame(width: 126, height: 18)
                    .rotationEffect(.degrees(-28))
                    .position(x: 23, y: 92)
            }
        }
        .accessibilityHidden(true)
    }
}

/// The form sheet that rises over `FausHeroBackground`: the theme's sheet gradient, optional
/// mesh texture and a lit top edge. The caller owns the corner clipping.
struct FausSheetBackground: View {
    var cornerRadius: CGFloat = 32

    @Environment(\.fausTheme) private var theme

    var body: some View {
        let shape = UnevenRoundedRectangle(topLeadingRadius: cornerRadius, topTrailingRadius: cornerRadius)
        ZStack {
            if theme.decor.sheetStops.count > 1 {
                GeometryReader { proxy in
                    // Stops are laid out over the first ~660pt so the lit band keeps its height.
                    LinearGradient(stops: theme.decor.sheetStops, startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 660 / max(proxy.size.height, 1)))
                }
            } else {
                theme.decor.sheetStops.first?.color ?? AppDesign.Colors.background
            }
            if let mesh = theme.decor.sheetMesh {
                FausMeshTextureView(texture: mesh, masked: false)
            }
        }
        .clipShape(shape)
        .overlay(shape.stroke(theme.decor.sheetEdge, lineWidth: 1.5).mask(
            LinearGradient(colors: [.black, .clear], startPoint: .top, endPoint: UnitPoint(x: 0.5, y: 0.08))
        ))
        .shadow(color: theme.decor.sheetEdgeGlow, radius: 9, x: 0, y: -1)
        .accessibilityHidden(true)
    }
}

/// White badge with two soft halo rings; `content` is drawn on top (usually brand-gradient filled).
struct FausBadge<Content: View>: View {
    var size: CGFloat
    @ViewBuilder var content: () -> Content

    @Environment(\.fausTheme) private var theme

    var body: some View {
        ZStack {
            Circle()
                .fill(theme.decor.badgeHalo.opacity(0.07))
                .frame(width: size + 32, height: size + 32)
            Circle()
                .fill(theme.decor.badgeHalo.opacity(0.16))
                .frame(width: size + 16, height: size + 16)
            Circle()
                .fill(LinearGradient(colors: theme.decor.badgeFill, startPoint: .topLeading, endPoint: .bottomTrailing))
                .overlay(
                    RadialGradient(
                        colors: [theme.decor.headerGlow, theme.decor.headerGlow.opacity(0)],
                        center: .center,
                        startRadius: 0,
                        endRadius: size * 0.5
                    )
                    .clipShape(Circle())
                )
                .overlay(Circle().strokeBorder(theme.decor.badgeBorder, lineWidth: 1.5))
                .frame(width: size, height: size)
                .shadow(color: FausBrand.deepBerry.opacity(0.35), radius: 12, x: 0, y: 10)
                .shadow(color: theme.decor.framedMarkGlow, radius: 13)
            content()
        }
        .accessibilityHidden(true)
    }
}

extension View {
    /// Fills the view's opaque pixels (an SF Symbol, text) with the diagonal brand gradient.
    func fausGradientForeground() -> some View {
        overlay(FausBrand.iconGradient).mask(self)
    }
}
