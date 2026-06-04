import Foundation

final class UserService {
    static let shared = UserService()

    private let network = NetworkService.shared
    private let keychain = KeychainService.shared

    private init() {}

    // MARK: - Get User By Email

    /// GET user/getByEmail?email=<email>  — requires Bearer token
    func getByEmail(_ email: String) async throws -> UserProfileResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        return try await network.get(
            path: "user/getByEmail",
            queryItems: [URLQueryItem(name: "email", value: email)],
            successType: UserProfileResponse.self,
            token: token
        )
    }

    // MARK: - Update User Profile

    /// PUT user/profile/{id}?userId=<userId>  — requires Bearer token
    func updateProfile(userId: String, request: UpdateProfileRequest) async throws -> UpdateProfileResponse {
        guard let token = keychain.authToken else {
            throw NetworkError.serverError("Not authenticated.")
        }
        return try await network.authenticatedRequest(
            path: "user/profile/\(userId)",
            method: "PUT",
            queryItems: [URLQueryItem(name: "userId", value: userId)],
            body: request,
            successType: UpdateProfileResponse.self,
            token: token
        )
    }
}
