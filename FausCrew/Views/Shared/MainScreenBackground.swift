import SwiftUI

/// Shared ambient backdrop for the app's primary screens.
/// It keeps the page visually quiet while giving white space a little depth.
struct MainScreenBackground: View {
    private let softApricot = Color(red: 0.96, green: 0.62, blue: 0.35)
    private let softOrange = Color(red: 0.93, green: 0.49, blue: 0.25)
    private let softBerry = Color(red: 0.46, green: 0.19, blue: 0.30)

    var body: some View {
        ZStack {
            Color(uiColor: .systemBackground)

            LinearGradient(
                colors: [
                    softApricot.opacity(0.035),
                    Color.clear,
                    softBerry.opacity(0.018)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            lineField
        }
        .ignoresSafeArea()
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

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
        AmbientCurve(
            start: start,
            control1: control1,
            control2: control2,
            end: end
        )
        .stroke(
            edgeWeightedInk(
                color,
                edgeOpacity: opacity,
                from: start,
                to: end
            ),
            style: StrokeStyle(lineWidth: width, lineCap: .round)
        )
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

#Preview {
    MainScreenBackground()
}
