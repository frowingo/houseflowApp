import Foundation

/// Local bot match rules shared by iOS and Android. It owns phases, physics,
/// bot steering and the result, but no clock: the platform host calls
/// `advanceCountdown()` every `countdownStepSeconds` while counting down and
/// `advance(by:)` with the real frame delta while playing. Every state change
/// bumps `snapshot.revision` exactly once.
public struct HouseRocketsBotMatch: Sendable {
    public static let countdownStart = 3
    public static let countdownStepSeconds = 0.75
    public static let botDecisionInterval = 0.12
    public static let botLaneOffsets = [-18.0, 20.0, 5.0]
    public static let botNameKeys = ["house_rockets_bot_one", "house_rockets_bot_two", "house_rockets_bot_three"]
    public static let humanNameKey = "house_rockets_you"

    public private(set) var snapshot: HouseRocketsSnapshot?
    public private(set) var configuration = HouseRocketsConfiguration.demo
    private var simulation = HouseRocketsSimulation(playerIDs: [])
    private var lastHumanSequence = -1
    private var pausedFrom: HouseRocketsPhase?
    private var lastBotUpdate = 0.0

    public init() {}

    public var phase: HouseRocketsPhase? { snapshot?.phase }

    /// Starts a new match: one human plus 1–3 bots, countdown at 3.
    public mutating func start(configuration: HouseRocketsConfiguration, matchID: UUID = UUID()) {
        self.configuration = HouseRocketsConfiguration(botCount: configuration.normalizedBotCount)
        lastHumanSequence = -1
        pausedFrom = nil
        lastBotUpdate = 0

        let colors = HouseRocketsColor.allCases
        let players = (0...self.configuration.normalizedBotCount).map { index in
            HouseRocketsPlayer(
                id: UUID(), nameKey: index == 0 ? Self.humanNameKey : Self.botNameKeys[index - 1],
                role: index == 0 ? .human : .bot, color: colors[index],
                isAlive: true, distance: 0, heading: 0, worldX: 0, worldY: 0
            )
        }
        simulation = HouseRocketsSimulation(playerIDs: players.map(\.id))
        var initial = HouseRocketsSnapshot(
            matchID: matchID, revision: 0, phase: .countdown, players: players, gates: [], speedFields: [],
            elapsedTime: 0, cameraX: 0, countdown: Self.countdownStart, winnerID: nil, lastEliminatedID: nil
        )
        synchronizeWorld(into: &initial)
        initial.revision = 1
        snapshot = initial
    }

    /// One countdown step. Returns `true` when the match switched to playing,
    /// so the host can start its frame loop.
    @discardableResult
    public mutating func advanceCountdown() -> Bool {
        guard var current = snapshot, current.phase == .countdown else { return false }
        let value = current.countdown ?? Self.countdownStart
        if value > 1 {
            current.countdown = value - 1
        } else {
            current.phase = .playing
            current.countdown = nil
        }
        current.revision += 1
        snapshot = current
        return current.phase == .playing
    }

    /// Advances physics by the real elapsed time (capped inside the simulation).
    /// Returns the players eliminated in this step, in roster order.
    @discardableResult
    public mutating func advance(by delta: TimeInterval) -> [UUID] {
        guard var current = snapshot, current.phase == .playing else { return [] }
        let previousAlive = Set(current.players.filter(\.isAlive).map(\.id))
        simulation.advance(by: delta)
        synchronizeWorld(into: &current)
        let eliminated = current.players.filter { previousAlive.contains($0.id) && !$0.isAlive }.map(\.id)
        // Resolve after every body has completed the same physics batch.
        current.lastEliminatedID = eliminated.first ?? current.lastEliminatedID
        switch HouseRocketsRules.resolve(players: current.players) {
        case .ongoing:
            if simulation.elapsedTime - lastBotUpdate >= Self.botDecisionInterval {
                driveBots(players: current.players)
                lastBotUpdate = simulation.elapsedTime
            }
        case .draw:
            current.winnerID = nil
            current.phase = .ended
        case .winner(let id):
            current.winnerID = id
            current.phase = .ended
        }
        current.revision += 1
        snapshot = current
        return eliminated
    }

    /// Applies a human command. A restart is accepted only after the match ended.
    /// Returns `true` when the state changed.
    @discardableResult
    public mutating func send(_ command: HouseRocketsCommand) -> Bool {
        guard let current = snapshot, command.matchID == current.matchID else { return false }
        switch command.action {
        case .restart:
            guard current.phase == .ended else { return false }
            start(configuration: configuration)
            return true
        case .steer(let heading):
            guard current.phase == .playing, let playerID = command.playerID,
                  playerID == current.humanPlayer?.id, current.humanPlayer?.isAlive == true,
                  command.sequence > lastHumanSequence, heading.isFinite else { return false }
            lastHumanSequence = command.sequence
            simulation.steer(playerID: playerID, heading: heading)
            return true
        }
    }

    /// Pauses from countdown or playing. Returns `true` when the state changed.
    @discardableResult
    public mutating func pause() -> Bool {
        guard var current = snapshot, current.phase == .playing || current.phase == .countdown else { return false }
        pausedFrom = current.phase
        current.phase = .paused
        current.revision += 1
        snapshot = current
        return true
    }

    /// Resumes the phase that was paused; the host restarts the matching timer
    /// (a countdown continues from its current value).
    @discardableResult
    public mutating func resume() -> HouseRocketsPhase? {
        guard var current = snapshot, current.phase == .paused else { return nil }
        let previous = pausedFrom ?? .playing
        current.phase = previous
        current.revision += 1
        snapshot = current
        pausedFrom = nil
        return previous
    }

    public mutating func reset() {
        snapshot = nil
        pausedFrom = nil
        simulation = HouseRocketsSimulation(playerIDs: [])
    }

    private mutating func driveBots(players: [HouseRocketsPlayer]) {
        for (index, player) in players.filter({ $0.role == .bot }).enumerated() where player.isAlive {
            let laneOffset = Self.botLaneOffsets[index % Self.botLaneOffsets.count]
            guard let heading = simulation.botHeading(playerID: player.id, laneOffset: laneOffset) else { continue }
            simulation.steer(playerID: player.id, heading: heading)
        }
    }

    private func synchronizeWorld(into current: inout HouseRocketsSnapshot) {
        let bodies = Dictionary(uniqueKeysWithValues: simulation.bodies.map { ($0.id, $0) })
        current.players = current.players.map { player in
            guard let body = bodies[player.id] else { return player }
            var updated = player
            updated.isAlive = body.isAlive
            updated.distance = body.x - HouseRocketsSimulation.spawnX
            updated.heading = simulation.screenHeading(for: body)
            updated.worldX = body.x
            updated.worldY = body.y
            updated.speedEffect = body.speedEffect
            updated.effectRemaining = body.effectRemaining
            return updated
        }
        current.gates = simulation.gates
        current.speedFields = simulation.speedFields
        current.elapsedTime = simulation.elapsedTime
        current.cameraX = simulation.cameraX
    }
}

extension HouseRocketsRenderFrame {
    /// Render state for a local bot match; online frames are mapped from wire DTOs.
    public static func local(_ snapshot: HouseRocketsSnapshot) -> HouseRocketsRenderFrame {
        let angle = HouseRocketsCourse.angle(at: snapshot.elapsedTime)
        return HouseRocketsRenderFrame(
            sessionID: snapshot.matchID.uuidString, courseVersion: 1, phase: .init(snapshot.phase),
            elapsedTime: snapshot.elapsedTime, cameraX: snapshot.cameraX, courseAngle: angle,
            players: snapshot.players.map { player in
                HouseRocketsRenderPlayer(
                    id: player.id.uuidString, name: .localizationKey(player.nameKey),
                    role: player.role, color: player.color, isAlive: player.isAlive,
                    worldX: player.worldX, worldY: player.worldY,
                    courseHeading: atan2(sin(player.heading - angle), cos(player.heading - angle)),
                    speedEffect: player.speedEffect, effectRemaining: player.effectRemaining
                )
            },
            gates: snapshot.gates.map {
                HouseRocketsRenderGate(id: $0.id.uuidString, worldX: $0.worldX, sections: $0.sections)
            },
            speedFields: snapshot.speedFields.map {
                HouseRocketsRenderField(id: $0.id.uuidString, worldX: $0.worldX,
                                        effect: $0.effect, phase: $0.phase, period: $0.period)
            }
        )
    }
}

extension HouseRocketsRenderPhase {
    public init(_ phase: HouseRocketsPhase) {
        switch phase {
        case .countdown: self = .countdown
        case .playing: self = .playing
        case .paused: self = .paused
        case .ended: self = .ended
        }
    }
}
