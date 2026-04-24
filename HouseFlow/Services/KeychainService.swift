import Foundation
import Security

/// Wrapper around the iOS Keychain for secure string storage.
final class KeychainService {
    static let shared = KeychainService()

    private let service = "com.houseflow.app"

    private init() {}

    // MARK: - Save

    @discardableResult
    func save(_ value: String, forKey key: String) -> Bool {
        guard let data = value.data(using: .utf8) else { return false }

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]

        // Remove existing item first (update-by-delete-then-add pattern)
        SecItemDelete(query as CFDictionary)

        var addQuery = query
        addQuery[kSecValueData] = data

        let status = SecItemAdd(addQuery as CFDictionary, nil)
        return status == errSecSuccess
    }

    // MARK: - Load

    func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        return value
    }

    // MARK: - Delete

    @discardableResult
    func delete(forKey key: String) -> Bool {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        return SecItemDelete(query as CFDictionary) == errSecSuccess
    }
}

// MARK: - Typed Keys

extension KeychainService {
    static let authTokenKey = "authToken"

    var authToken: String? {
        get { load(forKey: Self.authTokenKey) }
        set {
            if let token = newValue {
                save(token, forKey: Self.authTokenKey)
            } else {
                delete(forKey: Self.authTokenKey)
            }
        }
    }
}
