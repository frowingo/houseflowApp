import SpriteKit
import UIKit

private enum HouseTanksPhysicsCategory {
    static let tank: UInt32 = 1 << 0
    static let projectile: UInt32 = 1 << 1
    static let obstacle: UInt32 = 1 << 2
    static let wall: UInt32 = 1 << 3
    static let token: UInt32 = 1 << 4
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
    private var currentMap = HouseTanksMapCatalog.definition(for: .livingRoom)
    private var powerUps = HouseTanksPowerUpRules()
    private var nextTokenTime: TimeInterval = 0
    private var tokenNode: SKNode?
    private var powerTextures: [HouseTanksPowerUp: SKTexture] = [:]

    private let fireCooldown: TimeInterval = 0.58
    private let rotationSpeed: CGFloat = 0.88
    private let projectileSpeed: CGFloat = 510
    private let driveForce: CGFloat = 360
    private let tankVisualScale: CGFloat = 0.38
    private let tankSize = CGSize(width: 20, height: 14)
    private let projectileSize = CGSize(width: 9, height: 3.5)

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
        let preserveLayout = hasBuiltArena && oldSize.width > 0 && oldSize.height > 0
        let crates = Dictionary(uniqueKeysWithValues: children.compactMap { node -> (Int, (CGPoint, CGFloat))? in
            guard node.userData?["breaksOnHit"] as? Bool == true,
                  let index = node.userData?["obstacleIndex"] as? Int else { return nil }
            return (index, (node.position, node.zRotation))
        })
        clearToken()
        removeArenaNodes()
        hasBuiltArena = false
        buildArenaIfNeeded()

        if preserveLayout {
            for node in children where node.userData?["breaksOnHit"] as? Bool == true {
                guard let index = node.userData?["obstacleIndex"] as? Int,
                      let previous = crates[index] else {
                    node.removeFromParent()
                    continue
                }
                node.position = CGPoint(x: previous.0.x * size.width / oldSize.width,
                                        y: previous.0.y * size.height / oldSize.height)
                node.zRotation = previous.1
            }
        }

        let spawns = spawnPoints()
        for (index, playerID) in spawnOrder.enumerated() {
            guard let tank = tankNodes[playerID], index < spawns.count else { continue }
            tank.position = preserveLayout
                ? CGPoint(x: tank.position.x * size.width / oldSize.width,
                          y: tank.position.y * size.height / oldSize.height)
                : spawns[index]
            tank.physicsBody?.velocity = .zero
            tank.physicsBody?.angularVelocity = 0
        }
    }

    func prepareRound(players: [HouseTanksPlayer], map: HouseTanksMapDefinition) {
        assert(
            HouseTanksMapCatalog.validationIssues(for: map).isEmpty,
            "House-Tanks map definition is invalid"
        )
        // Rebuild every round to restore destroyed crates and their starting positions.
        currentMap = map
        removeArenaNodes()
        hasBuiltArena = false
        removeRoundNodes()
        buildArenaIfNeeded()
        powerUps = HouseTanksPowerUpRules()
        nextTokenTime = TimeInterval.random(in: HouseTanksPowerUpRules.spawnInterval)
        currentSceneTime = 0
        lastUpdateTime = 0
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
        lastUpdateTime = 0
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
        let power = powerUps.status(for: playerID)?.kind
        let cooldown = power == .rapidFire ? HouseTanksPowerUpRules.rapidFireCooldown : fireCooldown
        let previous = lastFireTime[playerID] ?? -.greatestFiniteMagnitude
        guard currentSceneTime - previous >= cooldown else { return false }
        lastFireTime[playerID] = currentSceneTime

        let offsets: [CGFloat] = power == .spreadShot ? HouseTanksPowerUpRules.spreadAngles : [0]
        for offset in offsets {
            let shotAngle = angle + offset
            let direction = CGVector(dx: cos(shotAngle), dy: sin(shotAngle))
            let startDistance = tankSize.width / 2 + 5
            let start = CGPoint(
                x: tank.position.x + direction.dx * startDistance,
                y: tank.position.y + direction.dy * startDistance
            )
            let projectile = makeProjectile(ownerID: playerID, color: tank.userData?["color"] as? String)
            projectile.position = start
            projectile.zRotation = shotAngle
            projectile.physicsBody?.velocity = CGVector(
                dx: direction.dx * projectileSpeed,
                dy: direction.dy * projectileSpeed
            )
            addChild(projectile)
            // The muzzle may touch a pushed crate or a thin wall. Do not spawn a shot
            // on the far side of that cover just because its center is outside the tank.
            var muzzleBlock: (body: SKPhysicsBody, distance: CGFloat)?
            physicsWorld.enumerateBodies(alongRayStart: tank.position, end: start) { body, point, _, _ in
                guard body.node !== tank,
                      body.categoryBitMask & (HouseTanksPhysicsCategory.obstacle | HouseTanksPhysicsCategory.wall | HouseTanksPhysicsCategory.tank) != 0 else { return }
                let hitDistance = hypot(point.x - tank.position.x, point.y - tank.position.y)
                if hitDistance < (muzzleBlock?.distance ?? .greatestFiniteMagnitude) {
                    muzzleBlock = (body, hitDistance)
                }
            }
            if let muzzleBlock { resolveImpact(projectile: projectile, otherBody: muzzleBlock.body) }
        }

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
        powerUps.remove(playerID: playerID)
        tank.childNode(withName: "power-indicator")?.removeFromParent()

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
        for obstacle in children where obstacle.name == "arena" {
            obstacle.physicsBody?.velocity = .zero
            obstacle.physicsBody?.angularVelocity = 0
        }
        clearToken()
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

        let obstacles = children.filter {
            $0.physicsBody?.categoryBitMask == HouseTanksPhysicsCategory.obstacle
        }.map { $0.calculateAccumulatedFrame() }
        let inset = max(16, size.height * 0.035) + 16
        let goal = powerUps.token.map { token in
            distance(from: tank.position, to: token.position) < 220 ? token.position : target.position
        } ?? target.position
        let waypoint = HouseTanksNavigation.waypoint(
            from: tank.position, to: goal,
            arena: CGRect(origin: .zero, size: size).insetBy(dx: inset, dy: inset),
            obstacles: obstacles
        )
        let targetAngle = atan2(waypoint.y - tank.position.y, waypoint.x - tank.position.x)
        let aimError = abs(HouseTanksMath.normalizedAngle(targetAngle - tank.zRotation))
        return HouseTanksBotObservation(
            aimError: aimError,
            targetDistance: distance(from: tank.position, to: waypoint),
            hasTarget: true
        )
    }

    func stopMatch() {
        gameplayEnabled = false
        removeRoundNodes()
    }

    override func update(_ currentTime: TimeInterval) {
        let delta = lastUpdateTime > 0 ? min(1.0 / 20.0, currentTime - lastUpdateTime) : 0
        lastUpdateTime = currentTime
        guard gameplayEnabled, delta > 0 else { return }
        powerUps.advance(by: delta)
        currentSceneTime = powerUps.time
        updateJokers()

        for playerID in activePlayerIDs {
            guard let tank = tankNodes[playerID] else { continue }
            let power = powerUps.status(for: playerID)?.kind
            let speed: CGFloat = power == .speed ? HouseTanksPowerUpRules.speedMultiplier : 1
            if drivingPlayerIDs.contains(playerID), let direction = drivingDirections[playerID] {
                tank.physicsBody?.applyForce(CGVector(
                    dx: direction.dx * driveForce * speed,
                    dy: direction.dy * driveForce * speed
                ))
                if power == .rapidFire {
                    _ = fire(playerID: playerID, angle: tank.zRotation, tank: tank)
                }
            } else {
                tank.zRotation += rotationSpeed * (rotationDirections[playerID] ?? 1) * delta
            }
            capVelocity(of: tank, maximum: 245 * speed)
            updatePowerIndicator(for: playerID, tank: tank)
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        guard gameplayEnabled else { return }
        let first = contact.bodyA
        let second = contact.bodyB
        if let tokenBody = [first, second].first(where: {
            $0.categoryBitMask == HouseTanksPhysicsCategory.token
        }) {
            guard let node = tokenBody.node, node === tokenNode, node.parent != nil else { return }
            let tankBody = tokenBody === first ? second : first
            if let raw = tankBody.node?.userData?["tankID"] as? String,
               let playerID = UUID(uuidString: raw), activePlayerIDs.contains(playerID),
               powerUps.collect(playerID: playerID) != nil {
                tokenNode?.removeFromParent()
                tokenNode = nil
                if let tank = tankNodes[playerID] { updatePowerIndicator(for: playerID, tank: tank) }
            }
            return
        }
        guard let projectileBody = [first, second].first(where: {
            $0.categoryBitMask & HouseTanksPhysicsCategory.projectile != 0
        }) else { return }

        let otherBody = projectileBody === first ? second : first
        guard let projectile = projectileBody.node else { return }
        resolveImpact(projectile: projectile, otherBody: otherBody)
    }

    private func resolveImpact(projectile: SKNode, otherBody: SKPhysicsBody) {
        // SpriteKit can deliver several contacts for one shot in the same physics step.
        guard projectile.parent != nil,
              projectile.userData?["spent"] as? Bool != true else { return }
        if projectile.userData?["ownerID"] as? String == otherBody.node?.userData?["tankID"] as? String {
            return
        }
        projectile.userData?["spent"] = true
        defer { projectile.removeFromParent() }

        if let obstacle = otherBody.node, obstacle.userData?["breaksOnHit"] as? Bool == true {
            guard obstacle.parent != nil else { return }
            addCrateFragments(at: obstacle.position)
            obstacle.removeFromParent()
            return
        }

        guard otherBody.categoryBitMask & HouseTanksPhysicsCategory.tank != 0,
              let ownerRaw = projectile.userData?["ownerID"] as? String,
              let ownerID = UUID(uuidString: ownerRaw),
              let targetRaw = otherBody.node?.userData?["tankID"] as? String,
              let targetID = UUID(uuidString: targetRaw),
              ownerID != targetID,
              activePlayerIDs.contains(targetID) else { return }

        if powerUps.status(for: targetID)?.kind == .shield {
            showHit(playerID: targetID)
        } else {
            onTankHit?(targetID, ownerID)
        }
    }

    private func buildArenaIfNeeded() {
        guard !hasBuiltArena, size.width > 0, size.height > 0 else { return }
        hasBuiltArena = true

        let mat = SKShapeNode(rect: CGRect(origin: .zero, size: size), cornerRadius: 0)
        mat.name = "arena"
        mat.fillColor = floorColor
        mat.strokeColor = .clear
        mat.zPosition = -20
        addChild(mat)

        addFloorPlanLines()
        addArenaBoundary()
        addObstacles()
    }

    private func addFloorPlanLines() {
        let path = CGMutablePath()
        for line in currentMap.floorLines {
            path.move(to: scenePoint(line.start))
            path.addLine(to: scenePoint(line.end))
        }

        let lines = SKShapeNode(path: path)
        lines.name = "arena"
        lines.strokeColor = floorAccent.withAlphaComponent(0.20)
        lines.lineWidth = max(3, size.height * 0.006)
        lines.lineCap = .round
        lines.zPosition = -15
        addChild(lines)

        for point in currentMap.floorMarkers {
            let marker = SKShapeNode(circleOfRadius: max(5, size.height * 0.010))
            marker.name = "arena"
            marker.position = scenePoint(point)
            marker.fillColor = floorAccent.withAlphaComponent(0.16)
            marker.strokeColor = floorAccent.withAlphaComponent(0.30)
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
            | HouseTanksPhysicsCategory.obstacle
        boundary.physicsBody?.contactTestBitMask = HouseTanksPhysicsCategory.projectile
        addChild(boundary)
    }

    private func addObstacles() {
        for (index, definition) in currentMap.obstacles.enumerated() {
            let obstacleSize = definition.renderedSize(in: size)
            let obstacle = makeObstacle(definition: definition, size: obstacleSize)
            obstacle.name = "arena"
            obstacle.userData = ["obstacleIndex": index, "breaksOnHit": definition.breaksOnHit]
            obstacle.position = scenePoint(definition.center)
            obstacle.zRotation = CGFloat(definition.rotation)
            obstacle.zPosition = 2
            obstacle.physicsBody?.categoryBitMask = HouseTanksPhysicsCategory.obstacle
            obstacle.physicsBody?.collisionBitMask = HouseTanksPhysicsCategory.tank
                | HouseTanksPhysicsCategory.projectile
                | HouseTanksPhysicsCategory.obstacle
                | HouseTanksPhysicsCategory.wall
            obstacle.physicsBody?.contactTestBitMask = HouseTanksPhysicsCategory.projectile
            addChild(obstacle)
        }
    }

    private func makeObstacle(
        definition: HouseTanksObstacleDefinition,
        size obstacleSize: CGSize
    ) -> SKShapeNode {
        let obstacle: SKShapeNode

        switch definition.style {
        case .roundTable, .pillar, .planter:
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

        obstacle.fillColor = obstacleColor(for: definition.isMovable ? .wood : definition.tone)
        obstacle.strokeColor = UIColor.white.withAlphaComponent(0.46)
        obstacle.lineWidth = 1.6
        obstacle.physicsBody?.isDynamic = definition.isMovable
        if definition.isMovable {
            obstacle.physicsBody?.mass = 0.45
            obstacle.physicsBody?.linearDamping = 4
            obstacle.physicsBody?.angularDamping = 5
            obstacle.physicsBody?.friction = 0.55
            obstacle.physicsBody?.restitution = 0.05
        }
        decorateObstacle(obstacle, style: definition.style, size: obstacleSize)
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
            | HouseTanksPhysicsCategory.token

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
        projectile.lineWidth = 1
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
        let flash = SKShapeNode(circleOfRadius: 3)
        flash.fillColor = color(for: HouseTanksColor(rawValue: colorName ?? "") ?? .teal)
        flash.strokeColor = UIColor.white
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
                ? UIColor(red: 0.96, green: 0.48, blue: 0.20, alpha: 1)
                : UIColor(red: 1.00, green: 0.78, blue: 0.28, alpha: 1)
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

    func powerUpStatus(for playerID: UUID) -> HouseTanksPowerUpStatus? {
        powerUps.status(for: playerID)
    }

    private func updateJokers() {
        if powerUps.token == nil {
            tokenNode?.removeFromParent()
            tokenNode = nil
        }
        if let token = powerUps.token, let node = tokenNode {
            updateTimerArc(on: node, fraction: (token.expiresAt - powerUps.time) / HouseTanksPowerUpRules.tokenLifetime, radius: 17)
        }
        guard powerUps.token == nil, powerUps.time >= nextTokenTime else { return }
        // Keep tokens clear of the top HUD, walls, initial spawns and current actors.
        let spawnArea = CGRect(x: 48, y: 44, width: size.width - 96, height: size.height - 124)
        guard spawnArea.width > 0, spawnArea.height > 0 else { return }
        let blocked = children.filter {
            $0.physicsBody?.categoryBitMask == HouseTanksPhysicsCategory.obstacle
        }.map { $0.calculateAccumulatedFrame() }
        let tanks = activePlayerIDs.compactMap { tankNodes[$0]?.position }
        for _ in 0..<80 {
            let point = CGPoint(x: CGFloat.random(in: spawnArea.minX...spawnArea.maxX),
                                y: CGFloat.random(in: spawnArea.minY...spawnArea.maxY))
            guard HouseTanksPowerUpRules.isValidSpawn(
                point, arena: spawnArea, starts: spawnPoints(), tanks: tanks, obstacles: blocked
            ) else { continue }
            let kind = HouseTanksPowerUp.allCases.randomElement() ?? .speed
            guard powerUps.spawn(kind: kind, at: point) else { return }
            let node = SKShapeNode(circleOfRadius: 14)
            node.name = "joker"
            node.position = point
            node.zPosition = 6
            node.fillColor = powerColor(kind)
            node.strokeColor = .white
            node.lineWidth = 1.5
            node.addChild(powerIcon(kind, side: 16))
            node.physicsBody = SKPhysicsBody(circleOfRadius: 16)
            node.physicsBody?.isDynamic = false
            node.physicsBody?.categoryBitMask = HouseTanksPhysicsCategory.token
            node.physicsBody?.collisionBitMask = 0
            node.physicsBody?.contactTestBitMask = HouseTanksPhysicsCategory.tank
            addChild(node)
            tokenNode = node
            updateTimerArc(on: node, fraction: 1, radius: 17)
            nextTokenTime = powerUps.time + TimeInterval.random(in: HouseTanksPowerUpRules.spawnInterval)
            return
        }
        // A crowded arena skips this attempt instead of placing a token in an unfair location.
        nextTokenTime = powerUps.time + 1
    }

    private func clearToken() {
        tokenNode?.removeFromParent()
        tokenNode = nil
        powerUps.removeToken()
    }

    private func updatePowerIndicator(for playerID: UUID, tank: SKNode) {
        guard let status = powerUps.status(for: playerID) else {
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
            badge.strokeColor = .white
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
            arc.strokeColor = UIColor(red: 0.23, green: 0.18, blue: 0.11, alpha: 1)
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
        if powerTextures[kind] == nil,
           let icon = UIImage(systemName: kind.symbolName,
                              withConfiguration: UIImage.SymbolConfiguration(pointSize: 18, weight: .bold)) {
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
        switch kind {
        case .speed: UIColor(red: 0.24, green: 0.38, blue: 0.13, alpha: 1)
        case .rapidFire: UIColor(red: 0.66, green: 0.23, blue: 0.10, alpha: 1)
        case .spreadShot: UIColor(red: 0.43, green: 0.22, blue: 0.57, alpha: 1)
        case .shield: UIColor(red: 0.16, green: 0.34, blue: 0.61, alpha: 1)
        }
    }

    private var floorColor: UIColor {
        switch currentMap.id {
        case .livingRoom: UIColor(red: 0.88, green: 0.81, blue: 0.68, alpha: 1)
        case .corridors: UIColor(red: 0.73, green: 0.80, blue: 0.87, alpha: 1)
        case .warehouse: UIColor(red: 0.83, green: 0.73, blue: 0.66, alpha: 1)
        case .courtyard: UIColor(red: 0.75, green: 0.83, blue: 0.68, alpha: 1)
        }
    }

    private var floorAccent: UIColor {
        switch currentMap.id {
        case .livingRoom: obstacleColor(for: .wood)
        case .corridors: obstacleColor(for: .blue)
        case .warehouse: obstacleColor(for: .orange)
        case .courtyard: obstacleColor(for: .green)
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

    private func spawnPoints() -> [CGPoint] {
        currentMap.spawnPoints.map(scenePoint)
    }

    private func removeRoundNodes() {
        clearToken()
        powerUps = HouseTanksPowerUpRules()
        children.filter { $0.name == "effect" }.forEach { $0.removeFromParent() }
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

    private func scenePoint(_ point: HouseTanksNormalizedPoint) -> CGPoint {
        CGPoint(x: size.width * CGFloat(point.x), y: size.height * CGFloat(point.y))
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

    private func obstacleColor(for tone: HouseTanksObstacleTone) -> UIColor {
        switch tone {
        case .navy: UIColor(red: 0.18, green: 0.27, blue: 0.32, alpha: 1)
        case .teal: UIColor(red: 0.24, green: 0.47, blue: 0.45, alpha: 1)
        case .orange: UIColor(red: 0.84, green: 0.43, blue: 0.22, alpha: 1)
        case .blue: UIColor(red: 0.33, green: 0.42, blue: 0.64, alpha: 1)
        case .wood: UIColor(red: 0.58, green: 0.43, blue: 0.25, alpha: 1)
        case .green: UIColor(red: 0.28, green: 0.50, blue: 0.34, alpha: 1)
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
