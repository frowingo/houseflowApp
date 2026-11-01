import Foundation

extension AppViewModel {
    /// Server-supplied text wins; otherwise the built-in Turkish/English copy for the app language.
    func social(_ key: String, tr: String, en: String) -> String {
        localized(key, fallback: APILanguage.code == "tr" ? tr : en)
    }
}
