import Foundation

public struct NotificationSettings: Codable, Sendable {
    public var onFailure: Bool
    public var onRecovery: Bool

    public init(onFailure: Bool = true, onRecovery: Bool = true) {
        self.onFailure = onFailure
        self.onRecovery = onRecovery
    }
}

public struct AppConfig: Codable, Sendable {
    public var version: Int
    public var environments: [AirflowEnvironment]
    public var refreshInterval: RefreshInterval
    public var showPausedDAGs: Bool
    public var dagFilter: String?
    public var maxRunsPerDAG: Int
    public var notifications: NotificationSettings
    public var checkForUpdates: Bool

    public init(
        version: Int = ConfigMigrator.currentVersion,
        environments: [AirflowEnvironment] = [],
        refreshInterval: RefreshInterval = .fiveMinutes,
        showPausedDAGs: Bool = false,
        dagFilter: String? = nil,
        maxRunsPerDAG: Int = 5,
        notifications: NotificationSettings = NotificationSettings(),
        checkForUpdates: Bool = true
    ) {
        self.version = version
        self.environments = environments
        self.refreshInterval = refreshInterval
        self.showPausedDAGs = showPausedDAGs
        self.dagFilter = dagFilter
        self.maxRunsPerDAG = maxRunsPerDAG
        self.notifications = notifications
        self.checkForUpdates = checkForUpdates
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        self.version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        self.environments = try container.decodeIfPresent([AirflowEnvironment].self, forKey: .environments) ?? []
        self.refreshInterval = try container.decodeIfPresent(RefreshInterval.self, forKey: .refreshInterval) ?? .fiveMinutes
        self.showPausedDAGs = try container.decodeIfPresent(Bool.self, forKey: .showPausedDAGs) ?? false
        self.dagFilter = try container.decodeIfPresent(String.self, forKey: .dagFilter)
        self.maxRunsPerDAG = try container.decodeIfPresent(Int.self, forKey: .maxRunsPerDAG) ?? 5
        self.notifications = try container.decodeIfPresent(NotificationSettings.self, forKey: .notifications) ?? NotificationSettings()
        self.checkForUpdates = try container.decodeIfPresent(Bool.self, forKey: .checkForUpdates) ?? true
    }

    public static let `default` = AppConfig()

    /// Returns the first enabled environment, if any
    public var activeEnvironment: AirflowEnvironment? {
        environments.first(where: \.isEnabled)
    }

    /// Returns all enabled environments
    public var enabledEnvironments: [AirflowEnvironment] {
        environments.filter(\.isEnabled)
    }
}
