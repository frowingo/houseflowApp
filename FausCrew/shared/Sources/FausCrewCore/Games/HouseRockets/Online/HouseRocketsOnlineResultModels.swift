import Foundation


public struct HouseRocketsResultPlayerIdentity: Equatable, Sendable {
    public let displayName: String
    public let color: HouseRocketsColor

    public init(displayName: String, color: HouseRocketsColor) {
        self.displayName = displayName
        self.color = color
    }
}

/// Persistence state, independent of the flight frame and socket lifetime.
public struct HouseRocketsOnlineResultState: Equatable, Sendable {
    public enum Phase: Equatable, Sendable { case idle, waiting, available, cancelledWithoutRecord, failed }
    public var phase: Phase = .idle
    public var sessionID: String?
    public var result: HouseRocketsResultDTO?
    public var identities: [String: HouseRocketsResultPlayerIdentity] = [:]
    public var endReason: HouseRocketsEndReason?
    public var failure: GameRealtimeSessionFailure?
    public var retryNotBefore: TimeInterval = 0
    public var terminalConfirmed = false

    public var isVisible: Bool { phase != .idle }
    public var canRematch: Bool { terminalConfirmed && (phase == .available || phase == .cancelledWithoutRecord) }
    public func canRetry(at uptime: TimeInterval) -> Bool {
        guard phase == .failed, uptime >= retryNotBefore else { return false }
        switch failure {
        case .http(let status, _): return ![401, 403].contains(status)
        case .invalidPayload, .protocolFailure: return false
        default: return true
        }
    }

    public init() {}
}

extension HouseRocketsResultDTO {
    /// A final snapshot's winner or distances never substitute for this contract.
    public func validate(sessionID: String, houseID: String) throws {
        try GameRealtimeCodec.validateCompatibility(protocolVersion: protocolVersion,
            courseVersion: courseVersion, gameKey: gameKey)
        guard sessionId == sessionID, houseId == houseID else { throw GameRealtimeError.unexpectedSession }
        guard durationSeconds.isFinite, durationSeconds >= 0, players.count <= 8,
              Set(players.map(\.playerId)).count == players.count,
              startedAt.map({ endedAt >= $0 }) ?? (durationSeconds == 0),
              players.allSatisfy({ !$0.playerId.isEmpty && $0.distance.isFinite && $0.distance >= 0
                  && ($0.eliminatedAtTick.map { $0 >= 0 } ?? true) }) else {
            throw GameRealtimeError.invalidResponse
        }
        switch status {
        case .cancelled:
            guard winnerId == nil, players.allSatisfy({ $0.rank == nil }),
                  endReason != .lastSurvivor, endReason != .simultaneousElimination else {
                throw GameRealtimeError.invalidResponse
            }
        case .completed:
            guard startedAt != nil, !players.isEmpty,
                  players.allSatisfy({ $0.rank.map { (1...players.count).contains($0) } ?? false }) else {
                throw GameRealtimeError.invalidResponse
            }
            if let winnerId {
                guard endReason == .lastSurvivor,
                      players.first(where: { $0.playerId == winnerId })?.rank == 1,
                      players.filter({ $0.rank == 1 }).count == 1 else { throw GameRealtimeError.invalidResponse }
            } else {
                guard endReason == .simultaneousElimination,
                      players.contains(where: { $0.rank == 1 }) else { throw GameRealtimeError.invalidResponse }
            }
        }
    }
}

