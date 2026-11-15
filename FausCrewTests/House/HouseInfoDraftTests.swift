import XCTest
import FausCrewCore
@testable import FausCrew

final class HouseInfoDraftTests: XCTestCase {
    func testNewDraftHasNoChanges() {
        XCTAssertFalse(makeDraft().hasChanges)
    }

    func testChangedFieldsCountAsChanges() {
        var draft = makeDraft()
        draft.name = "New name"
        XCTAssertTrue(draft.hasChanges)

        draft = makeDraft()
        draft.memberCountLimit += 1
        XCTAssertTrue(draft.hasChanges)

        draft = makeDraft()
        draft.profileImageURL = "https://img/other.png"
        XCTAssertTrue(draft.hasChanges)

        draft = makeDraft()
        draft.isChoreReviewPhotoRequired = true
        XCTAssertTrue(draft.hasChanges)
    }

    func testSurroundingWhitespaceIsNotAChange() {
        var draft = makeDraft()
        draft.name = "  Home \n"
        XCTAssertEqual(draft.normalizedName, "Home")
        XCTAssertFalse(draft.hasChanges)
    }

    func testOnlyAnOwnerWithANonEmptyChangedNameIsReadyToSave() {
        var draft = makeDraft()
        draft.name = "New name"
        XCTAssertTrue(draft.isReadyToSave(currentUserId: "owner"))
        XCTAssertFalse(draft.isReadyToSave(currentUserId: "member"))
        XCTAssertFalse(draft.isReadyToSave(currentUserId: nil))

        draft.name = "   "
        XCTAssertFalse(draft.isReadyToSave(currentUserId: "owner"))
    }

    func testUnchangedDraftIsNotReadyToSave() {
        XCTAssertFalse(makeDraft().isReadyToSave(currentUserId: "owner"))
    }

    func testMemberLimitBounds() {
        let small = makeDraft(memberCount: 1, limit: 2)
        XCTAssertEqual(small.minimumMemberLimit, 2)
        XCTAssertEqual(small.maximumMemberLimit, 8)

        let full = makeDraft(memberCount: 3, limit: 4)
        XCTAssertEqual(full.minimumMemberLimit, 3)
    }

    func testMaximumLimitGrowsWithAHouseLargerThanTheDefault() {
        let draft = makeDraft(memberCount: 10, limit: 10)
        XCTAssertEqual(draft.minimumMemberLimit, 10)
        XCTAssertEqual(draft.maximumMemberLimit, 10)
    }

    func testImageChoicesSkipBlankCurrentAndSummaryImages() {
        let info = HouseInfoData(
            houseMemberCount: 2,
            houseMemberCountLimit: 4,
            houseMembers: [owner, member],
            houseName: "Home",
            houseProfileImage: " ",
            houseType: 1
        )
        let draft = HouseInfoDraft(info: info, summaryImageURL: "")

        XCTAssertEqual(draft.imageChoices(available: ["https://img/a.png"]), ["https://img/a.png"])
    }

    func testDraftRaisesALimitBelowTheCurrentMembers() {
        let draft = makeDraft(memberCount: 3, limit: 2)
        XCTAssertEqual(draft.memberCountLimit, 3)
    }

    func testReplacingInfoKeepsEditsAndRaisesTheLimit() {
        var draft = makeDraft(memberCount: 2, limit: 2)
        draft.name = "Edited"
        draft.replaceInfo(makeInfo(memberCount: 4, limit: 4))

        XCTAssertEqual(draft.name, "Edited")
        XCTAssertEqual(draft.memberCountLimit, 4)
        XCTAssertEqual(draft.info.houseMemberCount, 4)
    }

    func testOwnerCanRemoveOnlyOtherMembers() {
        let draft = makeDraft()
        XCTAssertFalse(draft.canRemove(owner, currentUserId: "owner"))
        XCTAssertTrue(draft.canRemove(member, currentUserId: "owner"))
        XCTAssertFalse(draft.canRemove(member, currentUserId: "member"))
        XCTAssertFalse(draft.canRemove(member, currentUserId: nil))
    }

    func testOnlyANonOwnerMemberCanLeave() {
        let draft = makeDraft()
        XCTAssertTrue(draft.canLeave(currentUserId: "member"))
        XCTAssertFalse(draft.canLeave(currentUserId: "owner"))
        XCTAssertFalse(draft.canLeave(currentUserId: "stranger"))
        XCTAssertFalse(draft.canLeave(currentUserId: nil))
    }

    func testImageChoicesAreTrimmedUniqueAndOrdered() {
        let draft = makeDraft(summaryImageURL: "https://img/summary.png")
        let choices = draft.imageChoices(available: [
            " https://img/a.png ",
            "https://img/summary.png",
            "",
            "https://img/current.png",
            "https://img/b.png"
        ])

        XCTAssertEqual(choices, [
            "https://img/current.png",
            "https://img/summary.png",
            "https://img/a.png",
            "https://img/b.png"
        ])
    }

    // MARK: - Fixtures

    private let owner = HouseInfoMember(isOwner: true, name: "Owner", profileImage: "", userId: "owner")
    private let member = HouseInfoMember(isOwner: false, name: "Member", profileImage: "", userId: "member")

    private func makeInfo(memberCount: Int = 2, limit: Int = 4) -> HouseInfoData {
        HouseInfoData(
            houseMemberCount: memberCount,
            houseMemberCountLimit: limit,
            houseMembers: [owner, member],
            houseName: "Home",
            houseProfileImage: "https://img/current.png",
            houseType: 1
        )
    }

    private func makeDraft(
        memberCount: Int = 2,
        limit: Int = 4,
        summaryImageURL: String = "https://img/current.png"
    ) -> HouseInfoDraft {
        HouseInfoDraft(info: makeInfo(memberCount: memberCount, limit: limit), summaryImageURL: summaryImageURL)
    }
}
