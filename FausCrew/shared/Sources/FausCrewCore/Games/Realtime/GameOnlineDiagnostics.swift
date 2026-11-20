import Foundation

/// A window's median, 95th percentile and maximum, rounded to whole units.
public struct GameDiagnosticsSpread: Equatable, Sendable {
    public var p50: Int
    public var p95: Int
    public var max: Int

    public init(p50: Int, p95: Int, max: Int) {
        self.p50 = p50
        self.p95 = p95
        self.max = max
    }
}

/// Why the flight or race lost control of the robot; lifecycle resets (reconnect, new
/// grant, new round) are not losses.
public struct GameControlLosses: Equatable, Sendable {
    /// No fresh snapshot for longer than the display may extrapolate.
    public var stale = 0
    /// An input stayed unacknowledged through every retransmit.
    public var retransmit = 0
    /// The server rejected an input.
    public var reject = 0
    /// A send failure or an overflowing input queue.
    public var other = 0

    public var total: Int { stale + retransmit + reject + other }
}

/// What the debug overlay shows during a device test of an online game. Technical, not
/// localized; the same text on iOS and Android. Fields of the other game stay nil or 0.
public struct GameOnlineDiagnostics: Equatable, Sendable {
    public var lines: [String]

    /// Ping → pong round trip (ms).
    public var roundTrip: GameDiagnosticsSpread?
    /// Time between accepted snapshots of one timeline (ms).
    public var snapshotInterval: GameDiagnosticsSpread?
    /// Input sent → first snapshot that covers it (ms).
    public var acknowledgement: GameDiagnosticsSpread?
    public var snapshotRateHz: Int?
    public var displayFramesPerSecond = 0
    public var resyncRequests = 0
    public var controlLosses = GameControlLosses()
    /// Inputs the player made that were dropped for lack of control or a fresh snapshot.
    public var swallowedInputs = 0
    /// Faus Switch taps while the robot was not on a surface.
    public var unsupportedInputs = 0
    /// Local prediction correction (world units), before the limit; the Rockets player or the Switch robot.
    public var localCorrection: GameDiagnosticsSpread?
    public var localSnaps = 0

    /// Rockets: |rendered simulation step − wall step| (ms).
    public var displayJump: GameDiagnosticsSpread?
    /// Rockets: renders whose simulation time went backward.
    public var backwardDisplaySteps = 0
    /// Rockets: remote rockets that moved farther between renders than their speed allows.
    public var remoteTeleports = 0

    /// Switch: how far the display clock runs ahead of the snapshot pace (ms, signed).
    public var clockAhead: GameDiagnosticsSpread?
    /// Switch: clock resets to a snapshot far behind it (a screen jump back).
    public var clockSnaps = 0
    /// Switch: clock jumps forward to an early snapshot (a screen jump ahead), with their size (ms).
    public var pullForwards = 0
    public var pullForward: GameDiagnosticsSpread?
    public var remoteCorrection: GameDiagnosticsSpread?
    public var remoteSnaps = 0
    /// Switch, estimated: acknowledged flips the server probably ran late enough to be clipped.
    public var clippedFlips = 0
}

/// A bounded window of samples (a ring buffer): percentiles are computed only when read.
struct GameDiagnosticsWindow {
    private var values: [Double] = []
    private var oldest = 0
    let capacity: Int

    init(capacity: Int) { self.capacity = max(1, capacity) }

    var count: Int { values.count }

    /// A non-finite sample is dropped: the read would trap converting it to `Int`.
    mutating func append(_ value: Double) {
        guard value.isFinite else { return }
        if values.count < capacity {
            values.append(value)
        } else {
            values[oldest] = value
            oldest = (oldest + 1) % capacity
        }
    }

    mutating func removeAll() {
        values.removeAll(keepingCapacity: true)
        oldest = 0
    }

    func count(where isIncluded: (Double) -> Bool) -> Int { values.reduce(0) { isIncluded($1) ? $0 + 1 : $0 } }

    /// Nearest-rank percentile of the window; nil when empty.
    func percentile(_ fraction: Double) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        return sorted[min(sorted.count - 1, max(0, Int((fraction * Double(sorted.count)).rounded(.up)) - 1))]
    }

    /// p50, p95 and max, each multiplied by `scale` (1 000 for seconds → ms) and rounded.
    func spread(scale: Double = 1) -> GameDiagnosticsSpread? {
        guard let p50 = percentile(0.5), let p95 = percentile(0.95), let largest = values.max() else { return nil }
        func rounded(_ value: Double) -> Int { Int((value * scale).rounded()) }
        return GameDiagnosticsSpread(p50: rounded(p50), p95: rounded(p95), max: rounded(largest))
    }
}

enum GameControlLossCause { case stale, retransmit, reject, other }

/// What the Rockets flight and Switch race machines report into; the overlay reads it ~2×/s.
/// Everything is bounded: windows are ring buffers and the rest are counters.
final class GameOnlineDiagnosticsRecorder {
    // Window sizes are sample counts: 600 samples are ~20 s of 30 Hz snapshots or ~10 s of 60 Hz frames.
    private var snapshotIntervals = GameDiagnosticsWindow(capacity: 600)
    private var acknowledgements = GameDiagnosticsWindow(capacity: 64)
    private var displayJumps = GameDiagnosticsWindow(capacity: 600)
    private var localCorrections = GameDiagnosticsWindow(capacity: 128)
    private var remoteCorrections = GameDiagnosticsWindow(capacity: 128)
    private var clockAhead = GameDiagnosticsWindow(capacity: 600)
    private var pullForward = GameDiagnosticsWindow(capacity: 128)
    private var displayed = GameDiagnosticsWindow(capacity: 256)
    /// When the current run of playing frames began and the last one was drawn: a gap longer
    /// than `frameStreakGap` (countdown, the end, the app in the background) starts a new run.
    private var frameStreakStart: TimeInterval?
    private var lastDisplayedAt: TimeInterval?
    private static let frameStreakGap: TimeInterval = 0.25

    private(set) var resyncRequests = 0
    private(set) var controlLosses = GameControlLosses()
    private(set) var swallowedInputs = 0
    private(set) var unsupportedInputs = 0
    private(set) var backwardDisplaySteps = 0
    private(set) var remoteTeleports = 0
    private(set) var localSnaps = 0
    private(set) var remoteSnaps = 0
    private(set) var clockSnaps = 0
    private(set) var clippedFlips = 0
    private(set) var pullForwards = 0

    private var lastArrival: TimeInterval?
    private var lastDisplay: (now: TimeInterval, time: TimeInterval)?
    private var remotePositions: [String: (x: Double, y: Double)] = [:]

    // MARK: Reporting

    /// An accepted game snapshot; its gap to the previous one is counted unless the timeline restarted.
    func snapshotArrived(at uptime: TimeInterval) {
        if let lastArrival { snapshotIntervals.append(max(0, uptime - lastArrival)) }
        lastArrival = uptime
    }

    /// A new round, epoch, resync or reconnect: the gap across it would mean nothing.
    func timelineRestarted() {
        lastArrival = nil
        displayInterrupted()
    }

    func inputAcknowledged(after latency: TimeInterval) { acknowledgements.append(max(0, latency)) }

    func resyncRequested() { resyncRequests += 1 }

    func controlLost(_ cause: GameControlLossCause) {
        switch cause {
        case .stale: controlLosses.stale += 1
        case .retransmit: controlLosses.retransmit += 1
        case .reject: controlLosses.reject += 1
        case .other: controlLosses.other += 1
        }
    }

    func inputSwallowed() { swallowedInputs += 1 }
    func inputUnsupported() { unsupportedInputs += 1 }

    func displayedFrame(at uptime: TimeInterval) {
        if let last = lastDisplayedAt, uptime - last >= 0, uptime - last <= Self.frameStreakGap {
            // Same run.
        } else {
            frameStreakStart = uptime
        }
        lastDisplayedAt = uptime
        displayed.append(uptime)
    }

    /// The HUD's frame rate: 0 (no chip) until playing frames have been drawn without a pause for
    /// a whole second, and again once they stop, so a start, the end or a return from the
    /// background never shows a half-counted low number.
    func steadyFramesPerSecond(at now: TimeInterval) -> Int {
        guard let start = frameStreakStart, let last = lastDisplayedAt,
              now - last <= Self.frameStreakGap, now - start >= 1 else { return 0 }
        return displayedFramesPerSecond(at: now)
    }

    func displayedFramesPerSecond(at now: TimeInterval) -> Int {
        displayed.count { now - $0 >= 0 && now - $0 < 1 }
    }

    /// A render that is not a playing flight (or a restart): the next playing render has no step.
    func displayInterrupted() {
        lastDisplay = nil
        remotePositions.removeAll(keepingCapacity: true)
    }

    /// One playing render: the rendered simulation time against the wall clock. Returns the
    /// wall step, nil for the first render of a timeline.
    func displayStep(now: TimeInterval, simulationTime: TimeInterval) -> TimeInterval? {
        defer { lastDisplay = (now, simulationTime) }
        guard let last = lastDisplay else { return nil }
        let wall = now - last.now
        let step = simulationTime - last.time
        displayJumps.append(abs(step - wall))
        if step < 0 { backwardDisplaySteps += 1 }
        return wall
    }

    /// A remote rocket's rendered position; `maximumStep` (nil on a timeline's first render)
    /// is the farthest it may move since the previous render.
    func remoteRendered(id: String, x: Double, y: Double, isAlive: Bool, maximumStep: Double?) {
        guard isAlive else {
            remotePositions[id] = nil
            return
        }
        if let last = remotePositions[id], let maximumStep, hypot(x - last.x, y - last.y) > maximumStep {
            remoteTeleports += 1
        }
        remotePositions[id] = (x, y)
    }

    func localCorrected(by distance: Double, snapped: Bool) {
        localCorrections.append(distance)
        if snapped { localSnaps += 1 }
    }

    func remoteCorrected(by distance: Double, snapped: Bool) {
        remoteCorrections.append(distance)
        if snapped { remoteSnaps += 1 }
    }

    /// The display clock against the newest snapshot's pace, in seconds (positive = clock ahead).
    /// A clock behind the snapshot is pulled forward to it: a forward jump too, counted apart
    /// (below 1 ms is the normal early snapshot, not a jump).
    func clockPaced(ahead: Double, snapped: Bool) {
        clockAhead.append(ahead)
        if snapped { clockSnaps += 1 }
        if ahead < -0.001 {
            pullForwards += 1
            pullForward.append(-ahead)
        }
    }

    func flipMayBeClipped() { clippedFlips += 1 }

    // MARK: Reading

    /// The numbers both games share; the game-specific readers below add theirs and the text.
    func diagnostics(at now: TimeInterval, roundTrip: GameDiagnosticsSpread?, snapshotRateHz: Int?) -> GameOnlineDiagnostics {
        var result = GameOnlineDiagnostics(lines: [])
        result.roundTrip = roundTrip
        result.snapshotInterval = snapshotIntervals.spread(scale: 1_000)
        result.acknowledgement = acknowledgements.spread(scale: 1_000)
        result.snapshotRateHz = snapshotRateHz
        result.displayFramesPerSecond = displayedFramesPerSecond(at: now)
        result.resyncRequests = resyncRequests
        result.controlLosses = controlLosses
        result.swallowedInputs = swallowedInputs
        result.unsupportedInputs = unsupportedInputs
        result.localCorrection = localCorrections.spread()
        result.localSnaps = localSnaps
        return result
    }

    func rocketsDiagnostics(at now: TimeInterval, roundTrip: GameDiagnosticsSpread?,
                            snapshotRateHz: Int?) -> GameOnlineDiagnostics {
        var result = diagnostics(at: now, roundTrip: roundTrip, snapshotRateHz: snapshotRateHz)
        result.displayJump = displayJumps.spread(scale: 1_000)
        result.backwardDisplaySteps = backwardDisplaySteps
        result.remoteTeleports = remoteTeleports
        result.remoteCorrection = remoteCorrections.spread()
        result.remoteSnaps = remoteSnaps
        result.lines = [
            Self.roundTripLine(result), Self.snapshotLine(result), Self.acknowledgementLine(result),
            "clock jump p95 \(Self.value(result.displayJump?.p95)) ms · max \(Self.value(result.displayJump?.max))"
                + " · back \(backwardDisplaySteps)",
            "fix L \(Self.triple(result.localCorrection)) u · snap \(localSnaps)",
            "fix R \(Self.triple(result.remoteCorrection)) u · snap \(remoteSnaps) · teleports \(remoteTeleports)",
            Self.controlLine(result),
            "swallowed \(swallowedInputs)",
        ]
        return result
    }

    func switchDiagnostics(at now: TimeInterval, roundTrip: GameDiagnosticsSpread?,
                           snapshotRateHz: Int?) -> GameOnlineDiagnostics {
        var result = diagnostics(at: now, roundTrip: roundTrip, snapshotRateHz: snapshotRateHz)
        result.clockAhead = clockAhead.spread(scale: 1_000)
        result.clockSnaps = clockSnaps
        result.pullForwards = pullForwards
        result.pullForward = pullForward.spread(scale: 1_000)
        result.remoteCorrection = remoteCorrections.spread()
        result.remoteSnaps = remoteSnaps
        result.clippedFlips = clippedFlips
        result.lines = [
            Self.roundTripLine(result), Self.snapshotLine(result), Self.acknowledgementLine(result),
            "clock ahead \(Self.pair(result.clockAhead)) ms · snap \(clockSnaps)"
                + " · pull \(result.pullForwards)/\(Self.value(result.pullForward?.p95))",
            "fix L \(Self.triple(result.localCorrection)) u · snap \(localSnaps)",
            "fix R \(Self.triple(result.remoteCorrection)) u · snap \(remoteSnaps)",
            Self.controlLine(result),
            "swallowed \(swallowedInputs) · unsupported \(unsupportedInputs)",
            "clip? \(clippedFlips) (estimated)",
        ]
        return result
    }

    // MARK: Text

    private static func value(_ number: Int?) -> String { number.map(String.init) ?? "–" }
    private static func pair(_ spread: GameDiagnosticsSpread?) -> String {
        spread.map { "\($0.p50)/\($0.p95)" } ?? "–"
    }
    private static func triple(_ spread: GameDiagnosticsSpread?) -> String {
        spread.map { "\($0.p50)/\($0.p95)/\($0.max)" } ?? "–"
    }

    private static func roundTripLine(_ diagnostics: GameOnlineDiagnostics) -> String {
        "RTT \(pair(diagnostics.roundTrip)) ms (p50/p95)"
    }

    private static func snapshotLine(_ diagnostics: GameOnlineDiagnostics) -> String {
        "snap \(triple(diagnostics.snapshotInterval)) ms · \(diagnostics.snapshotRateHz.map { "\($0) Hz" } ?? "–")"
    }

    private static func acknowledgementLine(_ diagnostics: GameOnlineDiagnostics) -> String {
        "ACK \(pair(diagnostics.acknowledgement)) ms · \(diagnostics.displayFramesPerSecond) fps"
    }

    private static func controlLine(_ diagnostics: GameOnlineDiagnostics) -> String {
        let lost = diagnostics.controlLosses
        return "resync \(diagnostics.resyncRequests) · lost \(lost.total)"
            + " (stale \(lost.stale) retx \(lost.retransmit) rej \(lost.reject) other \(lost.other))"
    }
}
