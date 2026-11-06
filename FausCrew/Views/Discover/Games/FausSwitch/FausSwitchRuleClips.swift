import FausCrewCore
import SwiftUI

/// The lobby's rules as tiny looping clips instead of paragraphs: each one plays a
/// two- to three-second moment of the race (a flip, a block, a gap, a pad, a portal)
/// on a 160 × 90 stage. Drawn with `Canvas` on a 30 fps timeline, so there are no
/// video files. With Reduce Motion each clip holds one telling frame. The clips are
/// decorative; the rule's sentence is still read out by VoiceOver.
enum FausSwitchRuleClipKind: CaseIterable {
    case tap, solid, robots, gap, boost, slow, portal

    /// Loop length in seconds.
    var period: Double {
        switch self {
        case .robots, .portal: return 3.6
        case .slow: return 3.4
        default: return 3.2
        }
    }

    /// The frame shown under Reduce Motion.
    var stillPhase: Double {
        switch self {
        case .tap: return 0.3
        case .solid: return 0.5
        case .robots: return 0.5
        case .gap: return 0.55
        case .boost: return 0.6
        case .slow: return 0.55
        case .portal: return 0.5
        }
    }
}

struct FausSwitchRuleClip: View {
    let kind: FausSwitchRuleClipKind
    let playerColor: FausSwitchColor
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var otherColor: FausSwitchColor { playerColor == .berry ? .ocean : .berry }

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? kind.stillPhase : (seconds / kind.period).truncatingRemainder(dividingBy: 1)
            Canvas { context, size in
                let stage = FausSwitchClipStage(context: context, size: size)
                stage.background()
                switch kind {
                case .tap: stage.drawTap(phase)
                case .solid: stage.drawSolid(phase)
                case .robots: stage.drawRobots(phase)
                case .gap: stage.drawGap(phase)
                case .boost: stage.drawBoost(phase)
                case .slow: stage.drawSlow(phase)
                case .portal: stage.drawPortal(phase)
                }
            } symbols: {
                FausSwitchRobot(color: playerColor).frame(width: 48, height: 48).tag(ClipSymbol.player)
                FausSwitchRobot(color: playerColor, isUpsideDown: true).frame(width: 48, height: 48).tag(ClipSymbol.playerFlipped)
                FausSwitchRobot(color: otherColor).frame(width: 48, height: 48).tag(ClipSymbol.other)
                FausSwitchRobot(color: otherColor, isUpsideDown: true).frame(width: 48, height: 48).tag(ClipSymbol.otherFlipped)
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(FausSwitchPalette.plum)
                    .frame(width: 40, height: 40)
                    .tag(ClipSymbol.hand)
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.md, style: .continuous)
            .stroke(FausSwitchPalette.wine.opacity(0.22), lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// The floor rail's solid pieces between `from` and `to` with `gaps` cut out. Gaps
/// slide in from beyond the right edge and out past the left, so they may lie partly
/// or wholly outside the stage; no piece is ever empty or reversed.
enum FausSwitchClipRails {
    static func parts(from start: CGFloat, to end: CGFloat, around gaps: [ClosedRange<CGFloat>]) -> [ClosedRange<CGFloat>] {
        var parts: [ClosedRange<CGFloat>] = []
        var cursor = start
        for gap in gaps.sorted(by: { $0.lowerBound < $1.lowerBound }) {
            guard cursor < end else { break }
            let cut = min(gap.lowerBound, end)
            if cut > cursor { parts.append(cursor...cut) }
            cursor = max(cursor, gap.upperBound)
        }
        if cursor < end { parts.append(cursor...end) }
        return parts
    }
}

enum ClipSymbol: Hashable {
    case player, playerFlipped, other, otherFlipped, hand
}

/// World units: 160 wide, 90 high, origin bottom left. Rails are 7 thick; a robot is
/// 14 × 17 like the race's 27.2 × 33.6 box. The camera stands still and the world
/// slides left, as in the race.
private struct FausSwitchClipStage {
    let context: GraphicsContext
    let size: CGSize

    static let width: CGFloat = 160
    static let rail: CGFloat = 7
    static let floor: CGFloat = 7
    static let ceiling: CGFloat = 83
    static let robotHeight: CGFloat = 17
    static let floorCenter: CGFloat = floor + robotHeight / 2
    static let ceilingCenter: CGFloat = ceiling - robotHeight / 2
    /// How far the world slides per loop.
    static let travel: CGFloat = 240

    private var scale: CGFloat { size.width / Self.width }

    // MARK: Geometry

    private func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: x * scale, y: size.height - (y + height) * scale, width: width * scale, height: height * scale)
    }

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint {
        CGPoint(x: x * scale, y: size.height - y * scale)
    }

    private func fill(_ frame: CGRect, _ color: Color, radius: CGFloat = 1.6) {
        context.fill(Path(roundedRect: frame, cornerRadius: radius * scale, style: .continuous), with: .color(color))
    }

    /// Where an object that starts at `start` (screen x at phase 0) is now.
    private func slide(_ start: CGFloat, _ phase: Double) -> CGFloat {
        start - Self.travel * CGFloat(phase)
    }

    // MARK: Timing

    private static func progress(_ phase: Double, _ start: Double, _ end: Double) -> CGFloat {
        CGFloat(min(1, max(0, (phase - start) / (end - start))))
    }

    private static func smooth(_ value: CGFloat) -> CGFloat { value * value * (3 - 2 * value) }

    /// A flip from one rail to the other between `start` and `end`, accelerating like
    /// gravity.
    private static func flight(_ phase: Double, _ start: Double, _ end: Double, up: Bool) -> CGFloat {
        let fall = progress(phase, start, end)
        let travel = (ceilingCenter - floorCenter) * fall * fall
        return up ? floorCenter + travel : ceilingCenter - travel
    }

    // MARK: Pieces

    func background() {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(FausSwitchPalette.mint))
    }

    /// Both rails, with holes at `floorGaps` (screen x ranges) and stripes sliding left.
    private func rails(_ phase: Double, floorGaps: [ClosedRange<CGFloat>] = []) {
        let floorParts = FausSwitchClipRails.parts(from: -10, to: Self.width + 10, around: floorGaps)
        for part in floorParts {
            fill(rect(part.lowerBound, 0, part.upperBound - part.lowerBound, Self.rail), FausSwitchPalette.teal, radius: 0)
            fill(rect(part.lowerBound, Self.rail - 1.2, part.upperBound - part.lowerBound, 1.2), FausSwitchPalette.lime, radius: 0)
        }
        fill(rect(-10, Self.ceiling, Self.width + 20, Self.rail), FausSwitchPalette.teal, radius: 0)
        fill(rect(-10, Self.ceiling, Self.width + 20, 1.2), FausSwitchPalette.lime, radius: 0)
        // Stripes show the course moving.
        let offset = (CGFloat(phase) * Self.travel).truncatingRemainder(dividingBy: 20)
        var x = -offset
        while x < Self.width + 20 {
            let onFloor = floorParts.contains { $0.contains(x) && $0.contains(x + 6) }
            if onFloor { fill(rect(x, 2, 6, 1.4), FausSwitchPalette.green.opacity(0.7), radius: 0.7) }
            fill(rect(x + 10, Self.ceiling + 3.6, 6, 1.4), FausSwitchPalette.green.opacity(0.7), radius: 0.7)
            x += 20
        }
        for gap in floorGaps {
            fill(rect(gap.lowerBound - 1.4, 0, 1.4, Self.rail), FausSwitchPalette.berry, radius: 0)
            fill(rect(gap.upperBound, 0, 1.4, Self.rail), FausSwitchPalette.berry, radius: 0)
        }
    }

    private func robot(_ symbol: ClipSymbol, x: CGFloat, y: CGFloat, opacity: Double = 1) {
        guard opacity > 0.01, let resolved = context.resolveSymbol(id: symbol) else { return }
        // The robot art spans about 28 of its 32-unit square vertically.
        let side = Self.robotHeight * 32 / 28
        var layer = context
        layer.opacity = opacity
        layer.draw(resolved, in: rect(x - side / 2, y - side / 2, side, side))
    }

    /// A tap: a ring spreading from the robot and the finger lighting up in the corner.
    private func tap(_ phase: Double, at time: Double, x: CGFloat, y: CGFloat) {
        let spread = Self.progress(phase, time, time + 0.16)
        guard phase >= time, spread < 1 else { return }
        let radius = (5 + 13 * spread) * scale
        let center = point(x, y)
        let ring = Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2))
        context.stroke(ring, with: .color(FausSwitchPalette.wine.opacity(Double(1 - spread))), lineWidth: 1.6 * scale)
    }

    private func hand(_ phase: Double, taps: [Double]) {
        guard let resolved = context.resolveSymbol(id: ClipSymbol.hand) else { return }
        let glow = taps.map { max(0, 1 - abs(phase - $0) / 0.07) }.max() ?? 0
        var layer = context
        layer.opacity = 0.35 + 0.65 * glow
        let side = 15 + 3 * CGFloat(glow)
        layer.draw(resolved, in: rect(Self.width - side - 6, 26 - side / 2, side, side))
    }

    private func chevrons(_ frame: CGRect, color: Color, backward: Bool) {
        var path = Path()
        let rise = frame.height * 0.28
        for index in 0..<3 {
            let x = backward ? frame.maxX - frame.width * (0.28 + CGFloat(index) * 0.22)
                : frame.minX + frame.width * (0.28 + CGFloat(index) * 0.22)
            let arm = (backward ? 1 : -1) * frame.height * 0.22
            path.move(to: CGPoint(x: x + arm, y: frame.midY - rise))
            path.addLine(to: CGPoint(x: x, y: frame.midY))
            path.addLine(to: CGPoint(x: x + arm, y: frame.midY + rise))
        }
        context.stroke(path, with: .color(color), style: StrokeStyle(lineWidth: 1.1 * scale, lineCap: .round, lineJoin: .round))
    }

    private func portalRing(x: CGFloat, onFloor: Bool, pulse: Double, faint: Bool = false) {
        let height: CGFloat = 21, width: CGFloat = 11
        let base = onFloor ? Self.floor : Self.ceiling - height
        let frame = rect(x - width / 2, base, width, height)
        let ring = Path(ellipseIn: frame)
        if faint {
            context.fill(ring, with: .color(FausSwitchPalette.lavender.opacity(0.35)))
            context.stroke(ring, with: .color(FausSwitchPalette.wine.opacity(0.45)), lineWidth: 1 * scale)
            return
        }
        context.fill(ring, with: .color(FausSwitchPalette.deepWine))
        let core = 0.45 + 0.15 * sin(pulse * 2 * .pi * 3)
        context.fill(Path(ellipseIn: frame.insetBy(dx: frame.width * (1 - core) / 2, dy: frame.height * (1 - core) / 2)),
                     with: .color(FausSwitchPalette.lavender))
        context.stroke(ring, with: .color(FausSwitchPalette.wine), lineWidth: 1.8 * scale)
    }

    // MARK: Clips

    /// Tap on the floor: up to the ceiling; tap on the ceiling: back down.
    func drawTap(_ phase: Double) {
        rails(phase)
        let x: CGFloat = 60
        let y: CGFloat
        let flipped: Bool
        switch phase {
        case ..<0.25: y = Self.floorCenter; flipped = false
        case ..<0.65: y = Self.flight(phase, 0.25, 0.37, up: true); flipped = true
        default: y = Self.flight(phase, 0.65, 0.77, up: false); flipped = false
        }
        robot(flipped ? .playerFlipped : .player, x: x, y: y)
        tap(phase, at: 0.25, x: x, y: Self.floorCenter)
        tap(phase, at: 0.65, x: x, y: Self.ceilingCenter)
        hand(phase, taps: [0.25, 0.65])
    }

    /// A floor wall and its island slide in; the robot flips over to the ceiling,
    /// passes, and comes back down.
    func drawSolid(_ phase: Double) {
        rails(phase)
        let wall = slide(170, phase)
        fill(rect(wall, Self.floor, 14, 40), FausSwitchPalette.wine)
        fill(rect(wall + 20, 50, 20, 8), FausSwitchPalette.wine)
        let x: CGFloat = 50
        let y: CGFloat
        let flipped: Bool
        switch phase {
        case ..<0.3: y = Self.floorCenter; flipped = false
        case ..<0.72: y = Self.flight(phase, 0.3, 0.42, up: true); flipped = true
        default: y = Self.flight(phase, 0.72, 0.84, up: false); flipped = false
        }
        robot(flipped ? .playerFlipped : .player, x: x, y: y)
        tap(phase, at: 0.3, x: x, y: Self.floorCenter)
        tap(phase, at: 0.72, x: x, y: Self.ceilingCenter)
    }

    /// The player drops onto another robot's head, rides it, then flips away.
    func drawRobots(_ phase: Double) {
        rails(phase)
        let x: CGFloat = 70
        robot(.other, x: x, y: Self.floorCenter)
        let head = Self.floorCenter + Self.robotHeight
        let y: CGFloat
        let flipped: Bool
        switch phase {
        case ..<0.2:
            y = Self.ceilingCenter; flipped = true
        case ..<0.62:
            let fall = Self.progress(phase, 0.2, 0.3)
            y = Self.ceilingCenter - (Self.ceilingCenter - head) * fall * fall; flipped = false
        default:
            let rise = Self.progress(phase, 0.62, 0.72)
            y = head + (Self.ceilingCenter - head) * rise * rise; flipped = true
        }
        robot(flipped ? .playerFlipped : .player, x: x, y: y)
        tap(phase, at: 0.2, x: x, y: Self.ceilingCenter)
        tap(phase, at: 0.62, x: x, y: head)
    }

    /// The player flips over a floor gap in time; the robot ahead does not and falls.
    func drawGap(_ phase: Double) {
        let gap = slide(170, phase)
        rails(phase, floorGaps: [gap...(gap + 30)])
        let fallerX: CGFloat = 92
        // Over the gap from about 0.36; it drops out of the frame.
        let fallen = Self.progress(phase, 0.37, 0.56)
        let fallerOpacity = phase > 0.86 ? Double(Self.progress(phase, 0.86, 1)) : Double(1 - fallen * 0.6)
        let fallerY = phase > 0.86 ? Self.floorCenter : Self.floorCenter - 60 * fallen * fallen
        robot(.other, x: fallerX, y: fallerY, opacity: fallerOpacity)
        let x: CGFloat = 40
        let y: CGFloat
        let flipped: Bool
        switch phase {
        case ..<0.3: y = Self.floorCenter; flipped = false
        case ..<0.78: y = Self.flight(phase, 0.3, 0.42, up: true); flipped = true
        default: y = Self.flight(phase, 0.78, 0.9, up: false); flipped = false
        }
        robot(flipped ? .playerFlipped : .player, x: x, y: y)
        tap(phase, at: 0.3, x: x, y: Self.floorCenter)
    }

    /// Mid-flip through a floating speed pad: the robot surges forward for a moment.
    func drawBoost(_ phase: Double) {
        rails(phase)
        let pad = slide(170, phase)
        let used = phase > 0.5
        let padFrame = rect(pad - 12, 40, 24, 10)
        fill(padFrame, FausSwitchPalette.green.opacity(used ? 0.35 : 1), radius: 2)
        context.stroke(Path(roundedRect: padFrame, cornerRadius: 2 * scale), with: .color(FausSwitchPalette.deepWine.opacity(used ? 0.3 : 1)),
                       lineWidth: 0.8 * scale)
        chevrons(padFrame, color: FausSwitchPalette.mint.opacity(used ? 0.4 : 1), backward: false)
        let surge = phase < 0.5 ? 0 : (phase < 0.6 ? Self.smooth(Self.progress(phase, 0.5, 0.6))
            : 1 - Self.smooth(Self.progress(phase, 0.7, 0.95)))
        let x = 50 + 30 * surge
        let y: CGFloat
        let flipped: Bool
        switch phase {
        case ..<0.42: y = Self.floorCenter; flipped = false
        case ..<0.84: y = Self.flight(phase, 0.42, 0.54, up: true); flipped = true
        default: y = Self.flight(phase, 0.84, 0.96, up: false); flipped = false
        }
        if surge > 0.05 {
            for (index, offset) in [CGFloat(-4), 0, 4].enumerated() {
                let length = (10 + CGFloat(index % 2) * 5) * surge
                fill(rect(x - 9 - length, y + offset - 0.6, length, 1.2), FausSwitchPalette.green.opacity(0.8), radius: 0.6)
            }
        }
        robot(flipped ? .playerFlipped : .player, x: x, y: y)
        tap(phase, at: 0.42, x: 50, y: Self.floorCenter)
    }

    /// Running over a slow pad on the floor: the robot drops back for a moment.
    func drawSlow(_ phase: Double) {
        rails(phase)
        let pad = slide(176, phase)
        let used = phase > 0.42
        let padFrame = rect(pad - 12, Self.floor, 24, 7)
        fill(padFrame, FausSwitchPalette.lavender.opacity(used ? 0.45 : 1), radius: 1.5)
        context.stroke(Path(roundedRect: padFrame, cornerRadius: 1.5 * scale),
                       with: .color(FausSwitchPalette.deepWine.opacity(used ? 0.35 : 1)), lineWidth: 0.8 * scale)
        chevrons(padFrame, color: FausSwitchPalette.deepWine.opacity(used ? 0.4 : 1), backward: true)
        let drop = phase < 0.42 ? 0 : (phase < 0.62 ? Self.smooth(Self.progress(phase, 0.42, 0.62))
            : 1 - Self.smooth(Self.progress(phase, 0.75, 0.98)))
        let x = 72 - 32 * drop
        if drop > 0.05 {
            let center = point(x, Self.floorCenter)
            let radius = 13 * scale
            context.fill(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                         with: .color(FausSwitchPalette.lavender.opacity(0.45 * Double(drop))))
        }
        robot(.player, x: x, y: Self.floorCenter)
    }

    /// Into a floor portal: out on the ceiling, farther back, then on with the race.
    func drawPortal(_ phase: Double) {
        rails(phase)
        let portal = slide(178, phase)
        // The exit sits on the ceiling behind the portal, where the robot will come out.
        portalRing(x: portal - 52, onFloor: false, pulse: phase, faint: true)
        portalRing(x: portal, onFloor: true, pulse: phase)
        // The robot's front meets the opening; it comes out at the exit ring as it is then.
        let entered = 0.38
        let back = 178 - Self.travel * CGFloat(entered) - 52
        if phase < entered {
            robot(.player, x: 80, y: Self.floorCenter)
        } else if phase < 0.42 {
            // A blink between the two rings.
            let flash = Self.progress(phase, entered, 0.42)
            let center = point(portal, Self.floor + 10)
            let radius = (4 + 12 * flash) * scale
            context.stroke(Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                           with: .color(FausSwitchPalette.lavender.opacity(Double(1 - flash))), lineWidth: 2 * scale)
        } else {
            let x = phase < 0.74 ? back : back + (80 - back) * Self.smooth(Self.progress(phase, 0.74, 1))
            let y: CGFloat = phase < 0.62 ? Self.ceilingCenter : Self.flight(phase, 0.62, 0.74, up: false)
            robot(phase < 0.62 ? .playerFlipped : .player, x: x, y: y, opacity: Double(Self.progress(phase, 0.42, 0.47)))
            if phase >= 0.62 { tap(phase, at: 0.62, x: back, y: Self.ceilingCenter) }
        }
    }
}
