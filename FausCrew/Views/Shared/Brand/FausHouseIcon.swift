import SwiftUI

/// FausCrew's own house glyph on a 24-unit grid: roof, chimney, rounded walls and an arched door.
/// Android draws the same coordinates (`FausHouseIcon.kt`), so both platforms render it identically.
struct FausHouseShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 24
        let origin = CGPoint(x: rect.midX - 12 * scale, y: rect.midY - 12 * scale)
        func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }

        var path = Path()
        // Roof
        path.move(to: p(2.75, 11.25))
        path.addLine(to: p(12, 3.5))
        path.addLine(to: p(21.25, 11.25))
        // Chimney
        path.move(to: p(16.25, 6.9))
        path.addLine(to: p(16.25, 4.75))
        // Walls
        path.move(to: p(5.25, 9.4))
        path.addLine(to: p(5.25, 18.5))
        path.addQuadCurve(to: p(7.25, 20.5), control: p(5.25, 20.5))
        path.addLine(to: p(16.75, 20.5))
        path.addQuadCurve(to: p(18.75, 18.5), control: p(18.75, 20.5))
        path.addLine(to: p(18.75, 9.4))
        // Door
        path.move(to: p(9.75, 20.5))
        path.addLine(to: p(9.75, 16.25))
        path.addQuadCurve(to: p(12, 14), control: p(9.75, 14))
        path.addQuadCurve(to: p(14.25, 16.25), control: p(14.25, 14))
        path.addLine(to: p(14.25, 20.5))
        return path
    }
}

struct FausHouseIcon: View {
    enum Fill {
        case gradient
        case color(Color)
    }

    var size: CGFloat
    var fill: Fill = .gradient

    var body: some View {
        let style = StrokeStyle(lineWidth: 2.1 * size / 24, lineCap: .round, lineJoin: .round)
        Group {
            switch fill {
            case .gradient:
                FausHouseShape().stroke(FausBrand.houseGradient, style: style)
            case .color(let color):
                FausHouseShape().stroke(color, style: style)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

#Preview {
    HStack(spacing: 16) {
        FausHouseIcon(size: 48)
        FausHouseIcon(size: 24)
        FausHouseIcon(size: 24, fill: .color(.gray))
    }
    .padding()
}
