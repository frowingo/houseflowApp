import Foundation
import HouseFlowCore
import XCTest

final class AppEventsChannelTests: XCTestCase {
    private func channel() -> AppEventsChannel { AppEventsChannel(jitter: { 1 }) }

    private func open(_ channel: AppEventsChannel, house: String? = "h1") throws -> Int {
        channel.setSelectedHouse(house)
        channel.setActive(foreground: true, authenticated: true, now: 0)
        guard case .openSocket(let connection) = try XCTUnwrap(channel.drainEffects().last) else {
            throw XCTSkip("no socket")
        }
        channel.socketOpened(connection: connection, now: 0.1)
        return connection
    }

    func testParsesOnlyKnownSignals() {
        XCTAssertEqual(AppEventsWire.event(from: #"{"type":"ready"}"#), .ready)
        XCTAssertEqual(AppEventsWire.event(from: #"{"type":"user.changed"}"#), .userChanged)
        XCTAssertEqual(AppEventsWire.event(from: #"{"type":"house.changed","houseId":"h1"}"#), .houseChanged(houseID: "h1"))
        XCTAssertNil(AppEventsWire.event(from: #"{"type":"house.changed"}"#))
        XCTAssertNil(AppEventsWire.event(from: #"{"type":"chore.created"}"#))
        XCTAssertNil(AppEventsWire.event(from: "nope"))
    }

    func testReadyForcesProfileAndSelectedHouseAfterTheCoalesceWindow() throws {
        let channel = channel()
        let connection = try open(channel)
        channel.received(text: #"{"type":"ready"}"#, connection: connection, now: 0.2)
        channel.tick(now: 0.5)
        XCTAssertTrue(channel.drainEffects().isEmpty)
        channel.tick(now: 1.0)
        XCTAssertEqual(channel.drainEffects(), [.refresh(profile: true, houseID: "h1")])
    }

    func testNearbySignalsBecomeOneRefreshAndOtherHousesAreIgnored() throws {
        let channel = channel()
        let connection = try open(channel)
        channel.received(text: #"{"type":"house.changed","houseId":"other"}"#, connection: connection, now: 1)
        channel.tick(now: 2)
        XCTAssertTrue(channel.drainEffects().isEmpty, "Another house never triggers a request")
        channel.received(text: #"{"type":"house.changed","houseId":"h1"}"#, connection: connection, now: 3)
        channel.received(text: #"{"type":"house.changed","houseId":"h1"}"#, connection: connection, now: 3.2)
        channel.received(text: #"{"type":"user.changed"}"#, connection: connection, now: 3.4)
        channel.tick(now: 3.8)
        XCTAssertEqual(channel.drainEffects(), [.refresh(profile: true, houseID: "h1")])
        channel.received(text: #"{"type":"house.changed","houseId":"h1"}"#, connection: connection, now: 5)
        channel.tick(now: 6)
        XCTAssertEqual(channel.drainEffects(), [.refresh(profile: false, houseID: "h1")])
    }

    func testSelectionChangeDropsSignalsForThePreviousHouse() throws {
        let channel = channel()
        let connection = try open(channel)
        channel.received(text: #"{"type":"house.changed","houseId":"h1"}"#, connection: connection, now: 1)
        channel.setSelectedHouse("h2")
        channel.tick(now: 2)
        XCTAssertTrue(channel.drainEffects().isEmpty)
    }

    func testBackgroundClosesAndForegroundReopensWithAForcedRefresh() throws {
        let channel = channel()
        _ = try open(channel)
        channel.setActive(foreground: false, authenticated: true, now: 5)
        XCTAssertEqual(channel.drainEffects(), [.closeSocket])
        channel.setActive(foreground: true, authenticated: true, now: 60)
        guard case .openSocket = try XCTUnwrap(channel.drainEffects().first) else { return XCTFail() }
        channel.tick(now: 61)
        XCTAssertEqual(channel.drainEffects(), [.refresh(profile: true, houseID: "h1")])
    }

    func testDropsBackOffExponentiallyAndReadyResetsTheBackoff() throws {
        let channel = channel()
        var connection = try open(channel)
        var now = 1.0
        var delays: [TimeInterval] = []
        for _ in 0..<7 {
            channel.connectionFailed(status: nil, connection: connection, now: now)
            _ = channel.drainEffects()
            let start = now
            while true {
                now += 0.25
                channel.tick(now: now)
                if case .openSocket(let next) = channel.drainEffects().first {
                    connection = next
                    break
                }
            }
            delays.append((now - start).rounded())
        }
        XCTAssertEqual(delays, [1, 2, 4, 8, 16, 30, 30])
        channel.received(text: #"{"type":"ready"}"#, connection: connection, now: now)
        channel.connectionFailed(status: nil, connection: connection, now: now)
        _ = channel.drainEffects()
        channel.tick(now: now + 1.01)
        guard case .openSocket = channel.drainEffects().first else { return XCTFail("Backoff restarts at 1 s") }
    }

    func testUnauthorizedSignsOutWithoutRetrying() throws {
        let channel = channel()
        let connection = try open(channel)
        channel.connectionFailed(status: 401, connection: connection, now: 1)
        XCTAssertEqual(channel.drainEffects(), [.closeSocket, .signedOut])
        channel.tick(now: 100)
        XCTAssertTrue(channel.drainEffects().isEmpty)
    }

    func testSignOutClosesAndStaleSocketEventsAreIgnored() throws {
        let channel = channel()
        let connection = try open(channel)
        channel.setActive(foreground: true, authenticated: false, now: 1)
        XCTAssertEqual(channel.drainEffects(), [.closeSocket])
        channel.received(text: #"{"type":"ready"}"#, connection: connection, now: 1.1)
        channel.tick(now: 5)
        XCTAssertTrue(channel.drainEffects().isEmpty)
    }
}
