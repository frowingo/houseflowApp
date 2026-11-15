import Foundation
import Combine
import FausCrewCore

@MainActor
final class LocalizationStore: ObservableObject {
    @Published private(set) var languagePrefix: String? {
        didSet { APILanguage.update(prefix: languagePrefix) }
    }
    @Published private(set) var availableLanguages: [LocalizationLanguage] = []
    @Published private(set) var values: [String: String]
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingLanguages = false

    private let service: any LocalizationServicing
    private let cache: any LocalizationCacheStore
    private let deviceLanguages: () -> [String]
    private var refreshTask: Task<Void, Never>?
    private var languageTask: Task<Void, Never>?

    init(
        service: any LocalizationServicing,
        cache: any LocalizationCacheStore,
        deviceLanguages: @escaping () -> [String] = { Locale.preferredLanguages }
    ) {
        self.service = service
        self.cache = cache
        self.deviceLanguages = deviceLanguages

        if let cached = cache.loadMostRecent() {
            self.languagePrefix = cached.languagePrefix
            APILanguage.update(prefix: cached.languagePrefix)
            self.values = cached.values
        } else {
            self.languagePrefix = nil
            self.values = [:]
        }
    }

    deinit {
        refreshTask?.cancel()
        languageTask?.cancel()
    }

    func start() {
        refreshIfNeeded(force: values.isEmpty)
        loadLanguagesAndApplyDefault()
    }

    func value(for key: String) -> String {
        value(for: key, fallback: key)
    }

    func value(for key: String, fallback: String) -> String {
        values[key] ?? bundledValue(for: key) ?? fallback
    }

    /// Server text wins; otherwise the built-in Turkish/English copy for the app language.
    func value(for key: String, tr: String, en: String) -> String {
        value(for: key, fallback: APILanguage.code == "tr" ? tr : en)
    }

    func userMessage(for error: Error) -> String {
        switch error {
        case NetworkError.serverError(let message):
            return message
        case NetworkError.unauthorized:
            return value(
                for: "error_session_expired",
                tr: "Oturumunuz sona ermiş. Lütfen tekrar giriş yapın.",
                en: NetworkError.sessionExpiredMessage
            )
        case is URLError:
            return value(
                for: "error_network_unavailable",
                tr: "Bağlantı kurulamadı. İnternet bağlantınızı kontrol edin.",
                en: "Unable to connect. Please check your internet connection."
            )
        default:
            return value(
                for: "error_generic",
                tr: "Bir şeyler ters gitti. Lütfen tekrar deneyin.",
                en: NetworkError.genericMessage
            )
        }
    }

    func value(for key: String, replacements: [String: String]) -> String {
        var localizedValue = value(for: key)
        for (placeholder, value) in replacements {
            localizedValue = localizedValue.replacingOccurrences(of: "{\(placeholder)}", with: value)
        }
        return localizedValue
    }

    func setLanguagePrefix(_ newPrefix: String, forceRefresh: Bool = false) {
        let normalizedPrefix = normalize(newPrefix)
        guard !normalizedPrefix.isEmpty else { return }

        guard normalizedPrefix != languagePrefix else {
            refreshIfNeeded(force: values.isEmpty)
            return
        }

        languagePrefix = normalizedPrefix
        values = cache.load(languagePrefix: normalizedPrefix)
        refreshIfNeeded(force: forceRefresh || values.isEmpty)
    }

    func applyPreferredLanguage(_ rawLanguage: String?) {
        guard let rawLanguage else { return }
        let normalizedPrefix = normalize(rawLanguage)
        guard !normalizedPrefix.isEmpty else { return }
        setLanguagePrefix(normalizedPrefix)
    }

    func loadLanguagesAndApplyDefault(force: Bool = false) {
        guard force || availableLanguages.isEmpty else {
            applyInitialLanguageIfNeeded()
            return
        }

        languageTask?.cancel()
        languageTask = Task { [weak self] in
            await self?.loadLanguagesAndApplyDefaultAsync()
        }
    }

    func loadAvailableLanguages(force: Bool = false) async throws {
        guard force || availableLanguages.isEmpty else { return }

        isLoadingLanguages = true
        defer { isLoadingLanguages = false }

        let languages = try await service.fetchLanguages()
        availableLanguages = languages
        applyInitialLanguageIfNeeded()
    }

    func refreshLanguagePrefix(_ prefix: String) async throws {
        let normalizedPrefix = normalize(prefix)
        guard !normalizedPrefix.isEmpty else { return }

        refreshTask?.cancel()
        languagePrefix = normalizedPrefix
        values = cache.load(languagePrefix: normalizedPrefix)
        isRefreshing = true
        defer { isRefreshing = false }

        let items = try await service.fetchPlaintexts(languagePrefix: normalizedPrefix)
        let freshValues = valuesDictionary(from: items)
        values = freshValues
        cache.save(values: freshValues, languagePrefix: normalizedPrefix)
    }

    func refreshIfNeeded(force: Bool = false) {
        guard force || values.isEmpty else { return }
        guard let currentLanguagePrefix = languagePrefix, !currentLanguagePrefix.isEmpty else { return }

        refreshTask?.cancel()
        refreshTask = Task { [weak self] in
            await self?.refresh(languagePrefix: currentLanguagePrefix)
        }
    }

    private func loadLanguagesAndApplyDefaultAsync() async {
        isLoadingLanguages = true
        defer { isLoadingLanguages = false }

        do {
            let languages = try await service.fetchLanguages()
            guard !Task.isCancelled else { return }
            availableLanguages = languages
            applyInitialLanguageIfNeeded()
        } catch {
            // If the endpoint fails and there is no cache, lookup falls back to keys.
        }
    }

    private func applyInitialLanguageIfNeeded() {
        guard languagePrefix == nil else { return }

        let activeLanguages = availableLanguages.filter { $0.isActive }
        let selectedPrefix = preferredDeviceLanguagePrefix(in: activeLanguages)
            ?? activeLanguages.first(where: { $0.isDefault })?.prefix
            ?? activeLanguages.first?.prefix

        guard let selectedPrefix else { return }
        setLanguagePrefix(selectedPrefix, forceRefresh: values.isEmpty)
    }

    private func preferredDeviceLanguagePrefix(in activeLanguages: [LocalizationLanguage]) -> String? {
        guard let preferredIdentifier = deviceLanguages().first else { return nil }

        let normalizedIdentifier = normalizeLocaleIdentifier(preferredIdentifier)
        if let exactMatch = activeLanguages.first(where: {
            normalizeLocaleIdentifier($0.prefix) == normalizedIdentifier
        }) {
            return exactMatch.prefix
        }

        guard let preferredLanguageCode = baseLanguageCode(from: normalizedIdentifier) else { return nil }
        return activeLanguages.first(where: {
            baseLanguageCode(from: normalizeLocaleIdentifier($0.prefix)) == preferredLanguageCode
        })?.prefix
    }

    private func refresh(languagePrefix: String) async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let items = try await service.fetchPlaintexts(languagePrefix: languagePrefix)
            guard !Task.isCancelled, self.languagePrefix == languagePrefix else { return }

            let freshValues = valuesDictionary(from: items)
            values = freshValues
            cache.save(values: freshValues, languagePrefix: languagePrefix)
        } catch {
            // Lookup already falls back to the key, so a failed refresh should not block UI.
        }
    }

    /// The game dictionaries answer Turkish for every language but English, so they follow
    /// `APILanguage` (English unless the app language is Turkish) like the `tr`/`en` copy.
    private func bundledValue(for key: String) -> String? {
        let language = APILanguage.code
        return RPSLocalization.value(for: key, language: language)
            ?? FausSwitchLocalization.value(for: key, language: language)
            ?? HouseTanksLocalization.value(for: key, language: language)
            ?? HouseRocketsLocalization.value(for: key, language: language)
            ?? LuckySpinLocalization.value(for: key, language: language)
    }

    private func valuesDictionary(from items: [LocalizationPlaintextItem]) -> [String: String] {
        var dictionary: [String: String] = [:]
        for item in items {
            dictionary[item.key] = item.value
        }
        return dictionary
    }

    private func normalize(_ prefix: String) -> String {
        prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizeLocaleIdentifier(_ identifier: String) -> String {
        normalize(identifier).replacingOccurrences(of: "_", with: "-")
    }

    private func baseLanguageCode(from identifier: String) -> String? {
        identifier.split(separator: "-", omittingEmptySubsequences: true).first.map(String.init)
    }
}
