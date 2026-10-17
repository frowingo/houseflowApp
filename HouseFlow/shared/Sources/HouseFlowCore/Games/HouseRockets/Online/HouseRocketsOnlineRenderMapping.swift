import Foundation

extension HouseRocketsRenderFrame {
    /// Validates an authoritative online snapshot and maps it to render state. Any
    /// out-of-contract geometry or identity rejects the whole frame.
    static func phase(_ value: HouseRocketsWirePhase) -> HouseRocketsRenderPhase {
        switch value {
        case .countdown: return .countdown
        case .playing: return .playing
        case .recovering: return .recovering
        case .finalizing: return .finalizing
        case .ended: return .ended
        case .cancelled: return .cancelled
        }
    }

    public static func online(_ snapshot: HouseRocketsSnapshotDTO, localPlayerID: String) throws -> HouseRocketsRenderFrame {
        try GameRealtimeCodec.validateCompatibility(courseVersion: snapshot.courseVersion, gameKey: snapshot.gameKey)
        guard !snapshot.sessionId.isEmpty, snapshot.players.count <= 8,
              snapshot.runtimeEpoch >= 0, snapshot.stateSequence >= 0, snapshot.tick >= 0,
              snapshot.gates.count <= 64, snapshot.speedFields.count <= 64,
              snapshot.elapsedSeconds.isFinite, snapshot.elapsedSeconds >= 0,
              snapshot.cameraX.isFinite, snapshot.courseAngle.isFinite,
              (0...Double.pi / 2).contains(snapshot.courseAngle),
              Set(snapshot.players.map(\.playerId)).count == snapshot.players.count,
              Set(snapshot.gates.map(\.id)).count == snapshot.gates.count,
              Set(snapshot.speedFields.map(\.id)).count == snapshot.speedFields.count else {
            throw GameRealtimeError.invalidResponse
        }
        let players = try snapshot.players.map { player in
            guard !player.playerId.isEmpty, player.worldX.isFinite, player.worldY.isFinite,
                  player.courseHeading.isFinite, player.effectRemainingSeconds.isFinite,
                  player.effectRemainingSeconds >= 0, player.lastProcessedInputSequence >= 0 else {
                throw GameRealtimeError.invalidResponse
            }
            return HouseRocketsRenderPlayer(id: player.playerId, name: .displayName(player.displayName),
                role: player.playerId == localPlayerID ? .human : .remote,
                color: player.color, isAlive: player.isAlive, worldX: player.worldX, worldY: player.worldY,
                courseHeading: player.courseHeading, speedEffect: player.speedEffect,
                effectRemaining: player.effectRemainingSeconds)
        }
        let gates = try snapshot.gates.map { gate in
            guard !gate.id.isEmpty, gate.worldX.isFinite, (2...16).contains(gate.sections.count) else {
                throw GameRealtimeError.invalidResponse
            }
            var lastX = -Double.infinity
            let sections = try gate.sections.map { section in
                guard section.offsetX.isFinite, section.lowerY.isFinite, section.upperY.isFinite,
                      section.offsetX > lastX, section.lowerY <= section.upperY else {
                    throw GameRealtimeError.invalidResponse
                }
                lastX = section.offsetX
                return HouseRocketsPassageSection(offsetX: section.offsetX,
                    lowerY: section.lowerY, upperY: section.upperY)
            }
            return HouseRocketsRenderGate(id: gate.id, worldX: gate.worldX, sections: sections)
        }
        let fields = try snapshot.speedFields.map { field in
            guard !field.id.isEmpty, field.worldX.isFinite, field.phase.isFinite,
                  field.periodSeconds.isFinite, field.periodSeconds > 0 else {
                throw GameRealtimeError.invalidResponse
            }
            return HouseRocketsRenderField(id: field.id, worldX: field.worldX,
                effect: field.effect, phase: field.phase, period: field.periodSeconds)
        }
        return HouseRocketsRenderFrame(sessionID: snapshot.sessionId, courseVersion: snapshot.courseVersion,
            phase: phase(snapshot.phase),
            elapsedTime: snapshot.elapsedSeconds, cameraX: snapshot.cameraX, courseAngle: snapshot.courseAngle,
            players: players, gates: gates, speedFields: fields)
    }
}
