import Foundation

/// A debug-build network condition for device acceptance (F6): every socket message is held
/// for half the round trip, plus up to `jitterMilliseconds` either way, in each direction.
/// Order is kept, as on a TCP socket. HTTP requests (session, result) are not delayed.
public struct HouseTanksLatencySimulation: Equatable, Sendable {
    public var roundTripMilliseconds: Int
    public var jitterMilliseconds: Int

    public static let off = HouseTanksLatencySimulation(roundTripMilliseconds: 0, jitterMilliseconds: 0)

    public init(roundTripMilliseconds: Int, jitterMilliseconds: Int) {
        self.roundTripMilliseconds = max(0, roundTripMilliseconds)
        self.jitterMilliseconds = max(0, jitterMilliseconds)
    }

    public var isActive: Bool { roundTripMilliseconds > 0 || jitterMilliseconds > 0 }

    /// One direction's hold; `unit` is a random value in -1...1.
    func delay(unit: Double) -> TimeInterval {
        max(0, Double(roundTripMilliseconds) / 2_000 + Double(jitterMilliseconds) / 1_000 * unit)
    }
}

/// The HUD's FPS chip: 0 (red) at 20 fps or less to 1 (green) at 55 fps or more, so a
/// 60 Hz and a 120 Hz screen both read green; platforms map it to a hue.
public enum HouseTanksFrameRate {
    public static func quality(_ framesPerSecond: Int) -> Double {
        min(1, max(0, Double(framesPerSecond - 20) / 35))
    }
}

/// What the debug panel shows during a device test: the measured link and how the display
/// coped with it. Milliseconds are rounded; nil until there is something to measure.
public struct HouseTanksOnlineDiagnostics: Equatable, Sendable {
    public var connection: String
    public var runtimeEpoch: Int64?
    /// The last `realtime.ping` → `pong`, simulated latency included.
    public var roundTripMilliseconds: Int?
    /// Mean and standard deviation of the time between drawn snapshots (20 Hz ≈ 50 ms).
    public var snapshotIntervalMilliseconds: Int?
    public var snapshotJitterMilliseconds: Int?
    /// How old the newest snapshot is at this display frame.
    public var frameAgeMilliseconds: Int?
    /// From sending a press to the snapshot that acknowledged it (the felt delay).
    public var inputAcknowledgementMilliseconds: Int?
    public var unacknowledgedInputs: Int
    /// Older or equal snapshots that arrived late and were not drawn.
    public var lateFrames: Int
    /// Gaps long enough to restart the display buffer (lost frames, a reconnect).
    public var gapResets: Int
    /// Own-tank disagreements with the server: smoothed out / too large and jumped.
    public var corrections: Int
    public var snaps: Int
    public var staleControls: Int
    public var rateLimited: Int
    public var reconnects: Int
    /// Text received per second after decompression; the wire is smaller with deflate.
    public var receivedKilobytesPerSecond: Double
    public var displayFramesPerSecond: Int
    public var interpolationDelayMilliseconds: Int
    public var simulation: HouseTanksLatencySimulation

    /// The panel's text, the same on iOS and Android (technical, not localized).
    public var lines: [String] {
        func ms(_ value: Int?) -> String { value.map { "\($0) ms" } ?? "–" }
        let epoch = runtimeEpoch.map { " · epoch \($0)" } ?? ""
        let simulated = simulation.isActive
            ? " (sim \(simulation.roundTripMilliseconds)±\(simulation.jitterMilliseconds))" : ""
        let interval = snapshotIntervalMilliseconds.map { mean in
            "\(mean)±\(snapshotJitterMilliseconds ?? 0) ms" } ?? "–"
        return [
            "\(connection)\(epoch)",
            "RTT \(ms(roundTripMilliseconds))\(simulated)",
            "snapshot \(interval) · age \(ms(frameAgeMilliseconds))",
            "input→ACK \(ms(inputAcknowledgementMilliseconds)) · pending \(unacknowledgedInputs)",
            "delay \(interpolationDelayMilliseconds) ms · \(displayFramesPerSecond) fps · "
                + String(format: "%.1f KB/s", receivedKilobytesPerSecond),
            "late \(lateFrames) · gap \(gapResets) · fix \(corrections) · jump \(snaps)",
            "stale \(staleControls) · rate \(rateLimited) · reconnect \(reconnects)",
        ]
    }
}

/// Counters the engine and the play machine report into; the HUD reads only the frame rate.
final class HouseTanksDiagnosticsRecorder {
    private(set) var arrivals: [TimeInterval] = []
    private(set) var lastFrameUptime: TimeInterval?
    private(set) var acknowledgement: TimeInterval?
    private var received: [(uptime: TimeInterval, bytes: Int)] = []
    private var displayed: [TimeInterval] = []
    var gapResets = 0
    var corrections = 0
    var snaps = 0
    var staleControls = 0
    var rateLimited = 0
    var reconnects = 0

    func frameDrawn(receivedUptime: TimeInterval) {
        arrivals.append(receivedUptime)
        if arrivals.count > 41 { arrivals.removeFirst(arrivals.count - 41) }
        lastFrameUptime = receivedUptime
    }

    /// A new timeline (round, epoch, reconnect): intervals across it would mean nothing.
    func timelineRestarted() { arrivals.removeAll() }

    func acknowledged(after latency: TimeInterval) { acknowledgement = max(0, latency) }

    func receivedText(bytes: Int, at uptime: TimeInterval) {
        received.append((uptime, bytes))
        received.removeAll { uptime - $0.uptime > 1 }
    }

    func displayedFrame(at uptime: TimeInterval) {
        displayed.append(uptime)
        displayed.removeAll { uptime - $0 > 1 }
    }

    func displayedFramesPerSecond(at now: TimeInterval) -> Int {
        displayed.filter { now - $0 <= 1 }.count
    }

    func snapshot(at now: TimeInterval) -> (interval: Int?, jitter: Int?, age: Int?, ack: Int?, kilobytes: Double, fps: Int) {
        let intervals = zip(arrivals.dropFirst(), arrivals).map { $0 - $1 }
        var interval: Int?, jitter: Int?
        if !intervals.isEmpty {
            let mean = intervals.reduce(0, +) / Double(intervals.count)
            let variance = intervals.map { ($0 - mean) * ($0 - mean) }.reduce(0, +) / Double(intervals.count)
            interval = Self.ms(mean)
            jitter = Self.ms(variance.squareRoot())
        }
        let recent = received.filter { now - $0.uptime <= 1 }.map(\.bytes).reduce(0, +)
        return (interval, jitter, lastFrameUptime.map { Self.ms(max(0, now - $0)) }, acknowledgement.map(Self.ms),
                Double(recent) / 1_024, displayedFramesPerSecond(at: now))
    }

    private static func ms(_ seconds: TimeInterval) -> Int { Int((seconds * 1_000).rounded()) }
}
