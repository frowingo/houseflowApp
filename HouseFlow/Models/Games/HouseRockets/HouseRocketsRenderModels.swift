import Foundation

/// Render state has string identities and no network/control authority.
struct HouseRocketsRenderFrame: Equatable, Sendable {
    let sessionID: String
    let courseVersion: Int
    let phase: HouseRocketsRenderPhase
    var elapsedTime: TimeInterval
    var cameraX: Double
    var courseAngle: Double
    var players: [HouseRocketsRenderPlayer]
    let gates: [HouseRocketsRenderGate]
    let speedFields: [HouseRocketsRenderField]
}

enum HouseRocketsRenderPhase: String, Sendable {
    case countdown, playing, paused, recovering, finalizing, ended, cancelled
}

enum HouseRocketsPlayerName: Equatable, Sendable {
    case localizationKey(String)
    case displayName(String)
}

struct HouseRocketsRenderPlayer: Identifiable, Equatable, Sendable {
    let id: String
    let name: HouseRocketsPlayerName
    let role: HouseRocketsRole
    let color: HouseRocketsColor
    let isAlive: Bool
    var worldX: Double
    var worldY: Double
    var courseHeading: Double
    var speedEffect: HouseRocketsSpeedEffect?
    var effectRemaining: Double
}

struct HouseRocketsRenderGate: Identifiable, Equatable, Sendable, HouseRocketsGateGeometry {
    let id: String
    let worldX: Double
    let sections: [HouseRocketsPassageSection]
    var width: Double { (sections.last?.offsetX ?? 0) - (sections.first?.offsetX ?? 0) }
}

struct HouseRocketsRenderField: Identifiable, Equatable, Sendable {
    let id: String
    let worldX: Double
    let effect: HouseRocketsSpeedEffect
    let phase: Double
    let period: Double

    func worldY(at time: TimeInterval) -> Double {
        180 + sin(time * 2 * .pi / period + phase) * 112
    }
}
