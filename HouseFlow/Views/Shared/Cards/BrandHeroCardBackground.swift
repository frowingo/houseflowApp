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
