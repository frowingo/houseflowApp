import Foundation
import Combine

@MainActor
final class LocalizationStore: ObservableObject {
    @Published private(set) var language: AppLanguage
    @Published private(set) var values: [String: String]
    @Published private(set) var isRefreshing = false

    private let service: LocalizationService
    private let cache: LocalizationDiskCache
    private var refreshTask: Task<Void, Never>?

    private static let languageDefaultsKey = "localization.currentLanguage"

    init() {
        self.service = LocalizationService.shared
        self.cache = LocalizationDiskCache()

        let savedLanguage = AppLanguage(
            normalizing: UserDefaults.standard.string(forKey: Self.languageDefaultsKey)
        )
        self.language = savedLanguage
        self.values = cache.load(language: savedLanguage)
    }

    deinit {
        refreshTask?.cancel()
    }

    func start() {
        refreshIfNeeded(force: values.isEmpty)
    }

    func value(for key: String) -> String {
        values[key] ?? key
    }

    func value(for key: String, replacements: [String: String]) -> String {
        var localizedValue = value(for: key)
        for (placeholder, value) in replacements {
            localizedValue = localizedValue.replacingOccurrences(of: "{\(placeholder)}", with: value)
        }
        return localizedValue
    }

    func setLanguage(_ newLanguage: AppLanguage) {
        guard newLanguage != language else {
            refreshIfNeeded(force: values.isEmpty)
            return
        }

        language = newLanguage
        UserDefaults.standard.set(newLanguage.rawValue, forKey: Self.languageDefaultsKey)
        values = cache.load(language: newLanguage)
        refreshIfNeeded(force: true)
    }

    func applyPreferredLanguage(_ rawLanguage: String?) {
        setLanguage(AppLanguage(normalizing: rawLanguage))
    }

    func refreshIfNeeded(force: Bool = false) {
        guard force || values.isEmpty else { return }

        refreshTask?.cancel()
        let currentLanguage = language
        refreshTask = Task { [weak self] in
            await self?.refresh(language: currentLanguage)
        }
    }

    private func refresh(language: AppLanguage) async {
        isRefreshing = true
        defer { isRefreshing = false }

        do {
            let items = try await service.fetchPlaintexts(language: language)
            guard !Task.isCancelled, self.language == language else { return }

            let freshValues = Dictionary(
                uniqueKeysWithValues: items.map { ($0.key, $0.value) }
            )
            values = freshValues
            cache.save(values: freshValues, language: language)
        } catch {
            // Lookup already falls back to the key, so a failed refresh should not block UI.
        }
    }
}

struct LocalizationDiskCache {
    private let fileManager: FileManager
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
    }

    func load(language: AppLanguage) -> [String: String] {
        guard
            let data = try? Data(contentsOf: fileURL(for: language)),
            let payload = try? decoder.decode(LocalizationCachePayload.self, from: data)
        else {
            return [:]
        }

        return payload.values
    }

    func save(values: [String: String], language: AppLanguage) {
        do {
            let directory = cacheDirectory()
            try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
            let payload = LocalizationCachePayload(
                language: language.rawValue,
                updatedAt: Date(),
                values: values
            )
            let data = try encoder.encode(payload)
            try data.write(to: fileURL(for: language), options: .atomic)
        } catch {
            // Persisting the cache is best-effort; in-memory values remain available.
        }
    }

    private func fileURL(for language: AppLanguage) -> URL {
        cacheDirectory().appendingPathComponent("plaintext_\(language.rawValue).json")
    }

    private func cacheDirectory() -> URL {
        let root = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return root.appendingPathComponent("Localization", isDirectory: true)
    }
}

private struct LocalizationCachePayload: Codable {
    let language: String
    let updatedAt: Date
    let values: [String: String]
}
