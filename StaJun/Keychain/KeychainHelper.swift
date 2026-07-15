import Foundation
import Security

/// Keychain を使ったトークン永続化ヘルパー
enum KeychainHelper {
    private static let tokenKey = "com.oyajun.StaJun.authToken"

    /// 保存済み Bearer トークン（無ければ nil）
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

    // MARK: - Private

    private static func save(key: String, value: String) {
        let data = Data(value.utf8)
        // 既存を削除してから追加（update の代わり）
        delete(key: key)
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecValueData: data,
            kSecAttrAccessible: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        SecItemAdd(query as CFDictionary, nil)
    }

    private static func load(key: String) -> String? {
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
        let query: [CFString: Any] = [
            kSecClass: kSecClassGenericPassword,
            kSecAttrAccount: key,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
