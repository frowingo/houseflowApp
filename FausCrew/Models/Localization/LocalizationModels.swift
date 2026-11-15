import Foundation

nonisolated struct LocalizationLanguage: Codable, Identifiable, Equatable {
    let image: String
    let isActive: Bool
    let isDefault: Bool
    let name: String
    let nativeName: String
    let prefix: String

    var id: String { prefix }
}

nonisolated struct LocalizationLanguageResponse: Decodable {
    let data: [LocalizationLanguage]
    let success: Bool
}

nonisolated struct LocalizationPlaintextItem: Codable, Equatable {
    let key: String
    let language: String
    let value: String
}

nonisolated struct LocalizationPlaintextResponse: Decodable {
    let success: Bool
    let data: [LocalizationPlaintextItem]
}
