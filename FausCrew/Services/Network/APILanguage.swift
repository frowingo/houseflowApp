import Foundation

/// The `tr` / `en` code sent as `Accept-Language` and as a new account's `language`.
/// `LocalizationStore` keeps it in step with the language the user picked.
@MainActor
enum APILanguage {
    private(set) static var code: String = resolve(Locale.preferredLanguages.first)

    static func update(prefix: String?) {
        code = resolve(prefix)
    }

    private static func resolve(_ prefix: String?) -> String {
        prefix?.lowercased().hasPrefix("tr") == true ? "tr" : "en"
    }
}
