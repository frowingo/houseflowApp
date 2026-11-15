import Combine
import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class AppViewModelObservationTests: XCTestCase {
    func testOverlayStorePublishesOnlyWhenPresentationChanges() {
        let store = OverlayStore()
        var changeCount = 0
        let subscription = store.objectWillChange.sink { changeCount += 1 }
        defer { subscription.cancel() }

        store.setPresented(false)
        XCTAssertEqual(changeCount, 0)

        store.setPresented(true)
        store.setPresented(true)
        XCTAssertTrue(store.isPresented)
        XCTAssertEqual(changeCount, 1)

        store.setPresented(false)
        store.setPresented(false)
        XCTAssertFalse(store.isPresented)
        XCTAssertEqual(changeCount, 2)
    }

    func testToastChangesDoNotPublishAppViewModelChanges() {
        let model = makeModel()
        var modelChangeCount = 0
        var toastChangeCount = 0
        let modelSubscription = model.objectWillChange.sink { modelChangeCount += 1 }
        let toastSubscription = model.toastStore.objectWillChange.sink { toastChangeCount += 1 }
        defer {
            model.toastStore.clear()
            modelSubscription.cancel()
            toastSubscription.cancel()
        }

        model.showToast(message: "Saved", isError: false)

        XCTAssertEqual(model.toastMessage, "Saved")
        XCTAssertFalse(model.toastIsError)
        XCTAssertGreaterThan(toastChangeCount, 0)
        XCTAssertEqual(modelChangeCount, 0)

        let changesBeforeClear = toastChangeCount
        model.toastStore.clear()

        XCTAssertNil(model.toastMessage)
        XCTAssertGreaterThan(toastChangeCount, changesBeforeClear)
        XCTAssertEqual(modelChangeCount, 0)
    }

    func testOverlaySetterUsesStoreWithoutPublishingAppViewModelChanges() {
        let model = makeModel()
        var modelChangeCount = 0
        var overlayChangeCount = 0
        let modelSubscription = model.objectWillChange.sink { modelChangeCount += 1 }
        let overlaySubscription = model.overlayStore.objectWillChange.sink { overlayChangeCount += 1 }
        defer {
            modelSubscription.cancel()
            overlaySubscription.cancel()
        }

        model.isOverlayPresented = true
        model.isOverlayPresented = true

        XCTAssertTrue(model.overlayStore.isPresented)
        XCTAssertTrue(model.isOverlayPresented)
        XCTAssertEqual(overlayChangeCount, 1)
        XCTAssertEqual(modelChangeCount, 0)

        model.isOverlayPresented = false
        model.isOverlayPresented = false

        XCTAssertFalse(model.isOverlayPresented)
        XCTAssertEqual(overlayChangeCount, 2)
        XCTAssertEqual(modelChangeCount, 0)
    }

    func testHouseChangesStillPublishAppViewModelChanges() {
        let model = makeModel()
        var changeCount = 0
        let subscription = model.objectWillChange.sink { changeCount += 1 }
        defer { subscription.cancel() }

        model.currentHouse = TestFixture.houseResponse()

        XCTAssertGreaterThan(changeCount, 0)
    }

    private func makeModel() -> AppViewModel {
        let suiteName = "AppViewModelObservationTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(suiteName, isDirectory: true)
        addTeardownBlock {
            defaults.removePersistentDomain(forName: suiteName)
            try? FileManager.default.removeItem(at: directory)
        }

        return AppViewModel(dependencies: AppDependencies(
            keychain: FakeKeychainStore(),
            authService: FakeAuthService(),
            sessionRestorer: nil,
            userService: FakeUserService(),
            houseService: FakeHouseService(),
            choreService: FakeChoreService(),
            localizationService: FakeLocalizationService(),
            userDefaults: defaults,
            localizationCache: LocalizationDiskCache(baseDirectory: directory),
            houseRocketsSessionFactory: .localOnly
        ))
    }
}
