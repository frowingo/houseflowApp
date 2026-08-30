import Foundation

final class HouseService {
    private let network: any NetworkServicing
    private let keychain: any KeychainStoring

    init(network: any NetworkServicing, keychain: any KeychainStoring) {
        self.network = network
        self.keychain = keychain
    }

    // MARK: - Create House

    /// POST house/create  — requires Bearer token
    func createHouse(name: String, type: Int, maxMemberCount: Int) async throws -> HouseResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        let body = CreateHouseRequest(name: name, maxMemberCount: maxMemberCount, type: type)
        let response = try await network.authenticatedRequest(
            path: "house/create",
            method: "POST",
            body: body,
            successType: HouseAPIResponse<HouseResponse>.self,
            token: token
        )
        return try unwrap(response, fallbackError: "House could not be created.")
    }

    // MARK: - House Details

    /// GET house/details?HouseId=<id>  — requires Bearer token
    func fetchDetails(houseId: String) async throws -> HouseDetailsResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        let response = try await network.get(
            path: "house/details",
            queryItems: [URLQueryItem(name: "houseId", value: houseId)],
            successType: HouseAPIResponse<HouseDetailsResponse>.self,
            token: token
        )
        return try unwrap(response, fallbackError: "House details could not be loaded.")
    }

    // MARK: - Join House

    /// POST house/join  — requires Bearer token
    func joinHouse(inviteCode: String) async throws -> HouseResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        let body = JoinHouseRequest(inviteCode: inviteCode)
        let response = try await network.authenticatedRequest(
            path: "house/join",
            method: "POST",
            body: body,
            successType: HouseAPIResponse<HouseResponse>.self,
            token: token
        )
        return try unwrap(response, fallbackError: "House could not be joined.")
    }

    // MARK: - Create Announcement

    /// POST house/announcement — requires Bearer token
    func createAnnouncement(
        title: String,
        description: String,
        houseId: String
    ) async throws -> HouseAnnouncementDTO {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }

        let body = CreateAnnouncementRequest(
            description: description,
            houseId: houseId,
            title: title
        )
        let response = try await network.authenticatedRequest(
            path: "house/announcement",
            method: "POST",
            body: body,
            successType: HouseAPIResponse<HouseAnnouncementDTO>.self,
            token: token
        )
        return try unwrap(response, fallbackError: "Announcement could not be published.")
    }

    private func unwrap<Data: Decodable>(
        _ response: HouseAPIResponse<Data>,
        fallbackError: String
    ) throws -> Data {
        guard response.success, let data = response.data else {
            throw NetworkError.serverError(response.error ?? fallbackError)
        }
        return data
    }
}
