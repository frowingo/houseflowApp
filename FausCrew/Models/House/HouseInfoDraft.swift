import Foundation
import FausCrewCore

/// The house owner's editable copy of the house details, with the rules for saving it. It keeps
/// the last committed `info` it was built from, so the popup can tell what changed.
nonisolated struct HouseInfoDraft: Equatable {
    private(set) var info: HouseInfoData
    var name: String
    var memberCountLimit: Int
    var profileImageURL: String
    var isChoreReviewPhotoRequired: Bool
    private let summaryImageURL: String

    init(info: HouseInfoData, summaryImageURL: String) {
        self.info = info
        self.summaryImageURL = summaryImageURL
        name = info.houseName
        memberCountLimit = max(info.houseMemberCountLimit, HouseCreationRules.memberCountRange.lowerBound, info.houseMemberCount)
        profileImageURL = info.houseProfileImage
        isChoreReviewPhotoRequired = info.isChoreReviewPhotoRequired
    }

    var normalizedName: String {
        HouseCreationRules.normalizedName(name)
    }

    var minimumMemberLimit: Int {
        max(HouseCreationRules.memberCountRange.lowerBound, info.houseMemberCount)
    }

    var maximumMemberLimit: Int {
        max(HouseCreationRules.memberCountRange.upperBound, minimumMemberLimit)
    }

    var hasChanges: Bool {
        normalizedName != info.houseName
            || memberCountLimit != info.houseMemberCountLimit
            || profileImageURL != info.houseProfileImage
            || isChoreReviewPhotoRequired != info.isChoreReviewPhotoRequired
    }

    func isReadyToSave(currentUserId: String?) -> Bool {
        info.isOwner(userId: currentUserId) && !normalizedName.isEmpty && hasChanges
    }

    func canRemove(_ member: HouseInfoMember, currentUserId: String?) -> Bool {
        info.isOwner(userId: currentUserId) && !member.isOwner && member.userId != currentUserId
    }

    func canLeave(currentUserId: String?) -> Bool {
        guard !info.isOwner(userId: currentUserId), let currentUserId else { return false }
        return info.houseMembers.contains { $0.userId == currentUserId }
    }

    /// The images the owner can pick from: the current one, the one on the house summary, then
    /// the catalogue, without blanks or repeats.
    func imageChoices(available: [String]) -> [String] {
        var seen = Set<String>()
        return ([info.houseProfileImage, summaryImageURL] + available).compactMap { candidate in
            let value = candidate.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !value.isEmpty, seen.insert(value).inserted else { return nil }
            return value
        }
    }

    /// Takes the server's newer house info while keeping the owner's edits; the member limit can
    /// never drop below the people already in the house.
    mutating func replaceInfo(_ newInfo: HouseInfoData) {
        info = newInfo
        memberCountLimit = max(memberCountLimit, minimumMemberLimit)
    }
}
