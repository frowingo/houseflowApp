import FausCrewCore
import SwiftUI

/// The Faus Switch robot for SwiftUI surfaces (lobby, color picker, Games cover), drawn
/// with the same geometry as the scene's `FausSwitchRobotNode`: wide head, dark visor,
/// two white eyes, an ear pad, a small body with arms and legs.
struct FausSwitchRobot: View {
    let color: FausSwitchColor
    var isUpsideDown = false

    var body: some View {
        Canvas { context, size in
            let unit = min(size.width / 32, size.height / 32)
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            if isUpsideDown {
                context.translateBy(x: 0, y: size.height)
                context.scaleBy(x: 1, y: -1)
            }
            let base = color.uiColor
            func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
                CGRect(x: center.x + x * unit, y: center.y - (y + height) * unit, width: width * unit, height: height * unit)
            }
            func fill(_ frame: CGRect, radius: CGFloat, _ tone: UIColor, stroke: UIColor? = nil, line: CGFloat = 0) {
                let path = Path(roundedRect: frame, cornerRadius: radius * unit, style: .continuous)
                context.fill(path, with: .color(Color(uiColor: tone)))
                if let stroke { context.stroke(path, with: .color(Color(uiColor: stroke)), lineWidth: line * unit) }
            }
            let limb = base.switchDarkened(0.32)
            let outline = base.switchDarkened(0.5)
            fill(rect(-5.6, -14.7, 4, 5), radius: 1.4, limb)
            fill(rect(1.6, -14.7, 4, 5), radius: 1.4, limb)
            fill(rect(-9.8, -10.4, 3.2, 7), radius: 1.6, limb)
            fill(rect(6.6, -10.4, 3.2, 7), radius: 1.6, limb)
            fill(rect(-6.3, -10.6, 12.6, 7.8), radius: 2.8, base.switchDarkened(0.1), stroke: outline, line: 0.6)
            fill(rect(1.1, -7.9, 2.6, 2.6), radius: 1.3, FausSwitchPalette.UI.lime)
            fill(rect(-12.6, -3, 25.2, 16.6), radius: 6.6, base, stroke: outline, line: 0.9)
            fill(rect(-14.6, 1.2, 3.8, 8.2), radius: 1.6, limb)
            fill(rect(-8.5, 10.6, 11, 1.6), radius: 0.8, base.switchLightened(0.45).withAlphaComponent(0.55))
            fill(rect(-7.4, 0.4, 18, 10), radius: 4.4, FausSwitchPalette.UI.visor)
            fill(rect(-3.6, 3, 4.2, 4.8), radius: 1.3, UIColor(fausHex: 0xF4FFF2))
            fill(rect(3.0, 3, 4.2, 4.8), radius: 1.3, UIColor(fausHex: 0xF4FFF2))
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityHidden(true)
    }
}

/// The light course texture behind every Faus Switch surface.
struct FausSwitchTextureBackdrop: View {
    var body: some View {
        GeometryReader { geometry in
            Image("FausSwitchTexture")
                .resizable()
                .scaledToFill()
                .frame(width: geometry.size.width, height: geometry.size.height)
                .clipped()
                .overlay(FausSwitchPalette.mint.opacity(0.18))
        }
        .accessibilityHidden(true)
    }
}

/// A small slice of the course: two rails, a split block pair and robots on both rails.
struct FausSwitchCoverArtwork: View {
    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let rail = max(9, height * 0.11)
            ZStack(alignment: .topLeading) {
                FausSwitchTextureBackdrop()
                VStack(spacing: 0) {
                    FausSwitchPalette.teal.frame(height: rail)
                    Spacer(minLength: 0)
                    FausSwitchPalette.teal.frame(height: rail)
                }
                block(width: width * 0.11, height: height * 0.3, fill: FausSwitchPalette.wine, edge: FausSwitchPalette.lavender)
                    .position(x: width * 0.56, y: rail + height * 0.15)
                block(width: width * 0.11, height: height * 0.2, fill: FausSwitchPalette.lavender, edge: FausSwitchPalette.deepWine)
                    .position(x: width * 0.66, y: height * 0.6)
                block(width: width * 0.1, height: height * 0.22, fill: FausSwitchPalette.deepWine, edge: FausSwitchPalette.sand)
                    .position(x: width * 0.84, y: height - rail - height * 0.11)
                FausSwitchRobot(color: .ocean)
                    .frame(width: height * 0.34, height: height * 0.34)
                    .position(x: width * 0.26, y: height - rail - height * 0.15)
                FausSwitchRobot(color: .berry, isUpsideDown: true)
                    .frame(width: height * 0.34, height: height * 0.34)
                    .position(x: width * 0.38, y: rail + height * 0.15)
                Capsule()
                    .fill(FausSwitchPalette.berry)
                    .frame(width: 3, height: height * 0.34)
                    .shadow(color: FausSwitchPalette.lavender, radius: 4)
                    .position(x: width * 0.76, y: height * 0.36)
            }
        }
        .clipped()
        .accessibilityHidden(true)
    }

    private func block(width: CGFloat, height: CGFloat, fill: Color, edge: Color) -> some View {
        RoundedRectangle(cornerRadius: 3, style: .continuous)
            .fill(fill)
            .overlay(RoundedRectangle(cornerRadius: 3, style: .continuous).stroke(edge, lineWidth: 1))
            .frame(width: width, height: height)
    }
}
