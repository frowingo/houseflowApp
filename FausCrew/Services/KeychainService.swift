import Foundation
import Security

/// Wrapper around the iOS Keychain for secure string storage.
final class KeychainService {
    private enum Entry {
        case missing
        case loaded(String)
        case written(String)
    }

    private let service: String
    private var cache: [String: Entry] = [:]

    init(service: String = "com.fauscrew.app") {
        self.service = service
    }

    // MARK: - Save

    @discardableResult
    func save(_ value: String, forKey key: String) -> Bool {
        // Loaded legacy items still need one write to migrate their accessibility class.
        if case .written(let cachedValue)? = cache[key], cachedValue == value { return true }
        guard let data = value.data(using: .utf8) else { return false }

        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrService: service,
            kSecAttrAccount: key
        ]
        // Not in device backups and not readable before the first unlock after a restart.
        // Updating also moves items saved by older builds (default class) to this one.
        let attributes: [CFString: Any] = [
            kSecValueData:      data,
            kSecAttrAccessible: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        ]

        // Update in place so a failed write keeps the previous value instead of losing it.
        var status = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if status == errSecItemNotFound {
            let addQuery = query.merging(attributes) { _, new in new }
            status = SecItemAdd(addQuery as CFDictionary, nil)
        }
        if status == errSecSuccess {
            cache[key] = .written(value)
        }
        return status == errSecSuccess
    }

    // MARK: - Load

    func load(forKey key: String) -> String? {
        if let entry = cache[key] {
            switch entry {
            case .missing:
                return nil
            case .loaded(let value), .written(let value):
                return value
            }
        }

        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrService:      service,
            kSecAttrAccount:      key,
            kSecReturnData:       true,
            kSecMatchLimit:       kSecMatchLimitOne
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        if status == errSecItemNotFound {
            cache[key] = .missing
            return nil
        }
        guard status == errSecSuccess,
              let data = result as? Data,
              let value = String(data: data, encoding: .utf8) else {
            return nil
        }
        cache[key] = .loaded(value)
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
        let status = SecItemDelete(query as CFDictionary)
        if status == errSecSuccess || status == errSecItemNotFound {
            cache[key] = .missing
        } else {
            cache.removeValue(forKey: key)
        }
        return status == errSecSuccess
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
