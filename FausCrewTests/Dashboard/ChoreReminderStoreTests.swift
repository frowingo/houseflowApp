import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class ChoreReminderStoreTests: XCTestCase {
    private var service: FakeNotificationService!
    private var toast: ToastStore!
    private var userID: String?
    private var store: ChoreReminderStore!

    override func setUp() async throws {
        APILanguage.update(prefix: "en")
        service = FakeNotificationService()
        toast = ToastStore()
        userID = "u1"
        let localization = TestFixture.localizationStore()
        addTeardownBlock { try? FileManager.default.removeItem(at: localization.directory) }
        store = ChoreReminderStore(
            service: service, toastStore: toast, localizationStore: localization.store,
            currentUserID: { [unowned self] in self.userID }
        )
    }

    func testSuccessMarksTheChoreRemindedAndShowsAnInfoToast() async {
        await store.remind(choreID: "c1")

        XCTAssertTrue(store.isReminded("c1"))
        XCTAssertFalse(store.isSending("c1"))
        XCTAssertEqual(toast.message, "Reminder sent")
        XCTAssertFalse(toast.isError)
    }

    func testAConflictIsTheRemindedStateWithoutAToast() async {
        service.remindHandler = { _ in throw NotificationFailure(kind: .alreadyReminded, message: "Already") }

        await store.remind(choreID: "c1")

        XCTAssertTrue(store.isReminded("c1"))
        XCTAssertNil(toast.message)
    }

    func testRuleViolationsShowTheServerMessage() async {
        for kind in [NotificationFailure.Kind.invalidRequest, .notMember] {
            toast.clear()
            service.remindHandler = { _ in throw NotificationFailure(kind: kind, message: "Too early") }

            await store.remind(choreID: "c1")

            XCTAssertFalse(store.isReminded("c1"), "\(kind)")
            XCTAssertEqual(toast.message, "Too early", "\(kind)")
            XCTAssertTrue(toast.isError, "\(kind)")
        }
    }

    func testMissingServerMessageFallsBackToTheGenericText() async {
        service.remindHandler = { _ in throw NotificationFailure(kind: .invalidRequest, message: nil) }

        await store.remind(choreID: "c1")

        XCTAssertEqual(toast.message, NetworkError.genericMessage)
    }

    func testAMissingChoreShowsTheMessageAndAsksForAHouseRefresh() async {
        service.remindHandler = { _ in throw NotificationFailure(kind: .notFound, message: "Gone") }
        var refreshes = 0
        store.onChoreNotFound = { refreshes += 1 }

        await store.remind(choreID: "c1")

        XCTAssertEqual(toast.message, "Gone")
        XCTAssertEqual(refreshes, 1)
        XCTAssertFalse(store.isReminded("c1"))
    }

    func testARejectedSessionShowsNoToast() async {
        service.remindHandler = { _ in throw NotificationFailure(kind: .unauthorized, message: nil) }

        await store.remind(choreID: "c1")

        XCTAssertNil(toast.message)
        XCTAssertFalse(store.isReminded("c1"))
    }

    func testARemindedChoreIsNotSentAgain() async {
        await store.remind(choreID: "c1")
        await store.remind(choreID: "c1")

        XCTAssertEqual(service.remindCalls, ["c1"])
    }

    func testTheRemindedSetBelongsToTheUserAndIsClearedOnSignOut() async {
        await store.remind(choreID: "c1")
        userID = "u2"
        XCTAssertFalse(store.isReminded("c1"))

        userID = "u1"
        XCTAssertTrue(store.isReminded("c1"))
        store.clear()
        XCTAssertFalse(store.isReminded("c1"))
    }

    func testAnAnswerForAPreviousUserIsIgnored() async {
        service.remindHandler = { [unowned self] _ in self.userID = "u2" }

        await store.remind(choreID: "c1")

        XCTAssertFalse(store.isReminded("c1"))
        XCTAssertNil(toast.message)
        XCTAssertFalse(store.isSending("c1"))
    }
}
