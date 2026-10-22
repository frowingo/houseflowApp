import SwiftUI

/// Orange → berry hero surface with the `BrandHeroCardBackground` decorative geometry:
/// layered circles top-right and two tilted capsules. Used behind auth-flow headers.
struct FausHeroBackground: View {
    var body: some View {
        GeometryReader { proxy in
            let width = proxy.size.width
            ZStack(alignment: .topLeading) {
                FausBrand.heroGradient

                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 158, height: 158)
                    .position(x: width - 6, y: 60)
                Circle()
                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                    .frame(width: 118, height: 118)
                    .position(x: width - 15, y: 68)
                Circle()
                    .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    .frame(width: 82, height: 82)
                    .position(x: width - 21, y: 74)
                Capsule()
                    .fill(Color.white.opacity(0.08))
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

/// White badge with two soft halo rings; `content` is drawn on top (usually brand-gradient filled).
struct FausBadge<Content: View>: View {
    var size: CGFloat
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.07))
                .frame(width: size + 32, height: size + 32)
            Circle()
                .fill(Color.white.opacity(0.16))
                .frame(width: size + 16, height: size + 16)
            Circle()
                .fill(Color.white)
                .frame(width: size, height: size)
                .shadow(color: FausBrand.deepBerry.opacity(0.35), radius: 12, x: 0, y: 10)
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
