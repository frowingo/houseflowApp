import Foundation
import Combine

@MainActor
final class LocalizationStore: ObservableObject {
    @Published private(set) var languagePrefix: String?
    @Published private(set) var availableLanguages: [LocalizationLanguage] = []
    @Published private(set) var values: [String: String]
    @Published private(set) var isRefreshing = false
    @Published private(set) var isLoadingLanguages = false

    private let service: any LocalizationServicing
    private let cache: LocalizationDiskCache
    private var refreshTask: Task<Void, Never>?
    private var languageTask: Task<Void, Never>?

    init(
        service: any LocalizationServicing,
        cache: LocalizationDiskCache
    ) {
        self.service = service
        self.cache = cache

        if let cached = cache.loadMostRecent() {
            self.languagePrefix = cached.languagePrefix
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
        values[key] ?? RPSLocalization.value(for: key, language: languagePrefix) ?? key
    }

    func value(for key: String, fallback: String) -> String {
        values[key] ?? RPSLocalization.value(for: key, language: languagePrefix) ?? fallback
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
        guard let preferredIdentifier = Locale.preferredLanguages.first else { return nil }

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

struct LocalizationDiskCache {
    private let fileManager: FileManager
    private let baseDirectory: URL?
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default, baseDirectory: URL? = nil) {
        self.fileManager = fileManager
        self.baseDirectory = baseDirectory
    }

    func load(languagePrefix: String) -> [String: String] {
        guard
            let data = try? Data(contentsOf: fileURL(for: languagePrefix)),
            let payload = try? decoder.decode(LocalizationCachePayload.self, from: data)
        else {
            return [:]
        }

        return payload.values
    }

    func loadMostRecent() -> (languagePrefix: String, values: [String: String])? {
        guard
            let files = try? fileManager.contentsOfDirectory(
                at: cacheDirectory(),
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            )
        else {
            return nil
        }

        let sortedFiles = files
            .filter { $0.lastPathComponent.hasPrefix("plaintext_") && $0.pathExtension == "json" }
            .sorted { lhs, rhs in
                let lhsDate = (try? lhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let rhsDate = (try? rhs.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return lhsDate > rhsDate
            }

        for file in sortedFiles {
            guard
                let data = try? Data(contentsOf: file),
                let payload = try? decoder.decode(LocalizationCachePayload.self, from: data),
                !payload.language.isEmpty,
                !payload.values.isEmpty
            else {
                continue
            }
            return (payload.language, payload.values)
        }

        return nil
    }

    func save(values: [String: String], languagePrefix: String) {
        do {
            let directory = cacheDirectory()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let payload = LocalizationCachePayload(
                language: languagePrefix,
                updatedAt: Date(),
                values: values
            )
            let data = try encoder.encode(payload)
            try data.write(to: fileURL(for: languagePrefix), options: .atomic)
        } catch {
            // Persisting the cache is best-effort; in-memory values remain available.
        }
    }

    private func fileURL(for languagePrefix: String) -> URL {
        cacheDirectory().appendingPathComponent("plaintext_\(languagePrefix).json")
    }

    private func cacheDirectory() -> URL {
        if let baseDirectory {
            return baseDirectory
        }
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("Localization", isDirectory: true)
    }
}

private struct LocalizationCachePayload: Codable {
    let language: String
    let updatedAt: Date
    let values: [String: String]
}
