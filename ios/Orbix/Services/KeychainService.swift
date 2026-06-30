import Security
import Foundation
import os

enum KeychainService {
    private static let service = "com.orbix.keychain"
    private static let logger = Logger(subsystem: "com.orbix", category: "Keychain")

    @discardableResult
    static func save(key: String, data: Data) -> Bool {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly
        ]
        let deleteStatus = SecItemDelete(query as CFDictionary)
        if deleteStatus != errSecSuccess && deleteStatus != errSecItemNotFound {
            logger.error("Keychain delete failed for key=\(key): OSStatus \(deleteStatus)")
        }
        let addStatus = SecItemAdd(query as CFDictionary, nil)
        if addStatus != errSecSuccess {
            logger.error("Keychain add failed for key=\(key): OSStatus \(addStatus)")
            return false
        }
        return true
    }

    static func load(key: String) -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess, let data = item as? Data else {
            logger.error("Keychain load failed for key=\(key): OSStatus \(status)")
            return nil
        }
        return data
    }

    static func delete(key: String) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: key
        ]
        let status = SecItemDelete(query as CFDictionary)
        if status != errSecSuccess && status != errSecItemNotFound {
            logger.error("Keychain delete failed for key=\(key): OSStatus \(status)")
        }
    }

    static func saveString(_ value: String, forKey key: String) {
        if let data = value.data(using: .utf8) {
            _ = save(key: key, data: data)
        }
    }

    static func loadString(forKey key: String) -> String? {
        guard let data = load(key: key) else { return nil }
        return String(data: data, encoding: .utf8)
    }
}
