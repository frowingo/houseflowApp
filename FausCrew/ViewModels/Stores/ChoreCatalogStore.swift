import Foundation
import Combine
import FausCrewCore

/// The chore catalog as the server last sent it: system templates and the signed-in user's
/// drafts. The server is the only source of truth; this keeps the last list in memory so the
/// popup reopens without a blank state, and patches it with each PUT result.
/// PUT requests go one at a time, so each response is matched to its own request by index.
@MainActor
final class ChoreCatalogStore: ObservableObject {
    enum Phase: Equatable {
        case idle
        case loading
        case loaded
        case failed(ChoreCatalogFailure)
    }

    @Published private(set) var records: [ChoreCatalogRecord] = []
    @Published private(set) var phase: Phase = .idle
    /// Ids of drafts whose delete is on its way to the server.
    @Published private(set) var pendingDeletes: Set<String> = []

    private let service: (any ChoreCatalogServicing)?
    /// The user the list belongs to; another user's list is never shown.
    private var ownerId: String?
    private var refreshTask: Task<Void, Never>?
    private var queueTail: Task<Void, Never>?

    init(service: (any ChoreCatalogServicing)?) {
        self.service = service
    }

    var systemRecords: [ChoreCatalogRecord] { records.systemRecords }
    var userRecords: [ChoreCatalogRecord] { records.userRecords }
    var hasLoaded: Bool { phase == .loaded || !records.isEmpty }

    /// Fetches the list again. A failure keeps the last list on screen.
    func refresh(ownerId: String?) async {
        if ownerId != self.ownerId {
            self.ownerId = ownerId
            records = []
            phase = .idle
        }
        if let refreshTask {
            await refreshTask.value
            return
        }
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            await self.load()
        }
        refreshTask = task
        await task.value
        refreshTask = nil
    }

    private func load() async {
        guard let service else {
            phase = .failed(ChoreCatalogFailure(kind: .server, message: nil))
            return
        }
        phase = .loading
        do {
            let fetched = try await service.fetchCatalog()
            records = fetched
            phase = .loaded
        } catch is CancellationError {
            phase = records.isEmpty ? .idle : .loaded
        } catch {
            phase = .failed(Self.failure(error))
        }
    }

    /// Adds a draft (no id) or updates one (with id). Returns the failure, if any; after a 404
    /// the list is fetched again.
    @discardableResult
    func save(_ record: ChoreCatalogRecord) async -> ChoreCatalogFailure? {
        await enqueue { [self] in
            guard let service else { return ChoreCatalogFailure(kind: .server, message: nil) }
            do {
                records = try await service.upsertCatalog([record], local: records)
                return nil
            } catch {
                return await handle(error)
            }
        }
    }

    /// Removes the draft at once and restores it if the server refuses.
    @discardableResult
    func delete(_ record: ChoreCatalogRecord) async -> ChoreCatalogFailure? {
        guard let id = record.id, !record.isSystem else { return nil }
        let index = records.firstIndex { $0.id == id }
        records.removeAll { $0.id == id }
        pendingDeletes.insert(id)
        defer { pendingDeletes.remove(id) }
        return await enqueue { [self] in
            guard let service else { return restore(record, at: index, failure: ChoreCatalogFailure(kind: .server, message: nil)) }
            do {
                records = try await service.upsertCatalog([record.markedDeleted], local: records)
                return nil
            } catch {
                let failure = Self.failure(error)
                // Already gone on the server: nothing to restore.
                if failure.refreshesList { return await handle(error) }
                return restore(record, at: index, failure: failure)
            }
        }
    }

    private func restore(_ record: ChoreCatalogRecord, at index: Int?, failure: ChoreCatalogFailure) -> ChoreCatalogFailure {
        if !records.contains(where: { $0.id == record.id }) {
            records.insert(record, at: min(index ?? 0, records.count))
        }
        return failure
    }

    private func handle(_ error: Error) async -> ChoreCatalogFailure {
        let failure = Self.failure(error)
        if failure.refreshesList { await load() }
        return failure
    }

    /// Runs PUTs one after another.
    private func enqueue(_ operation: @escaping @MainActor () async -> ChoreCatalogFailure?) async -> ChoreCatalogFailure? {
        let previous = queueTail
        let task = Task { @MainActor () -> ChoreCatalogFailure? in
            await previous?.value
            return await operation()
        }
        queueTail = Task { _ = await task.value }
        return await task.value
    }

    private static func failure(_ error: Error) -> ChoreCatalogFailure {
        (error as? ChoreCatalogFailure) ?? ChoreCatalogFailure(kind: .server, message: nil)
    }
}
