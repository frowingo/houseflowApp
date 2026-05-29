import SwiftUI

// MARK: - Social Login Button

struct SocialLoginButton<Icon: View>: View {
    private let iconView: Icon
    let name: String
    let backgroundColor: Color
    let foregroundColor: Color
    let borderColor: Color?
    let action: () -> Void

    init(
        name: String,
        backgroundColor: Color,
        foregroundColor: Color,
        borderColor: Color? = nil,
        action: @escaping () -> Void,
        @ViewBuilder icon: () -> Icon
    ) {
        self.iconView = icon()
        self.name = name
        self.backgroundColor = backgroundColor
        self.foregroundColor = foregroundColor
        self.borderColor = borderColor
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: AppDesign.Spacing.xs) {
                iconView
                    .frame(width: 22, height: 22)
                Text(name)
                    .font(AppDesign.Typography.caption)
                    .foregroundColor(foregroundColor)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
            .background(backgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
                    .stroke(borderColor ?? Color.clear, lineWidth: 1)
            )
            .cornerRadius(AppDesign.CornerRadius.md)
        }
        .buttonStyle(PlainButtonStyle())
    }

    private var borderOverlay: some View {
        RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md)
            .stroke(borderColor ?? Color.clear, lineWidth: 1)
    }
}

// MARK: - Google Logo View

struct GoogleLogoView: View {
    var size: CGFloat = 20

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height
            let center = CGPoint(x: w / 2, y: h / 2)
            let lw = w * 0.22
            let r  = (w - lw) / 2

            let blue   = Color(red: 0.259, green: 0.522, blue: 0.957)
            let red    = Color(red: 0.918, green: 0.263, blue: 0.208)
            let yellow = Color(red: 0.980, green: 0.737, blue: 0.016)
            let green  = Color(red: 0.204, green: 0.659, blue: 0.325)
            let flat   = StrokeStyle(lineWidth: lw, lineCap: .butt)

            func arc(_ from: Double, _ to: Double) -> Path {
                var p = Path()
                p.addArc(center: center, radius: r,
                         startAngle: .degrees(from), endAngle: .degrees(to),
                         clockwise: true)
                return p
            }

            // Blue: top (290° → 355°)
            context.stroke(arc(290, 355), with: .color(blue),   style: flat)
            // Green: right → bottom-right (5° → 120°)
            context.stroke(arc(5,   120), with: .color(green),  style: flat)
            // Yellow: bottom (120° → 165°)
            context.stroke(arc(120, 165), with: .color(yellow), style: flat)
            // Red: left side (165° → 290°)
            context.stroke(arc(165, 290), with: .color(red),    style: flat)

            // Blue horizontal bar: center → right edge
            var bar = Path()
            bar.move(to: CGPoint(x: center.x, y: center.y))
            bar.addLine(to: CGPoint(x: w, y: center.y))
            context.stroke(bar, with: .color(blue),
                           style: StrokeStyle(lineWidth: lw, lineCap: .square))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Snapchat Ghost View

struct SnapchatGhostView: View {
    var size: CGFloat = 20
    var color: Color = .black

    var body: some View {
        Canvas { context, canvasSize in
            let w = canvasSize.width
            let h = canvasSize.height

            var ghost = Path()
            // Start: bottom center (between feet)
            ghost.move(to: CGPoint(x: w * 0.50, y: h * 0.83))
            // Right foot
            ghost.addCurve(to: CGPoint(x: w * 0.74, y: h * 0.93),
                           control1: CGPoint(x: w * 0.57, y: h * 0.78),
                           control2: CGPoint(x: w * 0.67, y: h * 0.97))
            // Right side up
            ghost.addCurve(to: CGPoint(x: w * 0.88, y: h * 0.56),
                           control1: CGPoint(x: w * 0.87, y: h * 0.86),
                           control2: CGPoint(x: w * 0.95, y: h * 0.72))
            // Right ear bump
            ghost.addCurve(to: CGPoint(x: w * 0.76, y: h * 0.20),
                           control1: CGPoint(x: w * 0.92, y: h * 0.38),
                           control2: CGPoint(x: w * 0.95, y: h * 0.20))
            // Head top right → center
            ghost.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.07),
                           control1: CGPoint(x: w * 0.65, y: h * 0.08),
                           control2: CGPoint(x: w * 0.58, y: h * 0.04))
            // Head top center → left
            ghost.addCurve(to: CGPoint(x: w * 0.24, y: h * 0.20),
                           control1: CGPoint(x: w * 0.42, y: h * 0.04),
                           control2: CGPoint(x: w * 0.35, y: h * 0.08))
            // Left ear bump
            ghost.addCurve(to: CGPoint(x: w * 0.12, y: h * 0.56),
                           control1: CGPoint(x: w * 0.05, y: h * 0.20),
                           control2: CGPoint(x: w * 0.08, y: h * 0.38))
            // Left side down
            ghost.addCurve(to: CGPoint(x: w * 0.26, y: h * 0.93),
                           control1: CGPoint(x: w * 0.05, y: h * 0.72),
                           control2: CGPoint(x: w * 0.13, y: h * 0.86))
            // Left foot → bottom center
            ghost.addCurve(to: CGPoint(x: w * 0.50, y: h * 0.83),
                           control1: CGPoint(x: w * 0.33, y: h * 0.97),
                           control2: CGPoint(x: w * 0.43, y: h * 0.78))
            ghost.closeSubpath()

            context.fill(ghost, with: .color(color))
        }
        .frame(width: size, height: size)
    }
}

// MARK: - Previews

#Preview("Google") {
    SocialLoginButton(
        name: "Google",
        backgroundColor: .white,
        foregroundColor: .black,
        borderColor: .gray.opacity(0.3),
        action: { print("Google login") }
    ) {
        GoogleLogoView(size: 22)
    }
    .frame(width: 100)
    .padding()
}

#Preview("Apple") {
    SocialLoginButton(
        name: "Apple",
        backgroundColor: .black,
        foregroundColor: .white,
        action: { print("Apple login") }
    ) {
        Image(systemName: "applelogo")
            .font(.system(size: 20))
            .foregroundColor(.white)
    }
    .frame(width: 100)
    .padding()
}

#Preview("Snapchat") {
    SocialLoginButton(
        name: "Snapchat",
        backgroundColor: .yellow,
        foregroundColor: .black,
        action: { print("Snapchat login") }
    ) {
        SnapchatGhostView(size: 20, color: .black)
    }
    .frame(width: 100)
    .padding()
}

#Preview("All Social Buttons") {
    HStack(spacing: 16) {
        SocialLoginButton(
            name: "Google",
            backgroundColor: .white,
            foregroundColor: .black,
            borderColor: .gray.opacity(0.3),
            action: {}
        ) { GoogleLogoView(size: 22) }

        SocialLoginButton(
            name: "Apple",
            backgroundColor: .black,
            foregroundColor: .white,
            action: {}
        ) {
            Image(systemName: "applelogo")
                .font(.system(size: 20))
                .foregroundColor(.white)
        }

        SocialLoginButton(
            name: "Snapchat",
            backgroundColor: .yellow,
            foregroundColor: .black,
            action: {}
        ) { SnapchatGhostView(size: 20, color: .black) }
    }
    .padding()
}

#Preview("Dark Mode") {
    HStack(spacing: 16) {
        SocialLoginButton(
            name: "Google",
            backgroundColor: .white,
            foregroundColor: .black,
            borderColor: .gray.opacity(0.3),
            action: {}
        ) { GoogleLogoView(size: 22) }

        SocialLoginButton(
            name: "Apple",
            backgroundColor: .black,
            foregroundColor: .white,
            action: {}
        ) {
            Image(systemName: "applelogo")
                .font(.system(size: 20))
                .foregroundColor(.white)
        }
    }
    .padding()
    .preferredColorScheme(.dark)
    .background(Color(.systemBackground))
}
