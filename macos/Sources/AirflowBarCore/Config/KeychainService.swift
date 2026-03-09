import Foundation
import CryptoKit
import os

public enum KeychainError: Error, Sendable {
    case saveFailed(OSStatus)
    case loadFailed(OSStatus)
    case deleteFailed(OSStatus)
    case updateFailed(OSStatus)
    case dataConversionFailed
    case keychainCreationFailed(OSStatus)
}

/// Stores credentials in an encrypted file at ~/.airflowbar/credentials.enc
/// using CryptoKit (AES-GCM). Avoids macOS Keychain prompts for unsigned builds.
public struct KeychainService: Sendable {
    private static let logger = Logger(subsystem: "com.airflowbar", category: "credentials")
    private static let storeQueue = DispatchQueue(label: "com.airflowbar.credentials.store")

    private static let credentialsFile: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".airflowbar")
            .appendingPathComponent("credentials.enc")
    }()

    private static let keyFile: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".airflowbar")
            .appendingPathComponent(".credentials.key")
    }()

    // MARK: - Public API (unchanged interface)

    public static func save(credential: AuthCredential, for environmentId: UUID) throws {
        try storeQueue.sync {
            var store = loadStore()
            let data = try JSONEncoder().encode(credential)
            store[environmentId.uuidString] = data.base64EncodedString()
            try saveStore(store)
        }
    }

    public static func save(data: Data, for environmentId: UUID) throws {
        try storeQueue.sync {
            var store = loadStore()
            store[environmentId.uuidString] = data.base64EncodedString()
            try saveStore(store)
        }
    }

    public static func load(for environmentId: UUID) -> AuthCredential? {
        storeQueue.sync {
            let store = loadStore()
            guard let b64 = store[environmentId.uuidString],
                  let data = Data(base64Encoded: b64) else { return nil }
            return try? JSONDecoder().decode(AuthCredential.self, from: data)
        }
    }

    public static func delete(for environmentId: UUID) {
        storeQueue.sync {
            var store = loadStore()
            store.removeValue(forKey: environmentId.uuidString)
            try? saveStore(store)
        }
    }

    // MARK: - Encrypted Store

    private static func loadStore() -> [String: String] {
        guard FileManager.default.fileExists(atPath: credentialsFile.path) else { return [:] }
        do {
            let encrypted = try Data(contentsOf: credentialsFile)
            let key = try getOrCreateKey()
            let box = try AES.GCM.SealedBox(combined: encrypted)
            let decrypted = try AES.GCM.open(box, using: key)
            return try JSONDecoder().decode([String: String].self, from: decrypted)
        } catch {
            logger.error("Failed to load credentials: \(error.localizedDescription)")
            return [:]
        }
    }

    private static func saveStore(_ store: [String: String]) throws {
        let dir = credentialsFile.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        let key = try getOrCreateKey()
        let data = try JSONEncoder().encode(store)
        let sealed = try AES.GCM.seal(data, using: key)
        guard let combined = sealed.combined else {
            throw KeychainError.dataConversionFailed
        }
        try combined.write(to: credentialsFile, options: .atomic)

        // Restrict file permissions to owner only (600)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: credentialsFile.path
        )
    }

    // MARK: - Encryption Key

    private static func getOrCreateKey() throws -> SymmetricKey {
        if FileManager.default.fileExists(atPath: keyFile.path) {
            let keyData = try Data(contentsOf: keyFile)
            return SymmetricKey(data: keyData)
        }

        // Generate a new 256-bit key
        let key = SymmetricKey(size: .bits256)
        let keyData = key.withUnsafeBytes { Data($0) }

        let dir = keyFile.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        try keyData.write(to: keyFile, options: .atomic)

        // Restrict key file permissions to owner only (600)
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: keyFile.path
        )

        return key
    }
}
