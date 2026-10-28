import Foundation

/// Encoding/decoding only; no UI state, auth lookup or game simulation.
public enum GameRealtimeCodec {
    public static let maximumClientMessageBytes = 16 * 1_024

    public static func makeDecoder() -> JSONDecoder {
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

    /// Writes dates as RFC 3339 UTC with milliseconds, the form the server reads.
    public static func makeEncoder() -> JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .custom { date, values in
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            var container = values.singleValueContainer()
            try container.encode(formatter.string(from: date))
        }
        return encoder
    }

    public static func decode(_ data: Data) throws -> GameRealtimeServerMessage {
        try decode(data, as: HouseRocketsRealtime.self)
    }

    public static func decode<Game: GameRealtimeGame>(_ data: Data, as game: Game.Type) throws -> GameRealtimeServerMessageOf<Game> {
        try makeDecoder().decode(GameRealtimeServerMessageOf<Game>.self, from: data)
    }

    public static func encode<Game: GameRealtimeGame>(_ message: GameRealtimeClientMessageOf<Game>) throws -> Data {
        let data = try JSONEncoder().encode(message)
        guard data.count <= maximumClientMessageBytes else { throw GameRealtimeError.messageTooLarge }
        return data
    }

    public static func validateIdentifier(_ value: String) throws {
        guard !value.isEmpty, value.utf8.count <= 128,
              value.trimmingCharacters(in: .whitespacesAndNewlines) == value else {
            throw GameRealtimeError.invalidIdentifier
        }
    }

    /// `gameSession.snapshot` and HTTP sessions: the shared envelope version and this game.
    public static func validateSession(_ session: GameSessionDTO, gameKey: String) throws {
        guard session.protocolVersion == GameRoute.realtimeProtocolVersion else {
            throw GameRealtimeError.unsupportedProtocol(session.protocolVersion)
        }
        guard session.gameKey == gameKey else { throw GameRealtimeError.invalidResponse }
    }

    /// House Rockets: protocol 2, course 1.
    public static func validateCompatibility(protocolVersion: Int = 2, courseVersion: Int = 1,
                                      gameKey: String) throws {
        guard protocolVersion == 2 else { throw GameRealtimeError.unsupportedProtocol(protocolVersion) }
        guard courseVersion == 1 else { throw GameRealtimeError.unsupportedCourse(courseVersion) }
        guard gameKey == "houseRockets" else { throw GameRealtimeError.invalidResponse }
    }
}

