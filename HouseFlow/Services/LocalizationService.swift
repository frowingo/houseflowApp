import Foundation

final class LocalizationService {
    static let shared = LocalizationService()

    private let network = NetworkService.shared

    private init() {}

    func fetchLanguages() async throws -> [LocalizationLanguage] {
        let response = try await network.get(
            path: "localization/languages",
            successType: LocalizationLanguageResponse.self
        )

        guard response.success else {
            throw NetworkError.serverError("localization_languages_fetch_failed")
        }

        return response.data
    }

    func fetchPlaintexts(languagePrefix: String) async throws -> [LocalizationPlaintextItem] {
        let response = try await network.get(
            path: "localization/plaintext/\(languagePrefix)",
            successType: LocalizationPlaintextResponse.self
        )

        guard response.success else {
            throw NetworkError.serverError("localization_fetch_failed")
        }

        return response.data
    }
}
