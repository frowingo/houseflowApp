import Foundation

enum AppLanguage: String, CaseIterable, Codable, Identifiable {
    case english = "en"
    case turkish = "tr"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .english: return "English"
        case .turkish: return "Türkçe"
        }
    }

    static let fallback: AppLanguage = .english

    init(normalizing rawValue: String?) {
        switch rawValue?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case AppLanguage.turkish.rawValue:
            self = .turkish
        default:
            self = .english
        }
    }
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
