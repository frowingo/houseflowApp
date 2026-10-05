import Foundation

/// Local acceptance configuration. Release builds ignore these launch arguments.
struct HouseRocketsAcceptanceConfiguration {
    var isEnabled = false
    var requestedFramesPerSecond = 60

    static var current: Self {
        #if DEBUG
        return parse(arguments: ProcessInfo.processInfo.arguments)
        #else
        return Self()
        #endif
    }

    static func parse(arguments: [String]) -> Self {
        guard arguments.contains("-HouseRocketsDiagnostics") else { return Self() }
        var value = Self(isEnabled: true)
        if let index = arguments.firstIndex(of: "-HouseRocketsFPS"), index + 1 < arguments.count,
           let fps = Int(arguments[index + 1]), [30, 60, 120].contains(fps) {
            value.requestedFramesPerSecond = fps
        }
        return value
    }
}

enum HouseRocketsAcceptanceMetric: String, Codable, CaseIterable {
    case frameInterval, roundTrip, snapshotInterval, inputAck
}

struct HouseRocketsAcceptanceSample: Codable, Equatable {
    let count: Int
    let windowCount: Int
    let meanMilliseconds: Double
    let p50Milliseconds: Double
    let p95Milliseconds: Double
    let maximumMilliseconds: Double
}

/// A bounded recent window, never a history of user/session identifiers or payloads.
struct HouseRocketsAcceptanceWindow {
    private(set) var count = 0
    private var values: [Double] = []
    private let capacity: Int

    init(capacity: Int = 240) { self.capacity = max(1, capacity) }

    mutating func append(seconds: TimeInterval) {
        let milliseconds = seconds * 1_000
        guard seconds >= 0, milliseconds.isFinite else { return }
        count += 1
        values.append(milliseconds)
        if values.count > capacity { values.removeFirst(values.count - capacity) }
    }

    var sample: HouseRocketsAcceptanceSample? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        func percentile(_ fraction: Double) -> Double {
            sorted[max(0, Int(ceil(Double(sorted.count) * fraction)) - 1)]
        }
        return .init(count: count, windowCount: values.count,
            meanMilliseconds: values.reduce(0, +) / Double(values.count),
            p50Milliseconds: percentile(0.5), p95Milliseconds: percentile(0.95),
            maximumMilliseconds: sorted[sorted.count - 1])
    }
}

struct HouseRocketsAcceptanceReport: Encodable {
    let schemaVersion = 1
    let run: Int
    let reason: String
    let mode: String
    let requestedFramesPerSecond: Int
    let screenMaximumFramesPerSecond: Int?
    let measuredFramesPerSecond: Double?
    let isForeground: Bool
    let reduceMotion: Bool
    let backgroundCount: Int
    let reconnectCount: Int
    let controlTransferCount: Int
    let metrics: [String: HouseRocketsAcceptanceSample]
}
