import FausCrewCore
import SpriteKit
import UIKit

/// Draws one Faus Switch frame: the course is static world geometry, the start
/// platforms follow the frame's robots (one per seat), the robots come from
/// `FausSwitchRenderFrame`; portals pulse with the race clock. Everything is drawn in track coordinates: each straight
/// section is a rotated copy placed where `FausSwitchTrack` puts it, the bends are drawn
/// as curved rails, and robots are posed (position and facing) through the track. The scene never simulates; demo and
/// online both hand it frames through `frameProvider`, called once per display frame
/// with the seconds since the previous one.
final class FausSwitchScene: SKScene {
    var frameProvider: ((TimeInterval) -> FausSwitchRenderFrame?)?
    /// A tap anywhere on the playfield.
    var onTap: (() -> Void)?
    var reduceMotion = false

    private let course = FausSwitchCourse.standard
    private let backdrop = SKNode()
    private let world = SKNode()
    private var backdropTiles: [(tile: SKSpriteNode, column: Int, row: Int)] = []
    private var backdropTileSize = CGSize(width: 1, height: 1)
    /// One node per straight section, in that section's track coordinates.
    private var sections: [SKNode] = []
    private var sectionRanges: [(startX: Double, endX: Double)] = []
    /// Each portal's swirl, pulsing with the race clock.
    private var portalGlows: [(x: Double, node: SKNode)] = []
    private var robots: [String: FausSwitchRobotNode] = [:]
    private let platforms = SKNode()
    /// Dims the band behind the "left behind" line. On straights it is just off screen;
    /// in a bend the line crosses the screen, so the zone that eliminates is visible.
    private let lostZone = SKShapeNode()
    private let lostLine = SKShapeNode()
    private var lostZoneTrail = -Double.infinity
    /// Robot colors by seat that the start platforms were drawn for.
    private var platformColors: [FausSwitchColor] = []
    private var viewport = FausSwitchViewport(screenWidth: 844, screenHeight: 390)
    private var lastUpdate: TimeInterval?
    private var isBuilt = false

    /// Rail colors per straight section (the bend before a section takes its colors):
    /// teal on the first run, deep wine on the climb, wine on the leftward run.
    private struct RailStyle {
        let fill: UIColor
        let surface: UIColor
    }

    private static let railStyles = [
        RailStyle(fill: FausSwitchPalette.UI.teal, surface: FausSwitchPalette.UI.green),
        RailStyle(fill: FausSwitchPalette.UI.deepWine, surface: FausSwitchPalette.UI.lavender),
        RailStyle(fill: FausSwitchPalette.UI.wine, surface: FausSwitchPalette.UI.lime),
    ]

    private static func railStyle(_ section: Int) -> RailStyle { railStyles[section % railStyles.count] }

    /// Obstacle colors, one per group (blocks less than 200 apart), in turn along the
    /// course, so a group reads as one piece and neighboring groups differ.
    private struct BlockStyle {
        let fill: UIColor
        let edge: UIColor
        let panel: UIColor
        let bolt: UIColor
    }

    private static let blockStyles = [
        BlockStyle(fill: FausSwitchPalette.UI.teal, edge: FausSwitchPalette.UI.green,
                   panel: FausSwitchPalette.UI.green, bolt: FausSwitchPalette.UI.lime),
        BlockStyle(fill: FausSwitchPalette.UI.wine, edge: FausSwitchPalette.UI.lavender,
                   panel: FausSwitchPalette.UI.lavender, bolt: FausSwitchPalette.UI.sand),
        BlockStyle(fill: FausSwitchPalette.UI.lavender, edge: FausSwitchPalette.UI.deepWine,
                   panel: FausSwitchPalette.UI.deepWine, bolt: FausSwitchPalette.UI.plum),
        BlockStyle(fill: FausSwitchPalette.UI.deepWine, edge: FausSwitchPalette.UI.sand,
                   panel: FausSwitchPalette.UI.sand, bolt: FausSwitchPalette.UI.lime),
    ]


    override init() {
        super.init(size: CGSize(width: FausSwitchMetrics.viewportWidth, height: FausSwitchMetrics.worldHeight))
        scaleMode = .resizeFill
        backgroundColor = FausSwitchPalette.UI.mint
        anchorPoint = .zero
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        view.isMultipleTouchEnabled = false
        buildIfNeeded()
        layoutForSize()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard isBuilt else { return }
        layoutForSize()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        onTap?()
    }

    override func update(_ currentTime: TimeInterval) {
        let elapsed = lastUpdate.map { min(max(currentTime - $0, 0), 0.1) } ?? 0
        lastUpdate = currentTime
        guard let frame = frameProvider?(elapsed) else { return }
        render(frame)
    }

    /// Clears the robots of a previous match; the course stays.
    func reset() {
        robots.values.forEach { $0.removeFromParent() }
        robots.removeAll()
        lastUpdate = nil
    }

    // MARK: - Frame

    func render(_ frame: FausSwitchRenderFrame) {
        buildIfNeeded()
        let camera = FausSwitchCamera.view(focus: frame.cameraFocus, track: course.track, viewport: viewport)
        let origin = camera.worldOrigin
        world.position = CGPoint(x: origin.x, y: origin.y)
        world.setScale(CGFloat(camera.scale))
        let focusPoint = course.track.pose(x: frame.cameraFocus, y: FausSwitchTrack.centerY)
        scrollBackdrop(focusX: focusPoint.x, focusY: focusPoint.y)
        layoutLostZone(trail: frame.cameraTrail)

        let time = frame.elapsedSeconds
        let visibleMin = frame.cameraTrail - 100
        let visibleMax = frame.cameraFocus + viewport.visibleWorldWidth
        for (index, portal) in portalGlows.enumerated() where portal.x >= visibleMin && portal.x <= visibleMax {
            portal.node.alpha = reduceMotion ? 0.75 : CGFloat(0.6 + 0.3 * sin(time * 4 + Double(index)))
        }

        layoutPlatforms(for: frame.runners)
        var seen = Set<String>()
        for runner in frame.runners {
            seen.insert(runner.id)
            let robot = robots[runner.id] ?? makeRobot(for: runner)
            let pose = course.track.pose(x: runner.state.x, y: runner.state.y)
            robot.update(runner, pose: pose, tick: frame.tick, phase: frame.phase, reduceMotion: reduceMotion)
            let lostBehind = !runner.state.isRunning && runner.state.x < frame.cameraTrail - 40
            robot.isHidden = lostBehind
        }
        for (id, robot) in robots where !seen.contains(id) {
            robot.removeFromParent()
            robots[id] = nil
        }
    }

    /// The band from the trail back 900 units, traced through the track (bends included).
    private func layoutLostZone(trail: Double) {
        guard abs(trail - lostZoneTrail) > 0.25 else { return }
        lostZoneTrail = trail
        let start = trail - 900
        let steps = 45
        let path = CGMutablePath()
        for index in 0...steps {
            let pose = course.track.pose(x: start + 900 * Double(index) / Double(steps), y: 0)
            let point = CGPoint(x: pose.x, y: pose.y)
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        for index in (0...steps).reversed() {
            let pose = course.track.pose(x: start + 900 * Double(index) / Double(steps), y: FausSwitchMetrics.worldHeight)
            path.addLine(to: CGPoint(x: pose.x, y: pose.y))
        }
        path.closeSubpath()
        lostZone.path = path
        let line = CGMutablePath()
        let low = course.track.pose(x: trail, y: 0)
        let high = course.track.pose(x: trail, y: FausSwitchMetrics.worldHeight)
        line.move(to: CGPoint(x: low.x, y: low.y))
        line.addLine(to: CGPoint(x: high.x, y: high.y))
        lostLine.path = line
    }

    private func makeRobot(for runner: FausSwitchRenderRunner) -> FausSwitchRobotNode {
        let robot = FausSwitchRobotNode(color: runner.color.uiColor, isLocal: runner.isLocal)
        robot.zPosition = runner.isLocal ? 12 : 10
        world.addChild(robot)
        robots[runner.id] = robot
        return robot
    }

    // MARK: - Layout

    private func layoutForSize() {
        viewport = FausSwitchViewport(screenWidth: Double(size.width), screenHeight: Double(size.height))
        layoutBackdrop()
    }

    /// The texture fills the screen height and repeats mirrored in both directions, so
    /// tile seams meet whichever way the course runs.
    private func layoutBackdrop() {
        backdropTiles.forEach { $0.tile.removeFromParent() }
        backdropTiles.removeAll()
        let texture = SKTexture(imageNamed: "FausSwitchTexture")
        let textureSize = texture.size()
        guard textureSize.width > 0, textureSize.height > 0, size.height > 0 else { return }
        let height = size.height
        backdropTileSize = CGSize(width: height * textureSize.width / textureSize.height, height: height)
        let columns = Int(ceil(size.width / backdropTileSize.width)) + 3
        for column in 0..<columns {
            for row in 0..<4 {
                let tile = SKSpriteNode(texture: texture, size: backdropTileSize)
                tile.xScale = column.isMultiple(of: 2) ? 1 : -1
                tile.yScale = row.isMultiple(of: 2) ? 1 : -1
                backdrop.addChild(tile)
                backdropTiles.append((tile, column, row))
            }
        }
        scrollBackdrop(focusX: 0, focusY: 0)
    }

    /// Parallax at 28 % of the camera's travel, along both axes.
    private func scrollBackdrop(focusX: Double, focusY: Double) {
        guard !backdropTiles.isEmpty else { return }
        let factor = reduceMotion ? 0 : CGFloat(viewport.scale) * 0.28
        let width = backdropTileSize.width
        let height = backdropTileSize.height
        let offsetX = -(CGFloat(focusX) * factor).truncatingRemainder(dividingBy: width * 2)
        let offsetY = -(CGFloat(focusY) * factor).truncatingRemainder(dividingBy: height * 2)
        // Keep both offsets in (-2·size, 0] so the grid always covers the screen.
        let x0 = offsetX > 0 ? offsetX - width * 2 : offsetX
        let y0 = offsetY > 0 ? offsetY - height * 2 : offsetY
        for entry in backdropTiles {
            entry.tile.position = CGPoint(x: x0 + CGFloat(entry.column) * width + width / 2,
                                          y: y0 + CGFloat(entry.row) * height + height / 2)
        }
    }

    // MARK: - Course

    private func buildIfNeeded() {
        guard !isBuilt else { return }
        isBuilt = true
        let groups = course.blockGroups()
        backdrop.zPosition = -20
        addChild(backdrop)
        world.zPosition = 0
        addChild(world)

        for (index, range) in course.track.straightRanges(length: course.length).enumerated() {
            let container = SKNode()
            container.position = CGPoint(x: range.pose.x, y: range.pose.y)
            container.zRotation = CGFloat(range.pose.angle)
            let section = SKNode()
            section.position = CGPoint(x: -course.track.straightStartX(index), y: -FausSwitchTrack.centerY)
            container.addChild(section)
            world.addChild(container)
            sections.append(section)
            sectionRanges.append((range.startX, range.endX))
        }
        for solid in course.solids {
            if solid.kind == .rail {
                // Rails run through the bends: each straight draws its own part.
                for (index, range) in sectionRanges.enumerated() {
                    let minX = max(solid.rect.minX, range.startX)
                    let maxX = min(solid.rect.maxX, range.endX)
                    guard maxX > minX else { continue }
                    var rect = solid.rect
                    rect.minX = minX
                    rect.maxX = maxX
                    sections[index].addChild(railNode(rect, style: Self.railStyle(index)))
                }
            } else {
                // A group never takes its section's rail color, so floor blocks stand out.
                let section = sectionIndex(at: solid.rect.midX)
                let group = groups[solid.id] ?? 0
                var style = Self.blockStyles[group % Self.blockStyles.count]
                if style.fill == Self.railStyle(section).fill {
                    style = Self.blockStyles[(group + 1) % Self.blockStyles.count]
                }
                sections[section].addChild(blockNode(solid.rect, style: style))
            }
        }
        for index in course.track.turns.indices { world.addChild(turnNode(index)) }
        for gap in course.gaps { section(at: (gap.minX + gap.maxX) / 2).addChild(gapNode(gap)) }
        for pad in course.boosts { section(at: pad.x).addChild(boostNode(pad)) }
        for pad in course.slows { section(at: pad.x).addChild(slowNode(pad)) }
        for portal in course.portals {
            section(at: portal.x).addChild(portalNode(portal))
            section(at: portal.exitX).addChild(portalExitNode(portal))
        }
        section(at: course.finishX).addChild(finishNode())
        platforms.zPosition = 1
        section(at: FausSwitchMetrics.spawnX).addChild(platforms)
        lostZone.fillColor = FausSwitchPalette.UI.plum.withAlphaComponent(0.22)
        lostZone.strokeColor = .clear
        lostLine.strokeColor = FausSwitchPalette.UI.berry.withAlphaComponent(0.6)
        lostLine.lineWidth = 3
        // Above the course, below the robots (eliminated ones fade on top of it).
        lostZone.zPosition = 8
        lostLine.zPosition = 8
        world.addChild(lostZone)
        world.addChild(lostLine)
    }

    /// The straight section that draws track x `x` (a bend belongs to the one before it).
    private func section(at x: Double) -> SKNode { sections[sectionIndex(at: x)] }

    private func sectionIndex(at x: Double) -> Int {
        sectionRanges.firstIndex { x < $0.endX } ?? sectionRanges.count - 1
    }

    /// A bend: both rails as curved bands with their running-surface lines.
    private func turnNode(_ index: Int) -> SKNode {
        let node = SKNode()
        let style = Self.railStyle(index + 1)
        let turn = course.track.turns[index]
        let arc = course.track.turnArc(index)
        let center = CGPoint(x: arc.centerX, y: arc.centerY)
        let start = CGFloat(arc.startAngle)
        let end = start + (arc.isLeft ? 1 : -1) * .pi / 2
        let clockwise = !arc.isLeft
        let sign = arc.isLeft ? -1.0 : 1.0
        // Radius of track height y: the ceiling side is inside on a left bend.
        func radius(_ y: Double) -> CGFloat { CGFloat(turn.radius + sign * (y - FausSwitchTrack.centerY)) }

        func band(from a: Double, to b: Double) -> SKShapeNode {
            let path = CGMutablePath()
            path.addArc(center: center, radius: radius(a), startAngle: start, endAngle: end, clockwise: clockwise)
            path.addArc(center: center, radius: radius(b), startAngle: end, endAngle: start, clockwise: !clockwise)
            path.closeSubpath()
            let shape = SKShapeNode(path: path)
            shape.fillColor = style.fill
            shape.strokeColor = style.fill
            shape.lineWidth = 0.5
            return shape
        }
        func surface(at y: Double) -> SKShapeNode {
            let path = CGMutablePath()
            path.addArc(center: center, radius: radius(y), startAngle: start, endAngle: end, clockwise: clockwise)
            let line = SKShapeNode(path: path)
            line.strokeColor = style.surface
            line.lineWidth = 2.2
            line.lineCap = .butt
            return line
        }
        let top = FausSwitchMetrics.worldHeight
        node.addChild(band(from: 0, to: FausSwitchMetrics.floorSurface))
        node.addChild(band(from: FausSwitchMetrics.ceilingSurface, to: top))
        node.addChild(surface(at: FausSwitchMetrics.floorSurface - 1.1))
        node.addChild(surface(at: FausSwitchMetrics.ceilingSurface + 1.1))
        return node
    }

    /// One platform per seat (`FausSwitchStartGrid`) in its robot's body color, with a
    /// lime line on the face the robot stands on.
    private func layoutPlatforms(for runners: [FausSwitchRenderRunner]) {
        let colors = runners.map(\.color)
        guard colors != platformColors else { return }
        platformColors = colors
        platforms.removeAllChildren()
        guard !runners.isEmpty else { return }
        let scale = runners.first?.state.scale ?? 1
        for (lane, runner) in zip(FausSwitchStartGrid.lanes(count: runners.count, runnerScale: scale), runners) {
            let frame = cgRect(lane.platform)
            let slab = SKShapeNode(rect: frame, cornerRadius: 2.5)
            slab.fillColor = runner.color.uiColor
            slab.strokeColor = runner.color.uiColor.switchDarkened(0.35)
            slab.lineWidth = 1.2
            let stripeY = lane.gravity == .down ? frame.maxY - 1.8 : frame.minY
            let stripe = SKShapeNode(rect: CGRect(x: frame.minX + 3, y: stripeY, width: frame.width - 6, height: 1.8),
                                     cornerRadius: 0.9)
            stripe.fillColor = FausSwitchPalette.UI.lime
            stripe.strokeColor = .clear
            slab.addChild(stripe)
            platforms.addChild(slab)
        }
    }

    private func cgRect(_ rect: FausSwitchRect) -> CGRect {
        CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: rect.height)
    }

    private func railNode(_ rect: FausSwitchRect, style: RailStyle) -> SKNode {
        let node = SKNode()
        let body = SKShapeNode(rect: cgRect(rect))
        body.fillColor = style.fill
        body.strokeColor = .clear
        node.addChild(body)

        // The running surface: the edge that faces the play band.
        let isFloor = rect.minY <= 0.5
        let surfaceY = isFloor ? rect.maxY : rect.minY
        let surface = SKShapeNode(rect: CGRect(x: rect.minX, y: surfaceY - (isFloor ? 2.2 : 0), width: rect.width, height: 2.2))
        surface.fillColor = style.surface
        surface.strokeColor = .clear
        node.addChild(surface)

        // Speed ticks inside the rail.
        let ticks = CGMutablePath()
        var x = (rect.minX / 56).rounded(.up) * 56
        let tickMid = isFloor ? rect.maxY - 10 : rect.minY + 10
        while x < rect.maxX - 6 {
            ticks.move(to: CGPoint(x: x, y: tickMid - 3))
            ticks.addLine(to: CGPoint(x: x + 6, y: tickMid + 3))
            x += 56
        }
        let tickNode = SKShapeNode(path: ticks)
        tickNode.strokeColor = style.surface.withAlphaComponent(0.55)
        tickNode.lineWidth = 1.6
        tickNode.lineCap = .round
        node.addChild(tickNode)
        return node
    }

    private func blockNode(_ rect: FausSwitchRect, style: BlockStyle) -> SKNode {
        let frame = cgRect(rect)
        let node = SKShapeNode(rect: frame, cornerRadius: min(5, frame.width / 4, frame.height / 4))
        node.fillColor = style.fill
        node.strokeColor = style.edge
        node.lineWidth = 1.4
        node.zPosition = 1

        // A recessed panel and two bolts read as a machined block.
        let inset = frame.insetBy(dx: 5, dy: 5)
        if inset.width > 6, inset.height > 6 {
            let panel = SKShapeNode(rect: inset, cornerRadius: 2.5)
            panel.fillColor = FausSwitchPalette.UI.plum.withAlphaComponent(0.18)
            panel.strokeColor = style.panel.withAlphaComponent(0.4)
            panel.lineWidth = 0.8
            node.addChild(panel)
        }
        for corner in [CGPoint(x: frame.minX + 4.5, y: frame.maxY - 4.5), CGPoint(x: frame.maxX - 4.5, y: frame.minY + 4.5)]
        where frame.width > 14 && frame.height > 14 {
            let bolt = SKShapeNode(circleOfRadius: 1.4)
            bolt.position = corner
            bolt.fillColor = style.bolt.withAlphaComponent(0.75)
            bolt.strokeColor = .clear
            node.addChild(bolt)
        }
        return node
    }

    private func gapNode(_ gap: FausSwitchGap) -> SKNode {
        let node = SKNode()
        node.zPosition = 1
        let isFloor = gap.rail == .down
        let railMin = isFloor ? 0 : FausSwitchMetrics.ceilingSurface
        let rect = CGRect(x: gap.minX, y: railMin, width: gap.maxX - gap.minX, height: FausSwitchMetrics.railThickness)

        // Hazard stripes where the rail is missing.
        let stripes = CGMutablePath()
        var x = rect.minX - rect.height
        while x < rect.maxX {
            stripes.move(to: CGPoint(x: x, y: rect.minY))
            stripes.addLine(to: CGPoint(x: x + rect.height, y: rect.maxY))
            x += 14
        }
        let crop = SKCropNode()
        let mask = SKSpriteNode(color: .white, size: rect.size)
        mask.anchorPoint = .zero
        mask.position = rect.origin
        crop.maskNode = mask
        let stripeNode = SKShapeNode(path: stripes)
        stripeNode.strokeColor = FausSwitchPalette.UI.plum.withAlphaComponent(0.45)
        stripeNode.lineWidth = 4
        crop.addChild(stripeNode)
        node.addChild(crop)

        // Chevrons on both lips point into the hole.
        let surfaceY = isFloor ? FausSwitchMetrics.floorSurface : FausSwitchMetrics.ceilingSurface
        let direction: CGFloat = isFloor ? -1 : 1
        for lip in [gap.minX, gap.maxX] {
            let chevron = CGMutablePath()
            chevron.move(to: CGPoint(x: lip - 7, y: surfaceY - direction * 2))
            chevron.addLine(to: CGPoint(x: lip, y: surfaceY + direction * 8))
            chevron.addLine(to: CGPoint(x: lip + 7, y: surfaceY - direction * 2))
            chevron.closeSubpath()
            let mark = SKShapeNode(path: chevron)
            mark.fillColor = FausSwitchPalette.UI.plum
            mark.strokeColor = .clear
            node.addChild(mark)
        }
        return node
    }

    private func boostNode(_ pad: FausSwitchBoostPad) -> SKNode {
        let frame = cgRect(pad.rect)
        let node = SKShapeNode(rect: frame, cornerRadius: 4)
        // A floating pad: a deep wine outline keeps it readable on the light course.
        node.fillColor = FausSwitchPalette.UI.green
        node.strokeColor = FausSwitchPalette.UI.deepWine
        node.lineWidth = 1.4
        node.zPosition = 2
        // Chevrons scale with the pad's height.
        let rise = frame.height * 0.27
        let arrows = CGMutablePath()
        for index in 0..<3 {
            let x = frame.minX + 12 + CGFloat(index) * 11
            arrows.move(to: CGPoint(x: x - 3.5, y: frame.midY + rise))
            arrows.addLine(to: CGPoint(x: x + 3, y: frame.midY))
            arrows.addLine(to: CGPoint(x: x - 3.5, y: frame.midY - rise))
        }
        let arrowNode = SKShapeNode(path: arrows)
        arrowNode.strokeColor = FausSwitchPalette.UI.mint
        arrowNode.lineWidth = 2.4
        arrowNode.lineCap = .round
        arrowNode.lineJoin = .round
        node.addChild(arrowNode)
        return node
    }

    /// A slow pad: lavender with three backward chevrons and a deep wine outline.
    private func slowNode(_ pad: FausSwitchSlowPad) -> SKNode {
        let frame = cgRect(pad.rect)
        let node = SKShapeNode(rect: frame, cornerRadius: 4)
        node.fillColor = FausSwitchPalette.UI.lavender
        node.strokeColor = FausSwitchPalette.UI.deepWine
        node.lineWidth = 1.4
        node.zPosition = 2
        let rise = frame.height * 0.27
        let arrows = CGMutablePath()
        for index in 0..<3 {
            let x = frame.maxX - 12 - CGFloat(index) * 11
            arrows.move(to: CGPoint(x: x + 3.5, y: frame.midY + rise))
            arrows.addLine(to: CGPoint(x: x - 3, y: frame.midY))
            arrows.addLine(to: CGPoint(x: x + 3.5, y: frame.midY - rise))
        }
        let arrowNode = SKShapeNode(path: arrows)
        arrowNode.strokeColor = FausSwitchPalette.UI.deepWine
        arrowNode.lineWidth = 2.4
        arrowNode.lineCap = .round
        arrowNode.lineJoin = .round
        node.addChild(arrowNode)
        return node
    }

    /// A portal: an upright ring standing on (or hanging from) its rail, just taller than
    /// a robot, with a pulsing swirl inside.
    private func portalNode(_ portal: FausSwitchPortal) -> SKNode {
        let node = SKNode()
        node.zPosition = 6
        let height = CGFloat(FausSwitchPortal.height) + 4
        let width = CGFloat(FausSwitchPortal.width)
        let base = portal.rail == .down ? CGFloat(FausSwitchMetrics.floorSurface) : CGFloat(FausSwitchMetrics.ceilingSurface) - height
        let frame = CGRect(x: CGFloat(portal.x) - width / 2, y: base, width: width, height: height)
        let swirl = SKShapeNode(ellipseIn: frame.insetBy(dx: 3, dy: 3))
        swirl.fillColor = FausSwitchPalette.UI.deepWine.withAlphaComponent(0.55)
        swirl.strokeColor = FausSwitchPalette.UI.lavender.withAlphaComponent(0.8)
        swirl.lineWidth = 1.2
        node.addChild(swirl)
        let core = SKShapeNode(ellipseIn: frame.insetBy(dx: 7, dy: 10))
        core.fillColor = FausSwitchPalette.UI.lavender.withAlphaComponent(0.5)
        core.strokeColor = .clear
        swirl.addChild(core)
        let ring = SKShapeNode(ellipseIn: frame)
        ring.fillColor = .clear
        ring.strokeColor = FausSwitchPalette.UI.wine
        ring.lineWidth = 3
        node.addChild(ring)
        // The foot that holds it on the rail.
        let footY = portal.rail == .down ? frame.minY - 1 : frame.maxY - 3
        let foot = SKShapeNode(rect: CGRect(x: frame.midX - 9, y: footY, width: 18, height: 4), cornerRadius: 2)
        foot.fillColor = FausSwitchPalette.UI.wine
        foot.strokeColor = .clear
        node.addChild(foot)
        portalGlows.append((portal.x, swirl))
        return node
    }

    /// Where a portal puts a robot: a faint ring on the opposite rail.
    private func portalExitNode(_ portal: FausSwitchPortal) -> SKNode {
        let height = CGFloat(FausSwitchPortal.height) + 4
        let width = CGFloat(FausSwitchPortal.width)
        let base = portal.exitGravity == .down ? CGFloat(FausSwitchMetrics.floorSurface)
            : CGFloat(FausSwitchMetrics.ceilingSurface) - height
        let ring = SKShapeNode(ellipseIn: CGRect(x: CGFloat(portal.exitX) - width / 2, y: base, width: width, height: height))
        ring.fillColor = FausSwitchPalette.UI.lavender.withAlphaComponent(0.18)
        ring.strokeColor = FausSwitchPalette.UI.wine.withAlphaComponent(0.45)
        ring.lineWidth = 1.5
        ring.zPosition = 2
        return ring
    }

    private func finishNode() -> SKNode {
        let node = SKNode()
        node.zPosition = 2
        let x = course.finishX
        let bottom = FausSwitchMetrics.floorSurface
        let top = FausSwitchMetrics.ceilingSurface
        let square: CGFloat = 8
        let background = SKShapeNode(rect: CGRect(x: x - square, y: bottom, width: square * 2, height: top - bottom))
        background.fillColor = FausSwitchPalette.UI.mint
        background.strokeColor = FausSwitchPalette.UI.plum
        background.lineWidth = 1
        node.addChild(background)
        let checks = CGMutablePath()
        var row = 0
        var y = bottom
        while y < top {
            let column: CGFloat = row.isMultiple(of: 2) ? 0 : 1
            checks.addRect(CGRect(x: x - square + column * square, y: y, width: square, height: min(square, top - y)))
            y += square
            row += 1
        }
        let checkNode = SKShapeNode(path: checks)
        checkNode.fillColor = FausSwitchPalette.UI.plum
        checkNode.strokeColor = .clear
        node.addChild(checkNode)
        return node
    }
}

/// The runner: a wide-headed robot with a dark visor, two white eyes and a side ear pad,
/// on a small body with arms and legs. It faces right; gravity "up" mirrors it vertically
/// so its feet stay on the ceiling.
final class FausSwitchRobotNode: SKNode {
    private let rig = SKNode()
    private let leftLeg: SKShapeNode
    private let rightLeg: SKShapeNode
    private let trail = SKNode()
    private let halo: SKShapeNode?
    private var gravity: FausSwitchGravity = .down
    private var hasPosition = false

    init(color: UIColor, isLocal: Bool) {
        let limb = color.switchDarkened(0.32)
        let outline = color.switchDarkened(0.5)
        func part(_ rect: CGRect, radius: CGFloat, fill: UIColor, stroke: UIColor = .clear, line: CGFloat = 0) -> SKShapeNode {
            let node = SKShapeNode(rect: rect, cornerRadius: radius)
            node.fillColor = fill
            node.strokeColor = stroke
            node.lineWidth = line
            return node
        }
        leftLeg = part(CGRect(x: -5.6, y: -14.7, width: 4, height: 5), radius: 1.4, fill: limb)
        rightLeg = part(CGRect(x: 1.6, y: -14.7, width: 4, height: 5), radius: 1.4, fill: limb)
        if isLocal {
            let ring = SKShapeNode(ellipseOf: CGSize(width: 40, height: 42))
            ring.fillColor = FausSwitchPalette.UI.lavender.withAlphaComponent(0.32)
            ring.strokeColor = FausSwitchPalette.UI.lavender.withAlphaComponent(0.8)
            ring.lineWidth = 1
            halo = ring
        } else {
            halo = nil
        }
        super.init()
        // The art is drawn for a 29.4-high box; scale it to the physics box.
        setScale(CGFloat(FausSwitchMetrics.runnerHeight / 29.4))

        if let halo { addChild(halo) }
        addChild(trail)
        addChild(rig)

        for offset: CGFloat in [-4, 3] {
            let streak = SKShapeNode(rect: CGRect(x: -30, y: offset - 0.8, width: 14, height: 1.6), cornerRadius: 0.8)
            streak.fillColor = FausSwitchPalette.UI.green
            streak.strokeColor = .clear
            trail.addChild(streak)
        }
        trail.alpha = 0

        rig.addChild(leftLeg)
        rig.addChild(rightLeg)
        for x: CGFloat in [-9.8, 6.6] {
            rig.addChild(part(CGRect(x: x, y: -10.4, width: 3.2, height: 7), radius: 1.6, fill: limb))
        }
        rig.addChild(part(CGRect(x: -6.3, y: -10.6, width: 12.6, height: 7.8), radius: 2.8, fill: color.switchDarkened(0.1),
                          stroke: outline, line: 0.6))
        let light = SKShapeNode(circleOfRadius: 1.3)
        light.position = CGPoint(x: 2.4, y: -6.6)
        light.fillColor = FausSwitchPalette.UI.lime
        light.strokeColor = .clear
        rig.addChild(light)

        // Head, ear pad, visor and eyes.
        rig.addChild(part(CGRect(x: -12.6, y: -3, width: 25.2, height: 16.6), radius: 6.6, fill: color,
                          stroke: outline, line: 0.9))
        rig.addChild(part(CGRect(x: -14.6, y: 1.2, width: 3.8, height: 8.2), radius: 1.6, fill: limb))
        let highlight = part(CGRect(x: -8.5, y: 10.6, width: 11, height: 1.6), radius: 0.8,
                             fill: color.switchLightened(0.45).withAlphaComponent(0.55))
        rig.addChild(highlight)
        rig.addChild(part(CGRect(x: -7.4, y: 0.4, width: 18, height: 10), radius: 4.4, fill: FausSwitchPalette.UI.visor))
        for x: CGFloat in [-3.6, 3.0] {
            rig.addChild(part(CGRect(x: x, y: 3, width: 4.2, height: 4.8), radius: 1.3, fill: UIColor(fausHex: 0xF4FFF2)))
        }

        if isLocal {
            let marker = CGMutablePath()
            marker.move(to: CGPoint(x: -4, y: 23))
            marker.addLine(to: CGPoint(x: 4, y: 23))
            marker.addLine(to: CGPoint(x: 0, y: 17.5))
            marker.closeSubpath()
            let markerNode = SKShapeNode(path: marker)
            markerNode.fillColor = FausSwitchPalette.UI.lime
            markerNode.strokeColor = FausSwitchPalette.UI.plum
            markerNode.lineWidth = 1
            rig.addChild(markerNode)
        }
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// `pose` is the robot's place in the world; its drawing stays in track terms (faces
    /// the run direction, feet toward its gravity rail) and turns with the course.
    func update(_ runner: FausSwitchRenderRunner, pose: FausSwitchPose, tick: Int64, phase: FausSwitchMatchPhase,
                reduceMotion: Bool) {
        let state = runner.state
        // Crowded races draw smaller robots (`FausSwitchRunnerState.scale`).
        let size = CGFloat(FausSwitchMetrics.runnerHeight / 29.4 * state.scale)
        if xScale != size { setScale(size) }
        position = CGPoint(x: pose.x, y: pose.y)
        zRotation = CGFloat(pose.angle)

        if state.gravity != gravity || !hasPosition {
            let target: CGFloat = state.gravity == .down ? 1 : -1
            rig.removeAction(forKey: "flip")
            halo?.removeAction(forKey: "flip")
            if reduceMotion || !hasPosition {
                rig.yScale = target
            } else {
                let turn = SKAction.scaleY(to: target, duration: 0.14)
                turn.timingMode = .easeInEaseOut
                rig.run(turn, withKey: "flip")
            }
            gravity = state.gravity
            hasPosition = true
        }

        switch state.status {
        case .crashed: alpha = 0.32
        case .finished: alpha = 1
        case .running: alpha = runner.isConnected ? 1 : 0.55
        }

        let running = state.isRunning && phase == .playing && !reduceMotion
        let stride = running ? CGFloat(sin(Double(tick) * 0.42)) * 0.9 : 0
        leftLeg.position.y = stride
        rightLeg.position.y = -stride
        trail.alpha = runner.isBoosted && state.isRunning ? 0.9 : 0
    }
}
