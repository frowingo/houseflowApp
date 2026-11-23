import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class PushRegistrationServiceTests: XCTestCase {
    private var journal: Journal!
    private var http: FakeHTTP!
    private var keychain: FakeKeychainStore!
    private var tokens: FakeTokens!
    private var service: PushRegistrationService!

    override func setUp() async throws {
        journal = Journal()
        http = FakeHTTP(journal: journal)
        keychain = FakeKeychainStore()
        keychain.authToken = "jwt-1"
        tokens = FakeTokens(journal: journal)
        tokens.token = "token-1"
        service = PushRegistrationService(http: http, keychain: keychain, tokens: tokens)
    }

    func testLaunchWithStoredSessionRegistersOnce() async {
        service.start()
        service.setSession(userID: "u1")
        service.setSession(userID: "u1")
        await settle { self.http.requests.count >= 1 }
        await settle()

        XCTAssertEqual(http.requests.count, 1)
        let request = http.requests[0]
        XCTAssertEqual(request.method, "POST")
        XCTAssertEqual(request.path, "notification/devices")
        XCTAssertEqual(request.headers["Authorization"], "Bearer jwt-1")
        XCTAssertEqual(body(of: request), ["token": "token-1", "platform": "ios"])
    }

    func testUserInitiatedSignOutSendsDeleteWithJWTThenDeletesLocalTokenThenFetchesFresh() async {
        service.start()
        service.setSession(userID: "u1")
        await settle { self.http.requests.count >= 1 }
        journal.events.removeAll()
        tokens.token = "token-2"

        service.signOut(reason: .userInitiated)
        keychain.authToken = nil
        await settle { self.journal.events.count >= 3 }

        XCTAssertEqual(journal.events, ["DELETE", "deleteToken", "currentToken"])
        let request = http.requests[1]
        XCTAssertEqual(request.method, "DELETE")
        XCTAssertEqual(request.headers["Authorization"], "Bearer jwt-1")
        XCTAssertEqual(body(of: request), ["token": "token-1"])
    }

    func testRejectedSessionAndDeletedAccountSendNoDelete() async {
        for reason in [PushSignOutReason.sessionRejected, .accountDeleted] {
            setUpFreshService()
            service.start()
            service.setSession(userID: "u1")
            await settle { self.http.requests.count >= 1 }
            journal.events.removeAll()

            service.signOut(reason: reason)
            await settle { self.journal.events.count >= 2 }

            XCTAssertEqual(journal.events, ["deleteToken", "currentToken"], "\(reason)")
            XCTAssertEqual(http.requests.map(\.method), ["POST"], "\(reason)")
        }
    }

    func testNoJWTSendsNoRequest() async {
        keychain.authToken = nil
        service.start()
        service.setSession(userID: "u1")
        await settle()
        await settle()

        XCTAssertTrue(http.requests.isEmpty)
    }

    func testLoginDuringCleanupRegistersOnlyTheFreshToken() async {
        service.start()
        service.setSession(userID: "u1")
        await settle { self.http.requests.count >= 1 }
        tokens.token = "token-2"
        keychain.authToken = "jwt-2"

        service.signOut(reason: .sessionRejected)
        service.setSession(userID: "u2")
        await settle { self.http.requests.count >= 2 }
        await settle()

        XCTAssertEqual(http.requests.count, 2)
        XCTAssertEqual(body(of: http.requests[1]), ["token": "token-2", "platform": "ios"])
        XCTAssertEqual(http.requests[1].headers["Authorization"], "Bearer jwt-2")
    }

    func testStartupTokenFetchedBeforeASignOutIsNotRegistered() async {
        tokens.holdNextFetch = true
        service.start()
        service.setSession(userID: "u1")
        tokens.token = "token-2"

        service.signOut(reason: .sessionRejected)
        service.setSession(userID: "u2")
        await settle { self.http.requests.count >= 1 }
        tokens.releaseHeldFetch(returning: "token-1")
        await settle()

        XCTAssertEqual(http.requests.count, 1)
        XCTAssertEqual(body(of: http.requests[0]), ["token": "token-2", "platform": "ios"])
    }

    func testUserInitiatedSignOutAfterSessionWasClearedStillSendsDelete() async {
        service.start()
        service.setSession(userID: "u1")
        await settle { self.http.requests.count >= 1 }
        // A transient non-signed-in state (e.g. the house error screen) clears the user first.
        service.setSession(userID: nil)
        journal.events.removeAll()

        service.signOut(reason: .userInitiated)
        keychain.authToken = nil
        await settle { self.journal.events.count >= 3 }

        XCTAssertEqual(journal.events, ["DELETE", "deleteToken", "currentToken"])
        XCTAssertEqual(http.requests[1].headers["Authorization"], "Bearer jwt-1")
    }

    // MARK: - Helpers

    private func setUpFreshService() {
        http = FakeHTTP(journal: journal)
        tokens = FakeTokens(journal: journal)
        tokens.token = "token-1"
        service = PushRegistrationService(http: http, keychain: keychain, tokens: tokens)
    }

    /// Lets the service's background jobs run until `condition` holds (or a bounded wait ends).
    private func settle(until condition: @MainActor () -> Bool = { false }) async {
        for _ in 0..<200 {
            if condition() { return }
            try? await Task.sleep(for: .milliseconds(5))
        }
    }

    private func body(of request: HTTPRequest) -> [String: String]? {
        request.body.flatMap { try? JSONDecoder().decode([String: String].self, from: $0) }
    }
}

private final class Journal {
    var events: [String] = []
}

@MainActor
private final class FakeHTTP: HTTPClient {
    private(set) var requests: [HTTPRequest] = []
    private let journal: Journal

    init(journal: Journal) { self.journal = journal }

    func send(_ request: HTTPRequest) async throws -> HTTPResponse {
        requests.append(request)
        journal.events.append(request.method)
        return HTTPResponse(statusCode: 200, headers: [:], body: Data(#"{"success":true}"#.utf8))
    }
}

@MainActor
private final class FakeTokens: PushTokenProviding {
    var token: String?
    /// The next `currentToken()` waits until `releaseHeldFetch(returning:)`.
    var holdNextFetch = false
    private var held: CheckedContinuation<String?, Never>?
    private let journal: Journal

    init(journal: Journal) { self.journal = journal }

    func currentToken() async -> String? {
        journal.events.append("currentToken")
        if holdNextFetch {
            holdNextFetch = false
            return await withCheckedContinuation { held = $0 }
        }
        return token
    }

    func releaseHeldFetch(returning token: String?) {
        held?.resume(returning: token)
        held = nil
    }

    func deleteToken() async {
        journal.events.append("deleteToken")
    }
}
