import Foundation

/// The presentation boundary maps DTOs; it does not decide eliminations or outcomes.
enum HouseRocketsRenderMapper {
    static func local(_ snapshot: HouseRocketsSnapshot) -> HouseRocketsRenderFrame {
        let angle = HouseRocketsCourse.angle(at: snapshot.elapsedTime)
        return HouseRocketsRenderFrame(sessionID: snapshot.matchID.uuidString, courseVersion: 1,
            phase: phase(snapshot.phase),
            elapsedTime: snapshot.elapsedTime, cameraX: snapshot.cameraX, courseAngle: angle,
            players: snapshot.players.map { player in
                HouseRocketsRenderPlayer(id: player.id.uuidString, name: .localizationKey(player.nameKey),
                    role: player.role, color: player.color, isAlive: player.isAlive,
                    worldX: player.worldX, worldY: player.worldY,
                    courseHeading: atan2(sin(player.heading - angle), cos(player.heading - angle)),
                    speedEffect: player.speedEffect, effectRemaining: player.effectRemaining)
            },
            gates: snapshot.gates.map {
                HouseRocketsRenderGate(id: $0.id.uuidString, worldX: $0.worldX, sections: $0.sections)
            },
            speedFields: snapshot.speedFields.map {
                HouseRocketsRenderField(id: $0.id.uuidString, worldX: $0.worldX,
                    effect: $0.effect, phase: $0.phase, period: $0.period)
            })
    }

    private static func phase(_ value: HouseRocketsPhase) -> HouseRocketsRenderPhase {
        switch value {
        case .countdown: return .countdown
        case .playing: return .playing
        case .paused: return .paused
        case .ended: return .ended
        }
    }

    private static func phase(_ value: HouseRocketsWirePhase) -> HouseRocketsRenderPhase {
        switch value {
        case .countdown: return .countdown
        case .playing: return .playing
        case .recovering: return .recovering
        case .finalizing: return .finalizing
        case .ended: return .ended
        case .cancelled: return .cancelled
        }
    }

    static func online(_ snapshot: HouseRocketsSnapshotDTO, localPlayerID: String) throws -> HouseRocketsRenderFrame {
        try GameRealtimeCodec.validateCompatibility(courseVersion: snapshot.courseVersion, gameKey: snapshot.gameKey)
        guard !snapshot.sessionId.isEmpty, snapshot.players.count <= 8,
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
                  player.courseHeading.isFinite, player.effectRemainingSeconds.isFinite else {
                throw GameRealtimeError.invalidResponse
            }
            return HouseRocketsRenderPlayer(id: player.playerId, name: .displayName(player.displayName),
                role: player.playerId == localPlayerID ? .human : .remote,
                color: player.color, isAlive: player.isAlive, worldX: player.worldX, worldY: player.worldY,
                courseHeading: player.courseHeading, speedEffect: player.speedEffect,
                effectRemaining: player.effectRemainingSeconds)
        }
        let gates = try snapshot.gates.map { gate in
            guard !gate.id.isEmpty, gate.worldX.isFinite, gate.sections.count >= 2 else {
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
