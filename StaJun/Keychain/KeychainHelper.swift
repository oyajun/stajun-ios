import Foundation
import Security

/// Keychain helper for token persistence
enum KeychainHelper {
    private static let tokenKey = "com.oyajun.StaJun.authToken"
    private static let emailKey = "com.oyajun.StaJun.userEmail"
    private static let lock = NSLock()

    /// Saved Bearer token (nil if not available)
    static var token: String? {
        get { load(key: tokenKey) }
        set {
            if let value = newValue {
                save(key: tokenKey, value: value)
            } else {
                delete(key: tokenKey)
            }
        }
    }

    /// Saved sign-in email (nil if not available)
    static var email: String? {
        get { load(key: emailKey) }
        set {
            if let value = newValue {
                save(key: emailKey, value: value)
            } else {
                delete(key: emailKey)
            }
        }
    }

    // MARK: - Private

    private static func save(key: String, value: String) {
        lock.lock()
        defer { lock.unlock() }

        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        let attributes: [CFString: Any] = [
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]

        let updateStatus = SecItemUpdate(query as CFDictionary, attributes as CFDictionary)
        if updateStatus == errSecItemNotFound {
            var addQuery = query
            addQuery[kSecValueData] = data
            addQuery[kSecAttrAccessible] = kSecAttrAccessibleWhenUnlockedThisDeviceOnly
            SecItemAdd(addQuery as CFDictionary, nil)
        }
    }

    private static func load(key: String) -> String? {
        lock.lock()
        defer { lock.unlock() }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData: true,
            kSecMatchLimit: kSecMatchLimitOne,
        ]
        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    private static func delete(key: String) {
        lock.lock()
        defer { lock.unlock() }

        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
