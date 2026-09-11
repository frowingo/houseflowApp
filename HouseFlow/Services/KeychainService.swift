import Foundation
import Security

/// Wrapper around the iOS Keychain for secure string storage.
final class KeychainService {
    private let service: String

    init(service: String = "com.houseflow.app") {
        self.service = service
    }

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
    static let authTokenKey    = "authToken"
    static let userEmailKey    = "userEmail"
    static let userFirstNameKey = "userFirstName"
    static let userLastNameKey  = "userLastName"
    static let pendingEmailVerificationKey = "pendingEmailVerification"

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

    var userEmail: String? {
        get { load(forKey: Self.userEmailKey) }
        set {
            if let email = newValue {
                save(email, forKey: Self.userEmailKey)
            } else {
                delete(forKey: Self.userEmailKey)
            }
        }
    }

    var userFirstName: String? {
        get { load(forKey: Self.userFirstNameKey) }
        set {
            if let value = newValue {
                save(value, forKey: Self.userFirstNameKey)
            } else {
                delete(forKey: Self.userFirstNameKey)
            }
        }
    }

    var userLastName: String? {
        get { load(forKey: Self.userLastNameKey) }
        set {
            if let value = newValue {
                save(value, forKey: Self.userLastNameKey)
            } else {
                delete(forKey: Self.userLastNameKey)
            }
        }
    }

    var pendingEmailVerification: String? {
        get { load(forKey: Self.pendingEmailVerificationKey) }
        set {
            if let email = newValue {
                save(email, forKey: Self.pendingEmailVerificationKey)
            } else {
                delete(forKey: Self.pendingEmailVerificationKey)
            }
        }
    }
}
