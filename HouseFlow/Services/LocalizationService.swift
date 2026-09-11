import Foundation

final class LocalizationService {
    private let network: any NetworkServicing

    init(network: any NetworkServicing) {
        self.network = network
    }

    func fetchLanguages() async throws -> [LocalizationLanguage] {
        let response = try await network.get(
            path: "localization/languages",
            queryItems: [],
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
            queryItems: [],
            successType: LocalizationPlaintextResponse.self
        )

        guard response.success else {
            throw NetworkError.serverError("localization_fetch_failed")
        }

        return response.data
    }
}
