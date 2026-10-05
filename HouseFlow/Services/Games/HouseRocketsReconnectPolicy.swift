import Foundation

/// Retry classification and timing only. Never changes match/session authority.
struct HouseRocketsReconnectPolicy {
    var maximumAttempts = 5
    var initialBudget: TimeInterval = 20
    var jitter: @MainActor () -> Double = { Double.random(in: 0.8...1.2) }

    @MainActor
    func delay(attempt: Int, minimum: TimeInterval) -> TimeInterval {
        max(minimum, min(8, 0.5 * pow(2, Double(max(0, attempt - 1)))) * min(1.2, max(0.8, jitter())))
    }

    static func automaticallyRetries(_ issue: HouseRocketsOnlineLobbyIssue) -> Bool {
        switch issue {
        case .connection(.transport), .timeout: return true
        case .connection(.http(let status, _)): return [408, 429, 500, 502, 503, 504].contains(status)
        case .connection(.protocolFailure(.notConnected)): return true
        case .rejected(let error): return ["realtime.error.unavailable", "realtime.error.command_failed"].contains(error.code) && error.retryable
        default: return false
        }
    }
}
