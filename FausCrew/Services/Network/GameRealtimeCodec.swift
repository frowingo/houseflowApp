import Foundation

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
