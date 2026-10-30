import SwiftUI

/// Shared ambient backdrop for the app's primary screens.
/// It keeps the page visually quiet while giving white space a little depth. The base, the
/// line inks and the optional mesh texture come from the active theme's `FausBackdrop`.
struct MainScreenBackground: View {
    enum Surface {
        case page
        case popup
    }

    var surface: Surface = .page

    @Environment(\.fausTheme) private var theme

    private var backdrop: FausBackdrop {
        surface == .popup ? theme.decor.popupBackdrop : theme.decor.backdrop
    }

    var body: some View {
        ZStack {
            if backdrop.baseStops.count > 1 {
                LinearGradient(stops: backdrop.baseStops, startPoint: backdrop.baseStart, endPoint: backdrop.baseEnd)
            } else {
                backdrop.baseStops.first?.color ?? AppDesign.Colors.background
            }

            if let mesh = backdrop.mesh {
                FausMeshTextureView(texture: mesh)
            }

            LinearGradient(
                colors: backdrop.wash,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            FausHeroGlow(color: backdrop.glow, reach: 0.6)

            if backdrop.drawsLines {
                lineField
            }
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private var softApricot: Color { backdrop.apricotInk }
    private var softOrange: Color { backdrop.orangeInk }
    private var softBerry: Color { backdrop.berryInk }

    /// Static, irregular paths feel random without changing whenever SwiftUI redraws.
    private var lineField: some View {
        ZStack {
            curve(
                from: UnitPoint(x: -0.08, y: 0.17),
                control1: UnitPoint(x: 0.04, y: 0.05),
                control2: UnitPoint(x: 0.15, y: 0.01),
                to: UnitPoint(x: 0.36, y: -0.07),
                color: softApricot,
                opacity: 0.17,
                width: 0.85
            )

            curve(
                from: UnitPoint(x: -0.06, y: 0.30),
                control1: UnitPoint(x: 0.11, y: 0.17),
                control2: UnitPoint(x: 0.30, y: 0.07),
                to: UnitPoint(x: 0.52, y: -0.06),
                color: softBerry,
                opacity: 0.18,
                width: 0.80
            )

            curve(
                from: UnitPoint(x: -0.10, y: 0.08),
                control1: UnitPoint(x: 0.30, y: 0.14),
                control2: UnitPoint(x: 0.74, y: -0.06),
                to: UnitPoint(x: 1.10, y: 0.26),
                color: softOrange,
                opacity: 0.20,
                width: 1.15
            )

            curve(
                from: UnitPoint(x: 1.08, y: 0.02),
                control1: UnitPoint(x: 0.65, y: 0.24),
                control2: UnitPoint(x: 0.70, y: 0.50),
                to: UnitPoint(x: -0.08, y: 0.61),
                color: softBerry,
                opacity: 0.18,
                width: 0.85
            )

            curve(
                from: UnitPoint(x: 0.72, y: -0.07),
                control1: UnitPoint(x: 0.89, y: 0.05),
                control2: UnitPoint(x: 1.02, y: 0.13),
                to: UnitPoint(x: 1.08, y: 0.31),
                color: softBerry,
                opacity: 0.15,
                width: 0.80
            )

            curve(
                from: UnitPoint(x: -0.12, y: 0.33),
                control1: UnitPoint(x: 0.28, y: 0.20),
                control2: UnitPoint(x: 0.58, y: 0.74),
                to: UnitPoint(x: 1.12, y: 0.64),
                color: softApricot,
                opacity: 0.16,
                width: 1.25
            )

            curve(
                from: UnitPoint(x: 0.24, y: -0.06),
                control1: UnitPoint(x: 0.12, y: 0.39),
                control2: UnitPoint(x: 0.42, y: 0.59),
                to: UnitPoint(x: 0.90, y: 1.08),
                color: softOrange,
                opacity: 0.15,
                width: 0.90
            )

            curve(
                from: UnitPoint(x: 1.10, y: 0.39),
                control1: UnitPoint(x: 0.55, y: 0.31),
                control2: UnitPoint(x: 0.23, y: 0.86),
                to: UnitPoint(x: -0.10, y: 0.91),
                color: softBerry,
                opacity: 0.17,
                width: 1.00
            )

            curve(
                from: UnitPoint(x: -0.10, y: 0.72),
                control1: UnitPoint(x: 0.34, y: 0.49),
                control2: UnitPoint(x: 0.78, y: 0.83),
                to: UnitPoint(x: 1.08, y: 1.02),
                color: softApricot,
                opacity: 0.13,
                width: 0.80
            )

            curve(
                from: UnitPoint(x: 0.62, y: 1.08),
                control1: UnitPoint(x: 0.73, y: 0.90),
                control2: UnitPoint(x: 0.94, y: 0.92),
                to: UnitPoint(x: 1.08, y: 0.74),
                color: softOrange,
                opacity: 0.15,
                width: 0.85
            )

            curve(
                from: UnitPoint(x: 0.42, y: 1.06),
                control1: UnitPoint(x: 0.58, y: 0.92),
                control2: UnitPoint(x: 0.83, y: 0.88),
                to: UnitPoint(x: 1.07, y: 0.60),
                color: softBerry,
                opacity: 0.17,
                width: 0.80
            )
        }
    }

    private func curve(
        from start: UnitPoint,
        control1: UnitPoint,
        control2: UnitPoint,
        to end: UnitPoint,
        color: Color,
        opacity: Double,
        width: CGFloat
    ) -> some View {
        let strength = strength(for: color)
        return AmbientCurve(
            start: start,
            control1: control1,
            control2: control2,
            end: end
        )
        .stroke(
            edgeWeightedInk(
                color,
                edgeOpacity: min(opacity * strength, 0.66),
                from: start,
                to: end
            ),
            style: StrokeStyle(lineWidth: width + backdrop.lineWidthBoost, lineCap: .round)
        )
    }

    private func strength(for ink: Color) -> Double {
        if ink == backdrop.apricotInk { return backdrop.apricotStrength }
        if ink == backdrop.orangeInk { return backdrop.orangeStrength }
        return backdrop.berryStrength
    }

    private func edgeWeightedInk(
        _ color: Color,
        edgeOpacity: Double,
        from start: UnitPoint,
        to end: UnitPoint
    ) -> LinearGradient {
        LinearGradient(
            stops: [
                .init(color: color.opacity(edgeOpacity), location: 0),
                .init(color: color.opacity(edgeOpacity * 0.64), location: 0.36),
                .init(color: color.opacity(edgeOpacity * 0.62), location: 0.64),
                .init(color: color.opacity(edgeOpacity), location: 1)
            ],
            startPoint: start,
            endPoint: end
        )
    }
}

private struct AmbientCurve: Shape {
    let start: UnitPoint
    let control1: UnitPoint
    let control2: UnitPoint
    let end: UnitPoint

    func path(in rect: CGRect) -> Path {
        Path { path in
            path.move(to: point(for: start, in: rect))
            path.addCurve(
                to: point(for: end, in: rect),
                control1: point(for: control1, in: rect),
                control2: point(for: control2, in: rect)
            )
        }
    }

    private func point(for unitPoint: UnitPoint, in rect: CGRect) -> CGPoint {
        CGPoint(
            x: rect.minX + rect.width * unitPoint.x,
            y: rect.minY + rect.height * unitPoint.y
        )
    }
}

/// Faus Dark's perforated metal: a hex grid of dark holes with a warm rim, strongest toward the
/// top-trailing light and never fully gone at the bottom, plus two faint sheens.
struct FausMeshTextureView: View {
    let texture: FausMeshTexture
    /// Auth's form sheet uses the texture without the radial fade.
    var masked = true

    var body: some View {
        ZStack {
            Canvas(rendersAsynchronously: true) { context, size in
                var holes = Path()
                var rims = Path()
                let rows = Int(size.height / texture.rowPitch) + 2
                let columns = Int(size.width / texture.pitch) + 2
                for row in 0..<rows {
                    let y = CGFloat(row) * texture.rowPitch + texture.pitch / 2
                    let shift = row.isMultiple(of: 2) ? 0 : texture.pitch / 2
                    for column in 0..<columns {
                        let x = CGFloat(column) * texture.pitch + texture.pitch / 2 + shift
                        holes.addEllipse(in: CGRect(
                            x: x - texture.holeRadius, y: y - texture.holeRadius,
                            width: texture.holeRadius * 2, height: texture.holeRadius * 2
                        ))
                        rims.addEllipse(in: CGRect(
                            x: x - texture.rimRadius, y: y - texture.rimRadius,
                            width: texture.rimRadius * 2, height: texture.rimRadius * 2
                        ))
                    }
                }
                context.stroke(rims, with: .color(texture.rim), lineWidth: 0.5)
                context.fill(holes, with: .color(texture.hole))
            }
            .mask {
                if masked {
                    GeometryReader { proxy in
                        RadialGradient(
                            stops: [
                                .init(color: .black, location: 0),
                                .init(color: .black.opacity(0.88), location: 0.55),
                                .init(color: .black.opacity(0.78), location: 1)
                            ],
                            center: UnitPoint(x: 0.72, y: 0.22),
                            startRadius: 0,
                            endRadius: max(proxy.size.width * 1.1, proxy.size.height * 0.7)
                        )
                    }
                } else {
                    Color.black
                }
            }

            GeometryReader { proxy in
                ZStack {
                    RadialGradient(
                        colors: [texture.sheen.opacity(masked ? 0.06 : 0.05), texture.sheen.opacity(0)],
                        center: UnitPoint(x: 0.74, y: 0.20),
                        startRadius: 0,
                        endRadius: proxy.size.width * 0.5
                    )
                    if masked {
                        RadialGradient(
                            colors: [texture.sheen.opacity(0.035), texture.sheen.opacity(0)],
                            center: UnitPoint(x: 0.30, y: 0.88),
                            startRadius: 0,
                            endRadius: proxy.size.width * 0.63
                        )
                    }
                }
            }
        }
        .drawingGroup()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

#Preview {
    MainScreenBackground()
}
