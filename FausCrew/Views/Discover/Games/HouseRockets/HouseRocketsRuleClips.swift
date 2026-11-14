import FausCrewCore
import SwiftUI

/// The lobby's How to play as tiny looping clips instead of paragraphs, like Faus Tanks':
/// each one plays a three- to four-second moment of a flight (steering from an edge, the
/// held heading, the two speed fields, falling behind) on a 160 × 90 slice of the course.
/// Drawn with `Canvas` on a 30 fps timeline, so there are no video files. With Reduce Motion
/// each clip holds one telling frame. The clips are decorative; the rule's sentence is still
/// read out by VoiceOver. Android draws the same clips from the same numbers
/// (`HouseRocketsRuleClips.kt`).
enum HouseRocketsRuleClipKind: CaseIterable {
    case steer, thrust, fields, survive

    /// Loop length in seconds.
    var period: Double {
        switch self {
        case .steer, .thrust: return 3.6
        case .fields, .survive: return 4.0
        }
    }

    /// The frame shown under Reduce Motion.
    var stillPhase: Double {
        switch self {
        case .steer: return 0.4
        case .thrust: return 0.6
        case .fields: return 0.32
        case .survive: return 0.55
        }
    }

    var titleKey: String {
        switch self {
        case .steer: return "house_rockets_clip_steer"
        case .thrust: return "house_rockets_clip_thrust"
        case .fields: return "house_rockets_clip_fields"
        case .survive: return "house_rockets_clip_survive"
        }
    }

    var detailKey: String { titleKey + "_detail" }
}

struct HouseRocketsRuleClip: View {
    let kind: HouseRocketsRuleClipKind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? kind.stillPhase : (seconds / kind.period).truncatingRemainder(dividingBy: 1)
            Canvas { context, size in
                let stage = HouseRocketsClipStage(context: context, size: size)
                switch kind {
                case .steer: stage.drawSteer(phase)
                case .thrust: stage.drawThrust(phase)
                case .fields: stage.drawFields(phase)
                case .survive: stage.drawSurvive(phase)
                }
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous)
            .stroke(HouseRocketsPreparationTheme.hairline, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

/// Stage units: 160 wide, 90 high, origin top left, y down; headings in degrees, 0 = right
/// (the course direction), clockwise. A rocket is the course artwork at 0.42 (nose 9 ahead
/// of its center, the player's ring 10.5 around it).
private struct HouseRocketsClipStage {
    let context: GraphicsContext
    let size: CGSize

    static let width: CGFloat = 160
    static let height: CGFloat = 90
    static let rocketScale: CGFloat = 0.42
    static let fieldRadius: CGFloat = 9
    static let trackTop: CGFloat = 8
    static let trackBottom: CGFloat = 82

    private var scale: CGFloat { size.width / Self.width }
    private static let player = HouseRocketsColor.mint
    private static let rival = HouseRocketsColor.coral
    private static let cream = Color(HouseRocketsPalette.cream)
    private static let navy = Color(HouseRocketsPalette.navy)
    private static let blue = Color(HouseRocketsPalette.blue)
    private static let red = Color(HouseRocketsPalette.red)
    private static let burgundy = Color(HouseRocketsPalette.burgundy)

    // MARK: Geometry and timing

    private func point(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * scale, y: y * scale) }

    private func rect(_ x: CGFloat, _ y: CGFloat, _ width: CGFloat, _ height: CGFloat) -> CGRect {
        CGRect(x: x * scale, y: y * scale, width: width * scale, height: height * scale)
    }

    private func circle(_ x: CGFloat, _ y: CGFloat, _ radius: CGFloat) -> Path {
        Path(ellipseIn: rect(x - radius, y - radius, radius * 2, radius * 2))
    }

    private static func progress(_ phase: Double, _ start: Double, _ end: Double) -> CGFloat {
        CGFloat(min(1, max(0, (phase - start) / (end - start))))
    }

    private static func smooth(_ value: CGFloat) -> CGFloat { value * value * (3 - 2 * value) }

    /// Fades the whole clip out at its end and in at its start, hiding the loop's jump.
    private static func loopFade(_ phase: Double, out start: Double = 0.9) -> Double {
        if phase < 0.05 { return Double(progress(phase, 0, 0.05)) }
        return 1 - Double(progress(phase, start, 0.97))
    }

    /// The flame's flicker while thrust is on.
    private static func flicker(_ phase: Double) -> CGFloat { 1 + 0.12 * CGFloat(sin(phase * 2 * .pi * 14)) }

    /// Integrates a heading (degrees over the loop) into the distance flown across the
    /// course, for a rocket moving `speed` units per loop.
    private static func drift(to phase: Double, speed: CGFloat, heading: (Double) -> CGFloat) -> CGPoint {
        let steps = max(1, Int(phase * 120))
        let step = phase / Double(steps)
        var x: CGFloat = 0, y: CGFloat = 0
        for index in 0..<steps {
            let angle = heading((Double(index) + 0.5) * step) * .pi / 180
            x += cos(angle) * speed * CGFloat(step)
            y += sin(angle) * speed * CGFloat(step)
        }
        return CGPoint(x: x, y: y)
    }

    // MARK: Pieces

    /// The course: the outer terrain color, the navy track with its rails and the centre
    /// dashes, which slide left by `scroll` units to show the flight.
    private func background(scroll: CGFloat, opacity: Double = 1) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(HouseRocketsPalette.outer)))
        var layer = context
        layer.opacity = opacity
        layer.fill(Path(rect(0, Self.trackTop, Self.width, Self.trackBottom - Self.trackTop)), with: .color(Self.navy))
        for y in [Self.trackTop, Self.trackBottom] {
            layer.fill(Path(rect(0, y - 0.8, Self.width, 1.6)), with: .color(Self.blue.opacity(0.65)))
        }
        let spacing: CGFloat = 20
        var x = -(scroll.truncatingRemainder(dividingBy: spacing))
        while x < Self.width {
            layer.fill(Path(roundedRect: rect(x, (Self.trackTop + Self.trackBottom) / 2 - 0.5, 8, 1), cornerRadius: 0.5 * scale),
                       with: .color(Self.cream.opacity(0.14)))
            x += spacing
        }
    }

    /// The course rocket (flame, fins, hull, collar, nose, window), nose along `heading`.
    private func rocket(x: CGFloat, y: CGFloat, heading: CGFloat, color: HouseRocketsColor, flame: CGFloat = 1,
                        isPlayer: Bool = false, effect: HouseRocketsSpeedEffect? = nil, opacity: Double = 1) {
        guard opacity > 0.01 else { return }
        var layer = context
        layer.opacity = opacity
        layer.translateBy(x: x * scale, y: y * scale)
        layer.rotate(by: .degrees(Double(heading)))
        // The artwork faces right with y up (SpriteKit); flip it into the canvas.
        layer.scaleBy(x: Self.rocketScale * scale, y: -Self.rocketScale * scale)
        let stroke = Self.cream
        if flame > 0 {
            var thrust = layer
            thrust.scaleBy(x: flame, y: 1)
            thrust.fill(Path(HouseRocketsArtwork.flame), with: .color(Self.cream))
            thrust.stroke(Path(HouseRocketsArtwork.flame), with: .color(Self.red), lineWidth: 1.8)
        }
        let tint = Color(HouseRocketsPalette.player(color))
        for (path, fill) in [(HouseRocketsArtwork.fins, tint), (HouseRocketsArtwork.hull, tint),
                             (HouseRocketsArtwork.collar, Self.burgundy), (HouseRocketsArtwork.nose, Self.red)] {
            layer.fill(Path(path), with: .color(fill))
            layer.stroke(Path(path), with: .color(stroke), lineWidth: 1.8)
        }
        layer.fill(Path(HouseRocketsArtwork.window), with: .color(Self.navy))
        layer.stroke(Path(HouseRocketsArtwork.window), with: .color(color == .mint ? Self.navy : stroke), lineWidth: 1.8)
        if isPlayer {
            layer.stroke(Path(ellipseIn: CGRect(x: -25, y: -25, width: 50, height: 50)),
                         with: .color(Self.cream.opacity(0.65)), lineWidth: 1.5)
        }
        if let effect {
            layer.stroke(Path(ellipseIn: CGRect(x: -29, y: -29, width: 58, height: 58)),
                         with: .color(effect == .boost ? Self.blue : Self.cream), lineWidth: 3)
        }
    }

    /// A speed field as the course draws it: blue with double chevrons, or red with brake bars.
    private func field(_ effect: HouseRocketsSpeedEffect, x: CGFloat, y: CGFloat, opacity: Double = 1) {
        guard opacity > 0.01, x > -Self.fieldRadius - 2, x < Self.width + Self.fieldRadius + 2 else { return }
        var layer = context
        layer.opacity = opacity
        let disc = circle(x, y, Self.fieldRadius)
        layer.fill(disc, with: .color(effect == .boost ? Self.blue : Self.red))
        layer.stroke(disc, with: .color(Self.cream), lineWidth: 1.1 * scale)
        var symbol = Path()
        if effect == .boost {
            for offset in [CGFloat(-3.4), 1.4] {
                symbol.move(to: point(x + offset - 1.6, y - 3.6))
                symbol.addLine(to: point(x + offset + 1.6, y))
                symbol.addLine(to: point(x + offset - 1.6, y + 3.6))
            }
        } else {
            for offset in [CGFloat(-2.4), 2.4] {
                symbol.move(to: point(x + offset, y - 4))
                symbol.addLine(to: point(x + offset, y + 4))
            }
        }
        layer.stroke(symbol, with: .color(effect == .boost ? Self.navy : Self.cream),
                     style: StrokeStyle(lineWidth: 1.6 * scale, lineCap: .round, lineJoin: .round))
    }

    /// The touch zones along both edges, where steering starts.
    private func edgeZones(opacity: Double) {
        guard opacity > 0.01 else { return }
        let width = Self.width * 0.3
        for x in [CGFloat(0), Self.width - width] {
            context.fill(Path(rect(x, Self.trackTop, width, Self.trackBottom - Self.trackTop)),
                         with: .color(Self.cream.opacity(0.07 * opacity)))
        }
    }

    /// The floating joystick under the finger: it appears where the touch starts and its
    /// knob leans the way the finger drags (`angle`, by `reach` of its 8-unit range).
    private func joystick(x: CGFloat, y: CGFloat, angle: CGFloat, reach: CGFloat, opacity: Double) {
        guard opacity > 0.01 else { return }
        var layer = context
        layer.opacity = 0.75 * opacity
        let base = circle(x, y, 13)
        layer.fill(base, with: .color(Self.blue.opacity(0.35)))
        layer.stroke(base, with: .color(Self.cream), lineWidth: 0.9 * scale)
        let radians = angle * .pi / 180
        let knobX = x + cos(radians) * 8 * reach, knobY = y + sin(radians) * 8 * reach
        layer.fill(circle(knobX, knobY, 5.4), with: .color(Self.cream))
        // The knob's arrow points where the rocket will fly.
        var arrow = Path()
        let tip = CGPoint(x: knobX + cos(radians) * 2.6, y: knobY + sin(radians) * 2.6)
        for side in [CGFloat(140), -140] {
            let wing = radians + side * .pi / 180
            arrow.move(to: point(tip.x + cos(wing) * 2.4, tip.y + sin(wing) * 2.4))
            arrow.addLine(to: point(tip.x, tip.y))
        }
        layer.stroke(arrow, with: .color(Self.navy), style: StrokeStyle(lineWidth: 1 * scale, lineCap: .round))
    }

    /// A ring spreading from a point: a touch landing, a field taken, a rocket out.
    private func ring(_ phase: Double, at time: Double, x: CGFloat, y: CGFloat, color: Color, from: CGFloat = 4,
                      reach: CGFloat = 10, duration: Double = 0.14) {
        let spread = Self.progress(phase, time, time + duration)
        guard phase >= time, spread < 1 else { return }
        context.stroke(circle(x, y, from + reach * spread), with: .color(color.opacity(Double(1 - spread))),
                       lineWidth: 1.3 * scale)
    }

    // MARK: Clips

    /// A finger on the left edge drags up, then down; the rocket turns to follow it, and
    /// the joystick disappears when the finger lifts.
    func drawSteer(_ phase: Double) {
        let touch = CGPoint(x: 24, y: 62)
        let heading: (Double) -> CGFloat = { phase in
            switch phase {
            case ..<0.18: return 0
            case ..<0.4: return -40 * Self.smooth(Self.progress(phase, 0.18, 0.4))
            case ..<0.48: return -40
            case ..<0.7: return -40 + 75 * Self.smooth(Self.progress(phase, 0.48, 0.7))
            case ..<0.78: return 35 - 35 * Self.smooth(Self.progress(phase, 0.7, 0.78))
            default: return 0
            }
        }
        let fade = Self.loopFade(phase)
        background(scroll: 140 * CGFloat(phase))
        edgeZones(opacity: fade)
        let drift = Self.drift(to: phase, speed: 70, heading: heading)
        rocket(x: 92, y: 45 + drift.y, heading: heading(phase), color: Self.player, flame: Self.flicker(phase),
               isPlayer: true, opacity: fade)
        let held = phase >= 0.18 && phase < 0.8
        if held {
            joystick(x: touch.x, y: touch.y, angle: heading(phase), reach: max(0.25, Self.progress(phase, 0.18, 0.24)),
                     opacity: fade)
        }
        ring(phase, at: 0.18, x: touch.x, y: touch.y, color: Self.cream, from: 3, reach: 9)
    }

    /// A short drag from the right edge sets a heading; after the finger lifts the rocket
    /// keeps flying that way with its thrust on.
    func drawThrust(_ phase: Double) {
        let touch = CGPoint(x: 136, y: 64)
        let aim: CGFloat = -28
        let heading: (Double) -> CGFloat = { phase in
            phase < 0.12 ? 0 : aim * Self.smooth(Self.progress(phase, 0.12, 0.3))
        }
        let fade = Self.loopFade(phase, out: 0.88)
        background(scroll: 40 * CGFloat(phase))
        let drift = Self.drift(to: phase, speed: 125, heading: heading)
        let x = 22 + drift.x, y = 60 + drift.y
        // After the release, the held heading runs ahead of the rocket as a dotted line.
        if phase >= 0.34 {
            let radians = aim * .pi / 180
            var guide = Path()
            var distance: CGFloat = 14
            while distance < 120 {
                let dot = CGPoint(x: x + cos(radians) * distance, y: y + sin(radians) * distance)
                guide.addEllipse(in: rect(dot.x - 0.7, dot.y - 0.7, 1.4, 1.4))
                distance += 5
            }
            var layer = context
            layer.opacity = fade * Double(Self.progress(phase, 0.34, 0.42))
            layer.fill(guide, with: .color(Self.cream.opacity(0.45)))
        }
        // Exhaust puffs left behind: the thrust never stops.
        for puff in 1...5 {
            let time = phase - Double(puff) * 0.05
            guard time > 0 else { continue }
            let back = Self.drift(to: time, speed: 125, heading: heading)
            var layer = context
            layer.opacity = fade * 0.35 * (1 - Double(puff) / 6)
            layer.fill(circle(22 + back.x - 5, 60 + back.y, 1.2 + CGFloat(puff) * 0.4), with: .color(Self.cream))
        }
        rocket(x: x, y: y, heading: heading(phase), color: Self.player, flame: Self.flicker(phase), isPlayer: true,
               opacity: fade)
        if phase >= 0.12, phase < 0.34 {
            joystick(x: touch.x, y: touch.y, angle: heading(phase), reach: max(0.25, Self.progress(phase, 0.12, 0.18)),
                     opacity: fade)
        }
        ring(phase, at: 0.12, x: touch.x, y: touch.y, color: Self.cream, from: 3, reach: 9)
    }

    /// The rocket crosses a blue field (the course rushes by, its flame grows) and then a
    /// red one (everything slows down).
    func drawFields(_ phase: Double) {
        let rocketX: CGFloat = 46, y: CGFloat = 45
        let boost = (start: 0.25, end: 0.5), slow = (start: 0.62, end: 0.85)
        let speed: CGFloat = 150
        func overlap(_ time: Double, _ window: (start: Double, end: Double)) -> CGFloat {
            CGFloat(max(0, min(time, window.end) - window.start))
        }
        func travelled(_ time: Double) -> CGFloat {
            speed * (CGFloat(time) + 0.45 * overlap(time, boost) - 0.35 * overlap(time, slow))
        }
        let distance = travelled(phase)
        let fade = Self.loopFade(phase)
        background(scroll: distance)
        let effect: HouseRocketsSpeedEffect? = (boost.start..<boost.end).contains(phase) ? .boost
            : (slow.start..<slow.end).contains(phase) ? .slow : nil
        field(.boost, x: rocketX + travelled(boost.start) - distance, y: y, opacity: fade)
        field(.slow, x: rocketX + travelled(slow.start) - distance, y: y, opacity: fade)
        if effect == .boost {
            // Speed lines streaming past the rocket.
            var lines = Path()
            for (index, offset) in [CGFloat(-7), 0, 7].enumerated() {
                let shift = (distance * 1.3 + CGFloat(index) * 17).truncatingRemainder(dividingBy: 40)
                lines.move(to: point(rocketX - 12 - shift, y + offset))
                lines.addLine(to: point(rocketX - 22 - shift, y + offset))
            }
            var layer = context
            layer.opacity = fade
            layer.stroke(lines, with: .color(Self.blue), style: StrokeStyle(lineWidth: 1 * scale, lineCap: .round))
        }
        let flame = (effect == .boost ? 1.7 : effect == .slow ? 0.65 : 1) * Self.flicker(phase)
        rocket(x: rocketX, y: y, heading: 0, color: Self.player, flame: flame, isPlayer: true, effect: effect,
               opacity: fade)
        ring(phase, at: boost.start, x: rocketX, y: y, color: Self.blue, from: 10, reach: 8)
        ring(phase, at: slow.start, x: rocketX, y: y, color: Self.red, from: 10, reach: 8)
    }

    /// A block holds the rival back while the player flies over it; the rival is not hurt,
    /// but it is pushed off the rear edge and is out. The last rocket flying wins.
    func drawSurvive(_ phase: Double) {
        let speed: CGFloat = 160
        let blockX = 150 - speed * CGFloat(phase)
        let block = (top: CGFloat(50), bottom: Self.trackBottom, width: CGFloat(14))
        let rivalY: CGFloat = 62
        let rivalFree: CGFloat = 84
        let rivalX = min(rivalFree, blockX - block.width / 2 - 9)
        let out = 0.81
        let fade = Self.loopFade(phase)
        background(scroll: speed * CGFloat(phase))
        // The rear edge: falling past it ends the flight.
        var edge = Path()
        edge.move(to: point(3, Self.trackTop))
        edge.addLine(to: point(3, Self.trackBottom))
        context.stroke(edge, with: .color(Self.red.opacity(0.85 * fade)),
                       style: StrokeStyle(lineWidth: 1.2 * scale, dash: [3 * scale, 2.5 * scale]))
        // The block, in the course's burgundy with a cream outline.
        var layer = context
        layer.opacity = fade
        let blockRect = Path(roundedRect: rect(blockX - block.width / 2, block.top, block.width, block.bottom - block.top),
                             cornerRadius: 1.5 * scale)
        layer.fill(blockRect, with: .color(Self.burgundy))
        layer.stroke(blockRect, with: .color(Self.cream), lineWidth: 0.9 * scale)

        let pressed = rivalX < rivalFree
        let contact = phase >= 0.3 && pressed
        if phase < out {
            rocket(x: rivalX, y: rivalY, heading: 0, color: Self.rival, flame: Self.flicker(phase), opacity: fade)
        }
        if contact {
            // Contact is harmless: a soft cream mark where the nose meets the block.
            context.fill(circle(rivalX + 9, rivalY, 1.6), with: .color(Self.cream.opacity(0.7 * fade)))
        }
        ring(phase, at: out, x: 6, y: rivalY, color: Self.red, from: 3, reach: 12, duration: 0.18)
        ring(phase, at: out + 0.02, x: 6, y: rivalY, color: Self.cream, from: 2, reach: 7, duration: 0.14)
        rocket(x: 96, y: 34 + 1.5 * CGFloat(sin(phase * 2 * .pi * 2)), heading: 0, color: Self.player,
               flame: Self.flicker(phase), isPlayer: true, opacity: fade)
        // The last rocket flying: its ring lights up once the rival is out.
        ring(phase, at: out + 0.04, x: 96, y: 34, color: Self.cream, from: 11, reach: 9, duration: 0.2)
    }
}
