import SwiftUI

// Faus Bloom decoration: the marbled texture, the edge garden of vines and flowers, and the petal
// ornaments of hero surfaces. Coordinates come from the Bloom design canvas, drawn for a
// 390×844 screen; each cluster stays pinned to its own corner so other sizes keep the layout.

// MARK: - Marble

/// The theme's ebru texture, top-aligned and filling the surface.
struct FausMarbleView: View {
    let marble: FausMarble

    var body: some View {
        GeometryReader { proxy in
            Image(marble.imageName)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                .clipped()
        }
        .opacity(marble.opacity)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

// MARK: - Garden

/// Vines with wild roses, daisies, tulips, buds and berries at the edges of a backdrop.
struct FausGardenView: View {
    enum Layout {
        /// Full screens: a vine down from the top-trailing corner, one up from the bottom-leading
        /// corner, a sprig at the bottom-trailing corner and a few drifting petals.
        case page
        /// Popup bodies: two short sprigs on the side edges.
        case popup
        /// The auth form sheet: a flowering corner at each bottom edge.
        case sheet
    }

    let garden: FausGarden
    var layout: Layout = .page

    var body: some View {
        Canvas { context, size in
            var painter = GardenPainter(context: context, garden: garden, size: size)
            switch layout {
            case .page: painter.drawPage()
            case .popup: painter.drawPopup()
            case .sheet: painter.drawSheet()
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

/// Where a design coordinate is measured from, so a cluster keeps its distance to its corner.
private enum Anchor {
    case topLeading, topTrailing, bottomLeading, bottomTrailing
    /// x from the leading or trailing edge, y scaled with the height.
    case leadingScaled, trailingScaled
}

private struct GardenPainter {
    let context: GraphicsContext
    let garden: FausGarden
    let size: CGSize
    /// The design frame of the current layout (390×844 for pages).
    var design = CGSize(width: 390, height: 844)

    init(context: GraphicsContext, garden: FausGarden, size: CGSize) {
        self.context = context
        self.garden = garden
        self.size = size
    }

    func point(_ x: CGFloat, _ y: CGFloat, _ anchor: Anchor) -> CGPoint {
        switch anchor {
        case .topLeading: CGPoint(x: x, y: y)
        case .topTrailing: CGPoint(x: size.width - (design.width - x), y: y)
        case .bottomLeading: CGPoint(x: x, y: size.height - (design.height - y))
        case .bottomTrailing: CGPoint(x: size.width - (design.width - x), y: size.height - (design.height - y))
        case .leadingScaled: CGPoint(x: x, y: y / design.height * size.height)
        case .trailingScaled: CGPoint(x: size.width - (design.width - x), y: y / design.height * size.height)
        }
    }

    // MARK: Layouts

    mutating func drawPage() {
        design = CGSize(width: 390, height: 844)

        // Top-trailing vine.
        stem(.topTrailing, opacity: 0.42, width: 1.6) { p, at in
            p.move(to: at(400, -10))
            p.addCurve(to: at(318, 180), control1: at(350, 60), control2: at(372, 130))
            p.addCurve(to: at(290, 340), control1: at(264, 230), control2: at(262, 280))
        }
        stem(.topTrailing, opacity: 0.36, width: 1.1) { p, at in
            p.move(to: at(352, 92))
            p.addCurve(to: at(382, 140), control1: at(372, 100), control2: at(384, 118))
        }
        leaf(378, 40, .topTrailing, rotation: 150, color: garden.leaf, opacity: 0.40)
        leaf(356, 110, .topTrailing, rotation: 20, color: garden.leafAlt, opacity: 0.38)
        leaf(322, 172, .topTrailing, rotation: 160, color: garden.leaf, opacity: 0.40)
        leaf(290, 250, .topTrailing, rotation: 30, color: garden.leafAlt, opacity: 0.36)
        leaf(300, 318, .topTrailing, rotation: -20, color: garden.leaf, opacity: 0.34)
        berries(368, 58, .topTrailing, color: garden.wine, opacity: 0.55)
        blossom(346, 140, .topTrailing, scale: 1.5, rotation: 12, color: garden.rose, opacity: 0.8)
        blossom(382, 142, .topTrailing, scale: 0.9, color: garden.petal, opacity: 0.9)
        bud(318, 214, .topTrailing, scale: 1.1, color: garden.mauve, opacity: 0.55)
        blossom(372, 250, .topTrailing, rotation: 30, color: garden.sky, opacity: 0.65)
        daisy(292, 340, .topTrailing, scale: 1.35, color: garden.petal, opacity: 0.95)

        // Bottom-leading vine.
        stem(.bottomLeading, opacity: 0.42, width: 1.6) { p, at in
            p.move(to: at(-10, 860))
            p.addCurve(to: at(70, 690), control1: at(40, 790), control2: at(20, 740))
            p.addCurve(to: at(100, 540), control1: at(120, 640), control2: at(120, 600))
        }
        stem(.bottomLeading, opacity: 0.5, width: 1.2) { p, at in
            p.move(to: at(100, 540))
            p.addLine(to: at(100, 556))
        }
        leaf(30, 780, .bottomLeading, rotation: -40, color: garden.leaf, opacity: 0.40)
        leaf(64, 700, .bottomLeading, rotation: 200, color: garden.leafAlt, opacity: 0.38)
        leaf(106, 616, .bottomLeading, rotation: -30, color: garden.leaf, opacity: 0.36)
        leaf(48, 740, .bottomLeading, rotation: 150, color: garden.leaf, opacity: 0.32)
        tulip(100, 548, .bottomLeading, scale: 1.5, rotation: -8, color: garden.rose, opacity: 0.75)
        daisy(80, 652, .bottomLeading, scale: 1.25, color: garden.petal, opacity: 0.95)
        blossom(38, 712, .bottomLeading, scale: 1.3, rotation: 20, color: garden.wine, opacity: 0.5)
        berries(22, 796, .bottomLeading, color: garden.mauve, opacity: 0.6)
        blossom(118, 772, .bottomLeading, scale: 0.95, color: garden.sky, opacity: 0.6)

        // Bottom-trailing sprig.
        stem(.bottomTrailing, opacity: 0.36, width: 1.3) { p, at in
            p.move(to: at(402, 690))
            p.addCurve(to: at(336, 800), control1: at(372, 720), control2: at(360, 760))
        }
        leaf(380, 716, .bottomTrailing, rotation: 200, color: garden.leafAlt, opacity: 0.34)
        leaf(356, 768, .bottomTrailing, rotation: -60, color: garden.leaf, opacity: 0.32)
        bud(372, 704, .bottomTrailing, scale: 0.85, color: garden.rose, opacity: 0.6)
        daisy(336, 800, .bottomTrailing, scale: 1.1, color: garden.petal, opacity: 0.95)

        // Drifting petals.
        petal(36, 44, .topLeading, rotation: -30, color: garden.rose, opacity: 0.45)
        petal(64, 24, .topLeading, scale: 0.8, rotation: 40, color: garden.petal, opacity: 0.8)
        petal(14, 430, .leadingScaled, rotation: 20, color: garden.rose, opacity: 0.4)
        petal(378, 470, .trailingScaled, rotation: -40, color: garden.petal, opacity: 0.85)
        petal(236, 820, .bottomLeading, scale: 0.8, rotation: 60, color: garden.rose, opacity: 0.35)
    }

    mutating func drawPopup() {
        design = size
        let w = size.width
        let y1 = size.height * 0.34
        let y2 = size.height * 0.62

        stem(.topLeading, opacity: 0.3, width: 1.2) { p, at in
            p.move(to: at(w + 8, y1 - 50))
            p.addCurve(to: at(w - 30, y1 + 60), control1: at(w - 24, y1 - 10), control2: at(w - 6, y1 + 30))
        }
        leaf(w - 12, y1 - 14, .topLeading, rotation: 160, color: garden.leafAlt, opacity: 0.3)
        leaf(w - 22, y1 + 40, .topLeading, rotation: 20, color: garden.leaf, opacity: 0.28)
        blossom(w - 16, y1 + 12, .topLeading, scale: 1.1, color: garden.rose, opacity: 0.55)
        daisy(w - 30, y1 + 62, .topLeading, scale: 0.9, color: garden.petal, opacity: 0.85)

        stem(.topLeading, opacity: 0.28, width: 1.2) { p, at in
            p.move(to: at(-8, y2 + 60))
            p.addCurve(to: at(26, y2 - 30), control1: at(20, y2 + 30), control2: at(6, y2))
        }
        leaf(8, y2 + 20, .topLeading, rotation: -40, color: garden.leaf, opacity: 0.28)
        tulip(26, y2 - 26, .topLeading, scale: 1.1, rotation: -10, color: garden.rose, opacity: 0.5)
        berries(12, y2 + 50, .topLeading, color: garden.mauve, opacity: 0.45)
    }

    mutating func drawSheet() {
        design = CGSize(width: 390, height: 556)

        stem(.bottomLeading, opacity: 0.36, width: 1.5) { p, at in
            p.move(to: at(-10, 570))
            p.addCurve(to: at(70, 400), control1: at(40, 500), control2: at(20, 450))
            p.addCurve(to: at(100, 290), control1: at(120, 350), control2: at(120, 330))
        }
        leaf(32, 498, .bottomLeading, rotation: -40, color: garden.leaf, opacity: 0.36)
        leaf(66, 420, .bottomLeading, rotation: 200, color: garden.leafAlt, opacity: 0.34)
        leaf(104, 352, .bottomLeading, rotation: -30, color: garden.leaf, opacity: 0.32)
        tulip(100, 292, .bottomLeading, scale: 1.4, rotation: -8, color: garden.rose, opacity: 0.72)
        daisy(80, 452, .bottomLeading, scale: 1.2, color: garden.petal, opacity: 0.95)
        blossom(36, 540, .bottomLeading, scale: 1.2, color: garden.wine, opacity: 0.45)

        stem(.bottomTrailing, opacity: 0.32, width: 1.3) { p, at in
            p.move(to: at(402, 420))
            p.addCurve(to: at(336, 530), control1: at(372, 450), control2: at(360, 490))
        }
        leaf(378, 448, .bottomTrailing, rotation: 200, color: garden.leafAlt, opacity: 0.32)
        daisy(340, 528, .bottomTrailing, scale: 1.1, color: garden.petal, opacity: 0.95)
        bud(372, 432, .bottomTrailing, scale: 0.85, color: garden.rose, opacity: 0.6)
    }

    // MARK: Elements

    private func stem(_ anchor: Anchor, opacity: Double, width: CGFloat, build: (inout Path, (CGFloat, CGFloat) -> CGPoint) -> Void) {
        var path = Path()
        build(&path) { point($0, $1, anchor) }
        context.stroke(path, with: .color(garden.vine.opacity(opacity)), style: StrokeStyle(lineWidth: width, lineCap: .round))
    }

    private func layer(_ x: CGFloat, _ y: CGFloat, _ anchor: Anchor, scale: CGFloat, rotation: Double, opacity: Double, draw: (inout GraphicsContext) -> Void) {
        var layer = context
        let origin = point(x, y, anchor)
        layer.translateBy(x: origin.x, y: origin.y)
        layer.rotate(by: .degrees(rotation))
        layer.scaleBy(x: scale, y: scale)
        layer.opacity = opacity
        draw(&layer)
    }

    private func leaf(_ x: CGFloat, _ y: CGFloat, _ anchor: Anchor, rotation: Double, color: Color, opacity: Double) {
        layer(x, y, anchor, scale: 1, rotation: rotation, opacity: opacity) { $0.fill(FausBloomShapes.leaf, with: .color(color)) }
    }

    private func blossom(_ x: CGFloat, _ y: CGFloat, _ anchor: Anchor, scale: CGFloat = 1, rotation: Double = 0, color: Color, opacity: Double) {
        layer(x, y, anchor, scale: scale, rotation: rotation, opacity: opacity) {
            $0.fill(FausBloomShapes.petals(count: 5, rx: 4.2, ry: 7), with: .color(color))
            $0.fill(FausBloomShapes.circle(radius: 2.8), with: .color(garden.blossomHeart))
        }
    }

    private func daisy(_ x: CGFloat, _ y: CGFloat, _ anchor: Anchor, scale: CGFloat = 1, color: Color, opacity: Double) {
        layer(x, y, anchor, scale: scale, rotation: 0, opacity: opacity) {
            $0.fill(FausBloomShapes.petals(count: 8, rx: 2.3, ry: 6, offset: 7), with: .color(color))
            $0.fill(FausBloomShapes.circle(radius: 3), with: .color(garden.pollen))
        }
    }

    private func tulip(_ x: CGFloat, _ y: CGFloat, _ anchor: Anchor, scale: CGFloat, rotation: Double, color: Color, opacity: Double) {
        layer(x, y, anchor, scale: scale, rotation: rotation, opacity: opacity) { $0.fill(FausBloomShapes.tulip, with: .color(color)) }
    }

    private func bud(_ x: CGFloat, _ y: CGFloat, _ anchor: Anchor, scale: CGFloat, color: Color, opacity: Double) {
        layer(x, y, anchor, scale: scale, rotation: 0, opacity: opacity) {
            $0.fill(FausBloomShapes.circle(radius: 8), with: .color(color))
            $0.stroke(FausBloomShapes.budSpiral, with: .color(.white.opacity(0.6)), style: StrokeStyle(lineWidth: 1.1, lineCap: .round))
        }
    }

    private func berries(_ x: CGFloat, _ y: CGFloat, _ anchor: Anchor, color: Color, opacity: Double) {
        layer(x, y, anchor, scale: 1, rotation: 0, opacity: opacity) { $0.fill(FausBloomShapes.berries, with: .color(color)) }
    }

    private func petal(_ x: CGFloat, _ y: CGFloat, _ anchor: Anchor, scale: CGFloat = 1, rotation: Double, color: Color, opacity: Double) {
        layer(x, y, anchor, scale: scale, rotation: rotation, opacity: opacity) {
            $0.fill(Path(ellipseIn: CGRect(x: -2.4, y: -4.4, width: 4.8, height: 8.8)), with: .color(color))
        }
    }
}

// MARK: - Shapes

/// Bloom's motifs, each centered on the origin.
enum FausBloomShapes {
    static let leaf = Path { p in
        p.move(to: .zero)
        p.addCurve(to: CGPoint(x: 24, y: -8), control1: CGPoint(x: 5, y: -9), control2: CGPoint(x: 15, y: -12))
        p.addCurve(to: .zero, control1: CGPoint(x: 17, y: -1), control2: CGPoint(x: 8, y: 3))
        p.closeSubpath()
    }

    static let tulip = Path { p in
        p.move(to: .zero)
        p.addCurve(to: CGPoint(x: -6, y: -15), control1: CGPoint(x: -7, y: -1), control2: CGPoint(x: -8, y: -10))
        p.addLine(to: CGPoint(x: -3, y: -11))
        p.addLine(to: CGPoint(x: 0, y: -16))
        p.addLine(to: CGPoint(x: 3, y: -11))
        p.addLine(to: CGPoint(x: 6, y: -15))
        p.addCurve(to: .zero, control1: CGPoint(x: 8, y: -10), control2: CGPoint(x: 7, y: -1))
        p.closeSubpath()
    }

    static let budSpiral = Path { p in
        p.move(to: CGPoint(x: 0, y: -1))
        p.addCurve(to: CGPoint(x: 0, y: 3), control1: CGPoint(x: 3, y: -1), control2: CGPoint(x: 3, y: 3))
        p.addCurve(to: CGPoint(x: 0, y: -4), control1: CGPoint(x: -4, y: 3), control2: CGPoint(x: -4, y: -3))
        p.addCurve(to: CGPoint(x: 2, y: 5.5), control1: CGPoint(x: 5, y: -4), control2: CGPoint(x: 6, y: 3))
    }

    static let berries: Path = {
        var p = circle(radius: 2.6)
        p.addPath(circle(radius: 2.1), transform: CGAffineTransform(translationX: 4.5, y: -3))
        p.addPath(circle(radius: 1.9), transform: CGAffineTransform(translationX: -3.4, y: -4.4))
        return p
    }()

    static func circle(radius: CGFloat) -> Path {
        Path(ellipseIn: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
    }

    /// `count` petals of radii `rx`×`ry` whose centers sit `offset` (default `ry`) from the origin.
    static func petals(count: Int, rx: CGFloat, ry: CGFloat, offset: CGFloat? = nil, rotation: Double = 0) -> Path {
        var path = Path()
        let petal = Path(ellipseIn: CGRect(x: -rx, y: -(offset ?? ry) - ry, width: rx * 2, height: ry * 2))
        for index in 0..<count {
            let angle = (rotation + Double(index) * 360 / Double(count)) * .pi / 180
            path.addPath(petal, transform: CGAffineTransform(rotationAngle: angle))
        }
        return path
    }
}

// MARK: - Hero Ornament

/// Bloom's decoration for hero surfaces, in place of the circles and capsules of
/// `FausOrnament.geometric`: a large petal flower at the top-trailing corner with its outline, a
/// leaf along the bottom-trailing edge and a blush sprig at the top-leading corner.
struct FausBloomOrnament: View {
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
    let sprig: Color

    var body: some View {
        Canvas { context, size in
            let w = size.width
            switch surface {
            case .heroCard:
                flower(context, center: CGPoint(x: w - 40, y: 6), rx: 20, ry: 34, opacity: 0.09)
                outline(context, center: CGPoint(x: w - 40, y: 6), rx: 13, ry: 24, opacity: 0.18)
                leafBand(context, origin: CGPoint(x: w - 190, y: 0), scale: 1, opacity: 0.08)
                sprigBranch(context, origin: CGPoint(x: -6, y: -6), scale: 1, opacity: 1)
            case .popupHeader:
                flower(context, center: CGPoint(x: w * 0.84, y: 0), rx: 16, ry: 28, opacity: 0.09)
                outline(context, center: CGPoint(x: w * 0.84, y: 0), rx: 10, ry: 19, opacity: 0.15)
                leafBand(context, origin: CGPoint(x: w * 0.84 - 76, y: -48), scale: 0.7, opacity: 0.07)
                sprigBranch(context, origin: CGPoint(x: -6, y: -14), scale: 0.6, opacity: 0.9)
            case .tabBar:
                flower(context, center: CGPoint(x: w - 26, y: 4), rx: 13, ry: 22, opacity: 0.09)
                outline(context, center: CGPoint(x: w - 26, y: 4), rx: 9, ry: 16, opacity: 0.15)
                sprigBranch(context, origin: CGPoint(x: -10, y: -10), scale: 0.62, opacity: 0.9)
            case .header:
                flower(context, center: CGPoint(x: w - 50, y: 40), rx: 28, ry: 50, opacity: 0.08)
                outline(context, center: CGPoint(x: w - 50, y: 40), rx: 18, ry: 34, opacity: 0.16)
                leafBand(context, origin: CGPoint(x: w - 230, y: size.height - 110), scale: 1.2, opacity: 0.08)
                sprigBranch(context, origin: CGPoint(x: -4, y: 24), scale: 1.3, opacity: 1)
                var bud = context
                bud.translateBy(x: w - 60, y: size.height - 64)
                bud.opacity = 0.4
                bud.fill(FausBloomShapes.petals(count: 5, rx: 4.2, ry: 7), with: .color(sprig))
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func flower(_ context: GraphicsContext, center: CGPoint, rx: CGFloat, ry: CGFloat, opacity: Double) {
        var layer = context
        layer.translateBy(x: center.x, y: center.y)
        layer.fill(FausBloomShapes.petals(count: 5, rx: rx, ry: ry), with: .color(ornament.opacity(opacity)))
    }

    private func outline(_ context: GraphicsContext, center: CGPoint, rx: CGFloat, ry: CGFloat, opacity: Double) {
        var layer = context
        layer.translateBy(x: center.x, y: center.y)
        layer.stroke(FausBloomShapes.petals(count: 5, rx: rx, ry: ry, rotation: 36), with: .color(ornament.opacity(opacity)), lineWidth: 1)
    }

    /// A long leaf rising toward the trailing edge, on a 190×112 frame.
    private func leafBand(_ context: GraphicsContext, origin: CGPoint, scale: CGFloat, opacity: Double) {
        var layer = context
        layer.translateBy(x: origin.x, y: origin.y)
        layer.scaleBy(x: scale, y: scale)
        var leaf = Path()
        leaf.move(to: CGPoint(x: 30, y: 120))
        leaf.addCurve(to: CGPoint(x: 200, y: 52), control1: CGPoint(x: 70, y: 90), control2: CGPoint(x: 120, y: 80))
        leaf.addCurve(to: CGPoint(x: 30, y: 120), control1: CGPoint(x: 140, y: 96), control2: CGPoint(x: 80, y: 110))
        leaf.closeSubpath()
        layer.fill(leaf, with: .color(ornament.opacity(opacity)))
    }

    /// A thin stem with two leaves, on a 120×70 frame.
    private func sprigBranch(_ context: GraphicsContext, origin: CGPoint, scale: CGFloat, opacity: Double) {
        var layer = context
        layer.translateBy(x: origin.x, y: origin.y)
        layer.scaleBy(x: scale, y: scale)
        layer.opacity = opacity
        var stem = Path()
        stem.move(to: CGPoint(x: 2, y: 64))
        stem.addCurve(to: CGPoint(x: 112, y: 10), control1: CGPoint(x: 30, y: 40), control2: CGPoint(x: 60, y: 26))
        layer.stroke(stem, with: .color(sprig.opacity(0.5)), style: StrokeStyle(lineWidth: 1.6 / scale, lineCap: .round))
        var leaves = Path()
        leaves.move(to: CGPoint(x: 34, y: 42))
        leaves.addCurve(to: CGPoint(x: 56, y: 26), control1: CGPoint(x: 36, y: 30), control2: CGPoint(x: 46, y: 24))
        leaves.addCurve(to: CGPoint(x: 34, y: 42), control1: CGPoint(x: 52, y: 36), control2: CGPoint(x: 44, y: 42))
        leaves.closeSubpath()
        leaves.move(to: CGPoint(x: 66, y: 26))
        leaves.addCurve(to: CGPoint(x: 94, y: 16), control1: CGPoint(x: 72, y: 16), control2: CGPoint(x: 84, y: 12))
        leaves.addCurve(to: CGPoint(x: 66, y: 26), control1: CGPoint(x: 86, y: 24), control2: CGPoint(x: 76, y: 28))
        leaves.closeSubpath()
        layer.fill(leaves, with: .color(sprig.opacity(0.38)))
    }
}

// MARK: - Badge Blossom

/// The daisy tucked on a brand badge's halo; the only Bloom touch next to the Faus mark.
struct FausBadgeBlossom: View {
    let garden: FausGarden
    var size: CGFloat = 40

    var body: some View {
        Canvas { context, canvasSize in
            var layer = context
            layer.translateBy(x: canvasSize.width / 2, y: canvasSize.height / 2)
            layer.scaleBy(x: size / 32, y: size / 32)
            layer.fill(FausBloomShapes.petals(count: 5, rx: 4.2, ry: 7), with: .color(garden.petal))
            layer.fill(FausBloomShapes.circle(radius: 2.8), with: .color(garden.pollen))
        }
        .frame(width: size, height: size)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
