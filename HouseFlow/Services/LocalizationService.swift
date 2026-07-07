import Foundation

final class LocalizationService {
    static let shared = LocalizationService()

    private let network = NetworkService.shared

    private init() {}

    func fetchPlaintexts(language: AppLanguage) async throws -> [LocalizationPlaintextItem] {
        let response = try await network.get(
            path: "localization/plaintexts/\(language.rawValue)",
            successType: LocalizationPlaintextResponse.self
        )

        guard response.success else {
            throw NetworkError.serverError("localization_fetch_failed")
        }

        return response.data
    }
}
