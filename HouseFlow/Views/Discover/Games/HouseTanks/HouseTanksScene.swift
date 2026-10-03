import SpriteKit
import UIKit

private enum HouseTanksPhysicsCategory {
    static let tank: UInt32 = 1 << 0
    static let projectile: UInt32 = 1 << 1
    static let obstacle: UInt32 = 1 << 2
    static let wall: UInt32 = 1 << 3
}

private enum HouseTanksObstacleStyle {
    case divider
    case sofa
    case roundTable
    case crate
}

private struct HouseTanksObstacleSpec {
    let x: CGFloat
    let y: CGFloat
    let width: CGFloat
    let height: CGFloat
    let rotation: CGFloat
    let color: UIColor
    let style: HouseTanksObstacleStyle
}

final class HouseTanksScene: SKScene, SKPhysicsContactDelegate {
    var onTankHit: ((UUID, UUID) -> Void)?

    private var tankNodes: [UUID: SKNode] = [:]
    private var spawnOrder: [UUID] = []
    private var activePlayerIDs = Set<UUID>()
    private var lastFireTime: [UUID: TimeInterval] = [:]
    private var rotationDirections: [UUID: CGFloat] = [:]
    private var drivingPlayerIDs = Set<UUID>()
    private var drivingDirections: [UUID: CGVector] = [:]
    private var currentSceneTime: TimeInterval = 0
    private var lastUpdateTime: TimeInterval = 0
    private var hasBuiltArena = false
    private var gameplayEnabled = false
    private var reduceMotion = false

    private let fireCooldown: TimeInterval = 0.58
    private let rotationSpeed: CGFloat = 0.88
    private let projectileSpeed: CGFloat = 510
    private let driveForce: CGFloat = 360
    private let obstacleScale: CGFloat = 0.72
    private let tankVisualScale: CGFloat = 0.76
    private let tankSize = CGSize(width: 40, height: 28)
    private let projectileSize = CGSize(width: 18, height: 7)

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = UIColor(red: 0.13, green: 0.18, blue: 0.21, alpha: 1)
        physicsWorld.gravity = .zero
        physicsWorld.contactDelegate = self
        buildArenaIfNeeded()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0 else { return }
        removeArenaNodes()
        hasBuiltArena = false
        buildArenaIfNeeded()

        let spawns = spawnPoints()
        for (index, playerID) in spawnOrder.enumerated() {
            guard let tank = tankNodes[playerID], index < spawns.count else { continue }
            tank.position = spawns[index]
            tank.physicsBody?.velocity = .zero
            tank.physicsBody?.angularVelocity = 0
        }
    }

    func prepareRound(players: [HouseTanksPlayer]) {
        buildArenaIfNeeded()
        removeRoundNodes()
        gameplayEnabled = false
        lastFireTime.removeAll()
        drivingPlayerIDs.removeAll()
        drivingDirections.removeAll()
        activePlayerIDs = Set(players.filter(\.isAlive).map(\.id))
        spawnOrder = players.map(\.id)

        let spawns = spawnPoints()
        for (index, player) in players.enumerated() {
            let spawn = spawns[min(index, spawns.count - 1)]
            let rotation: CGFloat = index == 0 ? 0 : (index == 1 ? .pi * 0.92 : -.pi * 0.92)
            let node = makeTank(player: player, position: spawn, rotation: rotation)
            tankNodes[player.id] = node
            rotationDirections[player.id] = index == 1 ? -1 : 1
            addChild(node)
        }
    }

    func setGameplayEnabled(_ enabled: Bool) {
        gameplayEnabled = enabled
        if !enabled {
            enumerateChildNodes(withName: "//projectile") { projectile, _ in
                projectile.removeFromParent()
            }
        }
    }

    func setSimulationPaused(_ paused: Bool) {
        isPaused = paused
    }

    func setReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
    }

    @discardableResult
    func beginPress(playerID: UUID) -> Bool {
        guard gameplayEnabled,
              activePlayerIDs.contains(playerID),
              !drivingPlayerIDs.contains(playerID),
              let tank = tankNodes[playerID] else { return false }

        let angle = tank.zRotation
        drivingPlayerIDs.insert(playerID)
        drivingDirections[playerID] = CGVector(dx: cos(angle), dy: sin(angle))
        tank.physicsBody?.angularVelocity = 0

        return fire(playerID: playerID, angle: angle, tank: tank)
    }

    func endPress(playerID: UUID) {
        guard drivingPlayerIDs.remove(playerID) != nil else { return }
        drivingDirections[playerID] = nil
        tankNodes[playerID]?.physicsBody?.velocity = .zero
        let previousDirection = rotationDirections[playerID] ?? 1
        rotationDirections[playerID] = HouseTanksMath.oppositeRotationDirection(
            after: previousDirection
        )
    }

    @discardableResult
    private func fire(playerID: UUID, angle: CGFloat, tank: SKNode) -> Bool {

        let previous = lastFireTime[playerID] ?? -.greatestFiniteMagnitude
        guard currentSceneTime - previous >= fireCooldown else { return false }
        lastFireTime[playerID] = currentSceneTime

        let direction = CGVector(dx: cos(angle), dy: sin(angle))
        let startDistance = tankSize.width / 2 + 10
        let start = CGPoint(
            x: tank.position.x + direction.dx * startDistance,
            y: tank.position.y + direction.dy * startDistance
        )

        let projectile = makeProjectile(ownerID: playerID, color: tank.userData?["color"] as? String)
        projectile.position = start
        projectile.zRotation = angle
        projectile.physicsBody?.velocity = CGVector(
            dx: direction.dx * projectileSpeed,
            dy: direction.dy * projectileSpeed
        )
        addChild(projectile)

        addMuzzleFlash(to: tank, colorName: tank.userData?["color"] as? String)
        return true
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

    func eliminate(playerID: UUID) {
        guard activePlayerIDs.remove(playerID) != nil, let tank = tankNodes[playerID] else { return }
        tank.physicsBody?.velocity = .zero
        tank.physicsBody?.angularVelocity = 0
        tank.physicsBody?.isDynamic = false
        tank.physicsBody?.categoryBitMask = HouseTanksPhysicsCategory.obstacle
        tank.physicsBody?.collisionBitMask = HouseTanksPhysicsCategory.tank
            | HouseTanksPhysicsCategory.projectile
        tank.physicsBody?.contactTestBitMask = HouseTanksPhysicsCategory.projectile
        rotationDirections[playerID] = nil
        drivingPlayerIDs.remove(playerID)
        drivingDirections[playerID] = nil

        if let artwork = tank.childNode(withName: "artwork") {
            artwork.childNode(withName: "aura")?.removeFromParent()
            applyDestroyedAppearance(to: artwork)
        }
        addExplosion(at: tank.position)
    }

    func freezeActors() {
        gameplayEnabled = false
        enumerateChildNodes(withName: "//projectile") { node, _ in
            node.removeFromParent()
        }
        for tank in tankNodes.values {
            tank.physicsBody?.velocity = .zero
            tank.physicsBody?.angularVelocity = 0
        }
        drivingPlayerIDs.removeAll()
        drivingDirections.removeAll()
    }

    func botObservation(for playerID: UUID) -> HouseTanksBotObservation {
        guard activePlayerIDs.contains(playerID), let tank = tankNodes[playerID] else {
            return HouseTanksBotObservation(aimError: .pi, targetDistance: 0, hasTarget: false)
        }

        let opponents = activePlayerIDs.compactMap { id -> SKNode? in
            guard id != playerID else { return nil }
            return tankNodes[id]
        }
        guard let target = opponents.min(by: {
            distance(from: tank.position, to: $0.position) < distance(from: tank.position, to: $1.position)
        }) else {
            return HouseTanksBotObservation(aimError: .pi, targetDistance: 0, hasTarget: false)
        }

        let targetAngle = atan2(target.position.y - tank.position.y, target.position.x - tank.position.x)
        let aimError = abs(HouseTanksMath.normalizedAngle(targetAngle - tank.zRotation))
        return HouseTanksBotObservation(
            aimError: aimError,
            targetDistance: distance(from: tank.position, to: target.position),
            hasTarget: true
        )
    }

    func stopMatch() {
        gameplayEnabled = false
        removeRoundNodes()
    }

    override func update(_ currentTime: TimeInterval) {
        currentSceneTime = currentTime
        let delta = lastUpdateTime > 0 ? min(1.0 / 20.0, currentTime - lastUpdateTime) : 0
        lastUpdateTime = currentTime
        guard gameplayEnabled, delta > 0 else { return }

        for playerID in activePlayerIDs {
            guard let tank = tankNodes[playerID] else { continue }
            if drivingPlayerIDs.contains(playerID), let direction = drivingDirections[playerID] {
                tank.physicsBody?.applyForce(CGVector(
                    dx: direction.dx * driveForce,
                    dy: direction.dy * driveForce
                ))
            } else {
                tank.zRotation += rotationSpeed * (rotationDirections[playerID] ?? 1) * delta
            }
            capVelocity(of: tank, maximum: 245)
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        let first = contact.bodyA
        let second = contact.bodyB
        guard let projectileBody = [first, second].first(where: {
            $0.categoryBitMask & HouseTanksPhysicsCategory.projectile != 0
        }) else { return }

        let otherBody = projectileBody === first ? second : first
        defer { projectileBody.node?.removeFromParent() }

        guard otherBody.categoryBitMask & HouseTanksPhysicsCategory.tank != 0,
              let ownerRaw = projectileBody.node?.userData?["ownerID"] as? String,
              let ownerID = UUID(uuidString: ownerRaw),
              let targetRaw = otherBody.node?.userData?["tankID"] as? String,
              let targetID = UUID(uuidString: targetRaw),
              ownerID != targetID,
              activePlayerIDs.contains(targetID) else { return }

        onTankHit?(targetID, ownerID)
    }

    private func buildArenaIfNeeded() {
        guard !hasBuiltArena, size.width > 0, size.height > 0 else { return }
        hasBuiltArena = true

        let mat = SKShapeNode(rect: CGRect(origin: .zero, size: size), cornerRadius: 0)
        mat.name = "arena"
        mat.fillColor = UIColor(red: 0.86, green: 0.80, blue: 0.69, alpha: 1)
        mat.strokeColor = .clear
        mat.zPosition = -20
        addChild(mat)

        addFloorPlanLines()
        addArenaBoundary()
        addObstacles()
    }

    private func addFloorPlanLines() {
        let path = CGMutablePath()
        path.move(to: CGPoint(x: size.width * 0.10, y: size.height * 0.50))
        path.addLine(to: CGPoint(x: size.width * 0.28, y: size.height * 0.50))
        path.addLine(to: CGPoint(x: size.width * 0.28, y: size.height * 0.78))
        path.move(to: CGPoint(x: size.width * 0.72, y: size.height * 0.22))
        path.addLine(to: CGPoint(x: size.width * 0.72, y: size.height * 0.50))
        path.addLine(to: CGPoint(x: size.width * 0.90, y: size.height * 0.50))

        let lines = SKShapeNode(path: path)
        lines.name = "arena"
        lines.strokeColor = UIColor(red: 0.25, green: 0.39, blue: 0.38, alpha: 0.18)
        lines.lineWidth = max(3, size.height * 0.006)
        lines.lineCap = .round
        lines.zPosition = -15
        addChild(lines)

        for point in [
            CGPoint(x: size.width * 0.12, y: size.height * 0.20),
            CGPoint(x: size.width * 0.88, y: size.height * 0.80),
            CGPoint(x: size.width * 0.50, y: size.height * 0.12),
            CGPoint(x: size.width * 0.50, y: size.height * 0.88),
        ] {
            let marker = SKShapeNode(circleOfRadius: max(8, size.height * 0.018))
            marker.name = "arena"
            marker.position = point
            marker.fillColor = UIColor(red: 0.20, green: 0.58, blue: 0.53, alpha: 0.18)
            marker.strokeColor = UIColor(red: 0.20, green: 0.58, blue: 0.53, alpha: 0.30)
            marker.lineWidth = 2
            marker.zPosition = -14
            addChild(marker)
        }
    }

    private func addArenaBoundary() {
        let inset = max(16, size.height * 0.035)
        let frame = CGRect(x: inset, y: inset, width: size.width - inset * 2, height: size.height - inset * 2)
        let boundary = SKShapeNode(rect: frame, cornerRadius: 26)
        boundary.name = "arena"
        boundary.strokeColor = UIColor(red: 0.12, green: 0.22, blue: 0.25, alpha: 0.80)
        boundary.lineWidth = max(8, size.height * 0.018)
        boundary.fillColor = .clear
        boundary.zPosition = -10
        boundary.physicsBody = SKPhysicsBody(edgeLoopFrom: frame)
        boundary.physicsBody?.categoryBitMask = HouseTanksPhysicsCategory.wall
        boundary.physicsBody?.collisionBitMask = HouseTanksPhysicsCategory.tank
            | HouseTanksPhysicsCategory.projectile
        boundary.physicsBody?.contactTestBitMask = HouseTanksPhysicsCategory.projectile
        addChild(boundary)
    }

    private func addObstacles() {
        let specs: [HouseTanksObstacleSpec] = [
            HouseTanksObstacleSpec(
                x: 0.50, y: 0.50, width: 0.07, height: 0.28, rotation: 0,
                color: UIColor(red: 0.18, green: 0.27, blue: 0.32, alpha: 1), style: .divider
            ),
            HouseTanksObstacleSpec(
                x: 0.31, y: 0.30, width: 0.18, height: 0.075, rotation: 0.04,
                color: UIColor(red: 0.24, green: 0.47, blue: 0.45, alpha: 1), style: .sofa
            ),
            HouseTanksObstacleSpec(
                x: 0.69, y: 0.70, width: 0.18, height: 0.075, rotation: -0.04,
                color: UIColor(red: 0.84, green: 0.43, blue: 0.22, alpha: 1), style: .sofa
            ),
            HouseTanksObstacleSpec(
                x: 0.30, y: 0.72, width: 0.12, height: 0.12, rotation: 0,
                color: UIColor(red: 0.33, green: 0.42, blue: 0.64, alpha: 1), style: .roundTable
            ),
            HouseTanksObstacleSpec(
                x: 0.70, y: 0.28, width: 0.10, height: 0.10, rotation: .pi / 12,
                color: UIColor(red: 0.58, green: 0.43, blue: 0.25, alpha: 1), style: .crate
            ),
        ]

        for spec in specs {
            let obstacleSize: CGSize
            switch spec.style {
            case .roundTable, .crate:
                let side = size.height * spec.height * obstacleScale
                obstacleSize = CGSize(width: side, height: side)
            case .divider, .sofa:
                obstacleSize = CGSize(
                    width: size.width * spec.width * obstacleScale,
                    height: size.height * spec.height * obstacleScale
                )
            }
            let obstacle = makeObstacle(spec: spec, size: obstacleSize)
            obstacle.name = "arena"
            obstacle.position = CGPoint(x: size.width * spec.x, y: size.height * spec.y)
            obstacle.zRotation = spec.rotation
            obstacle.zPosition = 2
            obstacle.physicsBody?.categoryBitMask = HouseTanksPhysicsCategory.obstacle
            obstacle.physicsBody?.collisionBitMask = HouseTanksPhysicsCategory.tank
                | HouseTanksPhysicsCategory.projectile
            obstacle.physicsBody?.contactTestBitMask = HouseTanksPhysicsCategory.projectile
            addChild(obstacle)
        }
    }

    private func makeObstacle(
        spec: HouseTanksObstacleSpec,
        size obstacleSize: CGSize
    ) -> SKShapeNode {
        let obstacle: SKShapeNode

        switch spec.style {
        case .roundTable:
            let diameter = min(obstacleSize.width, obstacleSize.height)
            obstacle = SKShapeNode(circleOfRadius: diameter / 2)
            obstacle.physicsBody = SKPhysicsBody(circleOfRadius: diameter / 2)
        default:
            obstacle = SKShapeNode(
                rectOf: obstacleSize,
                cornerRadius: min(14, obstacleSize.height * 0.28)
            )
            obstacle.physicsBody = SKPhysicsBody(rectangleOf: obstacleSize)
        }

        obstacle.fillColor = spec.color
        obstacle.strokeColor = UIColor.white.withAlphaComponent(0.46)
        obstacle.lineWidth = 2.4
        obstacle.physicsBody?.isDynamic = false
        decorateObstacle(obstacle, style: spec.style, size: obstacleSize)
        return obstacle
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
        }
    }

    private func makeTank(
        player: HouseTanksPlayer,
        position: CGPoint,
        rotation: CGFloat
    ) -> SKNode {
        let root = SKNode()
        root.name = "tank"
        root.position = position
        root.zRotation = rotation
        root.zPosition = 10
        root.userData = [
            "tankID": player.id.uuidString,
            "color": player.color.rawValue,
        ]
        root.physicsBody = SKPhysicsBody(rectangleOf: tankSize)
        root.physicsBody?.allowsRotation = false
        root.physicsBody?.linearDamping = 1.8
        root.physicsBody?.restitution = 0.36
        root.physicsBody?.friction = 0.28
        root.physicsBody?.mass = 1.25
        root.physicsBody?.categoryBitMask = HouseTanksPhysicsCategory.tank
        root.physicsBody?.collisionBitMask = HouseTanksPhysicsCategory.tank
            | HouseTanksPhysicsCategory.obstacle
            | HouseTanksPhysicsCategory.wall
        root.physicsBody?.contactTestBitMask = HouseTanksPhysicsCategory.projectile

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
        leftTrack.fillColor = UIColor(red: 0.08, green: 0.12, blue: 0.14, alpha: 1)
        leftTrack.strokeColor = UIColor.white.withAlphaComponent(0.20)
        artwork.addChild(leftTrack)

        let rightTrack = leftTrack.copy() as! SKShapeNode
        rightTrack.position.y = -17
        artwork.addChild(rightTrack)

        let hull = SKShapeNode(rectOf: CGSize(width: 44, height: 30), cornerRadius: 9)
        hull.name = "hull"
        hull.fillColor = tint
        hull.strokeColor = UIColor.white.withAlphaComponent(0.84)
        hull.lineWidth = 2.5
        hull.zPosition = 1
        artwork.addChild(hull)

        let turret = SKShapeNode(circleOfRadius: 10)
        turret.name = "turret"
        turret.fillColor = tint.adjustedBrightness(-0.10)
        turret.strokeColor = UIColor.white.withAlphaComponent(0.72)
        turret.lineWidth = 2
        turret.zPosition = 2
        artwork.addChild(turret)

        let barrel = SKShapeNode(rectOf: CGSize(width: 31, height: 8), cornerRadius: 4)
        barrel.name = "barrel"
        barrel.position.x = 18
        barrel.fillColor = tint.adjustedBrightness(-0.16)
        barrel.strokeColor = UIColor.white.withAlphaComponent(0.70)
        barrel.lineWidth = 1.5
        barrel.zPosition = 1
        turret.addChild(barrel)

        return root
    }

    private func makeProjectile(ownerID: UUID, color colorName: String?) -> SKNode {
        let projectile = SKShapeNode(
            rectOf: projectileSize,
            cornerRadius: projectileSize.height / 2
        )
        projectile.name = "projectile"
        projectile.fillColor = color(for: HouseTanksColor(rawValue: colorName ?? "") ?? .teal)
        projectile.strokeColor = UIColor.white.withAlphaComponent(0.92)
        projectile.lineWidth = 2
        projectile.zPosition = 8
        projectile.userData = ["ownerID": ownerID.uuidString]
        projectile.physicsBody = SKPhysicsBody(rectangleOf: projectileSize)
        projectile.physicsBody?.affectedByGravity = false
        projectile.physicsBody?.linearDamping = 0
        projectile.physicsBody?.restitution = 0
        projectile.physicsBody?.usesPreciseCollisionDetection = true
        projectile.physicsBody?.categoryBitMask = HouseTanksPhysicsCategory.projectile
        projectile.physicsBody?.collisionBitMask = HouseTanksPhysicsCategory.tank
            | HouseTanksPhysicsCategory.obstacle
            | HouseTanksPhysicsCategory.wall
        projectile.physicsBody?.contactTestBitMask = projectile.physicsBody?.collisionBitMask ?? 0
        projectile.run(.sequence([.wait(forDuration: 2.8), .removeFromParent()]))
        return projectile
    }

    private func addMuzzleFlash(to tank: SKNode, colorName: String?) {
        guard !reduceMotion else { return }
        let flash = SKShapeNode(circleOfRadius: 6)
        flash.fillColor = color(for: HouseTanksColor(rawValue: colorName ?? "") ?? .teal)
        flash.strokeColor = UIColor.white
        flash.lineWidth = 2
        flash.position = CGPoint(x: tankSize.width / 2 + 6, y: 0)
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
            let shard = SKShapeNode(circleOfRadius: reduceMotion ? 3 : 5)
            shard.fillColor = index.isMultiple(of: 2)
                ? UIColor(red: 0.96, green: 0.48, blue: 0.20, alpha: 1)
                : UIColor(red: 1.00, green: 0.78, blue: 0.28, alpha: 1)
            shard.strokeColor = .clear
            shard.position = position
            shard.zPosition = 20
            addChild(shard)

            let angle = CGFloat(index) / CGFloat(max(1, count)) * .pi * 2
            let distance: CGFloat = reduceMotion ? 22 : 54
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

    private func spawnPoints() -> [CGPoint] {
        [
            CGPoint(x: size.width * 0.18, y: size.height * 0.50),
            CGPoint(x: size.width * 0.80, y: size.height * 0.25),
            CGPoint(x: size.width * 0.80, y: size.height * 0.75),
        ]
    }

    private func removeRoundNodes() {
        enumerateChildNodes(withName: "//tank") { node, _ in node.removeFromParent() }
        enumerateChildNodes(withName: "//projectile") { node, _ in node.removeFromParent() }
        tankNodes.removeAll()
        spawnOrder.removeAll()
        activePlayerIDs.removeAll()
        rotationDirections.removeAll()
        drivingPlayerIDs.removeAll()
        drivingDirections.removeAll()
    }

    private func removeArenaNodes() {
        children.filter { $0.name == "arena" }.forEach { $0.removeFromParent() }
    }

    private func distance(from first: CGPoint, to second: CGPoint) -> CGFloat {
        hypot(second.x - first.x, second.y - first.y)
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

    private func capVelocity(of node: SKNode, maximum: CGFloat) {
        guard let body = node.physicsBody else { return }
        let speed = hypot(body.velocity.dx, body.velocity.dy)
        guard speed > maximum, speed > 0 else { return }
        let scale = maximum / speed
        body.velocity = CGVector(dx: body.velocity.dx * scale, dy: body.velocity.dy * scale)
    }

    private func color(for color: HouseTanksColor) -> UIColor {
        switch color {
        case .teal: UIColor(red: 0.12, green: 0.74, blue: 0.65, alpha: 1)
        case .orange: UIColor(red: 0.95, green: 0.43, blue: 0.18, alpha: 1)
        case .blue: UIColor(red: 0.24, green: 0.48, blue: 0.88, alpha: 1)
        }
    }
}

private extension UIColor {
    func adjustedBrightness(_ amount: CGFloat) -> UIColor {
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
