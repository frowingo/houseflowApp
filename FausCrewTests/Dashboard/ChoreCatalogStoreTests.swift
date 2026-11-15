import XCTest
import FausCrewCore
@testable import FausCrew

/// `ChoreCatalogStore` against a fake service: the list is the server's, PUT results patch it,
/// a refused delete comes back, and a 404 fetches the list again.
@MainActor
final class ChoreCatalogStoreTests: XCTestCase {
    private final class FakeService: ChoreCatalogServicing {
        var list: [ChoreCatalogRecord] = []
        var fetchError: ChoreCatalogFailure?
        var upsertError: ChoreCatalogFailure?
        private(set) var fetchCount = 0
        private(set) var sent: [[ChoreCatalogRecord]] = []
        private var nextId = 0

        func fetchCatalog() async throws -> [ChoreCatalogRecord] {
            fetchCount += 1
            if let fetchError { throw fetchError }
            return list
        }

        func upsertCatalog(_ records: [ChoreCatalogRecord], local: [ChoreCatalogRecord]) async throws -> [ChoreCatalogRecord] {
            sent.append(records)
            if let upsertError { throw upsertError }
            let response = records.map { record -> ChoreCatalogRecord in
                var saved = record
                if saved.id == nil {
                    nextId += 1
                    saved.id = String(format: "%024d", nextId)
                }
                saved.updatedOn = "2026-11-12T12:00:0\(nextId)Z"
                return saved
            }
            return try ChoreCatalogPatch.apply(response: response, sent: records, to: local)
        }
    }

    private let system = ChoreCatalogRecord(id: "6730f1c2a1b2c3d4e5f60701", title: "Bulaşıkları yıka", category: 1, isSystem: true)
    private let draft = ChoreCatalogRecord(id: "6730f1c2a1b2c3d4e5f60718", title: "Nevresimler", category: 2,
                                           updatedOn: "2026-11-12T09:00:00Z")

    func testRefreshLoadsSystemTemplatesAndDrafts() async {
        let service = FakeService()
        service.list = [system, draft]
        let store = ChoreCatalogStore(service: service)
        XCTAssertFalse(store.hasLoaded)

        await store.refresh(ownerId: "u1")
        XCTAssertEqual(store.phase, .loaded)
        XCTAssertEqual(store.systemRecords.map(\.id), [system.id])
        XCTAssertEqual(store.userRecords.map(\.id), [draft.id])
    }

    func testAFailedRefreshKeepsTheLastListAndAnotherUserStartsEmpty() async {
        let service = FakeService()
        service.list = [system]
        let store = ChoreCatalogStore(service: service)
        await store.refresh(ownerId: "u1")

        service.fetchError = ChoreCatalogFailure(kind: .server, message: "Down")
        await store.refresh(ownerId: "u1")
        XCTAssertEqual(store.records.count, 1)
        XCTAssertEqual(store.phase, .failed(ChoreCatalogFailure(kind: .server, message: "Down")))
        XCTAssertTrue(store.hasLoaded)

        await store.refresh(ownerId: "u2")
        XCTAssertTrue(store.records.isEmpty, "never shows the previous user's drafts")
    }

    func testSavingASystemTemplateAddsANewDraft() async {
        let service = FakeService()
        service.list = [system]
        let store = ChoreCatalogStore(service: service)
        await store.refresh(ownerId: "u1")

        let failure = await store.save(system.asNewUserRecord)
        XCTAssertNil(failure)
        XCTAssertNil(service.sent.last?.first?.id)
        XCTAssertEqual(service.sent.last?.first?.isSystem, false)
        XCTAssertEqual(store.userRecords.count, 1)
        XCTAssertEqual(store.systemRecords, [system], "the system template is untouched")

        // Saving it again adds another draft: there is no link to the template.
        await store.save(system.asNewUserRecord)
        XCTAssertEqual(store.userRecords.count, 2)
    }

    func testUpdatingADraftKeepsItsIdAndPlace() async {
        let service = FakeService()
        service.list = [system, draft]
        let store = ChoreCatalogStore(service: service)
        await store.refresh(ownerId: "u1")

        var changed = draft
        changed.title = "Nevresimleri değiştir"
        let failure = await store.save(changed)
        XCTAssertNil(failure)
        XCTAssertEqual(store.records.map(\.id), [system.id, draft.id])
        XCTAssertEqual(store.userRecords.first?.title, "Nevresimleri değiştir")
    }

    func testARefusedDeleteRestoresTheDraft() async {
        let service = FakeService()
        service.list = [system, draft]
        let store = ChoreCatalogStore(service: service)
        await store.refresh(ownerId: "u1")

        service.upsertError = ChoreCatalogFailure(kind: .server, message: "Nope")
        let failure = await store.delete(draft)
        XCTAssertEqual(failure?.message, "Nope")
        XCTAssertEqual(store.records.map(\.id), [system.id, draft.id])
        XCTAssertEqual(service.sent.last?.first?.isDeleted, true)
        XCTAssertTrue(store.pendingDeletes.isEmpty)
    }

    func testDeleteRemovesTheDraftAndNeverTouchesSystemTemplates() async {
        let service = FakeService()
        service.list = [system, draft]
        let store = ChoreCatalogStore(service: service)
        await store.refresh(ownerId: "u1")

        await store.delete(system)
        XCTAssertTrue(service.sent.isEmpty)
        let failure = await store.delete(draft)
        XCTAssertNil(failure)
        XCTAssertEqual(store.records.map(\.id), [system.id])
    }

    func testNotFoundFetchesTheListAgain() async {
        let service = FakeService()
        service.list = [system, draft]
        let store = ChoreCatalogStore(service: service)
        await store.refresh(ownerId: "u1")

        service.list = [system]
        service.upsertError = ChoreCatalogFailure(kind: .notFound, message: "Görev kataloğu kaydı bulunamadı veya silinmiş.")
        var changed = draft
        changed.title = "Başka"
        let failure = await store.save(changed)
        XCTAssertEqual(failure?.kind, .notFound)
        XCTAssertEqual(service.fetchCount, 2)
        XCTAssertEqual(store.records.map(\.id), [system.id])
    }

    func testWithoutAServiceTheCatalogShowsItsErrorState() async {
        let store = ChoreCatalogStore(service: nil)
        await store.refresh(ownerId: "u1")
        XCTAssertEqual(store.phase, .failed(ChoreCatalogFailure(kind: .server, message: nil)))
    }
}
