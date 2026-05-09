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
}
