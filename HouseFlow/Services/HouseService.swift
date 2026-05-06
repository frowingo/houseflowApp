import Foundation

final class HouseService {
    static let shared = HouseService()

    private let network = NetworkService.shared
    private let keychain = KeychainService.shared

    private init() {}

    // MARK: - Create House

    /// POST house/create  — requires Bearer token
    func createHouse(name: String, type: Int, maxMemberCount: Int) async throws -> HouseResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        let body = CreateHouseRequest(name: name, maxMemberCount: maxMemberCount, type: type)
        return try await network.authenticatedRequest(
            path: "house/create",
            body: body,
            successType: HouseResponse.self,
            token: token
        )
    }

    // MARK: - House Details

    /// GET house/details?HouseId=<id>  — requires Bearer token
    func fetchDetails(houseId: String) async throws -> HouseDetailsResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        return try await network.get(
            path: "house/details",
            queryItems: [URLQueryItem(name: "houseId", value: houseId)],
            successType: HouseDetailsResponse.self,
            token: token
        )
    }

    // MARK: - Join House

    /// POST house/join  — requires Bearer token
    func joinHouse(inviteCode: String) async throws -> HouseResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        let body = JoinHouseRequest(inviteCode: inviteCode)
        return try await network.authenticatedRequest(
            path: "house/join",
            body: body,
            successType: HouseResponse.self,
            token: token
        )
    }
}
