import Foundation
import os

@Observable
public final class ConfigStore: @unchecked Sendable {
    private static let configDirectory = FileManager.default.homeDirectoryForCurrentUser
        .appendingPathComponent(".airflowbar")
    private static let configFile = configDirectory.appendingPathComponent("config.json")
    private static let logger = Logger(subsystem: "com.airflowbar", category: "config")

    public private(set) var config: AppConfig

    public init() {
        self.config = Self.loadConfig()
    }

    private static func loadConfig() -> AppConfig {
        guard FileManager.default.fileExists(atPath: configFile.path) else {
            return .default
        }
        do {
            let data = try Data(contentsOf: configFile)

            // Run migrations on raw JSON
            if var json = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                do {
                    let didMigrate = try ConfigMigrator.migrate(json: &json)
                    if didMigrate {
                        let migratedData = try JSONSerialization.data(withJSONObject: json)
                        let decoded = try JSONDecoder().decode(AppConfig.self, from: migratedData)
                        let hydrated = hydrateCredentials(config: decoded)

                        do {
                            let store = try JSONEncoder().encode(hydrated)
                            try store.write(to: configFile, options: .atomic)
                        } catch {
                            logger.error(
                                "Config migrated in memory but could not be persisted: \(error.localizedDescription)"
                            )
                        }

                        logger.info("Config migrated to version \(hydrated.version)")
                        return hydrated
                    }
                } catch {
                    logger.error(
                        "Config migration failed; keeping legacy credential data in memory: \(error.localizedDescription)"
                    )
                    if let legacyConfig = loadLegacyConfig(from: data) {
                        return legacyConfig
                    }
                }
            }

            let decoded = try JSONDecoder().decode(AppConfig.self, from: data)
            return hydrateCredentials(config: decoded)
        } catch {
            logger.error("Failed to load config: \(error.localizedDescription). Using defaults.")
            if let data = try? Data(contentsOf: configFile),
               let legacyConfig = loadLegacyConfig(from: data) {
                return legacyConfig
            }
            return .default
        }
    }

    /// Hydrate credentials from Keychain for each environment
    private static func hydrateCredentials(config: AppConfig) -> AppConfig {
        var config = config
        for i in config.environments.indices {
            let envId = config.environments[i].id
            if let credential = KeychainService.load(for: envId) {
                config.environments[i].credential = credential
            }
        }
        return config
    }

    public func save(_ newConfig: AppConfig) throws {
        var normalizedConfig = newConfig
        normalizedConfig.version = ConfigMigrator.currentVersion

        let dir = Self.configDirectory
        if !FileManager.default.fileExists(atPath: dir.path) {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }

        // Save credentials to Keychain
        for env in normalizedConfig.environments {
            try KeychainService.save(credential: env.credential, for: env.id)
        }

        // Clean up credentials for removed environments
        let newIds = Set(normalizedConfig.environments.map(\.id))
        let oldIds = Set(config.environments.map(\.id))
        for removedId in oldIds.subtracting(newIds) {
            KeychainService.delete(for: removedId)
        }

        // Encode config (credentials excluded by AirflowEnvironment's custom encoding)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(normalizedConfig)
        try data.write(to: Self.configFile, options: .atomic)
        self.config = normalizedConfig

        Self.logger.info("Config saved successfully")
    }

    public func reload() {
        self.config = Self.loadConfig()
    }

    public var hasEnvironments: Bool {
        !config.environments.isEmpty
    }

    /// Update detected API version for an environment
    public func updateDetectedVersion(_ version: APIVersion, for environmentId: UUID) {
        if let index = config.environments.firstIndex(where: { $0.id == environmentId }) {
            config.environments[index].detectedAPIVersion = version
            do {
                try save(config)
            } catch {
                Self.logger.error("Failed to persist detected API version: \(error.localizedDescription)")
            }
        }
    }
}

private extension ConfigStore {
    struct LegacyAppConfig: Decodable {
        var version: Int
        var environments: [LegacyAirflowEnvironment]
        var refreshInterval: RefreshInterval
        var showPausedDAGs: Bool
        var dagFilter: String?
        var maxRunsPerDAG: Int
        var notifications: NotificationSettings

        enum CodingKeys: String, CodingKey {
            case version
            case environments
            case refreshInterval
            case showPausedDAGs
            case dagFilter
            case maxRunsPerDAG
            case notifications
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
            self.environments = try container.decodeIfPresent([LegacyAirflowEnvironment].self, forKey: .environments) ?? []
            self.refreshInterval = try container.decodeIfPresent(RefreshInterval.self, forKey: .refreshInterval) ?? .fiveMinutes
            self.showPausedDAGs = try container.decodeIfPresent(Bool.self, forKey: .showPausedDAGs) ?? false
            self.dagFilter = try container.decodeIfPresent(String.self, forKey: .dagFilter)
            self.maxRunsPerDAG = try container.decodeIfPresent(Int.self, forKey: .maxRunsPerDAG) ?? 5
            self.notifications = try container.decodeIfPresent(NotificationSettings.self, forKey: .notifications) ?? NotificationSettings()
        }

        func asCurrentConfig() -> AppConfig {
            AppConfig(
                version: version,
                environments: environments.map(\.asCurrentEnvironment),
                refreshInterval: refreshInterval,
                showPausedDAGs: showPausedDAGs,
                dagFilter: dagFilter,
                maxRunsPerDAG: maxRunsPerDAG,
                notifications: notifications
            )
        }
    }

    struct LegacyAirflowEnvironment: Decodable {
        var id: UUID
        var name: String
        var baseURL: String
        var credential: AuthCredential
        var isEnabled: Bool
        var detectedAPIVersion: APIVersion?

        enum CodingKeys: String, CodingKey {
            case id
            case name
            case baseURL
            case credential
            case isEnabled
            case detectedAPIVersion
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = try container.decode(UUID.self, forKey: .id)
            self.name = try container.decode(String.self, forKey: .name)
            self.baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
            self.credential = try container.decode(AuthCredential.self, forKey: .credential)
            self.isEnabled = try container.decodeIfPresent(Bool.self, forKey: .isEnabled) ?? true
            self.detectedAPIVersion = try container.decodeIfPresent(APIVersion.self, forKey: .detectedAPIVersion)
        }

        var asCurrentEnvironment: AirflowEnvironment {
            AirflowEnvironment(
                id: id,
                name: name,
                baseURL: baseURL,
                credential: credential,
                isEnabled: isEnabled,
                detectedAPIVersion: detectedAPIVersion
            )
        }
    }

    static func loadLegacyConfig(from data: Data) -> AppConfig? {
        guard let config = try? JSONDecoder().decode(LegacyAppConfig.self, from: data) else {
            return nil
        }
        return config.asCurrentConfig()
    }
}
