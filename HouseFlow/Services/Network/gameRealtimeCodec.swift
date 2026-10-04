import Foundation

/// Encoding/decoding only; no UI state, auth lookup or game simulation.
enum GameRealtimeCodec {
    static let maximumClientMessageBytes = 16 * 1_024

    static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .custom { values in
            let text = try values.singleValueContainer().decode(String.self)
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            if let date = formatter.date(from: text) { return date }
            formatter.formatOptions = [.withInternetDateTime]
            guard let date = formatter.date(from: text) else {
                throw DecodingError.dataCorrupted(.init(codingPath: values.codingPath,
                    debugDescription: "Expected RFC3339 timestamp"))
            }
            return date
        }
        return decoder
    }

    static func decode(_ data: Data) throws -> GameRealtimeServerMessage {
        try makeDecoder().decode(GameRealtimeServerMessage.self, from: data)
    }

    static func encode(_ message: GameRealtimeClientMessage) throws -> Data {
        let data = try JSONEncoder().encode(message)
        guard data.count <= maximumClientMessageBytes else { throw GameRealtimeError.messageTooLarge }
        return data
    }

    static func validateIdentifier(_ value: String) throws {
        guard !value.isEmpty, value.utf8.count <= 128,
              value.trimmingCharacters(in: .whitespacesAndNewlines) == value else {
            throw GameRealtimeError.invalidIdentifier
        }
    }

    static func validateCompatibility(protocolVersion: Int = 2, courseVersion: Int = 1,
                                      gameKey: String) throws {
        guard protocolVersion == 2 else { throw GameRealtimeError.unsupportedProtocol(protocolVersion) }
        guard courseVersion == 1 else { throw GameRealtimeError.unsupportedCourse(courseVersion) }
        guard gameKey == "houseRockets" else { throw GameRealtimeError.invalidResponse }
    }
}

struct GameRealtimeClock {
    let wallTime: @MainActor () -> Date
    let uptime: @MainActor () -> TimeInterval
    var sleep: @Sendable (TimeInterval) async throws -> Void = {
        try await Task.sleep(for: .seconds($0))
    }

    static var live: Self {
        Self(wallTime: { Date() }, uptime: { ProcessInfo.processInfo.systemUptime })
    }
}
