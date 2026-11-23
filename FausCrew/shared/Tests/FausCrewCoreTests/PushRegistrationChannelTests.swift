import FausCrewCore
import XCTest

final class PushRegistrationChannelTests: XCTestCase {
    private let channel = PushRegistrationChannel()

    private func drain() -> [PushRegistrationEffect] { channel.drainEffects() }

    private func finishCleanup() {
        channel.unregisterFinished()
        channel.localTokenDeleted()
        XCTAssertFalse(channel.isCleaningUp)
    }

    func testLaunchWithStoredSessionThenToken() {
        channel.setSession(userID: "u1")
        XCTAssertEqual(drain(), [])
        channel.setToken("t1")
        XCTAssertEqual(drain(), [.register(token: "t1")])
    }

    func testTokenThenSession() {
        channel.setToken("t1")
        XCTAssertEqual(drain(), [])
        channel.setSession(userID: "u1")
        XCTAssertEqual(drain(), [.register(token: "t1")])
    }

    func testTheSamePairIsRegisteredOncePerProcess() {
        channel.setSession(userID: "u1")
        channel.setToken("t1")
        _ = drain()
        channel.setToken("t1")
        channel.setSession(userID: "u1")
        channel.setSession(userID: nil)
        channel.setSession(userID: "u1")
        XCTAssertEqual(drain(), [], "Also while the request is in flight")
        channel.setToken("t1")
        XCTAssertEqual(drain(), [])
    }

    func testTokenRefreshRegistersTheNewToken() {
        channel.setSession(userID: "u1")
        channel.setToken("t1")
        _ = drain()
        channel.setToken("t2")
        XCTAssertEqual(drain(), [.register(token: "t2")])
    }

    func testAnAttemptedPairIsNotRetriedButANewTokenIs() {
        channel.setSession(userID: "u1")
        channel.setToken("t1")
        _ = drain()
        channel.setToken("t1")
        channel.setSession(userID: "u1")
        XCTAssertEqual(drain(), [])
        channel.setToken("t2")
        XCTAssertEqual(drain(), [.register(token: "t2")])
    }

    func testBlankValuesClearTheUserAndToken() {
        channel.setSession(userID: "u1")
        channel.setToken(" ")
        channel.setSession(userID: "")
        channel.setToken("t1")
        XCTAssertEqual(drain(), [])
    }

    func testUserInitiatedSignOutUnregistersThenDeletesTheLocalToken() {
        channel.setSession(userID: "u1")
        channel.setToken("t1")
        _ = drain()
        channel.signOut(reason: .userInitiated)
        XCTAssertEqual(drain(), [.unregister(token: "t1"), .deleteLocalToken])
        XCTAssertTrue(channel.isCleaningUp)
        channel.unregisterFinished()
        XCTAssertTrue(channel.isCleaningUp)
        channel.localTokenDeleted()
        XCTAssertFalse(channel.isCleaningUp)
    }

    func testRejectedSessionAndDeletedAccountOnlyDeleteTheLocalToken() {
        for reason in [PushSignOutReason.sessionRejected, .accountDeleted] {
            let channel = PushRegistrationChannel()
            channel.setSession(userID: "u1")
            channel.setToken("t1")
            _ = channel.drainEffects()
            channel.signOut(reason: reason)
            XCTAssertEqual(channel.drainEffects(), [.deleteLocalToken], reason.rawValue)
            channel.localTokenDeleted()
            XCTAssertFalse(channel.isCleaningUp)
        }
    }

    func testUserInitiatedSignOutWithoutATokenOnlyDeletesLocally() {
        channel.setSession(userID: "u1")
        channel.signOut(reason: .userInitiated)
        XCTAssertEqual(drain(), [.deleteLocalToken])
    }

    func testUserInitiatedSignOutAfterTheUserWasClearedStillUnregistersTheKnownToken() {
        channel.setSession(userID: "u1")
        channel.setToken("t1")
        _ = drain()
        channel.setSession(userID: nil) // e.g. an error screen
        channel.signOut(reason: .userInitiated)
        XCTAssertEqual(drain(), [.unregister(token: "t1"), .deleteLocalToken])
    }

    func testSignOutWhenNeverSignedInDoesNothing() {
        channel.signOut(reason: .userInitiated)
        XCTAssertEqual(drain(), [])
        XCTAssertFalse(channel.isCleaningUp)
        channel.setSession(userID: "u1")
        channel.setToken("t1")
        XCTAssertEqual(drain(), [.register(token: "t1")], "Nothing is left pending")
    }

    func testTokensDuringCleanupAreIgnored() {
        channel.setSession(userID: "u1")
        channel.setToken("t1")
        _ = drain()
        channel.signOut(reason: .userInitiated)
        _ = drain()
        channel.setToken("t1")
        channel.setToken("t2")
        finishCleanup()
        channel.setSession(userID: "u2")
        XCTAssertEqual(drain(), [], "The ignored tokens are not remembered")
    }

    func testLoginDuringCleanupWaitsForTheCleanupAndAFreshToken() {
        channel.setSession(userID: "u1")
        channel.setToken("t1")
        _ = drain()
        channel.signOut(reason: .userInitiated)
        _ = drain()
        channel.setSession(userID: "u2")
        XCTAssertEqual(drain(), [])
        channel.unregisterFinished()
        channel.localTokenDeleted()
        XCTAssertEqual(drain(), [], "No token yet: the old one was deleted")
        channel.setToken("t2")
        XCTAssertEqual(drain(), [.register(token: "t2")])
    }

    func testDuplicateSignOutDuringCleanupEmitsNothingMore() {
        channel.setSession(userID: "u1")
        channel.setToken("t1")
        _ = drain()
        channel.signOut(reason: .userInitiated)
        _ = drain()
        channel.signOut(reason: .sessionRejected)
        XCTAssertEqual(drain(), [])
        finishCleanup()
        channel.setToken("t2")
        XCTAssertEqual(drain(), [], "The second sign-out cleared the user that was waiting")
    }

    func testNewUserWithoutSignOutRegistersTheSameTokenForThem() {
        channel.setSession(userID: "A")
        channel.setToken("t1")
        _ = drain()
        channel.setSession(userID: nil)
        XCTAssertEqual(drain(), [])
        channel.setSession(userID: "B")
        XCTAssertEqual(drain(), [.register(token: "t1")])
    }

    func testAccountSwitchOnTheSameDeviceRegistersTheNewUserWithAFreshToken() {
        channel.setSession(userID: "A")
        channel.setToken("t1")
        _ = drain()
        channel.signOut(reason: .userInitiated)
        XCTAssertEqual(drain(), [.unregister(token: "t1"), .deleteLocalToken])
        finishCleanup()
        channel.setSession(userID: "B")
        XCTAssertEqual(drain(), [])
        channel.setToken("t2")
        XCTAssertEqual(drain(), [.register(token: "t2")])
    }

    func testRedactedTokenKeepsEightCharacters() {
        XCTAssertEqual(PushTokenLog.redacted("abcdefghijkl"), "abcdefgh…")
        XCTAssertEqual(PushTokenLog.redacted("abc"), "abc…")
    }
}
