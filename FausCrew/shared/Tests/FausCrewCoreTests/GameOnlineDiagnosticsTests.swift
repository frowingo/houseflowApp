@testable import FausCrewCore
import XCTest

/// The bounded window and its percentiles; the engines' own measurements are tested
/// beside their harnesses.
final class GameOnlineDiagnosticsTests: XCTestCase {
    func testEmptyWindowHasNoSpread() {
        let window = GameDiagnosticsWindow(capacity: 8)
        XCTAssertNil(window.spread())
        XCTAssertNil(window.percentile(0.5))
    }

    func testSingleSampleIsEveryPercentile() {
        var window = GameDiagnosticsWindow(capacity: 8)
        window.append(0.042)
        XCTAssertEqual(window.spread(scale: 1_000), GameDiagnosticsSpread(p50: 42, p95: 42, max: 42))
    }

    func testKnownSetGivesNearestRankPercentiles() {
        var window = GameDiagnosticsWindow(capacity: 100)
        for value in (1...100).shuffled() { window.append(Double(value)) }
        XCTAssertEqual(window.spread(), GameDiagnosticsSpread(p50: 50, p95: 95, max: 100))
        var small = GameDiagnosticsWindow(capacity: 10)
        for value in [10, 20, 30, 40] { small.append(Double(value)) }
        XCTAssertEqual(small.spread(), GameDiagnosticsSpread(p50: 20, p95: 40, max: 40))
    }

    func testSignedSamplesKeepTheirSign() {
        var window = GameDiagnosticsWindow(capacity: 8)
        for value in [-0.02, 0.01, 0.03] { window.append(value) }
        XCTAssertEqual(window.spread(scale: 1_000), GameDiagnosticsSpread(p50: 10, p95: 30, max: 30))
    }

    func testNonFiniteSamplesAreDroppedSoReadingNeverTraps() {
        var window = GameDiagnosticsWindow(capacity: 8)
        for value in [Double.nan, .infinity, -.infinity, 0.012] { window.append(value) }
        XCTAssertEqual(window.count, 1)
        XCTAssertEqual(window.spread(scale: 1_000), GameDiagnosticsSpread(p50: 12, p95: 12, max: 12))
    }

    func testWindowKeepsOnlyTheNewestSamples() {
        var window = GameDiagnosticsWindow(capacity: 4)
        for value in 1...10 { window.append(Double(value)) }
        XCTAssertEqual(window.count, 4)
        XCTAssertEqual(window.spread(), GameDiagnosticsSpread(p50: 8, p95: 10, max: 10))
        window.removeAll()
        XCTAssertNil(window.spread())
    }

    func testSnapshotGapsAreNotCountedAcrossATimelineRestart() {
        let recorder = GameOnlineDiagnosticsRecorder()
        recorder.snapshotArrived(at: 1)
        recorder.snapshotArrived(at: 1.05)
        recorder.timelineRestarted()
        recorder.snapshotArrived(at: 9)
        recorder.snapshotArrived(at: 9.04)
        let spread = recorder.diagnostics(at: 10, roundTrip: nil, snapshotRateHz: nil).snapshotInterval
        XCTAssertEqual(spread, GameDiagnosticsSpread(p50: 40, p95: 50, max: 50))
    }

    func testDisplayStepsCountBackwardAndJumpAndSkipTheFirstRender() throws {
        let recorder = GameOnlineDiagnosticsRecorder()
        XCTAssertNil(recorder.displayStep(now: 1, simulationTime: 5))
        XCTAssertEqual(try XCTUnwrap(recorder.displayStep(now: 1.0167, simulationTime: 5.0167)), 0.0167, accuracy: 0.000_1)
        XCTAssertNotNil(recorder.displayStep(now: 1.0333, simulationTime: 5.0))
        XCTAssertEqual(recorder.backwardDisplaySteps, 1)
        recorder.displayInterrupted()
        XCTAssertNil(recorder.displayStep(now: 2, simulationTime: 1), "The first render after an interruption has no step")
        XCTAssertEqual(recorder.backwardDisplaySteps, 1)
    }

    func testRemoteTeleportsNeedAStepBeyondWhatSpeedAllows() {
        let recorder = GameOnlineDiagnosticsRecorder()
        recorder.remoteRendered(id: "a", x: 0, y: 0, isAlive: true, maximumStep: nil)
        recorder.remoteRendered(id: "a", x: 30, y: 0, isAlive: true, maximumStep: 40)
        XCTAssertEqual(recorder.remoteTeleports, 0)
        recorder.remoteRendered(id: "a", x: 130, y: 0, isAlive: true, maximumStep: 40)
        XCTAssertEqual(recorder.remoteTeleports, 1)
        recorder.remoteRendered(id: "a", x: 900, y: 0, isAlive: false, maximumStep: 40)
        recorder.remoteRendered(id: "a", x: 0, y: 0, isAlive: true, maximumStep: 40)
        XCTAssertEqual(recorder.remoteTeleports, 1, "A dead rocket is forgotten")
    }

    func testFramesPerSecondCountsTheLastSecond() {
        let recorder = GameOnlineDiagnosticsRecorder()
        for index in 0..<120 { recorder.displayedFrame(at: Double(index) / 60) }
        XCTAssertEqual(recorder.displayedFramesPerSecond(at: 119.0 / 60), 60)
    }
}
