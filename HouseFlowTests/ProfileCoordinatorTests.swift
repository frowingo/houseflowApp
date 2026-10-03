import XCTest
@testable import HouseFlow

@MainActor
final class ProfileCoordinatorTests: XCTestCase {
    func testFetchingHouseProfileImagesUsesHouseCategory() async throws {
        let userService = FakeUserService()
        userService.getImagesHandler = { category in
            XCTAssertEqual(category, "house")
            return GetImagesResponse(data: [], success: true)
        }
        let authStore = AuthSessionStore(
            keychain: FakeKeychainStore(),
            authService: FakeAuthService(),
            userService: userService
        )
        let localization = TestFixture.localizationStore()
        defer { try? FileManager.default.removeItem(at: localization.directory) }
        let coordinator = ProfileCoordinator(
            authStore: authStore,
            houseStore: HouseSessionStore(houseService: FakeHouseService()),
            localizationStore: localization.store,
            toastStore: ToastStore()
        )

        let response = try await coordinator.fetchHouseProfileImages()

        XCTAssertTrue(response.success)
    }

    func testSavingLanguageUpdatesProfileRefreshesLocalizationAndRequiresLogin() async throws {
        let keychain = FakeKeychainStore()
        let userService = FakeUserService()
        userService.updateProfileHandler = { _, request in
            XCTAssertEqual(request.language, "tr")
            return UpdateProfileResponse(
                data: TestFixture.userResult(language: "tr"),
                success: true,
                error: nil
            )
        }
        let authStore = AuthSessionStore(
            keychain: keychain,
            authService: FakeAuthService(),
            userService: userService
        )
        authStore.applyAuthenticatedUser(TestFixture.profile(language: "en"))

        let localizationService = FakeLocalizationService()
        localizationService.fetchPlaintextsHandler = { prefix in
            XCTAssertEqual(prefix, "tr")
            return [
                LocalizationPlaintextItem(
                    key: "language_settings_relogin_message",
                    language: "tr",
                    value: "Please log in again"
                )
            ]
        }
        let localization = TestFixture.localizationStore(service: localizationService)
        defer { try? FileManager.default.removeItem(at: localization.directory) }
        let toastStore = ToastStore()
        let houseStore = HouseSessionStore(houseService: FakeHouseService())
        let coordinator = ProfileCoordinator(
            authStore: authStore,
            houseStore: houseStore,
            localizationStore: localization.store,
            toastStore: toastStore
        )
        var didRequireLogin = false

        try await coordinator.saveLanguagePreferenceAndRequireLogin(prefix: "tr") {
            didRequireLogin = true
        }

        XCTAssertEqual(userService.lastUpdatedUserId, "user-1")
        XCTAssertEqual(userService.lastUpdateRequest?.language, "tr")
        XCTAssertEqual(authStore.currentUserProfile?.language, "tr")
        XCTAssertEqual(localization.store.languagePrefix, "tr")
        XCTAssertTrue(didRequireLogin)
        XCTAssertEqual(toastStore.message, "Please log in again")
        XCTAssertFalse(toastStore.isError)
    }

    func testUpdatingHouseProfileRefreshesHouseSummaryAndSelectedHouse() async throws {
        let authStore = AuthSessionStore(
            keychain: FakeKeychainStore(),
            authService: FakeAuthService(),
            userService: FakeUserService()
        )
        authStore.applyAuthenticatedUser(TestFixture.profile(houseIds: ["house-1"]))

        let houseService = FakeHouseService()
        houseService.updateProfileHandler = { houseId, request in
            XCTAssertEqual(houseId, "house-1")
            XCTAssertEqual(request.houseName, "Updated House")
            XCTAssertEqual(request.houseMemberCountLimit, 6)
            return TestFixture.houseInfo(
                name: request.houseName,
                memberCountLimit: request.houseMemberCountLimit,
                profileImage: request.houseProfileImage
            )
        }
        let houseStore = HouseSessionStore(houseService: houseService)
        houseStore.applyHouseDetails(TestFixture.houseDetails())
        let localization = TestFixture.localizationStore()
        defer { try? FileManager.default.removeItem(at: localization.directory) }
        let coordinator = ProfileCoordinator(
            authStore: authStore,
            houseStore: houseStore,
            localizationStore: localization.store,
            toastStore: ToastStore()
        )

        _ = try await coordinator.updateHouseProfile(
            houseId: "house-1",
            name: "Updated House",
            memberCountLimit: 6,
            profileImage: "https://example.com/new-house.png",
            houseType: 1
        )

        XCTAssertEqual(authStore.currentUserProfile?.houseList.first?.houseName, "Updated House")
        XCTAssertEqual(
            authStore.currentUserProfile?.houseList.first?.houseProfile,
            "https://example.com/new-house.png"
        )
        XCTAssertEqual(houseStore.currentHouseDetails?.name, "Updated House")
        XCTAssertEqual(houseStore.currentHouseDetails?.maxMemberCount, 6)
        XCTAssertEqual(houseStore.houseName, "Updated House")
    }

    func testRemovingMemberRefreshesSelectedHouseDetails() async throws {
        let houseService = FakeHouseService()
        houseService.removeMemberHandler = { houseId, userId in
            XCTAssertEqual(houseId, "house-1")
            XCTAssertEqual(userId, "user-2")
        }
        houseService.fetchDetailsHandler = { houseId in
            XCTAssertEqual(houseId, "house-1")
            return TestFixture.houseDetails(members: [TestFixture.member()])
        }
        let houseStore = HouseSessionStore(houseService: houseService)
        houseStore.applyHouseDetails(
            TestFixture.houseDetails(
                members: [TestFixture.member(), TestFixture.member(id: "user-2")]
            )
        )

        try await houseStore.removeHouseMember(houseId: "house-1", userId: "user-2")

        XCTAssertEqual(houseStore.currentHouseDetails?.members.map(\.id), ["user-1"])
    }

    func testJoiningHouseFromProfilePatchesAuthenticatedHouseList() async throws {
        let authStore = AuthSessionStore(
            keychain: FakeKeychainStore(),
            authService: FakeAuthService(),
            userService: FakeUserService()
        )
        authStore.applyAuthenticatedUser(TestFixture.profile(houseIds: ["house-1"]))
        let houseService = FakeHouseService()
        houseService.joinHouseHandler = { inviteCode in
            XCTAssertEqual(inviteCode, "AB12CD34")
            return TestFixture.houseResponse(id: "house-2", name: "New House")
        }
        let localization = TestFixture.localizationStore()
        defer { try? FileManager.default.removeItem(at: localization.directory) }
        let coordinator = ProfileCoordinator(
            authStore: authStore,
            houseStore: HouseSessionStore(houseService: houseService),
            localizationStore: localization.store,
            toastStore: ToastStore()
        )

        _ = try await coordinator.joinHouse(inviteCode: "ab-12 cd34")

        XCTAssertEqual(authStore.currentUserProfile?.houseList.map(\.houseId), ["house-1", "house-2"])
        XCTAssertEqual(authStore.currentUserProfile?.houseList.last?.houseName, "New House")
    }
}
