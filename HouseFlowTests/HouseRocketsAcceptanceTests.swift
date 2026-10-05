import Foundation
import XCTest
@testable import HouseFlow

@MainActor
final class HouseRocketsAcceptanceTests: XCTestCase {
    func testDiagnosticsAreOptInAndFPSIsRestricted() {
        XCTAssertFalse(HouseRocketsAcceptanceConfiguration.parse(arguments: ["-HouseRocketsFPS", "120"]).isEnabled)
        for fps in [30, 60, 120] {
            let value = HouseRocketsAcceptanceConfiguration.parse(arguments: ["-HouseRocketsDiagnostics", "-HouseRocketsFPS", "\(fps)"])
            XCTAssertTrue(value.isEnabled)
            XCTAssertEqual(value.requestedFramesPerSecond, fps)
        }
        for value in ["0", "59", "240", "nan", "-HouseRocketsDiagnostics"] {
            XCTAssertEqual(HouseRocketsAcceptanceConfiguration.parse(arguments: ["-HouseRocketsDiagnostics", "-HouseRocketsFPS", value]).requestedFramesPerSecond, 60)
        }
        XCTAssertEqual(HouseRocketsAcceptanceConfiguration.parse(arguments: ["-HouseRocketsDiagnostics", "-HouseRocketsFPS"]).requestedFramesPerSecond, 60)
    }

    func testPercentilesUseMeasuredSamplesAndDoNotInventEmptyValues() {
        var window = HouseRocketsAcceptanceWindow()
        XCTAssertNil(window.sample)
        for value in 1...100 { window.append(seconds: Double(value) / 1_000) }
        XCTAssertEqual(window.sample?.count, 100)
        XCTAssertEqual(window.sample?.meanMilliseconds ?? 0, 50.5, accuracy: 0.000_001)
        XCTAssertEqual(window.sample?.p50Milliseconds ?? 0, 50, accuracy: 0.000_001)
        XCTAssertEqual(window.sample?.p95Milliseconds ?? 0, 95, accuracy: 0.000_001)
        XCTAssertEqual(window.sample?.maximumMilliseconds, 100)
    }

    func testWindowIsBoundedAndRejectsInvalidSamples() {
        var window = HouseRocketsAcceptanceWindow()
        for value in 0..<300 { window.append(seconds: Double(value) / 1_000) }
        for value in [Double.nan, .infinity, -.infinity, -1] { window.append(seconds: value) }
        XCTAssertEqual(window.sample?.count, 300)
        XCTAssertEqual(window.sample?.windowCount, 240)
        XCTAssertEqual(window.sample?.meanMilliseconds ?? 0, 179.5, accuracy: 0.000_001)
        XCTAssertEqual(window.sample?.p95Milliseconds ?? 0, 287, accuracy: 0.000_001)
    }

    func testDisabledRecorderProducesNoReports() async {
        var reports: [HouseRocketsAcceptanceReport] = []
        let recorder = HouseRocketsAcceptanceRecorder(configuration: .init(), sink: { reports.append($0) })
        recorder.begin(mode: .housemates)
        recorder.record(.roundTrip, seconds: 0.1)
        recorder.renderedFrame(at: 1, screenMaximumFPS: 120)
        recorder.flush(.stop)
        XCTAssertTrue(reports.isEmpty)
    }

    func testMeasuredFPSIsIndependentOfRequestedFPS() async throws {
        let rig = AcceptanceRecorderRig(fps: 120)
        rig.recorder.begin(mode: .localBots)
        for frame in 0...60 { rig.recorder.renderedFrame(at: Double(frame) / 60, screenMaximumFPS: 60) }
        rig.recorder.flush(.stop)
        let report = try XCTUnwrap(rig.reports.last)
        XCTAssertEqual(report.requestedFramesPerSecond, 120)
        XCTAssertEqual(report.screenMaximumFramesPerSecond, 60)
        XCTAssertEqual(report.measuredFramesPerSecond ?? 0, 60, accuracy: 0.000_001)
    }

    func testBackgroundGapIsNotCountedAsAFrameStall() async throws {
        let rig = AcceptanceRecorderRig()
        rig.recorder.begin(mode: .localBots)
        rig.recorder.renderedFrame(at: 1, screenMaximumFPS: 120)
        rig.recorder.renderedFrame(at: 1.01, screenMaximumFPS: 120)
        rig.recorder.setForeground(false)
        rig.recorder.renderedFrame(at: 20, screenMaximumFPS: 120)
        rig.recorder.record(.roundTrip, seconds: 10)
        rig.recorder.setForeground(true)
        rig.recorder.renderedFrame(at: 30, screenMaximumFPS: 120)
        rig.recorder.renderedFrame(at: 30.01, screenMaximumFPS: 120)
        rig.recorder.flush(.stop)
        let report = try XCTUnwrap(rig.reports.last)
        XCTAssertEqual(report.backgroundCount, 1)
        XCTAssertEqual(report.metrics["frameInterval"]?.count, 2)
        XCTAssertEqual(report.metrics["frameInterval"]?.maximumMilliseconds ?? 0, 10, accuracy: 0.000_001)
        XCTAssertNil(report.metrics["roundTrip"])
    }

    func testPeriodicReportsAreBoundedAndStopIsIdempotent() async {
        let rig = AcceptanceRecorderRig()
        rig.recorder.begin(mode: .housemates)
        for frame in 0..<100 { rig.recorder.renderedFrame(at: Double(frame) / 60, screenMaximumFPS: 120) }
        XCTAssertTrue(rig.reports.isEmpty)
        rig.time.now += 5
        rig.recorder.renderedFrame(at: 2, screenMaximumFPS: 120)
        XCTAssertEqual(rig.reports.count, 1)
        for frame in 121..<240 { rig.recorder.renderedFrame(at: Double(frame) / 60, screenMaximumFPS: 120) }
        XCTAssertEqual(rig.reports.count, 1)
        rig.recorder.flush(.stop); rig.recorder.flush(.stop)
        XCTAssertEqual(rig.reports.count, 2)
    }

    func testRematchClearsSamplesButKeepsDeviceSettings() async throws {
        let rig = AcceptanceRecorderRig(fps: 30)
        rig.recorder.setReduceMotion(true)
        rig.recorder.begin(mode: .housemates)
        rig.recorder.record(.roundTrip, seconds: 0.4)
        rig.recorder.flush(.result)
        rig.recorder.begin(mode: .housemates)
        rig.recorder.flush(.stop)
        let report = try XCTUnwrap(rig.reports.last)
        XCTAssertEqual(report.run, 2)
        XCTAssertTrue(report.reduceMotion)
        XCTAssertEqual(report.requestedFramesPerSecond, 30)
        XCTAssertTrue(report.metrics.isEmpty)
        XCTAssertNil(report.measuredFramesPerSecond)
    }

    func testSnapshotMetricsDeduplicateAndResetOnConnectionOrEpoch() async throws {
        let rig = AcceptanceRecorderRig()
        rig.recorder.begin(mode: .housemates)
        var state = HouseRocketsOnlineLobbyState()
        state.connectionGeneration = UUID()
        state.game = try AcceptanceFixture.snapshot(sequence: 10)
        state.gameReceivedUptime = 100
        rig.recorder.consume(state); rig.recorder.consume(state)
        state.game = try AcceptanceFixture.snapshot(sequence: 11)
        state.gameReceivedUptime = 100.05
        rig.recorder.consume(state)
        state.connectionGeneration = UUID()
        state.game = try AcceptanceFixture.snapshot(sequence: 12)
        state.gameReceivedUptime = 110
        rig.recorder.consume(state)
        state.game = try AcceptanceFixture.snapshot(sequence: 1, epoch: 8)
        state.gameReceivedUptime = 120
        rig.recorder.consume(state)
        state.game = try AcceptanceFixture.snapshot(sequence: 2, epoch: 8)
        state.gameReceivedUptime = 120.05
        state.controlTransferred = true
        rig.recorder.consume(state); rig.recorder.consume(state)
        rig.recorder.flush(.stop)
        let report = try XCTUnwrap(rig.reports.last)
        XCTAssertEqual(report.metrics["snapshotInterval"]?.count, 2)
        XCTAssertEqual(report.metrics["snapshotInterval"]?.meanMilliseconds ?? 0, 50, accuracy: 0.000_001)
        XCTAssertEqual(report.reconnectCount, 1)
        XCTAssertEqual(report.controlTransferCount, 1)
    }

    func testReportContainsOnlyAggregateFields() async throws {
        let rig = AcceptanceRecorderRig()
        rig.recorder.begin(mode: .housemates)
        rig.recorder.record(.roundTrip, seconds: 0.1)
        rig.recorder.flush(.stop)
        let data = try JSONEncoder().encode(XCTUnwrap(rig.reports.last))
        let json = try XCTUnwrap(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let keys = Set(json.keys)
        XCTAssertTrue(keys.isDisjoint(with: ["token", "email", "userId", "houseId", "sessionId", "controlGeneration", "connectionId", "payload"]))
        XCTAssertEqual(json["schemaVersion"] as? Int, 1)
        XCTAssertNotNil(json["metrics"])
    }

    func testHUDCadenceIsIndependentOfRenderFPS() throws {
        for fps in [30, 60, 120] {
            var cadence = HouseRocketsPresentationCadence()
            var count = 0
            let original = try AcceptanceFixture.presentation()
            for tick in 0..<fps {
                var frame = original.frame
                frame.elapsedTime += Double(tick) / Double(fps)
                let value = HouseRocketsOnlinePresentation(frame: frame, canSteer: true, isSyncing: false, eliminations: [])
                if cadence.shouldPublish(value, at: Double(tick) / Double(fps)) { count += 1 }
            }
            XCTAssertLessThanOrEqual(count, 20)
            XCTAssertGreaterThanOrEqual(count, 15) // 30 FPS quantizes a 50 ms HUD interval to two frames.
        }
    }

    func testControlLossAndRecoveryBypassHUDThrottle() throws {
        var cadence = HouseRocketsPresentationCadence()
        let original = try AcceptanceFixture.presentation()
        XCTAssertTrue(cadence.shouldPublish(original, at: 100))
        let lost = HouseRocketsOnlinePresentation(frame: original.frame, canSteer: false, isSyncing: true, eliminations: [])
        XCTAssertTrue(cadence.shouldPublish(lost, at: 100.001))
        XCTAssertTrue(cadence.shouldPublish(original, at: 100.002))
        XCTAssertFalse(cadence.shouldPublish(original, at: 101))
    }

    func testEliminationAndTerminalPhaseBypassHUDThrottle() throws {
        var cadence = HouseRocketsPresentationCadence()
        let original = try AcceptanceFixture.presentation()
        XCTAssertTrue(cadence.shouldPublish(original, at: 100))
        let eliminated = try AcceptanceFixture.presentation(alive: false)
        XCTAssertTrue(cadence.shouldPublish(eliminated, at: 100.001))
        let finalizing = try AcceptanceFixture.presentation(alive: false, phase: "finalizing")
        XCTAssertTrue(cadence.shouldPublish(finalizing, at: 100.002))
        XCTAssertTrue(cadence.shouldPublish(nil, at: 100.003))
        XCTAssertFalse(cadence.shouldPublish(nil, at: 100.004))
        XCTAssertTrue(cadence.shouldPublish(original, at: 100.005))
    }

    func testHUDKeepsLatestGeometryWhenNextUpdateIsDue() throws {
        var cadence = HouseRocketsPresentationCadence()
        let original = try AcceptanceFixture.presentation()
        XCTAssertTrue(cadence.shouldPublish(original, at: 100))
        var frame = original.frame
        frame.cameraX = 99
        let value = HouseRocketsOnlinePresentation(frame: frame, canSteer: original.canSteer, isSyncing: original.isSyncing, eliminations: [])
        XCTAssertFalse(cadence.shouldPublish(value, at: 100.01))
        XCTAssertTrue(cadence.shouldPublish(value, at: 100.05))
    }
}

@MainActor
private final class AcceptanceTime { var now: TimeInterval = 100 }

@MainActor
private final class AcceptanceRecorderRig {
    let time = AcceptanceTime()
    var reports: [HouseRocketsAcceptanceReport] = []
    var recorder: HouseRocketsAcceptanceRecorder!
    init(fps: Int = 60) {
        let time = self.time
        recorder = .init(configuration: .init(isEnabled: true, requestedFramesPerSecond: fps),
            clock: .init(wallTime: { Date() }, uptime: { time.now }), sink: { [weak self] in self?.reports.append($0) })
    }
}

@MainActor
enum AcceptanceFixture {
    static let playerID = "507f1f77bcf86cd799439021"
    static func snapshot(sequence: Int64 = 10, epoch: Int64 = 7, alive: Bool = true, phase: String = "playing") throws -> HouseRocketsSnapshotDTO {
        #if SWIFT_PACKAGE
        let bundle = Bundle.module
        #else
        let bundle = Bundle(for: HouseRocketsAcceptanceTests.self)
        #endif
        let url = try XCTUnwrap(bundle.url(forResource: "houseRocketsProtocol", withExtension: "json", subdirectory: "Fixtures")
            ?? bundle.url(forResource: "houseRocketsProtocol", withExtension: "json"))
        let root = try XCTUnwrap(JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any])
        let entries = try XCTUnwrap(root["serverMessages"] as? [[String: Any]])
        let entry = try XCTUnwrap(entries.first { $0["name"] as? String == "playing" }?["message"] as? [String: Any])
        var payload = try XCTUnwrap(entry["payload"] as? [String: Any])
        payload["runtimeEpoch"] = epoch; payload["stateSequence"] = sequence; payload["phase"] = phase
        var players = try XCTUnwrap(payload["players"] as? [[String: Any]])
        players[0]["playerId"] = playerID; players[0]["isAlive"] = alive
        players[0]["eliminatedAtTick"] = alive ? NSNull() : payload["tick"]
        payload["players"] = players
        return try GameRealtimeCodec.makeDecoder().decode(HouseRocketsSnapshotDTO.self, from: JSONSerialization.data(withJSONObject: payload))
    }
    static func presentation(alive: Bool = true, phase: String = "playing") throws -> HouseRocketsOnlinePresentation {
        .init(frame: try HouseRocketsRenderMapper.online(snapshot(alive: alive, phase: phase), localPlayerID: playerID),
            canSteer: alive && phase == "playing", isSyncing: false, eliminations: [])
    }
}
