import Foundation

/// Shared house endpoint bodies and response validation. Transport, token storage,
/// selected-house persistence and UI state remain platform-owned.
public enum HouseWireContract {
    public static func createBody(name: String, type: Int, maxMemberCount: Int) throws -> Data {
        try JSONEncoder().encode(CreateHouseRequest(name: name, maxMemberCount: maxMemberCount, type: type))
    }

    public static func joinBody(inviteCode: String) throws -> Data {
        try JSONEncoder().encode(JoinHouseRequest(inviteCode: InviteCodeRules.normalized(inviteCode)))
    }

    public static func inviteBody(houseId: String) throws -> Data {
        try JSONEncoder().encode(CreateHouseInviteCodeRequest(houseId: houseId))
    }

    public static func exitBody(houseId: String, userId: String) throws -> Data {
        try JSONEncoder().encode(ExitHouseRequest(houseId: houseId, userId: userId))
    }

    public static func profileBody(
        name: String, type: Int, maxMemberCount: Int, profileImage: String
    ) throws -> Data {
        try JSONEncoder().encode(UpdateHouseProfileRequest(
            houseMemberCountLimit: maxMemberCount,
            houseName: name,
            houseProfileImage: profileImage,
            houseType: type
        ))
    }

    public static func validate(action: String, response: HTTPResponse, decoder: JSONDecoder = JSONDecoder()) throws {
        guard (200...399).contains(response.statusCode) else {
            throw HTTPStatusFailure(response: response, decoder: decoder)
        }
        switch action {
        case "create", "join":
            _ = try unwrap(HouseAPIResponse<HouseResponse>.self, response.body, decoder)
        case "details":
            _ = try unwrap(HouseAPIResponse<HouseDetailsResponse>.self, response.body, decoder)
        case "info", "profile":
            _ = try unwrap(HouseAPIResponse<HouseInfoData>.self, response.body, decoder)
        case "invite":
            _ = try unwrap(HouseAPIResponse<HouseInviteCodeData>.self, response.body, decoder)
        case "exit":
            let reply = try decoder.decode(HouseActionResponse.self, from: response.body)
            guard reply.success else { throw HouseWireError.rejected(reply.error) }
        default:
            throw HouseWireError.unsupportedAction
        }
    }

    public static func preferredHouse(in houses: [AuthHouseSummary], chosenId: String?) -> AuthHouseSummary? {
        if let chosenId, let chosen = houses.first(where: { $0.houseId == chosenId }) { return chosen }
        return houses.first
    }

    private static func unwrap<T: Decodable>(
        _ type: HouseAPIResponse<T>.Type, _ body: Data, _ decoder: JSONDecoder
    ) throws -> T {
        let reply = try decoder.decode(type, from: body)
        guard reply.success, let data = reply.data else { throw HouseWireError.rejected(reply.error) }
        return data
    }
}

public enum HouseWireError: Error, Equatable {
    case rejected(String?)
    case unsupportedAction
}
