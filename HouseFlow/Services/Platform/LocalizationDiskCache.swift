import Foundation
import HouseFlowCore

struct LocalizationDiskCache: LocalizationCacheStore {
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
