import QuartzCore
import SpriteKit
import UIKit

final class HouseSwitchScene: SKScene, SKPhysicsContactDelegate {
    var onProgress: ((Double, TimeInterval) -> Void)?
    var onFlip: (() -> Void)?
    var onBlockedFlip: (() -> Void)?
    var onBoost: (() -> Void)?
    var onCrash: ((HouseSwitchCrashReason) -> Void)?
    var onFinish: (() -> Void)?
    var reduceMotion = false

    private enum RunState {
        case ready
        case running
        case ended
    }

    private let level: HouseSwitchLevel
    private let player = SKNode()
    private let cameraNode = SKCameraNode()

    private var gravityDirection: HouseSwitchGravity = .down
    private var runState: RunState = .ready
    private var runClock = HouseSwitchRunClock()
    private var elapsedTime: TimeInterval = 0
    private var lastPublishedTime: TimeInterval = 0
    private var lastFrameTime: TimeInterval = 0
    private var coursePositionX: CGFloat = HouseSwitchHorizontalLayout.originalSpawnX
    private var boostedUntil: TimeInterval = 0
    private var activatedBoosts: Set<Int> = []
    private var hasBuiltScene = false

    private let playerSize = CGSize(width: 34, height: 42)
    private let boostExtraSpeed: CGFloat = 110
    private let boostDuration: TimeInterval = 0.65

    private var playerScreenAnchorX: CGFloat {
        HouseSwitchHorizontalLayout.spawnX(for: size.width)
    }

    private var courseOffsetX: CGFloat {
        HouseSwitchHorizontalLayout.courseOffset(for: size.width)
    }

    private var courseEndX: CGFloat {
        level.length + courseOffsetX
    }

    init(size: CGSize, level: HouseSwitchLevel = .firstCourse) {
        self.level = level
        super.init(size: size)
        scaleMode = .resizeFill
        backgroundColor = .clear
        anchorPoint = .zero
    }

    @available(*, unavailable)
    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func didMove(to view: SKView) {
        physicsWorld.contactDelegate = self
        view.allowsTransparency = true
        view.ignoresSiblingOrder = true
        buildCourse()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        guard hasBuiltScene, size.width > 0, size.height > 0 else { return }
        let wasRunning = runState == .running
        let previousYRatio = oldSize.height > 0 ? player.position.y / oldSize.height : 0.13
        let previousPlayerX = player.position.x
        let previousCoursePositionX = coursePositionX
        let offsetChange = courseOffsetX
            - HouseSwitchHorizontalLayout.courseOffset(for: oldSize.width)

        buildCourse()
        player.position.x = wasRunning
            ? previousPlayerX + offsetChange
            : playerScreenAnchorX
        player.position.y = min(size.height - 72, max(72, previousYRatio * size.height))
        player.zRotation = gravityDirection.rotation
        coursePositionX = wasRunning
            ? previousCoursePositionX + offsetChange
            : playerScreenAnchorX
        updateCamera()

        for index in activatedBoosts {
            childNode(withName: "boost-\(index)")?.alpha = 0.42
        }

        if wasRunning {
            player.physicsBody?.isDynamic = true
            player.physicsBody?.velocity = CGVector(dx: HouseSwitchPhysicsTuning.runSpeed, dy: 0)
            runState = .running
            lastFrameTime = 0
        }
    }

    func startRun() {
        gravityDirection = .down
        coursePositionX = playerScreenAnchorX
        boostedUntil = 0
        activatedBoosts.removeAll()
        lastFrameTime = 0
        buildCourse()
        physicsWorld.gravity = gravityVector
        player.zRotation = gravityDirection.rotation
        player.physicsBody?.isDynamic = true
        player.physicsBody?.velocity = CGVector(dx: HouseSwitchPhysicsTuning.runSpeed, dy: 0)
        runState = .running
        isPaused = false
        runClock.start(at: CACurrentMediaTime())
        elapsedTime = 0
        lastPublishedTime = 0
        publishProgress(force: true)
    }

    func pauseRun() {
        guard runState == .running else { return }
        let now = CACurrentMediaTime()
        runClock.pause(at: now)
        elapsedTime = runClock.elapsed(at: now)
        publishProgress(force: true)
        isPaused = true
    }

    func resumeRun() {
        guard runState == .running else { return }
        runClock.resume(at: CACurrentMediaTime())
        lastFrameTime = 0
        isPaused = false
    }

    func stopRun() {
        runState = .ended
        player.physicsBody?.velocity = .zero
        player.physicsBody?.isDynamic = false
        isPaused = true
    }

    func flipGravity() {
        guard runState == .running, !isPaused else { return }
        guard isPlayerSupported else {
            onBlockedFlip?()
            return
        }

        gravityDirection = gravityDirection.opposite
        physicsWorld.gravity = gravityVector

        if let body = player.physicsBody {
            let currentSpeed = abs(body.velocity.dy)
            let launchSpeed = max(
                HouseSwitchPhysicsTuning.switchVelocity(for: size.height),
                currentSpeed * 0.34
            )
            body.velocity.dy = gravityDirection.rawValue * launchSpeed
            body.angularVelocity = 0
        }

        player.removeAction(forKey: "gravityRotation")
        if reduceMotion {
            player.zRotation = gravityDirection.rotation
        } else {
            player.run(
                .rotate(toAngle: gravityDirection.rotation, duration: 0.18, shortestUnitArc: true),
                withKey: "gravityRotation"
            )
            pulsePlayerGlow()
        }
        onFlip?()
    }

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        flipGravity()
    }

    override func update(_ currentTime: TimeInterval) {
        guard runState == .running else { return }

        elapsedTime = runClock.elapsed(at: CACurrentMediaTime())
        let frameDelta = lastFrameTime > 0
            ? min(max(0, currentTime - lastFrameTime), 0.1)
            : 0
        lastFrameTime = currentTime
        coursePositionX = min(
            courseEndX,
            coursePositionX + HouseSwitchPhysicsTuning.runSpeed * CGFloat(frameDelta)
        )

        if let body = player.physicsBody {
            body.velocity.dx = HouseSwitchPhysicsTuning.runSpeed
                + (elapsedTime < boostedUntil ? boostExtraSpeed : 0)
            body.angularVelocity = 0
        }

        updateCamera()
        publishProgress(force: false)

        if player.position.y < -80 || player.position.y > size.height + 80 {
            endRun(finished: false, crashReason: .boundary)
            return
        }

        if HouseSwitchRunMetrics.isCompletelyBehindViewport(
            playerCenterX: player.position.x,
            playerWidth: playerSize.width,
            viewportMinX: cameraNode.position.x - size.width / 2
        ) {
            endRun(finished: false, crashReason: .leftBehind)
        }
    }

    func didBegin(_ contact: SKPhysicsContact) {
        guard runState == .running else { return }

        if HouseSwitchCollisionPolicy.isLethalContact(
            contact.bodyA.categoryBitMask,
            contact.bodyB.categoryBitMask
        ) {
            endRun(finished: false, crashReason: .laser)
            return
        }

        if HouseSwitchCollisionPolicy.isFinishContact(
            contact.bodyA.categoryBitMask,
            contact.bodyB.categoryBitMask
        ) {
            endRun(finished: true)
            return
        }

        if HouseSwitchCollisionPolicy.isGapContact(
            contact.bodyA.categoryBitMask,
            contact.bodyB.categoryBitMask
        ) {
            let sensor = contact.bodyA.categoryBitMask == HouseSwitchPhysicsCategory.gap
                ? contact.bodyA.node
                : contact.bodyB.node
            beginGapFall(from: sensor)
            return
        }

        if HouseSwitchCollisionPolicy.isBoostContact(
            contact.bodyA.categoryBitMask,
            contact.bodyB.categoryBitMask
        ) {
            let sensor = contact.bodyA.categoryBitMask == HouseSwitchPhysicsCategory.boost
                ? contact.bodyA.node
                : contact.bodyB.node
            activateBoost(from: sensor)
        }

        // Solid contacts intentionally have no direct failure path. The course
        // keeps scrolling, so a blocked runner only fails after leaving view.
    }

    private var gravityVector: CGVector {
        CGVector(
            dx: 0,
            dy: gravityDirection.rawValue
                * HouseSwitchPhysicsTuning.gravityStrength(for: size.height)
        )
    }

    private func buildCourse() {
        removeAllChildren()
        removeAllActions()
        hasBuiltScene = true
        runState = .ready
        physicsWorld.gravity = gravityVector

        addChild(cameraNode)
        camera = cameraNode
        cameraNode.position = CGPoint(x: size.width / 2, y: size.height / 2)

        for platform in level.platforms {
            var frame = platform.frame(in: size.height)
            if frame.minX <= 0 {
                frame.size.width += courseOffsetX
            } else {
                frame.origin.x += courseOffsetX
            }
            addPlatform(frame: frame)
        }

        for laser in level.lasers {
            addLaser(laser)
        }

        for (index, gap) in level.gaps.enumerated() {
            addGapSensor(gap, index: index)
        }

        for (index, boost) in level.boosts.enumerated() {
            addBoost(boost, index: index)
        }

        addFinishGate()
        addPlayer()
    }

    private func addPlayer() {
        player.removeAllChildren()
        player.removeAllActions()
        player.position = CGPoint(x: playerScreenAnchorX, y: max(92, size.height * 0.13))
        player.zPosition = 30
        player.zRotation = 0

        let glow = SKShapeNode(ellipseOf: CGSize(width: 46, height: 46))
        glow.name = "playerGlow"
        glow.fillColor = UIColor(red: 0.20, green: 0.90, blue: 0.82, alpha: 0.18)
        glow.strokeColor = .clear
        glow.zPosition = -2
        player.addChild(glow)

        let bodyPath = CGMutablePath()
        bodyPath.move(to: CGPoint(x: -16, y: 3))
        bodyPath.addLine(to: CGPoint(x: 0, y: 20))
        bodyPath.addLine(to: CGPoint(x: 16, y: 3))
        bodyPath.addLine(to: CGPoint(x: 16, y: -18))
        bodyPath.addLine(to: CGPoint(x: -16, y: -18))
        bodyPath.closeSubpath()

        let bodyNode = SKShapeNode(path: bodyPath)
        bodyNode.fillColor = UIColor(red: 0.18, green: 0.82, blue: 0.78, alpha: 1)
        bodyNode.strokeColor = UIColor.white.withAlphaComponent(0.82)
        bodyNode.lineWidth = 2
        bodyNode.glowWidth = 3
        player.addChild(bodyNode)

        let door = SKShapeNode(rectOf: CGSize(width: 8, height: 12), cornerRadius: 2)
        door.position = CGPoint(x: 5, y: -12)
        door.fillColor = UIColor(red: 1.0, green: 0.52, blue: 0.22, alpha: 1)
        door.strokeColor = .clear
        player.addChild(door)

        let window = SKShapeNode(rectOf: CGSize(width: 8, height: 8), cornerRadius: 2)
        window.position = CGPoint(x: -6, y: -3)
        window.fillColor = UIColor(red: 0.05, green: 0.17, blue: 0.28, alpha: 0.9)
        window.strokeColor = UIColor.white.withAlphaComponent(0.35)
        window.lineWidth = 1
        player.addChild(window)

        player.physicsBody = SKPhysicsBody(rectangleOf: playerSize)
        player.physicsBody?.isDynamic = false
        player.physicsBody?.allowsRotation = false
        player.physicsBody?.restitution = 0
        // Rail contact must not slow the runner relative to the scrolling camera.
        player.physicsBody?.friction = 0
        player.physicsBody?.linearDamping = 0
        player.physicsBody?.categoryBitMask = HouseSwitchPhysicsCategory.player
        player.physicsBody?.collisionBitMask = HouseSwitchPhysicsCategory.solid
        player.physicsBody?.contactTestBitMask = HouseSwitchPhysicsCategory.solid
            | HouseSwitchPhysicsCategory.hazard
            | HouseSwitchPhysicsCategory.finish
            | HouseSwitchPhysicsCategory.gap
            | HouseSwitchPhysicsCategory.boost

        addChild(player)
    }

    private func addPlatform(frame: CGRect) {
        let platform = SKShapeNode(rectOf: frame.size, cornerRadius: 8)
        platform.position = CGPoint(x: frame.midX, y: frame.midY)
        platform.fillColor = UIColor(red: 0.07, green: 0.14, blue: 0.24, alpha: 0.98)
        platform.strokeColor = UIColor(red: 0.27, green: 0.86, blue: 0.82, alpha: 0.76)
        platform.lineWidth = 2
        platform.zPosition = 10
        platform.physicsBody = SKPhysicsBody(rectangleOf: frame.size)
        platform.physicsBody?.isDynamic = false
        // Walls still block forward motion; flat surfaces do not drag it.
        platform.physicsBody?.friction = 0
        platform.physicsBody?.restitution = 0
        platform.physicsBody?.categoryBitMask = HouseSwitchPhysicsCategory.solid
        platform.physicsBody?.collisionBitMask = HouseSwitchPhysicsCategory.player
        platform.physicsBody?.contactTestBitMask = 0

        let highlight = SKShapeNode(rectOf: CGSize(width: max(0, frame.width - 12), height: 3), cornerRadius: 1.5)
        highlight.position = CGPoint(x: 0, y: frame.height / 2 - 8)
        highlight.fillColor = UIColor.white.withAlphaComponent(0.18)
        highlight.strokeColor = .clear
        platform.addChild(highlight)

        addChild(platform)
    }

    private func addGapSensor(_ gap: HouseSwitchGapSpec, index: Int) {
        let inset = playerSize.width + 10
        let railEdgeY = gap.anchor == .floor
            ? size.height * 0.07
            : size.height * 0.93
        let sensor = SKNode()
        sensor.name = "gap-\(index)"
        sensor.position = CGPoint(
            x: gap.startX + gap.width / 2 + courseOffsetX,
            y: gap.anchor == .floor
                ? railEdgeY + 5
                : railEdgeY - 5
        )
        sensor.physicsBody = SKPhysicsBody(rectangleOf: CGSize(
            width: max(4, gap.width - 2 * inset),
            height: 36
        ))
        sensor.physicsBody?.isDynamic = false
        sensor.physicsBody?.categoryBitMask = HouseSwitchPhysicsCategory.gap
        sensor.physicsBody?.collisionBitMask = 0
        sensor.physicsBody?.contactTestBitMask = HouseSwitchPhysicsCategory.player
        addChild(sensor)

        for edgeX in [gap.startX - 5, gap.endX + 5] {
            let marker = SKShapeNode(rectOf: CGSize(width: 6, height: 14), cornerRadius: 2)
            marker.position = CGPoint(
                x: edgeX + courseOffsetX,
                y: railEdgeY + (gap.anchor == .floor ? -7 : 7)
            )
            marker.fillColor = UIColor(red: 1.0, green: 0.47, blue: 0.19, alpha: 0.92)
            marker.strokeColor = .clear
            marker.zPosition = 12
            addChild(marker)
        }
    }

    private func addBoost(_ spec: HouseSwitchBoostSpec, index: Int) {
        let pad = SKShapeNode(rectOf: CGSize(width: spec.width, height: 14), cornerRadius: 5)
        pad.name = "boost-\(index)"
        pad.position = CGPoint(
            x: spec.x + courseOffsetX,
            y: spec.anchor == .floor
                ? size.height * 0.07 + 7
                : size.height * 0.93 - 7
        )
        pad.fillColor = UIColor(red: 0.22, green: 0.91, blue: 0.79, alpha: 0.96)
        pad.strokeColor = UIColor.white.withAlphaComponent(0.88)
        pad.lineWidth = 1.5
        pad.glowWidth = 3
        pad.zPosition = 16

        let arrows = CGMutablePath()
        for centerX in stride(from: CGFloat(-17), through: CGFloat(17), by: 17) {
            arrows.move(to: CGPoint(x: centerX - 4, y: -4))
            arrows.addLine(to: CGPoint(x: centerX + 2, y: 0))
            arrows.addLine(to: CGPoint(x: centerX - 4, y: 4))
        }
        let directionMarks = SKShapeNode(path: arrows)
        directionMarks.strokeColor = UIColor(red: 0.03, green: 0.20, blue: 0.25, alpha: 0.9)
        directionMarks.lineWidth = 2
        directionMarks.lineCap = .round
        directionMarks.lineJoin = .round
        pad.addChild(directionMarks)

        pad.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: spec.width, height: 20))
        pad.physicsBody?.isDynamic = false
        pad.physicsBody?.categoryBitMask = HouseSwitchPhysicsCategory.boost
        pad.physicsBody?.collisionBitMask = 0
        pad.physicsBody?.contactTestBitMask = HouseSwitchPhysicsCategory.player
        addChild(pad)
    }

    private func addLaser(_ spec: HouseSwitchLaserSpec) {
        let railInset = max(58, size.height * 0.07)
        let beamLength = max(150, size.height * spec.heightRatio - railInset)
        let beamCenterY: CGFloat
        switch spec.anchor {
        case .floor:
            beamCenterY = railInset + beamLength / 2
        case .ceiling:
            beamCenterY = size.height - railInset - beamLength / 2
        }

        let container = SKNode()
        container.position = CGPoint(x: spec.x + courseOffsetX, y: 0)
        container.zPosition = 18

        let beam = SKShapeNode(rectOf: CGSize(width: 11, height: beamLength), cornerRadius: 5.5)
        beam.name = "laserBeam"
        beam.position = CGPoint(x: 0, y: beamCenterY)
        beam.fillColor = UIColor(red: 1.0, green: 0.34, blue: 0.12, alpha: 1)
        beam.strokeColor = UIColor.white.withAlphaComponent(0.9)
        beam.lineWidth = 2
        beam.glowWidth = 8
        beam.alpha = 0.14
        container.addChild(beam)

        for y in [beamCenterY - beamLength / 2, beamCenterY + beamLength / 2] {
            let emitter = SKShapeNode(ellipseOf: CGSize(width: 34, height: 34))
            emitter.position = CGPoint(x: 0, y: y)
            emitter.fillColor = UIColor(red: 0.09, green: 0.18, blue: 0.27, alpha: 1)
            emitter.strokeColor = UIColor(red: 1.0, green: 0.45, blue: 0.16, alpha: 0.88)
            emitter.lineWidth = 3
            emitter.glowWidth = 2
            container.addChild(emitter)
        }

        addChild(container)
        runLaserCycle(on: beam, initialDelay: spec.initialDelay)
    }

    private func runLaserCycle(on beam: SKShapeNode, initialDelay: TimeInterval) {
        let warning = SKAction.fadeAlpha(to: 0.42, duration: 0.22)

        let activate = SKAction.run { [weak beam] in
            guard let beam else { return }
            beam.alpha = 0.96
            let body = SKPhysicsBody(rectangleOf: beam.frame.size)
            body.isDynamic = false
            body.categoryBitMask = HouseSwitchPhysicsCategory.hazard
            body.collisionBitMask = 0
            body.contactTestBitMask = HouseSwitchPhysicsCategory.player
            beam.physicsBody = body
        }

        let deactivate = SKAction.run { [weak beam] in
            beam?.physicsBody = nil
        }

        let cycle = SKAction.sequence([
            .wait(forDuration: initialDelay),
            warning,
            .wait(forDuration: 0.36),
            activate,
            .wait(forDuration: 1.05),
            deactivate,
            .fadeAlpha(to: 0.14, duration: 0.2),
            .wait(forDuration: 1.35),
        ])
        beam.run(.repeatForever(cycle), withKey: "laserCycle")
    }

    private func addFinishGate() {
        let x = courseEndX - 120
        let gate = SKNode()
        gate.position = CGPoint(x: x, y: size.height / 2)
        gate.zPosition = 16

        let line = SKShapeNode(rectOf: CGSize(width: 5, height: size.height * 0.78), cornerRadius: 2.5)
        line.fillColor = UIColor(red: 0.20, green: 0.90, blue: 0.82, alpha: 0.92)
        line.strokeColor = UIColor.white.withAlphaComponent(0.65)
        line.glowWidth = 5
        gate.addChild(line)

        gate.physicsBody = SKPhysicsBody(rectangleOf: CGSize(width: 16, height: size.height * 0.82))
        gate.physicsBody?.isDynamic = false
        gate.physicsBody?.categoryBitMask = HouseSwitchPhysicsCategory.finish
        gate.physicsBody?.collisionBitMask = 0
        gate.physicsBody?.contactTestBitMask = HouseSwitchPhysicsCategory.player
        addChild(gate)
    }

    private func updateCamera() {
        let minCameraX = size.width / 2
        let maxCameraX = max(minCameraX, courseEndX - size.width / 2)
        let scrollingCameraX = coursePositionX + size.width / 2 - playerScreenAnchorX
        cameraNode.position.x = min(maxCameraX, max(minCameraX, scrollingCameraX))
        cameraNode.position.y = size.height / 2
    }

    private var isPlayerSupported: Bool {
        let probeFrame = HouseSwitchSupportProbe.frame(
            playerPosition: player.position,
            playerSize: playerSize,
            gravity: gravityDirection
        )
        var foundSupport = false

        physicsWorld.enumerateBodies(in: probeFrame) { body, stop in
            guard body.categoryBitMask & HouseSwitchPhysicsCategory.solid != 0 else { return }
            foundSupport = true
            stop.pointee = true
        }

        return foundSupport
    }

    private func beginGapFall(from sensor: SKNode?) {
        guard let name = sensor?.name,
              name.hasPrefix("gap-"),
              let index = Int(name.dropFirst(4)),
              level.gaps.indices.contains(index),
              !isPlayerSupported else { return }

        let gap = level.gaps[index]
        let fallingTowardGap = (gap.anchor == .floor && gravityDirection == .down)
            || (gap.anchor == .ceiling && gravityDirection == .up)
        guard fallingTowardGap else { return }

        let exitSpeed = max(300, size.height * 0.8)
        player.physicsBody?.velocity.dy = gravityDirection.rawValue * exitSpeed
    }

    private func activateBoost(from sensor: SKNode?) {
        guard let name = sensor?.name,
              name.hasPrefix("boost-"),
              let index = Int(name.dropFirst(6)),
              level.boosts.indices.contains(index),
              !activatedBoosts.contains(index),
              isPlayerSupported else { return }

        let boost = level.boosts[index]
        let onBoostRail = (boost.anchor == .floor && gravityDirection == .down)
            || (boost.anchor == .ceiling && gravityDirection == .up)
        guard onBoostRail else { return }

        activatedBoosts.insert(index)
        boostedUntil = max(boostedUntil, elapsedTime + boostDuration)
        sensor?.alpha = 0.42
        if !reduceMotion { pulsePlayerGlow() }
        onBoost?()
    }

    private func pulsePlayerGlow() {
        guard let glow = player.childNode(withName: "playerGlow") else { return }
        glow.removeAllActions()
        glow.setScale(0.82)
        glow.alpha = 0.9
        glow.run(.group([
            .scale(to: 1.35, duration: 0.22),
            .fadeAlpha(to: 0.28, duration: 0.22),
        ]))
    }

    private func publishProgress(force: Bool) {
        guard force || elapsedTime - lastPublishedTime >= 0.08 else { return }
        lastPublishedTime = elapsedTime
        onProgress?(
            HouseSwitchRunMetrics.progress(
                position: coursePositionX - courseOffsetX,
                courseLength: level.length
            ),
            elapsedTime
        )
    }

    private func endRun(
        finished: Bool,
        crashReason: HouseSwitchCrashReason = .boundary
    ) {
        guard runState == .running else { return }
        runState = .ended
        elapsedTime = runClock.elapsed(at: CACurrentMediaTime())
        player.physicsBody?.velocity = .zero
        player.physicsBody?.isDynamic = false
        publishProgress(force: true)

        if finished {
            onFinish?()
        } else {
            if !reduceMotion {
                player.run(.sequence([
                    .fadeAlpha(to: 0.22, duration: 0.08),
                    .fadeAlpha(to: 1, duration: 0.12),
                ]))
            }
            onCrash?(crashReason)
        }
    }
}
