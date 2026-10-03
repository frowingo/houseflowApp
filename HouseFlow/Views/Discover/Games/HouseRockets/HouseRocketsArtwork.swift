import SwiftUI
import UIKit

/// Shared palette for SpriteKit, the lobby and the Games cover.
enum HouseRocketsPalette {
    static let burgundy = UIColor(red: 120 / 255, green: 0, blue: 0, alpha: 1)
    static let red = UIColor(red: 193 / 255, green: 18 / 255, blue: 31 / 255, alpha: 1)
    static let cream = UIColor(red: 253 / 255, green: 240 / 255, blue: 213 / 255, alpha: 1)
    static let navy = UIColor(red: 0, green: 48 / 255, blue: 73 / 255, alpha: 1)
    static let blue = UIColor(red: 102 / 255, green: 155 / 255, blue: 188 / 255, alpha: 1)
    static let ice = UIColor(red: 169 / 255, green: 214 / 255, blue: 229 / 255, alpha: 1)
    static let outer = UIColor(red: 28 / 255, green: 69 / 255, blue: 94 / 255, alpha: 1)

    // Preserve serialized player identifiers while changing their visual palette.
    static func player(_ color: HouseRocketsColor) -> UIColor {
        switch color {
        case .mint: cream
        case .coral: red
        case .blue: blue
        case .gold: burgundy
        }
    }
}

enum HouseRocketsTheme {
    static let background = Color(HouseRocketsPalette.outer)
    static let panel = Color(HouseRocketsPalette.blue).opacity(0.12)
    static let accent = Color(HouseRocketsPalette.cream)
    static let danger = Color(HouseRocketsPalette.cream)
    static let sky = Color(HouseRocketsPalette.blue)
    static let ink = Color(HouseRocketsPalette.cream)
    static let muted = Color(HouseRocketsPalette.cream).opacity(0.76)
}

/// Curved vector contours based on the supplied rocket.png, normalized to face right.
/// A single drawing keeps the in-game silhouette and cover illustration consistent.
enum HouseRocketsArtwork {
    private static func referencePath(_ draw: (CGMutablePath) -> Void) -> CGPath {
        let path = CGMutablePath()
        draw(path)
        let k = 0.065 / sqrt(2.0)
        var transform = CGAffineTransform(a: k, b: -k, c: -k, d: -k, tx: 0, ty: 512 * k)
        return path.copy(using: &transform)!
    }

    static let hull = referencePath { p in
        p.move(to: CGPoint(x: 142, y: 245))
        p.addCurve(to: CGPoint(x: 496, y: 16), control1: CGPoint(x: 211, y: 91), control2: CGPoint(x: 368, y: 21))
        p.addCurve(to: CGPoint(x: 264, y: 366), control1: CGPoint(x: 486, y: 184), control2: CGPoint(x: 415, y: 313))
        p.closeSubpath()
    }
    static let fins = referencePath { p in
        p.move(to: CGPoint(x: 190, y: 153))
        p.addCurve(to: CGPoint(x: 17, y: 242), control1: CGPoint(x: 113, y: 129), control2: CGPoint(x: 49, y: 189))
        p.addLine(to: CGPoint(x: 138, y: 247)); p.closeSubpath()
        p.move(to: CGPoint(x: 359, y: 322))
        p.addCurve(to: CGPoint(x: 270, y: 496), control1: CGPoint(x: 384, y: 401), control2: CGPoint(x: 320, y: 466))
        p.addLine(to: CGPoint(x: 265, y: 372)); p.closeSubpath()
    }
    static let collar = referencePath { p in
        p.move(to: CGPoint(x: 142, y: 245)); p.addLine(to: CGPoint(x: 264, y: 366))
        p.addLine(to: CGPoint(x: 214, y: 420)); p.addLine(to: CGPoint(x: 91, y: 297)); p.closeSubpath()
    }
    static let nose = referencePath { p in
        p.move(to: CGPoint(x: 378, y: 38)); p.addLine(to: CGPoint(x: 474, y: 134))
        p.addCurve(to: CGPoint(x: 496, y: 16), control1: CGPoint(x: 485, y: 96), control2: CGPoint(x: 494, y: 55))
        p.addCurve(to: CGPoint(x: 378, y: 38), control1: CGPoint(x: 455, y: 19), control2: CGPoint(x: 414, y: 26))
        p.closeSubpath()
    }
    static let window = referencePath { p in
        p.addEllipse(in: CGRect(x: 282, y: 137, width: 94, height: 94))
    }
    static let flame = referencePath { p in
        p.move(to: CGPoint(x: 124, y: 328))
        p.addCurve(to: CGPoint(x: 53, y: 459), control1: CGPoint(x: 81, y: 368), control2: CGPoint(x: 58, y: 407))
        p.addCurve(to: CGPoint(x: 184, y: 388), control1: CGPoint(x: 108, y: 453), control2: CGPoint(x: 151, y: 428))
        p.closeSubpath()
    }

    /// Quiet, nested terrain contours. Generated only when the drawing size changes in SpriteKit.
    static func topography(in size: CGSize) -> [CGPath] {
        var paths: [CGPath] = []
        for index in 0..<20 {
            let path = CGMutablePath()
            let ring = index % 10
            let radius = CGFloat(34 + ring * 23)
            let centerX: CGFloat = index < 10 ? 0.86 : 0.14
            let centerY: CGFloat = index < 10 ? 0.82 : 0.12
            let center = CGPoint(x: size.width * centerX, y: size.height * centerY)
            let horizontalRadius = radius * size.width / 440
            let verticalRadius = radius * size.height / 260
            for step in 0...96 {
                let angle = CGFloat(step) / 96 * .pi * 2
                let wave = 1 + 0.10 * sin(3 * angle + 0.8) + 0.06 * cos(5 * angle)
                let x = center.x + cos(angle) * wave * horizontalRadius
                let y = center.y + sin(angle) * wave * verticalRadius
                if step == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
            path.closeSubpath()
            paths.append(path)
        }
        return paths
    }

    /// The outer contours move from cool blue through cream into the two reds.
    /// Keep this treatment out of the course so ships and hazards stay prominent.
    static func outerContourColor(at index: Int) -> UIColor {
        let ring = index % 10
        if index < 10 {
            return switch ring {
            case 0...2: HouseRocketsPalette.blue
            case 3...4, 6: HouseRocketsPalette.ice
            case 5: HouseRocketsPalette.cream
            case 7: HouseRocketsPalette.red
            default: HouseRocketsPalette.burgundy
            }
        } else {
            return switch ring {
            case 0...1: HouseRocketsPalette.burgundy
            case 2...4, 6...7: HouseRocketsPalette.red
            case 5: HouseRocketsPalette.cream
            case 8: HouseRocketsPalette.ice
            default: HouseRocketsPalette.blue
            }
        }
    }

    static func outerContourOpacity(at index: Int) -> CGFloat {
        let ring = index % 10
        if ring == 5 { return 0.32 }
        if index < 10 {
            if ring == 7 { return 0.42 }
            if ring >= 8 { return 0.38 }
        } else {
            if ring <= 1 { return 0.38 }
            if (2...4).contains(ring) || (6...7).contains(ring) { return 0.42 }
        }
        return 0.24
    }
}

struct HouseRocketsTopography: View {
    var body: some View {
        Canvas { context, size in
            for (index, path) in HouseRocketsArtwork.topography(in: size).enumerated() {
                let color = Color(HouseRocketsArtwork.outerContourColor(at: index))
                if index.isMultiple(of: 3) {
                    context.stroke(Path(path), with: .color(color.opacity(0.06)), lineWidth: 12)
                }
                context.stroke(Path(path),
                               with: .color(color.opacity(HouseRocketsArtwork.outerContourOpacity(at: index))),
                               lineWidth: index.isMultiple(of: 4) ? 1.2 : 0.75)
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}

struct HouseRocketsRocketMark: View {
    var body: some View {
        Canvas { context, size in
            context.translateBy(x: size.width / 2, y: size.height / 2)
            let scale = min(size.width, size.height) / 52
            context.scaleBy(x: scale, y: -scale)
            context.rotate(by: .degrees(40))
            let cream = Color(HouseRocketsPalette.cream)
            let navy = Color(HouseRocketsPalette.navy)
            for (path, fill) in [(HouseRocketsArtwork.flame, cream),
                                 (HouseRocketsArtwork.fins, Color(HouseRocketsPalette.blue)),
                                 (HouseRocketsArtwork.hull, cream),
                                 (HouseRocketsArtwork.collar, Color(HouseRocketsPalette.burgundy)),
                                 (HouseRocketsArtwork.nose, Color(HouseRocketsPalette.red)),
                                 (HouseRocketsArtwork.window, navy)] {
                context.fill(Path(path), with: .color(fill))
                context.stroke(Path(path), with: .color(navy), style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            }
        }
        .accessibilityHidden(true)
    }
}
