import SwiftUI

/// Shared brand treatment for the prominent cards shown at the top of main tabs.
struct BrandHeroCardBackground: View {
    private let brandOrange = Color(red: 1.0, green: 0.48, blue: 0.15)
    private let deepBerry = Color(red: 0.38, green: 0.10, blue: 0.22)

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color(red: 1.0, green: 0.57, blue: 0.22),
                                brandOrange,
                                deepBerry
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                decorativeGeometry
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
        }
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl))
        .overlay {
            RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xl)
                .strokeBorder(
                    LinearGradient(
                        colors: [Color.white.opacity(0.42), Color.white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: deepBerry.opacity(0.28), radius: 18, x: 0, y: 8)
        .allowsHitTesting(false)
    }

    private var decorativeGeometry: some View {
        ZStack {
            Circle()
                .fill(Color.white.opacity(0.08))
                .frame(width: 158, height: 158)
                .offset(x: 145, y: -62)

            Circle()
                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                .frame(width: 118, height: 118)
                .offset(x: 136, y: -54)

            Circle()
                .stroke(Color.white.opacity(0.10), lineWidth: 1)
                .frame(width: 82, height: 82)
                .offset(x: 130, y: -48)

            Capsule()
                .fill(Color.white.opacity(0.08))
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
    private let brandOrange = Color(red: 1.0, green: 0.48, blue: 0.15)
    private let deepBerry = Color(red: 0.38, green: 0.10, blue: 0.22)
    let topCornerRadius: CGFloat

    init(topCornerRadius: CGFloat = AppDesign.CornerRadius.xl) {
        self.topCornerRadius = topCornerRadius
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 1.0, green: 0.57, blue: 0.22),
                        brandOrange,
                        deepBerry
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )

                Circle()
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 112, height: 112)
                    .offset(x: proxy.size.width * 0.34, y: -42)

                Circle()
                    .stroke(Color.white.opacity(0.15), lineWidth: 1)
                    .frame(width: 78, height: 78)
                    .offset(x: proxy.size.width * 0.32, y: -34)

                Capsule()
                    .fill(Color.white.opacity(0.07))
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
                .fill(Color.white.opacity(0.14))
                .frame(height: 0.5)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
