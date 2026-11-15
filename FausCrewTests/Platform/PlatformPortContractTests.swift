import XCTest
import Security
import FausCrewCore
@testable import FausCrew

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
        let text = try String(contentsOf: sharedFixtureURL("platform_http_contract.txt"), encoding: .utf8)
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

    func testSaveMovesExistingItemToThisDeviceOnlyClass() throws {
        let service = "PlatformPortContractTests-\(UUID().uuidString)"
        let keychain = KeychainService(service: service)
        defer { keychain.delete(forKey: KeychainService.authTokenKey) }
        // An item as older builds stored it: no explicit accessibility class.
        let legacy: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: KeychainService.authTokenKey,
            kSecValueData: Data("old-token".utf8)
        ]
        guard SecItemAdd(legacy as CFDictionary, nil) == errSecSuccess else {
            throw XCTSkip("Unsigned simulator test host has no usable Keychain access")
        }
        XCTAssertNotEqual(accessibility(service: service, key: KeychainService.authTokenKey),
                          kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)

        XCTAssertTrue(keychain.save("new-token", forKey: KeychainService.authTokenKey))
        XCTAssertEqual(keychain.authToken, "new-token")
        XCTAssertEqual(accessibility(service: service, key: KeychainService.authTokenKey),
                       kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }

    func testSavingLoadedUnchangedValueMigratesOnce() throws {
        let service = "PlatformPortContractTests-\(UUID().uuidString)"
        let keychain = KeychainService(service: service)
        let key = KeychainService.userEmailKey
        defer { keychain.delete(forKey: key) }
        let legacy: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecValueData: Data("user@example.com".utf8)
        ]
        guard SecItemAdd(legacy as CFDictionary, nil) == errSecSuccess else {
            throw XCTSkip("Unsigned simulator test host has no usable Keychain access")
        }
        XCTAssertEqual(keychain.load(forKey: key), "user@example.com")
        XCTAssertNotEqual(accessibility(service: service, key: key),
                          kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)

        XCTAssertTrue(keychain.save("user@example.com", forKey: key))
        XCTAssertEqual(accessibility(service: service, key: key),
                       kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)

        let writer = KeychainService(service: service)
        XCTAssertTrue(writer.save("external@example.com", forKey: key))
        XCTAssertTrue(keychain.save("user@example.com", forKey: key))

        XCTAssertEqual(keychain.load(forKey: key), "user@example.com")
        XCTAssertEqual(KeychainService(service: service).load(forKey: key), "external@example.com")
    }

    // MARK: Keychain helpers

    private func accessibility(service: String, key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key,
            kSecReturnAttributes: true,
            kSecMatchLimit: kSecMatchLimitOne
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let attributes = result as? [String: Any] else { return nil }
        return attributes[kSecAttrAccessible as String] as? String
    }
}

@MainActor
private final class ContractLocalizationService: LocalizationServicing {
    func fetchLanguages() async throws -> [LocalizationLanguage] { [] }
    func fetchPlaintexts(languagePrefix: String) async throws -> [LocalizationPlaintextItem] { [] }
}
