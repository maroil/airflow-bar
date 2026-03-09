import Foundation

enum ConfigMigrationError: Error, Sendable {
    case invalidEnvironmentIdentifier
    case invalidCredentialPayload(environmentId: UUID)
    case credentialSaveFailed(environmentId: UUID, message: String)
}

public struct ConfigMigrator: Sendable {
    public static let currentVersion = 2

    typealias CredentialSaver = @Sendable (Data, UUID) throws -> Void
    private static let migrations: [Int: @Sendable (_ json: inout [String: Any], _ saveCredential: CredentialSaver) throws -> Void] = [
        1: migrateV1toV2,
    ]

    /// Run all pending migrations on raw JSON dictionary.
    /// Returns the migrated dictionary and whether any migration ran.
    static func migrate(
        json: inout [String: Any],
        saveCredential: @escaping CredentialSaver = { data, environmentId in
            try KeychainService.save(data: data, for: environmentId)
        }
    ) throws -> Bool {
        let version = json["version"] as? Int ?? 1
        guard version < currentVersion else { return false }

        for v in version..<currentVersion {
            if let migration = migrations[v] {
                try migration(&json, saveCredential)
            }
        }
        json["version"] = currentVersion
        return true
    }

    /// v1→v2: Move inline credentials from environments to Keychain.
    /// Strips credential fields from JSON; ConfigStore hydrates from Keychain after decode.
    private static func migrateV1toV2(
        _ json: inout [String: Any],
        saveCredential: CredentialSaver
    ) throws {
        guard var environments = json["environments"] as? [[String: Any]] else { return }
        var migratedIndices: [Int] = []

        for i in environments.indices {
            guard let credential = environments[i]["credential"] as? [String: Any] else {
                continue
            }

            guard let id = environments[i]["id"] as? String,
                  let envId = UUID(uuidString: id) else {
                throw ConfigMigrationError.invalidEnvironmentIdentifier
            }

            guard JSONSerialization.isValidJSONObject(credential) else {
                throw ConfigMigrationError.invalidCredentialPayload(environmentId: envId)
            }

            let credentialData = try JSONSerialization.data(withJSONObject: credential)
            do {
                try saveCredential(credentialData, envId)
            } catch {
                throw ConfigMigrationError.credentialSaveFailed(
                    environmentId: envId,
                    message: error.localizedDescription
                )
            }
            migratedIndices.append(i)
        }

        for index in migratedIndices {
            environments[index].removeValue(forKey: "credential")
        }
        json["environments"] = environments
    }
}
