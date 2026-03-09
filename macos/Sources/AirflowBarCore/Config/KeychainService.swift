import Foundation
import Security
import os

public enum KeychainError: Error, Sendable {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case updateFailed(OSStatus)
    case dataConversionFailed
}

public struct KeychainService: Sendable {
    private static let service = "com.airflowbar.credentials"
    private static let logger = Logger(subsystem: "com.airflowbar", category: "keychain")

    public static func save(credential: AuthCredential, for environmentId: UUID) throws {
        let data = try JSONEncoder().encode(credential)
        try save(data: data, for: environmentId)
    }

    public static func save(data: Data, for environmentId: UUID) throws {
        let account = environmentId.uuidString

        // Try to update first
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]

        let existing = SecItemCopyMatching(query as CFDictionary, nil)
        if existing == errSecSuccess {
            let update: [String: Any] = [kSecValueData as String: data]
            let status = SecItemUpdate(query as CFDictionary, update as CFDictionary)
            guard status == errSecSuccess else { throw KeychainError.updateFailed(status) }
        } else {
            var newItem = query
            newItem[kSecValueData as String] = data
            newItem[kSecAttrAccessible as String] = kSecAttrAccessibleWhenUnlocked

            let status = SecItemAdd(newItem as CFDictionary, nil)
            guard status == errSecSuccess else { throw KeychainError.saveFailed(status) }
        }
    }

    public static func load(for environmentId: UUID) -> AuthCredential? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: environmentId.uuidString,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess else {
            return nil
        }
        guard let data = result as? Data else {
            logger.error("Keychain returned non-data credential payload for \(environmentId.uuidString)")
            return nil
        }
        do {
            return try JSONDecoder().decode(AuthCredential.self, from: data)
        } catch {
            logger.error(
                "Failed to decode keychain credential for \(environmentId.uuidString): \(error.localizedDescription)"
            )
            return nil
        }
    }

    public static func delete(for environmentId: UUID) {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: environmentId.uuidString,
        ]
        SecItemDelete(query as CFDictionary)
    }
}
