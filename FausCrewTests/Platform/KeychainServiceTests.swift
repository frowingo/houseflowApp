import XCTest
@testable import FausCrew

@MainActor
final class KeychainServiceTests: XCTestCase {
    func testSecondLoadUsesCachedValue() throws {
        let service = "KeychainServiceTests-\(UUID().uuidString)"
        let keychain = KeychainService(service: service)
        let writer = KeychainService(service: service)
        let key = KeychainService.authTokenKey
        defer { writer.delete(forKey: key) }
        try requireKeychainAccess(writer, key: key)

        XCTAssertEqual(keychain.load(forKey: key), "stored-token")
        XCTAssertTrue(writer.save("external-token", forKey: key))

        XCTAssertEqual(KeychainService(service: service).load(forKey: key), "external-token")
        XCTAssertEqual(keychain.load(forKey: key), "stored-token")
    }

    func testMissingItemIsCached() throws {
        let service = "KeychainServiceTests-\(UUID().uuidString)"
        let keychain = KeychainService(service: service)
        let writer = KeychainService(service: service)
        let key = KeychainService.authTokenKey
        defer { writer.delete(forKey: key) }
        try requireKeychainAccess(writer, key: key)
        XCTAssertTrue(writer.delete(forKey: key))

        XCTAssertNil(keychain.load(forKey: key))
        XCTAssertTrue(writer.save("external-token", forKey: key))

        XCTAssertEqual(KeychainService(service: service).load(forKey: key), "external-token")
        XCTAssertNil(keychain.load(forKey: key))
    }

    func testSavingUnchangedValueReturnsTrueWithoutWriting() throws {
        let service = "KeychainServiceTests-\(UUID().uuidString)"
        let keychain = KeychainService(service: service)
        let writer = KeychainService(service: service)
        let key = KeychainService.authTokenKey
        defer { writer.delete(forKey: key) }
        try requireKeychainAccess(keychain, key: key)
        XCTAssertTrue(writer.save("external-token", forKey: key))

        XCTAssertTrue(keychain.save("stored-token", forKey: key))

        XCTAssertEqual(keychain.load(forKey: key), "stored-token")
        XCTAssertEqual(KeychainService(service: service).load(forKey: key), "external-token")
    }

    func testSavingChangedValueUpdatesCachedAbsenceAndValue() throws {
        let service = "KeychainServiceTests-\(UUID().uuidString)"
        let keychain = KeychainService(service: service)
        let writer = KeychainService(service: service)
        let key = KeychainService.authTokenKey
        defer { writer.delete(forKey: key) }
        try requireKeychainAccess(writer, key: key)
        XCTAssertTrue(writer.delete(forKey: key))
        XCTAssertNil(keychain.load(forKey: key))

        XCTAssertTrue(keychain.save("first-token", forKey: key))
        XCTAssertEqual(keychain.load(forKey: key), "first-token")
        XCTAssertTrue(keychain.save("second-token", forKey: key))

        XCTAssertEqual(keychain.load(forKey: key), "second-token")
        XCTAssertEqual(KeychainService(service: service).load(forKey: key), "second-token")
    }

    func testDeleteRemovesCachedValueStoredItemAndWriteHistory() throws {
        let service = "KeychainServiceTests-\(UUID().uuidString)"
        let keychain = KeychainService(service: service)
        let key = KeychainService.authTokenKey
        defer { keychain.delete(forKey: key) }
        try requireKeychainAccess(keychain, key: key)
        XCTAssertEqual(keychain.load(forKey: key), "stored-token")

        XCTAssertTrue(keychain.delete(forKey: key))

        XCTAssertNil(keychain.load(forKey: key))
        XCTAssertNil(KeychainService(service: service).load(forKey: key))
        XCTAssertTrue(keychain.save("stored-token", forKey: key))
        XCTAssertEqual(keychain.load(forKey: key), "stored-token")
        XCTAssertEqual(KeychainService(service: service).load(forKey: key), "stored-token")
    }

    func testDeletingMissingItemReturnsFalseAndCachesAbsence() throws {
        let service = "KeychainServiceTests-\(UUID().uuidString)"
        let keychain = KeychainService(service: service)
        let writer = KeychainService(service: service)
        let key = KeychainService.authTokenKey
        defer { writer.delete(forKey: key) }
        try requireKeychainAccess(writer, key: key)
        XCTAssertTrue(writer.delete(forKey: key))
        XCTAssertNil(keychain.load(forKey: key))

        XCTAssertFalse(keychain.delete(forKey: key))
        XCTAssertTrue(writer.save("external-token", forKey: key))

        XCTAssertNil(keychain.load(forKey: key))
    }

    private func requireKeychainAccess(_ keychain: KeychainService, key: String) throws {
        guard keychain.save("stored-token", forKey: key) else {
            throw XCTSkip("Unsigned simulator test host has no usable Keychain access")
        }
    }
}
