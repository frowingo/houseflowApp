import SpriteKit
import UIKit

/// Renders session snapshots. It never advances physics or decides eliminations.
final class HouseRocketsScene: SKScene {
    /// Samples an injected presentation source at the device's rendering cadence.
    var frameProvider: (() -> HouseRocketsRenderFrame?)?
    private let world = SKCropNode()
    private let worldMask = SKSpriteNode(color: .white, size: .zero)
    private let environment = SKNode()
    private var trackSurfaces: [SKShapeNode] = []
    private var rocketNodes: [String: SKNode] = [:]
    private var flames: [String: SKShapeNode] = [:]
    private var gateNodes: [String: SKNode] = [:]
    private var fieldNodes: [String: SKNode] = [:]
    private var trackDashes: [SKShapeNode] = []
    private var renderFrame: HouseRocketsRenderFrame?
    private var reduceMotion = false

    override func didMove(to view: SKView) {
        scaleMode = .resizeFill
        backgroundColor = HouseRocketsPalette.outer
        if world.parent == nil { addChild(world) }
        drawEnvironment()
        renderWorld()
    }

    override func didChangeSize(_ oldSize: CGSize) {
        super.didChangeSize(oldSize)
        guard size.width > 0, size.height > 0 else { return }
        drawEnvironment()
        renderWorld()
    }

    override func update(_ currentTime: TimeInterval) {
        if let incoming = frameProvider?() { applyFrame(incoming) }
    }

    func applySnapshot(_ incoming: HouseRocketsSnapshot) {
        applyFrame(HouseRocketsRenderMapper.local(incoming))
    }

    func applyFrame(_ incoming: HouseRocketsRenderFrame) {
        if renderFrame?.sessionID != incoming.sessionID || renderFrame?.courseVersion != incoming.courseVersion {
            clearWorld()
        }
        renderFrame = incoming
        if world.parent == nil { addChild(world) }
        let playerIDs = Set(incoming.players.map(\.id))
        for id in Array(rocketNodes.keys) where !playerIDs.contains(id) {
            rocketNodes.removeValue(forKey: id)?.removeFromParent()
            flames.removeValue(forKey: id)
        }
        for player in incoming.players where rocketNodes[player.id] == nil {
            let (node, flame) = makeRocket(color: player.color, isHuman: player.role == .human)
            node.setScale(0.5)
            world.addChild(node)
            rocketNodes[player.id] = node
            flames[player.id] = flame
        }
        renderWorld()
    }

    func setReduceMotion(_ enabled: Bool) {
        reduceMotion = enabled
        renderWorld()
    }

    func reset() {
        frameProvider = nil
        renderFrame = nil
        clearWorld()
    }

    private func clearWorld() {
        world.removeAllChildren()
        rocketNodes.removeAll()
        flames.removeAll()
        gateNodes.removeAll()
        fieldNodes.removeAll()
    }

    private func renderWorld() {
        guard let renderFrame, size.width > 0, size.height > 0 else { return }
        let projection = HouseRocketsProjection(elapsedTime: renderFrame.elapsedTime,
                                               cameraX: renderFrame.cameraX,
                                               width: Double(size.width), height: Double(size.height), courseAngle: renderFrame.courseAngle)
        // Future course segments must not float into the empty margins during a turn.
        if world.maskNode == nil { world.maskNode = worldMask }
        worldMask.anchorPoint = .zero
        worldMask.position = CGPoint(x: renderFrame.cameraX, y: 0)
        worldMask.size = CGSize(width: projection.visibleLength, height: HouseRocketsSimulation.trackHeight)
        world.setScale(CGFloat(projection.scale))
        world.zRotation = CGFloat(projection.angle)
        world.position = CGPoint(x: projection.origin.x, y: projection.origin.y)
        environment.setScale(CGFloat(projection.scale))
        environment.zRotation = CGFloat(projection.angle)
        let rear = projection.point(x: renderFrame.cameraX, y: 0)
        environment.position = CGPoint(x: rear.x, y: rear.y)
        for surface in trackSurfaces {
            surface.xScale = CGFloat(projection.visibleLength / HouseRocketsSimulation.viewportWidth)
        }
        for player in renderFrame.players {
            let node = rocketNodes[player.id]
            node?.position = CGPoint(x: player.worldX, y: player.worldY)
            node?.zRotation = player.courseHeading
            node?.alpha = player.isAlive ? 1 : 0.25
            flames[player.id]?.xScale = player.speedEffect == .boost ? 1.7 : (player.speedEffect == .slow ? 0.65 : 1)
            let effectRing = node?.childNode(withName: "speedEffect") as? SKShapeNode
            effectRing?.isHidden = player.speedEffect == nil
            effectRing?.strokeColor = player.speedEffect == .boost ? HouseRocketsPalette.blue : HouseRocketsPalette.cream
            flames[player.id]?.isHidden = renderFrame.phase != .playing || !player.isAlive || reduceMotion
        }
        let activeGateIDs = Set(renderFrame.gates.map(\.id))
        for id in Array(gateNodes.keys) where !activeGateIDs.contains(id) {
            gateNodes.removeValue(forKey: id)?.removeFromParent()
        }
        for gate in renderFrame.gates where gateNodes[gate.id] == nil {
            let node = makeGate(gate)
            world.addChild(node)
            gateNodes[gate.id] = node
        }
        let activeFields = Set(renderFrame.speedFields.map(\.id))
        for id in Array(fieldNodes.keys) where !activeFields.contains(id) {
            fieldNodes.removeValue(forKey: id)?.removeFromParent()
        }
        for field in renderFrame.speedFields {
            if fieldNodes[field.id] == nil {
                let node = makeSpeedField(field)
                world.addChild(node)
                fieldNodes[field.id] = node
            }
            fieldNodes[field.id]?.position = CGPoint(x: field.worldX, y: field.worldY(at: renderFrame.elapsedTime))
        }
        // World-anchored markings make leader-driven camera motion visible.
        let firstDash = floor(renderFrame.cameraX / 68)
        for (index, dash) in trackDashes.enumerated() {
            let x = (firstDash + Double(index)) * 68 - renderFrame.cameraX
            dash.position.x = CGFloat(x)
            dash.isHidden = x < 0 || x + 28 > projection.visibleLength
        }
    }

    private func makeGate(_ gate: HouseRocketsRenderGate) -> SKNode {
        let node = SKNode()
        node.position.x = gate.worldX
        node.zPosition = 2
        for polygon in gate.solidPolygons {
            let path = CGMutablePath()
            for (index, point) in polygon.enumerated() {
                let local = CGPoint(x: point.x - gate.worldX, y: point.y)
                if index == 0 { path.move(to: local) } else { path.addLine(to: local) }
            }
            path.closeSubpath()
            let block = SKShapeNode(path: path)
            block.fillColor = HouseRocketsPalette.burgundy
            block.strokeColor = HouseRocketsPalette.cream
            block.lineWidth = 2
            node.addChild(block)
            let crop = SKCropNode()
            let mask = SKShapeNode(path: path)
            mask.fillColor = .white
            mask.strokeColor = .clear
            crop.maskNode = mask
            let textureWidth = max(gate.width, 220)
            for (index, contour) in HouseRocketsArtwork.topography(in: CGSize(width: textureWidth, height: 360)).enumerated() {
                var shift = CGAffineTransform(translationX: -textureWidth / 2, y: 0)
                let line = SKShapeNode(path: contour.copy(using: &shift)!)
                line.strokeColor = (index.isMultiple(of: 4) ? HouseRocketsPalette.ice : HouseRocketsPalette.cream)
                    .withAlphaComponent(index.isMultiple(of: 4) ? 0.17 : 0.10)
                line.lineWidth = 1
                crop.addChild(line)
            }
            node.addChild(crop)
        }
        return node
    }

    private func makeSpeedField(_ field: HouseRocketsRenderField) -> SKNode {
        let node = SKNode()
        node.zPosition = 3
        let tint: UIColor = field.effect == .boost ? HouseRocketsPalette.blue : HouseRocketsPalette.red
        let boundary = SKShapeNode(circleOfRadius: HouseRocketsSpeedField.radius)
        boundary.fillColor = tint
        boundary.strokeColor = HouseRocketsPalette.cream
        let artworkScale = CGFloat(HouseRocketsSpeedField.artworkScale)
        boundary.lineWidth = 2.5 * artworkScale
        node.addChild(boundary)
        let symbolPath = CGMutablePath()
        if field.effect == .boost {
            for x in [-9.0, 3.0] {
                symbolPath.move(to: CGPoint(x: x - 4, y: -9))
                symbolPath.addLine(to: CGPoint(x: x + 4, y: 0))
                symbolPath.addLine(to: CGPoint(x: x - 4, y: 9))
            }
        } else {
            for x in [-6.0, 6.0] {
                symbolPath.move(to: CGPoint(x: x, y: -10))
                symbolPath.addLine(to: CGPoint(x: x, y: 10))
            }
        }
        let symbol = SKShapeNode(path: symbolPath)
        symbol.strokeColor = field.effect == .boost ? HouseRocketsPalette.navy : HouseRocketsPalette.cream
        symbol.lineWidth = 4
        symbol.setScale(artworkScale)
        // Center the actual path bounds, including the asymmetric double chevron.
        let bounds = symbolPath.boundingBoxOfPath
        symbol.position = CGPoint(x: -bounds.midX * artworkScale, y: -bounds.midY * artworkScale)
        node.addChild(symbol)
        return node
    }

    private func makeRocket(color: HouseRocketsColor, isHuman: Bool) -> (SKNode, SKShapeNode) {
        let node = SKNode()
        node.zPosition = isHuman ? 5 : 4
        let tint = HouseRocketsPalette.player(color)
        let outline = HouseRocketsPalette.cream
        func part(_ path: CGPath, fill: UIColor, stroke: UIColor = HouseRocketsPalette.cream) -> SKShapeNode {
            let shape = SKShapeNode(path: path)
            shape.fillColor = fill
            shape.strokeColor = stroke
            shape.lineWidth = 1.8
            node.addChild(shape)
            return shape
        }
        let flame = part(HouseRocketsArtwork.flame, fill: HouseRocketsPalette.cream,
                         stroke: HouseRocketsPalette.red)
        flame.isHidden = true
        // Color the full silhouette so nearby players remain distinguishable.
        _ = part(HouseRocketsArtwork.fins, fill: tint)
        _ = part(HouseRocketsArtwork.hull, fill: tint)
        _ = part(HouseRocketsArtwork.collar, fill: HouseRocketsPalette.burgundy)
        _ = part(HouseRocketsArtwork.nose, fill: HouseRocketsPalette.red)
        _ = part(HouseRocketsArtwork.window, fill: HouseRocketsPalette.navy,
                 stroke: color == .mint ? HouseRocketsPalette.navy : outline)

        if isHuman {
            let ring = SKShapeNode(circleOfRadius: 25)
            ring.fillColor = .clear
            ring.strokeColor = outline.withAlphaComponent(0.65)
            ring.lineWidth = 1.5
            node.addChild(ring)
        }
        let effectRing = SKShapeNode(circleOfRadius: 29)
        effectRing.name = "speedEffect"
        effectRing.fillColor = .clear
        effectRing.lineWidth = 3
        effectRing.isHidden = true
        node.addChild(effectRing)
        return (node, flame)
    }

    private func drawEnvironment() {
        childNode(withName: "topography")?.removeFromParent()
        let topography = SKNode()
        topography.name = "topography"
        topography.zPosition = -20
        for (index, path) in HouseRocketsArtwork.topography(in: size).enumerated() {
            let color = HouseRocketsArtwork.outerContourColor(at: index)
            if index.isMultiple(of: 3) {
                let wash = SKShapeNode(path: path)
                wash.strokeColor = color.withAlphaComponent(0.06)
                wash.lineWidth = 12
                topography.addChild(wash)
            }
            let line = SKShapeNode(path: path)
            line.strokeColor = color.withAlphaComponent(HouseRocketsArtwork.outerContourOpacity(at: index))
            line.lineWidth = index.isMultiple(of: 4) ? 1.2 : 0.75
            topography.addChild(line)
        }
        addChild(topography)
        environment.removeAllChildren()
        trackSurfaces.removeAll()
        environment.zPosition = -10
        if environment.parent == nil { addChild(environment) }
        let length = CGFloat(HouseRocketsSimulation.viewportWidth)
        let across = CGFloat(HouseRocketsSimulation.trackHeight)
        let track = SKShapeNode(rect: CGRect(x: 0, y: 0, width: length, height: across))
        track.fillColor = HouseRocketsPalette.navy
        track.strokeColor = .clear
        environment.addChild(track)
        trackSurfaces.append(track)
        for y in [CGFloat.zero, across] {
            let rail = SKShapeNode(rect: CGRect(x: 0, y: y - 3, width: length, height: 6))
            rail.fillColor = HouseRocketsPalette.blue.withAlphaComponent(0.65)
            rail.strokeColor = .clear
            environment.addChild(rail)
            trackSurfaces.append(rail)
        }
        trackDashes = (0..<20).map { _ in
            let dash = SKShapeNode(rect: CGRect(x: 0, y: across / 2 - 1,
                                                width: 28, height: 2), cornerRadius: 1)
            dash.fillColor = HouseRocketsPalette.cream.withAlphaComponent(0.12)
            dash.strokeColor = .clear
            environment.addChild(dash)
            return dash
        }
    }
}
