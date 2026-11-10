import FausCrewCore
import SwiftUI

/// The lobby's How to play as tiny looping clips instead of paragraphs: each one plays a
/// three- to four-second moment of a match (a shot, a drive, a win, a crate, two jokers)
/// on a 160 × 90 top-down stage. Drawn with `Canvas` on a 30 fps timeline, so there are
/// no video files. With Reduce Motion each clip holds one telling frame. The clips are
/// decorative; the rule's sentence is still read out by VoiceOver. Android draws the same
/// clips from the same numbers (`HouseTanksRuleClips.kt`).
enum HouseTanksRuleClipKind: CaseIterable {
    case fire, drive, survive, crates, joker, shield

    /// Loop length in seconds.
    var period: Double {
        switch self {
        case .fire: return 3.2
        case .crates: return 3.8
        case .joker: return 4.0
        default: return 3.6
        }
    }

    /// The frame shown under Reduce Motion.
    var stillPhase: Double {
        switch self {
        case .fire: return 0.3
        case .drive: return 0.45
        case .survive: return 0.62
        case .crates: return 0.74
        case .joker: return 0.56
        case .shield: return 0.25
        }
    }

    var titleKey: String {
        switch self {
        case .fire: return "house_tanks_rule_fire"
        case .drive: return "house_tanks_rule_drive"
        case .survive: return "house_tanks_rule_survive"
        case .crates: return "house_tanks_rule_crates"
        case .joker: return "house_tanks_rule_jokers"
        case .shield: return "house_tanks_rule_joker_time"
        }
    }

    var detailKey: String { titleKey + "_detail" }
}

struct HouseTanksRuleClip: View {
    let kind: HouseTanksRuleClipKind
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30, paused: reduceMotion)) { timeline in
            let seconds = timeline.date.timeIntervalSinceReferenceDate
            let phase = reduceMotion ? kind.stillPhase : (seconds / kind.period).truncatingRemainder(dividingBy: 1)
            Canvas { context, size in
                let stage = HouseTanksClipStage(context: context, size: size)
                stage.background()
                switch kind {
                case .fire: stage.drawFire(phase)
                case .drive: stage.drawDrive(phase)
                case .survive: stage.drawSurvive(phase)
                case .crates: stage.drawCrates(phase)
                case .joker: stage.drawJoker(phase)
                case .shield: stage.drawShield(phase)
                }
            } symbols: {
                Image(systemName: "hand.tap.fill")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(HouseTanksMapPalette.steel)
                    .frame(width: 40, height: 40)
                    .tag(TanksClipSymbol.hand)
            }
        }
        .aspectRatio(16.0 / 9.0, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: AppDesign.CornerRadius.sm, style: .continuous)
            .stroke(HouseTanksFieldTheme.hairline, lineWidth: 1))
        .accessibilityHidden(true)
    }
}

private enum TanksClipSymbol: Hashable {
    case hand
}

/// Stage units: 160 wide, 90 high, origin top left, y down; angles in degrees, 0 = right,
/// clockwise. A tank is the arena artwork at 0.3 (hull 13 long, barrel tip 10 ahead of
/// its center).
private struct HouseTanksClipStage {
    let context: GraphicsContext
    let size: CGSize

    static let width: CGFloat = 160
    static let height: CGFloat = 90
    static let tankScale: CGFloat = 0.3
    static let barrelTip: CGFloat = 10

    private var scale: CGFloat { size.width / Self.width }
    private static let player = Color(uiColor: HouseTanksColor.blue.uiColor)
    private static let rival = Color(uiColor: HouseTanksColor.orange.uiColor)
    private static let crateWood = HouseTanksMapPalette.khaki

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

    private static func direction(_ degrees: CGFloat) -> CGVector {
        let radians = degrees * .pi / 180
        return CGVector(dx: cos(radians), dy: sin(radians))
    }

    /// Fades the whole clip out at its end and in at its start, hiding the loop's jump.
    private static func loopFade(_ phase: Double, out start: Double = 0.9) -> Double {
        if phase < 0.05 { return Double(progress(phase, 0, 0.05)) }
        return 1 - Double(progress(phase, start, 0.97))
    }

    // MARK: Pieces

    func background() {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(HouseTanksMapPalette.paper))
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(HouseTanksMapPalette.sand.opacity(0.5)))
        var grid = Path()
        var x: CGFloat = 16
        while x < Self.width {
            grid.move(to: point(x, 0))
            grid.addLine(to: point(x, Self.height))
            x += 16
        }
        var y: CGFloat = 15
        while y < Self.height {
            grid.move(to: point(0, y))
            grid.addLine(to: point(Self.width, y))
            y += 15
        }
        context.stroke(grid, with: .color(HouseTanksMapPalette.slate.opacity(0.14)), lineWidth: 0.6)
    }

    /// The arena tank artwork (aura, tracks, hull, turret, barrel), barrel along `angle`.
    private func tank(x: CGFloat, y: CGFloat, angle: CGFloat, color: Color, isPlayer: Bool = true,
                      isDestroyed: Bool = false, opacity: Double = 1) {
        guard opacity > 0.01 else { return }
        var layer = context
        layer.opacity = opacity
        layer.translateBy(x: x * scale, y: y * scale)
        layer.rotate(by: .degrees(Double(angle)))
        layer.scaleBy(x: Self.tankScale * scale, y: Self.tankScale * scale)
        let ink = HouseTanksMapPalette.ink
        let dead = Color(white: 0.12)
        let deadStroke = Color(white: 0.35)
        if !isDestroyed {
            let aura = Path(ellipseIn: CGRect(x: -36, y: -30, width: 72, height: 60))
            layer.fill(aura, with: .color(color.opacity(isPlayer ? 0.18 : 0.07)))
            layer.stroke(aura, with: .color(color.opacity(isPlayer ? 0.72 : 0.26)), lineWidth: isPlayer ? 3 : 1.5)
        }
        for trackY in [CGFloat(-22), 12] {
            let track = Path(roundedRect: CGRect(x: -19, y: trackY, width: 38, height: 10), cornerRadius: 5)
            layer.fill(track, with: .color(isDestroyed ? dead : ink))
            layer.stroke(track, with: .color(isDestroyed ? deadStroke : HouseTanksMapPalette.paper.opacity(0.25)), lineWidth: 1)
        }
        let hull = Path(roundedRect: CGRect(x: -22, y: -15, width: 44, height: 30), cornerRadius: 9)
        layer.fill(hull, with: .color(isDestroyed ? dead : color))
        layer.stroke(hull, with: .color(isDestroyed ? deadStroke : ink), lineWidth: 2.5)
        let turret = Path(ellipseIn: CGRect(x: -10, y: -10, width: 20, height: 20))
        layer.fill(turret, with: .color(isDestroyed ? dead : color))
        layer.fill(turret, with: .color(Color.black.opacity(isDestroyed ? 0 : 0.1)))
        layer.stroke(turret, with: .color(isDestroyed ? deadStroke : ink), lineWidth: 2)
        let barrel = Path(roundedRect: CGRect(x: 2.5, y: -4, width: 31, height: 8), cornerRadius: 4)
        layer.fill(barrel, with: .color(isDestroyed ? Color(white: 0.18) : color))
        layer.fill(barrel, with: .color(Color.black.opacity(isDestroyed ? 0 : 0.16)))
        layer.stroke(barrel, with: .color(isDestroyed ? deadStroke : ink), lineWidth: 1.5)
    }

    /// Where a tank at (x, y) facing `angle` fires from.
    private static func muzzle(_ x: CGFloat, _ y: CGFloat, _ angle: CGFloat) -> CGPoint {
        let direction = direction(angle)
        return CGPoint(x: x + direction.dx * barrelTip, y: y + direction.dy * barrelTip)
    }

    /// A shell fired at `time` from `origin` along `angle` at `speed` (units per loop).
    /// Returns its position, or nil before it is fired, after `until`, or off the stage.
    private static func shellPosition(_ phase: Double, time: Double, origin: CGPoint, angle: CGFloat, speed: CGFloat,
                                      until: Double = 1) -> CGPoint? {
        guard phase >= time, phase < until else { return nil }
        let travel = speed * CGFloat(phase - time)
        let direction = direction(angle)
        let position = CGPoint(x: origin.x + direction.dx * travel, y: origin.y + direction.dy * travel)
        guard position.x > -6, position.x < width + 6, position.y > -6, position.y < height + 6 else { return nil }
        return position
    }

    private func shell(_ position: CGPoint, angle: CGFloat, color: Color) {
        var layer = context
        layer.translateBy(x: position.x * scale, y: position.y * scale)
        layer.rotate(by: .degrees(Double(angle)))
        let body = Path(roundedRect: CGRect(x: -2.7 * scale, y: -1.05 * scale, width: 5.4 * scale, height: 2.1 * scale),
                        cornerRadius: 1.05 * scale)
        layer.fill(body, with: .color(color))
        layer.stroke(body, with: .color(HouseTanksMapPalette.ink), lineWidth: 0.5 * scale)
    }

    private func muzzleFlash(_ phase: Double, at time: Double, origin: CGPoint) {
        let flash = Self.progress(phase, time, time + 0.05)
        guard phase >= time, flash < 1 else { return }
        context.fill(circle(origin.x, origin.y, 2.5 + 2 * flash),
                     with: .color(HouseTanksMapPalette.khaki.opacity(Double(1 - flash))))
    }

    /// A ring spreading from a point: a tap on the tank, a hit or a pickup.
    private func ring(_ phase: Double, at time: Double, x: CGFloat, y: CGFloat, color: Color, from: CGFloat = 4,
                      reach: CGFloat = 11, duration: Double = 0.16) {
        let spread = Self.progress(phase, time, time + duration)
        guard phase >= time, spread < 1 else { return }
        context.stroke(circle(x, y, from + reach * spread), with: .color(color.opacity(Double(1 - spread))),
                       lineWidth: 1.4 * scale)
    }

    /// The finger in the corner: it lights up on each tap and stays lit while held.
    private func hand(_ phase: Double, taps: [Double] = [], holds: [ClosedRange<Double>] = []) {
        guard let resolved = context.resolveSymbol(id: TanksClipSymbol.hand) else { return }
        let tapGlow = taps.map { max(0, 1 - abs(phase - $0) / 0.07) }.max() ?? 0
        let held = holds.contains { $0.contains(phase) }
        let glow = held ? 1 : tapGlow
        var layer = context
        layer.opacity = 0.35 + 0.65 * glow
        let side = 15 + 3 * CGFloat(glow)
        layer.draw(resolved, in: rect(Self.width - side - 6, Self.height - side - 5, side, side))
    }

    private func crate(x: CGFloat, y: CGFloat, side: CGFloat = 14, opacity: Double = 1) {
        guard opacity > 0.01 else { return }
        var layer = context
        layer.opacity = opacity
        let frame = rect(x - side / 2, y - side / 2, side, side)
        let box = Path(roundedRect: frame, cornerRadius: 1.4 * scale)
        layer.fill(box, with: .color(Self.crateWood))
        layer.stroke(box, with: .color(HouseTanksMapPalette.ink.opacity(0.55)), lineWidth: 0.7 * scale)
        var cross = Path()
        let inset = side * 0.23
        cross.move(to: point(x - side / 2 + inset, y - side / 2 + inset))
        cross.addLine(to: point(x + side / 2 - inset, y + side / 2 - inset))
        cross.move(to: point(x - side / 2 + inset, y + side / 2 - inset))
        cross.addLine(to: point(x + side / 2 - inset, y - side / 2 + inset))
        layer.stroke(cross, with: .color(.white.opacity(0.35)), style: StrokeStyle(lineWidth: 1 * scale, lineCap: .round))
    }

    /// A crate breaking: four planks flying apart and fading.
    private func splinters(_ phase: Double, at time: Double, x: CGFloat, y: CGFloat) {
        let spread = Self.progress(phase, time, time + 0.16)
        guard phase >= time, spread < 1 else { return }
        for (index, angle) in [CGFloat(-135), -45, 45, 135].enumerated() {
            let direction = Self.direction(angle + CGFloat(index) * 9)
            let distance = 3 + 13 * spread
            var layer = context
            layer.opacity = Double(1 - spread)
            layer.translateBy(x: (x + direction.dx * distance) * scale, y: (y + direction.dy * distance) * scale)
            layer.rotate(by: .degrees(Double(angle + 160 * spread)))
            layer.fill(Path(roundedRect: CGRect(x: -3.5 * scale, y: -1.2 * scale, width: 7 * scale, height: 2.4 * scale),
                            cornerRadius: 0.6 * scale), with: .color(Self.crateWood))
        }
    }

    /// A tank going up: a hot ring and a dark puff.
    private func explosion(_ phase: Double, at time: Double, x: CGFloat, y: CGFloat) {
        let spread = Self.progress(phase, time, time + 0.18)
        guard phase >= time, spread < 1 else { return }
        context.fill(circle(x, y, 6 + 10 * spread), with: .color(HouseTanksMapPalette.ink.opacity(0.35 * Double(1 - spread))))
        context.stroke(circle(x, y, 5 + 14 * spread), with: .color(HouseTanksMapPalette.rust.opacity(Double(1 - spread))),
                       lineWidth: 2 * scale)
    }

    private func jokerGlyph(_ kind: HouseTanksPowerUp, x: CGFloat, y: CGFloat, side: CGFloat) {
        guard let glyph = kind.glyph(pointSize: 18) else { return }
        var image = context.resolve(Image(uiImage: glyph).renderingMode(.template))
        image.shading = .color(HouseTanksMapPalette.paper)
        context.draw(image, in: rect(x - side / 2, y - side / 2, side, side))
    }

    /// The arena token: a tinted disc with the joker's glyph and its timer ring.
    private func token(_ kind: HouseTanksPowerUp, x: CGFloat, y: CGFloat, pulse: Double, timer: CGFloat, opacity: Double) {
        guard opacity > 0.01 else { return }
        var layer = context
        layer.opacity = opacity
        let radius = 6 + 0.6 * CGFloat(sin(pulse * 2 * .pi * 3))
        let tint = Color(uiColor: kind.tint)
        layer.fill(circle(x, y, radius), with: .color(tint))
        layer.stroke(circle(x, y, radius), with: .color(HouseTanksMapPalette.paper), lineWidth: 1 * scale)
        var arc = Path()
        arc.addArc(center: point(x, y), radius: (radius + 2.2) * scale, startAngle: .degrees(-90),
                   endAngle: .degrees(-90 + 360 * Double(timer)), clockwise: false)
        layer.stroke(arc, with: .color(tint.opacity(0.8)), style: StrokeStyle(lineWidth: 1.1 * scale, lineCap: .round))
        HouseTanksClipStage(context: layer, size: size).jokerGlyph(kind, x: x, y: y, side: 7)
    }

    /// The joker badge over a tank, with the time it has left as a ring.
    private func badge(_ kind: HouseTanksPowerUp, tankX: CGFloat, tankY: CGFloat, left: CGFloat, opacity: Double) {
        guard opacity > 0.01 else { return }
        var layer = context
        layer.opacity = opacity
        let x = tankX + 9, y = tankY - 11
        let tint = Color(uiColor: kind.tint)
        layer.fill(circle(x, y, 4.6), with: .color(tint))
        layer.stroke(circle(x, y, 4.6), with: .color(HouseTanksMapPalette.paper), lineWidth: 0.8 * scale)
        var arc = Path()
        arc.addArc(center: point(x, y), radius: 6.3 * scale, startAngle: .degrees(-90),
                   endAngle: .degrees(-90 + 360 * Double(max(0, left))), clockwise: false)
        layer.stroke(arc, with: .color(tint), style: StrokeStyle(lineWidth: 1 * scale, lineCap: .round))
        HouseTanksClipStage(context: layer, size: size).jokerGlyph(kind, x: x, y: y, side: 5.4)
    }

    // MARK: Clips

    /// The tank turns on its own; each tap fires along the barrel.
    func drawFire(_ phase: Double) {
        let x: CGFloat = 48, y: CGFloat = 45
        let angle: (Double) -> CGFloat = { -90 + 360 * CGFloat($0) }
        for time in [0.22, 0.62] {
            let origin = Self.muzzle(x, y, angle(time))
            if let position = Self.shellPosition(phase, time: time, origin: origin, angle: angle(time), speed: 380) {
                shell(position, angle: angle(time), color: Self.player)
            }
        }
        tank(x: x, y: y, angle: angle(phase), color: Self.player)
        for time in [0.22, 0.62] {
            muzzleFlash(phase, at: time, origin: Self.muzzle(x, y, angle(time)))
            ring(phase, at: time, x: x, y: y, color: HouseTanksMapPalette.steel, from: 9, reach: 8)
        }
        hand(phase, taps: [0.22, 0.62])
    }

    /// Pressing locks the aim; holding drives along the barrel; letting go turns again.
    func drawDrive(_ phase: Double) {
        let start = CGPoint(x: 30, y: 52)
        let aim: CGFloat = -20
        let drive = Self.progress(phase, 0.2, 0.62)
        let direction = Self.direction(aim)
        let x = start.x + direction.dx * 95 * drive
        let y = start.y + direction.dy * 95 * drive
        let angle: CGFloat
        switch phase {
        case ..<0.2: angle = -110 + 90 * Self.progress(phase, 0, 0.2)
        case ..<0.62: angle = aim
        default: angle = aim + 90 * Self.progress(phase, 0.62, 0.9)
        }
        let fade = Self.loopFade(phase)
        // Track marks behind the tank.
        if drive > 0 {
            var marks = Path()
            let normal = CGVector(dx: -direction.dy, dy: direction.dx)
            var step: CGFloat = 0
            while step < 95 * drive - 6 {
                for side in [CGFloat(-4.2), 4.2] {
                    let from = CGPoint(x: start.x + direction.dx * step + normal.dx * side,
                                       y: start.y + direction.dy * step + normal.dy * side)
                    marks.move(to: point(from.x, from.y))
                    marks.addLine(to: point(from.x + direction.dx * 2.4, from.y + direction.dy * 2.4))
                }
                step += 4.5
            }
            var layer = context
            layer.opacity = fade
            layer.stroke(marks, with: .color(HouseTanksMapPalette.umber.opacity(0.35)), lineWidth: 1.1 * scale)
        }
        tank(x: x, y: y, angle: angle, color: Self.player, opacity: fade)
        if (0.2...0.62).contains(phase) {
            // A held press: a steady ring that breathes.
            let breathe = 0.5 + 0.5 * sin(phase * 2 * .pi * 6)
            context.stroke(circle(x, y, 10 + CGFloat(breathe)), with: .color(HouseTanksMapPalette.steel.opacity(0.55)),
                           lineWidth: 1.2 * scale)
        }
        hand(phase, holds: [0.2...0.62])
    }

    /// Two hits finish the rival's last armor; the round, and the third win, are yours.
    func drawSurvive(_ phase: Double) {
        let player = CGPoint(x: 34, y: 48), rival = CGPoint(x: 126, y: 48)
        let shots = [0.18, 0.43]
        let speed: CGFloat = 625
        let origin = Self.muzzle(player.x, player.y, 0)
        let hitTimes = shots.map { $0 + Double((rival.x - 8 - origin.x) / speed) }
        for (shot, hit) in zip(shots, hitTimes) {
            if let position = Self.shellPosition(phase, time: shot, origin: origin, angle: 0, speed: speed, until: hit) {
                shell(position, angle: 0, color: Self.player)
            }
        }
        let fade = Self.loopFade(phase)
        let destroyed = phase >= hitTimes[1]
        let flicker = hitTimes.contains { phase >= $0 && phase < $0 + 0.05 } ? 0.45 : 1
        tank(x: rival.x, y: rival.y, angle: 180, color: Self.rival, isPlayer: false, isDestroyed: destroyed,
             opacity: fade * flicker)
        tank(x: player.x, y: player.y, angle: 0, color: Self.player, opacity: fade)
        for shot in shots { muzzleFlash(phase, at: shot, origin: origin) }
        ring(phase, at: hitTimes[0], x: rival.x - 6, y: rival.y, color: HouseTanksMapPalette.rust, from: 2, reach: 7)
        explosion(phase, at: hitTimes[1], x: rival.x, y: rival.y)

        // The rival's armor: five pips, two left.
        let armor = phase < hitTimes[0] ? 2 : (phase < hitTimes[1] ? 1 : 0)
        for index in 0..<5 {
            let lit = index < armor
            let frame = rect(rival.x - 11 + CGFloat(index) * 4.6, rival.y - 17, 3.6, 2.2)
            var layer = context
            layer.opacity = fade
            layer.fill(Path(roundedRect: frame, cornerRadius: 0.6 * scale),
                       with: .color(lit ? HouseTanksMapPalette.rust : HouseTanksMapPalette.slate.opacity(0.3)))
        }
        // Rounds: two won, the third lands when the rival goes up.
        let winAt = hitTimes[1] + 0.1
        for index in 0..<3 {
            let center = CGPoint(x: Self.width / 2 - 9 + CGFloat(index) * 9, y: 9)
            let won = index < 2 || phase >= winAt
            let pop: CGFloat = index == 2 && phase >= winAt ? 1 + 0.5 * (1 - Self.progress(phase, winAt, winAt + 0.08)) : 1
            var layer = context
            layer.opacity = fade
            layer.fill(circle(center.x, center.y, 2.8 * pop),
                       with: .color(won ? Self.player : HouseTanksMapPalette.slate.opacity(0.25)))
            layer.stroke(circle(center.x, center.y, 2.8 * pop), with: .color(HouseTanksMapPalette.ink.opacity(0.5)),
                         lineWidth: 0.6 * scale)
        }
        hand(phase, taps: shots)
    }

    /// Driving pushes a crate along; one shell breaks another.
    func drawCrates(_ phase: Double) {
        let y: CGFloat = 60
        let drive = Self.progress(phase, 0.05, 0.4)
        let x = 18 + 44 * drive
        let pushed = max(46, x + 14)
        let aim: CGFloat = -40 * Self.smooth(Self.progress(phase, 0.45, 0.58))
        let fired = 0.6
        let origin = Self.muzzle(62, y, -40)
        let target = CGPoint(x: origin.x + Self.direction(-40).dx * 55, y: origin.y + Self.direction(-40).dy * 55)
        let speed: CGFloat = 570
        let hit = fired + Double(48 / speed)
        let fade = Self.loopFade(phase, out: 0.88)
        crate(x: pushed, y: y, opacity: fade)
        if phase < hit {
            crate(x: target.x, y: target.y, opacity: Double(Self.progress(phase, 0, 0.06)))
        }
        if let position = Self.shellPosition(phase, time: fired, origin: origin, angle: -40, speed: speed, until: hit) {
            shell(position, angle: -40, color: Self.player)
        }
        tank(x: x, y: y, angle: aim, color: Self.player, opacity: fade)
        muzzleFlash(phase, at: fired, origin: origin)
        splinters(phase, at: hit, x: target.x, y: target.y)
        hand(phase, taps: [fired], holds: [0.05...0.4])
    }

    /// Driving over a token takes its joker; a spread shot then fans out five shells.
    func drawJoker(_ phase: Double) {
        let y: CGFloat = 46
        let tokenX: CGFloat = 76
        let taken = 0.32
        let x = 22 + (tokenX - 22) * Self.progress(phase, 0.05, taken)
        let fade = Self.loopFade(phase)
        if phase < taken {
            token(.spreadShot, x: tokenX, y: y, pulse: phase, timer: 0.8 - 0.25 * CGFloat(phase),
                  opacity: Double(Self.progress(phase, 0, 0.05)))
        }
        for time in [0.5, 0.72] {
            let origin = Self.muzzle(x, y, 0)
            for spread in [CGFloat(-24), -12, 0, 12, 24] {
                if let position = Self.shellPosition(phase, time: time, origin: origin, angle: spread, speed: 420) {
                    shell(position, angle: spread, color: Self.player)
                }
            }
        }
        tank(x: x, y: y, angle: 0, color: Self.player, opacity: fade)
        for time in [0.5, 0.72] { muzzleFlash(phase, at: time, origin: Self.muzzle(x, y, 0)) }
        ring(phase, at: taken, x: tokenX, y: y, color: Color(uiColor: HouseTanksPowerUp.spreadShot.tint), from: 6, reach: 10,
             duration: 0.12)
        if phase >= taken {
            badge(.spreadShot, tankX: x, tankY: y, left: 1 - 0.55 * Self.progress(phase, taken, 1),
                  opacity: fade * Double(Self.progress(phase, taken, taken + 0.04)))
        }
        hand(phase, taps: [0.5, 0.72], holds: [0.05...taken])
    }

    /// A shield joker stops the rival's shells until its time runs out.
    func drawShield(_ phase: Double) {
        let player = CGPoint(x: 40, y: 48), rival = CGPoint(x: 128, y: 48)
        let shots = [0.12, 0.42]
        let speed: CGFloat = 540
        let bubble: CGFloat = 13
        let origin = Self.muzzle(rival.x, rival.y, 180)
        let impacts = shots.map { $0 + Double((origin.x - (player.x + bubble)) / speed) }
        let expires = 0.8
        let shieldOpacity = Double(Self.progress(phase, 0, 0.06)) * (1 - Double(Self.progress(phase, expires, expires + 0.08)))
        let fade = Self.loopFade(phase)
        for (shot, impact) in zip(shots, impacts) {
            if let position = Self.shellPosition(phase, time: shot, origin: origin, angle: 180, speed: speed, until: impact) {
                shell(position, angle: 180, color: Self.rival)
            }
        }
        tank(x: rival.x, y: rival.y, angle: 180, color: Self.rival, isPlayer: false, opacity: fade)
        tank(x: player.x, y: player.y, angle: 0, color: Self.player, opacity: fade)
        if shieldOpacity > 0.01 {
            let flash = impacts.map { max(0, 1 - abs(phase - $0) / 0.06) }.max() ?? 0
            let steel = HouseTanksMapPalette.steel
            context.fill(circle(player.x, player.y, bubble),
                         with: .color(steel.opacity((0.14 + 0.2 * Double(flash)) * shieldOpacity)))
            context.stroke(circle(player.x, player.y, bubble), with: .color(steel.opacity(0.75 * shieldOpacity)),
                           lineWidth: (1.2 + 0.8 * CGFloat(flash)) * scale)
        }
        for (shot, impact) in zip(shots, impacts) {
            muzzleFlash(phase, at: shot, origin: origin)
            ring(phase, at: impact, x: player.x + bubble, y: player.y, color: HouseTanksMapPalette.steel, from: 1.5, reach: 6,
                 duration: 0.1)
        }
        badge(.shield, tankX: player.x, tankY: player.y, left: 1 - CGFloat(phase / expires),
              opacity: shieldOpacity * fade)
    }
}
