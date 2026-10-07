import Foundation
import OSLog

/// Opt-in, aggregate measurements only. It cannot change gameplay or release gates.
@MainActor
final class HouseRocketsAcceptanceRecorder {
    enum Reason: String { case periodic, background, result, stop }
    typealias Sink = (HouseRocketsAcceptanceReport) -> Void
    private let configuration: HouseRocketsAcceptanceConfiguration
    private let clock: GameRealtimeClock
    private let sink: Sink
    private var windows: [HouseRocketsAcceptanceMetric: HouseRocketsAcceptanceWindow] = [:]
    private var mode: HouseRocketsMode?
    private var run = 0
    private var nextReportAt: TimeInterval = 0
    private var lastFrameAt: TimeInterval?
    private var lastSnapshot: (epoch: Int64, sequence: Int64, uptime: TimeInterval)?
    private var connectionGeneration: UUID?
    private var wasControlTransferred = false
    private var isForeground = true
    private var reduceMotion = false
    private var screenMaximumFPS: Int?
    private var backgroundCount = 0
    private var reconnectCount = 0
    private var controlTransferCount = 0

    init(configuration: HouseRocketsAcceptanceConfiguration, clock: GameRealtimeClock? = nil,
         sink: Sink? = nil) {
        self.configuration = configuration
        self.clock = clock ?? .live
        self.sink = sink ?? Self.log
    }

    func begin(mode: HouseRocketsMode) {
        guard configuration.isEnabled else { return }
        self.mode = mode
        run += 1
        windows.removeAll()
        screenMaximumFPS = nil
        lastFrameAt = nil; lastSnapshot = nil; connectionGeneration = nil
        wasControlTransferred = false
        backgroundCount = 0; reconnectCount = 0; controlTransferCount = 0
        nextReportAt = clock.uptime() + 5
    }

    func setReduceMotion(_ enabled: Bool) { reduceMotion = enabled }

    func setForeground(_ active: Bool) {
        guard active != isForeground else { return }
        isForeground = active
        lastFrameAt = nil; lastSnapshot = nil
        if !active, mode != nil { backgroundCount += 1; flush(.background) }
    }

    func renderedFrame(at uptime: TimeInterval, screenMaximumFPS: Int?) {
        guard configuration.isEnabled, mode != nil, isForeground, uptime.isFinite else { return }
        self.screenMaximumFPS = screenMaximumFPS
        if let previous = lastFrameAt, uptime > previous { record(.frameInterval, seconds: uptime - previous) }
        lastFrameAt = uptime
        if clock.uptime() >= nextReportAt { flush(.periodic) }
    }

    func consume(_ state: HouseRocketsOnlineLobbyState) {
        guard configuration.isEnabled, mode == .housemates else { return }
        setForeground(state.isForeground)
        if connectionGeneration != state.connectionGeneration {
            if connectionGeneration != nil { reconnectCount += 1 }
            connectionGeneration = state.connectionGeneration
            lastSnapshot = nil
        }
        if state.controlTransferred, !wasControlTransferred { controlTransferCount += 1 }
        wasControlTransferred = state.controlTransferred
        guard isForeground, let game = state.game, game.phase == .playing,
              let uptime = state.gameReceivedUptime else { lastSnapshot = nil; return }
        if let previous = lastSnapshot {
            guard game.runtimeEpoch > previous.epoch ||
                (game.runtimeEpoch == previous.epoch && game.stateSequence > previous.sequence) else { return }
            if game.runtimeEpoch == previous.epoch { record(.snapshotInterval, seconds: uptime - previous.uptime) }
        }
        lastSnapshot = (game.runtimeEpoch, game.stateSequence, uptime)
    }

    func record(_ metric: HouseRocketsAcceptanceMetric, seconds: TimeInterval) {
        guard configuration.isEnabled, mode != nil, isForeground else { return }
        windows[metric, default: .init()].append(seconds: seconds)
    }

    func flush(_ reason: Reason) {
        guard configuration.isEnabled, let mode else { return }
        let metrics = windows.reduce(into: [String: HouseRocketsAcceptanceSample]()) { result, entry in
            if let sample = entry.value.sample { result[entry.key.rawValue] = sample }
        }
        let mean = metrics[HouseRocketsAcceptanceMetric.frameInterval.rawValue]?.meanMilliseconds
        sink(.init(run: run, reason: reason.rawValue, mode: mode.rawValue,
            requestedFramesPerSecond: configuration.requestedFramesPerSecond,
            screenMaximumFramesPerSecond: screenMaximumFPS,
            measuredFramesPerSecond: mean.flatMap { $0 > 0 ? 1_000 / $0 : nil },
            isForeground: isForeground, reduceMotion: reduceMotion, backgroundCount: backgroundCount,
            reconnectCount: reconnectCount, controlTransferCount: controlTransferCount, metrics: metrics))
        nextReportAt = clock.uptime() + 5
        if reason == .stop { self.mode = nil; lastFrameAt = nil; lastSnapshot = nil }
    }

    private static func log(_ report: HouseRocketsAcceptanceReport) {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        guard let data = try? encoder.encode(report), let text = String(data: data, encoding: .utf8) else { return }
        Logger(subsystem: "HouseFlow", category: "HouseRocketsAcceptance").info("\(text, privacy: .public)")
    }
}
