import Foundation

struct LocalizationLanguage: Codable, Identifiable, Equatable {
    let image: String
    let isActive: Bool
    let isDefault: Bool
    let name: String
    let nativeName: String
    let prefix: String

    var id: String { prefix }
}

struct LocalizationLanguageResponse: Decodable {
    let data: [LocalizationLanguage]
    let success: Bool
}

struct LocalizationPlaintextItem: Codable, Equatable {
    let key: String
    let language: String
    let value: String
}

struct LocalizationPlaintextResponse: Decodable {
    let success: Bool
    let data: [LocalizationPlaintextItem]
}
