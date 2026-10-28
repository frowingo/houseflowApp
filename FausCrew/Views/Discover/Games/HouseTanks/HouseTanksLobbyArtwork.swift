import SwiftUI
import FausCrewCore

/// Faded field-map palette for the House-Tanks entry screens.
/// steel, paper, khaki and slate are the fixed brand colors; the rest are tuned around them.
enum HouseTanksMapPalette {
    static let steel = Color(hex: "0067A5")
    static let paper = Color(hex: "F0F8FF")
    static let khaki = Color(hex: "BA8C63")
    static let slate = Color(hex: "747D83")

    static let ink = Color(hex: "1F2C35")
    static let graphite = Color(hex: "56616A")
    static let deepSteel = Color(hex: "004C7A")
    static let sand = Color(hex: "E6DAC6")
    /// Khaki deep enough for text on paper.
    static let umber = Color(hex: "85603F")
    static let olive = Color(hex: "6F7556")
    static let rust = Color(hex: "A4503B")
    /// Reserved for the aim joker's sight line.
    static let signalRed = Color(hex: "DE1820")
}

enum HouseTanksFieldTheme {
    static let ink = HouseTanksMapPalette.ink
    static let muted = HouseTanksMapPalette.graphite
    static let accent = HouseTanksMapPalette.steel
    static let earth = HouseTanksMapPalette.khaki
    static let danger = HouseTanksMapPalette.rust
    static let surface = HouseTanksMapPalette.paper.opacity(0.94)
    static let hairline = HouseTanksMapPalette.slate.opacity(0.28)
    static let stencil = Font.system(.caption2, design: .monospaced).weight(.semibold)
}

/// Washed-out survey sheet: isometric grid, aged paper and faint coordinates.
/// Detail is weighted toward the edges so the reading column stays clean.
struct HouseTanksMapBackdrop: View {
    var body: some View {
        Canvas(rendersAsynchronously: true) { context, size in
            let rect = CGRect(origin: .zero, size: size)
            let center = CGPoint(x: rect.midX, y: rect.midY)
            let reach = hypot(size.width, size.height) / 2
            let palette = HouseTanksMapPalette.self

            context.fill(Path(rect), with: .color(palette.paper))
            context.fill(Path(rect), with: .radialGradient(
                Gradient(colors: [palette.sand.opacity(0), palette.sand.opacity(0.35), palette.khaki.opacity(0.32)]),
                center: center, startRadius: reach * 0.35, endRadius: reach))

            drawIsometricGrid(in: &context, size: size)
            drawCoordinateLines(in: &context, size: size)

            // Clear the reading column; the ellipse follows the screen's aspect.
            var clearing = context
            clearing.translateBy(x: center.x, y: center.y)
            clearing.scaleBy(x: 1, y: max(1, size.height / max(size.width, 1)) * 0.9)
            let radius = size.width * 0.62
            clearing.fill(Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2)),
                          with: .radialGradient(
                            Gradient(colors: [palette.paper.opacity(0.9), palette.paper.opacity(0.55), palette.paper.opacity(0)]),
                            center: .zero, startRadius: 0, endRadius: radius))

            drawPaperWear(in: &context, size: size)
            drawContours(in: &context, size: size)
            drawFieldMarks(in: &context, size: size)
            drawNeatline(in: &context, size: size)
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func drawIsometricGrid(in context: inout GraphicsContext, size: CGSize) {
        let spacing: CGFloat = 30
        let slope = tan(CGFloat.pi / 6)
        let rise = size.width * slope
        var minor = Path()
        var major = Path()
        var index = 0
        var offset = -rise
        while offset < size.height + rise {
            var line = Path()
            line.move(to: CGPoint(x: 0, y: offset))
            line.addLine(to: CGPoint(x: size.width, y: offset + rise))
            line.move(to: CGPoint(x: 0, y: offset + rise))
            line.addLine(to: CGPoint(x: size.width, y: offset))
            if index.isMultiple(of: 4) { major.addPath(line) } else { minor.addPath(line) }
            offset += spacing / cos(CGFloat.pi / 6)
            index += 1
        }
        context.stroke(minor, with: .color(HouseTanksMapPalette.slate.opacity(0.11)), lineWidth: 0.5)
        context.stroke(major, with: .color(HouseTanksMapPalette.slate.opacity(0.17)), lineWidth: 0.8)
    }

    private func drawCoordinateLines(in context: inout GraphicsContext, size: CGSize) {
        let columns = 6
        let rows = max(6, Int((size.height / size.width * 6).rounded()))
        var path = Path()
        for column in 1..<columns {
            let x = size.width * CGFloat(column) / CGFloat(columns)
            path.move(to: CGPoint(x: x, y: 0))
            path.addLine(to: CGPoint(x: x, y: size.height))
        }
        for row in 1..<rows {
            let y = size.height * CGFloat(row) / CGFloat(rows)
            path.move(to: CGPoint(x: 0, y: y))
            path.addLine(to: CGPoint(x: size.width, y: y))
        }
        context.stroke(path, with: .color(HouseTanksMapPalette.steel.opacity(0.10)),
                       style: StrokeStyle(lineWidth: 0.7, dash: [2, 6]))
    }

    private func drawPaperWear(in context: inout GraphicsContext, size: CGSize) {
        var random = SeededGenerator(seed: 0x7A11)
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let reach = hypot(size.width, size.height) / 2

        // Stains sit in the corners, blurred into the fibers.
        var stains = context
        stains.addFilter(.blur(radius: 26))
        for corner in [CGPoint(x: 0, y: 0), CGPoint(x: size.width, y: size.height * 0.08),
                       CGPoint(x: size.width * 0.04, y: size.height), CGPoint(x: size.width, y: size.height)] {
            let width = size.width * CGFloat(random.next(in: 0.32...0.5))
            let height = width * CGFloat(random.next(in: 0.6...1))
            stains.fill(Path(ellipseIn: CGRect(x: corner.x - width / 2, y: corner.y - height / 2,
                                                width: width, height: height)),
                        with: .color(HouseTanksMapPalette.khaki.opacity(0.16)))
        }

        // Specks and fibers thin out toward the center.
        for _ in 0..<1_100 {
            let point = CGPoint(x: CGFloat(random.next(in: 0...1)) * size.width,
                                y: CGFloat(random.next(in: 0...1)) * size.height)
            let edge = hypot(point.x - center.x, point.y - center.y) / reach
            guard random.next(in: 0...1) < pow(Double(edge), 1.6) else { continue }
            let tone = random.next(in: 0...1) < 0.55 ? HouseTanksMapPalette.slate : HouseTanksMapPalette.khaki
            let opacity = random.next(in: 0.05...0.16)
            if random.next(in: 0...1) < 0.18 {
                let angle = CGFloat(random.next(in: 0...(2 * .pi)))
                let length = CGFloat(random.next(in: 3...9))
                var fiber = Path()
                fiber.move(to: point)
                fiber.addLine(to: CGPoint(x: point.x + cos(angle) * length, y: point.y + sin(angle) * length))
                context.stroke(fiber, with: .color(tone.opacity(opacity)), lineWidth: 0.5)
            } else {
                let diameter = CGFloat(random.next(in: 0.6...1.8))
                context.fill(Path(ellipseIn: CGRect(x: point.x, y: point.y, width: diameter, height: diameter)),
                             with: .color(tone.opacity(opacity)))
            }
        }

        // Two old fold creases: a lit edge beside a soft shadow.
        for crease in [(CGPoint(x: size.width * 0.5, y: 0), CGPoint(x: size.width * 0.52, y: size.height)),
                       (CGPoint(x: 0, y: size.height * 0.36), CGPoint(x: size.width, y: size.height * 0.34))] {
            var line = Path()
            line.move(to: crease.0)
            line.addLine(to: crease.1)
            context.stroke(line, with: .color(HouseTanksMapPalette.slate.opacity(0.07)), lineWidth: 1.4)
            context.stroke(line.offsetBy(dx: 0.8, dy: 0.8), with: .color(Color.white.opacity(0.5)), lineWidth: 0.6)
        }
    }

    private func drawContours(in context: inout GraphicsContext, size: CGSize) {
        let hills: [(CGPoint, CGFloat, Color)] = [
            (CGPoint(x: size.width * 0.96, y: size.height * 0.1), size.width * 0.06, HouseTanksMapPalette.khaki),
            (CGPoint(x: size.width * 0.02, y: size.height * 0.9), size.width * 0.07, HouseTanksMapPalette.olive),
        ]
        for (center, base, tone) in hills {
            for ring in 0..<7 {
                let radius = base + CGFloat(ring) * size.width * 0.035
                var path = Path()
                for step in 0...72 {
                    let angle = CGFloat(step) / 72 * .pi * 2
                    let wave = 1 + 0.12 * sin(3 * angle + CGFloat(ring) * 0.4) + 0.05 * cos(5 * angle)
                    let point = CGPoint(x: center.x + cos(angle) * radius * wave * 1.15,
                                        y: center.y + sin(angle) * radius * wave * 0.8)
                    if step == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()
                context.stroke(path, with: .color(tone.opacity(ring.isMultiple(of: 3) ? 0.26 : 0.16)),
                               lineWidth: ring.isMultiple(of: 3) ? 0.9 : 0.6)
            }
        }
    }

    private func drawFieldMarks(in context: inout GraphicsContext, size: CGSize) {
        let palette = HouseTanksMapPalette.self
        let label = Font.system(size: 8, weight: .semibold, design: .monospaced)

        // Elevation marks along the upper left edge.
        for (x, y, height) in [(0.09, 0.15, "412"), (0.2, 0.22, "388"), (0.07, 0.42, "356")] {
            let point = CGPoint(x: size.width * x, y: size.height * y)
            var triangle = Path()
            triangle.move(to: CGPoint(x: point.x, y: point.y - 4))
            triangle.addLine(to: CGPoint(x: point.x + 4, y: point.y + 3))
            triangle.addLine(to: CGPoint(x: point.x - 4, y: point.y + 3))
            triangle.closeSubpath()
            context.stroke(triangle, with: .color(palette.slate.opacity(0.4)), lineWidth: 0.7)
            context.draw(Text(height).font(label).foregroundColor(palette.slate.opacity(0.5)),
                         at: CGPoint(x: point.x + 14, y: point.y))
        }

        // An advance route on the right edge.
        var route = Path()
        route.move(to: CGPoint(x: size.width * 0.98, y: size.height * 0.62))
        route.addCurve(to: CGPoint(x: size.width * 0.86, y: size.height * 0.4),
                       control1: CGPoint(x: size.width * 0.86, y: size.height * 0.56),
                       control2: CGPoint(x: size.width * 0.95, y: size.height * 0.46))
        context.stroke(route, with: .color(palette.steel.opacity(0.24)),
                       style: StrokeStyle(lineWidth: 1.1, lineCap: .round, dash: [5, 4]))
        let tip = CGPoint(x: size.width * 0.86, y: size.height * 0.4)
        var arrow = Path()
        arrow.move(to: CGPoint(x: tip.x - 5, y: tip.y + 2))
        arrow.addLine(to: tip)
        arrow.addLine(to: CGPoint(x: tip.x + 2, y: tip.y + 6))
        context.stroke(arrow, with: .color(palette.steel.opacity(0.3)), lineWidth: 1.1)

        // Objective markers near the lower edge.
        for (x, y) in [(0.24, 0.84), (0.8, 0.76)] {
            let point = CGPoint(x: size.width * x, y: size.height * y)
            var mark = Path(ellipseIn: CGRect(x: point.x - 7, y: point.y - 7, width: 14, height: 14))
            mark.move(to: CGPoint(x: point.x - 11, y: point.y))
            mark.addLine(to: CGPoint(x: point.x + 11, y: point.y))
            mark.move(to: CGPoint(x: point.x, y: point.y - 11))
            mark.addLine(to: CGPoint(x: point.x, y: point.y + 11))
            context.stroke(mark, with: .color(palette.rust.opacity(0.2)), lineWidth: 0.8)
        }

        // Compass in the lower right corner.
        let compass = CGPoint(x: size.width - 44, y: size.height - 76)
        context.stroke(Path(ellipseIn: CGRect(x: compass.x - 18, y: compass.y - 18, width: 36, height: 36)),
                       with: .color(palette.slate.opacity(0.32)), lineWidth: 0.7)
        var needle = Path()
        needle.move(to: CGPoint(x: compass.x, y: compass.y - 24))
        needle.addLine(to: CGPoint(x: compass.x + 4, y: compass.y))
        needle.addLine(to: CGPoint(x: compass.x, y: compass.y + 24))
        needle.addLine(to: CGPoint(x: compass.x - 4, y: compass.y))
        needle.closeSubpath()
        context.fill(needle, with: .color(palette.khaki.opacity(0.28)))
        context.stroke(needle, with: .color(palette.slate.opacity(0.36)), lineWidth: 0.6)
        context.draw(Text("N").font(label).foregroundColor(palette.slate.opacity(0.55)),
                     at: CGPoint(x: compass.x, y: compass.y - 31))
    }

    private func drawNeatline(in context: inout GraphicsContext, size: CGSize) {
        let palette = HouseTanksMapPalette.self
        let outer = CGRect(origin: .zero, size: size).insetBy(dx: 8, dy: 8)
        let inner = outer.insetBy(dx: 5, dy: 5)
        context.stroke(Path(outer), with: .color(palette.slate.opacity(0.24)), lineWidth: 0.8)
        context.stroke(Path(inner), with: .color(palette.slate.opacity(0.14)), lineWidth: 0.5)

        let label = Font.system(size: 7, weight: .semibold, design: .monospaced)
        let columns = 6
        let rows = max(6, Int((size.height / size.width * 6).rounded()))
        var ticks = Path()
        for column in 0..<columns {
            let x = size.width * (CGFloat(column) + 0.5) / CGFloat(columns)
            let letter = String(UnicodeScalar(UInt8(65 + column)))
            context.draw(Text(letter).font(label).foregroundColor(palette.slate.opacity(0.5)),
                         at: CGPoint(x: x, y: outer.maxY - 10))
            let edge = size.width * CGFloat(column) / CGFloat(columns)
            ticks.move(to: CGPoint(x: edge, y: outer.minY))
            ticks.addLine(to: CGPoint(x: edge, y: inner.minY))
            ticks.move(to: CGPoint(x: edge, y: outer.maxY))
            ticks.addLine(to: CGPoint(x: edge, y: inner.maxY))
        }
        for row in 0..<rows {
            let y = size.height * (CGFloat(row) + 0.5) / CGFloat(rows)
            context.draw(Text(String(format: "%02d", row + 1)).font(label)
                            .foregroundColor(palette.slate.opacity(0.5)),
                         at: CGPoint(x: inner.minX + 9, y: y))
            let edge = size.height * CGFloat(row) / CGFloat(rows)
            ticks.move(to: CGPoint(x: outer.minX, y: edge))
            ticks.addLine(to: CGPoint(x: inner.minX, y: edge))
            ticks.move(to: CGPoint(x: outer.maxX, y: edge))
            ticks.addLine(to: CGPoint(x: inner.maxX, y: edge))
        }
        context.stroke(ticks, with: .color(palette.slate.opacity(0.3)), lineWidth: 0.6)
    }
}

/// The arena tank exactly as HouseTanksScene builds the player's tank: aura, tracks, hull,
/// turret and barrel in the same units, so the color picker shows what will drive on the map.
struct HouseTanksArenaTank: View {
    private let tint: UIColor

    init(color: HouseTanksColor) {
        tint = color.uiColor
    }

    /// A tank in a color outside the player palette, such as the white header emblem.
    init(tint: UIColor) {
        self.tint = tint
    }

    var body: some View {
        Canvas { context, size in
            let ink = HouseTanksMapPalette.ink
            let scale = min(size.width, size.height) / 76
            context.translateBy(x: size.width / 2, y: size.height / 2)
            context.scaleBy(x: scale, y: scale)
            context.rotate(by: .degrees(-30))

            let aura = Path(ellipseIn: CGRect(x: -36, y: -30, width: 72, height: 60))
            context.fill(aura, with: .color(Color(uiColor: tint).opacity(0.18)))
            context.stroke(aura, with: .color(Color(uiColor: tint).opacity(0.72)), lineWidth: 3)

            for y in [CGFloat(-22), 12] {
                let track = Path(roundedRect: CGRect(x: -19, y: y, width: 38, height: 10), cornerRadius: 5)
                context.fill(track, with: .color(ink))
                context.stroke(track, with: .color(HouseTanksMapPalette.paper.opacity(0.25)), lineWidth: 1)
            }

            let hull = Path(roundedRect: CGRect(x: -22, y: -15, width: 44, height: 30), cornerRadius: 9)
            context.fill(hull, with: .color(Color(uiColor: tint)))
            context.stroke(hull, with: .color(ink), lineWidth: 2.5)

            let turret = Path(ellipseIn: CGRect(x: -10, y: -10, width: 20, height: 20))
            context.fill(turret, with: .color(Color(uiColor: tint.tanksShaded(by: -0.10))))
            context.stroke(turret, with: .color(ink), lineWidth: 2)

            let barrel = Path(roundedRect: CGRect(x: 2.5, y: -4, width: 31, height: 8), cornerRadius: 4)
            context.fill(barrel, with: .color(Color(uiColor: tint.tanksShaded(by: -0.16))))
            context.stroke(barrel, with: .color(ink), lineWidth: 1.5)
        }
        .accessibilityHidden(true)
    }
}

/// Small survey sheet of a real arena, drawn from the same map definition as the scene.
struct HouseTanksMapPreview: View {
    /// A tank seated by the server, in normalized arena coordinates (y up).
    struct Seat: Equatable {
        let x: Double
        let y: Double
        let rotation: Double
        let color: HouseTanksColor
    }

    let mapID: HouseTanksMapID
    var isSelected = false
    /// The online room's seated tanks; nil marks the demo's spawn points instead.
    var seats: [Seat]? = nil

    var body: some View {
        Canvas { context, size in
            let palette = HouseTanksMapPalette.self
            let rect = CGRect(origin: .zero, size: size)
            context.fill(Path(rect), with: .color(isSelected ? palette.paper : palette.sand.opacity(0.45)))

            var grid = Path()
            let spacing: CGFloat = 9
            let rise = size.width * tan(CGFloat.pi / 6)
            var offset = -rise
            while offset < size.height + rise {
                grid.move(to: CGPoint(x: 0, y: offset))
                grid.addLine(to: CGPoint(x: size.width, y: offset + rise))
                grid.move(to: CGPoint(x: 0, y: offset + rise))
                grid.addLine(to: CGPoint(x: size.width, y: offset))
                offset += spacing
            }
            context.stroke(grid, with: .color(palette.slate.opacity(0.14)), lineWidth: 0.4)

            let definition = HouseTanksMapCatalog.definition(for: mapID)
            // SpriteKit's arena grows upward; flip it for SwiftUI's coordinates.
            func point(_ normalized: HouseTanksNormalizedPoint) -> CGPoint {
                CGPoint(x: normalized.x * size.width, y: (1 - normalized.y) * size.height)
            }
            var lines = Path()
            for line in definition.floorLines {
                lines.move(to: point(line.start))
                lines.addLine(to: point(line.end))
            }
            context.stroke(lines, with: .color(palette.steel.opacity(0.28)),
                           style: StrokeStyle(lineWidth: 0.8, dash: [3, 3]))

            for obstacle in definition.obstacles {
                let rendered = obstacle.renderedSize(in: HouseTanksSize(width: Double(size.width), height: Double(size.height)),
                                                     mapScale: definition.scale)
                var piece = context
                piece.translateBy(x: obstacle.center.x * size.width, y: (1 - obstacle.center.y) * size.height)
                piece.rotate(by: .radians(-obstacle.rotation))
                let frame = CGRect(x: -rendered.width / 2, y: -rendered.height / 2,
                                   width: rendered.width, height: rendered.height)
                let shape: Path = switch obstacle.style {
                case .roundTable, .pillar, .planter: Path(ellipseIn: frame)
                default: Path(roundedRect: frame, cornerRadius: 1)
                }
                let fill: Color = switch obstacle.style {
                case .crate: palette.khaki.opacity(0.75)
                case .planter: palette.olive.opacity(0.6)
                default: palette.slate.opacity(0.6)
                }
                piece.fill(shape, with: .color(fill))
                piece.stroke(shape, with: .color(palette.ink.opacity(0.35)), lineWidth: 0.5)
            }

            if let seats {
                // Hull and barrel, sized like the arena's tank against the map.
                let length = HouseTanksWorld.tankLength * definition.scale * size.width / HouseTanksWorld.arenaSize.width
                for seat in seats {
                    var tank = context
                    tank.translateBy(x: seat.x * size.width, y: (1 - seat.y) * size.height)
                    tank.rotate(by: .radians(-seat.rotation))
                    let hull = CGRect(x: -length / 2, y: -length * 0.36, width: length, height: length * 0.72)
                    let tint = Color(uiColor: seat.color.uiColor)
                    tank.fill(Path(roundedRect: hull, cornerRadius: length * 0.12), with: .color(tint))
                    tank.stroke(Path(roundedRect: hull, cornerRadius: length * 0.12),
                                with: .color(palette.ink.opacity(0.55)), lineWidth: 0.8)
                    var barrel = Path()
                    barrel.move(to: .zero)
                    barrel.addLine(to: CGPoint(x: length * 0.78, y: 0))
                    tank.stroke(barrel, with: .color(palette.ink.opacity(0.8)), lineWidth: max(1.2, length * 0.14))
                }
            } else {
                // The demo's seats: four on standard maps.
                for spawn in definition.spawnPoints.prefix(definition.demoPlayerCounts.upperBound) {
                    let center = point(spawn)
                    context.fill(Path(ellipseIn: CGRect(x: center.x - 2.5, y: center.y - 2.5, width: 5, height: 5)),
                                 with: .color(palette.steel))
                }
            }
            context.stroke(Path(rect.insetBy(dx: 0.5, dy: 0.5)), with: .color(palette.slate.opacity(0.4)), lineWidth: 1)
        }
        .aspectRatio(872 / 400, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// Registration brackets at the four corners of a field card.
struct HouseTanksCornerMarks: Shape {
    var length: CGFloat = 8

    func path(in rect: CGRect) -> Path {
        var path = Path()
        for (corner, dx, dy) in [(CGPoint(x: rect.minX, y: rect.minY), 1.0, 1.0),
                                 (CGPoint(x: rect.maxX, y: rect.minY), -1.0, 1.0),
                                 (CGPoint(x: rect.minX, y: rect.maxY), 1.0, -1.0),
                                 (CGPoint(x: rect.maxX, y: rect.maxY), -1.0, -1.0)] {
            path.move(to: CGPoint(x: corner.x + length * dx, y: corner.y))
            path.addLine(to: corner)
            path.addLine(to: CGPoint(x: corner.x, y: corner.y + length * dy))
        }
        return path
    }
}

extension View {
    /// Compact paper plate for in-match readouts.
    func hudPanel() -> some View {
        self
            .background(HouseTanksMapPalette.paper.opacity(0.92),
                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.xs, style: .continuous)
                    .stroke(HouseTanksMapPalette.slate.opacity(0.45), lineWidth: 1)
            }
            .shadow(color: HouseTanksMapPalette.ink.opacity(0.12), radius: 0, x: 2, y: 2)
    }

    /// Paper card with a hairline frame and corner brackets, as on a field folder.
    func houseTanksFieldCard(padding: CGFloat = AppDesign.Spacing.lg) -> some View {
        self
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(HouseTanksFieldTheme.surface,
                        in: RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous)
                    .stroke(HouseTanksFieldTheme.hairline, lineWidth: 1)
            }
            .overlay {
                HouseTanksCornerMarks()
                    .stroke(HouseTanksMapPalette.slate.opacity(0.55), lineWidth: 1.2)
                    .padding(4)
            }
    }
}

/// A card lifted off the sheet: a tinted block sits behind it and the card presses into it.
struct HouseTanksRaisedButtonStyle: ButtonStyle {
    var depth: Color
    var offset: CGFloat = 4

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .offset(x: configuration.isPressed ? offset : 0, y: configuration.isPressed ? offset : 0)
            .background {
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous)
                    .fill(depth.opacity(0.55))
                    .offset(x: offset, y: offset)
            }
            .animation(.easeOut(duration: 0.1), value: configuration.isPressed)
    }
}

/// Deterministic noise so the paper looks the same on every launch.
private struct SeededGenerator {
    private var state: UInt64

    init(seed: UInt64) { state = seed }

    mutating func next(in range: ClosedRange<Double>) -> Double {
        state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
        let unit = Double(state >> 11) / Double(1 << 53)
        return range.lowerBound + unit * (range.upperBound - range.lowerBound)
    }
}
