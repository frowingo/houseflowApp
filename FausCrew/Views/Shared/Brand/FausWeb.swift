import SwiftUI

// MARK: - Web Geometry

/// An orb web: straight spokes from the hub and rings whose chords sag toward the hub.
/// Shared by the web dot of the Faus Web mark (`FausWebDotShape`).
enum FausWebGeometry {
    static func path(
        center: CGPoint,
        radius: CGFloat,
        spokes: Int = 8,
        rings: Int = 3,
        rotation: Double = -.pi / 2,
        sag: CGFloat = 0.72
    ) -> Path {
        let angles = (0..<spokes).map { rotation + Double($0) * 2 * .pi / Double(spokes) }
        func point(_ angle: Double, _ r: CGFloat) -> CGPoint {
            CGPoint(x: center.x + CGFloat(cos(angle)) * r, y: center.y + CGFloat(sin(angle)) * r)
        }

        var path = Path()
        for angle in angles {
            path.move(to: center)
            path.addLine(to: point(angle, radius))
        }
        for ring in 1...rings {
            let r = radius * CGFloat(ring) / CGFloat(rings)
            path.move(to: point(angles[0], r))
            for index in 0..<spokes {
                let start = angles[index]
                let end = index + 1 < spokes ? angles[index + 1] : angles[0] + 2 * .pi
                path.addQuadCurve(to: point(end, r), control: point((start + end) / 2, r * sag))
            }
            path.closeSubpath()
        }
        return path
    }
}

/// The Faus Web replacement for the mark's round dot, on the mark's 1024 grid: an 8-spoke,
/// 3-ring web turned 22.5° around (652, 578).
struct FausWebDotShape: Shape {
    static let center = CGPoint(x: 652, y: 578)

    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 1024
        let web = FausWebGeometry.path(center: Self.center, radius: 78, rotation: -.pi / 2 + .pi / 8)
        return web.applying(
            CGAffineTransform(translationX: rect.midX - 512 * scale, y: rect.midY - 512 * scale)
                .scaledBy(x: scale, y: scale)
        )
    }
}

// MARK: - Hero Ornament

/// Faus Web's decoration for hero surfaces: a crimson glow from the top-leading corner and a
/// sky glow from the bottom-trailing one, a cream orb web hanging in the top-trailing corner and
/// an angled silk strand across the surface.
struct FausWebOrnament: View {
    enum Surface {
        /// Main-tab top cards.
        case heroCard
        /// Popup title bars.
        case popupHeader
        /// The floating tab bar.
        case tabBar
        /// Full-bleed headers (auth, splash).
        case header
    }

    let surface: Surface
    let ornament: Color

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack(alignment: .topLeading) {
                if surface != .tabBar {
                    glows(size)
                }

                corner(size)

                strand(size)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func glows(_ size: CGSize) -> some View {
        // CSS `circle at corner … 55%` over the diagonal: 55% of the corner-to-corner distance.
        let reach = hypot(size.width, size.height) * 0.55
        return ZStack {
            RadialGradient(
                colors: [Color(fausHex: 0xE23A42, opacity: 0.42), Color(fausHex: 0xE23A42, opacity: 0)],
                center: .topLeading,
                startRadius: 0,
                endRadius: reach
            )
            RadialGradient(
                colors: [Color(fausHex: 0x8FB2FF, opacity: 0.26), Color(fausHex: 0x8FB2FF, opacity: 0)],
                center: .bottomTrailing,
                startRadius: 0,
                endRadius: reach
            )
        }
        .frame(width: size.width, height: size.height)
    }

    private func corner(_ size: CGSize) -> some View {
        let (side, opacity): (CGFloat, Double) = switch surface {
        case .heroCard: (120, 0.18)
        case .popupHeader: (70, 0.2)
        case .tabBar: (80, 0.16)
        case .header: (170, 0.16)
        }
        return Image("WebCorner")
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(ornament)
            .frame(width: side, height: side)
            .opacity(opacity)
            .offset(x: size.width - side)
    }

    /// Strand placements from the Faus Web canvas (390pt wide design), as leading, top,
    /// width, height, rotation and opacity.
    private func strand(_ size: CGSize) -> some View {
        let (x, y, w, h, angle, opacity): (CGFloat, CGFloat, CGFloat, CGFloat, Double, Double) = switch surface {
        case .heroCard: (-30, 68, 420, 63, -5, 0.4)
        case .popupHeader: (-65, -8, 240, 36, -17, 0.55)
        case .tabBar: (size.width - 187, -6, 260, 39, 17, 0.5)
        case .header: (-40, 220, 480, 72, -5, 0.5)
        }
        return Image("WebStrand")
            .resizable()
            .renderingMode(.template)
            .foregroundStyle(ornament)
            .frame(width: w, height: h)
            .rotationEffect(.degrees(angle))
            .opacity(opacity)
            .offset(x: x, y: y)
    }
}

// MARK: - Card Sheen

/// The lighter tone a main card fades from at its top-trailing corner (`FausDecor.cardSheen`);
/// draws nothing in themes with flat cards. Lay it over the card fill, inside its clip.
struct FausCardSheen: View {
    @Environment(\.fausTheme) private var theme

    var body: some View {
        if theme.decor.cardSheen != .clear {
            LinearGradient(
                stops: [
                    .init(color: theme.decor.cardSheen, location: 0),
                    .init(color: theme.decor.cardSheen.opacity(0), location: 0.72)
                ],
                startPoint: .topTrailing,
                endPoint: .bottomLeading
            )
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
    }
}
