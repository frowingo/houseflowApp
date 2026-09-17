import Foundation

struct HouseInfoData: Decodable, Equatable {
    let houseMemberCount: Int
    let houseMemberCountLimit: Int
    let houseMembers: [HouseInfoMember]
    let houseName: String
    let houseProfileImage: String
    let houseType: Int

    func isOwner(userId: String?) -> Bool {
        guard let userId else { return false }
        return houseMembers.first(where: { $0.userId == userId })?.isOwner == true
    }

    func removingMember(userId: String) -> HouseInfoData {
        let remainingMembers = houseMembers.filter { $0.userId != userId }
        return HouseInfoData(
            houseMemberCount: remainingMembers.count,
            houseMemberCountLimit: houseMemberCountLimit,
            houseMembers: remainingMembers,
            houseName: houseName,
            houseProfileImage: houseProfileImage,
            houseType: houseType
        )
    }
}

struct HouseInfoMember: Decodable, Equatable, Identifiable {
    let isOwner: Bool
    let name: String
    let profileImage: String
    let userId: String

    var id: String { userId }
}

struct UpdateHouseProfileRequest: Encodable, Equatable {
    let houseMemberCountLimit: Int
    let houseName: String
    let houseProfileImage: String
    let houseType: Int
}

struct ExitHouseRequest: Encodable, Equatable {
    let houseId: String
    let userId: String
}

struct CreateHouseInviteCodeRequest: Encodable, Equatable {
    let houseId: String
}

struct HouseInviteCodeData: Decodable, Equatable {
    let expiresInSeconds: Int
    let inviteCode: String
}

struct HouseActionResponse: Decodable, Equatable {
    let success: Bool
    let error: String?
}
