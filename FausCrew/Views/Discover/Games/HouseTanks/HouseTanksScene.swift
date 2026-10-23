import FausCrewCore
import SpriteKit
import UIKit

/// Field-map inks for the arena; the paper itself is drawn by SwiftUI behind the scene.
private enum FieldInk {
    static let ink = UIColor(red: 31 / 255, green: 44 / 255, blue: 53 / 255, alpha: 1)
    static let paper = UIColor(red: 240 / 255, green: 248 / 255, blue: 1, alpha: 1)
    static let steel = UIColor(red: 0, green: 103 / 255, blue: 165 / 255, alpha: 1)
    static let khaki = UIColor(red: 186 / 255, green: 140 / 255, blue: 99 / 255, alpha: 1)
    static let slate = UIColor(red: 116 / 255, green: 125 / 255, blue: 131 / 255, alpha: 1)
    static let olive = UIColor(red: 111 / 255, green: 117 / 255, blue: 86 / 255, alpha: 1)
    static let rust = UIColor(red: 164 / 255, green: 80 / 255, blue: 59 / 255, alpha: 1)
    static let umber = UIColor(red: 133 / 255, green: 96 / 255, blue: 63 / 255, alpha: 1)
    /// The one saturated ink on the sheet, reserved for the aim joker.
    static let signalRed = UIColor(red: 222 / 255, green: 24 / 255, blue: 32 / 255, alpha: 1)
}

extension HouseTanksPowerUp {
    /// SF Symbol for the jokers that have one; spread shot and the rocket are drawn instead.
    var symbolName: String {
        switch self {
        case .rocket: "paperplane.fill"
        case .rapidFire: "flame.fill"
        case .spreadShot: "arrow.up.left.and.arrow.up.right"
        case .shield: "shield.fill"
        case .aim: "scope"
        }
    }

    /// Token, on-tank badge and How-to-play color.
    var tint: UIColor {
        switch self {
        case .rocket: FieldInk.olive
        case .rapidFire: FieldInk.rust
        case .spreadShot: FieldInk.umber
        case .shield: FieldInk.steel
        case .aim: FieldInk.signalRed
        }
    }

    /// Template glyph shared by arena tokens and the How-to-play list. Spread shot and the giant
    /// rocket have no fitting SF Symbol, so they are drawn.
    func glyph(pointSize: CGFloat) -> UIImage? {
        switch self {
        case .spreadShot: return spreadGlyph(pointSize: pointSize)
        case .rocket: return rocketGlyph(pointSize: pointSize)
        default:
            return UIImage(systemName: symbolName,
                           withConfiguration: UIImage.SymbolConfiguration(pointSize: pointSize, weight: .bold))?
                .withRenderingMode(.alwaysTemplate)
        }
    }

    /// A rocket climbing to the upper right: body, nose, two fins and an exhaust puff.
    private func rocketGlyph(pointSize: CGFloat) -> UIImage {
        let side = pointSize * 1.2
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { renderer in
            let context = renderer.cgContext
            context.translateBy(x: side / 2, y: side / 2)
            context.rotate(by: -.pi / 4)
            context.setFillColor(UIColor.black.cgColor)
            let length = side * 0.86
            let width = side * 0.28
            context.addPath(CGPath(roundedRect: CGRect(x: -length * 0.42, y: -width / 2, width: length * 0.62, height: width),
                                   cornerWidth: width * 0.3, cornerHeight: width * 0.3, transform: nil))
            context.move(to: CGPoint(x: length * 0.2, y: -width / 2))
            context.addLine(to: CGPoint(x: length * 0.5, y: 0))
            context.addLine(to: CGPoint(x: length * 0.2, y: width / 2))
            for sign in [CGFloat(1), -1] {
                context.move(to: CGPoint(x: -length * 0.42, y: sign * width / 2))
                context.addLine(to: CGPoint(x: -length * 0.5, y: sign * width * 1.25))
                context.addLine(to: CGPoint(x: -length * 0.18, y: sign * width / 2))
            }
            context.fillPath()
            context.fillEllipse(in: CGRect(x: -length * 0.62, y: -width * 0.3, width: width * 0.6, height: width * 0.6))
        }.withRenderingMode(.alwaysTemplate)
    }

    /// Three rods fanning out of one muzzle point.
    private func spreadGlyph(pointSize: CGFloat) -> UIImage {
        let side = pointSize * 1.2
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { renderer in
            let context = renderer.cgContext
            let origin = CGPoint(x: side / 2, y: side * 0.84)
            let length = side * 0.7
            context.setLineCap(.round)
            context.setLineWidth(side * 0.14)
            context.setStrokeColor(UIColor.black.cgColor)
            context.setFillColor(UIColor.black.cgColor)
            for spread in [CGFloat(-0.52), 0, 0.52] {
                let angle = -CGFloat.pi / 2 + spread
                context.move(to: origin)
                context.addLine(to: CGPoint(x: origin.x + cos(angle) * length, y: origin.y + sin(angle) * length))
            }
            context.strokePath()
            let dot = side * 0.12
            context.fillEllipse(in: CGRect(x: origin.x - dot, y: origin.y - dot, width: dot * 2, height: dot * 2))
        }.withRenderingMode(.alwaysTemplate)
    }
}

extension HouseTanksColor {
    /// In-match tank color; the raw value stays the serialized identity.
    var uiColor: UIColor {
        switch self {
        // Muted plum: the one hue no other tank, crate or wall uses.
        case .plum: UIColor(red: 107 / 255, green: 76 / 255, blue: 122 / 255, alpha: 1)
        case .orange: UIColor(red: 200 / 255, green: 104 / 255, blue: 58 / 255, alpha: 1)
        case .blue: FieldInk.steel
        case .olive: UIColor(red: 124 / 255, green: 139 / 255, blue: 46 / 255, alpha: 1)
        }
    }
}

/// Draws a FauseTanks world from the shared engine (FausCrewCore). It owns no rules and no
/// physics: every frame it reports the real delta through `onFrame`, the session advances
/// the engine, and `render(_:roundKey:events:)` mirrors the result onto nodes.
final class HouseTanksScene: SKScene {
    /// Once per display frame with the real delta (capped like the engine).
    var onFrame: ((TimeInterval) -> Void)?
    /// The drawing surface changed; the engine follows it.
    var onResize: ((CGSize) -> Void)?

    private var lastUpdateTime: TimeInterval = 0
    private var reduceMotion = false
    private var currentMap = HouseTanksMapCatalog.definition(for: .livingRoom)
    private var arenaKey: String?
    private var tankNodes: [UUID: SKNode] = [:]
    private var destroyedTanks = Set<UUID>()
    private var crateNodes: [Int: SKNode] = [:]
    private var projectileNodes: [Int: SKNode] = [:]
    private var tokenNode: SKNode?
    private var tokenKind: HouseTanksPowerUp?
    private var powerTextures: [HouseTanksPowerUp: SKTexture] = [:]

    private let tankVisualScale: CGFloat = 0.38
    private let tankSize = CGSize(width: 20, height: 14)
    private let projectileSize = CGSize(width: 9, height: 3.5)
    private let rocketSize = CGSize(width: 22, height: 8)

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = .clear
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0 else { return }
        onResize?(size)
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdateTime > 0 ? min(1.0 / 20.0, currentTime - lastUpdateTime) : 0
        lastUpdateTime = currentTime
        onFrame?(delta)
    }

    func setSimulationPaused(_ paused: Bool) {
        lastUpdateTime = 0
        isPaused = paused
    }

    func setReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
    }

    /// Removes everything; the next `render` rebuilds the arena.
    func stopMatch() {
        removeAllChildren()
        arenaKey = nil
        tankNodes.removeAll()
        destroyedTanks.removeAll()
        crateNodes.removeAll()
        projectileNodes.removeAll()
        tokenNode = nil
        tokenKind = nil
    }

    /// Mirrors the engine onto nodes. `roundKey` changes with every new round (a fresh arena).
    func render(_ world: HouseTanksWorld, roundKey: String, events: [HouseTanksWorld.Event]) {
        let key = "\(roundKey)|\(world.size.width)x\(world.size.height)"
        if key != arenaKey {
            let sameRound = arenaKey?.hasPrefix(roundKey + "|") == true
            arenaKey = key
            buildArena(world, keepActors: sameRound)
        }
        syncTanks(world)
        syncCrates(world)
        syncProjectiles(world)
        syncToken(world)
        for event in events { play(event) }
    }

    // MARK: - Arena

    private func buildArena(_ world: HouseTanksWorld, keepActors: Bool) {
        currentMap = world.map
        children.filter { $0.name == "arena" || $0.name == "crate" || $0.name == "effect" }.forEach { $0.removeFromParent() }
        crateNodes.removeAll()
        if !keepActors {
            tankNodes.values.forEach { $0.removeFromParent() }
            tankNodes.removeAll()
            destroyedTanks.removeAll()
            projectileNodes.values.forEach { $0.removeFromParent() }
            projectileNodes.removeAll()
            tokenNode?.removeFromParent()
            tokenNode = nil
            tokenKind = nil
        }

        let mat = SKShapeNode(rect: CGRect(origin: .zero, size: size), cornerRadius: 0)
        mat.name = "arena"
        mat.fillColor = floorTint
        mat.strokeColor = .clear
        mat.zPosition = -20
        addChild(mat)

        addFloorPlanLines()
        addArenaBoundary()
        for obstacle in world.obstacles where !obstacle.isDestroyed {
            let node = makeObstacle(obstacle)
            node.position = point(obstacle.position)
            node.zRotation = CGFloat(obstacle.rotation)
            node.zPosition = 2
            if obstacle.isMovable {
                node.name = "crate"
                crateNodes[obstacle.index] = node
            } else {
                node.name = "arena"
            }
            addChild(node)
        }
    }

    private func makeObstacle(_ obstacle: HouseTanksWorld.Obstacle) -> SKShapeNode {
        let obstacleSize = CGSize(width: obstacle.size.width, height: obstacle.size.height)
        let node: SKShapeNode
        if obstacle.isRound {
            node = SKShapeNode(circleOfRadius: min(obstacleSize.width, obstacleSize.height) / 2)
        } else {
            node = SKShapeNode(rectOf: obstacleSize, cornerRadius: min(14, obstacleSize.height * 0.28))
        }
        node.fillColor = obstacleColor(for: obstacle.isMovable ? .wood : obstacle.definition.tone)
        node.strokeColor = FieldInk.ink.withAlphaComponent(0.55)
        node.lineWidth = 1.4
        decorateObstacle(node, style: obstacle.definition.style, size: obstacleSize)
        return node
    }

    // MARK: - Sync

    private func syncTanks(_ world: HouseTanksWorld) {
        for tank in world.tanks {
            let node: SKNode
            if let existing = tankNodes[tank.id] {
                node = existing
            } else {
                node = makeTank(tank)
                tankNodes[tank.id] = node
                addChild(node)
            }
            node.position = point(tank.position)
            node.zRotation = CGFloat(tank.rotation)
            if !tank.isActive, !destroyedTanks.contains(tank.id) {
                destroyedTanks.insert(tank.id)
                if let artwork = node.childNode(withName: "artwork") {
                    artwork.childNode(withName: "aura")?.removeFromParent()
                    applyDestroyedAppearance(to: artwork)
                }
            }
            updatePowerIndicator(tank.isActive ? world.powerUpStatus(for: tank.id) : nil, on: node)
            updateAimLine(on: node, length: world.aimLength(for: tank.id))
        }
    }

    private func syncCrates(_ world: HouseTanksWorld) {
        for obstacle in world.obstacles where obstacle.isMovable {
            guard let node = crateNodes[obstacle.index] else { continue }
            if obstacle.isDestroyed {
                node.removeFromParent()
                crateNodes[obstacle.index] = nil
            } else {
                node.position = point(obstacle.position)
            }
        }
    }

    private func syncProjectiles(_ world: HouseTanksWorld) {
        var live = Set<Int>()
        for projectile in world.projectiles {
            live.insert(projectile.id)
            let node: SKNode
            if let existing = projectileNodes[projectile.id] {
                node = existing
            } else {
                node = projectile.isRocket ? makeRocket() : makeProjectile(color: projectile.color)
                projectileNodes[projectile.id] = node
                addChild(node)
            }
            node.position = point(projectile.position)
            node.zRotation = CGFloat(projectile.rotation)
        }
        for (id, node) in projectileNodes where !live.contains(id) {
            node.removeFromParent()
            projectileNodes[id] = nil
        }
    }

    private func syncToken(_ world: HouseTanksWorld) {
        guard let token = world.powerUps.token else {
            tokenNode?.removeFromParent()
            tokenNode = nil
            tokenKind = nil
            return
        }
        if tokenNode == nil || tokenKind != token.kind {
            tokenNode?.removeFromParent()
            let node = SKShapeNode(circleOfRadius: 14)
            node.name = "joker"
            node.zPosition = 6
            node.fillColor = powerColor(token.kind)
            node.strokeColor = FieldInk.paper
            node.lineWidth = 1.5
            node.addChild(powerIcon(token.kind, side: 16))
            addChild(node)
            tokenNode = node
            tokenKind = token.kind
        }
        guard let tokenNode else { return }
        tokenNode.position = point(token.position)
        updateTimerArc(on: tokenNode, fraction: (token.expiresAt - world.time) / HouseTanksPowerUpRules.tokenLifetime,
                       radius: 17)
    }

    private func play(_ event: HouseTanksWorld.Event) {
        switch event {
        case .fired(let playerID, _):
            if let tank = tankNodes[playerID] { addMuzzleFlash(to: tank, colorName: tank.userData?["color"] as? String) }
        case .shielded(let playerID):
            showHit(playerID: playerID)
        case .crateBroken(_, let position):
            addCrateFragments(at: point(position))
        case .explosion(let position), .eliminated(_, let position):
            addExplosion(at: point(position))
        case .jokerCollected:
            break
        }
    }

    /// Aim joker: a dotted red sight line from the muzzle to the arena wall.
    private func updateAimLine(on tank: SKNode, length: Double?) {
        guard let length else {
            tank.childNode(withName: "aim-line")?.removeFromParent()
            return
        }
        let line: SKShapeNode
        if let existing = tank.childNode(withName: "aim-line") as? SKShapeNode {
            line = existing
        } else {
            line = SKShapeNode()
            line.name = "aim-line"
            line.strokeColor = FieldInk.signalRed
            line.lineWidth = 2.6
            line.lineCap = .round
            line.zPosition = -1
            tank.addChild(line)
        }
        let start = tankSize.width / 2 + 6
        guard CGFloat(length) > start else {
            line.path = nil
            return
        }
        let path = CGMutablePath()
        path.move(to: CGPoint(x: start, y: 0))
        path.addLine(to: CGPoint(x: CGFloat(length), y: 0))
        // A zero-length dash with a round cap draws a dot.
        line.path = path.copy(dashingWithPhase: 0, lengths: [0.1, 7])
    }

    private func makeProjectile(color: HouseTanksColor) -> SKNode {
        let projectile = SKShapeNode(rectOf: projectileSize, cornerRadius: projectileSize.height / 2)
        projectile.name = "projectile"
        projectile.fillColor = color.uiColor
        projectile.strokeColor = FieldInk.ink
        projectile.lineWidth = 1
        projectile.zPosition = 8
        return projectile
    }

    private func point(_ vector: HouseTanksVector) -> CGPoint {
        CGPoint(x: vector.x, y: vector.y)
    }

    private func scenePoint(_ point: HouseTanksNormalizedPoint) -> CGPoint {
        CGPoint(x: size.width * CGFloat(point.x), y: size.height * CGFloat(point.y))
    }

    private func color(for color: HouseTanksColor) -> UIColor {
        color.uiColor
    }

    // MARK: - Drawing

    private func addFloorPlanLines() {
        let path = CGMutablePath()
        for line in currentMap.floorLines {
            path.move(to: scenePoint(line.start))
            path.addLine(to: scenePoint(line.end))
        }

        let lineWidth = max(2, size.height * 0.004)
        let lines = SKShapeNode(path: path.copy(dashingWithPhase: 0, lengths: [lineWidth * 3, lineWidth * 2.5]))
        lines.name = "arena"
        lines.strokeColor = floorAccent.withAlphaComponent(0.38)
        lines.lineWidth = lineWidth
        lines.lineCap = .round
        lines.zPosition = -15
        addChild(lines)

        let radius = max(5, size.height * 0.011)
        for point in currentMap.floorMarkers {
            let cross = CGMutablePath()
            cross.move(to: CGPoint(x: -radius * 1.7, y: 0))
            cross.addLine(to: CGPoint(x: radius * 1.7, y: 0))
            cross.move(to: CGPoint(x: 0, y: -radius * 1.7))
            cross.addLine(to: CGPoint(x: 0, y: radius * 1.7))
            cross.addEllipse(in: CGRect(x: -radius, y: -radius, width: radius * 2, height: radius * 2))
            let marker = SKShapeNode(path: cross)
            marker.name = "arena"
            marker.position = scenePoint(point)
            marker.strokeColor = floorAccent.withAlphaComponent(0.42)
            marker.lineWidth = 1
            marker.zPosition = -14
            addChild(marker)
        }
    }

    private func addArenaBoundary() {
        let inset = max(16, size.height * 0.035)
        let frame = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
        // A double neatline with corner brackets frames the arena like a map sheet.
        let boundary = SKShapeNode(rect: frame, cornerRadius: 4)
        boundary.name = "arena"
        boundary.strokeColor = FieldInk.ink.withAlphaComponent(0.62)
        boundary.lineWidth = max(2.5, size.height * 0.006)
        boundary.fillColor = .clear
        boundary.zPosition = -10
        addChild(boundary)

        let innerFrame = frame.insetBy(dx: 6, dy: 6)
        let inner = SKShapeNode(rect: innerFrame, cornerRadius: 2)
        inner.name = "arena"
        inner.strokeColor = FieldInk.slate.withAlphaComponent(0.4)
        inner.lineWidth = 0.8
        inner.fillColor = .clear
        inner.zPosition = -10
        addChild(inner)

        let bracket = CGMutablePath()
        let length = max(14, size.height * 0.04)
        for (corner, dx, dy) in [(CGPoint(x: innerFrame.minX, y: innerFrame.minY), CGFloat(1), CGFloat(1)),
                                 (CGPoint(x: innerFrame.maxX, y: innerFrame.minY), -1, 1),
                                 (CGPoint(x: innerFrame.minX, y: innerFrame.maxY), 1, -1),
                                 (CGPoint(x: innerFrame.maxX, y: innerFrame.maxY), -1, -1)] {
            bracket.move(to: CGPoint(x: corner.x + length * dx, y: corner.y + 4 * dy))
            bracket.addLine(to: CGPoint(x: corner.x + 4 * dx, y: corner.y + 4 * dy))
            bracket.addLine(to: CGPoint(x: corner.x + 4 * dx, y: corner.y + length * dy))
        }
        let brackets = SKShapeNode(path: bracket)
        brackets.name = "arena"
        brackets.strokeColor = FieldInk.steel.withAlphaComponent(0.55)
        brackets.lineWidth = 1.5
        brackets.zPosition = -10
        addChild(brackets)
    }

    private func decorateObstacle(
        _ obstacle: SKShapeNode,
        style: HouseTanksObstacleStyle,
        size obstacleSize: CGSize
    ) {
        switch style {
        case .divider:
            for yOffset in [CGFloat(-0.26), 0, 0.26] {
                let slat = SKShapeNode(
                    rectOf: CGSize(
                        width: max(5, obstacleSize.width * 0.58),
                        height: max(3, obstacleSize.height * 0.055)
                    ),
                    cornerRadius: 2
                )
                slat.position.y = obstacleSize.height * yOffset
                slat.fillColor = UIColor.white.withAlphaComponent(0.20)
                slat.strokeColor = .clear
                obstacle.addChild(slat)
            }

        case .sofa:
            let back = SKShapeNode(
                rectOf: CGSize(
                    width: obstacleSize.width * 0.78,
                    height: max(5, obstacleSize.height * 0.18)
                ),
                cornerRadius: 3
            )
            back.position.y = obstacleSize.height * 0.20
            back.fillColor = UIColor.white.withAlphaComponent(0.20)
            back.strokeColor = .clear
            obstacle.addChild(back)

            for xOffset in [CGFloat(-0.24), 0.24] {
                let seam = SKShapeNode(
                    rectOf: CGSize(
                        width: max(2, obstacleSize.width * 0.018),
                        height: obstacleSize.height * 0.46
                    ),
                    cornerRadius: 1
                )
                seam.position.x = obstacleSize.width * xOffset
                seam.fillColor = UIColor.white.withAlphaComponent(0.22)
                seam.strokeColor = .clear
                obstacle.addChild(seam)
            }

        case .roundTable:
            let inset = SKShapeNode(
                circleOfRadius: min(obstacleSize.width, obstacleSize.height) * 0.27
            )
            inset.fillColor = UIColor.white.withAlphaComponent(0.14)
            inset.strokeColor = UIColor.white.withAlphaComponent(0.22)
            inset.lineWidth = 1.5
            obstacle.addChild(inset)

        case .crate:
            let path = CGMutablePath()
            path.move(to: CGPoint(
                x: -obstacleSize.width * 0.27,
                y: -obstacleSize.height * 0.27
            ))
            path.addLine(to: CGPoint(
                x: obstacleSize.width * 0.27,
                y: obstacleSize.height * 0.27
            ))
            path.move(to: CGPoint(
                x: -obstacleSize.width * 0.27,
                y: obstacleSize.height * 0.27
            ))
            path.addLine(to: CGPoint(
                x: obstacleSize.width * 0.27,
                y: -obstacleSize.height * 0.27
            ))
            let cross = SKShapeNode(path: path)
            cross.strokeColor = UIColor.white.withAlphaComponent(0.24)
            cross.lineWidth = 2
            cross.lineCap = .round
            obstacle.addChild(cross)

        case .bookshelf:
            for xOffset in [CGFloat(-0.28), -0.09, 0.10, 0.29] {
                let book = SKShapeNode(
                    rectOf: CGSize(
                        width: max(2, obstacleSize.width * 0.08),
                        height: max(4, obstacleSize.height * 0.58)
                    ),
                    cornerRadius: 1
                )
                book.position.x = obstacleSize.width * xOffset
                book.fillColor = UIColor.white.withAlphaComponent(0.18 + abs(xOffset) * 0.16)
                book.strokeColor = .clear
                obstacle.addChild(book)
            }

        case .pillar:
            let inner = SKShapeNode(
                circleOfRadius: min(obstacleSize.width, obstacleSize.height) * 0.28
            )
            inner.fillColor = UIColor.white.withAlphaComponent(0.16)
            inner.strokeColor = UIColor.white.withAlphaComponent(0.28)
            inner.lineWidth = 1
            obstacle.addChild(inner)

        case .planter:
            for angle in stride(from: CGFloat.zero, to: .pi * 2, by: .pi / 3) {
                let leaf = SKShapeNode(
                    ellipseOf: CGSize(
                        width: max(3, obstacleSize.width * 0.24),
                        height: max(5, obstacleSize.height * 0.42)
                    )
                )
                leaf.position = CGPoint(
                    x: cos(angle) * obstacleSize.width * 0.14,
                    y: sin(angle) * obstacleSize.height * 0.14
                )
                leaf.zRotation = angle - .pi / 2
                leaf.fillColor = UIColor.white.withAlphaComponent(0.15)
                leaf.strokeColor = .clear
                obstacle.addChild(leaf)
            }
        }
    }

    private func makeTank(_ player: HouseTanksWorld.Tank) -> SKNode {
        let root = SKNode()
        root.name = "tank"
        root.zPosition = 10
        root.userData = ["color": player.color.rawValue]

        let artwork = SKNode()
        artwork.name = "artwork"
        artwork.setScale(tankVisualScale)
        root.addChild(artwork)

        let tint = color(for: player.color)
        let aura = SKShapeNode(ellipseOf: CGSize(width: 72, height: 60))
        aura.name = "aura"
        aura.fillColor = tint.withAlphaComponent(player.role == .human ? 0.18 : 0.07)
        aura.strokeColor = tint.withAlphaComponent(player.role == .human ? 0.72 : 0.26)
        aura.lineWidth = player.role == .human ? 3 : 1.5
        aura.zPosition = -2
        artwork.addChild(aura)

        let leftTrack = SKShapeNode(rectOf: CGSize(width: 38, height: 10), cornerRadius: 5)
        leftTrack.position.y = 17
        leftTrack.fillColor = FieldInk.ink
        leftTrack.strokeColor = FieldInk.paper.withAlphaComponent(0.25)
        artwork.addChild(leftTrack)

        let rightTrack = leftTrack.copy() as! SKShapeNode
        rightTrack.position.y = -17
        artwork.addChild(rightTrack)

        let hull = SKShapeNode(rectOf: CGSize(width: 44, height: 30), cornerRadius: 9)
        hull.name = "hull"
        hull.fillColor = tint
        hull.strokeColor = FieldInk.ink
        hull.lineWidth = 2.5
        hull.zPosition = 1
        artwork.addChild(hull)

        let turret = SKShapeNode(circleOfRadius: 10)
        turret.name = "turret"
        turret.fillColor = tint.tanksShaded(by: -0.10)
        turret.strokeColor = FieldInk.ink
        turret.lineWidth = 2
        turret.zPosition = 2
        artwork.addChild(turret)

        let barrel = SKShapeNode(rectOf: CGSize(width: 31, height: 8), cornerRadius: 4)
        barrel.name = "barrel"
        barrel.position.x = 18
        barrel.fillColor = tint.tanksShaded(by: -0.16)
        barrel.strokeColor = FieldInk.ink
        barrel.lineWidth = 1.5
        barrel.zPosition = 1
        turret.addChild(barrel)

        return root
    }

    /// Giant rocket joker: a slower, much larger shot with fins and a flame, lethal on any tank.
    private func makeRocket() -> SKNode {
        let rocket = SKNode()
        rocket.name = "projectile"
        rocket.zPosition = 9

        let length = rocketSize.width
        let radius = rocketSize.height / 2
        let flame = SKShapeNode(ellipseOf: CGSize(width: length * 0.55, height: rocketSize.height * 0.8))
        flame.position.x = -length * 0.62
        flame.fillColor = FieldInk.signalRed
        flame.strokeColor = FieldInk.khaki
        flame.lineWidth = 1
        if !reduceMotion {
            flame.run(.repeatForever(.sequence([.scaleX(to: 0.6, duration: 0.06), .scaleX(to: 1, duration: 0.06)])))
        }
        rocket.addChild(flame)

        let fins = CGMutablePath()
        fins.move(to: CGPoint(x: -length * 0.5, y: radius))
        fins.addLine(to: CGPoint(x: -length * 0.62, y: radius * 2.1))
        fins.addLine(to: CGPoint(x: -length * 0.18, y: radius))
        fins.move(to: CGPoint(x: -length * 0.5, y: -radius))
        fins.addLine(to: CGPoint(x: -length * 0.62, y: -radius * 2.1))
        fins.addLine(to: CGPoint(x: -length * 0.18, y: -radius))
        let finNode = SKShapeNode(path: fins)
        finNode.fillColor = FieldInk.rust
        finNode.strokeColor = FieldInk.ink
        finNode.lineWidth = 1
        rocket.addChild(finNode)

        let body = SKShapeNode(rectOf: CGSize(width: length, height: rocketSize.height), cornerRadius: radius)
        body.fillColor = FieldInk.olive
        body.strokeColor = FieldInk.ink
        body.lineWidth = 1.4
        rocket.addChild(body)

        let nose = CGMutablePath()
        nose.move(to: CGPoint(x: length * 0.3, y: radius))
        nose.addLine(to: CGPoint(x: length * 0.62, y: 0))
        nose.addLine(to: CGPoint(x: length * 0.3, y: -radius))
        nose.closeSubpath()
        let noseNode = SKShapeNode(path: nose)
        noseNode.fillColor = FieldInk.signalRed
        noseNode.strokeColor = FieldInk.ink
        noseNode.lineWidth = 1.2
        rocket.addChild(noseNode)

        return rocket
    }

    private func addMuzzleFlash(to tank: SKNode, colorName: String?) {
        guard !reduceMotion else { return }
        let flash = SKShapeNode(circleOfRadius: 3)
        flash.fillColor = color(for: HouseTanksColor(rawValue: colorName ?? "") ?? .plum)
        flash.strokeColor = FieldInk.paper
        flash.lineWidth = 1
        flash.position = CGPoint(x: tankSize.width / 2 + 3, y: 0)
        flash.zPosition = 5
        tank.addChild(flash)
        flash.run(.sequence([
            .group([.scale(to: 1.8, duration: 0.08), .fadeOut(withDuration: 0.10)]),
            .removeFromParent(),
        ]))
    }

    private func addExplosion(at position: CGPoint) {
        let count = reduceMotion ? 4 : 10
        for index in 0..<count {
            let shard = SKShapeNode(circleOfRadius: reduceMotion ? 1.5 : 2.5)
            shard.name = "effect"
            shard.fillColor = index.isMultiple(of: 2)
                ? FieldInk.rust
                : FieldInk.khaki
            shard.strokeColor = .clear
            shard.position = position
            shard.zPosition = 20
            addChild(shard)

            let angle = CGFloat(index) / CGFloat(max(1, count)) * .pi * 2
            let distance: CGFloat = reduceMotion ? 11 : 27
            let destination = CGPoint(
                x: position.x + cos(angle) * distance,
                y: position.y + sin(angle) * distance
            )
            shard.run(.sequence([
                .group([.move(to: destination, duration: reduceMotion ? 0.12 : 0.30), .fadeOut(withDuration: 0.32)]),
                .removeFromParent(),
            ]))
        }
    }

    private func addCrateFragments(at position: CGPoint) {
        for index in 0..<(reduceMotion ? 1 : 5) {
            let shard = SKShapeNode(rectOf: CGSize(width: 8, height: 3), cornerRadius: 1)
            shard.name = "effect"
            shard.fillColor = obstacleColor(for: .wood)
            shard.strokeColor = .clear
            shard.position = position
            shard.zPosition = 12
            addChild(shard)
            let angle = CGFloat(index) / 5 * .pi * 2
            let move = reduceMotion ? SKAction.wait(forDuration: 0.2)
                : SKAction.moveBy(x: cos(angle) * 20, y: sin(angle) * 20, duration: 0.25)
            shard.run(.sequence([.group([move, .fadeOut(withDuration: 0.3)]), .removeFromParent()]))
        }
    }

    func showHit(playerID: UUID) {
        guard let tank = tankNodes[playerID],
              let artwork = tank.childNode(withName: "artwork"),
              let hull = artwork.childNode(withName: "hull") else { return }
        let flash = SKAction.sequence([
            .fadeAlpha(to: 0.28, duration: 0.05),
            .fadeAlpha(to: 1, duration: 0.12),
        ])
        hull.run(flash, withKey: "hit-flash")
    }

    private func updatePowerIndicator(_ status: HouseTanksPowerUpStatus?, on tank: SKNode) {
        guard let status else {
            tank.childNode(withName: "power-indicator")?.removeFromParent()
            return
        }
        var indicator = tank.childNode(withName: "power-indicator")
        if indicator?.userData?["kind"] as? String != status.kind.rawValue {
            indicator?.removeFromParent()
            let node = SKNode()
            node.name = "power-indicator"
            node.userData = ["kind": status.kind.rawValue]
            let ring = SKShapeNode(circleOfRadius: 20)
            ring.fillColor = powerColor(status.kind).withAlphaComponent(status.kind == .shield ? 0.22 : 0.08)
            ring.strokeColor = powerColor(status.kind)
            ring.lineWidth = status.kind == .shield ? 2.5 : 1
            node.addChild(ring)
            let badge = SKShapeNode(circleOfRadius: 9)
            badge.position = CGPoint(x: 0, y: 29)
            badge.fillColor = powerColor(status.kind)
            badge.strokeColor = FieldInk.paper
            badge.lineWidth = 1
            badge.addChild(powerIcon(status.kind, side: 11))
            node.addChild(badge)
            tank.addChild(node)
            indicator = node
        }
        guard let indicator else { return }
        indicator.zRotation = -tank.zRotation
        updateTimerArc(on: indicator, fraction: status.remaining / HouseTanksPowerUpRules.duration, radius: 22)
    }

    private func updateTimerArc(on node: SKNode, fraction: Double, radius: CGFloat) {
        let arc: SKShapeNode
        if let existing = node.childNode(withName: "timer-arc") as? SKShapeNode {
            arc = existing
        } else {
            arc = SKShapeNode()
            arc.name = "timer-arc"
            arc.strokeColor = FieldInk.ink
            arc.lineWidth = 2
            arc.lineCap = .round
            node.addChild(arc)
        }
        let path = CGMutablePath()
        path.addArc(center: .zero, radius: radius, startAngle: .pi / 2,
                    endAngle: .pi / 2 - .pi * 2 * CGFloat(min(1, max(0, fraction))), clockwise: true)
        arc.path = path
    }

    private func powerIcon(_ kind: HouseTanksPowerUp, side: CGFloat) -> SKNode {
        if powerTextures[kind] == nil, let icon = kind.glyph(pointSize: 18) {
            powerTextures[kind] = SKTexture(image: icon.withTintColor(.white, renderingMode: .alwaysOriginal))
        }
        let icon = SKSpriteNode(texture: powerTextures[kind])
        if let texture = powerTextures[kind] {
            let native = texture.size()
            let scale = side / max(native.width, native.height)
            icon.size = CGSize(width: native.width * scale, height: native.height * scale)
        }
        return icon
    }

    private func powerColor(_ kind: HouseTanksPowerUp) -> UIColor {
        kind.tint
    }

    /// A light wash over the paper gives each map its own sheet color.
    private var floorTint: UIColor {
        switch currentMap.id {
        case .livingRoom: FieldInk.khaki.withAlphaComponent(0.14)
        case .corridors: FieldInk.steel.withAlphaComponent(0.07)
        case .warehouse: FieldInk.rust.withAlphaComponent(0.08)
        case .courtyard: FieldInk.olive.withAlphaComponent(0.12)
        }
    }

    private var floorAccent: UIColor {
        switch currentMap.id {
        case .livingRoom: FieldInk.umber
        case .corridors: FieldInk.steel
        case .warehouse: FieldInk.rust
        case .courtyard: FieldInk.olive
        }
    }

    private func obstacleColor(for tone: HouseTanksObstacleTone) -> UIColor {
        switch tone {
        case .navy: UIColor(red: 74 / 255, green: 85 / 255, blue: 93 / 255, alpha: 1)
        case .teal: UIColor(red: 88 / 255, green: 128 / 255, blue: 124 / 255, alpha: 1)
        case .orange: UIColor(red: 176 / 255, green: 112 / 255, blue: 74 / 255, alpha: 1)
        case .blue: UIColor(red: 79 / 255, green: 111 / 255, blue: 140 / 255, alpha: 1)
        case .wood: FieldInk.khaki
        case .green: FieldInk.olive
        }
    }

    private func applyDestroyedAppearance(to node: SKNode) {
        if let shape = node as? SKShapeNode {
            shape.fillColor = shape.name == "barrel"
                ? UIColor(white: 0.18, alpha: 1)
                : UIColor(white: 0.12, alpha: 1)
            shape.strokeColor = UIColor(white: 0.35, alpha: 1)
        }

        node.children.forEach { applyDestroyedAppearance(to: $0) }
    }
}

extension UIColor {
    /// Lighter or darker in HSB brightness; tank turrets and barrels use it on the hull color.
    func tanksShaded(by amount: CGFloat) -> UIColor {
        var hue: CGFloat = 0
        var saturation: CGFloat = 0
        var brightness: CGFloat = 0
        var alpha: CGFloat = 0
        guard getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: &alpha) else {
            return self
        }
        return UIColor(
            hue: hue,
            saturation: saturation,
            brightness: min(1, max(0, brightness + amount)),
            alpha: alpha
        )
    }
}
