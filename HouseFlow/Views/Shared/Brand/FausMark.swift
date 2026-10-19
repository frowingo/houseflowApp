import SwiftUI

// MARK: - Faus Brand

/// FausCrew brand palette, matching the app icon and `BrandHeroCardBackground`.
enum FausBrand {
    static let orangeLight = Color(red: 1.0, green: 0.57, blue: 0.22)
    static let orange = Color(red: 1.0, green: 0.48, blue: 0.15)
    static let deepBerry = Color(red: 0.38, green: 0.10, blue: 0.22)
    static let markBerry = Color(red: 0.54, green: 0.14, blue: 0.25)
    static let spinnerRed = Color(red: 1.0, green: 0.37, blue: 0.18)
    static let spinnerBerry = Color(red: 0.64, green: 0.14, blue: 0.29)

    /// Hero surfaces (auth header): the `BrandHeroCardBackground` orange → berry diagonal.
    static var heroGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: orangeLight, location: 0),
                .init(color: orange, location: 0.4),
                .init(color: deepBerry, location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// Icons and small accents filled with the brand diagonal.
    static var iconGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: orangeLight, location: 0),
                .init(color: orange, location: 0.4),
                .init(color: markBerry, location: 1)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    /// `FausHouseIcon` stroke, laid out on the icon's 24-unit grid.
    static var houseGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: orangeLight, location: 0),
                .init(color: orange, location: 0.4),
                .init(color: markBerry, location: 1)
            ],
            startPoint: UnitPoint(x: 3 / 24, y: 3 / 24),
            endPoint: UnitPoint(x: 21 / 24, y: 21 / 24)
        )
    }

    /// Primary call-to-action buttons.
    static var buttonGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: orangeLight, location: 0),
                .init(color: orange, location: 0.35),
                .init(color: markBerry, location: 1)
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }

    /// The roof-F gradient: orange at the roof, berry at the foot of the stem.
    static var markGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: orangeLight, location: 0),
                .init(color: orange, location: 0.35),
                .init(color: markBerry, location: 1)
            ],
            startPoint: UnitPoint(x: 332 / 1024, y: 246 / 1024),
            endPoint: UnitPoint(x: 692 / 1024, y: 778 / 1024)
        )
    }
}

// MARK: - Faus Mark

/// The roof-shaped "F" of the FausCrew icon, drawn on a 1024 grid
/// (source: Design/AppIcon/FausCrew-AppIcon-Light.svg). Order: roof right → apex → stem → arm,
/// so `trim` draws it like a pen stroke.
struct FausMarkShape: Shape {
    func path(in rect: CGRect) -> Path {
        let scale = min(rect.width, rect.height) / 1024
        let origin = CGPoint(x: rect.midX - 512 * scale, y: rect.midY - 512 * scale)
        func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
            CGPoint(x: origin.x + x * scale, y: origin.y + y * scale)
        }

        var path = Path()
        path.move(to: point(692, 398))
        path.addLine(to: point(512, 246))
        path.addLine(to: point(332, 398))
        path.addLine(to: point(332, 778))
        path.move(to: point(332, 578))
        path.addLine(to: point(512, 578))
        return path
    }
}

/// The roof-F glyph plus its "crew" dot, in one solid color.
struct FausMark: View {
    var size: CGFloat
    var color: Color = .white
    var progress: CGFloat = 1
    var dotScale: CGFloat = 1

    var body: some View {
        let unit = size / 1024
        ZStack {
            FausMarkShape()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 76 * unit, lineCap: .round, lineJoin: .round))

            Circle()
                .fill(color)
                .frame(width: 88 * unit, height: 88 * unit)
                .scaleEffect(dotScale)
                .position(x: 622 * unit, y: 578 * unit)
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// The roof-F filled with the brand gradient, framed by a thin orange circle whose
/// inside is cleared to `fill` so the page's ambient lines stop at its edge.
struct FausFramedMark: View {
    var size: CGFloat
    var fill: Color = Color(uiColor: .systemBackground)
    var progress: CGFloat = 1
    var dotScale: CGFloat = 1

    var body: some View {
        let unit = size / 1024
        ZStack {
            Circle()
                .fill(fill)
                .frame(width: 940 * unit, height: 940 * unit)
                .overlay(
                    Circle().stroke(FausBrand.orange.opacity(0.55), lineWidth: max(1, 7 * unit))
                )

            Rectangle()
                .fill(FausBrand.markGradient)
                .frame(width: size, height: size)
                .mask(FausMark(size: size, progress: progress, dotScale: dotScale))
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

// MARK: - Faus Spinner

/// Loading indicator: rounded arc pieces orbit clockwise, bunching into one long arc on the
/// right and splitting apart on the left, with a springy settle when they join and a small
/// pull-back before they leave. The gradient stays fixed while the pieces move through it.
struct FausSpinner: View {
    var size: CGFloat = 46

    @Environment(\.fausSplashActive) private var splashActive

    private let pieceCount = 7
    private let period: Double = 2.6
    private let bunching: Double = 0.82
    // Geometry on a 48pt grid, scaled to `size`.
    private let radius: CGFloat = 17
    private let lineWidth: CGFloat = 4.6
    private let pieceLength: CGFloat = 12.5

    var body: some View {
        TimelineView(.animation(minimumInterval: nil, paused: splashActive)) { timeline in
            Canvas { context, canvasSize in
                let unit = min(canvasSize.width, canvasSize.height) / 48
                let center = CGPoint(x: canvasSize.width / 2, y: canvasSize.height / 2)
                let halfSweep = Double(pieceLength / 2 / radius)
                let cycle = timeline.date.timeIntervalSinceReferenceDate / period
                let shading = GraphicsContext.Shading.linearGradient(
                    Gradient(stops: [
                        .init(color: FausBrand.orangeLight, location: 0),
                        .init(color: FausBrand.spinnerRed, location: 0.5),
                        .init(color: FausBrand.spinnerBerry, location: 1)
                    ]),
                    startPoint: CGPoint(x: 7 * unit, y: 7 * unit),
                    endPoint: CGPoint(x: 41 * unit, y: 41 * unit)
                )
                let style = StrokeStyle(lineWidth: lineWidth * unit, lineCap: .round)

                for index in 0..<pieceCount {
                    let phase = (cycle + Double(index) / Double(pieceCount)).truncatingRemainder(dividingBy: 1)
                    let turn = position(phase) + cycle * 0.12
                    let angle = turn * 2 * .pi

                    var path = Path()
                    path.addArc(
                        center: center,
                        radius: radius * unit,
                        startAngle: .radians(angle - halfSweep),
                        endAngle: .radians(angle + halfSweep),
                        clockwise: false
                    )
                    context.stroke(path, with: shading, style: style)
                }
            }
        }
        .frame(width: size, height: size)
        .shadow(color: FausBrand.spinnerRed.opacity(0.35), radius: size * 0.055, x: 0, y: size * 0.065)
        .accessibilityHidden(true)
    }

    /// Where a piece sits (in turns) at `phase` through its cycle: slow on the right, fast on
    /// the left, plus a damped overshoot on arrival and a pull-back before departure.
    private func position(_ phase: Double) -> Double {
        var turn = phase - (bunching / (2 * .pi)) * sin(2 * .pi * phase)

        let sinceArrival = (phase - 0.8 + 1).truncatingRemainder(dividingBy: 1)
        if sinceArrival < 0.45 {
            turn += 0.05 * exp(-10 * sinceArrival) * sin(30 * sinceArrival)
        }
        if phase > 0.08 && phase < 0.3 {
            let progress = (phase - 0.08) / 0.22
            turn -= 0.035 * sin(.pi * progress) * (1 - progress)
        }
        return turn
    }
}

#Preview {
    VStack(spacing: 32) {
        FausFramedMark(size: 190)
        FausSpinner()
    }
    .padding()
}
