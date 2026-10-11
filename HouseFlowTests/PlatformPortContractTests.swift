import XCTest
import HouseFlowCore
@testable import HouseFlow

@MainActor
final class PlatformPortContractTests: XCTestCase {
    private static let keychain = KeychainService(service: "PlatformPortContractTests-\(UUID().uuidString)")
    private static let localizationService = ContractLocalizationService()

    func testHTTPAdapterPreservesMethodQueryHeadersBodyAndStatus() async throws {
        let fixture = try platformHTTPFixture()
        var captured: URLRequest?
        let client = URLSessionHTTPClient(
            baseURL: URL(string: "https://example.com/api/v1")!,
            requestExecutor: { request in
                captured = request
                let response = HTTPURLResponse(
                    url: request.url!,
                    statusCode: try XCTUnwrap(Int(fixture["responseStatus"] ?? "")),
                    httpVersion: nil,
                    headerFields: [
                        try XCTUnwrap(fixture["responseHeaderName"]):
                            try XCTUnwrap(fixture["responseHeaderValue"])
                    ]
                )!
                return (Data(try XCTUnwrap(fixture["responseBody"]).utf8), response)
            }
        )

        let response = try await client.send(HTTPRequest(
            path: try XCTUnwrap(fixture["path"]),
            method: try XCTUnwrap(fixture["method"]),
            queryItems: [HTTPQueryItem(
                name: try XCTUnwrap(fixture["queryName"]),
                value: try XCTUnwrap(fixture["queryValue"])
            )],
            headers: [
                "Authorization": try XCTUnwrap(fixture["authorization"]),
                "Content-Type": try XCTUnwrap(fixture["contentType"])
            ],
            body: Data(try XCTUnwrap(fixture["body"]).utf8)
        ))

        let request = try XCTUnwrap(captured)
        XCTAssertEqual(request.url?.path, "/api/v1/\(try XCTUnwrap(fixture["path"]))")
        XCTAssertEqual(URLComponents(url: request.url!, resolvingAgainstBaseURL: false)?.queryItems,
                       [URLQueryItem(name: try XCTUnwrap(fixture["queryName"]), value: try XCTUnwrap(fixture["queryValue"]))])
        XCTAssertEqual(request.httpMethod, fixture["method"])
        XCTAssertEqual(request.value(forHTTPHeaderField: "Authorization"), fixture["authorization"])
        XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), fixture["contentType"])
        XCTAssertEqual(request.httpBody, Data(try XCTUnwrap(fixture["body"]).utf8))
        XCTAssertEqual(response.statusCode, Int(fixture["responseStatus"] ?? ""))
        XCTAssertEqual(response.headers["x-request-id"], fixture["responseHeaderValue"])
        XCTAssertEqual(HTTPStatusFailure(response: response).message, fixture["failureMessage"])
    }

    private func platformHTTPFixture() throws -> [String: String] {
        let repositoryDirectory = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent()
        let path = repositoryDirectory.appendingPathComponent("HouseFlow/shared/Fixtures/platform_http_contract.txt")
        let text = try String(contentsOf: path, encoding: .utf8)
        return Dictionary(uniqueKeysWithValues: text.split(separator: "\n").map { line in
            let parts = line.split(separator: "=", maxSplits: 1, omittingEmptySubsequences: false)
            return (String(parts[0]), String(parts[1]))
        })
    }

    func testPreferencesAdapterReadsExistingKeysAndWritesSameDomain() throws {
        let suite = "PlatformPortContractTests-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defaults.removePersistentDomain(forName: suite)
        defer { defaults.removePersistentDomain(forName: suite) }

        defaults.set(true, forKey: "hasSeenOnboarding")
        defaults.set("house-old", forKey: "chosenHouse")
        let port: any PreferencesStore = defaults
        XCTAssertTrue(port.bool(forKey: "hasSeenOnboarding"))
        XCTAssertEqual(port.string(forKey: "chosenHouse"), "house-old")

        port.set("house-new", forKey: "chosenHouse")
        XCTAssertEqual(defaults.string(forKey: "chosenHouse"), "house-new")
        port.removeObject(forKey: "chosenHouse")
        XCTAssertNil(defaults.string(forKey: "chosenHouse"))
    }

    func testLocalizationCacheReadsExistingPayloadAndFallbackIsUnchanged() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("PlatformPortContractTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let port: any LocalizationCacheStore = LocalizationDiskCache(baseDirectory: directory)
        let legacyPayload = Data(#"{"language":"en","updatedAt":0,"values":{"known.key":"Cached value"}}"#.utf8)
        try legacyPayload.write(to: directory.appendingPathComponent("plaintext_en.json"))
        XCTAssertEqual(port.load(languagePrefix: "en")["known.key"], "Cached value")
        XCTAssertEqual(port.loadMostRecent()?.languagePrefix, "en")

        let store = LocalizationStore(service: Self.localizationService, cache: port)
        XCTAssertEqual(store.value(for: "known.key"), "Cached value")
        XCTAssertEqual(store.value(for: "missing.key", fallback: "Fallback"), "Fallback")

        port.save(values: ["known.key": "Updated value"], languagePrefix: "en")
        XCTAssertEqual(port.load(languagePrefix: "en")["known.key"], "Updated value")
    }

    func testKeychainPortSavesLoadsAndDeletesToken() throws {
        let keychain = Self.keychain
        guard keychain.save("test-token", forKey: KeychainService.authTokenKey) else {
            throw XCTSkip("Unsigned simulator test host has no usable Keychain access")
        }
        let port: any SecureSessionStore = keychain
        XCTAssertEqual(port.authToken, "test-token")
        port.authToken = "updated-token"
        XCTAssertEqual(port.authToken, "updated-token")
        port.authToken = nil
        XCTAssertNil(port.authToken)
    }
}

@MainActor
private final class ContractLocalizationService: LocalizationServicing {
    func fetchLanguages() async throws -> [LocalizationLanguage] { [] }
    func fetchPlaintexts(languagePrefix: String) async throws -> [LocalizationPlaintextItem] { [] }
}
