import Foundation

/// Render state has string identities and no network/control authority.
public struct HouseRocketsRenderFrame: Equatable, Sendable {
    public let sessionID: String
    public let courseVersion: Int
    public let phase: HouseRocketsRenderPhase
    public var elapsedTime: TimeInterval
    public var cameraX: Double
    public var courseAngle: Double
    public var players: [HouseRocketsRenderPlayer]
    public let gates: [HouseRocketsRenderGate]
    public let speedFields: [HouseRocketsRenderField]

    public init(sessionID: String, courseVersion: Int, phase: HouseRocketsRenderPhase, elapsedTime: TimeInterval, cameraX: Double, courseAngle: Double, players: [HouseRocketsRenderPlayer], gates: [HouseRocketsRenderGate], speedFields: [HouseRocketsRenderField]) {
        self.sessionID = sessionID
        self.courseVersion = courseVersion
        self.phase = phase
        self.elapsedTime = elapsedTime
        self.cameraX = cameraX
        self.courseAngle = courseAngle
        self.players = players
        self.gates = gates
        self.speedFields = speedFields
    }
}

public enum HouseRocketsRenderPhase: String, Sendable {
    case countdown, playing, paused, recovering, finalizing, ended, cancelled
}

public enum HouseRocketsPlayerName: Equatable, Sendable {
    case localizationKey(String)
    case displayName(String)
}

public struct HouseRocketsRenderPlayer: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: HouseRocketsPlayerName
    public let role: HouseRocketsRole
    public let color: HouseRocketsColor
    public let isAlive: Bool
    public var worldX: Double
    public var worldY: Double
    public var courseHeading: Double
    public var speedEffect: HouseRocketsSpeedEffect?
    public var effectRemaining: Double

    public init(id: String, name: HouseRocketsPlayerName, role: HouseRocketsRole, color: HouseRocketsColor, isAlive: Bool, worldX: Double, worldY: Double, courseHeading: Double, speedEffect: HouseRocketsSpeedEffect?, effectRemaining: Double) {
        self.id = id
        self.name = name
        self.role = role
        self.color = color
        self.isAlive = isAlive
        self.worldX = worldX
        self.worldY = worldY
        self.courseHeading = courseHeading
        self.speedEffect = speedEffect
        self.effectRemaining = effectRemaining
    }
}

public struct HouseRocketsRenderGate: Identifiable, Equatable, Sendable, HouseRocketsGateGeometry {
    public let id: String
    public let worldX: Double
    public let sections: [HouseRocketsPassageSection]
    public var width: Double { (sections.last?.offsetX ?? 0) - (sections.first?.offsetX ?? 0) }

    public init(id: String, worldX: Double, sections: [HouseRocketsPassageSection]) {
        self.id = id
        self.worldX = worldX
        self.sections = sections
    }
}

public struct HouseRocketsRenderField: Identifiable, Equatable, Sendable {
    public let id: String
    public let worldX: Double
    public let effect: HouseRocketsSpeedEffect
    public let phase: Double
    public let period: Double

    public func worldY(at time: TimeInterval) -> Double {
        180 + sin(time * 2 * .pi / period + phase) * 112
    }

    public init(id: String, worldX: Double, effect: HouseRocketsSpeedEffect, phase: Double, period: Double) {
        self.id = id
        self.worldX = worldX
        self.effect = effect
        self.phase = phase
        self.period = period
    }
}

