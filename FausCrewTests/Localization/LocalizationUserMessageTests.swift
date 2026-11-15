import XCTest
import FausCrewCore
@testable import FausCrew

@MainActor
final class LocalizationUserMessageTests: XCTestCase {
    override func setUp() async throws {
        try await super.setUp()
        let previousLanguage = APILanguage.code
        APILanguage.update(prefix: "en")
        addTeardownBlock {
            await MainActor.run {
                APILanguage.update(prefix: previousLanguage)
            }
        }
    }

    func testServerErrorPreservesUserMessage() {
        let store = makeStore()

        XCTAssertEqual(
            store.userMessage(for: NetworkError.serverError("This house is full.")),
            "This house is full."
        )
    }

    func testUnauthorizedUsesSessionExpiredFallback() {
        let store = makeStore()

        XCTAssertEqual(
            store.userMessage(for: NetworkError.unauthorized),
            "Your session has expired. Please sign in again."
        )
    }

    func testURLErrorUsesConnectionFallbackWithoutTechnicalDetails() {
        let store = makeStore()
        let error = URLError(.notConnectedToInternet, userInfo: [
            NSLocalizedDescriptionKey: "technical-connection-detail"
        ])
        let message = store.userMessage(for: error)

        XCTAssertEqual(message, "Unable to connect. Please check your internet connection.")
        XCTAssertFalse(message.contains("technical-connection-detail"))
        XCTAssertFalse(message.contains("-1009"))
    }

    func testDecodingErrorUsesGenericFallbackWithoutTechnicalDetails() {
        let error = DecodingError.dataCorrupted(.init(
            codingPath: [],
            debugDescription: "technical-decoding-detail"
        ))

        assertGenericMessage(for: NetworkError.decodingError(error))
    }

    func testUnknownStatusUsesGenericFallbackWithoutStatusCode() {
        assertGenericMessage(for: NetworkError.unknown(500))
    }

    func testInvalidURLUsesGenericFallback() {
        assertGenericMessage(for: NetworkError.invalidURL)
    }

    func testUnrecognizedErrorUsesGenericFallbackWithoutTechnicalDetails() {
        assertGenericMessage(for: TestError.sample)
    }

    func testTurkishFallbacksCoverEveryErrorType() {
        APILanguage.update(prefix: "tr")
        let store = makeStore()
        let cases: [(Error, String)] = [
            (NetworkError.serverError("This house is full."), "This house is full."),
            (NetworkError.unauthorized, "Oturumunuz sona ermiş. Lütfen tekrar giriş yapın."),
            (URLError(.notConnectedToInternet), "Bağlantı kurulamadı. İnternet bağlantınızı kontrol edin."),
            (NetworkError.decodingError(TestError.sample), "Bir şeyler ters gitti. Lütfen tekrar deneyin."),
            (NetworkError.unknown(500), "Bir şeyler ters gitti. Lütfen tekrar deneyin."),
            (NetworkError.invalidURL, "Bir şeyler ters gitti. Lütfen tekrar deneyin."),
            (TestError.sample, "Bir şeyler ters gitti. Lütfen tekrar deneyin.")
        ]

        for (error, expected) in cases {
            let message = store.userMessage(for: error)

            XCTAssertEqual(message, expected)
            XCTAssertFalse(message.contains("test-error"))
            XCTAssertFalse(message.contains("500"))
        }
    }

    func testUserMessagesUseBackendValuesRegardlessOfFallbackLanguage() async throws {
        let service = FakeLocalizationService()
        service.fetchPlaintextsHandler = { prefix in
            XCTAssertEqual(prefix, "tr")
            return [
                LocalizationPlaintextItem(key: "error_generic", language: prefix, value: "Tekrar deneyin."),
                LocalizationPlaintextItem(key: "error_network_unavailable", language: prefix, value: "Bağlantınızı kontrol edin."),
                LocalizationPlaintextItem(key: "error_session_expired", language: prefix, value: "Tekrar giriş yapın.")
            ]
        }
        let store = makeStore(service: service)

        try await store.refreshLanguagePrefix("tr")

        for language in ["tr", "en"] {
            APILanguage.update(prefix: language)

            XCTAssertEqual(store.userMessage(for: NetworkError.unknown(500)), "Tekrar deneyin.")
            XCTAssertEqual(store.userMessage(for: URLError(.notConnectedToInternet)), "Bağlantınızı kontrol edin.")
            XCTAssertEqual(store.userMessage(for: NetworkError.unauthorized), "Tekrar giriş yapın.")
            XCTAssertEqual(store.userMessage(for: NetworkError.serverError("This house is full.")), "This house is full.")
        }
    }

    func testNetworkErrorDescriptionsHideTechnicalDetails() {
        let errors: [NetworkError] = [
            .invalidURL,
            .decodingError(TestError.sample),
            .unknown(500)
        ]

        for error in errors {
            XCTAssertEqual(error.localizedDescription, "Something went wrong. Please try again.")
        }
        XCTAssertEqual(NetworkError.serverError("This house is full.").localizedDescription, "This house is full.")
    }

    private func assertGenericMessage(
        for error: Error,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        let message = makeStore().userMessage(for: error)

        XCTAssertEqual(message, "Something went wrong. Please try again.", file: file, line: line)
        for detail in ["technical-decoding-detail", "500", "invalidURL", "test-error"] {
            XCTAssertFalse(message.contains(detail), file: file, line: line)
        }
    }

    private func makeStore(service: FakeLocalizationService? = nil) -> LocalizationStore {
        let localization = TestFixture.localizationStore(service: service ?? FakeLocalizationService())
        addTeardownBlock {
            try? FileManager.default.removeItem(at: localization.directory)
        }
        return localization.store
    }
}
